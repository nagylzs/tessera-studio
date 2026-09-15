import 'package:file_picker/file_picker.dart';

import 'file_format.dart';
import 'opened_document.dart';

/// The picked file has an extension no [FileFormat] claims.
final class UnsupportedFileException implements Exception {
  const UnsupportedFileException(this.fileName);

  final String fileName;

  @override
  String toString() => 'UnsupportedFileException: $fileName';
}

/// Lets the user choose a file and reads it. Registered in get_it so the
/// UI can be tested with a fake.
abstract interface class FileOpener {
  /// Shows the picker; `null` when the user cancels. Throws
  /// [UnsupportedFileException] for an unknown extension.
  Future<OpenedDocument?> pick();
}

/// The real thing: the platform file dialog through `file_picker`.
final class PickerFileOpener implements FileOpener {
  const PickerFileOpener();

  @override
  Future<OpenedDocument?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: FileFormat.allExtensions,
    );
    if (file == null) return null;
    return OpenedDocument.detect(
      name: file.name,
      bytes: await file.readAsBytes(),
    );
  }
}
