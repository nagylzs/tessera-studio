import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/charts/chart_panel.dart';
import 'package:tessera_studio/charts/chart_settings.dart';
import 'package:tessera_studio/export/export_target.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/pages/workbench_page.dart';
import 'package:tessera_studio/platform/system_bars.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/layout_store.dart';
import 'package:tessera_studio/state/schema_store.dart';
import 'package:tessera_studio/state/settings.dart';
import 'package:tessera_studio/widgets/split_view.dart';

import 'fakes.dart';

const _csv =
    'region,product,amount,units\n'
    'EU,p1,10,1\n'
    'US,p2,20,2\n'
    'EU,p2,5,3\n';

final class _Opener implements FileOpener {
  @override
  Future<OpenedDocument?> pick({String? dialogTitle}) async => OpenedDocument(
    name: 'sales.csv',
    format: FileFormat.csv,
    bytes: Uint8List.fromList(_csv.codeUnits),
  );
}

late MemoryLayoutStore _layouts;
late MemorySettingsStore _settings;
late FakeSystemBars _bars;
late FakeExportTarget _exports;

void _register() {
  _exports = FakeExportTarget();
  _settings = MemorySettingsStore();
  _bars = FakeSystemBars();
  GetIt.I
    ..registerSingleton<SystemBars>(_bars)
    ..registerSingleton<ExportTarget>(_exports)
    ..registerSingleton<FileOpener>(_Opener())
    ..registerSingleton<ClipboardReader>(FakeClipboard())
    ..registerSingleton<DocumentLoader>(FakeLoader())
    ..registerSingleton<SchemaStore>(MemorySchemaStore())
    ..registerSingleton<LayoutStore>(_layouts = MemoryLayoutStore())
    ..registerSingleton<AppSettings>(AppSettings(_settings))
    ..registerSingleton<AppState>(AppState());
}

AppState get _state => GetIt.I<AppState>();

/// Runs [action] for real (inference and import do not advance on the
/// fake clock) and waits until the app is no longer busy.
Future<void> _doAndWait(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  await tester.runAsync(() async {
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (var i = 0; i < 500 && _state.busy.value; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _toCube(WidgetTester tester) async {
  await tester.pumpWidget(const TesseraStudioApp());
  await _doAndWait(
    tester,
    () => tester.tap(find.widgetWithText(FilledButton, 'Open file…')),
  );
  final labelled = find.widgetWithText(FilledButton, 'Continue');
  await _doAndWait(
    tester,
    () => tester.tap(
      labelled.evaluate().isEmpty ? find.byTooltip('Continue') : labelled,
    ),
  );
  expect(find.byType(WorkbenchPage), findsOneWidget);
  expect(find.byType(CubeView), findsOneWidget);
}

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _tapTooltip(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

Future<void> _showChart(WidgetTester tester) =>
    _tapTooltip(tester, 'Show chart');

/// The system back button.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Taps the grid's value [text]; a finger unless told otherwise.
Future<void> _tapValue(
  WidgetTester tester,
  String text, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  await tester.tap(
    find.descendant(of: find.byType(CubeView), matching: find.text(text)).first,
    kind: kind,
  );
  // past the delay that tells a tap from a double tap, and the chart's own
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => GetIt.I.reset());

  testWidgets('a file opens on its pivot; the chart comes when asked', (
    tester,
  ) async {
    _size(tester, 1400, 900);
    _register();
    await _toCube(tester);
    expect(find.byType(ChartPanel), findsNothing);
    await _showChart(tester);
    expect(find.byType(ChartPanel), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(CubeView), findsOneWidget);
    await _tapTooltip(tester, 'Hide chart');
    expect(find.byType(ChartPanel), findsNothing);
    expect(find.byType(CubeView), findsOneWidget);
    expect(find.byTooltip('Show chart'), findsOneWidget);
  });

  testWidgets('on a desktop the chart sits beside the grid', (tester) async {
    _size(tester, 1400, 900);
    _register();
    await _toCube(tester);
    await _showChart(tester);
    final split = tester.widget<SplitView>(find.byType(SplitView));
    expect(split.axis, Axis.horizontal);
    expect(
      tester.getCenter(find.byType(CubeView)).dx,
      lessThan(tester.getCenter(find.byType(ChartPanel)).dx),
    );
    // and the same in the grid-only layout
    final settings = GetIt.I<AppSettings>();
    await settings.setCubeLayout(CubePageLayout.cubeOnly);
    await tester.pumpAndSettle();
    expect(find.byType(SplitView), findsOneWidget);
  });

  testWidgets('on a tablet in portrait it sits above the grid', (tester) async {
    _size(tester, 800, 1280);
    _register();
    await _toCube(tester);
    await _showChart(tester);
    final split = tester.widget<SplitView>(find.byType(SplitView));
    expect(split.axis, Axis.vertical);
    expect(
      tester.getCenter(find.byType(ChartPanel)).dy,
      lessThan(tester.getCenter(find.byType(CubeView)).dy),
    );
  });

  testWidgets('the divider moves and is remembered', (tester) async {
    _size(tester, 1400, 900);
    _register();
    await _toCube(tester);
    await _showChart(tester);
    final before = tester.getSize(find.byType(CubeView)).width;
    // the divider sits just left of the chart
    Future<void> drag(double dx) async {
      final panel = find.byType(ChartPanel);
      await tester.dragFrom(
        Offset(tester.getTopLeft(panel).dx - 8, tester.getCenter(panel).dy),
        Offset(dx, 0),
      );
      await tester.pumpAndSettle();
    }

    await drag(150);
    expect(tester.getSize(find.byType(CubeView)).width, greaterThan(before));
    expect(_settings.chartSplit, greaterThan(0.5));
    final moved = _settings.chartSplit!;

    // neither pane can be pushed off
    await drag(2000);
    expect(
      tester.getSize(find.byType(ChartPanel)).width,
      greaterThanOrEqualTo(200),
    );
    expect(_settings.chartSplit, greaterThan(moved));
  });

  group('on a phone', () {
    testWidgets('the chart takes the grid\'s place, and back returns', (
      tester,
    ) async {
      _size(tester, 400, 800);
      _register();
      await _toCube(tester);
      await _showChart(tester);
      expect(find.byType(SplitView), findsNothing);
      expect(find.byType(BarChart), findsOneWidget);
      // the grid waits offstage, its scroll position intact
      expect(find.byType(CubeView), findsNothing);
      expect(find.byType(CubeView, skipOffstage: false), findsOneWidget);
      // the button says where it goes
      expect(find.byTooltip('Show pivot table'), findsOneWidget);
      await _tapTooltip(tester, 'Show pivot table');
      expect(find.byType(ChartPanel), findsNothing);
      expect(find.byType(CubeView), findsOneWidget);

      await _showChart(tester);
      await _back(tester);
      // back left the chart, not the file
      expect(find.byType(WorkbenchPage), findsOneWidget);
      expect(find.byType(ChartPanel), findsNothing);
      expect(find.byType(CubeView), findsOneWidget);
      await _back(tester);
      expect(find.byType(WorkbenchPage), findsNothing);
    });

    testWidgets('in landscape too, with one row of controls', (tester) async {
      _size(tester, 800, 360);
      _register();
      await _toCube(tester);
      await _showChart(tester);
      expect(find.byType(SplitView), findsNothing);
      expect(find.byType(BarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
      // the chart has most of the height
      expect(tester.getSize(find.byType(BarChart)).height, greaterThan(100));
    });

    testWidgets('the chart can fill the screen; back returns to its page', (
      tester,
    ) async {
      _size(tester, 400, 800);
      _register();
      await _toCube(tester);
      await _showChart(tester);
      await _tapTooltip(tester, 'Full screen');
      expect(find.byType(AppBar), findsNothing);
      expect(_bars.hidden, isTrue);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(SegmentedButton<ChartKind>), findsNothing);
      await _tapTooltip(tester, 'Exit full screen');
      expect(find.byType(AppBar), findsOneWidget);
      expect(_bars.hidden, isFalse);

      await _tapTooltip(tester, 'Full screen');
      await _back(tester);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(_bars.hidden, isFalse);
    });

    testWidgets('a tap on a value still goes full screen in the grid', (
      tester,
    ) async {
      _size(tester, 400, 800);
      _register();
      await _toCube(tester);
      await _tapValue(tester, '2');
      expect(find.byType(AppBar), findsNothing);
      expect(_bars.hidden, isTrue);
      await _back(tester);
      expect(_bars.hidden, isFalse);
    });
  });

  testWidgets('beside a chart a tap selects, without going full screen', (
    tester,
  ) async {
    _size(tester, 800, 1280); // grid only, chart above
    _register();
    await _toCube(tester);
    await _showChart(tester);
    await _tapValue(tester, '2');
    expect(find.byType(AppBar), findsOneWidget);
    expect(_bars.hidden, isFalse);
    expect(_state.cube.controller.value!.selection, isNotNull);
  });

  testWidgets('every kind draws, or says why it cannot', (tester) async {
    _size(tester, 1400, 900);
    _register();
    await _toCube(tester);
    await _showChart(tester);
    Future<void> kind(String tooltip) => _tapTooltip(tester, tooltip);
    await kind('Stacked bars');
    expect(find.byType(BarChart), findsOneWidget);
    await kind('Line');
    expect(find.byType(LineChart), findsOneWidget);
    await kind('Pie');
    expect(find.byType(PieChart), findsOneWidget);
    await kind('Scatter');
    // one aggregate so far
    expect(find.byType(ScatterChart), findsNothing);
    expect(find.textContaining('needs two values'), findsOneWidget);
    final ctrl = _state.cube.controller.value!;
    ctrl.updateSpec(
      ctrl.cube.spec.copyWith(
        aggregates: [
          Aggregate.sum(const Measure('amount')),
          Aggregate.sum(const Measure('units')),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScatterChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it follows the pivot and, on request, the current cell', (
    tester,
  ) async {
    _size(tester, 1400, 900);
    _register();
    await _toCube(tester);
    await _showChart(tester);
    expect(find.text('EU'), findsWidgets);
    BarChartData data() => tester.widget<BarChart>(find.byType(BarChart)).data;
    // Count by region: EU 2, US 1
    expect(data().barGroups.length, 2);
    expect(data().barGroups.map((g) => g.barRods.single.toY), [2, 1]);

    // a filter in the pivot
    final ctrl = _state.cube.controller.value!;
    ctrl.updateSpec(
      ctrl.cube.spec.copyWith(
        filter: () =>
            ValueFilter(const ColumnDimension('region'), const ['EU']),
      ),
    );
    await tester.pumpAndSettle();
    expect(data().barGroups.map((g) => g.barRods.single.toY), [2]);
    ctrl.updateSpec(ctrl.cube.spec.copyWith(filter: () => null));
    await tester.pumpAndSettle();

    // the current cell, by its other column
    _state.cube.chart.update(const ChartSettings(source: ChartSource.cell));
    await tester.pumpAndSettle();
    expect(find.textContaining('No current cell, so this'), findsOneWidget);
    await _tapValue(tester, '2', kind: PointerDeviceKind.mouse);
    expect(find.textContaining('No current cell, so this'), findsNothing);
    expect(find.textContaining('region = EU'), findsWidgets);
    // a tap in the grid is not the chart's: it changes after it settles
    expect(data().barGroups.map((g) => g.barRods.single.toY), [1, 1]);
    expect(tester.takeException(), isNull);
  });

  group('remembered per structure', () {
    testWidgets('a chart comes back as it was left', (tester) async {
      _size(tester, 1400, 900);
      _register();
      await _toCube(tester);
      await _showChart(tester);
      await _tapTooltip(tester, 'Line');
      expect(_layouts.charts.length, 1);
      expect(_layouts.charts.values.single.visible, isTrue);
      expect(_layouts.charts.values.single.settings.kind, ChartKind.line);

      // close, and open it again
      _state.closeFile();
      await tester.pumpAndSettle();
      await _doAndWait(
        tester,
        () => tester.tap(find.widgetWithText(FilledButton, 'Open file…')),
      );
      final labelled = find.widgetWithText(FilledButton, 'Continue');
      if (labelled.evaluate().isNotEmpty) {
        await _doAndWait(tester, () => tester.tap(labelled));
      }
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('a hidden chart with its defaults leaves nothing', (
      tester,
    ) async {
      _size(tester, 1400, 900);
      _register();
      await _toCube(tester);
      await _showChart(tester);
      expect(_layouts.charts, isNotEmpty);
      await _tapTooltip(tester, 'Hide chart');
      expect(_layouts.charts, isEmpty);
    });
  });

  group('export', () {
    testWidgets('a showing chart heads the dialog and saves as a PNG', (
      tester,
    ) async {
      _size(tester, 1400, 900);
      _register();
      await _toCube(tester);

      // no chart, no entry
      await _tapTooltip(tester, 'Save as…');
      expect(find.text('PNG image'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await _showChart(tester);
      await _tapTooltip(tester, 'Save as…');
      expect(find.text('Chart'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('PNG image'));
        await tester.pump();
        for (var i = 0; i < 200 && _exports.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      final saved = _exports.saved.single;
      expect(saved.fileName, 'sales chart.png');
      expect(saved.mimeType, 'image/png');
      // the PNG signature, then a 2000 × 1280 IHDR
      expect(saved.bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(saved.bytes, 16, 24);
      expect(header.getUint32(0), 2000);
      expect(header.getUint32(4), 1280);
      // nothing of the off-screen drawing stays behind
      expect(find.byType(BarChart), findsOneWidget);
    });
  });

  testWidgets('the panel fits every language', (tester) async {
    _size(tester, 400, 800);
    _register();
    await _toCube(tester);
    await _showChart(tester);
    for (final code in const [
      'cs',
      'de',
      'es',
      'fr',
      'hu',
      'it',
      'ja',
      'nl',
      'pl',
      'pt',
      'ru',
      'tr',
      'zh',
    ]) {
      await GetIt.I<AppSettings>().setLocale(Locale(code));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: code);
    }
  });

  // The owner's desktop runs at 1.5, and phones go to 2: every height and
  // width around a chart's text has to follow it.
  group('at a larger text size', () {
    Future<void> everyChart(
      WidgetTester tester,
      double scale, {
      required double width,
      required double height,
    }) async {
      _size(tester, width, height);
      _register();
      await _toCube(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await _showChart(tester);
      // two levels on an axis: the labels with two lines
      final ctrl = _state.cube.controller.value!;
      ctrl.updateSpec(
        ctrl.cube.spec.copyWith(
          rows: CubeAxis.of(const [
            ColumnDimension('region'),
            ColumnDimension('product'),
          ]),
        ),
      );
      ctrl.expandRowLevel(0);
      await tester.pumpAndSettle();
      for (final kind in ChartKind.values) {
        // swapped: the rows' names in a legend
        for (final transpose in const [false, true]) {
          _state.cube.chart.update(
            ChartSettings(kind: kind, transpose: transpose),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$kind, $transpose at $scale in $width × $height',
          );
        }
      }
    }

    for (final scale in const [1.0, 1.3, 1.5, 2.0, 3.0]) {
      testWidgets('$scale beside the grid', (tester) async {
        await everyChart(tester, scale, width: 1200, height: 800);
      });
      testWidgets('$scale on a phone', (tester) async {
        await everyChart(tester, scale, width: 400, height: 800);
      });
      testWidgets('$scale on a phone on its side', (tester) async {
        await everyChart(tester, scale, width: 800, height: 360);
      });
      // not at 3: the editors alone overflow that, chart or no chart
      if (scale < 3) {
        testWidgets('$scale beside the grid, in a low window', (tester) async {
          await everyChart(tester, scale, width: 900, height: 500);
        });
      }
    }
  });
}
