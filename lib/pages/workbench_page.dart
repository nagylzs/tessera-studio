import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../files/file_format.dart';
import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';

/// Shows the open document. For now only its name, format and size; the
/// pivot workbench (schema, editors, CubeView) lands here next.
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
        ),
        body: ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: Text(_formatLabel(l10n, document.format)),
          subtitle: Text(l10n.fileSize(document.size)),
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
