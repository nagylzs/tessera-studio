/// What an export writes: the cube as shown in any of these, or the
/// facts behind it as a plain table in one of [tables].
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
  jsonl('jsonl', 'application/x-ndjson');

  const ExportFormat(this.extension, this.mimeType);

  /// The formats the facts export to as a table.
  static const tables = [xlsx, ods, csv, jsonl];

  final String extension;
  final String mimeType;
}
