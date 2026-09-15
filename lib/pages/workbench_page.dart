import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart' hide NumberFormat;

import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/app_menu.dart';
import '../widgets/editors_panel.dart';

/// The cube page. Two layouts ([CubePageLayout]): editors inline above the
/// grid, or the grid alone with the editors in a bottom sheet behind
/// the "Editors" button; by window width unless the user chose.
class WorkbenchPage extends StatelessWidget {
  const WorkbenchPage({super.key, required this.document});

  final OpenedDocument document;

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) state.closeFile();
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SignalBuilder(
          builder: (context) {
            final ctrl = state.cube.controller.value;
            final layout = settings.cubeLayout.value.resolve(
              constraints.maxWidth,
            );
            final editorsInline = layout == CubePageLayout.editors;
            return Scaffold(
              appBar: AppBar(
                title: Text(document.name),
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
                  AppMenuButton(
                    entries: [
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
                  if (state.restored.value case final restored?)
                    MaterialBanner(
                      leading: const Icon(Icons.history),
                      content: Text(l10n.schemaRestored(restored.savedAt)),
                      actions: [
                        TextButton(
                          onPressed: state.resetToInferred,
                          child: Text(l10n.resetToInferred),
                        ),
                        TextButton(
                          onPressed: state.dismissRestored,
                          child: Text(
                            MaterialLocalizations.of(context).okButtonLabel,
                          ),
                        ),
                      ],
                    ),
                  Expanded(child: _body(context, state, ctrl, editorsInline)),
                ],
              ),
            );
          },
        ),
      ),
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
    final view = CubeView(controller: ctrl, aggregates: shown);
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
