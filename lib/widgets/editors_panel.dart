import 'package:flutter/material.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../files/file_format.dart';
import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../state/cube_state.dart';

/// The import summary and the axis and aggregate editors. Inline above
/// the grid on wide windows, in a bottom sheet on narrow ones. The two
/// axis editors sit side by side when the panel is at least
/// [sideBySideFrom] wide and under each other otherwise (an axis editor
/// cannot shrink below its caption, its widest chip and its add button).
class EditorsPanel extends StatelessWidget {
  const EditorsPanel({super.key, required this.document, required this.cube});

  static const sideBySideFrom = 600.0;

  final OpenedDocument document;
  final CubeState cube;

  @override
  Widget build(BuildContext context) {
    final controller = cube.controller.value!;
    final dimensions = cube.dimensions.value;
    final shown = cube.shown.value ?? controller.cube.spec.aggregates;
    final rows = AxisEditor(
      controller: controller,
      side: AxisSide.rows,
      available: dimensions,
    );
    final columns = AxisEditor(
      controller: controller,
      side: AxisSide.columns,
      available: dimensions,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ImportSummary(document: document, cube: cube),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= sideBySideFrom
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: rows),
                      const SizedBox(width: 8),
                      Expanded(child: columns),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [rows, const SizedBox(height: 8), columns],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AggregateEditor(
            controller: controller,
            selected: shown.toSet(),
            onSelectedChanged: (a) => cube.shown.value = a,
            dimensions: dimensions,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// "sales.csv · CSV file · 178,238 bytes · 20,000 records, 3 columns
/// · tap for the import report"; tapping opens [showImportReport].
class ImportSummary extends StatelessWidget {
  const ImportSummary({super.key, required this.document, required this.cube});

  final OpenedDocument document;
  final CubeState cube;

  static String formatLabel(AppLocalizations l10n, FileFormat format) =>
      switch (format) {
        FileFormat.csv => l10n.formatCsv,
        FileFormat.tsv => l10n.formatTsv,
        FileFormat.xlsx => l10n.formatXlsx,
        FileFormat.ods => l10n.formatOds,
        FileFormat.json => l10n.formatJson,
        FileFormat.jsonl => l10n.formatJsonl,
        FileFormat.snapshot => l10n.formatSnapshot,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = cube.result.value;
    if (result == null) return const SizedBox.shrink();
    final report = result.report;
    final facts = result.facts;
    final nullified = report.nullifiedPerColumn.values.fold(0, (a, b) => a + b);
    final parts = [
      formatLabel(l10n, document.format),
      l10n.fileSize(document.size),
      l10n.importSummary(facts.rowCount, facts.columns.length),
      if (report.widenedColumns.isNotEmpty)
        l10n.widenedSummary(report.widenedColumns.length),
      if (nullified > 0) l10n.nullifiedSummary(nullified),
      l10n.tapForReport,
    ];
    return InkWell(
      onTap: () => showImportReport(context, report),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          parts.join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

Future<void> showImportReport(BuildContext context, ImportReport report) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.importReportTitle),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(l10n.rowsImported(report.rowsImported)),
            for (final e in report.widenedColumns.entries)
              Text(l10n.widenedTo(e.key, l10n.columnType(e.value))),
            for (final e in report.nullifiedPerColumn.entries)
              Text(l10n.couldNotParse(e.key, e.value)),
            if (report.issues.isNotEmpty) const Divider(),
            for (final issue in report.issues) Text(issue.toString()),
            if (report.issuesTruncated) const Text('…'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );
}

/// The active filter and the current cell — what an app charts or
/// drills into. Below the grid on wide windows, atop the sheet on
/// narrow ones.
class CurrentCellLine extends StatelessWidget {
  const CurrentCellLine({super.key, required this.controller});

  final CubeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cell = controller.currentCell;
        final t = TesseraLocalizations.of(context);
        final facts = controller.cube.facts;
        final filter = controller.cube.spec.filter;
        final filterText = filter == null
            ? null
            : '${t.filter}: '
                  '${filter.toExpressionSource() ?? (filter is PredicateFilter ? filter.label : null) ?? t.customFilter}';
        final text = cell == null
            ? l10n.noCurrentCell
            : cell.coordinate.isEmpty
            ? l10n.currentCellTotal(cell.factCount)
            : l10n.currentCell(
                cell.coordinate.values.entries
                    .map(
                      (e) =>
                          '${t.dimensionLabel(e.key, facts)} = '
                          '${e.value == null ? t.emptyGroup : t.formatValue(e.key, e.value)}',
                    )
                    .join(', '),
                cell.factCount,
              );
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            filterText == null ? text : '$filterText\n$text',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
