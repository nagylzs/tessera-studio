import 'package:tessera_flutter/tessera_flutter.dart' show TesseraSnapshot;

/// What is exported; each has its own formats in [ExportFormat].
enum ExportKind { chart, pivot, facts }

/// What an export writes: the cube as shown in one of [pivots], the facts
/// behind it as a plain table in one of [tables], or both at once in a
/// [snapshot], which Tessera Studio reopens as it was; the chart in one
/// of [charts].
enum ExportFormat {
  xlsx(
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  ods('ods', 'application/vnd.oasis.opendocument.spreadsheet'),
  html('html', 'text/html'),
  svg('svg', 'image/svg+xml'),
  pdf('pdf', 'application/pdf'),
  csv('csv', 'text/csv'),
  json('json', 'application/json'),
  jsonl('jsonl', 'application/x-ndjson'),
  snapshot(TesseraSnapshot.fileExtension, TesseraSnapshot.mimeType),
  png('png', 'image/png');

  const ExportFormat(this.extension, this.mimeType);

  /// The formats the cube exports to as it is shown.
  static const pivots = [xlsx, ods, html, svg, pdf, csv, json, jsonl];

  /// The formats the facts export to as a table.
  static const tables = [xlsx, ods, csv, jsonl];

  /// The formats the chart exports to. fl_chart draws on a canvas only, so
  /// no vector format yet (TODO.md).
  static const charts = [png];

  final String extension;
  final String mimeType;
}
