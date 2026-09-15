import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../files/file_format.dart';
import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';

/// The screen after a file is loaded: the schema editor. For now only
/// the document's name, format and size; inference and the column
/// editor land here next, then the workbench follows.
class SchemaPage extends StatelessWidget {
  const SchemaPage({super.key, required this.document});

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
