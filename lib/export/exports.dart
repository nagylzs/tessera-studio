import 'dart:convert' show utf8;

import 'package:flutter/services.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_html/tessera_html.dart';
import 'package:tessera_ods/tessera_ods.dart';
import 'package:tessera_pdf/tessera_pdf.dart';
import 'package:tessera_svg/tessera_svg.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

import '../app.dart' show tesseraGreen;
import 'export_format.dart';

/// The look of every export: headers on the tessera green. Exports go
/// on paper and into spreadsheets, so they do not follow the dark theme.
final exportTheme = CubeExportTheme.brand(primary: tesseraGreen.toARGB32());

/// The PDF's: dark text on a light green. tessera_pdf 0.2.0 writes the
/// page header and footer in the header cells' text colour, which the
/// green theme makes white on white paper; light headers save toner too.
final pdfExportTheme = CubeExportTheme.brand(
  primary: CubeExportTheme.mix(0xFFFFFFFF, tesseraGreen.toARGB32(), 0.35),
  onPrimary: 0xFF191C1B,
);

/// The cube as laid out, with the [aggregates] the grid shows (`null` =
/// all of the spec's), as [format]. [title] names the sheet or heads
/// the page.
Future<Uint8List> cubeExport(
  Cube cube,
  ExportFormat format, {
  required String title,
  required TesseraStrings strings,
  List<Aggregate>? aggregates,
}) async {
  final layout = cube.layout;
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
      theme: pdfExportTheme,
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
