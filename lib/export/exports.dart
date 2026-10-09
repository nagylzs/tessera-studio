import 'dart:convert' show utf8;

import 'package:flutter/services.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_html/tessera_html.dart';
import 'package:tessera_ods/tessera_ods.dart';
import 'package:tessera_pdf/tessera_pdf.dart';
import 'package:tessera_svg/tessera_svg.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

import '../style/grid_style.dart';
import 'export_format.dart';

/// The cube as laid out, with the [aggregates] the grid shows (`null` =
/// all of the spec's), as [format], in the export theme of [style] (the
/// grid's; exports go on paper, so not the dark theme). [title] names
/// the sheet or heads the page.
Future<Uint8List> cubeExport(
  Cube cube,
  ExportFormat format, {
  required String title,
  required TesseraStrings strings,
  List<Aggregate>? aggregates,
  GridStyle style = GridStyle.standard,
}) async {
  final layout = cube.layout;
  final exportTheme = style.exportTheme;
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
      theme: style.pdfExportTheme,
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

/// Noto Sans, embedded so that accented, Greek and Cyrillic text
/// survives (the PDF built-in Helvetica is WinAnsi only); loaded once.
final Future<PdfFonts> _pdfFonts = () async {
  final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  return PdfFonts(
    regular: regular.buffer.asUint8List(),
    bold: bold.buffer.asUint8List(),
  );
}();
