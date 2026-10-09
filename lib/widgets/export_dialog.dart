import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../export/export_format.dart';
import '../export/export_target.dart';
import '../export/exports.dart';
import '../l10n/generated/app_localizations.dart';
import '../style/grid_style.dart';

/// A format from the export dialog; [facts] = the facts as a table
/// rather than the cube.
typedef ExportChoice = ({ExportFormat format, bool facts});

/// Asks for a format, writes the export of [cube] (with the [aggregates]
/// the grid shows, in its [style]) and shares it ([share]) or saves it
/// where the user says; the outcome goes to a snack bar. [onBusy] brackets the writing,
/// which runs on this isolate like the cube layout does.
Future<void> runExport(
  BuildContext context, {
  required String documentName,
  required Cube cube,
  List<Aggregate>? aggregates,
  GridStyle style = GridStyle.standard,
  required bool share,
  required ValueChanged<bool> onBusy,
}) async {
  final l10n = AppLocalizations.of(context);
  final strings = TesseraLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final title = (share ? l10n.share : l10n.saveAs).replaceAll('…', '');
  final choice = await showExportDialog(context, title: title);
  if (choice == null) return;
  final base = documentName.replaceFirst(RegExp(r'\.[^.]*$'), '');
  final format = choice.format;
  final fileName =
      '${choice.facts ? l10n.factsFileName(base) : l10n.pivotFileName(base)}'
      '.${format.extension}';
  final target = GetIt.I<ExportTarget>();
  try {
    onBusy(true);
    final Uint8List bytes;
    try {
      // let the progress bar paint before the work holds the isolate
      await WidgetsBinding.instance.endOfFrame;
      bytes = choice.facts
          ? factsExport(cube, format, title: base)
          : await cubeExport(
              cube,
              format,
              title: base,
              strings: strings,
              aggregates: aggregates,
              style: style,
            );
    } finally {
      onBusy(false);
    }
    if (share) {
      await target.share(bytes, fileName: fileName, mimeType: format.mimeType);
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

/// Every format, the cube's first, then the facts' as a table. A
/// dialog rather than a menu: thumbs as well as mice.
Future<ExportChoice?> showExportDialog(
  BuildContext context, {
  required String title,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<ExportChoice>(
    context: context,
    builder: (context) {
      final heading = Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary);
      Widget header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
        child: Text(text, style: heading),
      );
      Widget tile(ExportFormat format, {required bool facts}) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(formatIcon(format)),
        title: Text(formatName(l10n, format)),
        trailing: Text('.${format.extension}'),
        onTap: () => Navigator.pop(context, (format: format, facts: facts)),
      );
      return AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.only(bottom: 8),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              header(l10n.exportPivot),
              for (final f in ExportFormat.values) tile(f, facts: false),
              const Divider(),
              header(l10n.exportFacts),
              for (final f in ExportFormat.tables) tile(f, facts: true),
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
    },
  );
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
    };

IconData formatIcon(ExportFormat format) => switch (format) {
  ExportFormat.xlsx || ExportFormat.ods => Icons.grid_on,
  ExportFormat.html => Icons.public,
  ExportFormat.svg => Icons.image_outlined,
  ExportFormat.pdf => Icons.picture_as_pdf_outlined,
  ExportFormat.csv => Icons.notes,
  ExportFormat.json || ExportFormat.jsonl => Icons.data_object,
};
