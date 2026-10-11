// Fills a Microsoft Store listing export with store/listing/<lang>.yaml
// and gathers the images next to it, ready for Partner Center's "Import
// listings" (Application overview → Store listings).
//
//   dart run tool/ms_listing.dart <exported.csv> <out-dir>
//
// Partner Center → Application overview → "Export listings" gives the
// .csv: one row per listing field, one column per language of the
// package (en-us, cs-cz, …). The tool writes <out-dir>/<same name>.csv,
// <out-dir>/screenshots/*.png (store/screenshots/microsoft) and
// <out-dir>/store-logo-300.png; every language gets the same images.
// Rows the tool does not know are left as exported.
//
// Import it with "Import listings" → **Import folder** on <out-dir> (one
// .csv in it). Partner Center wants image paths that start with that
// folder's own name ("<out-dir name>/screenshots/1-pivot.png"); after an
// import, an export shows the images as Partner Center URLs instead.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _developer = 'László Zsolt Nagy';
const _copyright = '© 2026 László Zsolt Nagy';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'usage: dart run tool/ms_listing.dart <exported.csv> <out-dir>',
    );
    exit(64);
  }
  final input = File(args[0]);
  final out = Directory(args[1])..createSync(recursive: true);
  final root = out.absolute.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
  final rows = _parseCsv(utf8.decode(input.readAsBytesSync()));
  final header = rows.first;
  if (header.first.startsWith('\uFEFF')) header[0] = header.first.substring(1);

  final shots =
      Directory('store/screenshots/microsoft')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final shotDir = Directory('${out.path}/screenshots')..createSync();
  for (final f in shots) {
    f.copySync('${shotDir.path}/${f.uri.pathSegments.last}');
  }
  File('store/screenshots/microsoft-store-logo.png')
      .copySync('${out.path}/store-logo-300.png');

  for (var c = 4; c < header.length; c++) {
    final lang = header[c].split('-').first; // en-us → en, zh-cn → zh
    final file = File('store/listing/$lang.yaml');
    if (!file.existsSync()) {
      stderr.writeln('no store/listing/$lang.yaml for ${header[c]}');
      exit(1);
    }
    final yaml = loadYaml(file.readAsStringSync()) as YamlMap;
    final features = (yaml['features'] as YamlList).cast<String>();
    final terms = (yaml['search_terms'] as YamlList).cast<String>();
    final values = <String, String>{
      'Description': yaml['description'] as String,
      'ShortDescription': yaml['summary'] as String,
      'DevStudio': _developer,
      'CopyrightTrademarkInformation': _copyright,
      for (var i = 0; i < features.length; i++) 'Feature${i + 1}': features[i],
      for (var i = 0; i < terms.length; i++) 'SearchTerm${i + 1}': terms[i],
      for (var i = 0; i < shots.length; i++)
        'DesktopScreenshot${i + 1}':
            '$root/screenshots/${shots[i].uri.pathSegments.last}',
      'StoreLogo300x300': '$root/store-logo-300.png',
    };
    for (final row in rows.skip(1)) {
      final value = values[row.first];
      if (value != null) row[c] = value;
    }
  }

  final csv = StringBuffer('\uFEFF');
  csv.write(rows.map((r) => r.map(_quote).join(',')).join('\r\n'));
  File('${out.path}/${input.uri.pathSegments.last}')
      .writeAsStringSync(csv.toString());
  stdout.writeln(
    '${header.length - 4} languages, ${shots.length} screenshots → ${out.path}',
  );
}

/// RFC 4180: fields separated by commas, rows by CRLF or LF, a quoted
/// field may hold commas, line breaks and doubled quotes.
List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\r' || ch == '\n') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

String _quote(String s) =>
    RegExp(r'[",\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
