import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:tessera_flutter/tessera_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import 'chart_content.dart';
import 'chart_settings.dart';

/// Draws [content] with fl_chart: this file is the whole adapter between
/// the engine's chart data and the chart package. Reshaped from the tessera
/// example app's `chart_widgets.dart`.
class ChartFigure extends StatelessWidget {
  const ChartFigure({super.key, required this.content});

  final ChartContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (content.problem case final problem?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(switch (problem) {
            ChartProblem.nothing => l10n.chartNothing,
            ChartProblem.needsTwoValues => l10n.chartNeedsTwoValues,
            ChartProblem.noBreakdown => l10n.chartNoBreakdown,
            ChartProblem.noPositive => l10n.chartNoPositive,
          }, textAlign: TextAlign.center),
        ),
      );
    }
    if (content.scatter case final data?) return _scatter(context, data);
    final data = content.data!;
    return switch (content.kind) {
      ChartKind.bar => _bars(context, data, stacked: false),
      ChartKind.stacked => _bars(context, data, stacked: true),
      ChartKind.line => _line(context, data),
      ChartKind.pie => _pie(context, data),
      ChartKind.scatter => throw StateError('a scatter chart has no ChartData'),
    };
  }
}

/// A palette of visually distinct hues, one per series, computed in OKLCH
/// like the grid's hue levels; the first hue is the theme's primary.
List<Color> seriesColors(BuildContext context, int count) {
  final scheme = Theme.of(context).colorScheme;
  final start = Oklch.fromArgb(scheme.primary.toARGB32()).hue;
  final dark = scheme.brightness == Brightness.dark;
  return [
    for (var i = 0; i < math.max(count, 1); i++)
      Color(
        Oklch(
          dark ? 0.72 : 0.58,
          0.14,
          (start + i * HueLevels.goldenAngle) % 360,
        ).toArgb(),
      ),
  ];
}

/// A round tick interval (1, 2, 5 × 10ⁿ) giving about [ticks] steps
/// over [range]; fl_chart's default crowds the axis on a tall chart.
double niceInterval(double range, {int ticks = 8}) {
  if (range <= 0 || !range.isFinite) return 1;
  final raw = range / ticks;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final unit = raw / magnitude;
  final step = unit <= 1
      ? 1.0
      : unit <= 2
      ? 2.0
      : unit <= 5
      ? 5.0
      : 10.0;
  return step * magnitude;
}

/// Ticks that fit an axis of [extent] pixels, one per [per] pixels.
int _ticksFor(double extent, {double per = 50}) =>
    (extent / per).floor().clamp(3, 8);

/// An axis over [values]: a [niceInterval] for its extent (including zero
/// unless [includeZero] is false) and the extent rounded outwards to whole
/// intervals, so the axis ends on labelled ticks instead of a max label
/// overlapping the tick below it. Whole units on a period axis
/// ([minInterval] 1).
class AxisRange {
  factory AxisRange(
    Iterable<double> values, {
    bool includeZero = true,
    int ticks = 8,
    double minInterval = 0,
  }) {
    var lo = includeZero ? 0.0 : double.infinity;
    var hi = includeZero ? 0.0 : double.negativeInfinity;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (!lo.isFinite) lo = hi = 0;
    final interval = math.max(niceInterval(hi - lo, ticks: ticks), minInterval);
    final min = (lo / interval).floorToDouble() * interval;
    final max = (hi / interval).ceilToDouble() * interval;
    return AxisRange._(interval, min, max == min ? min + interval : max);
  }

  const AxisRange._(this.interval, this.min, this.max);

  final double interval;
  final double min;
  final double max;

  /// The labelled positions, for measuring and comparing their labels.
  Iterable<double> get ticks sync* {
    final count = ((max - min) / interval).round();
    for (var i = 0; i <= count; i++) {
      yield min + i * interval;
    }
  }
}

/// How the numbers of an axis read in [locale]: short forms ("12K", "3.4M")
/// from five digits up, unless they would make two ticks read the same,
/// and as many decimals as the interval needs.
String Function(double) axisNumbers(AxisRange range, String locale) {
  final biggest = math.max(range.min.abs(), range.max.abs());
  final decimals = range.interval >= 1
      ? 0
      : (-math.log(range.interval) / math.ln10).ceil().clamp(1, 6);
  final plain = intl.NumberFormat.decimalPattern(locale)
    ..maximumFractionDigits = decimals
    ..minimumFractionDigits = decimals;
  if (biggest < 10000) return plain.format;
  final short = intl.NumberFormat.compact(locale: locale)
    ..maximumFractionDigits = 1;
  final labels = range.ticks.map(short.format).toList();
  return labels.toSet().length == labels.length ? short.format : plain.format;
}

/// Width of [text] in [style], at the user's text size.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Reserved width for the [numbers] of the ticks of [range]: the widest,
/// and the gap fl_chart leaves ([SideTitleWidget.space]).
double _axisWidth(
  BuildContext context,
  AxisRange range,
  String Function(double) numbers,
  TextStyle style,
) =>
    [for (final v in range.ticks) _textWidth(context, numbers(v), style)]
        .fold(24.0, math.max) +
    12;

const _axisFontSize = 10.0;

TextStyle _axisStyle(BuildContext context) => TextStyle(
  fontSize: _axisFontSize,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

/// The legend fl_chart does not draw: a swatch per series. Scrolls when
/// there is no room for it all.
Widget _legend(BuildContext context, List<String> labels, List<Color> colors) =>
    Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 76),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (var i = 0; i < labels.length; i++)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 12, color: colors[i]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          labels[i],
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

/// Axis titles: numbers on the left at the ticks of [left], [bottom] below.
/// fl_chart labels the axis ends as well, so the charts round their ranges
/// to whole intervals ([AxisRange]) and the end labels fall on ticks.
FlTitlesData _titles(
  BuildContext context, {
  required AxisRange left,
  required Widget Function(double value, TitleMeta meta) bottom,
  double? bottomInterval,
  double bottomSize = 28,
  // the end labels of a numeric or time axis collide with their neighbours
  bool bottomEnds = true,
}) {
  final numbers = axisNumbers(left, Localizations.localeOf(context).toString());
  final style = _axisStyle(context);
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: _axisWidth(context, left, numbers, style),
        interval: left.interval,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          child: Text(numbers(v), style: style, softWrap: false),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: bottomSize,
        interval: bottomInterval,
        minIncluded: bottomEnds,
        maxIncluded: bottomEnds,
        getTitlesWidget: bottom,
      ),
    ),
  );
}

/// Grid lines on the same intervals as the titles.
FlGridData _grid(
  BuildContext context,
  double horizontalInterval, {
  double? verticalInterval,
}) {
  final line = FlLine(
    color: Theme.of(context).colorScheme.outlineVariant,
    strokeWidth: 1,
  );
  return FlGridData(
    horizontalInterval: horizontalInterval,
    drawVerticalLine: verticalInterval != null,
    verticalInterval: verticalInterval,
    getDrawingHorizontalLine: (_) => line,
    getDrawingVerticalLine: (_) => line,
  );
}

/// A bottom title for a numeric or period axis.
Widget _bottomTitle(BuildContext context, String text, TitleMeta meta) =>
    SideTitleWidget(
      meta: meta,
      child: Text(text, style: _axisStyle(context)),
    );

/// Room on the right for a bottom title near the chart's edge.
const _rightMargin = EdgeInsets.only(right: 24);

/// fl_chart's default wraps a group's name and value into many lines.
const _tooltipWidth = 260.0;

TextStyle _tooltipStyle(BuildContext context) =>
    TextStyle(color: Theme.of(context).colorScheme.onInverseSurface);

Color _tooltipColor(BuildContext context) =>
    Theme.of(context).colorScheme.inverseSurface;

/// A date, short enough for an axis: the time only when it has one.
String _dateText(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${d.year}-${two(d.month)}-${two(d.day)}';
  return d.hour == 0 && d.minute == 0 && d.second == 0
      ? date
      : '$date ${two(d.hour)}:${two(d.minute)}';
}

/// One group's own name. A raw date reads short: the engine's default has
/// the whole timestamp, which fits a table's column but not an axis.
String _groupText(TesseraStrings strings, DimensionValue e) =>
    switch (e.value) {
      null => strings.emptyGroup,
      final DateTime d => _dateText(d),
      final value => strings.formatValue(e.dimension, value),
    };

/// A group's label with its ancestors when it sits deeper than the first
/// level (visible leaves under an expanded group): "Electronics › Africa",
/// so two "(empty)" groups — or 2024's Q1 and 2025's — can be told apart.
/// [own] names the summary, which has no path.
String pathLabel(
  TesseraStrings strings,
  DimensionPath path,
  String own, {
  String separator = ' › ',
}) => path.isRoot
    ? own
    : path.entries.map((e) => _groupText(strings, e)).join(separator);

List<String> _categoryLabels(BuildContext context, ChartData data) {
  final strings = TesseraLocalizations.of(context);
  return [for (final c in data.categories) pathLabel(strings, c.path, c.label)];
}

List<String> _seriesLabels(BuildContext context, ChartData data) {
  final strings = TesseraLocalizations.of(context);
  return [for (final s in data.series) pathLabel(strings, s.path, s.label)];
}

/// Whether any category sits below the first level.
bool _deep(ChartData data) => data.categories.any((c) => c.path.length > 1);

/// Height of the bottom titles: two lines for deep categories.
double _bottomSize(ChartData data) => _deep(data) ? 48 : 28;

/// Narrowest slot a category's name is written in: narrower ones share
/// their name's slot with their neighbours, whose names are left out. Text
/// may be cut short and still say something; a date or a number may not,
/// so it needs its whole width.
double _minLabelWidth(BuildContext context, ChartData data, TextStyle style) {
  const atLeast = 48.0;
  final strings = TesseraLocalizations.of(context);
  final cs = data.categories;
  if (!cs.every((c) => c.value is DateTime || c.value is num)) return atLeast;
  return cs
          .map(
            (c) =>
                _textWidth(context, pathLabel(strings, c.path, c.label), style),
          )
          .fold(atLeast - 8, math.max) +
      8;
}

/// Bottom titles naming the categories at integer positions; a deep
/// category's own label goes on a second line under its ancestors
/// ("Electronics › North America" would not fit). Where they do not all
/// fit only every n-th is written; the tooltip names the others.
Widget Function(double, TitleMeta) _categoryTitles(
  BuildContext context,
  ChartData data,
) {
  final strings = TesseraLocalizations.of(context);
  final style = _axisStyle(context);
  final minWidth = _minLabelWidth(context, data, style);
  final ancestorsOf = [
    for (final c in data.categories)
      c.path.length > 1
          ? c.path.entries
                .take(c.path.length - 1)
                .map((e) => _groupText(strings, e))
                .join(' › ')
          : null,
  ];
  return (v, meta) {
    final i = v.round();
    if ((v - i).abs() > 1e-6 || i < 0 || i >= data.categories.length) {
      return const SizedBox.shrink();
    }
    final slot = meta.parentAxisSize / data.categories.length;
    final step = (minWidth / slot).ceil().clamp(1, 1 << 20);
    if (i % step != 0) return const SizedBox.shrink();
    final category = data.categories[i];
    final own = category.path.isRoot
        ? category.label
        : _groupText(strings, category.path.last);
    final ancestors = ancestorsOf[i];
    Widget line(String text) => Text(
      text,
      style: style,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
    return SideTitleWidget(
      meta: meta,
      // a name wider than its bar stays on the chart at both ends
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
      child: SizedBox(
        width: slot * step,
        child: ancestors == null
            ? line(own)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [line(ancestors), line(own)],
              ),
      ),
    );
  };
}

/// Grouped or stacked bars: one group per category, one rod per series
/// (or one rod with a stack item per series).
Widget _bars(BuildContext context, ChartData data, {required bool stacked}) {
  final strings = TesseraLocalizations.of(context);
  final colors = seriesColors(context, data.series.length);
  final labels = _categoryLabels(context, data);
  final series = _seriesLabels(context, data);
  final tops = <double>[];
  final groups = <BarChartGroupData>[];
  // rod widths so the groups fill the chart, set once the width is known
  double rodWidth(double chartWidth) {
    final slots =
        data.categories.length * (stacked ? 2 : data.series.length + 1);
    return ((chartWidth - 60) / math.max(slots, 1)).clamp(1.0, 56.0);
  }

  for (var i = 0; i < data.categories.length; i++) {
    if (stacked) {
      // positives stack upwards from 0, negatives downwards
      var top = 0.0, bottom = 0.0;
      final items = <BarChartRodStackItem>[];
      for (var s = 0; s < data.series.length; s++) {
        final v = data.series[s].values[i];
        if (v == null || v == 0) continue;
        if (v > 0) {
          items.add(BarChartRodStackItem(top, top + v, colors[s]));
          top += v;
        } else {
          items.add(BarChartRodStackItem(bottom + v, bottom, colors[s]));
          bottom += v;
        }
      }
      tops.addAll([top, bottom]);
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              fromY: bottom,
              toY: top,
              rodStackItems: items,
              color: Colors.transparent,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      );
    } else {
      tops.addAll([for (final s in data.series) s.values[i] ?? 0]);
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 1,
          barRods: [
            for (var s = 0; s < data.series.length; s++)
              BarChartRodData(
                toY: data.series[s].values[i] ?? 0,
                color: colors[s],
                borderRadius: BorderRadius.zero,
              ),
          ],
        ),
      );
    }
  }
  return Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final range = AxisRange(
              tops,
              ticks: _ticksFor(constraints.maxHeight),
            );
            return BarChart(
              BarChartData(
                minY: range.min,
                maxY: range.max,
                barGroups: [
                  for (final g in groups)
                    g.copyWith(
                      barRods: [
                        for (final r in g.barRods)
                          r.copyWith(width: rodWidth(constraints.maxWidth)),
                      ],
                    ),
                ],
                titlesData: _titles(
                  context,
                  left: range,
                  bottom: _categoryTitles(context, data),
                  bottomSize: _bottomSize(data),
                ),
                gridData: _grid(context, range.interval),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => _tooltipColor(context),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    maxContentWidth: _tooltipWidth,
                    getTooltipItem: (group, gi, rod, ri) {
                      final text = stacked
                          ? [
                              labels[group.x],
                              for (var s = 0; s < data.series.length; s++)
                                if (data.series[s].values[group.x]
                                    case final v?)
                                  '${series[s]}: ${strings.formatNumber(v)}',
                            ].join('\n')
                          : '${labels[group.x]}\n${series[ri]}: '
                                '${strings.formatNumber(data.series[ri].values[group.x] ?? 0)}';
                      return BarTooltipItem(text, _tooltipStyle(context));
                    },
                  ),
                ),
              ),
              duration: Duration.zero,
            );
          },
        ),
      ),
      if (data.series.length > 1 || !data.series.first.path.isRoot)
        _legend(context, series, colors),
    ],
  );
}

/// A line chart's horizontal axis.
sealed class LineAxis {
  const LineAxis();

  /// A period axis when every category is a period of one length, a numeric
  /// one when every value is a plain number, else evenly spaced names.
  static LineAxis of(ChartData data) {
    final cs = data.categories;
    // a single point has no scale, and would sit at the end of one
    if (cs.length < 2) return const CategoryAxis();
    final periods = {for (final c in cs) _periodOf(c)};
    if (periods.length == 1 && periods.first != null) {
      return PeriodAxis(periods.first!);
    }
    // a timestamp column with some values at midnight is still timestamps
    if (cs.every((c) => c.value is DateTime)) {
      return const PeriodAxis(ChartPeriod.instant);
    }
    // a date part without a period start (a month on its own, a weekday)
    // is a number too, but an ordinal one: its months are named
    if (cs.every(
      (c) =>
          c.number != null &&
          c.path.entries.isNotEmpty &&
          c.path.last.dimension is! DatePartDimension,
    )) {
      return const NumericAxis();
    }
    return const CategoryAxis();
  }
}

final class CategoryAxis extends LineAxis {
  const CategoryAxis();
}

final class NumericAxis extends LineAxis {
  const NumericAxis();
}

final class PeriodAxis extends LineAxis {
  const PeriodAxis(this.period);

  final ChartPeriod period;
}

/// The length of the periods on a time axis. Its positions count these,
/// so that the labels fall on whole years or months rather than wherever
/// a number of days ends, and a month without sales leaves its gap.
enum ChartPeriod { year, quarter, month, week, day, instant }

ChartPeriod? _periodOf(ChartCategory c) {
  if (c.periodStart == null) return null;
  if (c.value case final DateTime d) {
    final midnight = d.hour == 0 && d.minute == 0 && d.second == 0;
    return midnight ? ChartPeriod.day : ChartPeriod.instant;
  }
  bool has(DatePart part) => c.path.entries.any(
    (e) =>
        e.dimension is DatePartDimension &&
        (e.dimension as DatePartDimension).part == part,
  );
  final last = c.path.last.dimension;
  if (last is! DatePartDimension) return null;
  return switch (last.part) {
    DatePart.year => ChartPeriod.year,
    DatePart.quarter => ChartPeriod.quarter,
    DatePart.month => ChartPeriod.month,
    DatePart.week => ChartPeriod.week,
    // the 5th of no month in particular, or 14:00 of no day: not positions
    DatePart.day => has(DatePart.month) ? ChartPeriod.day : null,
    DatePart.hour => has(DatePart.day) ? ChartPeriod.instant : null,
    DatePart.weekday => null,
  };
}

const _dayMs = 86400000.0;

/// [date]'s position on an axis of [period]s.
double periodPosition(ChartPeriod period, DateTime date) => switch (period) {
  ChartPeriod.year => date.year.toDouble(),
  ChartPeriod.quarter => (date.year * 4 + (date.month - 1) ~/ 3).toDouble(),
  ChartPeriod.month => (date.year * 12 + date.month - 1).toDouble(),
  // 1970-01-05 was a Monday, so whole numbers are the ISO weeks' Mondays
  ChartPeriod.week =>
    ((date.millisecondsSinceEpoch / _dayMs - 4) / 7).roundToDouble(),
  ChartPeriod.day => (date.millisecondsSinceEpoch / _dayMs).roundToDouble(),
  ChartPeriod.instant => date.millisecondsSinceEpoch / _dayMs,
};

/// The label of position [v] on an axis of [period]s.
String periodLabel(ChartPeriod period, double v, TesseraStrings strings) {
  String two(int n) => n.toString().padLeft(2, '0');
  String date(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
  final n = v.round();
  return switch (period) {
    ChartPeriod.year => '$n',
    ChartPeriod.quarter => '${n ~/ 4} ${strings.quarter(n % 4 + 1)}',
    ChartPeriod.month => '${n ~/ 12}-${two(n % 12 + 1)}',
    ChartPeriod.week => date(
      DateTime.fromMillisecondsSinceEpoch(
        ((v * 7 + 4) * _dayMs).round(),
        isUtc: true,
      ),
    ),
    ChartPeriod.day || ChartPeriod.instant => date(
      DateTime.fromMillisecondsSinceEpoch((v * _dayMs).round(), isUtc: true),
    ),
  };
}

/// One line per series, on the axis [LineAxis.of] finds.
Widget _line(BuildContext context, ChartData source) {
  final strings = TesseraLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  // an empty group has no place on a numeric or time axis, but is a
  // category like any other on a categorical one
  final trimmed = source.withoutEmpty();
  final axis = LineAxis.of(trimmed);
  final data = axis is CategoryAxis ? source : trimmed;
  final colors = seriesColors(context, data.series.length);
  final series = _seriesLabels(context, data);
  final labels = _categoryLabels(context, data);
  double x(int i) => switch (axis) {
    PeriodAxis(:final period) => periodPosition(
      period,
      data.categories[i].periodStart!,
    ),
    NumericAxis() => data.categories[i].number!.toDouble(),
    CategoryAxis() => i.toDouble(),
  };
  final labelAt = <double, String>{
    for (var i = 0; i < data.categories.length; i++) x(i): labels[i],
  };
  return Column(
    children: [
      Expanded(
        child: Padding(
          padding: _rightMargin,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final range = AxisRange([
                for (final s in data.series)
                  for (final v in s.values) ?v,
              ], ticks: _ticksFor(constraints.maxHeight));
              // a real axis is rounded to its ticks too; positions stay
              final xRange = axis is CategoryAxis || data.categories.isEmpty
                  ? null
                  : AxisRange(
                      [for (var i = 0; i < data.categories.length; i++) x(i)],
                      includeZero: false,
                      ticks: _ticksFor(
                        constraints.maxWidth,
                        // dates are wide
                        per: axis is PeriodAxis ? 110 : 90,
                      ),
                      minInterval: axis is PeriodAxis ? 1 : 0,
                    );
              final numbers = xRange == null
                  ? null
                  : axisNumbers(xRange, locale);
              Widget bottom(double v, TitleMeta meta) => switch (axis) {
                CategoryAxis() => _categoryTitles(context, data)(v, meta),
                NumericAxis() => _bottomTitle(context, numbers!(v), meta),
                PeriodAxis(:final period) => _bottomTitle(
                  context,
                  periodLabel(period, v, strings),
                  meta,
                ),
              };
              // half a slot of room at both ends of a categorical axis
              return LineChart(
                LineChartData(
                  minY: range.min,
                  maxY: range.max,
                  minX: xRange?.min ?? -0.5,
                  maxX: xRange?.max ?? data.categories.length - 0.5,
                  lineBarsData: [
                    for (var s = 0; s < data.series.length; s++)
                      LineChartBarData(
                        color: colors[s],
                        barWidth: 2,
                        dotData: FlDotData(show: data.categories.length <= 60),
                        spots: [
                          for (var i = 0; i < data.categories.length; i++)
                            if (data.series[s].values[i] case final v?)
                              FlSpot(x(i), v)
                            // a blank cell breaks the line on a categorical
                            // axis; on a real axis there is simply no point
                            else if (axis is CategoryAxis)
                              FlSpot.nullSpot,
                        ],
                      ),
                  ],
                  titlesData: _titles(
                    context,
                    left: range,
                    bottom: bottom,
                    bottomInterval: xRange?.interval ?? 1,
                    bottomEnds: xRange == null,
                    bottomSize: xRange == null ? _bottomSize(data) : 28,
                  ),
                  gridData: _grid(context, range.interval),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _tooltipColor(context),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      maxContentWidth: _tooltipWidth,
                      getTooltipItems: (spots) => [
                        for (var k = 0; k < spots.length; k++)
                          LineTooltipItem(
                            [
                              if (k == 0) labelAt[spots[k].x] ?? '',
                              '${series[spots[k].barIndex]}: '
                                  '${strings.formatNumber(spots[k].y)}',
                            ].join('\n'),
                            _tooltipStyle(context),
                          ),
                      ],
                    ),
                  ),
                ),
                duration: Duration.zero,
              );
            },
          ),
        ),
      ),
      if (data.series.length > 1 || !data.series.first.path.isRoot)
        _legend(context, series, colors),
    ],
  );
}

/// One series as a pie, the largest slice first, see [pieSlices]; the
/// legend carries the percentages too small to fit on their slice.
Widget _pie(BuildContext context, ChartData data) {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final percent = intl.NumberFormat.percentPattern(
    Localizations.localeOf(context).toString(),
  )..maximumFractionDigits = 0;
  final (:slices, :left) = pieSlices(data);
  final labels = _categoryLabels(context, data);
  final total = slices.fold(0.0, (sum, s) => sum + s.value);
  final colors = [
    for (var k = 0; k < slices.length; k++)
      if (slices[k].index == null)
        scheme.outline
      else
        seriesColors(context, slices.length)[k],
  ];
  return Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => PieChart(
            PieChartData(
              sectionsSpace: 1,
              centerSpaceRadius: 0,
              startDegreeOffset: -90,
              sections: [
                for (var k = 0; k < slices.length; k++)
                  PieChartSectionData(
                    value: slices[k].value,
                    color: colors[k],
                    title: slices[k].value / total >= 0.04
                        ? percent.format(slices[k].value / total)
                        : '',
                    titleStyle: TextStyle(
                      fontSize: 11,
                      color: scheme.brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                    ),
                    // fill the pane
                    radius: (constraints.biggest.shortestSide / 2 - 8).clamp(
                      20.0,
                      400.0,
                    ),
                  ),
              ],
            ),
            duration: Duration.zero,
          ),
        ),
      ),
      _legend(context, [
        // the percentage first: a long name is cut short
        for (final s in slices)
          '${percent.format(s.value / total)} '
              '${s.index == null ? l10n.chartOthers : labels[s.index!]}',
      ], colors),
    ],
  );
}

/// One dot per point, coloured by series; a dot grows with its fact count.
Widget _scatter(BuildContext context, ScatterData data) {
  final strings = TesseraLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final colors = seriesColors(context, data.series.length);
  String seriesLabel(ScatterSeries s) =>
      pathLabel(strings, s.path ?? DimensionPath.root, s.label);
  final spots = <ScatterSpot>[];
  final labels = <(double, double), String>{};
  for (var s = 0; s < data.series.length; s++) {
    for (final p in data.series[s].points) {
      spots.add(
        ScatterSpot(
          p.x,
          p.y,
          dotPainter: FlDotCirclePainter(
            color: colors[s].withValues(alpha: 0.85),
            radius: 3 + math.log(p.factCount + 1),
          ),
        ),
      );
      final series = seriesLabel(data.series[s]);
      labels[(p.x, p.y)] = [
        if (p.label.isNotEmpty) pathLabel(strings, p.path!, p.label),
        if (series.isNotEmpty) series,
        '${data.xLabel}: ${strings.formatNumber(p.x)}',
        '${data.yLabel}: ${strings.formatNumber(p.y)}',
      ].join('\n');
    }
  }
  return Column(
    children: [
      Expanded(
        child: Padding(
          padding: _rightMargin,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final xRange = AxisRange(
                [for (final s in spots) s.x],
                includeZero: false,
                ticks: _ticksFor(constraints.maxWidth, per: 90),
              );
              final yRange = AxisRange(
                [for (final s in spots) s.y],
                includeZero: false,
                ticks: _ticksFor(constraints.maxHeight),
              );
              final xNumbers = axisNumbers(xRange, locale);
              return ScatterChart(
                ScatterChartData(
                  minX: xRange.min,
                  maxX: xRange.max,
                  minY: yRange.min,
                  maxY: yRange.max,
                  scatterSpots: spots,
                  titlesData: _titles(
                    context,
                    left: yRange,
                    bottom: (v, meta) =>
                        _bottomTitle(context, xNumbers(v), meta),
                    bottomInterval: xRange.interval,
                    bottomEnds: false,
                  ),
                  gridData: _grid(
                    context,
                    yRange.interval,
                    verticalInterval: xRange.interval,
                  ),
                  borderData: FlBorderData(show: false),
                  scatterTouchData: ScatterTouchData(
                    touchTooltipData: ScatterTouchTooltipData(
                      getTooltipColor: (_) => _tooltipColor(context),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      maxContentWidth: _tooltipWidth,
                      getTooltipItems: (spot) => ScatterTooltipItem(
                        labels[(spot.x, spot.y)] ?? '',
                        textStyle: _tooltipStyle(context),
                      ),
                    ),
                  ),
                ),
                duration: Duration.zero,
              );
            },
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${data.xLabel} → · ${data.yLabel} ↑',
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
      if (data.series.length > 1 || data.series.first.label.isNotEmpty)
        _legend(context, [for (final s in data.series) seriesLabel(s)], colors),
    ],
  );
}
