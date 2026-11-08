import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_studio/charts/chart_content.dart';
import 'package:tessera_studio/charts/chart_drawing.dart';
import 'package:tessera_studio/charts/chart_settings.dart';
import 'package:tessera_studio/state/layout_store.dart';

const _strings = TesseraStringsEn();

const region = ColumnDimension('region');
const product = ColumnDimension('product');
const year = ColumnDimension('year');
final amount = Aggregate.sum(const Measure('amount'));
final units = Aggregate.sum(const Measure('units'));

/// region × product × year, with a value for a text-sorted chart.
Future<FactTable> _facts() async {
  const csv =
      'region,product,year,amount,units\n'
      'EU,p1,2023,10,1\n'
      'EU,p2,2023,20,2\n'
      'EU,p1,2024,30,3\n'
      'US,p2,2023,40,4\n'
      'US,p3,2024,50,5\n'
      'Asia,p3,2024,5,6\n';
  final source = CsvDataSource.fromData(
    Uint8List.fromList(utf8.encode(csv)),
    name: 'sales.csv',
  );
  return (await loadFacts(source)).facts;
}

Cube _cube(
  FactTable facts, {
  List<Dimension> rows = const [region],
  List<Dimension> columns = const [],
  List<Aggregate>? aggregates,
  FactFilter? filter,
}) => Cube(
  facts: facts,
  spec: CubeSpec(
    rows: CubeAxis.of(rows),
    columns: CubeAxis.of(columns),
    aggregates: aggregates ?? [amount],
    filter: filter,
  ),
);

ChartContent _content(
  Cube cube, {
  ChartSettings settings = const ChartSettings(),
  List<Aggregate>? shown,
  CubeCell? cell,
  List<Dimension> dimensions = const [region, product, year],
}) => chartContent(
  cube: cube,
  settings: settings,
  dimensions: dimensions,
  strings: _strings,
  shown: shown,
  cell: cell,
);

DimensionPath _group(Dimension dimension, Object value) =>
    DimensionPath.root.child(DimensionValue(dimension, value));

/// What the grid shows: the cell of [row] × [column] for [aggregate].
double? _grid(
  Cube cube,
  List<Object> row,
  List<Object> column,
  Aggregate aggregate,
) {
  DimensionPath path(CubeAxis axis, List<Object> values) {
    var p = DimensionPath.root;
    for (var i = 0; i < values.length; i++) {
      p = p.child(DimensionValue(axis.dimensions[i].dimension, values[i]));
    }
    return p;
  }

  final cell = cube.layout.cellFor(
    path(cube.spec.rows, row),
    path(cube.spec.columns, column),
  );
  return (cell?.aggregate(aggregate) as num?)?.toDouble();
}

void main() {
  group('placement', () {
    test('by window size, not by device', () {
      // desktops and tablets in landscape
      expect(ChartPlacement.of(const Size(1600, 1000)), ChartPlacement.beside);
      expect(ChartPlacement.of(const Size(1280, 800)), ChartPlacement.beside);
      expect(ChartPlacement.of(const Size(840, 480)), ChartPlacement.beside);
      // tablets in portrait, narrow windows
      expect(ChartPlacement.of(const Size(800, 1280)), ChartPlacement.above);
      expect(ChartPlacement.of(const Size(600, 600)), ChartPlacement.above);
      // phones, either way up, and small windows
      expect(ChartPlacement.of(const Size(412, 915)), ChartPlacement.instead);
      expect(ChartPlacement.of(const Size(915, 412)), ChartPlacement.instead);
      expect(ChartPlacement.of(const Size(599, 900)), ChartPlacement.instead);
      expect(ChartPlacement.of(const Size(700, 500)), ChartPlacement.instead);
    });
  });

  group('the pivot', () {
    test('a chart agrees with the grid, cell by cell', () async {
      final facts = await _facts();
      final cube = _cube(facts, rows: [region], columns: [year]);
      final data = _content(cube).data!;
      expect(data.categories.map((c) => c.label), ['Asia', 'EU', 'US']);
      expect(data.series.map((s) => s.label), ['2023', '2024']);
      for (final s in data.series) {
        for (var i = 0; i < data.categories.length; i++) {
          expect(
            s.values[i],
            _grid(cube, [data.categories[i].value!], [s.value!], amount),
            reason: '${data.categories[i].label} ${s.label}',
          );
        }
      }
      // spot checks against the CSV itself
      expect(data.series[0].values, [null, 30, 40]);
      expect(data.series[1].values, [5, 30, 50]);
    });

    test('follows the filter and the expanded groups', () async {
      final facts = await _facts();
      final filtered = _cube(facts, filter: ValueFilter(region, const ['EU']));
      expect(_content(filtered).data!.categories.map((c) => c.label), ['EU']);
      expect(_content(filtered).data!.series.first.values, [60]);

      var cube = _cube(facts, rows: [region, product]);
      var data = _content(cube).data!;
      expect(data.categories.length, 3);
      cube = cube.toggleRow(_group(region, 'EU'));
      data = _content(cube).data!;
      // EU's children take its place, so that it is not counted twice
      expect(data.categories.map((c) => c.label), ['Asia', 'p1', 'p2', 'US']);
      expect(data.series.first.values, [5, 40, 20, 90]);
    });

    test('swaps rows and columns', () async {
      final facts = await _facts();
      final cube = _cube(facts, rows: [region], columns: [year]);
      final data = _content(
        cube,
        settings: const ChartSettings(transpose: true),
      ).data!;
      expect(data.categories.map((c) => c.label), ['2023', '2024']);
      expect(data.series.map((s) => s.label), ['Asia', 'EU', 'US']);
      expect(data.series[2].values, [40, 50]);
    });

    test('starts from the first value the grid shows', () async {
      final facts = await _facts();
      final cube = _cube(facts, aggregates: [amount, units]);
      expect(_content(cube).value, amount);
      expect(_content(cube, shown: [units]).value, units);
      expect(
        _content(
          cube,
          shown: [units],
          settings: ChartSettings(value: amount),
        ).value,
        amount,
      );
    });

    test('a choice the pivot no longer has falls back', () async {
      final facts = await _facts();
      final cube = _cube(facts);
      final content = _content(cube, settings: ChartSettings(value: units));
      expect(content.value, amount);
      expect(content.data!.series.first.values, [5, 60, 90]);
    });

    test('draws the first groups and series of a large pivot', () async {
      final rows = StringBuffer('name,kind,amount\n');
      for (var i = 0; i < 100; i++) {
        for (var k = 0; k < 20; k++) {
          rows.writeln('n${i.toString().padLeft(3, '0')},k$k,1');
        }
      }
      final facts = (await loadFacts(
        CsvDataSource.fromData(
          Uint8List.fromList(utf8.encode(rows.toString())),
          name: 'large.csv',
        ),
      )).facts;
      final cube = _cube(
        facts,
        rows: const [ColumnDimension('name')],
        columns: const [ColumnDimension('kind')],
      );
      final content = _content(cube);
      expect(content.data!.categories.length, maxCategories(ChartKind.bar));
      expect(content.data!.series.length, maxSeries);
      expect(content.categoriesTotal, 100);
      expect(content.seriesTotal, 20);
      expect(content.categoriesShown, maxCategories(ChartKind.bar));
      expect(content.seriesShown, maxSeries);
      expect(content.data!.categories.first.label, 'n000');
    });
  });

  group('a pie', () {
    test('shows the totals of the groups', () async {
      final facts = await _facts();
      final cube = _cube(facts, rows: [region], columns: [year]);
      final data = _content(
        cube,
        settings: const ChartSettings(kind: ChartKind.pie),
      ).data!;
      expect(data.series.single.path.isRoot, isTrue);
      expect(data.series.single.values, [5, 60, 90]);
    });

    test('of a pivot that hides its totals shows the first series', () async {
      final facts = await _facts();
      final cube = Cube(
        facts: facts,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([year], summaryPosition: SummaryPosition.hidden),
          aggregates: [amount],
        ),
      );
      final data = _content(
        cube,
        settings: const ChartSettings(kind: ChartKind.pie),
      ).data!;
      expect(data.series.single.label, '2023');
    });

    test('merges small slices, keeping the percentages true', () async {
      final rows = StringBuffer('name,amount\n');
      for (var i = 0; i < 30; i++) {
        rows.writeln('n$i,${100 - i}');
      }
      rows.writeln('minus,-5');
      final facts = (await loadFacts(
        CsvDataSource.fromData(
          Uint8List.fromList(utf8.encode(rows.toString())),
          name: 'many.csv',
        ),
      )).facts;
      final cube = _cube(facts, rows: const [ColumnDimension('name')]);
      final content = _content(
        cube,
        settings: const ChartSettings(kind: ChartKind.pie),
      );
      final (:slices, :left) = pieSlices(content.data!);
      expect(slices.length, maxPieSlices);
      expect(slices.last.index, isNull);
      expect(left, 1);
      final all = [for (var i = 0; i < 30; i++) 100.0 - i];
      expect(
        slices.fold(0.0, (sum, s) => sum + s.value),
        all.reduce((a, b) => a + b),
      );
      expect(slices.first.value, 100);
    });

    test('without a positive value says so', () async {
      final facts = (await loadFacts(
        CsvDataSource.fromData(
          Uint8List.fromList(utf8.encode('name,amount\na,-1\nb,0\n')),
          name: 'negative.csv',
        ),
      )).facts;
      final cube = _cube(facts, rows: const [ColumnDimension('name')]);
      expect(
        _content(
          cube,
          settings: const ChartSettings(kind: ChartKind.pie),
        ).problem,
        ChartProblem.noPositive,
      );
    });
  });

  group('the current cell', () {
    test('is broken down by the first dimension it leaves free', () async {
      final facts = await _facts();
      final cube = _cube(facts, rows: [region, product]);
      final eu = _group(region, 'EU');
      final cell = cube.layout.cellFor(eu, DimensionPath.root)!;
      final content = _content(
        cube,
        cell: cell,
        settings: const ChartSettings(source: ChartSource.cell),
      );
      expect(content.category, product);
      // text: largest first; and only EU's facts
      expect(content.data!.categories.map((c) => c.label), ['p1', 'p2']);
      expect(content.data!.series.single.values, [40, 20]);
      // the same as the engine's own drill-down
      final engine = ChartData.fromCell(
        cube.layout,
        cell,
        category: product,
        aggregate: amount,
      );
      expect(
        content.data!.series.single.values.reduce((a, b) => a! + b!),
        engine.series.single.values.reduce((a, b) => a! + b!),
      );
    });

    test('keeps the order of dates and numbers', () async {
      final facts = await _facts();
      final cube = _cube(facts);
      final us = cube.layout.cellFor(_group(region, 'US'), DimensionPath.root)!;
      final content = _content(
        cube,
        cell: us,
        settings: const ChartSettings(source: ChartSource.cell, category: year),
      );
      expect(content.data!.categories.map((c) => c.label), ['2023', '2024']);
      expect(content.data!.series.single.values, [40, 50]);
    });

    test('with a second breakdown as series', () async {
      final facts = await _facts();
      final cube = _cube(facts);
      final eu = cube.layout.cellFor(_group(region, 'EU'), DimensionPath.root)!;
      final data = _content(
        cube,
        cell: eu,
        settings: const ChartSettings(
          source: ChartSource.cell,
          category: product,
          series: year,
        ),
      ).data!;
      expect(data.series.map((s) => s.label), ['2023', '2024']);
      expect(data.categories.map((c) => c.label), ['p1', 'p2']);
      expect(data.series[0].values, [10, 20]);
      expect(data.series[1].values, [30, null]);
    });

    test('none current: all the facts, within the filter', () async {
      final facts = await _facts();
      final cube = _cube(
        facts,
        filter: NotFilter(ValueFilter(region, const ['Asia'])),
      );
      final content = _content(
        cube,
        settings: const ChartSettings(source: ChartSource.cell),
      );
      // the pivot's row is free while no cell pins it
      expect(content.category, region);
      expect(content.cell, isNull);
      expect(content.data!.categories.map((c) => c.label), ['US', 'EU']);
      expect(content.data!.series.single.values, [90, 60]);
    });

    test('that pins everything says so', () async {
      final facts = await _facts();
      final cube = _cube(facts);
      final eu = cube.layout.cellFor(_group(region, 'EU'), DimensionPath.root)!;
      expect(
        _content(
          cube,
          cell: eu,
          dimensions: const [region],
          settings: const ChartSettings(source: ChartSource.cell),
        ).problem,
        ChartProblem.noBreakdown,
      );
    });

    test('a chosen breakdown the cell pins gives way', () async {
      final facts = await _facts();
      final cube = _cube(facts, rows: [region, product]);
      final eu = cube.layout.cellFor(_group(region, 'EU'), DimensionPath.root)!;
      final content = _content(
        cube,
        cell: eu,
        settings: const ChartSettings(
          source: ChartSource.cell,
          category: region,
          series: region,
        ),
      );
      expect(content.category, product);
      expect(content.series, isNull);
    });
  });

  group('all data', () {
    test('by a dimension the pivot does not show', () async {
      final facts = await _facts();
      final cube = _cube(facts, columns: [year]);
      final content = _content(
        cube,
        settings: const ChartSettings(
          source: ChartSource.all,
          category: product,
        ),
      );
      expect(content.category, product);
      // text: largest first, over all the facts
      expect(content.data!.categories.map((c) => c.label), ['p2', 'p3', 'p1']);
      expect(content.data!.series.single.values, [60, 55, 40]);
    });

    test('starts from the pivot\'s first row dimension', () async {
      final facts = await _facts();
      final content = _content(
        _cube(facts, rows: [product, region]),
        settings: const ChartSettings(source: ChartSource.all),
      );
      expect(content.category, product);
    });

    test('whatever the current cell, within the filter', () async {
      final facts = await _facts();
      final cube = _cube(
        facts,
        filter: NotFilter(ValueFilter(region, const ['Asia'])),
      );
      final eu = cube.layout.cellFor(_group(region, 'EU'), DimensionPath.root)!;
      final content = _content(
        cube,
        cell: eu,
        settings: const ChartSettings(
          source: ChartSource.all,
          category: region,
          series: year,
        ),
      );
      // a cell pins nothing here: region stays, EU's facts are not alone
      expect(content.cell, isNull);
      expect(content.category, region);
      expect(content.series, year);
      final data = content.data!;
      expect(data.categories.map((c) => c.label), ['US', 'EU']);
      expect(data.series.map((s) => s.label), ['2023', '2024']);
      expect(data.series[0].values, [40, 30]);
      expect(data.series[1].values, [50, 30]);
    });

    test('ignores the pivot\'s swap', () async {
      final facts = await _facts();
      final content = _content(
        _cube(facts, columns: [year]),
        settings: const ChartSettings(
          source: ChartSource.all,
          transpose: true,
          category: product,
        ),
      );
      expect(content.data!.categories.map((c) => c.label), ['p2', 'p3', 'p1']);
      expect(content.data!.series, hasLength(1));
    });

    test('with no dimension at all says so', () async {
      final facts = await _facts();
      expect(
        _content(
          Cube(
            facts: facts,
            spec: CubeSpec(aggregates: [amount]),
          ),
          dimensions: const [],
          settings: const ChartSettings(source: ChartSource.all),
        ).problem,
        ChartProblem.noBreakdown,
      );
    });

    test('a scatter: one point per group', () async {
      final facts = await _facts();
      final content = _content(
        _cube(facts, aggregates: [amount, units]),
        settings: const ChartSettings(
          kind: ChartKind.scatter,
          source: ChartSource.all,
          category: product,
        ),
      );
      final points = content.scatter!.series.single.points;
      expect(
        {for (final p in points) p.label: (p.x, p.y)},
        {'p1': (40.0, 4.0), 'p2': (60.0, 6.0), 'p3': (55.0, 11.0)},
      );
    });
  });

  group('a scatter of records', () {
    const scatterOfRecords = ChartSettings(
      kind: ChartKind.scatter,
      source: ChartSource.all,
      records: true,
    );

    test('one dot per record, on the columns its aggregates read', () async {
      final facts = await _facts();
      final content = _content(
        _cube(facts, aggregates: [amount, units]),
        settings: scatterOfRecords,
      );
      expect(content.records, isTrue);
      expect(content.category, isNull);
      expect(content.xMeasure, const Measure('amount'));
      expect(content.yMeasure, const Measure('units'));
      final scatter = content.scatter!;
      expect(scatter.xLabel, 'amount');
      expect(
        [for (final p in scatter.points) (p.x, p.y)],
        [
          (10.0, 1.0),
          (20.0, 2.0),
          (30.0, 3.0),
          (40.0, 4.0),
          (50.0, 5.0),
          (5.0, 6.0),
        ],
      );
      expect(content.recordsShown, 6);
      expect(content.recordsTotal, 6);
    });

    test('with one aggregate, on two different columns', () async {
      final facts = await _facts();
      final content = _content(_cube(facts), settings: scatterOfRecords);
      // sum of amount is the only value: units, the next column, for y
      expect(content.problem, isNull);
      expect(content.xMeasure, const Measure('amount'));
      expect(content.yMeasure, isNot(const Measure('amount')));
    });

    test('the chosen columns, coloured by a dimension', () async {
      final facts = await _facts();
      final scatter = _content(
        _cube(facts),
        settings: scatterOfRecords.copyWith(
          xMeasure: const Measure('units'),
          yMeasure: const Measure('amount'),
          series: () => region,
        ),
      ).scatter!;
      expect(scatter.series.map((s) => s.label), ['Asia', 'EU', 'US']);
      expect(
        [for (final p in scatter.series[1].points) (p.x, p.y)],
        [(1.0, 10.0), (2.0, 20.0), (3.0, 30.0)],
      );
    });

    test('of the current cell: only its records', () async {
      final facts = await _facts();
      final cube = _cube(facts);
      final us = cube.layout.cellFor(_group(region, 'US'), DimensionPath.root)!;
      final content = _content(
        cube,
        cell: us,
        settings: const ChartSettings(
          kind: ChartKind.scatter,
          source: ChartSource.cell,
          records: true,
        ),
      );
      expect(content.scatter!.points.map((p) => p.x), [40, 50]);
    });

    test('within the filter', () async {
      final facts = await _facts();
      final content = _content(
        _cube(facts, filter: ValueFilter(region, const ['EU'])),
        settings: scatterOfRecords,
      );
      expect(content.scatter!.points.map((p) => p.x), [10, 20, 30]);
    });

    test('only from a breakdown: of the pivot, a dot per group', () async {
      final facts = await _facts();
      final content = _content(
        _cube(facts, aggregates: [amount, units]),
        settings: scatterOfRecords.copyWith(source: ChartSource.pivot),
      );
      expect(content.records, isFalse);
      expect(content.scatter!.points, hasLength(3));
    });

    test('needs two columns of numbers', () async {
      final source = CsvDataSource.fromData(
        Uint8List.fromList(utf8.encode('region,amount\nEU,1\nUS,2\n')),
        name: 'one.csv',
      );
      final facts = (await loadFacts(source)).facts;
      expect(
        _content(
          _cube(facts),
          dimensions: const [region],
          settings: scatterOfRecords,
        ).problem,
        ChartProblem.needsTwoMeasures,
      );
    });

    test('many are taken at even steps, and counted', () async {
      final facts = await _facts();
      final (:rows, :total) = sampleRecords(
        facts,
        x: const Measure('amount'),
        y: const Measure('units'),
        limit: 3,
      );
      expect(total, 6);
      expect(rows, [0, 2, 4]);
      final within = sampleRecords(
        facts,
        x: const Measure('amount'),
        y: const Measure('units'),
        filter: ValueFilter(region, const ['EU', 'US']),
        limit: 2,
      );
      // rows 0–4 pass
      expect(within.total, 5);
      expect(within.rows, [0, 2]);
    });
  });

  group('values shown as something else', () {
    test('chart in the pivot and in a cell\'s breakdown', () async {
      final facts = await _facts();
      final base = amount;
      final shown = <Aggregate>[
        PercentOfTotalAggregate(base, TotalOf.grand),
        RunningTotalAggregate(base, AxisSide.columns),
        RankAggregate(base, AxisSide.rows),
        DifferenceFromAggregate(base, AxisSide.columns, const PreviousItem()),
      ];
      for (final a in shown) {
        final cube = _cube(
          facts,
          rows: [region],
          columns: [year],
          aggregates: [base, a],
        );
        final eu = cube.layout.cellFor(
          _group(region, 'EU'),
          DimensionPath.root,
        )!;
        for (final kind in ChartKind.values) {
          final pivot = _content(
            cube,
            settings: ChartSettings(kind: kind, value: a, x: base, y: a),
          );
          expect(pivot.problem == null || kind == ChartKind.pie, isTrue);
          final cell = _content(
            cube,
            cell: eu,
            settings: ChartSettings(
              kind: kind,
              source: ChartSource.cell,
              value: a,
              x: base,
              y: a,
              category: product,
            ),
          );
          expect(
            cell.data != null || cell.scatter != null || cell.problem != null,
            isTrue,
            reason: '$a $kind',
          );
        }
      }
    });
  });

  group('a scatter chart', () {
    test('needs two values', () async {
      final facts = await _facts();
      expect(
        _content(
          _cube(facts),
          settings: const ChartSettings(kind: ChartKind.scatter),
        ).problem,
        ChartProblem.needsTwoValues,
      );
      // where single records would do, it says so
      expect(
        _content(
          _cube(facts),
          settings: const ChartSettings(
            kind: ChartKind.scatter,
            source: ChartSource.all,
          ),
        ).problem,
        ChartProblem.needsTwoValuesOrRecords,
      );
    });

    test('plots one against the other per group', () async {
      final facts = await _facts();
      final cube = _cube(facts, aggregates: [amount, units]);
      final content = _content(
        cube,
        settings: const ChartSettings(kind: ChartKind.scatter),
      );
      expect(content.x, amount);
      expect(content.y, units);
      final points = content.scatter!.points.toList();
      expect(points.map((p) => (p.label, p.x, p.y)), [
        ('Asia', 5.0, 6.0),
        ('EU', 60.0, 6.0),
        ('US', 90.0, 9.0),
      ]);
    });

    // Found on the owner's Mac, 2026-11-07: "Nothing to chart here".
    group('swapped', () {
      Map<String, List<(String, double, double)>> bySeries(ChartContent c) => {
        for (final s in c.scatter!.series)
          s.label: [for (final p in s.points) (p.label, p.x, p.y)],
      };

      test('has a point per column and a series per row', () async {
        final facts = await _facts();
        final cube = _cube(
          facts,
          columns: const [year],
          aggregates: [amount, units],
        );
        final content = _content(
          cube,
          settings: const ChartSettings(
            kind: ChartKind.scatter,
            transpose: true,
          ),
        );
        expect(content.problem, isNull);
        final series = bySeries(content);
        expect(series['EU'], [('2023', 30.0, 3.0), ('2024', 30.0, 3.0)]);
        expect(series['Asia'], [('2024', 5.0, 6.0)]);
      });

      test('without columns, every row is a series of one point', () async {
        final facts = await _facts();
        final cube = _cube(facts, aggregates: [amount, units]);
        final content = _content(
          cube,
          settings: const ChartSettings(
            kind: ChartKind.scatter,
            transpose: true,
          ),
        );
        expect(content.problem, isNull);
        final points = content.scatter!.points.map((p) => (p.x, p.y)).toSet();
        expect(points, containsAll({(5.0, 6.0), (60.0, 6.0), (90.0, 9.0)}));
      });
    });

    test('of the current cell plots its breakdown', () async {
      final facts = await _facts();
      final cube = _cube(facts, aggregates: [amount, units]);
      final eu = cube.layout.cellFor(_group(region, 'EU'), DimensionPath.root)!;
      final content = _content(
        cube,
        cell: eu,
        settings: const ChartSettings(
          kind: ChartKind.scatter,
          source: ChartSource.cell,
          category: product,
        ),
      );
      expect(content.scatter!.points.map((p) => (p.label, p.x, p.y)), [
        ('p1', 40.0, 4.0),
        ('p2', 20.0, 2.0),
      ]);
    });
  });

  group('axes', () {
    test('ticks are whole intervals that include zero', () {
      final range = AxisRange([3, 97], ticks: 5);
      expect(range.min, 0);
      expect(range.interval, 20);
      expect(range.max, 100);
      expect(range.ticks, [0, 20, 40, 60, 80, 100]);
    });

    test('an empty axis still has a range', () {
      final range = AxisRange(const []);
      expect(range.max, greaterThan(range.min));
    });

    test('numbers read short from five digits, if ticks stay apart', () {
      expect(axisNumbers(AxisRange([0, 900]), 'en')(200), '200');
      expect(axisNumbers(AxisRange([0, 8000]), 'en')(2000), '2,000');
      expect(axisNumbers(AxisRange([0, 90000]), 'en')(20000), '20K');
      expect(axisNumbers(AxisRange([0, 0.8]), 'en')(0.2), '0.2');
      // 100,020 and 100,040 would both read 100K
      final close = AxisRange([100000, 100100], includeZero: false);
      expect(axisNumbers(close, 'en')(100020), '100,020');
    });

    test('numbers follow the locale', () {
      expect(axisNumbers(AxisRange([0, 0.8]), 'hu')(0.2), '0,2');
      expect(axisNumbers(AxisRange([0, 8000]), 'de')(2000), '2.000');
    });

    test('short numbers exist in every language', () {
      for (final code in TesseraStrings.supportedLanguages) {
        final numbers = axisNumbers(AxisRange([0, 9000000]), code);
        expect(numbers(2000000), isNotEmpty, reason: code);
        expect(axisNumbers(AxisRange([0, 0.8]), code)(0.2), isNotEmpty);
      }
    });

    test('periods have whole positions and read as periods', () {
      const strings = TesseraStringsEn();
      String round(ChartPeriod period, DateTime date) =>
          periodLabel(period, periodPosition(period, date), strings);
      final d = DateTime.utc(2024, 4, 1);
      expect(round(ChartPeriod.year, d), '2024');
      expect(round(ChartPeriod.quarter, d), '2024 Q2');
      expect(round(ChartPeriod.month, d), '2024-04');
      expect(round(ChartPeriod.day, d), '2024-04-01');
      // ISO week 14 of 2024 starts on this Monday
      expect(round(ChartPeriod.week, d), '2024-04-01');
      expect(
        periodPosition(ChartPeriod.month, DateTime.utc(2025, 1, 1)) -
            periodPosition(ChartPeriod.month, DateTime.utc(2024, 12, 1)),
        1,
      );
    });

    test('a line chart picks its axis from the categories', () async {
      final facts = await _facts();
      final numeric = ChartData.fromLayout(_cube(facts, rows: [year]).layout);
      expect(LineAxis.of(numeric), isA<NumericAxis>());
      final names = ChartData.fromLayout(_cube(facts).layout);
      expect(LineAxis.of(names), isA<CategoryAxis>());

      final dated = (await loadFacts(
        CsvDataSource.fromData(
          Uint8List.fromList(
            utf8.encode(
              'day,amount\n2024-01-15,1\n2024-05-02,2\n2025-03-09,3\n',
            ),
          ),
          name: 'dated.csv',
        ),
      )).facts;
      const dayColumn = ColumnDimension('day');
      const years = DatePartDimension('day', DatePart.year);
      const months = DatePartDimension('day', DatePart.month);
      final byDay = ChartData.fromLayout(
        _cube(dated, rows: [dayColumn]).layout,
      );
      expect(
        LineAxis.of(byDay),
        isA<PeriodAxis>().having((a) => a.period, 'period', ChartPeriod.day),
      );
      final byYear = ChartData.fromLayout(_cube(dated, rows: [years]).layout);
      expect(
        LineAxis.of(byYear),
        isA<PeriodAxis>().having((a) => a.period, 'period', ChartPeriod.year),
      );
      // the months of no year in particular are names
      final byMonth = ChartData.fromLayout(_cube(dated, rows: [months]).layout);
      expect(LineAxis.of(byMonth), isA<CategoryAxis>());
      // half of it expanded: periods of two lengths have no one axis
      var mixed = _cube(dated, rows: [years, months]);
      mixed = mixed.toggleRow(_group(years, 2024));
      expect(
        LineAxis.of(ChartData.fromLayout(mixed.layout)),
        isA<CategoryAxis>(),
      );
    });
  });

  group('room for a scatter chart\'s dots', () {
    // the owner's Mac: 448,848 on an axis ending at 450K, half over its edge
    test('an axis does not end right at a value near a round number', () {
      final range = AxisRange(
        withDotRoom([183228, 231686, 273170, 448848], extent: 800, radius: 11),
        includeZero: false,
      );
      const hi = 448848.0;
      final pixels = (range.max - hi) / (range.max - range.min) * 800;
      expect(pixels, greaterThanOrEqualTo(11));
      expect(range.min, lessThan(183228));
    });

    test('plain values stay above zero', () {
      final range = AxisRange(
        withDotRoom([0, 50, 100], extent: 800, radius: 11),
        includeZero: false,
      );
      expect(range.min, 0);
      expect(range.max, greaterThan(100));
    });

    test('negative values get room below them', () {
      final range = AxisRange(
        withDotRoom([-100, 100], extent: 800, radius: 11),
        includeZero: false,
      );
      expect(range.min, lessThan(-100));
      expect(range.max, greaterThan(100));
    });

    test('a single point has room on both sides', () {
      final range = AxisRange(
        withDotRoom([100], extent: 800, radius: 11),
        includeZero: false,
      );
      expect(range.min, lessThan(100));
      expect(range.max, greaterThan(100));
    });
  });

  group('settings', () {
    test('every source survives the store; an unknown one is the pivot', () {
      for (final source in ChartSource.values) {
        final json = jsonDecode(jsonEncode(ChartSettings(source: source)));
        expect(
          ChartSettings.fromJson(json as Map<String, Object?>).source,
          source,
        );
      }
      expect(
        ChartSettings.fromJson(const {'source': 'later'}).source,
        ChartSource.pivot,
      );
    });

    test('survive the store', () async {
      final settings = ChartSettings(
        kind: ChartKind.scatter,
        source: ChartSource.cell,
        transpose: true,
        value: amount,
        x: amount,
        y: units,
        category: product,
        series: const DatePartDimension('date', DatePart.quarter),
        records: true,
        xMeasure: const Measure('amount'),
        yMeasure: Measure.expression('amount / units', label: 'price'),
      );
      final json = jsonDecode(
        jsonEncode(StoredChart(visible: true, settings: settings).toJson()),
      );
      final back = StoredChart.fromJson((json as Map).cast());
      expect(back.visible, isTrue);
      expect(back.settings.kind, ChartKind.scatter);
      expect(back.settings.source, ChartSource.cell);
      expect(back.settings.transpose, isTrue);
      expect(back.settings.value, amount);
      expect(back.settings.x, amount);
      expect(back.settings.y, units);
      expect(back.settings.category, product);
      expect(back.settings.series, settings.series);
      expect(back.settings.records, isTrue);
      expect(back.settings.xMeasure, const Measure('amount'));
      expect(back.settings.yMeasure, settings.yMeasure);
    });

    test('the defaults stay small, and an unknown kind is the default', () {
      expect(const ChartSettings().toJson(), {
        'kind': 'bar',
        'source': 'pivot',
      });
      final back = ChartSettings.fromJson({'kind': 'radar', 'source': '?'});
      expect(back.kind, ChartKind.bar);
      expect(back.source, ChartSource.pivot);
    });

    test('copyWith clears the series only when asked', () {
      const start = ChartSettings(series: year);
      expect(start.copyWith(kind: ChartKind.line).series, year);
      expect(start.copyWith(series: () => null).series, isNull);
    });

    test('the memory store keeps charts apart from layouts', () async {
      final store = MemoryLayoutStore();
      await store.writeChart(
        'k',
        const StoredChart(visible: true, settings: ChartSettings()),
      );
      expect(store.entries, isEmpty);
      expect((await store.readChart('k'))?.visible, isTrue);
      await store.deleteChart('k');
      expect(await store.readChart('k'), isNull);
    });
  });
}
