import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../charts/chart_settings.dart';
import '../export/export_format.dart';
import '../export/export_target.dart';
import '../export/exports.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/settings.dart';
import '../style/grid_style.dart';

/// What the export dialog asks for; a snapshot counts as the pivot.
typedef ExportChoice = ({ExportKind kind, ExportFormat format, ChartLook look});

/// Asks for a format, writes the export of [cube] (with the [aggregates]
/// the grid shows, in its [style]) and shares it ([share]) or saves it
/// where the user says; the outcome goes to a snack bar. File names and
/// titles start from [baseName] (`OpenedDocument.exportBaseName`). [onBusy] brackets the writing,
/// which runs on this isolate like the cube layout does. [shareOrigin] is
/// the share button's rect, where an iPad's share popover points. With
/// [chartBytes], a chart is showing: the dialog starts on it.
Future<void> runExport(
  BuildContext context, {
  required String baseName,
  required Cube cube,
  List<Aggregate>? aggregates,
  GridStyle style = GridStyle.standard,
  required bool share,
  Rect? shareOrigin,
  required ValueChanged<bool> onBusy,
  Future<Uint8List> Function(ExportFormat format, ChartLook look)? chartBytes,
}) async {
  final l10n = AppLocalizations.of(context);
  final strings = TesseraLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final title = (share ? l10n.share : l10n.saveAs).replaceAll('…', '');
  final choice = await showExportDialog(
    context,
    title: title,
    chart: chartBytes != null,
  );
  if (choice == null) return;
  final format = choice.format;
  // a snapshot is the file itself again, under its own extension
  final stem = format == ExportFormat.snapshot
      ? baseName
      : switch (choice.kind) {
          ExportKind.chart => l10n.chartFileName(baseName),
          ExportKind.facts => l10n.factsFileName(baseName),
          ExportKind.pivot => l10n.pivotFileName(baseName),
        };
  final fileName = '$stem.${format.extension}';
  final target = GetIt.I<ExportTarget>();
  try {
    onBusy(true);
    final Uint8List bytes;
    try {
      // let the progress bar paint before the work holds the isolate
      await WidgetsBinding.instance.endOfFrame;
      bytes = switch (choice.kind) {
        ExportKind.chart => await chartBytes!(format, choice.look),
        ExportKind.facts => factsExport(cube, format, title: baseName),
        ExportKind.pivot => await cubeExport(
          cube,
          format,
          title: baseName,
          strings: strings,
          aggregates: aggregates,
          style: style,
        ),
      };
    } finally {
      onBusy(false);
    }
    if (share) {
      await target.share(
        bytes,
        fileName: fileName,
        mimeType: format.mimeType,
        origin: shareOrigin,
      );
      return;
    }
    final saved = await target.save(
      bytes,
      fileName: fileName,
      mimeType: format.mimeType,
      dialogTitle: title,
    );
    if (saved == null) return;
    // a desktop gives a path; Android a content Uri, the web a download
    final where = saved.isScheme('file') ? saved.toFilePath() : fileName;
    messenger.showSnackBar(SnackBar(content: Text(l10n.savedTo(where))));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.exportFailed(e.toString()))),
    );
  }
}

/// What to export and in which format. A dialog rather than a menu: thumbs
/// as well as mice. It starts on the [chart] when one is showing.
Future<ExportChoice?> showExportDialog(
  BuildContext context, {
  required String title,
  bool chart = false,
}) => showDialog<ExportChoice>(
  context: context,
  builder: (context) => _ExportDialog(title: title, chart: chart),
);

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.title, required this.chart});

  final String title;
  final bool chart;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  final _settings = GetIt.I<AppSettings>();
  late var _kind = widget.chart ? ExportKind.chart : ExportKind.pivot;

  Widget _tile(ExportKind kind, ExportFormat format) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      visualDensity: VisualDensity.compact,
      leading: Icon(formatIcon(format)),
      title: Text(formatName(l10n, format)),
      trailing: Text('.${format.extension}'),
      onTap: () => Navigator.pop(context, (
        kind: kind,
        format: format,
        look: _settings.chartLook.value,
      )),
    );
  }

  /// How the chart will look, then its formats.
  List<Widget> _chart() {
    final l10n = AppLocalizations.of(context);
    final look = _settings.chartLook.value;
    void change(ChartLook look) {
      unawaited(_settings.setChartLook(look));
      setState(() {});
    }

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(l10n.themeLight)),
              ButtonSegment(value: true, label: Text(l10n.themeDark)),
            ],
            selected: {look.dark},
            onSelectionChanged: (selected) =>
                change((dark: selected.single, transparent: look.transparent)),
          ),
        ),
      ),
      CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(l10n.chartTransparent),
        value: look.transparent,
        onChanged: (value) =>
            change((dark: look.dark, transparent: value ?? false)),
      ),
      const Divider(),
      for (final f in ExportFormat.charts) _tile(ExportKind.chart, f),
    ];
  }

  List<Widget> _pivot() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return [
      for (final f in ExportFormat.pivots) _tile(ExportKind.pivot, f),
      const Divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        child: Text(
          l10n.exportSnapshot,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      _tile(ExportKind.pivot, ExportFormat.snapshot),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kinds = [
      if (widget.chart) ExportKind.chart,
      ExportKind.pivot,
      ExportKind.facts,
    ];
    return AlertDialog(
      // its top stays put, so the chips stay under the pointer from one kind
      // to the next, however many formats each has
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.fromLTRB(
        40,
        MediaQuery.sizeOf(context).height * 0.1,
        40,
        24,
      ),
      // all of it scrolls: in a low window, a list of its own under the title
      // and the chips would have room for a row or two
      scrollable: true,
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(bottom: 8),
      // as wide as its longest line where the window has room
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // chips, which wrap, as long names and large text may not fit
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
              child: Wrap(
                runSpacing: 4,
                children: [
                  for (final kind in kinds)
                    // not the Wrap's spacing, which its width leaves out
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(switch (kind) {
                          ExportKind.chart => l10n.exportChart,
                          ExportKind.pivot => l10n.exportPivot,
                          ExportKind.facts => l10n.exportFacts,
                        }),
                        selected: kind == _kind,
                        onSelected: (_) => setState(() => _kind = kind),
                      ),
                    ),
                ],
              ),
            ),
            ...switch (_kind) {
              ExportKind.chart => _chart(),
              ExportKind.pivot => _pivot(),
              ExportKind.facts => [
                for (final f in ExportFormat.tables) _tile(ExportKind.facts, f),
              ],
            },
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}

String formatName(AppLocalizations l10n, ExportFormat format) =>
    switch (format) {
      ExportFormat.xlsx => l10n.formatXlsx,
      ExportFormat.ods => l10n.formatOds,
      ExportFormat.html => l10n.formatHtml,
      ExportFormat.svg => l10n.formatSvg,
      ExportFormat.pdf => l10n.formatPdf,
      ExportFormat.csv => l10n.formatCsv,
      ExportFormat.json => l10n.formatJson,
      ExportFormat.jsonl => l10n.formatJsonl,
      ExportFormat.snapshot => l10n.formatSnapshot,
      ExportFormat.png => l10n.formatPng,
    };

IconData formatIcon(ExportFormat format) => switch (format) {
  ExportFormat.xlsx || ExportFormat.ods => Icons.grid_on,
  ExportFormat.html => Icons.public,
  ExportFormat.svg => Icons.image_outlined,
  ExportFormat.pdf => Icons.picture_as_pdf_outlined,
  ExportFormat.csv => Icons.notes,
  ExportFormat.json || ExportFormat.jsonl => Icons.data_object,
  ExportFormat.snapshot => Icons.inventory_2_outlined,
  ExportFormat.png => Icons.image_outlined,
};
