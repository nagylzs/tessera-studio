import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../files/clipboard_reader.dart';
import '../files/document_loader.dart';
import '../files/file_opener.dart';
import '../files/open_requests.dart';
import '../files/opened_document.dart';
import 'schema_store.dart';

/// Why opening or loading did not produce a document.
sealed class OpenFailure {
  const OpenFailure(this.fileName);

  final String fileName;
}

final class UnsupportedFile extends OpenFailure {
  const UnsupportedFile(super.fileName);
}

final class OpenError extends OpenFailure {
  const OpenError(super.fileName, this.error);

  final Object error;
}

/// The clipboard was empty or held nothing that can be opened.
final class NothingToOpen extends OpenFailure {
  const NothingToOpen() : super('');
}

/// The screens of the viewer, in the order a file passes through them.
enum AppPage { home, schema, workbench }

/// What inference found out about the open document's source (`null`
/// for a snapshot, which carries its schema).
final class SourceInfo {
  const SourceInfo({
    required this.columnNames,
    required this.samples,
    required this.inferred,
  });

  final List<String> columnNames;

  /// The first few rows, shown raw next to each column on the schema page.
  final List<SourceRow> samples;
  final Schema inferred;

  String get structureKey => inferred.structureKey;
}

/// Application-wide state: the one document the viewer shows and where
/// it is in the open → schema → workbench flow.
final class AppState {
  /// How many source rows the schema page shows as samples.
  static const sampleRows = 5;

  /// The open document, `null` on the home screen.
  final document = signal<OpenedDocument?>(null);

  final page = signal(AppPage.home);

  /// Where the schema page returns to on cancel: home right after
  /// opening, the workbench when opened from there.
  final schemaBack = signal(AppPage.home);

  /// `true` while the picker is up or the picked file is being read.
  final opening = signal(false);

  /// Progress of a load or of the inference that follows it, `null`
  /// when nothing is being loaded.
  final loading = signal<LoadProgress?>(null);

  /// Why the last load failed; shown on the home screen until the next
  /// attempt.
  final loadFailure = signal<OpenFailure?>(null);

  final source = signal<SourceInfo?>(null);

  /// The schema in force: inferred, restored from the store, or edited.
  final schema = signal<Schema?>(null);

  /// The stored schema that was applied automatically, until dismissed.
  final restored = signal<StoredSchema?>(null);

  /// Shows the picker and opens the chosen file. Returns `null` on
  /// success or cancel, a failure otherwise.
  Future<OpenFailure?> openFile() async {
    if (opening.value) return null;
    opening.value = true;
    try {
      final doc = await GetIt.I<FileOpener>().pick();
      if (doc != null) await _open(doc);
      return null;
    } on UnsupportedFileException catch (e) {
      return UnsupportedFile(e.fileName);
    } catch (e) {
      return OpenError('', e);
    } finally {
      opening.value = false;
    }
  }

  /// Reads a file path or URL (the command-line argument, or a file the
  /// system handed us) with progress and opens it; a failure lands in
  /// [loadFailure]. [name] overrides the name derived from [source].
  Future<void> loadFrom(String source, {String? name}) async {
    final loader = GetIt.I<DocumentLoader>();
    name ??= loader.nameOf(source);
    loadFailure.value = null;
    loading.value = LoadProgress(name: name);
    final OpenedDocument doc;
    try {
      doc = await loader.load(
        source,
        name: name,
        onProgress: (p) => loading.value = p,
      );
    } on UnsupportedFileException catch (e) {
      loading.value = null;
      loadFailure.value = UnsupportedFile(e.fileName);
      return;
    } catch (e) {
      loading.value = null;
      loadFailure.value = OpenError(name, e);
      return;
    }
    await _open(doc);
  }

  /// Whether "Open from clipboard" is enabled; see [refreshClipboard].
  final clipboardAvailable = signal(true);

  Future<void> refreshClipboard() async {
    clipboardAvailable.value = await GetIt.I<ClipboardReader>().hasText();
  }

  /// Opens what the clipboard holds: a URL or file path on a single
  /// line is loaded like a command-line argument, anything else is
  /// treated as tabular text named [clipboardName]. Failures land in
  /// [loadFailure]; nothing usable is [NothingToOpen].
  Future<void> openFromClipboard(String clipboardName) async {
    loadFailure.value = null;
    final text = (await GetIt.I<ClipboardReader>().readText())?.trim();
    if (text == null || text.isEmpty) {
      loadFailure.value = const NothingToOpen();
      return;
    }
    final source = clipboardSource(text);
    if (source != null) return loadFrom(source);
    final OpenedDocument doc;
    try {
      doc = OpenedDocument.detect(
        name: clipboardName,
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
    } on UnsupportedFileException {
      loadFailure.value = const NothingToOpen();
      return;
    }
    await _open(doc);
  }

  /// A single-line clipboard [text] that names something to load — an
  /// http(s) URL, a `file:` URL (as a path) or an absolute path — else
  /// `null` (the text is data, or nothing).
  static String? clipboardSource(String text) {
    if (text.contains('\n') || text.contains('\r')) return null;
    final uri = Uri.tryParse(text);
    if (uri != null) {
      if (uri.scheme == 'http' || uri.scheme == 'https') return text;
      if (uri.scheme == 'file') return uri.toFilePath();
    }
    if (text.startsWith('/') ||
        text.startsWith(r'\\') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(text)) {
      return text;
    }
    return null;
  }

  /// Opens a file dropped on the window: by path through [loadFrom]
  /// where there is one (desktop), else from its bytes (the web).
  Future<void> openDropped(XFile file) async {
    final name = file.name.isEmpty ? null : file.name;
    if (!kIsWeb && file.path.isNotEmpty) return loadFrom(file.path, name: name);
    final label = name ?? 'file';
    loadFailure.value = null;
    loading.value = LoadProgress(name: label);
    try {
      final doc = OpenedDocument.detect(
        name: label,
        bytes: await file.readAsBytes(),
      );
      await _open(doc);
    } on UnsupportedFileException catch (e) {
      loadFailure.value = UnsupportedFile(e.fileName);
    } catch (e) {
      loadFailure.value = OpenError(label, e);
    } finally {
      loading.value = null;
    }
  }

  /// Handles what the platform side reports for a file the system asked
  /// us to open: progress while it is being copied, then [loadFrom].
  void handleOpenRequest(OpenRequest request) {
    switch (request) {
      case OpenStarted(:final name):
        loadFailure.value = null;
        loading.value = LoadProgress(name: name);
      case OpenReady(:final name, :final path):
        loadFrom(path, name: name);
      case OpenRequestFailed(:final name, :final error):
        loading.value = null;
        loadFailure.value = OpenError(name, error);
    }
  }

  /// Makes [doc] the document and takes it to the schema page, or
  /// straight to the workbench when a schema is stored for its
  /// structure (or it is a snapshot). Inference failures go to
  /// [loadFailure] and leave the home screen up.
  Future<void> _open(OpenedDocument doc) async {
    loadFailure.value = null;
    loading.value = LoadProgress(name: doc.name);
    try {
      await _prepare(doc);
      document.value = doc;
    } catch (e) {
      loadFailure.value = OpenError(doc.name, e);
    } finally {
      loading.value = null;
    }
  }

  Future<void> _prepare(OpenedDocument doc) async {
    final snapshot = doc.snapshot;
    if (snapshot != null) {
      source.value = null;
      schema.value = snapshot.facts.schema;
      restored.value = null;
      page.value = AppPage.workbench;
      return;
    }
    final src = doc.dataSource!;
    final columnNames = await src.columnNames();
    final samples = await src.rows().take(sampleRows).toList();
    final inferred = await inferSchema(src);
    final info = SourceInfo(
      columnNames: columnNames,
      samples: samples,
      inferred: inferred,
    );
    final stored = await _store.read(info.structureKey);
    source.value = info;
    if (stored != null) {
      schema.value = stored.schema;
      restored.value = stored;
      page.value = AppPage.workbench;
    } else {
      schema.value = inferred;
      restored.value = null;
      schemaBack.value = AppPage.home;
      page.value = AppPage.schema;
    }
  }

  /// The schema page's "Continue": [edited] is the schema from now on
  /// and is remembered for this structure — or forgotten when it equals
  /// the inferred one.
  Future<void> acceptSchema(Schema edited) async {
    schema.value = edited;
    restored.value = null;
    page.value = AppPage.workbench;
    final info = source.value;
    if (info == null) return;
    if (sameSchema(edited, info.inferred)) {
      await _store.delete(info.structureKey);
    } else {
      await _store.write(
        info.structureKey,
        StoredSchema(edited, savedAt: DateTime.now()),
      );
    }
  }

  /// The banner's "Reset to inferred": forgets the stored schema and
  /// shows the inferred one on the schema page.
  Future<void> resetToInferred() async {
    final info = source.value;
    if (info == null) return;
    schema.value = info.inferred;
    restored.value = null;
    schemaBack.value = AppPage.workbench;
    page.value = AppPage.schema;
    await _store.delete(info.structureKey);
  }

  void dismissRestored() => restored.value = null;

  /// The workbench's "Schema…".
  void editSchema() {
    if (source.value == null) return;
    schemaBack.value = AppPage.workbench;
    page.value = AppPage.schema;
  }

  /// The schema page's back/close: discard edits.
  void cancelSchema() {
    if (schemaBack.value == AppPage.workbench) {
      page.value = AppPage.workbench;
    } else {
      closeFile();
    }
  }

  void closeFile() {
    document.value = null;
    source.value = null;
    schema.value = null;
    restored.value = null;
    page.value = AppPage.home;
  }

  SchemaStore get _store => GetIt.I<SchemaStore>();

  /// Whether [a] and [b] are the same schema in everything the store
  /// keeps (types, inclusion, labels, formats, syntax, null values).
  static bool sameSchema(Schema a, Schema b) {
    const codec = CubeJson.standard;
    return jsonEncode(codec.encodeSchema(a)) ==
        jsonEncode(codec.encodeSchema(b));
  }
}
