import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;

import 'file_format.dart';
import 'file_opener.dart';
import 'opened_document.dart';

/// How far a [DocumentLoader.load] has got.
final class LoadProgress {
  const LoadProgress({required this.name, this.bytesRead = 0, this.totalBytes});

  /// The file name the bytes will be opened under.
  final String name;
  final int bytesRead;

  /// `null` when the size is not known up front (a chunked response).
  final int? totalBytes;

  /// 0..1, or `null` when [totalBytes] is unknown (indeterminate bar).
  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (bytesRead / total).clamp(0.0, 1.0);
  }
}

/// A download or file read that failed for a reason worth showing.
final class LoadException implements Exception {
  const LoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef LoadProgressCallback = void Function(LoadProgress progress);

/// Reads a document from a file path or an http(s) URL — the app's
/// command-line argument. Registered in get_it so the UI can be tested
/// with a fake.
abstract interface class DocumentLoader {
  /// The name [source] will be opened under, without reading anything.
  String nameOf(String source);

  /// Reads [source] fully, reporting [onProgress] as bytes arrive.
  /// Throws [UnsupportedFileException] for an unknown extension and
  /// [LoadException] for an HTTP error status.
  Future<OpenedDocument> load(
    String source, {
    LoadProgressCallback? onProgress,
  });
}

/// The real thing: `cross_file` for paths, `package:http` for URLs, so
/// nothing here needs `dart:io` directly.
final class IoDocumentLoader implements DocumentLoader {
  /// [client] is for tests; without one a client is opened per load.
  const IoDocumentLoader({this.client});

  final http.Client? client;

  static Uri? _asUrl(String source) {
    final uri = Uri.tryParse(source);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
        ? uri
        : null;
  }

  @override
  String nameOf(String source) {
    final url = _asUrl(source);
    if (url != null) {
      final segments = url.pathSegments.where((s) => s.isNotEmpty);
      return segments.isEmpty ? url.host : segments.last;
    }
    return XFile(source).name;
  }

  @override
  Future<OpenedDocument> load(
    String source, {
    LoadProgressCallback? onProgress,
  }) async {
    final name = nameOf(source);
    final format = FileFormat.ofFileName(name);
    if (format == null) throw UnsupportedFileException(name);

    final url = _asUrl(source);
    final Stream<List<int>> stream;
    final int? total;
    http.Client? owned;
    if (url != null) {
      final client = this.client ?? (owned = http.Client());
      final response = await client.send(http.Request('GET', url));
      if (response.statusCode != 200) {
        owned?.close();
        final reason = response.reasonPhrase;
        throw LoadException(
          'HTTP ${response.statusCode}'
          '${reason == null || reason.isEmpty ? '' : ' $reason'}',
        );
      }
      stream = response.stream;
      total = response.contentLength;
    } else {
      final file = XFile(source);
      stream = file.openRead();
      total = await file.length();
    }

    final builder = BytesBuilder(copy: false);
    onProgress?.call(LoadProgress(name: name, totalBytes: total));
    try {
      await for (final chunk in stream) {
        builder.add(chunk);
        onProgress?.call(
          LoadProgress(
            name: name,
            bytesRead: builder.length,
            totalBytes: total,
          ),
        );
      }
    } finally {
      owned?.close();
    }
    return OpenedDocument(
      name: name,
      format: format,
      bytes: builder.takeBytes(),
    );
  }
}
