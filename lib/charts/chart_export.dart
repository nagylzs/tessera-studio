import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:tessera_flutter/tessera_flutter.dart' show TesseraStrings;

import '../export/export_format.dart';
import 'chart_content.dart';
import 'chart_layout.dart';
import 'chart_scene.dart';
import 'chart_settings.dart';

/// The chart of [content] as [format], one of [ExportFormat.charts]; see
/// [chartScene] for the other arguments.
Future<Uint8List> chartExport(
  ExportFormat format,
  ChartContent content, {
  required String title,
  required List<String> caption,
  required String? problem,
  required String others,
  required ChartLook look,
  required TesseraStrings strings,
  required String locale,
}) async {
  final font = await rootBundle.load(_fontAsset);
  final metrics = PdfTtfFont(PdfDocument(), font);
  final scene = chartScene(
    content,
    title: title,
    caption: caption,
    problem: problem,
    others: others,
    look: look,
    strings: strings,
    locale: locale,
    measure: (text, size) => _width(metrics, text, size),
  );
  return switch (format) {
    ExportFormat.png => scenePng(scene, font),
    ExportFormat.svg => Uint8List.fromList(utf8.encode(sceneSvg(scene))),
    ExportFormat.pdf => scenePdf(scene, font),
    _ => throw ArgumentError.value(format, 'format', 'not a chart format'),
  };
}

const _fontAsset = 'assets/fonts/NotoSans-Regular.ttf';

/// Width of [text] at [size] in the bundled font; 1 em for what it does not
/// have, which is what the other fonts' CJK glyphs are wide.
double _width(PdfTtfFont font, String text, double size) {
  var em = 0.0;
  for (final rune in text.runes) {
    em += font.isRuneSupported(rune)
        ? font.glyphMetrics(rune).advanceWidth
        : 1.0;
  }
  return em * size;
}

// ---- PNG

const _family = 'Tessera Chart';
bool _familyLoaded = false;

/// [scene] drawn at [chartImageRatio]. Text is in the bundled font; the
/// engine finds other fonts for what that does not have.
Future<Uint8List> scenePng(ChartScene scene, ByteData font) async {
  if (!_familyLoaded) {
    await (FontLoader(_family)..addFont(Future.value(font))).load();
    _familyLoaded = true;
  }
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(chartImageRatio);
  if (scene.background case final background?) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, scene.width, scene.height),
      ui.Paint()..color = background,
    );
  }
  for (final shape in scene.shapes) {
    switch (shape) {
      case SceneRect(:final x, :final y, :final width, :final height):
        canvas.drawRect(
          ui.Rect.fromLTWH(x, y, width, height),
          ui.Paint()..color = shape.color,
        );
      case SceneLine(:final x1, :final y1, :final x2, :final y2):
        canvas.drawLine(
          ui.Offset(x1, y1),
          ui.Offset(x2, y2),
          ui.Paint()
            ..color = shape.color
            ..strokeWidth = shape.width,
        );
      case ScenePolyline(:final points):
        canvas.drawPath(
          ui.Path()..addPolygon(points, false),
          ui.Paint()
            ..color = shape.color
            ..strokeWidth = shape.width
            ..style = ui.PaintingStyle.stroke
            ..strokeJoin = ui.StrokeJoin.round
            ..strokeCap = ui.StrokeCap.round,
        );
      case SceneCircle(:final x, :final y, :final radius):
        canvas.drawCircle(
          ui.Offset(x, y),
          radius,
          ui.Paint()..color = shape.color,
        );
      case SceneSlice(:final x, :final y, :final radius):
        canvas.drawPath(
          ui.Path()
            ..moveTo(x, y)
            ..arcTo(
              ui.Rect.fromCircle(center: ui.Offset(x, y), radius: radius),
              shape.start,
              shape.sweep,
              false,
            )
            ..close(),
          ui.Paint()..color = shape.color,
        );
      case SceneText():
        final builder =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(fontFamily: _family, maxLines: 1),
              )
              ..pushStyle(
                ui.TextStyle(
                  color: shape.color,
                  fontFamily: _family,
                  fontSize: shape.size,
                ),
              )
              ..addText(shape.text);
        final paragraph = builder.build()
          ..layout(const ui.ParagraphConstraints(width: double.infinity));
        final width = paragraph.maxIntrinsicWidth;
        canvas.drawParagraph(
          paragraph,
          ui.Offset(switch (shape.anchor) {
            TextAnchor.start => shape.x,
            TextAnchor.middle => shape.x - width / 2,
            TextAnchor.end => shape.x - width,
          }, shape.y - paragraph.alphabeticBaseline),
        );
        paragraph.dispose();
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (scene.width * chartImageRatio).round(),
    (scene.height * chartImageRatio).round(),
  );
  picture.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

// ---- SVG

String _number(double v) {
  final text = v.toStringAsFixed(2);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

String _hex(ui.Color c) {
  String two(double channel) =>
      (channel * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}';
}

/// The colour's attribute, and its opacity where it has one.
String _fill(ui.Color c) =>
    'fill="${_hex(c)}"${c.a < 1 ? ' fill-opacity="${_number(c.a)}"' : ''}';

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// [scene] as an SVG document. Text stays text in the fonts of whatever shows
/// it, Noto Sans first, as it was measured with.
String sceneSvg(ChartScene scene) {
  final w = _number(scene.width), h = _number(scene.height);
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" '
      'viewBox="0 0 $w $h" '
      'font-family="\'Noto Sans\', \'Segoe UI\', \'Helvetica Neue\', Arial, sans-serif">',
    )
    ..writeln('<title>${_escape(scene.title)}</title>');
  if (scene.background case final background?) {
    out.writeln('<rect width="$w" height="$h" ${_fill(background)}/>');
  }
  for (final shape in scene.shapes) {
    out.writeln(switch (shape) {
      SceneRect(:final x, :final y, :final width, :final height) =>
        '<rect x="${_number(x)}" y="${_number(y)}" '
            'width="${_number(width)}" height="${_number(height)}" '
            '${_fill(shape.color)}/>',
      SceneLine(:final x1, :final y1, :final x2, :final y2) =>
        '<line x1="${_number(x1)}" y1="${_number(y1)}" '
            'x2="${_number(x2)}" y2="${_number(y2)}" '
            'stroke="${_hex(shape.color)}" '
            'stroke-width="${_number(shape.width)}"/>',
      ScenePolyline(:final points) =>
        '<polyline points="${points.map((p) => '${_number(p.dx)},${_number(p.dy)}').join(' ')}" '
            'fill="none" stroke="${_hex(shape.color)}" '
            'stroke-width="${_number(shape.width)}" '
            'stroke-linejoin="round" stroke-linecap="round"/>',
      SceneCircle(:final x, :final y, :final radius) =>
        '<circle cx="${_number(x)}" cy="${_number(y)}" '
            'r="${_number(radius)}" ${_fill(shape.color)}/>',
      SceneSlice(:final x, :final y, :final radius) => () {
        final end = shape.start + shape.sweep;
        final large = shape.sweep > math.pi ? 1 : 0;
        return '<path d="M${_number(x)} ${_number(y)} '
            'L${_number(x + math.cos(shape.start) * radius)} '
            '${_number(y + math.sin(shape.start) * radius)} '
            'A${_number(radius)} ${_number(radius)} 0 $large 1 '
            '${_number(x + math.cos(end) * radius)} '
            '${_number(y + math.sin(end) * radius)} Z" '
            '${_fill(shape.color)}/>';
      }(),
      SceneText() =>
        '<text x="${_number(shape.x)}" y="${_number(shape.y)}" '
            'font-size="${_number(shape.size)}" ${_fill(shape.color)}'
            '${switch (shape.anchor) {
              TextAnchor.start => '',
              TextAnchor.middle => ' text-anchor="middle"',
              TextAnchor.end => ' text-anchor="end"',
            }}>${_escape(shape.text)}</text>',
    });
  }
  out.writeln('</svg>');
  return out.toString();
}

// ---- PDF

/// Points per logical pixel: the page fits A4 in landscape as it is.
const _pdfScale = 0.75;

PdfColor _pdfColor(ui.Color c) => PdfColor(c.r, c.g, c.b);

/// [scene] as a one-page PDF. Text is in the bundled font, embedded. What that
/// does not have comes out as a question mark: no Japanese or Chinese, as in
/// the pivot's PDF (TODO.md).
Future<Uint8List> scenePdf(ChartScene scene, ByteData font) async {
  final document = PdfDocument();
  PdfInfo(document, title: scene.title, creator: 'Tessera Studio');
  final embedded = PdfTtfFont(document, font);
  final page = PdfPage(
    document,
    pageFormat: PdfPageFormat(
      scene.width * _pdfScale,
      scene.height * _pdfScale,
    ),
  );
  final g = page.getGraphics();
  double px(double x) => x * _pdfScale;
  // PDF's y runs upwards
  double py(double y) => (scene.height - y) * _pdfScale;
  void translucent(ui.Color color, void Function() draw) {
    g.saveContext();
    if (color.a < 1) {
      g.setGraphicState(
        PdfGraphicState(fillOpacity: color.a, strokeOpacity: color.a),
      );
    }
    g.setFillColor(_pdfColor(color));
    draw();
    g.restoreContext();
  }

  if (scene.background case final background?) {
    g.setFillColor(_pdfColor(background));
    g.drawRect(0, 0, px(scene.width), px(scene.height));
    g.fillPath();
  }
  for (final shape in scene.shapes) {
    switch (shape) {
      case SceneRect(:final x, :final y, :final width, :final height):
        translucent(shape.color, () {
          g.drawRect(px(x), py(y + height), px(width), px(height));
          g.fillPath();
        });
      case SceneLine(:final x1, :final y1, :final x2, :final y2):
        g
          ..setStrokeColor(_pdfColor(shape.color))
          ..setLineWidth(px(shape.width))
          ..drawLine(px(x1), py(y1), px(x2), py(y2))
          ..strokePath();
      case ScenePolyline(:final points):
        g
          ..setStrokeColor(_pdfColor(shape.color))
          ..setLineWidth(px(shape.width))
          ..setLineJoin(PdfLineJoin.round)
          ..setLineCap(PdfLineCap.round)
          ..moveTo(px(points.first.dx), py(points.first.dy));
        for (final p in points.skip(1)) {
          g.lineTo(px(p.dx), py(p.dy));
        }
        g.strokePath();
      case SceneCircle(:final x, :final y, :final radius):
        translucent(shape.color, () {
          g.drawEllipse(px(x), py(y), px(radius), px(radius));
          g.fillPath();
        });
      case SceneSlice(:final x, :final y, :final radius):
        translucent(shape.color, () {
          final end = shape.start + shape.sweep;
          final x1 = px(x + math.cos(shape.start) * radius);
          final y1 = py(y + math.sin(shape.start) * radius);
          g
            ..moveTo(px(x), py(y))
            ..lineTo(x1, y1)
            ..bezierArc(
              x1,
              y1,
              px(radius),
              px(radius),
              px(x + math.cos(end) * radius),
              py(y + math.sin(end) * radius),
              large: shape.sweep > math.pi,
              // clockwise on the page: y runs upwards here
              sweep: false,
            )
            ..closePath()
            ..fillPath();
        });
      case SceneText():
        final text = String.fromCharCodes(
          shape.text.runes.map((r) => embedded.isRuneSupported(r) ? r : 0x3f),
        );
        final width = _width(embedded, text, shape.size);
        translucent(shape.color, () {
          g.drawString(
            embedded,
            px(shape.size),
            text,
            px(switch (shape.anchor) {
              TextAnchor.start => shape.x,
              TextAnchor.middle => shape.x - width / 2,
              TextAnchor.end => shape.x - width,
            }),
            py(shape.y),
          );
        });
    }
  }
  return document.save();
}
