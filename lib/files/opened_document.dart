import 'dart:typed_data';

import 'package:tessera_flutter/tessera_flutter.dart';

import 'file_format.dart';

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
  });

  final String name;
  final FileFormat format;
  final Uint8List bytes;

  int get size => bytes.length;

  /// The tessera source for a tabular file, `null` for a snapshot.
  DataSource? get dataSource => format.dataSource(bytes, name: name);

  /// The decoded contents of a `.tsnp` file, `null` for tabular files.
  SnapshotContents? get snapshot => format == FileFormat.snapshot
      ? const TesseraSnapshot().decode(bytes)
      : null;
}
