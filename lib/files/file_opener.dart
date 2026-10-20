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

/// The platform's file dialog could not be shown at all — on Linux,
/// where `file_picker` talks to xdg-desktop-portal over D-Bus with no
/// fallback, because no portal is running.
final class PickerUnavailableException implements Exception {
  const PickerUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'PickerUnavailableException: $cause';
}

/// Lets the user choose a file and reads it. Registered in get_it so the
/// UI can be tested with a fake.
abstract interface class FileOpener {
  /// Shows the picker, with [dialogTitle] where the platform shows a
  /// title; `null` when the user cancels. Throws
  /// [UnsupportedFileException] for an unknown extension and
  /// [PickerUnavailableException] when there is no dialog to show.
  Future<OpenedDocument?> pick({String? dialogTitle});
}

/// The real thing: the platform file dialog through `file_picker`.
final class PickerFileOpener implements FileOpener {
  const PickerFileOpener();

  @override
  Future<OpenedDocument?> pick({String? dialogTitle}) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: dialogTitle,
        type: FileType.custom,
        allowedExtensions: FileFormat.allExtensions,
      );
    } catch (e) {
      throw PickerUnavailableException(e);
    }
    if (file == null) return null;
    return OpenedDocument.detect(
      name: file.name,
      bytes: await file.readAsBytes(),
    );
  }
}
