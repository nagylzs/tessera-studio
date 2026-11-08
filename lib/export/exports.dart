import 'dart:convert' show utf8;

import 'package:flutter/services.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_html/tessera_html.dart';
import 'package:tessera_ods/tessera_ods.dart';
import 'package:tessera_pdf/tessera_pdf.dart';
import 'package:tessera_svg/tessera_svg.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

import 'export_format.dart';

/// The cube as laid out, with the [aggregates] the grid shows (`null` =
/// all of the spec's), as [format], in the grid's [style] and depth
/// [coloring] (its light variant: exports go on paper). [title] names the
/// sheet or heads the page. Documents name fonts their readers have; a
/// PDF embeds the app's own under its names.
Future<Uint8List> cubeExport(
  Cube cube,
  ExportFormat format, {
  required String title,
  required TesseraStrings strings,
  List<Aggregate>? aggregates,
  required CubeStyle style,
  DepthColoring coloring = DepthColoring.both,
}) async {
  final layout = cube.layout;
  final exportTheme = CubeExportTheme.fromStyle(style, coloring: coloring);
  return switch (format) {
    ExportFormat.xlsx => XlsxCubeExporter(
      strings: strings,
      theme: exportTheme,
    ).export(layout, aggregates: aggregates, sheetName: title),
    ExportFormat.ods => OdsCubeExporter(
      strings: strings,
      theme: exportTheme,
    ).export(layout, aggregates: aggregates, sheetName: title),
    ExportFormat.html => _utf8(
      HtmlCubeExporter(
        strings: strings,
        theme: exportTheme,
      ).export(layout, aggregates: aggregates, title: title),
    ),
    ExportFormat.svg => _utf8(
      SvgCubeExporter(
        strings: strings,
        theme: exportTheme,
      ).export(layout, aggregates: aggregates, title: title),
    ),
    ExportFormat.pdf => await PdfCubeExporter(
      strings: strings,
      theme: CubeExportTheme.fromStyle(
        style,
        coloring: coloring,
        families: _pdfFamilies,
      ),
      fonts: await _pdfFonts,
      footer: const PdfPageText(left: '{date}', right: '{page} / {pages}'),
    ).export(layout, aggregates: aggregates, title: title),
    ExportFormat.csv => _utf8(
      CsvCubeExporter(
        strings: strings,
        options: const CsvExportOptions(byteOrderMark: true),
      ).export(layout, aggregates: aggregates),
    ),
    ExportFormat.json => _utf8(
      JsonCubeExporter(
        strings: strings,
        options: const JsonExportOptions(indent: '  '),
      ).export(layout, aggregates: aggregates),
    ),
    ExportFormat.jsonl => _utf8(
      JsonCubeExporter(strings: strings)
          .exportLines(layout, aggregates: aggregates),
    ),
    // the facts with the spec and expanded groups: reopens as it is now
    ExportFormat.snapshot => TesseraSnapshot().encode(
      cube.facts,
      config: CubeConfig.of(cube),
    ),
    ExportFormat.png => throw ArgumentError.value(
      format,
      'format',
      'not a cube format',
    ),
  };
}

/// The facts behind [cube] — every column, the rows passing its filter —
/// as a plain table in one of [ExportFormat.tables].
Uint8List factsExport(Cube cube, ExportFormat format, {required String title}) {
  final filter = cube.spec.filter;
  ExportTable table() => ExportTable.ofFacts(cube.facts, filter: filter);
  return switch (format) {
    ExportFormat.xlsx => const XlsxTableExporter().export(
      table(),
      sheetName: title,
    ),
    ExportFormat.ods => const OdsTableExporter().export(
      table(),
      sheetName: title,
    ),
    ExportFormat.csv => _utf8(
      const CsvTableExporter(options: CsvExportOptions(byteOrderMark: true))
          .export(table()),
    ),
    ExportFormat.jsonl => _utf8(
      const JsonFactExporter().exportLines(cube.facts, filter: filter),
    ),
    _ => throw ArgumentError.value(format, 'format', 'not a table format'),
  };
}

Uint8List _utf8(String text) => Uint8List.fromList(utf8.encode(text));

/// The names a PDF gives the style's font kinds: the app's fonts, which
/// [_pdfFonts] embeds under them.
const _pdfFamilies = ExportFamilies(
  sans: 'Noto Sans',
  serif: 'Noto Serif',
  mono: 'Noto Sans Mono',
);

/// Noto Sans, Serif and Sans Mono, embedded so that accented, Greek and
/// Cyrillic text survives (the PDF built-in Helvetica is WinAnsi only);
/// loaded once. A family goes into a PDF only if one of its cells uses it.
final Future<PdfFonts> _pdfFonts = () async {
  Future<PdfFonts> family(String file) async {
    final regular = await rootBundle.load('assets/fonts/$file-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/$file-Bold.ttf');
    return PdfFonts(
      regular: regular.buffer.asUint8List(),
      bold: bold.buffer.asUint8List(),
    );
  }

  final sans = await family('NotoSans');
  return PdfFonts(
    regular: sans.regular!,
    bold: sans.bold,
    families: {
      _pdfFamilies.serif: await family('NotoSerif'),
      _pdfFamilies.mono: await family('NotoSansMono'),
    },
  );
}();
