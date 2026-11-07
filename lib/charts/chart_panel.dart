import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/chart_state.dart';
import '../widgets/editors_panel.dart';
import 'chart_content.dart';
import 'chart_drawing.dart';
import 'chart_settings.dart';

/// What a figure shows in words, under it: the value, the cell, the filter
/// and what was left out, for readers of an exported image too.
List<String> chartCaption(
  BuildContext context,
  ChartContent content,
  Cube cube,
) {
  final l10n = AppLocalizations.of(context);
  final t = TesseraLocalizations.of(context);
  final facts = content.facts;
  if (content.problem != null) return const [];
  final isCell = content.source == ChartSource.cell;
  final filter = cube.spec.filter;
  final data = content.data;
  final coordinate = content.cell?.coordinate;
  final hasCell = coordinate != null && !coordinate.isEmpty;
  final left = content.kind == ChartKind.pie && data != null
      ? pieSlices(data).left
      : 0;
  return [
    [
      if (content.scatter == null) t.aggregateLabel(content.value, facts),
      // a pie is one series; where the pivot hides its totals, not the total
      if (content.kind == ChartKind.pie && !data!.series.first.path.isRoot)
        data.series.first.label,
      if (hasCell) describeCoordinate(t, facts, coordinate),
      if (isCell && content.category != null)
        '${l10n.chartBreakDownBy}: ${t.dimensionLabel(content.category!, facts)}',
      if (filter != null) describeFilter(t, filter),
    ].join(' — '),
    if (isCell && !hasCell) l10n.chartNoCell,
    if (content.kind != ChartKind.pie &&
        content.categoriesShown < content.categoriesTotal)
      l10n.chartFirstGroups(content.categoriesShown, content.categoriesTotal),
    if (content.kind != ChartKind.pie &&
        content.seriesShown < content.seriesTotal)
      l10n.chartFirstSeries(content.seriesShown, content.seriesTotal),
    if (left > 0) l10n.chartPieLeftOut(left),
  ].where((line) => line.isNotEmpty).toList();
}

/// A live chart of the cube in [controller]: the controls that apply to the
/// chosen type and data, the figure, and a caption saying what is drawn. It
/// follows the grid: every change of the pivot redraws it at once, and a
/// chart of the current cell follows the selection shortly after it stops.
class ChartPanel extends StatefulWidget {
  const ChartPanel({
    super.key,
    required this.controller,
    required this.dimensions,
    required this.state,
    this.shown,
    this.onFullScreen,
    this.fullScreen = false,
  });

  final CubeController controller;

  /// The dimensions a cell can be broken down by.
  final List<Dimension> dimensions;
  final ChartState state;

  /// The aggregates the grid shows; the chart starts from the first.
  final List<Aggregate>? shown;

  /// Set where a button should offer the whole screen, or leave it when
  /// [fullScreen]: phones.
  final VoidCallback? onFullScreen;

  /// The figure alone, no controls.
  final bool fullScreen;

  @override
  State<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends State<ChartPanel> {
  /// How long the selection must rest before a cell's chart is redrawn:
  /// its breakdown builds a cube, and arrow keys repeat fast.
  static const _settle = Duration(milliseconds: 150);

  Timer? _settling;

  /// The cube and selection the shown chart is for.
  Cube? _cube;
  CellAddress? _selection;

  /// The chart in force, and what it was computed from.
  ChartContent? _content;
  Object? _contentKey;

  @override
  void initState() {
    super.initState();
    _cube = widget.controller.cube;
    _selection = widget.controller.selection;
    widget.controller.addListener(_controllerChanged);
  }

  @override
  void didUpdateWidget(ChartPanel old) {
    super.didUpdateWidget(old);
    if (identical(old.controller, widget.controller)) return;
    old.controller.removeListener(_controllerChanged);
    widget.controller.addListener(_controllerChanged);
    _cube = widget.controller.cube;
    _selection = widget.controller.selection;
  }

  @override
  void dispose() {
    _settling?.cancel();
    widget.controller.removeListener(_controllerChanged);
    super.dispose();
  }

  void _controllerChanged() {
    final ctrl = widget.controller;
    if (!identical(ctrl.cube, _cube)) {
      _settling?.cancel();
      setState(() {
        _cube = ctrl.cube;
        _selection = ctrl.selection;
      });
      return;
    }
    if (ctrl.selection == _selection) return;
    if (widget.state.settings.value.source != ChartSource.cell) {
      _selection = ctrl.selection;
      return;
    }
    _settling?.cancel();
    _settling = Timer(_settle, () {
      if (mounted) setState(() => _selection = widget.controller.selection);
    });
  }

  /// The chart for the current state; the same object while nothing it
  /// depends on has changed, as a selection or a rebuild of the page.
  ChartContent _contentFor(BuildContext context, ChartSettings settings) {
    final strings = TesseraLocalizations.of(context);
    final isCell = settings.source == ChartSource.cell;
    final key = (
      _cube,
      settings,
      isCell ? _selection : null,
      strings,
      widget.shown,
      widget.dimensions,
    );
    if (_content != null && key == _contentKey) return _content!;
    _contentKey = key;
    return _content = chartContent(
      cube: widget.controller.cube,
      settings: settings,
      dimensions: widget.dimensions,
      strings: strings,
      shown: widget.shown,
      cell: isCell ? widget.controller.currentCell : null,
    );
  }

  void _update(ChartSettings settings) => widget.state.update(settings);

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final settings = widget.state.settings.value;
      final content = _contentFor(context, settings);
      final caption = chartCaption(context, content, widget.controller.cube);
      final figure = Semantics(
        container: true,
        label: caption.join('. '),
        child: ChartFigure(content: content),
      );
      if (widget.fullScreen) {
        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 48, 8),
                child: figure,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit),
                tooltip: AppLocalizations.of(context).chartExitFullScreen,
                onPressed: widget.onFullScreen,
              ),
            ),
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final controls = _controls(context, settings, content);
            final scale = chartTextScale(context);
            // large text, or editors above a short window, can leave less
            // than a chart needs: the pane scrolls then, nothing is cut
            final needed =
                40 * scale +
                8 +
                chartMinHeight(context) +
                (caption.isEmpty ? 0 : 4 + 32 * scale);
            final low = constraints.maxHeight < math.max(420, needed);
            final column = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // low panes keep their height for the chart
                if (low)
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(spacing: 8, children: controls),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: controls,
                  ),
                const SizedBox(height: 8),
                Expanded(child: figure),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      caption.join('\n'),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: low ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            );
            return constraints.maxHeight >= needed
                ? column
                : SingleChildScrollView(
                    child: SizedBox(height: needed, child: column),
                  );
          },
        ),
      );
    },
  );

  List<Widget> _controls(
    BuildContext context,
    ChartSettings settings,
    ChartContent content,
  ) {
    final l10n = AppLocalizations.of(context);
    final t = TesseraLocalizations.of(context);
    final facts = content.facts;
    final aggregates = widget.controller.cube.spec.aggregates;
    final isCell = settings.source == ChartSource.cell;
    final isScatter = settings.kind == ChartKind.scatter;
    String aggregate(Aggregate a) => t.aggregateLabel(a, facts);
    String dimension(Dimension d) => t.dimensionLabel(d, facts);
    final pinned = content.cell?.coordinate;
    final usable = [
      for (final d in content.dimensions)
        if (pinned == null || !pinned.constrains(d)) d,
    ];
    return [
      SegmentedButton<ChartKind>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        segments: [
          for (final kind in ChartKind.values)
            ButtonSegment(
              value: kind,
              icon: Icon(_kindIcon(kind)),
              tooltip: _kindLabel(l10n, kind),
            ),
        ],
        selected: {settings.kind},
        onSelectionChanged: (kinds) =>
            _update(settings.copyWith(kind: kinds.first)),
      ),
      _Picker<ChartSource>(
        tooltip: l10n.chartSourceTooltip,
        value: settings.source,
        items: ChartSource.values,
        itemLabel: (s) => switch (s) {
          ChartSource.pivot => l10n.chartSourcePivot,
          ChartSource.cell => l10n.chartSourceCell,
        },
        onSelected: (s) => _update(settings.copyWith(source: s)),
      ),
      if (!isScatter)
        _Picker<Aggregate>(
          label: l10n.chartValue,
          value: content.value,
          items: aggregates,
          itemLabel: aggregate,
          onSelected: (a) => _update(settings.copyWith(value: a)),
        )
      else if (aggregates.length > 1) ...[
        _Picker<Aggregate>(
          label: l10n.chartAxisX,
          value: content.x,
          items: aggregates,
          itemLabel: aggregate,
          onSelected: (a) => _update(settings.copyWith(x: a)),
        ),
        _Picker<Aggregate>(
          label: l10n.chartAxisY,
          value: content.y,
          items: aggregates,
          itemLabel: aggregate,
          enabled: (a) => a != content.x,
          onSelected: (a) => _update(settings.copyWith(y: a)),
        ),
      ],
      if (isCell) ...[
        if (content.category case final category?)
          _Picker<Dimension>(
            label: l10n.chartBreakDownBy,
            value: category,
            items: usable,
            itemLabel: dimension,
            onSelected: (d) => _update(settings.copyWith(category: d)),
          ),
        if (settings.kind != ChartKind.pie && content.category != null)
          _Picker<Dimension?>(
            label: l10n.chartSeries,
            value: content.series,
            items: [null, ...usable],
            itemLabel: (d) => d == null ? l10n.chartNoSeries : dimension(d),
            enabled: (d) => d == null || d != content.category,
            onSelected: (d) => _update(settings.copyWith(series: () => d)),
          ),
      ] else
        IconButton(
          icon: const Icon(Icons.swap_horiz),
          tooltip: l10n.chartSwapAxes,
          isSelected: settings.transpose,
          onPressed: () =>
              _update(settings.copyWith(transpose: !settings.transpose)),
        ),
      if (widget.onFullScreen != null)
        IconButton(
          icon: const Icon(Icons.fullscreen),
          tooltip: l10n.chartFullScreen,
          onPressed: widget.onFullScreen,
        ),
    ];
  }
}

IconData _kindIcon(ChartKind kind) => switch (kind) {
  ChartKind.bar => Icons.bar_chart,
  ChartKind.stacked => Icons.stacked_bar_chart,
  ChartKind.line => Icons.show_chart,
  ChartKind.pie => Icons.pie_chart_outline,
  ChartKind.scatter => Icons.scatter_plot_outlined,
};

String _kindLabel(AppLocalizations l10n, ChartKind kind) => switch (kind) {
  ChartKind.bar => l10n.chartKindBar,
  ChartKind.stacked => l10n.chartKindStacked,
  ChartKind.line => l10n.chartKindLine,
  ChartKind.pie => l10n.chartKindPie,
  ChartKind.scatter => l10n.chartKindScatter,
};

/// "Label: value ▾", opening a menu of [items]. A popup route: back closes
/// it, and it works with thumbs and mice alike.
class _Picker<T> extends StatelessWidget {
  const _Picker({
    super.key,
    this.label,
    this.tooltip,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    this.enabled,
  });

  final String? label;
  final String? tooltip;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onSelected;
  final bool Function(T)? enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = itemLabel(value);
    // by position: a chosen `null` would read as a cancelled menu
    return PopupMenuButton<int>(
      tooltip: tooltip ?? label,
      initialValue: items.indexOf(value),
      onSelected: (i) => onSelected(items[i]),
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            enabled: enabled?.call(items[i]) ?? true,
            child: Text(itemLabel(items[i])),
          ),
      ],
      child: Container(
        // a minimum: the button grows with the user's text size
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label == null ? text : '$label: $text',
                  style: Theme.of(context).textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
