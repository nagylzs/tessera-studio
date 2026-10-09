import 'dart:convert';
import 'dart:typed_data';

import 'file_format.dart';

/// Why a file that was read could not be opened, in the terms the
/// failure page explains.
enum FailureKind {
  /// A text format whose bytes are not UTF-8 — typically Excel's plain
  /// "CSV", written in a Windows code page.
  notUtf8,

  /// A spreadsheet or snapshot whose structure is broken (damaged, or
  /// another kind of file under the wrong name).
  damaged,

  /// A syntax error in JSON, JSON Lines or delimited text.
  syntax,

  /// No columns at all.
  empty,

  /// Column headings but no rows.
  noRows,

  other,
}

/// Thrown by the open flow for a source without columns or rows, which
/// would otherwise open into an empty schema page or cube.
final class EmptySourceException implements Exception {
  const EmptySourceException({required this.hasColumns});

  final bool hasColumns;

  @override
  String toString() =>
      hasColumns ? 'The source has no rows' : 'The source has no columns';
}

/// A file that was read but could not be opened or imported, as the
/// failure page shows it.
final class FileFailure {
  const FileFailure({
    required this.fileName,
    required this.kind,
    this.format,
    this.detail,
    this.rowsRead,
  });

  /// Classifies [error], thrown while opening [fileName] ([format] and
  /// [bytes] when known); [rowsRead] = rows imported before it.
  factory FileFailure.of(
    String fileName,
    Object error, {
    FileFormat? format,
    Uint8List? bytes,
    int? rowsRead,
  }) {
    final kind = switch (error) {
      EmptySourceException(:final hasColumns) =>
        hasColumns ? FailureKind.noRows : FailureKind.empty,
      _ when format != null && format.isText && !_isUtf8(bytes) =>
        FailureKind.notUtf8,
      FormatException() when format == null || format.isText =>
        FailureKind.syntax,
      FormatException() => FailureKind.damaged,
      _ => FailureKind.other,
    };
    return FileFailure(
      fileName: fileName,
      kind: kind,
      format: format,
      detail: error is EmptySourceException ? null : describe(error),
      rowsRead: rowsRead,
    );
  }

  final String fileName;
  final FailureKind kind;
  final FileFormat? format;

  /// The technical message, for the "Details" section and bug reports.
  final String? detail;

  /// Rows imported before the error, when it came during the import.
  final int? rowsRead;

  /// [error] as one line: a [FormatException]'s message without the type
  /// names stacked in front of it.
  static String describe(Object error) {
    var text = error.toString();
    const prefix = 'FormatException: ';
    while (text.startsWith(prefix)) {
      text = text.substring(prefix.length);
    }
    return text;
  }

  static bool _isUtf8(Uint8List? bytes) {
    if (bytes == null) return true;
    try {
      utf8.decode(bytes);
      return true;
    } on FormatException {
      return false;
    }
  }
}
