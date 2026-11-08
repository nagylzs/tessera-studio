import 'package:tessera_flutter/tessera_flutter.dart';

import 'chart_settings.dart';

/// Why there is nothing to draw.
enum ChartProblem {
  /// The cube has no groups or values to draw.
  nothing,

  /// A scatter chart with fewer than two aggregates.
  needsTwoValues,

  /// The same for a breakdown, where a scatter of records would do.
  needsTwoValuesOrRecords,

  /// A scatter of records with fewer than two numeric columns.
  needsTwoMeasures,

  /// The current cell pins every dimension, or there is none at all.
  noBreakdown,

  /// A pie chart without one positive value.
  noPositive,
}

/// Groups a chart draws at most, by kind. More cannot be told apart, and
/// the first ones of a large pivot are drawn with a note saying so.
int maxCategories(ChartKind kind) => switch (kind) {
  ChartKind.bar || ChartKind.stacked => 60,
  ChartKind.line => 500,
  // every slice is read, the small ones then merge: a part of the slices
  // would make wrong percentages
  ChartKind.pie => 1 << 20,
  ChartKind.scatter => 1000,
};

/// Series a chart draws at most: their colours and legend stop helping.
const maxSeries = 12;

/// Slices a pie shows: the largest, and one more for all the others.
const maxPieSlices = 12;

/// Dots a scatter of records draws at most. Beyond it they are taken at
/// even steps through the records, so the cloud keeps its shape wherever
/// the file is sorted by, and the caption says so.
const maxRecords = 5000;

/// What a chart draws, resolved from [ChartSettings] against a cube: the
/// data, or the [problem] instead, the choices in force and what was cut.
final class ChartContent {
  const ChartContent({
    required this.kind,
    required this.source,
    required this.facts,
    required this.value,
    required this.x,
    required this.y,
    required this.dimensions,
    this.category,
    this.series,
    this.cell,
    this.data,
    this.scatter,
    this.problem,
    this.categoriesTotal = 0,
    this.seriesTotal = 0,
    this.records = false,
    this.measures = const [],
    this.xMeasure,
    this.yMeasure,
    this.recordsShown = 0,
    this.recordsTotal = 0,
  });

  final ChartKind kind;
  final ChartSource source;
  final FactTable facts;
  final Aggregate value;
  final Aggregate x;
  final Aggregate y;

  /// What the chart may be broken down by: the file's, and the pivot's own.
  final List<Dimension> dimensions;

  /// All data or the current cell only ([ChartSource.breaksDown]).
  final Dimension? category;
  final Dimension? series;

  /// Current cell only; `null` while no cell is current: the grand total.
  final CubeCell? cell;

  final ChartData? data;
  final ScatterData? scatter;
  final ChartProblem? problem;

  /// Groups and series available, before [maxCategories] and [maxSeries].
  final int categoriesTotal;
  final int seriesTotal;

  /// A scatter of records ([ChartSettings.records]): one dot per record.
  final bool records;

  /// What a scatter of records may take as coordinates, see
  /// [chartMeasures]; empty for any other chart.
  final List<Measure> measures;
  final Measure? xMeasure;
  final Measure? yMeasure;

  /// Records drawn and records there are, see [maxRecords].
  final int recordsShown;
  final int recordsTotal;

  int get categoriesShown => categoriesTotal < maxCategories(kind)
      ? categoriesTotal
      : maxCategories(kind);
  int get seriesShown => data?.series.length ?? scatter?.series.length ?? 0;
}

/// Whether [dimension] has an order of its own (dates, numbers), which a
/// chart keeps; the groups of any other read best largest first.
bool hasOwnOrder(Dimension dimension, FactTable facts) {
  if (dimension is DatePartDimension) return true;
  if (dimension is ColumnDimension) {
    final type = facts.findColumn(dimension.sourceColumn)?.type;
    return type != null &&
        type != ColumnType.text &&
        type != ColumnType.boolean;
  }
  return false;
}

Dimension? _fewestValues(List<Dimension> dimensions, FactTable facts) {
  Dimension? best;
  var fewest = 1 << 62;
  for (final d in dimensions) {
    if (d is! ColumnDimension) continue;
    final column = facts.findColumn(d.sourceColumn);
    if (column == null || column.type != ColumnType.text) continue;
    if (column.distinctCount > 1 && column.distinctCount < fewest) {
      best = d;
      fewest = column.distinctCount;
    }
  }
  return best;
}

/// The dimensions a chart can use: [dimensions] and the pivot's own (a
/// computed one is not among the standard ones).
List<Dimension> chartDimensions(Cube cube, List<Dimension> dimensions) => [
  ...dimensions,
  for (final axis in [cube.spec.rows, cube.spec.columns])
    for (final d in axis.dimensions)
      if (!dimensions.contains(d.dimension)) d.dimension,
];

/// The measures a scatter of records can use: the numeric columns, and the
/// pivot's own (a computed one is not among the columns).
List<Measure> chartMeasures(Cube cube) {
  final measures = standardMeasures(cube.facts);
  for (final a in cube.spec.aggregates) {
    if (a is MeasureAggregate && !measures.contains(a.measure)) {
      measures.add(a.measure);
    }
  }
  return measures;
}

/// The rows of [facts] that [filter] lets through and that have both [x]
/// and [y], at most [limit] of them, taken at even steps; and how many
/// there are in all.
({List<int> rows, int total}) sampleRecords(
  FactTable facts, {
  required Measure x,
  required Measure y,
  FactFilter? filter,
  int limit = maxRecords,
}) {
  final pass = filter?.compile(facts);
  final all = <int>[];
  for (var row = 0; row < facts.rowCount; row++) {
    if (pass != null && !pass(row)) continue;
    if (facts.measureValue(row, x) == null) continue;
    if (facts.measureValue(row, y) == null) continue;
    all.add(row);
  }
  if (all.length <= limit) return (rows: all, total: all.length);
  return (
    rows: [for (var i = 0; i < limit; i++) all[i * all.length ~/ limit]],
    total: all.length,
  );
}

/// Resolves [settings] against [cube] and reads the chart's data, never
/// more cells than it draws. [shown] are the aggregates the grid shows;
/// [cell] the current cell, for [ChartSource.cell].
///
/// A breakdown ([ChartSource.all], [ChartSource.cell]) is read from a cube
/// of its own over the facts that the pivot's filter, and the cell's
/// coordinate, let through.
ChartContent chartContent({
  required Cube cube,
  required ChartSettings settings,
  required List<Dimension> dimensions,
  required TesseraStrings strings,
  List<Aggregate>? shown,
  CubeCell? cell,
}) {
  final facts = cube.facts;
  final aggregates = cube.spec.aggregates;
  final firstShown =
      shown?.where(aggregates.contains).firstOrNull ?? aggregates.first;
  final value = aggregates.contains(settings.value)
      ? settings.value!
      : firstShown;
  final x = aggregates.contains(settings.x) ? settings.x! : firstShown;
  final y = aggregates.contains(settings.y) && settings.y != x
      ? settings.y!
      : aggregates.firstWhere((a) => a != x, orElse: () => x);
  final all = chartDimensions(cube, dimensions);
  final kind = settings.kind;
  final isCell = settings.source == ChartSource.cell;
  final breaksDown = settings.source.breaksDown;
  final isScatter = kind == ChartKind.scatter;
  final records = isScatter && breaksDown && settings.records;
  // a record has no aggregates: its columns, by default those the
  // scatter's aggregates read
  final measures = records ? chartMeasures(cube) : const <Measure>[];
  Measure? measureOf(Aggregate a) => switch (a) {
    final MeasureAggregate m when measures.contains(m.measure) => m.measure,
    _ => null,
  };
  final xMeasure = measures.contains(settings.xMeasure)
      ? settings.xMeasure
      : measureOf(x) ?? measures.firstOrNull;
  final yMeasure =
      measures.contains(settings.yMeasure) && settings.yMeasure != xMeasure
      ? settings.yMeasure
      : [
          measureOf(y),
          ...measures,
        ].firstWhere((m) => m != null && m != xMeasure, orElse: () => null);

  bool pinned(Dimension d) =>
      isCell && (cell?.coordinate.constrains(d) ?? false);
  final usable = [
    for (final d in all)
      if (!pinned(d)) d,
  ];
  // the first breakdown follows the pivot: its first row dimension (then
  // column dimension) the cell does not pin, else the text column with the
  // fewest values, as the first pivot of a file has, else any
  final category = !breaksDown || records
      ? null
      : usable.contains(settings.category)
      ? settings.category
      : [
              for (final axis in [cube.spec.rows, cube.spec.columns])
                for (final d in axis.dimensions)
                  if (usable.contains(d.dimension)) d.dimension,
            ].firstOrNull ??
            _fewestValues(usable, facts) ??
            usable.firstOrNull;
  final series =
      breaksDown &&
          usable.contains(settings.series) &&
          settings.series != category
      ? settings.series
      : null;

  ChartContent result({
    ChartData? data,
    ScatterData? scatter,
    ChartProblem? problem,
    int categoriesTotal = 0,
    int seriesTotal = 0,
    int recordsShown = 0,
    int recordsTotal = 0,
  }) => ChartContent(
    kind: kind,
    source: settings.source,
    facts: facts,
    value: value,
    x: x,
    y: y,
    dimensions: all,
    category: category,
    series: series,
    cell: isCell ? cell : null,
    data: data,
    scatter: scatter,
    problem: problem,
    categoriesTotal: categoriesTotal,
    seriesTotal: seriesTotal,
    records: records,
    measures: measures,
    xMeasure: xMeasure,
    yMeasure: yMeasure,
    recordsShown: recordsShown,
    recordsTotal: recordsTotal,
  );

  if (records && (xMeasure == null || yMeasure == null)) {
    return result(problem: ChartProblem.needsTwoMeasures);
  }
  if (isScatter && !records && x == y) {
    return result(
      problem: breaksDown
          ? ChartProblem.needsTwoValuesOrRecords
          : ChartProblem.needsTwoValues,
    );
  }
  if (breaksDown && !records && category == null) {
    return result(problem: ChartProblem.noBreakdown);
  }

  // Everything is read from a layout: the pivot's, or for a breakdown one
  // built over its facts, so that the chart can never disagree with a
  // table of the same spec.
  final FactFilter? filter;
  if (isCell) {
    final whole = cube.layout;
    final at = cell ?? whole.cellFor(DimensionPath.root, DimensionPath.root);
    filter = at == null ? cube.spec.filter : cellFilter(whole, at);
  } else {
    filter = cube.spec.filter;
  }

  if (records) {
    final (:rows, :total) = sampleRecords(
      facts,
      x: xMeasure!,
      y: yMeasure!,
      filter: filter,
    );
    final all = ScatterData.ofFacts(
      facts,
      x: xMeasure,
      y: yMeasure,
      series: series,
      rows: rows,
      strings: strings,
    );
    if (all.series.isEmpty) return result(problem: ChartProblem.nothing);
    final scatter = all.series.length <= maxSeries
        ? all
        : ScatterData(
            xLabel: all.xLabel,
            yLabel: all.yLabel,
            xMeasure: all.xMeasure,
            yMeasure: all.yMeasure,
            series: all.series.take(maxSeries).toList(),
          );
    return result(
      scatter: scatter,
      seriesTotal: all.series.length,
      recordsShown: rows.length,
      recordsTotal: total,
    );
  }

  final CubeLayout layout;
  if (breaksDown) {
    layout = Cube(
      facts: facts,
      spec: CubeSpec(
        rows: CubeAxis(
          dimensions: [
            AxisDimension(
              category!,
              sort: hasOwnOrder(category, facts) || isScatter
                  ? null
                  : AxisSort(
                      by: SortBy.aggregate,
                      aggregate: value,
                      direction: SortDirection.descending,
                    ),
            ),
          ],
        ),
        columns: series == null
            ? const CubeAxis()
            : CubeAxis(dimensions: [AxisDimension(series)]),
        aggregates: isScatter ? [x, y] : [value],
        filter: filter,
      ),
    ).layout;
  } else {
    layout = cube.layout;
  }
  final transpose = !breaksDown && settings.transpose;
  final categoryAxis = transpose ? layout.columns : layout.rows;
  final seriesAxis = transpose ? layout.rows : layout.columns;
  final categoryEntries = ChartEntries.leaves.select(categoryAxis);
  final seriesEntries = ChartEntries.leaves.select(seriesAxis);

  ChartEntries first(List<HeaderEntry> entries, int count) =>
      ChartEntries.paths([for (final e in entries.take(count)) e.path]);

  final categories = first(categoryEntries, maxCategories(kind));
  // A pie is one series: the total of each group, or where the pivot hides
  // its totals, its first series.
  final hasTotal = seriesAxis.indexOf(DimensionPath.root) >= 0;
  final seriesChoice = kind == ChartKind.pie
      ? hasTotal
            ? const ChartEntries.paths([DimensionPath.root])
            : first(seriesEntries, 1)
      : first(seriesEntries, maxSeries);
  final seriesTotal = kind == ChartKind.pie ? 1 : seriesEntries.length;

  if (isScatter) {
    final scatter = ScatterData.fromLayout(
      layout,
      x: x,
      y: y,
      // by what they are, not by axis: with transpose it swaps them itself
      points: categories,
      series: seriesChoice,
      transpose: transpose,
      strings: strings,
    );
    return scatter.points.isEmpty
        ? result(problem: ChartProblem.nothing)
        : result(
            scatter: scatter,
            categoriesTotal: categoryEntries.length,
            seriesTotal: seriesTotal,
          );
  }

  final data = ChartData.fromLayout(
    layout,
    aggregate: value,
    rows: transpose ? seriesChoice : categories,
    columns: transpose ? categories : seriesChoice,
    transpose: transpose,
    strings: strings,
  );
  if (data.categories.isEmpty || data.series.isEmpty) {
    return result(problem: ChartProblem.nothing);
  }
  if (kind == ChartKind.pie &&
      !data.series.first.values.any((v) => v != null && v > 0)) {
    return result(problem: ChartProblem.noPositive);
  }
  return result(
    data: data,
    categoriesTotal: categoryEntries.length,
    seriesTotal: seriesTotal,
  );
}

/// A pie's slices: every group with a positive value, largest first.
/// Beyond [maxPieSlices] the smallest merge into one (`index` `null`).
/// [left] counts the groups without a positive value, which a pie cannot
/// show.
({List<({int? index, double value})> slices, int left}) pieSlices(
  ChartData data,
) {
  final values = data.series.first.values;
  final positive = [
    for (var i = 0; i < values.length; i++)
      if (values[i] case final v? when v > 0) (index: i, value: v),
  ]..sort((a, b) => b.value.compareTo(a.value));
  final left = data.categories.length - positive.length;
  if (positive.length <= maxPieSlices) {
    return (
      slices: [for (final p in positive) (index: p.index, value: p.value)],
      left: left,
    );
  }
  final kept = positive.take(maxPieSlices - 1);
  final rest = positive
      .skip(maxPieSlices - 1)
      .fold(0.0, (sum, p) => sum + p.value);
  return (
    slices: [
      for (final p in kept) (index: p.index, value: p.value),
      (index: null, value: rest),
    ],
    left: left,
  );
}
