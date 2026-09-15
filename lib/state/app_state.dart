import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../files/document_loader.dart';
import '../files/file_opener.dart';
import '../files/opened_document.dart';

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

/// Application-wide state: the one document the viewer shows.
final class AppState {
  /// The open document, `null` on the home screen.
  final document = signal<OpenedDocument?>(null);

  /// `true` while the picker is up or the picked file is being read.
  final opening = signal(false);

  /// Progress of [loadFrom], `null` when nothing is being loaded.
  final loading = signal<LoadProgress?>(null);

  /// Why the last [loadFrom] failed; shown on the home screen until the
  /// next attempt.
  final loadFailure = signal<OpenFailure?>(null);

  /// Shows the picker and makes the chosen file the [document].
  /// Returns `null` on success or cancel, a failure otherwise.
  Future<OpenFailure?> openFile() async {
    if (opening.value) return null;
    opening.value = true;
    try {
      final doc = await GetIt.I<FileOpener>().pick();
      if (doc != null) document.value = doc;
      return null;
    } on UnsupportedFileException catch (e) {
      return UnsupportedFile(e.fileName);
    } catch (e) {
      return OpenError('', e);
    } finally {
      opening.value = false;
    }
  }

  /// Reads a file path or URL (the command-line argument) with progress
  /// and makes it the [document]; a failure lands in [loadFailure].
  Future<void> loadFrom(String source) async {
    final loader = GetIt.I<DocumentLoader>();
    final name = loader.nameOf(source);
    loadFailure.value = null;
    loading.value = LoadProgress(name: name);
    try {
      document.value = await loader.load(
        source,
        onProgress: (p) => loading.value = p,
      );
    } on UnsupportedFileException catch (e) {
      loadFailure.value = UnsupportedFile(e.fileName);
    } catch (e) {
      loadFailure.value = OpenError(name, e);
    } finally {
      loading.value = null;
    }
  }

  void closeFile() => document.value = null;
}
