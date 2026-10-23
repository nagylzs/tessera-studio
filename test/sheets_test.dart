import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/export/export_target.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_failure.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/pages/schema_page.dart';
import 'package:tessera_studio/pages/workbench_page.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/layout_store.dart';
import 'package:tessera_studio/state/schema_store.dart';
import 'package:tessera_studio/state/settings.dart';

import 'fakes.dart';

typedef Rows = List<List<Object>>;

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// An .xlsx workbook of [sheets] (name → rows of strings and numbers),
/// with [hidden] sheets, saved on the sheet at [activeTab].
Uint8List xlsx(
  Map<String, Rows> sheets, {
  Set<String> hidden = const {},
  int activeTab = 0,
}) {
  const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  final archive = Archive();
  void add(String path, String xml) =>
      archive.add(ArchiveFile.bytes(path, utf8.encode(xml)));
  final names = sheets.keys.toList();
  add(
    'xl/workbook.xml',
    '<workbook xmlns="$ns" xmlns:r="$rel">'
        '<bookViews><workbookView activeTab="$activeTab"/></bookViews><sheets>'
        '${[for (final (i, n) in names.indexed) '<sheet name="$n" sheetId="${i + 1}"${hidden.contains(n) ? ' state="hidden"' : ''} r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 0; i < names.length; i++) '<Relationship Id="rId${i + 1}" Type="$rel/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
        '</Relationships>',
  );
  for (final (i, rows) in sheets.values.indexed) {
    final data = StringBuffer();
    for (final (r, row) in rows.indexed) {
      data.write('<row r="${r + 1}">');
      for (final (c, v) in row.indexed) {
        final ref = '${String.fromCharCode(0x41 + c)}${r + 1}';
        data.write(
          v is num
              ? '<c r="$ref"><v>$v</v></c>'
              : '<c r="$ref" t="inlineStr"><is><t>${_escape('$v')}</t></is></c>',
        );
      }
      data.write('</row>');
    }
    add(
      'xl/worksheets/sheet${i + 1}.xml',
      '<worksheet xmlns="$ns"><sheetData>$data</sheetData></worksheet>',
    );
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

/// An .ods document of [sheets], saved on the sheet named [active].
Uint8List ods(Map<String, Rows> sheets, {String? active}) {
  final archive = Archive()
    ..add(
      ArchiveFile.bytes(
        'mimetype',
        utf8.encode('application/vnd.oasis.opendocument.spreadsheet'),
      )..compression = CompressionType.none,
    );
  final body = StringBuffer();
  for (final MapEntry(key: name, value: rows) in sheets.entries) {
    body.write('<table:table table:name="$name">');
    for (final row in rows) {
      body.write('<table:table-row>');
      for (final v in row) {
        body.write(
          v is num
              ? '<table:table-cell office:value-type="float" office:value="$v"><text:p>$v</text:p></table:table-cell>'
              : '<table:table-cell office:value-type="string"><text:p>${_escape('$v')}</text:p></table:table-cell>',
        );
      }
      body.write('</table:table-row>');
    }
    body.write('</table:table>');
  }
  archive.add(
    ArchiveFile.bytes(
      'content.xml',
      utf8.encode(
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">'
        '<office:body><office:spreadsheet>$body</office:spreadsheet>'
        '</office:body></office:document-content>',
      ),
    ),
  );
  if (active != null) {
    archive.add(
      ArchiveFile.bytes(
        'settings.xml',
        utf8.encode(
          '<office:document-settings '
          'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
          'xmlns:config="urn:oasis:names:tc:opendocument:xmlns:config:1.0">'
          '<office:settings><config:config-item-set config:name="ooo:view-settings">'
          '<config:config-item-map-indexed config:name="Views"><config:config-item-map-entry>'
          '<config:config-item config:name="ActiveTable" config:type="string">$active</config:config-item>'
          '</config:config-item-map-entry></config:config-item-map-indexed>'
          '</config:config-item-set></office:settings></office:document-settings>',
        ),
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

/// A README sheet, a data sheet, a hidden one and an empty one.
final Map<String, Rows> book = {
  'Readme': [
    ['Item', 'Details'],
    ['Units', 'µg/g'],
  ],
  'Data': [
    ['region', 'amount'],
    ['EU', 1],
    ['US', 2],
  ],
  'Lookup': [
    ['code'],
    ['x'],
  ],
  'Empty': [],
};

final class _Opener implements FileOpener {
  _Opener(this.name, this.bytes);

  final String name;
  final Uint8List bytes;

  @override
  Future<OpenedDocument?> pick({String? dialogTitle}) async =>
      OpenedDocument.detect(name: name, bytes: bytes);
}

late MemorySchemaStore store;

AppState _register(String name, Uint8List bytes) {
  store = MemorySchemaStore();
  final state = AppState();
  GetIt.I
    ..registerSingleton<FileOpener>(_Opener(name, bytes))
    ..registerSingleton<ClipboardReader>(FakeClipboard())
    ..registerSingleton<DocumentLoader>(const IoDocumentLoader())
    ..registerSingleton<SchemaStore>(store)
    ..registerSingleton<LayoutStore>(MemoryLayoutStore())
    ..registerSingleton<AppSettings>(AppSettings(MemorySettingsStore()))
    ..registerSingleton<ExportTarget>(FakeExportTarget())
    ..registerSingleton<AppState>(state);
  return state;
}

/// Waits for the import a known structure starts.
Future<void> _settle(AppState state) async {
  for (var i = 0; i < 500 && state.busy.value; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() => GetIt.I.reset());

  group('opening a workbook', () {
    test('shows the sheet it was saved on; offers the visible sheets with '
        'values', () async {
      final state = _register(
        'book.xlsx',
        xlsx(book, hidden: {'Lookup'}, activeTab: 1),
      );
      expect(await state.openFile(), isNull);
      final doc = state.document.value!;
      expect(doc.sheet, 'Data');
      expect(doc.sheets, ['Readme', 'Data']);
      expect(state.source.value!.columnNames, ['region', 'amount']);
      expect(state.page.value, AppPage.schema);
      expect(doc.title, 'book.xlsx - Data');
      expect(doc.exportBaseName, 'book - Data');
    });

    test('an empty or hidden saved sheet: the first one with values', () async {
      for (final tab in [2, 3]) {
        await GetIt.I.reset();
        final state = _register(
          'book.xlsx',
          xlsx(book, hidden: {'Lookup'}, activeTab: tab),
        );
        expect(await state.openFile(), isNull);
        expect(state.failure.value, isNull);
        expect(state.document.value!.sheet, 'Readme');
      }
    });

    test('a heading without rows gives way to the next sheet', () async {
      final state = _register(
        'report.xlsx',
        xlsx({
          'Cover': [
            ['Report 2026'],
          ],
          ...book,
        }),
      );
      await state.openFile();
      expect(state.failure.value, isNull);
      expect(state.document.value!.sheet, 'Readme');
      // still offered: choosing it says why it cannot be shown
      expect(state.document.value!.sheets, [
        'Cover',
        'Readme',
        'Data',
        'Lookup',
      ]);
      await state.openSheet('Cover');
      expect(state.failure.value!.kind, FailureKind.noRows);
      expect(state.failure.value!.fileName, 'report.xlsx - Cover');
      state.dismissFailure();
      expect(state.document.value!.sheet, 'Readme');
    });

    test('nothing to show: fails like an empty file', () async {
      final state = _register('empty.xlsx', xlsx({'A': [], 'B': []}));
      await state.openFile();
      expect(state.document.value, isNull);
      expect(state.failure.value!.kind, FailureKind.empty);
    });

    test('one sheet: no choice, plain names', () async {
      final state = _register(
        'data.xlsx',
        xlsx({'Data': book['Data']!, 'Empty': []}, activeTab: 1),
      );
      await state.openFile();
      final doc = state.document.value!;
      expect(doc.sheet, 'Data');
      expect(doc.sheets, ['Data']);
      expect(doc.title, 'data.xlsx');
      expect(doc.exportBaseName, 'data');
    });

    test('an OpenDocument spreadsheet too', () async {
      final state = _register('book.ods', ods(book, active: 'Lookup'));
      await state.openFile();
      final doc = state.document.value!;
      expect(doc.format, FileFormat.ods);
      expect(doc.sheet, 'Lookup');
      expect(doc.sheets, ['Readme', 'Data', 'Lookup']);
      expect(state.source.value!.columnNames, ['code']);
    });
  });

  test('switching sheets: each has its own schema and pivot', () async {
    final state = _register('book.xlsx', xlsx(book, activeTab: 1));
    await state.openFile();
    final data = state.source.value!.inferred;
    await state.acceptSchema(
      data.replace(data['region']!.copyWith(label: 'Region')),
    );
    await _settle(state);
    expect(state.page.value, AppPage.workbench);

    await state.openSheet('Readme');
    expect(state.document.value!.sheet, 'Readme');
    expect(state.document.value!.sheets, ['Readme', 'Data', 'Lookup']);
    expect(state.source.value!.columnNames, ['Item', 'Details']);
    expect(state.page.value, AppPage.schema);

    // back to Data: its schema was stored, so straight to the workbench
    await state.openSheet('Data');
    await _settle(state);
    expect(state.page.value, AppPage.workbench);
    expect(state.schema.value!['region']!.label, 'Region');
    expect(state.restored.value, isNotNull);
    expect(state.cube.result.value!.facts.rowCount, 2);
  });

  testWidgets('the title lists the sheets and switches', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = _register('book.xlsx', xlsx(book, activeTab: 1));
    await tester.pumpWidget(const TesseraStudioApp());

    Future<void> tapAndWait(Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        for (var i = 0; i < 500 && state.busy.value; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
    }

    await tapAndWait(find.widgetWithText(FilledButton, 'Open file…'));
    expect(find.byType(SchemaPage), findsOneWidget);
    expect(find.text('book.xlsx'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose sheet'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<String>), findsNWidgets(3));
    await tapAndWait(find.text('Readme'));
    expect(state.document.value!.sheet, 'Readme');
    expect(find.text('Readme'), findsOneWidget);
    expect(find.text('Item'), findsWidgets);
    expect(find.text('region'), findsNothing); // not the last sheet's page

    await tapAndWait(find.widgetWithText(FilledButton, 'Continue'));
    expect(find.byType(WorkbenchPage), findsOneWidget);
    expect(find.byTooltip('Choose sheet'), findsOneWidget);
  });

  testWidgets('a single sheet has a plain title', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = _register('data.xlsx', xlsx({'Data': book['Data']!}));
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.runAsync(() async {
      await state.openFile();
    });
    await tester.pumpAndSettle();
    expect(find.byType(SchemaPage), findsOneWidget);
    expect(find.byTooltip('Choose sheet'), findsNothing);
  });
}
