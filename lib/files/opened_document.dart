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

  int get size => bytes.length;

  /// The tessera source for a tabular file, `null` for a snapshot.
  DataSource? get dataSource =>
      format.dataSource(bytes, name: name, delimiter: delimiter);

  /// The decoded contents of a `.tsnp` file, `null` for tabular files.
  SnapshotContents? get snapshot => format == FileFormat.snapshot
      ? const TesseraSnapshot().decode(bytes)
      : null;
}
