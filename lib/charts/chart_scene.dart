import 'dart:ui' show Color, Offset, Size;

/// The size of an exported chart in logical pixels, whatever the window: a
/// chart made on a phone reads as well in a document as one made on a desktop.
const chartImageSize = Size(1000, 640);

/// The pixels per logical pixel of an exported PNG.
const chartImageRatio = 2.0;

/// Where a text's x stands in it.
enum TextAnchor { start, middle, end }

/// What an exported chart is made of, in logical pixels from the top left.
sealed class SceneShape {
  const SceneShape();
}

final class SceneRect extends SceneShape {
  const SceneRect(this.x, this.y, this.width, this.height, this.color);

  final double x, y, width, height;
  final Color color;
}

final class SceneLine extends SceneShape {
  const SceneLine(this.x1, this.y1, this.x2, this.y2, this.color, this.width);

  final double x1, y1, x2, y2;
  final Color color;
  final double width;
}

final class ScenePolyline extends SceneShape {
  const ScenePolyline(this.points, this.color, this.width);

  final List<Offset> points;
  final Color color;
  final double width;
}

final class SceneCircle extends SceneShape {
  const SceneCircle(this.x, this.y, this.radius, this.color);

  final double x, y, radius;
  final Color color;
}

/// A slice of a pie: angles in radians, clockwise from three o'clock.
final class SceneSlice extends SceneShape {
  const SceneSlice(
    this.x,
    this.y,
    this.radius,
    this.start,
    this.sweep,
    this.color,
  );

  final double x, y, radius, start, sweep;
  final Color color;
}

/// A line of text; [y] is its baseline.
final class SceneText extends SceneShape {
  const SceneText(
    this.text,
    this.x,
    this.y,
    this.size,
    this.color, {
    this.anchor = TextAnchor.start,
  });

  final String text;
  final double x, y, size;
  final Color color;
  final TextAnchor anchor;
}

/// A chart laid out on a page, ready for any of the formats: no format has a
/// layout of its own, so all of them look the same. Nothing behind it when
/// [background] is null.
final class ChartScene {
  const ChartScene({
    required this.title,
    required this.width,
    required this.height,
    required this.background,
    required this.shapes,
  });

  final String title;
  final double width, height;
  final Color? background;
  final List<SceneShape> shapes;
}
