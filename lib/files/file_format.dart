import 'dart:typed_data';

import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_ods/tessera_ods.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

/// The file types Tessera Studio opens, keyed by extension.
///
/// Every tabular format maps to a tessera [DataSource]; [snapshot] is the
/// engine's own `.tsnp` container (a [FactTable] plus an optional
/// [CubeConfig]) and is decoded with [TesseraSnapshot] instead.
enum FileFormat {
  csv(['csv', 'txt']),
  tsv(['tsv', 'tab']),
  xlsx(['xlsx']),
  ods(['ods']),
  json(['json']),
  jsonl(['jsonl', 'ndjson']),
  snapshot([
    'tsnp',
  ]); // TesseraSnapshot.fileExtension once tessera > 0.2.1 is published

  const FileFormat(this.extensions);

  /// Lower-case extensions without the dot; the first one is canonical.
  final List<String> extensions;

  /// Every extension of every format, for file-picker filters.
  static List<String> get allExtensions => [
    for (final f in values) ...f.extensions,
  ];

  /// The format for [fileName] by its extension, or `null` when unknown.
  static FileFormat? ofFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = fileName.substring(dot + 1).toLowerCase();
    for (final f in values) {
      if (f.extensions.contains(ext)) return f;
    }
    return null;
  }

  /// A [DataSource] reading [bytes] already in memory, so the result is
  /// sendable to an import isolate. `null` for [snapshot].
  DataSource? dataSource(Uint8List bytes, {required String name}) =>
      switch (this) {
        csv => CsvDataSource.fromData(bytes, name: name),
        tsv => CsvDataSource.fromData(
          bytes,
          name: name,
          options: const CsvOptions(delimiter: '\t'),
        ),
        xlsx => XlsxDataSource.fromData(bytes, name: name),
        ods => OdsDataSource.fromData(bytes, name: name),
        json => JsonDataSource.fromData(bytes, name: name),
        jsonl => JsonlDataSource.fromData(bytes, name: name),
        snapshot => null,
      };
}
