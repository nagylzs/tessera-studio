import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_studio/export/export_format.dart';
import 'package:tessera_studio/export/exports.dart';
import 'package:tessera_studio/style/grid_style.dart';

// Hungarian, Cyrillic and CJK labels: the PDF font covers the first two
// and must not fail on the third.
const csv =
    'region,product,amount\n'
    'Észak,ő termék,10\n'
    'Юг,p2,20\n'
    '東京,p3,5\n'
    'Észak,p2,1\n';

Future<Cube> _cube({FactFilter? filter}) async {
  final source = CsvDataSource.fromData(
    Uint8List.fromList(utf8.encode(csv)),
    name: 'sales.csv',
  );
  final result = await loadFacts(source);
  return Cube(
    facts: result.facts,
    spec: CubeSpec(
      rows: CubeAxis.of([ColumnDimension('region')]),
      aggregates: [Aggregate.count, Aggregate.sum(ColumnMeasure('amount'))],
      filter: filter,
    ),
  );
}

String _text(Uint8List bytes) => utf8.decode(bytes);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // rootBundle: PDF fonts

  test('the cube exports in every format', () async {
    final cube = await _cube();
    Future<Uint8List> export(ExportFormat f) =>
        cubeExport(cube, f, title: 'sales', strings: const TesseraStringsEn());

    for (final f in [ExportFormat.xlsx, ExportFormat.ods]) {
      expect(ascii.decode((await export(f)).sublist(0, 2)), 'PK', reason: '$f');
    }
    final pdf = await export(ExportFormat.pdf);
    expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(_text(await export(ExportFormat.html)), contains('Észak'));
    final svg = _text(await export(ExportFormat.svg));
    expect(svg, contains('<svg'));
    expect(svg, contains('Юг'));
    final csvBytes = await export(ExportFormat.csv);
    expect(csvBytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]); // BOM, for Excel
    expect(_text(csvBytes), contains('東京'));
    final records = jsonDecode(_text(await export(ExportFormat.json))) as List;
    expect(records, hasLength(4)); // three regions and the total
    final lines = _text(await export(ExportFormat.jsonl)).trim().split('\n');
    expect(lines.map(jsonDecode), hasLength(4));
  });

  test('the exports take the grid style\'s export theme', () async {
    final cube = await _cube();
    Future<String> html(GridStyle style) async => _text(
      await cubeExport(
        cube,
        ExportFormat.html,
        title: 'sales',
        strings: const TesseraStringsEn(),
        style: style,
      ),
    );
    expect((await html(GridStyle.standard)).toLowerCase(), contains('00856e'));
    expect(await html(GridStyle.spreadsheet), contains('Courier New'));
    expect(await html(GridStyle.standard), isNot(contains('Courier New')));
  });

  test('the cube exports only the aggregates shown', () async {
    final cube = await _cube();
    Future<Map<String, Object?>> firstRecord(
      List<Aggregate>? aggregates,
    ) async {
      final bytes = await cubeExport(
        cube,
        ExportFormat.json,
        title: 'sales',
        strings: const TesseraStringsEn(),
        aggregates: aggregates,
      );
      return ((jsonDecode(_text(bytes)) as List).first as Map).cast();
    }

    final all = await firstRecord(null);
    final countOnly = await firstRecord([Aggregate.count]);
    expect(countOnly.length, all.length - 1);
  });

  test('the facts export as a table, filtered like the cube', () async {
    final cube = await _cube(filter: ExpressionFilter('amount > 6'));
    for (final f in [ExportFormat.xlsx, ExportFormat.ods]) {
      final bytes = factsExport(cube, f, title: 'sales');
      expect(ascii.decode(bytes.sublist(0, 2)), 'PK', reason: '$f');
    }
    final csvLines = _text(factsExport(cube, ExportFormat.csv, title: 'sales'))
        .trim()
        .split(RegExp(r'\r?\n'));
    expect(csvLines, hasLength(3)); // header + the two rows above 6
    expect(csvLines.first, contains('region'));
    final lines = _text(factsExport(cube, ExportFormat.jsonl, title: 'sales'))
        .trim()
        .split('\n');
    expect(lines.map((l) => (jsonDecode(l) as Map)['region']), ['Észak', 'Юг']);
    expect(
      () => factsExport(cube, ExportFormat.pdf, title: 'sales'),
      throwsArgumentError,
    );
  });
}
