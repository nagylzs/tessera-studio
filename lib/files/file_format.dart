import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_ods/tessera_ods.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

/// The file types Tessera Studio opens.
///
/// A format is found from the file name ([ofFileName]), else from an
/// HTTP media type ([ofMimeType]), else from the bytes themselves
/// ([ofBytes]). Every tabular format maps to a tessera [DataSource];
/// [snapshot] is the engine's own `.tsnp` container (a [FactTable] plus
/// an optional [CubeConfig]) and is decoded with [TesseraSnapshot].
enum FileFormat {
  /// Delimited text; the delimiter is sniffed ([sniffDelimiter]), so a
  /// semicolon-separated export is a CSV too.
  csv(['csv', 'txt'], ['text/csv', 'text/comma-separated-values']),
  tsv(['tsv', 'tab'], ['text/tab-separated-values']),
  xlsx(
    ['xlsx'],
    ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
  ),
  ods(['ods'], ['application/vnd.oasis.opendocument.spreadsheet']),
  json(['json'], ['application/json']),
  jsonl(
    ['jsonl', 'ndjson'],
    ['application/x-ndjson', 'application/jsonl', 'application/x-jsonlines'],
  ),
  // TesseraSnapshot.fileExtension / .mimeType once tessera > 0.2.1 is
  // published.
  snapshot(['tsnp'], ['application/vnd.tessera.snapshot']);

  const FileFormat(this.extensions, this.mimeTypes);

  /// Lower-case extensions without the dot; the first one is canonical.
  final List<String> extensions;

  /// Media types that mean this format; the first one is canonical.
  final List<String> mimeTypes;

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

  /// The format for a media type such as `text/csv; charset=utf-8`, or
  /// `null` when it says nothing useful (`text/plain`,
  /// `application/octet-stream`, absent).
  static FileFormat? ofMimeType(String? mimeType) {
    if (mimeType == null) return null;
    final bare = mimeType.split(';').first.trim().toLowerCase();
    for (final f in values) {
      if (f.mimeTypes.contains(bare)) return f;
    }
    return null;
  }

  /// How many leading bytes [ofBytes] and [sniffDelimiter] look at.
  static const sniffLength = 64 * 1024;

  /// The format the bytes themselves reveal, or `null`: a snapshot by its
  /// magic, XLSX and ODS by their zip contents, JSON by its first
  /// character (`[` an array, `{` JSON Lines), and text with a delimiter
  /// or more than one line as [csv] / [tsv]. A single line without a
  /// delimiter, binary data and malformed UTF-8 are `null`.
  static FileFormat? ofBytes(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x54 && // T
        bytes[1] == 0x53 && // S
        bytes[2] == 0x4E && // N
        bytes[3] == 0x50) {
      // P
      return snapshot;
    }
    if (bytes.length >= 30 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 3 &&
        bytes[3] == 4) {
      return _ofZip(bytes);
    }
    final text = textPrefix(bytes);
    if (text == null) return null;
    final t = text.trimLeft();
    if (t.isEmpty) return null;
    if (t.startsWith('[')) return json;
    if (t.startsWith('{')) return jsonl;
    final delimiter = sniffDelimiter(text);
    if (delimiter == '\t') return tsv;
    if (delimiter != null) return csv;
    final lines = LineSplitter.split(t).where((l) => l.trim().isNotEmpty);
    return lines.length > 1 ? csv : null;
  }

  /// The first zip entry tells: ODS stores `mimetype` first (uncompressed,
  /// its content the media type), XLSX starts with `[Content_Types].xml`
  /// or its `_rels` / `xl/` parts.
  static FileFormat? _ofZip(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final nameLength = data.getUint16(26, Endian.little);
    final extraLength = data.getUint16(28, Endian.little);
    final nameStart = 30;
    if (bytes.length < nameStart + nameLength) return null;
    final name = ascii.decode(
      bytes.sublist(nameStart, nameStart + nameLength),
      allowInvalid: true,
    );
    if (name == 'mimetype') {
      final size = data.getUint32(22, Endian.little);
      final start = nameStart + nameLength + extraLength;
      if (bytes.length < start + size) return null;
      final mime = ascii.decode(
        bytes.sublist(start, start + size),
        allowInvalid: true,
      );
      return ofMimeType(mime);
    }
    if (name == '[Content_Types].xml' ||
        name.startsWith('_rels/') ||
        name.startsWith('xl/') ||
        name.startsWith('docProps/')) {
      return xlsx;
    }
    return null;
  }

  /// The leading bytes as text, or `null` when they are not UTF-8 text
  /// (a lone replacement character at the very end is a cut multi-byte
  /// sequence and is tolerated; control characters other than tab, CR
  /// and LF are not).
  static String? textPrefix(Uint8List bytes) {
    final end = math.min(bytes.length, sniffLength);
    if (end == 0) return null;
    var text = utf8.decode(bytes.sublist(0, end), allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    final bad = '�'.allMatches(text).length;
    if (bad > 1 || (bad == 1 && !text.endsWith('�'))) return null;
    for (final unit in text.codeUnits) {
      if (unit < 0x20 && unit != 0x09 && unit != 0x0A && unit != 0x0D) {
        return null;
      }
    }
    return text;
  }

  /// The delimiter of delimited [text]: tab, semicolon, comma or pipe,
  /// whichever occurs on every one of the first lines most consistently.
  /// `null` when none does (a single column, or not a table).
  static String? sniffDelimiter(String text) {
    final lines = LineSplitter.split(text)
        .where((l) => l.trim().isNotEmpty)
        .take(20)
        .toList();
    if (lines.isEmpty) return null;
    String? best;
    var bestScore = 0;
    for (final d in const ['\t', ';', ',', '|']) {
      final counts = [for (final l in lines) d.allMatches(l).length];
      final min = counts.reduce(math.min);
      if (min == 0) continue;
      final consistent = counts.every((c) => c == counts.first);
      final score = min * (consistent ? 2 : 1);
      if (score > bestScore) {
        best = d;
        bestScore = score;
      }
    }
    return best;
  }

  /// A [DataSource] reading [bytes] already in memory, so the result is
  /// sendable to an import isolate. [delimiter] applies to [csv] only.
  /// `null` for [snapshot].
  DataSource? dataSource(
    Uint8List bytes, {
    required String name,
    String? delimiter,
  }) => switch (this) {
    csv => CsvDataSource.fromData(
      bytes,
      name: name,
      options: CsvOptions(delimiter: delimiter ?? ','),
    ),
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
