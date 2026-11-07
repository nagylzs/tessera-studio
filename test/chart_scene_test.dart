import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Size;

import 'package:flutter/material.dart' show Brightness, ColorScheme;
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_studio/app.dart' show tesseraGreen;
import 'package:tessera_studio/charts/chart_content.dart';
import 'package:tessera_studio/charts/chart_export.dart';
import 'package:tessera_studio/charts/chart_layout.dart';
import 'package:tessera_studio/charts/chart_scene.dart';
import 'package:tessera_studio/charts/chart_settings.dart';
import 'package:xml/xml.dart';

const _strings = TesseraStringsEn();

const region = ColumnDimension('region');
const product = ColumnDimension('product');
const year = ColumnDimension('year');
final amount = Aggregate.sum(const Measure('amount'));
final units = Aggregate.sum(const Measure('units'));

Future<FactTable> _factsOf(String csv) async => (await loadFacts(
  CsvDataSource.fromData(Uint8List.fromList(utf8.encode(csv)), name: 'a.csv'),
)).facts;

Future<FactTable> _facts() => _factsOf(
  'region,product,year,amount,units\n'
  'EU,p1,2023,10,1\n'
  'EU,p2,2023,20,2\n'
  'EU,p1,2024,30,3\n'
  'US,p2,2023,40,4\n'
  'US,p3,2024,50,5\n'
  'Asia,p3,2024,5,6\n',
);

Cube _cube(
  FactTable facts, {
  List<Dimension> rows = const [region],
  List<Dimension> columns = const [],
  List<Aggregate>? aggregates,
}) => Cube(
  facts: facts,
  spec: CubeSpec(
    rows: CubeAxis.of(rows),
    columns: CubeAxis.of(columns),
    aggregates: aggregates ?? [amount],
  ),
);

/// Half an em a character: wide enough to look like a real font's.
double _measure(String text, double size) => text.runes.length * size * 0.55;

ChartScene _scene(
  Cube cube, {
  ChartSettings settings = const ChartSettings(),
  ChartLook look = plainChartLook,
  List<String> caption = const ['the caption'],
  String? problem,
  String title = 'the title',
  List<Dimension> dimensions = const [region, product, year],
}) => chartScene(
  chartContent(
    cube: cube,
    settings: settings,
    dimensions: dimensions,
    strings: _strings,
  ),
  title: title,
  caption: caption,
  problem: problem,
  others: 'Others',
  look: look,
  strings: _strings,
  locale: 'en',
  measure: _measure,
);

Iterable<T> _all<T>(ChartScene s) => s.shapes.whereType<T>();
List<String> _texts(ChartScene s) => [
  for (final t in _all<SceneText>(s)) t.text,
];

/// Every shape's outline stays on the page, the text's by its measured width.
void _expectOnPage(ChartScene s) {
  void x(double v, Object what) =>
      expect(v, inInclusiveRange(-0.01, s.width + 0.01), reason: 'x of $what');
  void y(double v, Object what) =>
      expect(v, inInclusiveRange(-0.01, s.height + 0.01), reason: 'y of $what');
  for (final shape in s.shapes) {
    switch (shape) {
      case SceneRect():
        x(shape.x, shape);
        x(shape.x + shape.width, shape);
        y(shape.y, shape);
        y(shape.y + shape.height, shape);
      case SceneLine():
        x(shape.x1, shape);
        x(shape.x2, shape);
        y(shape.y1, shape);
        y(shape.y2, shape);
      case ScenePolyline():
        for (final p in shape.points) {
          x(p.dx, shape);
          y(p.dy, shape);
        }
      case SceneCircle():
        x(shape.x - shape.radius, shape);
        x(shape.x + shape.radius, shape);
        y(shape.y - shape.radius, shape);
        y(shape.y + shape.radius, shape);
      case SceneSlice():
        x(shape.x - shape.radius, shape);
        x(shape.x + shape.radius, shape);
        y(shape.y - shape.radius, shape);
        y(shape.y + shape.radius, shape);
      case SceneText():
        final width = _measure(shape.text, shape.size);
        final left = switch (shape.anchor) {
          TextAnchor.start => shape.x,
          TextAnchor.middle => shape.x - width / 2,
          TextAnchor.end => shape.x - width,
        };
        x(left, '"${shape.text}"');
        x(left + width, '"${shape.text}"');
        y(shape.y, '"${shape.text}"');
    }
  }
}

void main() {
  group('bars', () {
    test('are as tall as their values, from one zero line', () async {
      final scene = _scene(_cube(await _facts()));
      final bars = _all<SceneRect>(scene).toList();
      expect(bars, hasLength(3)); // Asia, EU, US; no legend for one series
      final heights = {
        for (final b in bars) (b.height / bars.first.height).toStringAsFixed(3),
      };
      expect(heights, hasLength(3));
      // sorted by name: Asia 5, EU 60, US 90
      expect(bars[1].height / bars[0].height, closeTo(60 / 5, 1e-9));
      expect(bars[2].height / bars[1].height, closeTo(90 / 60, 1e-9));
      final zero = bars.first.y + bars.first.height;
      for (final b in bars) {
        expect(b.y + b.height, closeTo(zero, 1e-9));
      }
    });

    test('stack in their series order, the total at the top', () async {
      final scene = _scene(
        _cube(await _facts(), columns: const [year]),
        settings: const ChartSettings(kind: ChartKind.stacked),
      );
      // 4 stack items and a swatch per series
      final rects = _all<SceneRect>(scene).toList();
      final rods = rects.where((r) => r.width != 12).toList();
      expect(rods, hasLength(5)); // Asia 2024; EU both; US both
      final eu = rods.where((r) => r.x == rods[1].x).toList();
      expect(eu, hasLength(2));
      // the second sits on the first
      expect(eu[1].y + eu[1].height, closeTo(eu[0].y, 1e-9));
    });

    test('below zero go downwards', () async {
      final facts = await _factsOf('region,amount\nA,10\nB,-5\n');
      final scene = _scene(_cube(facts));
      final bars = _all<SceneRect>(scene).toList();
      expect(bars[0].y + bars[0].height, closeTo(bars[1].y, 1e-9));
      expect(bars[0].height / bars[1].height, closeTo(2, 1e-9));
    });

    test('a group\'s label has its ancestors on a line above it', () async {
      final cube = _cube(
        await _facts(),
        rows: const [region, product],
      ).expandRowLevel(0);
      final scene = _scene(cube);
      final texts = _texts(scene);
      expect(texts, contains('EU'));
      expect(texts, contains('p1'));
      final eu = _all<SceneText>(scene).firstWhere((t) => t.text == 'EU');
      final p1 = _all<SceneText>(scene).firstWhere((t) => t.text == 'p1');
      expect(p1.y, greaterThan(eu.y));
    });

    test('more groups than fit: every n-th is written', () async {
      final csv = StringBuffer('region,amount\n');
      for (var i = 0; i < 60; i++) {
        csv.writeln('group$i,${i + 1}');
      }
      final scene = _scene(_cube(await _factsOf(csv.toString())));
      expect(_all<SceneRect>(scene), hasLength(60));
      final labels = _texts(scene).where((t) => t.startsWith('group')).toList();
      expect(labels.length, lessThan(30));
      expect(labels.length, greaterThan(5));
      _expectOnPage(scene);
    });

    test('a legend names the series, only when there are several', () async {
      final facts = await _facts();
      expect(_texts(_scene(_cube(facts))), isNot(contains('2023')));
      final split = _scene(_cube(facts, columns: const [year]));
      expect(_texts(split), containsAll(['2023', '2024']));
    });
  });

  group('lines', () {
    test('have a point per value', () async {
      final scene = _scene(
        _cube(await _facts(), columns: const [year]),
        settings: const ChartSettings(kind: ChartKind.line),
      );
      expect(_all<SceneCircle>(scene), hasLength(5));
      expect(_all<ScenePolyline>(scene), isNotEmpty);
    });

    test('a blank cell breaks a line on a categorical axis', () async {
      // the 2023 series has no value for Asia, which comes first; and the
      // middle group of a second chart has none
      final facts = await _factsOf(
        'region,year,amount\nA,1,1\nB,2,2\nC,1,3\nD,1,4\n',
      );
      final scene = _scene(
        _cube(facts, columns: const [ColumnDimension('year')]),
        settings: const ChartSettings(kind: ChartKind.line),
        dimensions: const [region, ColumnDimension('year')],
      );
      // year 1: A | C, D, so one run of two points; year 2: B alone, no run
      expect(_all<ScenePolyline>(scene).map((l) => l.points.length), [2]);
      expect(_all<SceneCircle>(scene), hasLength(4));
    });

    test('a month without values leaves its gap on a time axis', () async {
      final facts = await _factsOf(
        'day,amount\n2025-01-15,1\n2025-02-15,2\n2025-06-15,3\n',
      );
      const year = DatePartDimension('day', DatePart.year);
      const month = DatePartDimension('day', DatePart.month);
      final cube = _cube(facts, rows: const [year, month]).expandRowLevel(0);
      final scene = _scene(
        cube,
        settings: const ChartSettings(kind: ChartKind.line),
        dimensions: const [year, month],
      );
      final xs = [for (final c in _all<SceneCircle>(scene)) c.x];
      expect(xs, hasLength(3));
      final oneMonth = xs[1] - xs[0];
      expect(xs[2] - xs[1], closeTo(4 * oneMonth, 1e-6));
      expect(_texts(scene).any((t) => t.startsWith('2025-')), isTrue);
    });
  });

  group('a pie', () {
    test('goes clockwise from noon, the whole way round', () async {
      final scene = _scene(
        _cube(await _facts()),
        settings: const ChartSettings(kind: ChartKind.pie),
      );
      final slices = _all<SceneSlice>(scene).toList();
      expect(slices, hasLength(3));
      expect(slices.first.start, closeTo(-math.pi / 2, 0.02));
      final swept = slices.fold(0.0, (sum, s) => sum + s.sweep);
      // a hair between each
      expect(swept, closeTo(2 * math.pi, 0.05));
      // largest first: US 90, EU 60, Asia 5, as a share of 155
      expect(slices[0].sweep / slices[1].sweep, closeTo(90 / 60, 0.02));
    });

    test('its legend starts with the percentages', () async {
      final texts = _texts(
        _scene(
          _cube(await _facts()),
          settings: const ChartSettings(kind: ChartKind.pie),
        ),
      );
      expect(texts, containsAll(['58% US', '39% EU', '3% Asia']));
      // on the slice too, unless it is too small
      expect(texts, containsAll(['58%', '39%']));
      expect(texts, isNot(contains('3%')));
    });

    test('a single group is a whole circle', () async {
      final facts = await _factsOf('region,amount\nA,10\n');
      final scene = _scene(
        _cube(facts),
        settings: const ChartSettings(kind: ChartKind.pie),
      );
      expect(_all<SceneSlice>(scene), isEmpty);
      expect(_all<SceneCircle>(scene), hasLength(1));
    });

    test('small groups merge into Others', () async {
      final csv = StringBuffer('region,amount\n');
      for (var i = 0; i < 30; i++) {
        csv.writeln('group$i,${i + 1}');
      }
      final scene = _scene(
        _cube(await _factsOf(csv.toString())),
        settings: const ChartSettings(kind: ChartKind.pie),
      );
      expect(_texts(scene).where((t) => t.endsWith(' Others')), hasLength(1));
      _expectOnPage(scene);
    });
  });

  group('a scatter chart', () {
    Future<Cube> two() async =>
        _cube(await _facts(), aggregates: [amount, units]);

    test(
      'names its axes by letter, in the bundled font\'s characters',
      () async {
        final scene = _scene(
          await two(),
          settings: const ChartSettings(kind: ChartKind.scatter),
        );
        final axes = _texts(scene).singleWhere((t) => t.startsWith('X: '));
        expect(axes, contains('Y: '));
        expect(axes, isNot(contains('→')));
      },
    );

    test('keeps every dot inside its plot', () async {
      final scene = _scene(
        await two(),
        settings: const ChartSettings(kind: ChartKind.scatter),
      );
      final dots = _all<SceneCircle>(scene).toList();
      expect(dots, hasLength(3));
      final lines = _all<SceneLine>(scene).toList();
      final top = lines.map((l) => math.min(l.y1, l.y2)).reduce(math.min);
      final bottom = lines.map((l) => math.max(l.y1, l.y2)).reduce(math.max);
      final left = lines.map((l) => math.min(l.x1, l.x2)).reduce(math.min);
      final right = lines.map((l) => math.max(l.x1, l.x2)).reduce(math.max);
      for (final d in dots) {
        expect(d.x - d.radius, greaterThanOrEqualTo(left));
        expect(d.x + d.radius, lessThanOrEqualTo(right));
        expect(d.y - d.radius, greaterThanOrEqualTo(top));
        expect(d.y + d.radius, lessThanOrEqualTo(bottom));
      }
    });
  });

  group('the page', () {
    test('has the title and each line of the caption', () async {
      final scene = _scene(
        _cube(await _facts()),
        title: 'Sales 2025',
        caption: const ['first line', '', 'second line'],
      );
      expect(
        _texts(scene),
        containsAll(['Sales 2025', 'first line', 'second line']),
      );
      final first = _all<SceneText>(scene)
          .firstWhere((t) => t.text == 'first line');
      final second = _all<SceneText>(scene)
          .firstWhere((t) => t.text == 'second line');
      expect(second.y, greaterThan(first.y));
    });

    test('long names are cut, and everything stays on it', () async {
      final long = 'a very long name ' * 8;
      final facts = await _factsOf(
        'region,year,amount,units\n'
        '$long 1,$long x,10,1\n'
        '$long 2,$long y,20,2\n'
        '$long 3,$long x,30,3\n',
      );
      final cube = _cube(
        facts,
        columns: const [ColumnDimension('year')],
        aggregates: [amount, units],
      );
      for (final kind in ChartKind.values) {
        final scene = _scene(
          cube,
          settings: ChartSettings(kind: kind),
          title: long,
          caption: [long],
          dimensions: const [region, ColumnDimension('year')],
        );
        _expectOnPage(scene);
        expect(
          _texts(scene).any((t) => t.endsWith('…')),
          isTrue,
          reason: '$kind',
        );
      }
    });

    test('every kind stays on the page, swapped or not', () async {
      final cube = _cube(
        await _facts(),
        columns: const [year],
        aggregates: [amount, units],
      );
      for (final kind in ChartKind.values) {
        for (final transpose in const [false, true]) {
          _expectOnPage(
            _scene(
              cube,
              settings: ChartSettings(kind: kind, transpose: transpose),
            ),
          );
        }
      }
    });

    test('says what is wrong when there is nothing to draw', () async {
      final facts = await _facts();
      final scene = _scene(
        _cube(facts),
        settings: const ChartSettings(kind: ChartKind.scatter),
        problem: 'needs two values',
      );
      expect(_texts(scene), contains('needs two values'));
      expect(_all<SceneRect>(scene), isEmpty);
      _expectOnPage(scene);
    });

    test('the look sets the background and the colours', () async {
      final cube = _cube(await _facts());
      final light = _scene(cube);
      expect(light.background, const Color(0xFFFFFFFF));
      final dark = _scene(cube, look: (dark: true, transparent: false));
      expect(
        dark.background,
        ColorScheme.fromSeed(
          seedColor: tesseraGreen,
          brightness: Brightness.dark,
        ).surface,
      );
      expect(
        _scene(cube, look: (dark: true, transparent: true)).background,
        isNull,
      );
      // the text follows the look, background or none
      Color titleOf(ChartScene s) =>
          _all<SceneText>(s).firstWhere((t) => t.text == 'the title').color;
      expect(titleOf(light).computeLuminance(), lessThan(0.2));
      expect(
        titleOf(_scene(cube, look: (dark: true, transparent: true)))
            .computeLuminance(),
        greaterThan(0.5),
      );
    });

    test('is the exported size', () async {
      final scene = _scene(_cube(await _facts()));
      expect(Size(scene.width, scene.height), chartImageSize);
    });
  });

  group('SVG', () {
    Future<XmlDocument> svg(ChartScene s) async =>
        XmlDocument.parse(sceneSvg(s));

    test('is well formed, with the scene in it', () async {
      final scene = _scene(_cube(await _facts()));
      final doc = await svg(scene);
      final root = doc.rootElement;
      expect(root.name.local, 'svg');
      expect(root.getAttribute('viewBox'), '0 0 1000 640');
      final texts = doc.findAllElements('text').map((e) => e.innerText);
      expect(texts, containsAll(['the title', 'the caption', 'EU', 'US']));
      // 3 bars and the background
      expect(doc.findAllElements('rect'), hasLength(4));
      expect(doc.findAllElements('line'), isNotEmpty);
    });

    test('escapes what the data may hold', () async {
      final facts = await _factsOf('region,amount\n"<b>A&B""</b>",1\nC,2\n');
      final scene = _scene(_cube(facts), title: 'a <title> & more');
      final doc = await svg(scene);
      expect(doc.findAllElements('title').single.innerText, 'a <title> & more');
      expect(
        doc.findAllElements('text').map((e) => e.innerText),
        contains('<b>A&B"</b>'),
      );
    });

    test('has no background when transparent', () async {
      final cube = _cube(await _facts());
      final solid = await svg(_scene(cube));
      final clear = await svg(
        _scene(cube, look: (dark: false, transparent: true)),
      );
      expect(
        solid.findAllElements('rect').length,
        clear.findAllElements('rect').length + 1,
      );
    });

    test('draws every kind, with the opacity of a scatter\'s dots', () async {
      final cube = _cube(await _facts(), aggregates: [amount, units]);
      expect(
        (await svg(
          _scene(cube, settings: const ChartSettings(kind: ChartKind.pie)),
        )).findAllElements('path'),
        hasLength(3),
      );
      final line = await svg(
        _scene(cube, settings: const ChartSettings(kind: ChartKind.line)),
      );
      expect(line.findAllElements('polyline'), isNotEmpty);
      final dots = await svg(
        _scene(cube, settings: const ChartSettings(kind: ChartKind.scatter)),
      );
      expect(
        dots.findAllElements('circle').first.getAttribute('fill-opacity'),
        isNotNull,
      );
    });
  });

  group('PDF', () {
    final font = ByteData.sublistView(
      File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
    );

    test('is written for every kind', () async {
      final cube = _cube(await _facts(), aggregates: [amount, units]);
      for (final kind in ChartKind.values) {
        final bytes = await scenePdf(
          _scene(cube, settings: ChartSettings(kind: kind)),
          font,
        );
        // what is inside is compressed; pdfinfo and pdftoppm checked it once
        expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-', reason: '$kind');
        expect(latin1.decode(bytes).trimRight(), endsWith('%%EOF'));
      }
    });

    test('survives what the bundled font does not have', () async {
      final facts = await _factsOf('region,amount\n日本語,1\nÁrvíztűrő,2\n');
      final bytes = await scenePdf(_scene(_cube(facts), title: '売上'), font);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
