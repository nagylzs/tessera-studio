import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart' hide NumberFormat;

import '../charts/chart_content.dart';
import '../charts/chart_drawing.dart';
import '../charts/chart_export.dart';
import '../charts/chart_panel.dart';
import '../charts/chart_settings.dart';
import '../export/export_target.dart';
import '../files/file_failure.dart';
import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../platform/system_bars.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../style/style_gallery.dart';
import '../widgets/app_menu.dart';
import '../widgets/document_title.dart';
import '../widgets/editors_panel.dart';
import '../widgets/export_dialog.dart';
import '../widgets/failure_view.dart';
import '../widgets/open_file.dart';
import '../widgets/split_view.dart';

/// The cube page. Two layouts ([CubePageLayout]): editors inline above the
/// grid, or the grid alone with the editors in a bottom sheet behind
/// the "Editors" button; by window size unless the user chose.
///
/// Export is one tap away: Share on phones and tablets (Save as… then
/// sits in the menu), both side by side on a Mac, Save as… elsewhere; each
/// opens the format dialog.
///
/// Full screen, like a video player: in the grid-alone layout a tap (a
/// finger, not a mouse click) on a value hides the app bar and the
/// system bars, and the next one brings them back; so does back.
///
/// The chart button adds a chart, placed by window size ([ChartPlacement]):
/// beside or above the grid with a divider to drag, or on a phone instead
/// of it, where the button and back return to the grid.
class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key, required this.document});

  final OpenedDocument document;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

/// What fills the screen: the grid, by a tap on a value on a touch screen,
/// or the chart, by its button.
enum _FullScreen { grid, chart }

class _WorkbenchPageState extends State<WorkbenchPage> {
  OpenedDocument get document => widget.document;

  _FullScreen? _fullScreen;

  /// Holds the keyboard while the chart fills the screen, for Esc.
  final _fullChartFocus = FocusNode(debugLabel: 'full screen chart');

  /// Keeps the grid's scroll position when its parents change (full
  /// screen, a switch of layout).
  final _gridKey = GlobalKey();
  final _chartKey = GlobalKey();

  /// The chart's place in the current window, for back.
  ChartPlacement _placement = ChartPlacement.beside;

  /// The kind of the last pointer down on the grid; a cell tap does not
  /// say what tapped it.
  PointerDeviceKind? _pointer;

  /// Set while an export is written; a progress bar shows under the bar.
  bool _exporting = false;

  /// The size the grid had when the chart took the whole window, which it
  /// keeps meanwhile: at the window's size a pivot that scrolled in its pane
  /// may fit, and the grid would come back at its top.
  Size? _gridSizeBehindChart;

  void _setFullScreen(_FullScreen? value) {
    if (value == _fullScreen) return;
    _gridSizeBehindChart = value == _FullScreen.chart
        ? _gridKey.currentContext?.size
        : null;
    setState(() => _fullScreen = value);
    final bars = GetIt.I<SystemBars>();
    value != null ? bars.hide() : bars.show();
    if (value == _FullScreen.chart) {
      // it has no node to take the focus from the grid until it is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fullChartFocus.requestFocus();
      });
    }
  }

  void _cellTapped(bool editorsInline) {
    final touch = switch (_pointer) {
      PointerDeviceKind.touch ||
      PointerDeviceKind.stylus ||
      PointerDeviceKind.invertedStylus => true,
      _ => false,
    };
    // beside a chart a tap picks the cell the chart may be showing
    final alongside =
        GetIt.I<AppState>().cube.chart.visible.value &&
        _placement != ChartPlacement.instead;
    if (!touch) return;
    if (_fullScreen != null) {
      _setFullScreen(null);
    } else if (!editorsInline && !alongside) {
      _setFullScreen(_FullScreen.grid);
    }
  }

  /// Back: out of full screen, then from a phone's chart to its grid, then
  /// out of the file.
  void _back(AppState state) {
    final chart = state.cube.chart;
    if (_fullScreen != null) {
      _setFullScreen(null);
    } else if (chart.visible.value && _placement == ChartPlacement.instead) {
      chart.setVisible(false);
    } else {
      state.closeFile();
    }
  }

  @override
  void dispose() {
    if (_fullScreen != null) GetIt.I<SystemBars>().show();
    _fullChartFocus.dispose();
    super.dispose();
  }

  /// Exports the cube with the aggregates the grid shows.
  /// Where [context]'s widget is on the screen: the share button, for
  /// an iPad's share popover.
  static Rect? _globalRect(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _export(
    BuildContext context,
    CubeController ctrl, {
    required bool share,
    Rect? shareOrigin,
  }) {
    final cubeState = GetIt.I<AppState>().cube;
    final spec = ctrl.cube.spec.aggregates;
    final shown = cubeState.shown.value?.where(spec.contains).toList();
    return runExport(
      context,
      baseName: document.exportBaseName,
      cube: ctrl.cube,
      aggregates: shown == null || shown.isEmpty ? null : shown,
      style: GetIt.I<StyleGallery>().byId(
        GetIt.I<AppSettings>().gridStyle.value,
      ),
      coloring: GetIt.I<AppSettings>().depthColoring.value,
      share: share,
      shareOrigin: shareOrigin,
      onBusy: (busy) {
        if (mounted) setState(() => _exporting = busy);
      },
      chartBytes: !cubeState.chart.visible.value
          ? null
          : (format, look) {
              final l10n = AppLocalizations.of(context);
              final strings = TesseraLocalizations.of(context);
              final settings = cubeState.chart.settings.value;
              final content = chartContent(
                cube: ctrl.cube,
                settings: settings,
                dimensions: cubeState.dimensions.value,
                strings: strings,
                shown: shown,
                cell: settings.source == ChartSource.cell
                    ? ctrl.currentCell
                    : null,
              );
              return chartExport(
                format,
                content,
                title: document.exportBaseName,
                caption: chartCaption(context, content, ctrl.cube),
                problem: switch (content.problem) {
                  final problem? => chartProblemText(l10n, problem),
                  null => null,
                },
                others: l10n.chartOthers,
                look: look,
                strings: strings,
                locale: Localizations.localeOf(context).toString(),
              );
            },
    );
  }

  Future<void> _editFilter(BuildContext context, CubeController ctrl) async {
    final spec = ctrl.cube.spec;
    final result = await showFilterEditor(
      context,
      facts: ctrl.cube.facts,
      initial: spec.filter,
    );
    if (result == null) return;
    ctrl.updateSpec(spec.copyWith(filter: () => result.filter));
  }

  Future<void> _showEditors(BuildContext context, AppState state) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scroll) => SingleChildScrollView(
            controller: scroll,
            child: SignalBuilder(
              builder: (context) {
                final ctrl = state.cube.controller.value;
                if (ctrl == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CurrentCellLine(controller: ctrl),
                    EditorsPanel(document: document, cube: state.cube),
                  ],
                );
              },
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = GetIt.I<AppState>();
    final settings = GetIt.I<AppSettings>();
    final canShare = GetIt.I<ExportTarget>().canShare;
    final sharesFirst = GetIt.I<ExportTarget>().sharesFirst;
    return PopScope(
      // An open tessera menu holds a local history entry on this route
      // (like a drawer): let that back through to close the menu only.
      canPop: ModalRoute.of(context)?.willHandlePopInternally ?? false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(state);
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SignalBuilder(
          builder: (context) {
            final ctrl = state.cube.controller.value;
            final layout = settings.cubeLayout.value.resolve(
              constraints.biggest,
            );
            final editorsInline = layout == CubePageLayout.editors;
            _placement = ChartPlacement.of(constraints.biggest);
            final chartVisible = state.cube.chart.visible.value;
            final canExport =
                ctrl != null && !state.cube.importing.value && !_exporting;
            return Scaffold(
              appBar: _fullScreen != null
                  ? null
                  : AppBar(
                      title: DocumentTitle(
                        document: document,
                        title: document.name,
                      ),
                      // writing an export, or reading another sheet
                      bottom: _exporting || state.loading.value != null
                          ? const PreferredSize(
                              preferredSize: Size.fromHeight(4),
                              child: LinearProgressIndicator(),
                            )
                          : null,
                      leading: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: l10n.closeFile,
                        onPressed: state.closeFile,
                      ),
                      actions: [
                        if (!editorsInline)
                          IconButton(
                            icon: const Icon(Icons.tune),
                            tooltip: l10n.editorsTooltip,
                            onPressed: ctrl == null
                                ? null
                                : () => _showEditors(context, state),
                          ),
                        if (editorsInline)
                          IconButton(
                            icon: const Icon(Icons.filter_alt_outlined),
                            tooltip: l10n.filterMenu,
                            onPressed: ctrl == null
                                ? null
                                : () => _editFilter(context, ctrl),
                          ),
                        _chartButton(context, state, ctrl, chartVisible),
                        if (!sharesFirst)
                          IconButton(
                            icon: const Icon(Icons.file_download_outlined),
                            tooltip: l10n.saveAs,
                            onPressed: canExport
                                ? () => _export(context, ctrl, share: false)
                                : null,
                          ),
                        if (canShare)
                          Builder(
                            builder: (button) => IconButton(
                              icon: const Icon(Icons.share),
                              tooltip: l10n.share,
                              onPressed: canExport
                                  ? () => _export(
                                      context,
                                      ctrl,
                                      share: true,
                                      shareOrigin: _globalRect(button),
                                    )
                                  : null,
                            ),
                          ),
                        AppMenuButton(
                          entries: [
                            if (sharesFirst)
                              AppMenuEntry(
                                label: l10n.saveAs,
                                icon: Icons.file_download_outlined,
                                enabled: canExport,
                                onTap: () =>
                                    _export(context, ctrl!, share: false),
                              ),
                            AppMenuEntry(
                              label: l10n.editorsOnTop,
                              checked: editorsInline,
                              enabled: ctrl != null,
                              onTap: () => settings.setCubeLayout(
                                editorsInline
                                    ? CubePageLayout.cubeOnly
                                    : CubePageLayout.editors,
                              ),
                            ),
                            if (!editorsInline)
                              AppMenuEntry(
                                label: l10n.filterMenu,
                                icon: Icons.filter_alt_outlined,
                                enabled: ctrl != null,
                                onTap: () => _editFilter(context, ctrl!),
                              ),
                            AppMenuEntry(
                              label: l10n.editSchema,
                              icon: Icons.view_column_outlined,
                              enabled: state.source.value != null,
                              onTap: state.editSchema,
                            ),
                          ],
                        ),
                      ],
                    ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_fullScreen == null &&
                      (state.restored.value != null ||
                          state.restoredLayout.value != null))
                    _restoredBanner(context, state),
                  Expanded(child: _body(context, state, ctrl, editorsInline)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Shows or hides the chart. On a phone it says where it goes: the chart
  /// takes the grid's place, so hiding it shows the table.
  Widget _chartButton(
    BuildContext context,
    AppState state,
    CubeController? ctrl,
    bool visible,
  ) {
    final l10n = AppLocalizations.of(context);
    final instead = _placement == ChartPlacement.instead;
    return IconButton(
      icon: Icon(
        !visible
            ? Icons.insert_chart_outlined
            : instead
            ? Icons.table_chart_outlined
            : Icons.insert_chart,
      ),
      tooltip: !visible
          ? l10n.chartShow
          : instead
          ? l10n.chartShowTable
          : l10n.chartHide,
      onPressed: ctrl == null
          ? null
          : () => state.cube.chart.setVisible(!visible),
    );
  }

  /// What was restored for this file's structure — the schema, the
  /// pivot or both — with a way back from each.
  Widget _restoredBanner(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context);
    final schema = state.restored.value;
    final layout = state.restoredLayout.value;
    return MaterialBanner(
      leading: const Icon(Icons.history),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (schema != null) Text(l10n.schemaRestored(schema.savedAt)),
          if (layout != null) Text(l10n.layoutRestored(layout.savedAt)),
        ],
      ),
      actions: [
        if (schema != null)
          TextButton(
            onPressed: state.resetToInferred,
            child: Text(l10n.resetToInferred),
          ),
        if (layout != null)
          TextButton(
            onPressed: state.defaultPivot,
            child: Text(l10n.defaultPivot),
          ),
        TextButton(
          onPressed: state.dismissRestored,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    AppState state,
    CubeController? ctrl,
    bool editorsInline,
  ) {
    final l10n = AppLocalizations.of(context);
    final error = state.cube.error.value;
    if (error != null) {
      // read and inferred fine, then failed further down the file
      return FailureView(
        failure: FileFailure.of(
          document.name,
          error,
          format: document.format,
          bytes: document.bytes,
          rowsRead: state.cube.errorRows.value,
        ),
        actions: [
          if (state.source.value != null)
            FilledButton.icon(
              icon: const Icon(Icons.view_column_outlined),
              label: Text(l10n.editSchema),
              onPressed: state.editSchema,
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: Text(l10n.openAnotherFile),
            onPressed: () => pickAndOpen(context),
          ),
          TextButton(
            onPressed: state.closeFile,
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      );
    }
    if (ctrl == null || state.cube.importing.value) {
      final progress = state.cube.progress.value;
      final locale = Localizations.localeOf(context).toString();
      final fraction = progress?.fraction;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(value: fraction),
            ),
            const SizedBox(height: 8),
            Text(
              progress == null
                  ? l10n.importing
                  : '${l10n.importRows(progress.rowsRead)}'
                        '${fraction == null ? '' : ' (${NumberFormat.percentPattern(locale).format(fraction)})'}',
            ),
          ],
        ),
      );
    }
    final shown = state.cube.shown.value ?? ctrl.cube.spec.aggregates;
    final settings = GetIt.I<AppSettings>();
    final style = GetIt.I<StyleGallery>().byId(settings.gridStyle.value);
    // The cells draw their hover and ink on the nearest Material; were that
    // the page's, no scrolling would clip them and they would show on a chart
    // beside the grid. All this moves together when the layout changes.
    final view = ClipRect(
      key: _gridKey,
      child: Material(
        type: MaterialType.transparency,
        child: Listener(
          onPointerDown: (event) => _pointer = event.kind,
          child: CubeView(
            controller: ctrl,
            theme: CubeTheme.fromStyle(
              style,
              coloring: settings.depthColoring.value,
              fontFamilies: styleFontFamilies,
            ),
            aggregates: shown,
            onCellTap: (_) => _cellTapped(editorsInline),
          ),
        ),
      ),
    );
    final content = _withChart(state, ctrl, view, shown, editorsInline);
    // Nothing but the grid or the chart, kept clear of a notch.
    switch (_fullScreen) {
      case _FullScreen.grid:
        return SafeArea(child: view);
      case _FullScreen.chart:
        return Focus(
          focusNode: _fullChartFocus,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent ||
                event.logicalKey != LogicalKeyboardKey.escape) {
              return KeyEventResult.ignored;
            }
            _setFullScreen(null);
            return KeyEventResult.handled;
          },
          child: SafeArea(child: content),
        );
      case null:
        break;
    }
    if (!editorsInline) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorsPanel(document: document, cube: state.cube),
        Expanded(child: content),
        CurrentCellLine(controller: ctrl),
      ],
    );
  }

  /// The grid and, when asked for, the chart in its place in this window.
  Widget _withChart(
    AppState state,
    CubeController ctrl,
    Widget view,
    List<Aggregate> shown,
    bool editorsInline,
  ) {
    final chart = state.cube.chart;
    if (!chart.visible.value) return view;
    final settings = GetIt.I<AppSettings>();
    final fullChart = _fullScreen == _FullScreen.chart;
    final panel = ChartPanel(
      key: _chartKey,
      controller: ctrl,
      dimensions: state.cube.dimensions.value,
      state: chart,
      shown: shown,
      fullScreen: fullChart,
      onFullScreen: () => _setFullScreen(fullChart ? null : _FullScreen.chart),
    );
    // The chart's captions and buttons, unlike the grid's scrolling cells,
    // must keep clear of a gesture bar or a notch where they touch the edge.
    return switch (fullChart ? ChartPlacement.instead : _placement) {
      ChartPlacement.beside => SplitView(
        axis: Axis.horizontal,
        fraction: settings.chartSplit.value,
        onChanged: settings.setChartSplit,
        first: view,
        second: SafeArea(
          top: false,
          left: false,
          bottom: !editorsInline,
          child: panel,
        ),
      ),
      ChartPlacement.above => SplitView(
        axis: Axis.vertical,
        fraction: settings.chartSplit.value,
        onChanged: settings.setChartSplit,
        first: SafeArea(top: false, bottom: false, child: panel),
        second: view,
      ),
      // the grid stays, offstage, with its scroll position and selection
      ChartPlacement.instead => Stack(
        fit: StackFit.expand,
        children: [
          if (_gridSizeBehindChart case final size?)
            Positioned.fromRect(
              rect: Offset.zero & size,
              child: Offstage(child: view),
            )
          else
            Offstage(child: view),
          SafeArea(top: false, bottom: !editorsInline, child: panel),
        ],
      ),
    };
  }
}
