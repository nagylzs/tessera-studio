import 'dart:ui' show Size;

import 'package:tessera_flutter/tessera_flutter.dart';

/// The chart types the panel draws.
enum ChartKind { bar, stacked, line, pie, scatter }

/// What a chart shows.
enum ChartSource {
  /// The pivot table as it is shown: its visible groups.
  pivot,

  /// All the facts the pivot's filter lets through, broken down by
  /// dimensions of the chart's own, whatever the pivot shows: revenue by
  /// month beside a pivot of regions.
  all,

  /// The facts behind the current cell, broken down by a dimension.
  cell;

  /// Whether the chart picks its own dimensions ([ChartSettings.category],
  /// [ChartSettings.series]) instead of reading the pivot's.
  bool get breaksDown => this != pivot;
}

/// How an exported chart looks. Light on white unless asked, as exports go on
/// paper. On no background the text has to suit the page it will land on,
/// which only the user knows, so [dark] stays a choice of its own.
typedef ChartLook = ({bool dark, bool transparent});

const plainChartLook = (dark: false, transparent: false);

/// Where the chart goes in a window, next to the grid or in its place.
enum ChartPlacement {
  /// Beside the grid: desktops and tablets in landscape.
  beside,

  /// Above the grid: tablets in portrait, narrower desktop windows.
  above,

  /// Instead of the grid, with a button to switch: phones, either way up.
  instead;

  /// Material's "expanded" width: from here two panes fit side by side.
  static const besideFrom = 840.0;

  /// Material's "medium" width: from here both fit one above the other.
  static const aboveFrom = 600.0;

  /// Below this height a phone in landscape has room for one pane only.
  static const besideTallFrom = 480.0;

  /// Below this height two panes one above the other would both be cramped.
  static const aboveTallFrom = 600.0;

  /// The placement in a window of [size]; by window, not by device.
  static ChartPlacement of(Size size) {
    if (size.width >= besideFrom && size.height >= besideTallFrom) {
      return beside;
    }
    if (size.width >= aboveFrom && size.height >= aboveTallFrom) return above;
    return instead;
  }
}

/// What the user chose for a chart. The aggregates and dimensions may no
/// longer exist when the pivot changes under them, so each is only a wish:
/// see `chartContent`, which resolves them against the current cube.
final class ChartSettings {
  const ChartSettings({
    this.kind = ChartKind.bar,
    this.source = ChartSource.pivot,
    this.transpose = false,
    this.value,
    this.x,
    this.y,
    this.category,
    this.series,
    this.records = false,
    this.xMeasure,
    this.yMeasure,
  });

  factory ChartSettings.fromJson(Map<String, Object?> json) {
    const codec = CubeJson.standard;
    Aggregate? aggregate(String key) => json[key] == null
        ? null
        : codec.decodeAggregate((json[key] as Map).cast<String, Object?>());
    Dimension? dimension(String key) => json[key] == null
        ? null
        : codec.decodeDimension((json[key] as Map).cast<String, Object?>());
    Measure? measure(String key) => json[key] == null
        ? null
        : codec.decodeMeasure((json[key] as Map).cast<String, Object?>());
    return ChartSettings(
      kind: ChartKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => ChartKind.bar,
      ),
      source: ChartSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => ChartSource.pivot,
      ),
      transpose: json['transpose'] == true,
      value: aggregate('value'),
      x: aggregate('x'),
      y: aggregate('y'),
      category: dimension('category'),
      series: dimension('series'),
      records: json['records'] == true,
      xMeasure: measure('xMeasure'),
      yMeasure: measure('yMeasure'),
    );
  }

  final ChartKind kind;
  final ChartSource source;

  /// Pivot only: groups from the columns, series from the rows.
  final bool transpose;

  /// The aggregate of a bar, line or pie chart; `null` = the first shown.
  final Aggregate? value;

  /// The aggregates of a scatter chart.
  final Aggregate? x;
  final Aggregate? y;

  /// All data or the current cell ([ChartSource.breaksDown]): the dimension
  /// it is broken down by; `null` = the first one of the pivot the cell does
  /// not pin. The two sources share it, so a switch keeps the breakdown.
  final Dimension? category;

  /// All data or the current cell: a second breakdown, as series.
  final Dimension? series;

  /// A scatter of all data or the current cell: one dot per record, at
  /// [xMeasure] against [yMeasure], instead of one per group of [category].
  final bool records;

  /// The coordinates of a scatter of records: numeric columns, as a record
  /// has no aggregates; `null` = those the scatter's aggregates sum up.
  final Measure? xMeasure;
  final Measure? yMeasure;

  ChartSettings copyWith({
    ChartKind? kind,
    ChartSource? source,
    bool? transpose,
    Aggregate? value,
    Aggregate? x,
    Aggregate? y,
    Dimension? category,
    Dimension? Function()? series,
    bool? records,
    Measure? xMeasure,
    Measure? yMeasure,
  }) => ChartSettings(
    kind: kind ?? this.kind,
    source: source ?? this.source,
    transpose: transpose ?? this.transpose,
    value: value ?? this.value,
    x: x ?? this.x,
    y: y ?? this.y,
    category: category ?? this.category,
    series: series == null ? this.series : series(),
    records: records ?? this.records,
    xMeasure: xMeasure ?? this.xMeasure,
    yMeasure: yMeasure ?? this.yMeasure,
  );

  Map<String, Object?> toJson() {
    const codec = CubeJson.standard;
    return {
      'kind': kind.name,
      'source': source.name,
      if (transpose) 'transpose': true,
      if (value case final a?) 'value': codec.encodeAggregate(a),
      if (x case final a?) 'x': codec.encodeAggregate(a),
      if (y case final a?) 'y': codec.encodeAggregate(a),
      if (category case final d?) 'category': codec.encodeDimension(d),
      if (series case final d?) 'series': codec.encodeDimension(d),
      if (records) 'records': true,
      if (xMeasure case final m?) 'xMeasure': codec.encodeMeasure(m),
      if (yMeasure case final m?) 'yMeasure': codec.encodeMeasure(m),
    };
  }
}

/// The chart the user left files of one structure on, next to their pivot.
final class StoredChart {
  const StoredChart({required this.visible, required this.settings});

  /// A damaged entry throws; the store reads that as none.
  factory StoredChart.fromJson(Map<String, Object?> json) => StoredChart(
    visible: json['visible'] == true,
    settings: ChartSettings.fromJson(
      (json['settings'] as Map).cast<String, Object?>(),
    ),
  );

  final bool visible;
  final ChartSettings settings;

  Map<String, Object?> toJson() => {
    'visible': visible,
    'settings': settings.toJson(),
  };
}
