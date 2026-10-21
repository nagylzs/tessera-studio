import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'file_format.dart';
import 'opened_document.dart';

/// The picked file is in no [FileFormat]: neither its extension nor its
/// first bytes tell one.
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
  /// [UnsupportedFileException] for a file in no known format and
  /// [PickerUnavailableException] when there is no dialog to show.
  Future<OpenedDocument?> pick({String? dialogTitle});
}

/// The real thing: the platform file dialog through `file_picker`.
final class PickerFileOpener implements FileOpener {
  const PickerFileOpener();

  @override
  Future<OpenedDocument?> pick({String? dialogTitle}) async {
    // Android's picker filters by the media type it has on record for a
    // file, not by its name: extensions the device does not know (.tsnp,
    // .jsonl) drop out of the filter, so their files are greyed out, and
    // so is a CSV that a website served as Excel. There every file can be
    // picked, and the detection below turns down what is not ours.
    final filter = kIsWeb || defaultTargetPlatform != TargetPlatform.android;
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: dialogTitle,
        type: filter ? FileType.custom : FileType.any,
        allowedExtensions: filter ? FileFormat.allExtensions : null,
      );
    } catch (e) {
      throw PickerUnavailableException(e);
    }
    if (file == null) return null;
    // A name that says nothing is judged by its first bytes, so a film
    // picked by mistake is not read whole into memory.
    if (FileFormat.ofFileName(file.name) == null &&
        FileFormat.ofBytes(await _head(file)) == null) {
      throw UnsupportedFileException(file.name);
    }
    return OpenedDocument.detect(
      name: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  /// The first [FileFormat.sniffLength] bytes of [file], or all of a
  /// shorter one.
  static Future<Uint8List> _head(PlatformFile file) async {
    final head = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      head.add(chunk);
      if (head.length >= FileFormat.sniffLength) break;
    }
    final bytes = head.takeBytes();
    return bytes.length > FileFormat.sniffLength
        ? Uint8List.sublistView(bytes, 0, FileFormat.sniffLength)
        : bytes;
  }
}
