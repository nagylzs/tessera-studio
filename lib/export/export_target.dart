import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Where an export goes: a file the user picks, or the share sheet.
/// Registered in get_it; tests register a fake.
abstract interface class ExportTarget {
  /// Whether [share] is offered: phones and tablets, where sending a
  /// file to another app is the usual way out.
  bool get canShare;

  /// Writes [bytes] where the user says in the platform's save dialog;
  /// the saved file's Uri (`file:` on desktops, `content:` on Android, a
  /// download on the web), or `null` when cancelled.
  Future<Uri?> save(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
    String? dialogTitle,
  });

  /// Hands [bytes] to the share sheet as a file named [fileName].
  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  });
}

/// `file_picker` writes the bytes itself (Android and iOS give a
/// document Uri, not a path); `share_plus` shares them.
final class PlatformExportTarget implements ExportTarget {
  const PlatformExportTarget();

  @override
  bool get canShare =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<Uri?> save(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
    String? dialogTitle,
  }) => FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: dialogTitle,
  );

  @override
  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      // the IO XFile.fromData ignores its name
      fileNameOverrides: [fileName],
    ),
  );
}
