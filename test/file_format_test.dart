import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';

/// A zip's first local file header (stored entry) followed by its content.
Uint8List zipWith(String name, [String content = '']) {
  final n = ascii.encode(name), c = ascii.encode(content);
  final header = ByteData(30)
    ..setUint32(0, 0x04034B50, Endian.little)
    ..setUint32(18, c.length, Endian.little)
    ..setUint32(22, c.length, Endian.little)
    ..setUint16(26, n.length, Endian.little)
    ..setUint16(28, 0, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...n, ...c]);
}

Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('media types map to formats, parameters ignored', () {
    expect(FileFormat.ofMimeType('text/csv; charset=utf-8'), FileFormat.csv);
    expect(FileFormat.ofMimeType('application/json'), FileFormat.json);
    expect(FileFormat.ofMimeType('application/x-ndjson'), FileFormat.jsonl);
    expect(
      FileFormat.ofMimeType('application/vnd.tessera.snapshot'),
      FileFormat.snapshot,
    );
    expect(FileFormat.ofMimeType('text/plain'), isNull);
    expect(FileFormat.ofMimeType('application/octet-stream'), isNull);
    expect(FileFormat.ofMimeType(null), isNull);
  });

  test('bytes reveal binary formats', () {
    expect(
      FileFormat.ofBytes(text('TSNP\x01\x00\x00\x00')),
      FileFormat.snapshot,
    );
    expect(
      FileFormat.ofBytes(
        zipWith('mimetype', 'application/vnd.oasis.opendocument.spreadsheet'),
      ),
      FileFormat.ods,
    );
    expect(FileFormat.ofBytes(zipWith('[Content_Types].xml')), FileFormat.xlsx);
    expect(FileFormat.ofBytes(zipWith('_rels/.rels')), FileFormat.xlsx);
    expect(FileFormat.ofBytes(zipWith('photo.jpg')), isNull);
    expect(FileFormat.ofBytes(Uint8List.fromList([0, 1, 2, 255, 254])), isNull);
    expect(FileFormat.ofBytes(Uint8List(0)), isNull);
  });

  test('bytes reveal text formats', () {
    expect(FileFormat.ofBytes(text('[{"a":1}]')), FileFormat.json);
    expect(
      FileFormat.ofBytes(text('\uFEFF  {"a":1}\n{"a":2}')),
      FileFormat.jsonl,
    );
    expect(FileFormat.ofBytes(text('a\tb\n1\t2\n')), FileFormat.tsv);
    expect(FileFormat.ofBytes(text('a;b\n1;2\n')), FileFormat.csv);
    expect(FileFormat.ofBytes(text('a,b\r\n1,2\r\n')), FileFormat.csv);
    expect(FileFormat.ofBytes(text('name\nalice\nbob\n')), FileFormat.csv);
    expect(FileFormat.ofBytes(text('just one word')), isNull);
    expect(FileFormat.ofBytes(text('   \n  ')), isNull);
  });

  test('the delimiter is the most consistent one', () {
    expect(FileFormat.sniffDelimiter('a\tb\n1\t2'), '\t');
    expect(FileFormat.sniffDelimiter('a;b\n1,5;2,5'), ';');
    expect(FileFormat.sniffDelimiter('a,b\n"x, y",2'), ',');
    expect(FileFormat.sniffDelimiter('a|b\n1|2'), '|');
    expect(FileFormat.sniffDelimiter('single\ncolumn'), isNull);
    expect(FileFormat.sniffDelimiter(''), isNull);
  });

  test('detect: name, then media type, then bytes; csv gets a delimiter', () {
    final semi = OpenedDocument.detect(
      name: 'x.csv',
      bytes: text('a;b\n1;2\n'),
    );
    expect(semi.format, FileFormat.csv);
    expect(semi.delimiter, ';');
    final byMime = OpenedDocument.detect(
      name: 'download',
      bytes: text('a,b\n1,2\n'),
      mimeType: 'application/json',
    );
    expect(byMime.format, FileFormat.json); // the type wins over the bytes
    final sniffed = OpenedDocument.detect(
      name: 'paste',
      bytes: text('a\tb\n1\t2'),
    );
    expect(sniffed.format, FileFormat.tsv);
    expect(sniffed.delimiter, isNull);
    expect(
      () => OpenedDocument.detect(name: 'blob', bytes: text('hello')),
      throwsA(isA<UnsupportedFileException>()),
    );
  });

  test('every format builds its source or snapshot', () async {
    for (final f in FileFormat.values) {
      final src = f.dataSource(text('a,b\n1,2\n'), name: 'x');
      expect(src == null, f == FileFormat.snapshot, reason: f.name);
    }
    final semi = OpenedDocument.detect(
      name: 'x.csv',
      bytes: text('a;b\n1;2\n'),
    );
    expect(await semi.dataSource!.columnNames(), ['a', 'b']);
  });
}
