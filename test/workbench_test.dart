import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
import 'package:tessera_studio/platform/system_bars.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/cube_state.dart';
import 'package:tessera_studio/state/schema_store.dart';
import 'package:tessera_studio/state/settings.dart';
import 'package:tessera_studio/widgets/editors_panel.dart';

import 'fakes.dart';

const csv = 'region,product,amount\nEU,p1,10\nUS,p2,20\nEU,p2,5\n';

/// Picks [name] with [text]; a test may change both to open another file.
final class _Opener implements FileOpener {
  String name = 'sales.csv';
  String text = csv;

  @override
  Future<OpenedDocument?> pick() async => OpenedDocument(
    name: name,
    format: FileFormat.csv,
    bytes: Uint8List.fromList(text.codeUnits),
  );
}

late _Opener _opener;
late MemorySettingsStore settingsStore;
late FakeSystemBars bars;

void _register() {
  _opener = _Opener();
  settingsStore = MemorySettingsStore();
  bars = FakeSystemBars();
  GetIt.I
    ..registerSingleton<SystemBars>(bars)
    ..registerSingleton<FileOpener>(_opener)
    ..registerSingleton<ClipboardReader>(FakeClipboard())
    ..registerSingleton<DocumentLoader>(FakeLoader())
    ..registerSingleton<SchemaStore>(MemorySchemaStore())
    ..registerSingleton<AppSettings>(AppSettings(settingsStore))
    ..registerSingleton<AppState>(AppState());
}

Future<void> _tapAndWait(WidgetTester tester, Finder finder) =>
    _doAndWait(tester, () => tester.tap(finder));

/// Runs [action] for real (inference and import do not advance on the
/// fake clock) and waits until the app is no longer busy.
Future<void> _doAndWait(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  final state = GetIt.I<AppState>();
  await tester.runAsync(() async {
    await action();
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

  testWidgets('a tap on a value toggles full screen in the narrow layout', (
    tester,
  ) async {
    _size(tester, 400, 800);
    _register();
    await _toCube(tester);
    // counts by region: EU 2, US 1, total 3
    Finder value(String text) =>
        find.descendant(of: find.byType(CubeView), matching: find.text(text));
    expect(find.byType(AppBar), findsOneWidget);

    await tester.tap(value('2'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(bars.calls, ['hide']);

    await tester.tap(value('1'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(bars.calls, ['hide', 'show']);

    // back leaves full screen and keeps the file open
    await tester.tap(value('2'));
    await tester.pumpAndSettle();
    expect(bars.hidden, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(WorkbenchPage), findsOneWidget);
    expect(bars.hidden, isFalse);

    // a mouse click only selects
    await tester.tap(value('3'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(bars.calls, hasLength(4));

    // closing the file in full screen brings the bars back
    await tester.tap(value('2'));
    await tester.pumpAndSettle();
    expect(bars.hidden, isTrue);
    GetIt.I<AppState>().closeFile();
    await tester.pumpAndSettle();
    expect(find.byType(WorkbenchPage), findsNothing);
    expect(bars.hidden, isFalse);
  });

  testWidgets('a tap on a value only selects with the editors on top', (
    tester,
  ) async {
    _size(tester, 1400, 900);
    _register();
    await _toCube(tester);
    await tester.tap(
      find.descendant(of: find.byType(CubeView), matching: find.text('2')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.textContaining('Current cell'), findsOneWidget);
    expect(bars.calls, isEmpty);
  });

  testWidgets('a file opened over another starts from its own default cube', (
    tester,
  ) async {
    _size(tester, 1400, 900);
    _register();
    await _toCube(tester);
    expect(find.text('region'), findsWidgets);

    _opener
      ..name = 'cities.csv'
      ..text = 'city,amount\nA,1\nB,2\nC,3\n';
    await _doAndWait(tester, () async {
      unawaited(GetIt.I<AppState>().openFile());
    });
    await _tapAndWait(tester, find.widgetWithText(FilledButton, 'Continue'));
    expect(find.text('cities.csv'), findsOneWidget);
    Finder value(String text) =>
        find.descendant(of: find.byType(CubeView), matching: find.text(text));
    // rows on city, not the previous file's region pruned to nothing
    expect(value('A'), findsOneWidget);
    expect(value('C'), findsOneWidget);
  });

  test('the layout resolves by window size only when automatic', () {
    const auto = CubePageLayout.auto;
    expect(auto.resolve(const Size(839, 900)), CubePageLayout.cubeOnly);
    expect(auto.resolve(const Size(840, 480)), CubePageLayout.editors);
    // a phone in landscape: wide enough, too low
    expect(auto.resolve(const Size(914, 411)), CubePageLayout.cubeOnly);
    expect(auto.resolve(const Size(1280, 479)), CubePageLayout.cubeOnly);
    expect(
      CubePageLayout.editors.resolve(const Size(300, 300)),
      CubePageLayout.editors,
    );
    expect(
      CubePageLayout.cubeOnly.resolve(const Size(2000, 1200)),
      CubePageLayout.cubeOnly,
    );
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
