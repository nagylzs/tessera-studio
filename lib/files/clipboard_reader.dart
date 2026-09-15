import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plain text from the system clipboard. Registered in get_it so the UI
/// can be tested with a fake. Files copied as file objects (Explorer,
/// Finder) are not text and stay invisible here; see TODO.md.
abstract interface class ClipboardReader {
  /// Whether there is text to read, without reading it (no "pasted
  /// from" notice on mobile). Always `true` on the web, which cannot
  /// tell without a user gesture.
  Future<bool> hasText();

  Future<String?> readText();
}

final class SystemClipboardReader implements ClipboardReader {
  const SystemClipboardReader();

  @override
  Future<bool> hasText() async {
    if (kIsWeb) return true;
    try {
      return await Clipboard.hasStrings();
    } on Object {
      return true;
    }
  }

  @override
  Future<String?> readText() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } on Object {
      return null;
    }
  }
}
