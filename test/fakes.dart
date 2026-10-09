import 'dart:async';
import 'dart:typed_data';

import 'package:tessera_studio/export/export_target.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/platform/links.dart';
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

/// Records what was saved or shared; [saveTo] is what the save dialog
/// "picks" (`null` = cancelled), [error] makes both throw.
final class FakeExportTarget implements ExportTarget {
  FakeExportTarget({this.canShare = false});

  @override
  final bool canShare;
  Uri? saveTo;
  Object? error;
  final saved = <({String fileName, String mimeType, Uint8List bytes})>[];
  final shared = <({String fileName, String mimeType, Uint8List bytes})>[];

  @override
  Future<Uri?> save(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
    String? dialogTitle,
  }) async {
    if (error case final e?) throw e;
    saved.add((fileName: fileName, mimeType: mimeType, bytes: bytes));
    return saveTo;
  }

  @override
  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    if (error case final e?) throw e;
    shared.add((fileName: fileName, mimeType: mimeType, bytes: bytes));
  }
}

/// Records the links the app asked the browser to open.
final class FakeLinkOpener implements LinkOpener {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
