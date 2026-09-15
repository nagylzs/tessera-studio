import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;

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
/// command-line argument, the clipboard's. Registered in get_it so the
/// UI can be tested with a fake.
abstract interface class DocumentLoader {
  /// The name [source] will be opened under, without reading anything.
  String nameOf(String source);

  /// Reads [source] fully, reporting [onProgress] as bytes arrive. The
  /// document is named [name], or [nameOf] the source when omitted (a
  /// file copied to a cache keeps its original name this way; a URL's
  /// `Content-Disposition` file name wins over its path). The format
  /// comes from the name, else the response's `Content-Type`, else the
  /// bytes ([OpenedDocument.detect]). Throws [UnsupportedFileException]
  /// when none of them recognises the file and [LoadException] for an
  /// HTTP error status.
  Future<OpenedDocument> load(
    String source, {
    String? name,
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
    String? name,
    LoadProgressCallback? onProgress,
  }) async {
    final url = _asUrl(source);
    final Stream<List<int>> stream;
    final int? total;
    String? mimeType;
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
      mimeType = response.headers['content-type'];
      name ??=
          dispositionFileName(response.headers['content-disposition']) ??
          nameOf(source);
    } else {
      name ??= nameOf(source);
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
    return OpenedDocument.detect(
      name: name,
      bytes: builder.takeBytes(),
      mimeType: mimeType,
    );
  }

  static final _filenameStar = RegExp("filename\\*=(?:utf-8|UTF-8)''([^;]+)");
  static final _filename = RegExp('filename="([^"]*)"|filename=([^;]+)');

  /// The file name in a `Content-Disposition` header, `null` if none:
  /// the RFC 5987 `filename*=UTF-8''…` form first, then `filename=`.
  static String? dispositionFileName(String? header) {
    if (header == null) return null;
    final star = _filenameStar.firstMatch(header);
    if (star != null) {
      try {
        return _basename(Uri.decodeComponent(star.group(1)!.trim()));
      } on ArgumentError {
        // fall through to the plain form
      }
    }
    final plain = _filename.firstMatch(header);
    if (plain == null) return null;
    final name = (plain.group(1) ?? plain.group(2))!.trim();
    return name.isEmpty ? null : _basename(name);
  }

  /// A sender's path components are never trusted.
  static String _basename(String name) => name.split(RegExp(r'[\\/]')).last;
}
