import 'dart:math' as math;

import 'package:flutter/material.dart'
    show Brightness, Color, ColorScheme, Colors, Offset, Rect, Size;
import 'package:intl/intl.dart' as intl;
import 'package:tessera_flutter/tessera_flutter.dart';

import '../app.dart' show tesseraGreen;
import 'chart_content.dart';
import 'chart_drawing.dart';
import 'chart_scene.dart';
import 'chart_settings.dart';

/// The width of [text] at [size]. The layout takes it from outside, as the
/// bundled font's metrics stand for every format's.
typedef TextMeasure = double Function(String text, double size);

const _margin = 24.0;
const _titleSize = 16.0;
const _textSize = 11.0;
const _lineHeight = 1.3;

/// [content] on a page: the [title] above it, the [caption]'s lines below,
/// and [problem] in its place when there is nothing to draw. fl_chart cannot
/// write vectors, so an export is drawn from the same [ChartContent], with the
/// same axes, colours and labels as the screen but a layout of its own.
ChartScene chartScene(
  ChartContent content, {
  required String title,
  required List<String> caption,
  required String? problem,
  required String others,
  required ChartLook look,
  required TesseraStrings strings,
  required String locale,
  required TextMeasure measure,
  Size size = chartImageSize,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: tesseraGreen,
    brightness: look.dark ? Brightness.dark : Brightness.light,
  );
  final drawing = _Drawing(scheme, strings, locale, others, measure);
  final lines = [
    for (final line in caption)
      if (line.isNotEmpty) line,
  ];
  final page = Rect.fromLTWH(
    _margin,
    _margin,
    size.width - 2 * _margin,
    size.height - 2 * _margin,
  );
  drawing.heading(title, page);
  drawing.caption(lines, page);
  final area = Rect.fromLTRB(
    page.left,
    page.top + _titleSize * _lineHeight + 12,
    page.right,
    page.bottom - (lines.isEmpty ? 0 : lines.length * drawing.line + 8),
  );
  if (problem != null) {
    drawing.message(problem, area);
  } else if (content.scatter case final data?) {
    drawing.scatter(data, area);
  } else {
    final data = content.data!;
    switch (content.kind) {
      case ChartKind.bar:
        drawing.bars(data, area, stacked: false);
      case ChartKind.stacked:
        drawing.bars(data, area, stacked: true);
      case ChartKind.line:
        drawing.lineChart(data, area);
      case ChartKind.pie:
        drawing.pie(data, area);
      case ChartKind.scatter:
        throw StateError('a scatter chart has no ChartData');
    }
  }
  return ChartScene(
    title: title,
    width: size.width,
    height: size.height,
    background: look.transparent
        ? null
        : look.dark
        ? scheme.surface
        : Colors.white,
    shapes: drawing.shapes,
  );
}

final class _LegendEntry {
  const _LegendEntry(this.text, this.color, this.width);

  final String text;
  final Color color;
  final double width;
}

final class _Drawing {
  _Drawing(this.scheme, this.strings, this.locale, this.others, this.measure);

  final ColorScheme scheme;
  final TesseraStrings strings;
  final String locale;
  final String others;
  final TextMeasure measure;
  final shapes = <SceneShape>[];

  double get line => _textSize * _lineHeight;

  void _text(
    String text,
    double x,
    double baseline, {
    double size = _textSize,
    Color? color,
    TextAnchor anchor = TextAnchor.start,
  }) => shapes.add(
    SceneText(
      text,
      x,
      baseline,
      size,
      color ?? scheme.onSurfaceVariant,
      anchor: anchor,
    ),
  );

  /// [text] in [width], cut short with an ellipsis if it must be.
  String _fit(String text, double width, [double size = _textSize]) {
    if (measure(text, size) <= width) return text;
    final runes = text.runes.toList();
    String cut(int count) =>
        '${String.fromCharCodes(runes.take(count)).trimRight()}…';
    var low = 0, high = runes.length;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (measure(cut(middle), size) <= width) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return cut(low);
  }

  /// A label centred on [x] but kept inside [bounds], as the last bar's name
  /// is often wider than the room beside it.
  void _centred(String text, double x, double baseline, Rect bounds) {
    final half = measure(text, _textSize) / 2;
    _text(
      text,
      x.clamp(
        bounds.left + half,
        math.max(bounds.left + half, bounds.right - half),
      ),
      baseline,
      anchor: TextAnchor.middle,
    );
  }

  void heading(String title, Rect page) => _text(
    _fit(title, page.width, _titleSize),
    page.left,
    page.top + _titleSize,
    size: _titleSize,
    color: scheme.onSurface,
  );

  void caption(List<String> lines, Rect page) {
    var baseline = page.bottom - (lines.length - 1) * line;
    for (final text in lines) {
      _text(
        _fit(text, page.width),
        page.left,
        baseline,
        color: scheme.onSurface,
      );
      baseline += line;
    }
  }

  void message(String text, Rect area) => _text(
    _fit(text, area.width),
    area.center.dx,
    area.center.dy,
    color: scheme.onSurface,
    anchor: TextAnchor.middle,
  );

  // ---- legends

  static const _swatch = 12.0;
  static const _swatchGap = 4.0;
  static const _entryGap = 12.0;
  static const _entryWidth = 220.0;

  List<List<_LegendEntry>> _legendRows(
    List<String> labels,
    List<Color> colors,
    double width,
  ) {
    final rows = <List<_LegendEntry>>[];
    var used = 0.0;
    for (var i = 0; i < labels.length; i++) {
      final room = _entryWidth - _swatch - _swatchGap;
      final text = _fit(labels[i], room);
      final entry = _LegendEntry(
        text,
        colors[i],
        _swatch + _swatchGap + measure(text, _textSize),
      );
      if (rows.isEmpty || used + _entryGap + entry.width > width) {
        rows.add([entry]);
        used = entry.width;
      } else {
        rows.last.add(entry);
        used += _entryGap + entry.width;
      }
    }
    return rows;
  }

  double _legendHeight(List<List<_LegendEntry>> rows) =>
      rows.isEmpty ? 0 : 8 + rows.length * (line + 4);

  /// The [rows], centred, at the bottom of [area].
  void _legend(List<List<_LegendEntry>> rows, Rect area) {
    var y = area.bottom - rows.length * (line + 4) + 4;
    for (final row in rows) {
      final width =
          row.fold(0.0, (sum, e) => sum + e.width) +
          (row.length - 1) * _entryGap;
      var x = area.center.dx - width / 2;
      for (final entry in row) {
        shapes.add(
          SceneRect(x, y + (line - _swatch) / 2, _swatch, _swatch, entry.color),
        );
        _text(entry.text, x + _swatch + _swatchGap, y + _textSize);
        x += entry.width + _entryGap;
      }
      y += line + 4;
    }
  }

  // ---- axes

  /// The plot in [area], with room for [numbers] on the left and [below] it.
  Rect _plot(
    Rect area,
    AxisRange range,
    String Function(double) numbers, {
    required double below,
    double right = 12,
  }) {
    final widest = range.ticks
        .map((v) => measure(numbers(v), _textSize))
        .fold(24.0, math.max);
    return Rect.fromLTRB(
      area.left + widest + 8,
      area.top + 4,
      area.right - right,
      area.bottom - below,
    );
  }

  /// Where [v] is on [range] along [from]-[to].
  static double _along(AxisRange range, double v, double from, double to) =>
      from + (v - range.min) / (range.max - range.min) * (to - from);

  void _gridLine(double x1, double y1, double x2, double y2) =>
      shapes.add(SceneLine(x1, y1, x2, y2, scheme.outlineVariant, 1));

  void _valueAxis(AxisRange range, Rect plot, String Function(double) numbers) {
    for (final v in range.ticks) {
      final y = _along(range, v, plot.bottom, plot.top);
      _gridLine(plot.left, y, plot.right, y);
      _text(
        numbers(v),
        plot.left - 8,
        y + _textSize * 0.35,
        anchor: TextAnchor.end,
      );
    }
  }

  /// A group's label under the plot: its ancestors on a line above its own
  /// name. Where they do not all fit, only every n-th is written.
  void _categoryLabels(ChartData data, Rect plot, Rect area) {
    final count = data.categories.length;
    if (count == 0) return;
    final slot = plot.width / count;
    final step = math.max((_narrowestLabel(data) / slot).ceil(), 1);
    final bounds = Rect.fromLTRB(area.left, plot.top, area.right, area.bottom);
    for (var i = 0; i < count; i += step) {
      final category = data.categories[i];
      final width = math.max(slot * step - 4, 0.0);
      final x = plot.left + slot * (i + 0.5);
      var baseline = plot.bottom + 8 + _textSize;
      if (category.path.length > 1) {
        final ancestors = category.path.entries
            .take(category.path.length - 1)
            .map((e) => groupText(strings, e))
            .join(' › ');
        _centred(_fit(ancestors, width), x, baseline, bounds);
        baseline += line;
      }
      final own = category.path.isRoot
          ? category.label
          : groupText(strings, category.path.last);
      _centred(_fit(own, width), x, baseline, bounds);
    }
  }

  /// Text may be cut short and still say something; a date or a number may
  /// not, so it needs its whole width.
  double _narrowestLabel(ChartData data) {
    const atLeast = 48.0;
    final cs = data.categories;
    if (!cs.every((c) => c.value is DateTime || c.value is num)) return atLeast;
    return cs
            .map((c) => measure(pathLabel(strings, c.path, c.label), _textSize))
            .fold(atLeast - 8, math.max) +
        8;
  }

  List<String> _seriesLabels(ChartData data) => [
    for (final s in data.series) pathLabel(strings, s.path, s.label),
  ];

  // ---- bars

  void bars(ChartData data, Rect area, {required bool stacked}) {
    final colors = seriesColorsOf(scheme, data.series.length);
    final rows = data.series.length > 1 || !data.series.first.path.isRoot
        ? _legendRows(_seriesLabels(data), colors, area.width)
        : const <List<_LegendEntry>>[];
    final legend = _legendHeight(rows);
    final labels = deepCategories(data) ? 2 : 1;
    final below = legend + 8 + labels * line;

    final tops = <double>[];
    for (var i = 0; i < data.categories.length; i++) {
      if (stacked) {
        var top = 0.0, bottom = 0.0;
        for (final s in data.series) {
          final v = s.values[i] ?? 0;
          v > 0 ? top += v : bottom += v;
        }
        tops.addAll([top, bottom]);
      } else {
        tops.addAll([for (final s in data.series) s.values[i] ?? 0]);
      }
    }
    final range = AxisRange(tops, ticks: ticksFor(area.height - below));
    final numbers = axisNumbers(range, locale);
    final plot = _plot(area, range, numbers, below: below);
    _valueAxis(range, plot, numbers);

    final count = data.categories.length;
    final slots = count * (stacked ? 2 : data.series.length + 1);
    final rod = ((plot.width - 60) / math.max(slots, 1)).clamp(1.0, 56.0);
    final slot = plot.width / math.max(count, 1);
    double y(double v) => _along(range, v, plot.bottom, plot.top);
    void bar(double x, double from, double to, Color color) {
      final top = math.min(y(from), y(to));
      final height = (y(from) - y(to)).abs();
      if (height > 0) shapes.add(SceneRect(x, top, rod, height, color));
    }

    for (var i = 0; i < count; i++) {
      final centre = plot.left + slot * (i + 0.5);
      if (stacked) {
        // positives stack upwards from 0, negatives downwards
        var top = 0.0, bottom = 0.0;
        for (var s = 0; s < data.series.length; s++) {
          final v = data.series[s].values[i];
          if (v == null || v == 0) continue;
          if (v > 0) {
            bar(centre - rod / 2, top, top + v, colors[s]);
            top += v;
          } else {
            bar(centre - rod / 2, bottom + v, bottom, colors[s]);
            bottom += v;
          }
        }
      } else {
        final group = data.series.length * rod + (data.series.length - 1);
        for (var s = 0; s < data.series.length; s++) {
          final v = data.series[s].values[i];
          if (v == null) continue;
          bar(centre - group / 2 + s * (rod + 1), 0, v, colors[s]);
        }
      }
    }
    _categoryLabels(data, plot, area);
    _legend(rows, area);
  }

  // ---- lines

  void lineChart(ChartData source, Rect area) {
    // an empty group has no place on a numeric or time axis, but is a
    // category like any other on a categorical one
    final trimmed = source.withoutEmpty();
    final axis = LineAxis.of(trimmed);
    final data = axis is CategoryAxis ? source : trimmed;
    final colors = seriesColorsOf(scheme, data.series.length);
    final rows = data.series.length > 1 || !data.series.first.path.isRoot
        ? _legendRows(_seriesLabels(data), colors, area.width)
        : const <List<_LegendEntry>>[];
    final legend = _legendHeight(rows);
    final labels = axis is CategoryAxis && deepCategories(data) ? 2 : 1;
    final below = legend + 8 + labels * line;
    final range = AxisRange([
      for (final s in data.series)
        for (final v in s.values) ?v,
    ], ticks: ticksFor(area.height - below));
    final numbers = axisNumbers(range, locale);
    final plot = _plot(area, range, numbers, below: below, right: 24);
    _valueAxis(range, plot, numbers);

    double position(int i) => switch (axis) {
      PeriodAxis(:final period) => periodPosition(
        period,
        data.categories[i].periodStart!,
      ),
      NumericAxis() => data.categories[i].number!.toDouble(),
      CategoryAxis() => i.toDouble(),
    };
    final count = data.categories.length;
    final xRange = axis is CategoryAxis || count == 0
        ? null
        : AxisRange(
            [for (var i = 0; i < count; i++) position(i)],
            includeZero: false,
            // dates are wide
            ticks: ticksFor(plot.width, per: axis is PeriodAxis ? 110 : 90),
            minInterval: axis is PeriodAxis ? 1 : 0,
          );
    double x(int i) => xRange == null
        ? plot.left + plot.width / math.max(count, 1) * (i + 0.5)
        : _along(xRange, position(i), plot.left, plot.right);
    double y(double v) => _along(range, v, plot.bottom, plot.top);

    for (var s = 0; s < data.series.length; s++) {
      var run = <Offset>[];
      void flush() {
        if (run.length > 1) shapes.add(ScenePolyline(run, colors[s], 2));
        run = [];
      }

      for (var i = 0; i < count; i++) {
        final v = data.series[s].values[i];
        if (v != null) {
          run.add(Offset(x(i), y(v)));
          if (count <= 60) shapes.add(SceneCircle(x(i), y(v), 3, colors[s]));
        } else if (axis is CategoryAxis) {
          // a blank cell breaks the line on a categorical axis; on a real
          // axis there is simply no point
          flush();
        }
      }
      flush();
    }

    if (xRange == null) {
      _categoryLabels(data, plot, area);
    } else {
      final text = axisNumbers(xRange, locale);
      final baseline = plot.bottom + 8 + _textSize;
      for (final v in xRange.ticks) {
        _centred(
          switch (axis) {
            PeriodAxis(:final period) => periodLabel(period, v, strings),
            _ => text(v),
          },
          _along(xRange, v, plot.left, plot.right),
          baseline,
          area,
        );
      }
    }
    _legend(rows, area);
  }

  // ---- pies

  void pie(ChartData data, Rect area) {
    final percent = intl.NumberFormat.percentPattern(locale)
      ..maximumFractionDigits = 0;
    final (:slices, :left) = pieSlices(data);
    final total = slices.fold(0.0, (sum, s) => sum + s.value);
    final palette = seriesColorsOf(scheme, slices.length);
    final colors = [
      for (var k = 0; k < slices.length; k++)
        slices[k].index == null ? scheme.outline : palette[k],
    ];
    final rows = _legendRows(
      [
        // the percentage first: a long name is cut short
        for (final s in slices)
          '${percent.format(s.value / total)} ${s.index == null ? others : pathLabel(strings, data.categories[s.index!].path, data.categories[s.index!].label)}',
      ],
      colors,
      area.width,
    );
    final room = Rect.fromLTRB(
      area.left,
      area.top,
      area.right,
      area.bottom - _legendHeight(rows),
    );
    final radius = (room.shortestSide / 2 - 8).clamp(20.0, 400.0);
    final x = room.center.dx, y = room.center.dy;
    final labelColor = scheme.brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    // a hair between the slices, which also works on no background
    final gap = slices.length > 1 ? 0.015 : 0.0;
    var angle = -math.pi / 2;
    for (var k = 0; k < slices.length; k++) {
      final share = slices[k].value / total;
      final sweep = share * 2 * math.pi;
      if (sweep >= 2 * math.pi - 1e-9) {
        shapes.add(SceneCircle(x, y, radius, colors[k]));
      } else {
        shapes.add(
          SceneSlice(
            x,
            y,
            radius,
            angle + gap / 2,
            math.max(sweep - gap, 0),
            colors[k],
          ),
        );
      }
      if (share >= 0.04) {
        final middle = angle + sweep / 2;
        _text(
          percent.format(share),
          x + math.cos(middle) * radius * 0.65,
          y + math.sin(middle) * radius * 0.65 + _textSize * 0.35,
          color: labelColor,
          anchor: TextAnchor.middle,
        );
      }
      angle += sweep;
    }
    _legend(rows, area);
  }

  // ---- scatter

  /// X and Y by letter: the screen's arrows are not in the bundled font.
  void scatter(ScatterData data, Rect area) {
    final colors = seriesColorsOf(scheme, data.series.length);
    final rows = data.series.length > 1 || data.series.first.label.isNotEmpty
        ? _legendRows(
            [
              for (final s in data.series)
                pathLabel(strings, s.path ?? DimensionPath.root, s.label),
            ],
            colors,
            area.width,
          )
        : const <List<_LegendEntry>>[];
    final legend = _legendHeight(rows);
    final below = legend + 8 + 2 * line + 4;
    var biggest = 0.0;
    for (final p in data.points) {
      biggest = math.max(biggest, scatterDotRadius(p));
    }
    final room = biggest + 2;
    final height = area.height - below;
    final yRange = AxisRange(
      withDotRoom(
        [for (final p in data.points) p.y],
        extent: height,
        radius: room,
      ),
      includeZero: false,
      ticks: ticksFor(height),
    );
    final yNumbers = axisNumbers(yRange, locale);
    final plot = _plot(area, yRange, yNumbers, below: below, right: 24);
    final xRange = AxisRange(
      withDotRoom(
        [for (final p in data.points) p.x],
        extent: plot.width,
        radius: room,
      ),
      includeZero: false,
      ticks: ticksFor(plot.width, per: 90),
    );
    final xNumbers = axisNumbers(xRange, locale);
    _valueAxis(yRange, plot, yNumbers);
    final baseline = plot.bottom + 8 + _textSize;
    for (final v in xRange.ticks) {
      final x = _along(xRange, v, plot.left, plot.right);
      _gridLine(x, plot.top, x, plot.bottom);
      _centred(xNumbers(v), x, baseline, area);
    }
    for (var s = 0; s < data.series.length; s++) {
      for (final p in data.series[s].points) {
        shapes.add(
          SceneCircle(
            _along(xRange, p.x, plot.left, plot.right),
            _along(yRange, p.y, plot.bottom, plot.top),
            scatterDotRadius(p),
            colors[s].withValues(alpha: scatterDotAlpha(data)),
          ),
        );
      }
    }
    _centred(
      _fit('X: ${data.xLabel}  ·  Y: ${data.yLabel}', plot.width),
      plot.center.dx,
      baseline + line + 4,
      area,
    );
    _legend(rows, area);
  }
}
