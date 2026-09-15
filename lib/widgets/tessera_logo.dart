import 'package:flutter/widgets.dart';

/// The tessera icon drawn with the canvas (no image asset): the L-shaped
/// frame and the nine tiles of `icon/tessera-icon-foreground.svg` in the
/// tessera repository, without the background square.
///
/// Fills the largest square that fits the constraints. [opacity] applies
/// to every shape (they do not overlap, so no layer is needed).
class TesseraLogo extends StatelessWidget {
  const TesseraLogo({super.key, this.opacity = 1.0});

  final double opacity;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _LogoPainter(opacity), size: Size.infinite);
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.opacity);

  final double opacity;

  static const _frame = Color(0xFF00856E);
  static const _rowColors = [
    Color(0xFFADEEDB),
    Color(0xFFEED2FF),
    Color(0xFFF5DC98),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    canvas
      ..save()
      ..translate((size.width - side) / 2, (size.height - side) / 2)
      ..scale(side / 1024);

    final frame = Path()
      ..moveTo(188, 144)
      ..lineTo(836, 144)
      ..arcToPoint(const Offset(880, 188), radius: const Radius.circular(44))
      ..lineTo(880, 320)
      ..lineTo(336, 320)
      ..arcToPoint(
        const Offset(320, 336),
        radius: const Radius.circular(16),
        clockwise: false,
      )
      ..lineTo(320, 880)
      ..lineTo(188, 880)
      ..arcToPoint(const Offset(144, 836), radius: const Radius.circular(44))
      ..lineTo(144, 188)
      ..arcToPoint(const Offset(188, 144), radius: const Radius.circular(44))
      ..close();
    canvas.drawPath(frame, Paint()..color = _frame.withValues(alpha: opacity));

    for (var row = 0; row < 3; row++) {
      final paint = Paint()..color = _rowColors[row].withValues(alpha: opacity);
      for (var col = 0; col < 3; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(336.0 + 184 * col, 336.0 + 184 * row, 176, 176),
            const Radius.circular(10),
          ),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.opacity != opacity;
}
