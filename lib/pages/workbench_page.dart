import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart' hide NumberFormat;

import '../export/export_target.dart';
import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../platform/system_bars.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/app_menu.dart';
import '../widgets/editors_panel.dart';
import '../widgets/export_dialog.dart';

/// The cube page. Two layouts ([CubePageLayout]): editors inline above the
/// grid, or the grid alone with the editors in a bottom sheet behind
/// the "Editors" button; by window size unless the user chose.
///
/// Export is one tap away: Share on phones and tablets (Save as… then
/// sits in the menu), Save as… elsewhere; both open the format dialog.
///
/// Full screen, like a video player: in the grid-alone layout a tap (a
/// finger, not a mouse click) on a value hides the app bar and the
/// system bars, and the next one brings them back; so does back.
class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key, required this.document});

  final OpenedDocument document;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  OpenedDocument get document => widget.document;

  bool _fullScreen = false;

  /// Keeps the grid's scroll position when its parents change (full
  /// screen, a switch of layout).
  final _gridKey = GlobalKey();

  /// The kind of the last pointer down on the grid; a cell tap does not
  /// say what tapped it.
  PointerDeviceKind? _pointer;

  /// Set while an export is written; a progress bar shows under the bar.
  bool _exporting = false;

  void _setFullScreen(bool value) {
    if (value == _fullScreen) return;
    setState(() => _fullScreen = value);
    final bars = GetIt.I<SystemBars>();
    value ? bars.hide() : bars.show();
  }

  void _cellTapped(bool editorsInline) {
    final touch = switch (_pointer) {
      PointerDeviceKind.touch ||
      PointerDeviceKind.stylus ||
      PointerDeviceKind.invertedStylus => true,
      _ => false,
    };
    if (touch && (_fullScreen || !editorsInline)) _setFullScreen(!_fullScreen);
  }

  @override
  void dispose() {
    if (_fullScreen) GetIt.I<SystemBars>().show();
    super.dispose();
  }

  /// Exports the cube with the aggregates the grid shows.
  Future<void> _export(
    BuildContext context,
    CubeController ctrl, {
    required bool share,
  }) {
    final spec = ctrl.cube.spec.aggregates;
    final shown = GetIt.I<AppState>().cube.shown.value
        ?.where(spec.contains)
        .toList();
    return runExport(
      context,
      documentName: document.name,
      cube: ctrl.cube,
      aggregates: shown == null || shown.isEmpty ? null : shown,
      style: GetIt.I<AppSettings>().gridStyle.value,
      share: share,
      onBusy: (busy) {
        if (mounted) setState(() => _exporting = busy);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _fullScreen ? _setFullScreen(false) : state.closeFile();
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SignalBuilder(
          builder: (context) {
            final ctrl = state.cube.controller.value;
            final layout = settings.cubeLayout.value.resolve(
              constraints.biggest,
            );
            final editorsInline = layout == CubePageLayout.editors;
            final canExport =
                ctrl != null && !state.cube.importing.value && !_exporting;
            return Scaffold(
              appBar: _fullScreen
                  ? null
                  : AppBar(
                      title: Text(document.name),
                      bottom: _exporting
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
                        IconButton(
                          icon: Icon(
                            canShare
                                ? Icons.share
                                : Icons.file_download_outlined,
                          ),
                          tooltip: canShare ? l10n.share : l10n.saveAs,
                          onPressed: canExport
                              ? () => _export(context, ctrl, share: canShare)
                              : null,
                        ),
                        AppMenuButton(
                          entries: [
                            if (canShare)
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
                  if (!_fullScreen &&
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.importFailed(error.toString()),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
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
    final style = GetIt.I<AppSettings>().gridStyle.value;
    final view = Listener(
      onPointerDown: (event) => _pointer = event.kind,
      child: CubeView(
        key: _gridKey,
        controller: ctrl,
        theme: style.theme(Theme.of(context).brightness),
        aggregates: shown,
        onCellTap: (_) => _cellTapped(editorsInline),
      ),
    );
    // Nothing but the grid, kept clear of a notch.
    if (_fullScreen) return SafeArea(child: view);
    if (!editorsInline) return view;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorsPanel(document: document, cube: state.cube),
        Expanded(child: view),
        CurrentCellLine(controller: ctrl),
      ],
    );
  }
}
