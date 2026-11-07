import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Where an export goes: a file the user picks, or the share sheet.
/// Registered in get_it; tests register a fake.
abstract interface class ExportTarget {
  /// Whether [share] is offered: phones and tablets, and the Mac, whose
  /// share menu gives Mail the file. Not Windows, where share_plus's dialog
  /// can stay on screen after the app is gone, nor Linux (TODO.md).
  bool get canShare;

  /// Whether sharing is the usual way out, with Save as… in the menu: phones
  /// and tablets. Elsewhere the two sit side by side.
  bool get sharesFirst;

  /// Writes [bytes] where the user says in the platform's save dialog;
  /// the saved file's Uri (`file:` on desktops, `content:` on Android, a
  /// download on the web), or `null` when cancelled.
  Future<Uri?> save(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
    String? dialogTitle,
  });

  /// Hands [bytes] to the share sheet as a file named [fileName]. On an
  /// iPad the sheet is a popover that points at [origin] (in global
  /// coordinates), the button that asked for it; share_plus refuses to
  /// share there without one.
  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
    Rect? origin,
  });
}

/// `file_picker` writes the bytes itself (Android and iOS give a
/// document Uri, not a path); `share_plus` shares them.
final class PlatformExportTarget implements ExportTarget {
  const PlatformExportTarget();

  @override
  bool get canShare => sharesFirst || _macOS;

  @override
  bool get sharesFirst =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _macOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

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
    Rect? origin,
  }) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      // the IO XFile.fromData ignores its name
      fileNameOverrides: [fileName],
      sharePositionOrigin: origin,
    ),
  );
}
