import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('tessera_studio'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('names come from the last path segment', () {
    const loader = IoDocumentLoader();
    expect(loader.nameOf('/data/sales.csv'), 'sales.csv');
    expect(
      loader.nameOf('https://example.com/dl/rows.jsonl?x=1'),
      'rows.jsonl',
    );
    expect(loader.nameOf('https://example.com'), 'example.com');
  });

  test('a file path is read with progress', () async {
    final file = File('${dir.path}/sales.csv')..writeAsStringSync('a,b\n1,2\n');
    final progress = <LoadProgress>[];
    final doc = await const IoDocumentLoader().load(
      file.path,
      onProgress: progress.add,
    );
    expect(doc.name, 'sales.csv');
    expect(doc.format, FileFormat.csv);
    expect(doc.size, 8);
    expect(progress.first.bytesRead, 0);
    expect(progress.last.bytesRead, 8);
    expect(progress.last.fraction, 1.0);
  });

  test('an explicit name overrides the path name', () async {
    final file = File('${dir.path}/1234_copy')..writeAsStringSync('{"a":1}');
    final doc = await const IoDocumentLoader().load(
      file.path,
      name: 'rows.json',
    );
    expect(doc.name, 'rows.json');
    expect(doc.format, FileFormat.json);
  });

  test('an unknown extension is refused before reading', () {
    expect(
      () => const IoDocumentLoader().load('${dir.path}/missing.docx'),
      throwsA(isA<UnsupportedFileException>()),
    );
  });

  test('a URL is downloaded with progress', () async {
    final client = MockClient.streaming((request, _) async {
      expect(request.url.toString(), 'https://example.com/sales.tsv');
      return http.StreamedResponse(
        Stream.fromIterable(['a\tb\n'.codeUnits, '1\t2\n'.codeUnits]),
        200,
        contentLength: 8,
      );
    });
    final progress = <LoadProgress>[];
    final doc = await IoDocumentLoader(client: client)
        .load('https://example.com/sales.tsv', onProgress: progress.add);
    expect(doc.format, FileFormat.tsv);
    expect(doc.size, 8);
    expect(progress.map((p) => p.bytesRead), [0, 4, 8]);
    expect(progress.map((p) => p.fraction), [0.0, 0.5, 1.0]);
  });

  test('an unknown content length gives an indeterminate fraction', () async {
    final client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(Stream.value([1, 2, 3]), 200),
    );
    final progress = <LoadProgress>[];
    await IoDocumentLoader(client: client)
        .load('https://example.com/x.csv', onProgress: progress.add);
    expect(progress.last.fraction, isNull);
  });

  test('an HTTP error status fails the load', () {
    final client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(
        const Stream.empty(),
        404,
        reasonPhrase: 'Not Found',
      ),
    );
    expect(
      IoDocumentLoader(client: client).load('https://example.com/x.csv'),
      throwsA(
        isA<LoadException>().having(
          (e) => e.message,
          'message',
          'HTTP 404 Not Found',
        ),
      ),
    );
  });
}
