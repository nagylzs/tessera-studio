import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';

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

  test('a file with an unknown extension is sniffed', () async {
    final file = File('${dir.path}/export.dat')
      ..writeAsStringSync('a;b\n1;2\n');
    final doc = await const IoDocumentLoader().load(file.path);
    expect(doc.format, FileFormat.csv);
    expect(doc.delimiter, ';');
    File('${dir.path}/blob.bin').writeAsBytesSync([0, 1, 2, 3]);
    expect(
      () => const IoDocumentLoader().load('${dir.path}/blob.bin'),
      throwsA(isA<UnsupportedFileException>()),
    );
  });

  test('a URL without a useful path uses Content-Disposition, then the '
      'type, then the bytes', () async {
    Future<OpenedDocument> fetch(Map<String, String> headers, String body) =>
        IoDocumentLoader(
          client: MockClient.streaming(
            (_, _) async => http.StreamedResponse(
              Stream.value(body.codeUnits),
              200,
              headers: headers,
            ),
          ),
        ).load('https://example.com/download?id=7');

    final named = await fetch({
      'content-disposition': 'attachment; filename="rows.jsonl"',
    }, '{"a":1}\n');
    expect(named.name, 'rows.jsonl');
    expect(named.format, FileFormat.jsonl);

    final starred = await fetch({
      'content-disposition': "attachment; filename*=UTF-8''%C3%A1rak.json",
    }, '[{"a":1}]');
    expect(starred.name, 'árak.json');
    expect(starred.format, FileFormat.json);

    final typed = await fetch({
      'content-type': 'text/tab-separated-values; charset=utf-8',
    }, 'a\tb\n1\t2\n');
    expect(typed.name, 'download');
    expect(typed.format, FileFormat.tsv);

    final sniffed = await fetch({
      'content-type': 'application/octet-stream',
    }, 'a,b\n1,2\n');
    expect(sniffed.format, FileFormat.csv);

    expect(
      () => fetch({'content-type': 'application/octet-stream'}, 'nothing'),
      throwsA(isA<UnsupportedFileException>()),
    );
  });

  test('Content-Disposition file names are parsed and stripped of paths', () {
    const parse = IoDocumentLoader.dispositionFileName;
    expect(parse(null), isNull);
    expect(parse('inline'), isNull);
    expect(parse('attachment; filename=data.csv'), 'data.csv');
    expect(parse('attachment; filename="a b.xlsx"; size=3'), 'a b.xlsx');
    expect(parse('attachment; filename="../../x.csv"'), 'x.csv');
    expect(parse("attachment; filename*=utf-8''%E2%82%AC.csv"), '€.csv');
    expect(
      parse('attachment; filename="p.csv"; filename*=UTF-8\'\'q.csv'),
      'q.csv',
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
