import 'package:flutter/material.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../app.dart' show tesseraGreen;

/// How the cube grid looks, chosen under "Grid style…" and remembered in
/// `AppSettings`. Each style has a [CubeTheme] for the screen and a
/// [CubeExportTheme] for the exports, authored to match (an export theme
/// is plain ARGB, not converted from the screen's: the screen's shading
/// is too subtle for paper). Adapted from the tessera example's presets.
enum GridStyle {
  /// Colours from the app's theme; exports in the tessera green.
  standard,

  /// White cells, grey grid lines, monospace figures — light also in the
  /// dark theme, like a sheet of paper.
  spreadsheet,

  /// Deeper levels in deeper teal; light also in the dark theme.
  gradient,

  /// Every level in its own hue, from the app's primary colour.
  hueLevels,

  /// Strong grid lines, larger bold text, taller rows.
  highContrast,

  /// Small text and short rows: more of the cube on the screen.
  compact;

  /// The grid's theme under [brightness]; what a style leaves unset
  /// comes from the app's theme.
  CubeTheme theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      standard => const CubeTheme(),
      spreadsheet => CubeTheme(
        levelColor: (_) => Colors.white,
        headerColor: Colors.grey.shade200,
        summaryColor: Colors.grey.shade300,
        borderColor: Colors.grey.shade500,
        sortKeyColor: Colors.yellow.withValues(alpha: 0.35),
        selectionColor: Colors.green.shade800,
        // pinned: the dark theme's light icons vanish on light headers
        headerIconColor: Colors.black54,
        cellTextStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.black87,
        ),
        headerTextStyle: const TextStyle(fontSize: 12, color: Colors.black),
        cellPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      gradient => CubeTheme(
        levelColor: CubeTheme.gradient([
          Colors.teal.shade50,
          Colors.teal.shade200,
          Colors.teal.shade400,
        ]),
        summaryColor: Colors.teal.shade100,
        headerColor: Colors.teal.shade100,
        borderColor: Colors.teal.shade700,
        selectionColor: Colors.deepOrange,
        sortKeyColor: Colors.deepOrange.withValues(alpha: 0.25),
        headerIconColor: Colors.black54,
        cellTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
        headerTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      hueLevels => const CubeTheme(hueLevels: HueLevels()),
      highContrast => CubeTheme(
        borderColor: dark ? Colors.white : Colors.black,
        cellTextStyle: const TextStyle(fontSize: 14),
        headerTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        rowHeight: 34,
        headerRowHeight: 34,
        selectionColor: dark ? Colors.redAccent : Colors.red,
        cellPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      compact => const CubeTheme(
        cellTextStyle: TextStyle(fontSize: 11),
        headerTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        rowHeight: 20,
        // a title cell's text, sort arrow and menu button need a bit more
        headerRowHeight: 24,
        minColumnWidth: 56,
        minRowHeaderWidth: 80,
        cellPadding: EdgeInsets.symmetric(horizontal: 3),
      ),
    };
  }

  /// The look of the exports in this style (spreadsheets, web page, SVG).
  CubeExportTheme get exportTheme => switch (this) {
    standard => _brand,
    spreadsheet => const CubeExportTheme(
      headerFill: 0xFFEEEEEE,
      summaryFill: 0xFFE0E0E0,
      levelFills: [0xFFFFFFFF],
      borderColor: 0xFF9E9E9E,
      cellFont: ExportFont(family: 'Courier New'),
      summaryFont: ExportFont(family: 'Courier New', bold: true),
    ),
    gradient => CubeExportTheme(
      headerFill: 0xFFB2DFDB, // teal 100
      summaryFill: 0xFFB2DFDB,
      levelFills: CubeExportTheme.gradient(0xFFE0F2F1, 0xFF26A69A, 4),
      borderColor: 0xFF00796B,
      headerFont: const ExportFont(bold: true),
    ),
    hueLevels => CubeExportTheme.hueLevels(
      levels: HueLevels(hue: Oklch.fromArgb(tesseraGreen.toARGB32()).hue),
    ),
    highContrast => const CubeExportTheme(
      borderColor: 0xFF000000,
      cellFont: ExportFont(size: 12),
      headerFont: ExportFont(size: 12, bold: true),
      summaryFont: ExportFont(size: 12, bold: true),
    ),
    compact => const CubeExportTheme(
      cellFont: ExportFont(size: 8),
      headerFont: ExportFont(size: 8),
      summaryFont: ExportFont(size: 8, bold: true),
    ),
  };

  /// The PDF's: as [exportTheme], except that the standard green gets
  /// dark text on a light green — tessera_pdf 0.2.0 writes the page
  /// header and footer in the header cells' text colour, white on the
  /// green (fixed in the library, unreleased).
  CubeExportTheme get pdfExportTheme =>
      this == standard ? _pdfBrand : exportTheme;
}

final _brand = CubeExportTheme.brand(primary: tesseraGreen.toARGB32());

final _pdfBrand = CubeExportTheme.brand(
  primary: CubeExportTheme.mix(0xFFFFFFFF, tesseraGreen.toARGB32(), 0.35),
  onPrimary: 0xFF191C1B,
);
