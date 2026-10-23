import 'dart:typed_data';

import 'package:tessera_flutter/tessera_flutter.dart';

import 'file_format.dart';
import 'file_opener.dart';

/// A file the user opened: its name, detected format and full contents.
///
/// The bytes are kept in memory because that is the only thing every
/// platform can hand us (web and Android content URIs have no path), and
/// because in-memory sources can be sent to the import isolate as they
/// are.
final class OpenedDocument {
  const OpenedDocument({
    required this.name,
    required this.format,
    required this.bytes,
    this.delimiter,
    this.sheet,
    this.sheets = const [],
  });

  /// Finds the format from [name], else [mimeType], else the [bytes]
  /// ([FileFormat.ofBytes]), and sniffs the delimiter of delimited text.
  /// Throws [UnsupportedFileException] when nothing recognises the file.
  factory OpenedDocument.detect({
    required String name,
    required Uint8List bytes,
    String? mimeType,
  }) {
    final format =
        FileFormat.ofFileName(name) ??
        FileFormat.ofMimeType(mimeType) ??
        FileFormat.ofBytes(bytes);
    if (format == null) throw UnsupportedFileException(name);
    String? delimiter;
    if (format == FileFormat.csv) {
      final text = FileFormat.textPrefix(bytes);
      delimiter = text == null ? null : FileFormat.sniffDelimiter(text);
    }
    return OpenedDocument(
      name: name,
      format: format,
      bytes: bytes,
      delimiter: delimiter,
    );
  }

  final String name;
  final FileFormat format;
  final Uint8List bytes;

  /// The sniffed delimiter of a [FileFormat.csv] file, `null` for the
  /// default comma and for other formats.
  final String? delimiter;

  /// The sheet of a workbook that is shown, `null` before one is chosen
  /// (the first is read) and for the other formats.
  final String? sheet;

  /// The sheets of a workbook there is something to show on — not
  /// hidden, not empty —, in workbook order. The user can switch between
  /// them when there are several.
  final List<String> sheets;

  int get size => bytes.length;

  /// The same file showing [sheet] of [sheets] (default: this one's).
  OpenedDocument withSheet(String sheet, {List<String>? sheets}) =>
      OpenedDocument(
        name: name,
        format: format,
        bytes: bytes,
        delimiter: delimiter,
        sheet: sheet,
        sheets: sheets ?? this.sheets,
      );

  /// The file name, followed by the sheet's when the workbook has
  /// several.
  String get title =>
      sheets.length > 1 && sheet != null ? '$name - $sheet' : name;

  /// The name exports start from: the file name without its extension,
  /// followed by the sheet's when the workbook has several.
  String get exportBaseName {
    final base = name.replaceFirst(RegExp(r'\.[^.]*$'), '');
    return sheets.length > 1 && sheet != null ? '$base - $sheet' : base;
  }

  /// The tessera source for a tabular file, `null` for a snapshot.
  DataSource? get dataSource =>
      format.dataSource(bytes, name: name, delimiter: delimiter, sheet: sheet);

  /// The decoded contents of a `.tsnp` file, `null` for tabular files.
  SnapshotContents? get snapshot => format == FileFormat.snapshot
      ? const TesseraSnapshot().decode(bytes)
      : null;
}
