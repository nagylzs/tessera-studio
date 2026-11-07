import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:tessera_flutter/tessera_flutter.dart';

import '../app.dart' show tesseraGreen;
import 'chart_content.dart';
import 'chart_drawing.dart';
import 'chart_panel.dart';
import 'chart_settings.dart';

/// The size of an exported chart, whatever the window: a chart made on a
/// phone reads as well in a document as one made on a desktop.
const chartImageSize = Size(1000, 640);

/// The pixels per logical pixel of an exported chart.
const chartImageRatio = 2.0;

/// [content] as a PNG, headed by [title] and with its caption. Drawn off
/// screen in the [look] asked for, whatever the app's theme. Needs a frame
/// to draw in.
Future<Uint8List> chartPng(
  BuildContext context, {
  required ChartContent content,
  required Cube cube,
  required String title,
  ChartLook look = plainChartLook,
}) async {
  final boundary = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      // beyond the window's left edge, and painted all the same
      left: -chartImageSize.width - 100,
      top: 0,
      width: chartImageSize.width,
      height: chartImageSize.height,
      child: RepaintBoundary(
        key: boundary,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.noScaling),
          child: Theme(
            data: ThemeData(
              colorSchemeSeed: tesseraGreen,
              brightness: look.dark ? Brightness.dark : Brightness.light,
            ),
            child: _ChartPage(
              content: content,
              cube: cube,
              title: title,
              look: look,
            ),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: chartImageRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}

class _ChartPage extends StatelessWidget {
  const _ChartPage({
    required this.content,
    required this.cube,
    required this.title,
    required this.look,
  });

  final ChartContent content;
  final Cube cube;
  final String title;
  final ChartLook look;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: look.transparent ? MaterialType.transparency : MaterialType.canvas,
      color: switch (look) {
        (transparent: true, dark: _) => null,
        (transparent: false, dark: true) => theme.colorScheme.surface,
        (transparent: false, dark: false) => Colors.white,
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(child: ChartFigure(content: content)),
            const SizedBox(height: 8),
            Text(
              chartCaption(context, content, cube).join('\n'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
