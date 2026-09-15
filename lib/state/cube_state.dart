import 'package:flutter/foundation.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../files/opened_document.dart';

/// The cube of the open document: the import (off the UI isolate, with
/// progress), the resulting facts and report, and the [CubeController]
/// the widgets drive. Owned by `AppState`; cleared with the document.
final class CubeState {
  /// Rows between two progress reports.
  static const progressEvery = 5000;

  /// Set while an import runs; `null` otherwise (also before the first
  /// row count is known: the UI then shows an indeterminate bar).
  final importing = signal(false);
  final progress = signal<ImportProgress?>(null);

  final result = signal<ImportResult?>(null);
  final error = signal<Object?>(null);

  /// Non-null once there is a cube to show.
  final controller = signal<CubeController?>(null);

  /// The dimensions offered by the axis editors.
  final dimensions = signal<List<Dimension>>(const []);

  /// The aggregates the view shows; `null` = all of the spec's.
  final shown = signal<List<Aggregate>?>(null);

  /// The schema the current facts were imported with (`null` for a
  /// snapshot).
  Schema? _schema;

  /// Builds the cube for [doc] under [schema]: a snapshot decodes at
  /// once, anything else is imported in an isolate.
  Future<void> start(OpenedDocument doc, Schema schema) async {
    final snapshot = doc.snapshot;
    if (snapshot != null) {
      _schema = null;
      result.value = ImportResult(
        facts: snapshot.facts,
        report: const ImportReport(
          rowsRead: 0,
          rowsImported: 0,
          nullifiedPerColumn: {},
          widenedColumns: {},
          issues: [],
          issuesTruncated: false,
        ),
      );
      _install(
        snapshot.facts,
        spec: snapshot.config?.spec,
        rowExpansion: snapshot.config?.rowExpansion,
        columnExpansion: snapshot.config?.columnExpansion,
      );
      return;
    }
    await _import(doc, schema);
  }

  /// A schema edited on the cube page: label-only changes relabel the
  /// facts in place; anything else re-imports, keeping the spec where
  /// the new facts allow.
  Future<void> applySchema(OpenedDocument doc, Schema edited) async {
    final current = _schema;
    final ctrl = controller.value;
    if (current == null || ctrl == null || !sameExceptLabels(current, edited)) {
      return _import(doc, edited);
    }
    final changed = <String, String?>{
      for (final c in edited.columns)
        if (c.label != current[c.name]?.label) c.name: c.label,
    };
    _schema = edited;
    if (changed.isEmpty) return;
    final old = ctrl.cube;
    ctrl.cube = Cube(
      facts: old.facts.withLabels(changed),
      spec: old.spec,
      rowExpansion: old.rowExpansion,
      columnExpansion: old.columnExpansion,
    );
  }

  Future<void> _import(OpenedDocument doc, Schema schema) async {
    importing.value = true;
    progress.value = null;
    error.value = null;
    final ImportResult imported;
    try {
      imported = await loadFactsInIsolate(
        doc.dataSource!,
        schema: schema,
        importer: const FactTableImporter(progressEvery: progressEvery),
        onProgress: (p) {
          progress.value = p;
          return true;
        },
      );
    } catch (e) {
      error.value = e;
      return;
    } finally {
      importing.value = false;
      progress.value = null;
    }
    _schema = schema;
    result.value = imported;
    final old = controller.value?.cube;
    _install(
      imported.facts,
      spec: old == null ? null : prune(old.spec, imported.facts),
      rowExpansion: old?.rowExpansion,
      columnExpansion: old?.columnExpansion,
    );
  }

  void _install(
    FactTable facts, {
    CubeSpec? spec,
    ExpansionState? rowExpansion,
    ExpansionState? columnExpansion,
  }) {
    final dims = standardDimensions(facts);
    final resolved = spec ?? defaultSpec(facts);
    final kept = [
      for (final a in shown.value ?? const <Aggregate>[])
        if (resolved.aggregates.contains(a)) a,
    ];
    shown.value = shown.value == null || kept.isEmpty ? null : kept;
    controller.value?.dispose();
    dimensions.value = dims;
    controller.value = CubeController(
      Cube(
        facts: facts,
        spec: resolved,
        rowExpansion: rowExpansion,
        columnExpansion: columnExpansion,
      ),
    );
  }

  void clear() {
    controller.value?.dispose();
    controller.value = null;
    result.value = null;
    error.value = null;
    progress.value = null;
    importing.value = false;
    dimensions.value = const [];
    shown.value = null;
    _schema = null;
  }

  /// A readable first cube: one low-cardinality text column on the rows
  /// and a count.
  static CubeSpec defaultSpec(FactTable facts) {
    final text = facts.columns.where((c) => c.type == ColumnType.text).toList();
    final byDistinct = [...text]
      ..sort((a, b) => a.distinctCount - b.distinctCount);
    final first =
        byDistinct.where((c) => c.distinctCount > 1).firstOrNull ??
        text.firstOrNull;
    return CubeSpec(
      rows: first == null
          ? const CubeAxis()
          : CubeAxis.of([ColumnDimension(first.name)]),
      aggregates: const [Aggregate.count],
    );
  }

  /// Drops dimensions and aggregates whose columns are gone or changed
  /// type (after a re-import under an edited schema).
  static CubeSpec prune(CubeSpec spec, FactTable facts) {
    bool hasColumn(String name) => facts.columns.any((c) => c.name == name);
    bool dimensionOk(Dimension d) {
      if (!d.sourceColumns.every(hasColumn)) return false;
      if (d is DatePartDimension) {
        final t = facts.column(d.sourceColumn).type;
        return t == ColumnType.date || t == ColumnType.dateTime;
      }
      if (d is ExpressionDimension) {
        return Expression.validate(
              d.source,
              scope: ExpressionScope.ofFacts(facts, functions: d.functions),
            ) ==
            null;
      }
      return true;
    }

    bool measureOk(Measure m) => switch (m) {
      ColumnMeasure(:final column) =>
        hasColumn(column) && facts.column(column).type.isNumeric,
      ExpressionMeasure(:final source, :final functions) =>
        Expression.validate(
              source,
              scope: ExpressionScope.ofFacts(facts, functions: functions),
              expected: ExprType.number,
            ) ==
            null,
    };

    bool aggregateOk(Aggregate a) => switch (a) {
      MeasureAggregate(:final measure) => measureOk(measure),
      DistinctCountAggregate(:final dimension) => dimensionOk(dimension),
      ExpressionAggregate(:final source, :final functions) =>
        Expression.validate(
              source,
              scope: ExpressionScope.cellsOf(facts, functions: functions),
              expected: ExprType.number,
            ) ==
            null,
      _ => true,
    };
    CubeAxis pruneAxis(CubeAxis axis) => axis.copyWith(
      dimensions: [
        for (final d in axis.dimensions)
          if (dimensionOk(d.dimension) &&
              (d.sort?.aggregate == null || aggregateOk(d.sort!.aggregate!)))
            d
          else if (dimensionOk(d.dimension))
            AxisDimension(d.dimension),
      ],
    );
    final aggregates = [
      for (final a in spec.aggregates)
        if (aggregateOk(a)) a,
    ];
    return CubeSpec(
      rows: pruneAxis(spec.rows),
      columns: pruneAxis(spec.columns),
      aggregates: aggregates.isEmpty ? const [Aggregate.count] : aggregates,
      filter: spec.filter,
    );
  }

  /// Whether [a] and [b] describe the same import apart from labels.
  static bool sameExceptLabels(Schema a, Schema b) {
    if (a.columns.length != b.columns.length) return false;
    for (var i = 0; i < a.columns.length; i++) {
      final x = a.columns[i], y = b.columns[i];
      if (x.name != y.name ||
          x.type != y.type ||
          x.include != y.include ||
          x.format != y.format ||
          x.numberSyntax != y.numberSyntax ||
          x.parser != y.parser ||
          !setEquals(x.nullValues, y.nullValues)) {
        return false;
      }
    }
    return true;
  }
}
