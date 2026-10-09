import 'dart:async';

import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/platform/system_bars.dart';

final class FakeClipboard implements ClipboardReader {
  FakeClipboard([this.text]);

  String? text;

  @override
  Future<bool> hasText() async => text != null && text!.isNotEmpty;

  @override
  Future<String?> readText() async => text;
}

/// A loader whose result the test completes; records what was asked.
final class FakeLoader implements DocumentLoader {
  /// Created lazily, on the first [load] — inside `runAsync`, so that
  /// completing it wakes real-async code and not the fake clock.
  late final completer = Completer<OpenedDocument>();
  LoadProgressCallback? onProgress;
  String? loadedSource;
  String? loadedName;

  @override
  String nameOf(String source) => source.split('/').last;

  @override
  Future<OpenedDocument> load(
    String source, {
    String? name,
    LoadProgressCallback? onProgress,
  }) {
    loadedSource = source;
    loadedName = name;
    this.onProgress = onProgress;
    return completer.future;
  }
}

/// Records whether the system bars are shown and every call.
final class FakeSystemBars implements SystemBars {
  final calls = <String>[];
  bool get hidden => calls.isNotEmpty && calls.last == 'hide';

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> show() async => calls.add('show');
}
