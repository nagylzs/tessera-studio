import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// Two panes along [axis] with a divider to drag between them. While
/// dragging only this widget rebuilds; [onChanged] gets the result at the
/// end. A double tap on the divider goes back to half and half.
class SplitView extends StatefulWidget {
  const SplitView({
    super.key,
    required this.axis,
    required this.first,
    required this.second,
    required this.fraction,
    required this.onChanged,
    this.minExtent = 200,
  });

  final Axis axis;
  final Widget first;
  final Widget second;

  /// The first pane's share of the room, 0 to 1.
  final double fraction;
  final ValueChanged<double> onChanged;

  /// Neither pane gets smaller than this, room permitting.
  final double minExtent;

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  /// Set while dragging.
  double? _dragging;

  /// Room for a finger; the line itself is one pixel.
  static const _handle = 16.0;

  double _clamped(double fraction, double room) {
    if (room <= 0) return 0.5;
    final min = (widget.minExtent / room).clamp(0.0, 0.5);
    return fraction.clamp(min, 1 - min);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = widget.axis == Axis.horizontal;
      final total = horizontal ? constraints.maxWidth : constraints.maxHeight;
      final room = total - _handle;
      final fraction = _clamped(_dragging ?? widget.fraction, room);
      final firstExtent = room * fraction;
      void update(double delta) => setState(
        () => _dragging = _clamped((firstExtent + delta) / room, room),
      );
      void end() {
        if (_dragging case final value?) widget.onChanged(value);
        setState(() => _dragging = null);
      }

      final line = DecoratedBox(
        decoration: BoxDecoration(
          color: _dragging == null
              ? Theme.of(context).colorScheme.outlineVariant
              : Theme.of(context).colorScheme.primary,
        ),
        child: SizedBox(
          width: horizontal ? 1 : double.infinity,
          height: horizontal ? double.infinity : 1,
        ),
      );
      final handle = MouseRegion(
        cursor: horizontal
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          supportedDevices: PointerDeviceKind.values.toSet(),
          onHorizontalDragUpdate: horizontal ? (d) => update(d.delta.dx) : null,
          onHorizontalDragEnd: horizontal ? (_) => end() : null,
          onVerticalDragUpdate: horizontal ? null : (d) => update(d.delta.dy),
          onVerticalDragEnd: horizontal ? null : (_) => end(),
          onDoubleTap: () => widget.onChanged(0.5),
          child: SizedBox(
            width: horizontal ? _handle : null,
            height: horizontal ? null : _handle,
            child: Center(child: line),
          ),
        ),
      );
      final children = <Widget>[
        SizedBox(
          width: horizontal ? firstExtent : null,
          height: horizontal ? null : firstExtent,
          child: widget.first,
        ),
        handle,
        Expanded(child: widget.second),
      ];
      return horizontal
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            );
    },
  );
}
