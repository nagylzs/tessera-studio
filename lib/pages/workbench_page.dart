import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../files/file_format.dart';
import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../state/app_state.dart';
import '../widgets/app_menu.dart';

/// Where the pivot will be. For now: the document's name, format and
/// size, the columns of the accepted schema, and the banner that says a
/// stored schema was applied. The import and the CubeView land next.
class WorkbenchPage extends StatelessWidget {
  const WorkbenchPage({super.key, required this.document});

  final OpenedDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = GetIt.I<AppState>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) state.closeFile();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(document.name),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.closeFile,
            onPressed: state.closeFile,
          ),
          actions: [
            SignalBuilder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.view_column_outlined),
                tooltip: l10n.editSchema,
                onPressed: state.source.value == null ? null : state.editSchema,
              ),
            ),
            const AppMenuButton(),
          ],
        ),
        body: SignalBuilder(
          builder: (context) {
            final restored = state.restored.value;
            final schema = state.schema.value;
            return Column(
              children: [
                if (restored != null)
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
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: Text(_formatLabel(l10n, document.format)),
                  subtitle: Text(l10n.fileSize(document.size)),
                ),
                const Divider(height: 1),
                if (schema != null)
                  Expanded(
                    child: ListView(
                      children: [
                        for (final c in schema.included)
                          ListTile(
                            dense: true,
                            title: Text(c.displayLabel),
                            subtitle: Text(l10n.columnType(c.type)),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatLabel(AppLocalizations l10n, FileFormat format) =>
      switch (format) {
        FileFormat.csv => l10n.formatCsv,
        FileFormat.tsv => l10n.formatTsv,
        FileFormat.xlsx => l10n.formatXlsx,
        FileFormat.ods => l10n.formatOds,
        FileFormat.json => l10n.formatJson,
        FileFormat.jsonl => l10n.formatJsonl,
        FileFormat.snapshot => l10n.formatSnapshot,
      };
}
