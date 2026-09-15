import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/pages/workbench_page.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/cube_state.dart';
import 'package:tessera_studio/state/schema_store.dart';
import 'package:tessera_studio/state/settings.dart';
import 'package:tessera_studio/widgets/editors_panel.dart';

import 'fakes.dart';

const csv = 'region,product,amount\nEU,p1,10\nUS,p2,20\nEU,p2,5\n';

final class _Opener implements FileOpener {
  @override
  Future<OpenedDocument?> pick() async => OpenedDocument(
    name: 'sales.csv',
    format: FileFormat.csv,
    bytes: Uint8List.fromList(csv.codeUnits),
  );
}

late MemorySettingsStore settingsStore;

void _register() {
  settingsStore = MemorySettingsStore();
  GetIt.I
    ..registerSingleton<FileOpener>(_Opener())
    ..registerSingleton<ClipboardReader>(FakeClipboard())
    ..registerSingleton<DocumentLoader>(FakeLoader())
    ..registerSingleton<SchemaStore>(MemorySchemaStore())
    ..registerSingleton<AppSettings>(AppSettings(settingsStore))
    ..registerSingleton<AppState>(AppState());
}

Future<void> _tapAndWait(WidgetTester tester, Finder finder) async {
  final state = GetIt.I<AppState>();
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

/// Opens sales.csv and accepts the inferred schema.
Future<void> _toCube(WidgetTester tester) async {
  await tester.pumpWidget(const TesseraStudioApp());
  await _tapAndWait(tester, find.widgetWithText(FilledButton, 'Open file…'));
  // Wide bars have a labelled button, narrow ones an icon with a tooltip.
  final labelled = find.widgetWithText(FilledButton, 'Continue');
  await _tapAndWait(
    tester,
    labelled.evaluate().isEmpty ? find.byTooltip('Continue') : labelled,
  );
  expect(find.byType(WorkbenchPage), findsOneWidget);
  expect(find.byType(CubeView), findsOneWidget);
}

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => GetIt.I.reset());

  testWidgets('a wide window imports and shows the editors inline', (
    tester,
  ) async {
    _size(tester, 1400, 900);
    _register();
    await _toCube(tester);
    expect(find.byType(EditorsPanel), findsOneWidget);
    expect(find.byType(AxisEditor), findsNWidgets(2));
    expect(find.byType(CurrentCellLine), findsOneWidget);
    expect(find.textContaining('3 records, 3 columns'), findsOneWidget);
    expect(find.byTooltip('Filter…'), findsOneWidget);
    expect(find.byTooltip('Editors'), findsNothing);
    // rows on the lowest-cardinality text column: region (EU, US)
    expect(find.text('EU'), findsOneWidget);
    expect(find.text('US'), findsOneWidget);

    await tester.tap(find.textContaining('tap for the import report'));
    await tester.pumpAndSettle();
    expect(find.text('Import report'), findsOneWidget);
    expect(find.text('3 rows imported'), findsOneWidget);
  });

  testWidgets('a narrow window shows the cube alone; the sheet holds the '
      'editors; the menu switches layouts', (tester) async {
    _size(tester, 400, 800);
    _register();
    await _toCube(tester);
    expect(find.byType(EditorsPanel), findsNothing);
    expect(find.byType(AxisEditor), findsNothing);
    expect(find.byTooltip('Filter…'), findsNothing);

    await tester.tap(find.byTooltip('Editors'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AxisEditor), findsNWidgets(2));
    expect(find.byType(CurrentCellLine), findsOneWidget);
    await tester.tapAt(const Offset(200, 20)); // dismiss
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editors on top'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorsPanel), findsOneWidget);
    expect(settingsStore.cubeLayout, 'editors');
    expect(GetIt.I<AppSettings>().cubeLayout.value, CubePageLayout.editors);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editors on top'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorsPanel), findsNothing);
    expect(settingsStore.cubeLayout, 'cubeOnly');
  });

  test('the layout resolves by width only when automatic', () {
    expect(CubePageLayout.auto.resolve(839), CubePageLayout.cubeOnly);
    expect(CubePageLayout.auto.resolve(840), CubePageLayout.editors);
    expect(CubePageLayout.editors.resolve(300), CubePageLayout.editors);
    expect(CubePageLayout.cubeOnly.resolve(2000), CubePageLayout.cubeOnly);
  });

  test('sameExceptLabels ignores labels only', () {
    const a = ColumnSpec(name: 'x', type: ColumnType.text);
    expect(
      CubeState.sameExceptLabels(Schema([a]), Schema([a.copyWith(label: 'X')])),
      isTrue,
    );
    expect(
      CubeState.sameExceptLabels(
        Schema([a]),
        Schema([a.copyWith(type: ColumnType.integer)]),
      ),
      isFalse,
    );
    expect(
      CubeState.sameExceptLabels(
        Schema([a]),
        Schema([a.copyWith(include: false)]),
      ),
      isFalse,
    );
  });
}
