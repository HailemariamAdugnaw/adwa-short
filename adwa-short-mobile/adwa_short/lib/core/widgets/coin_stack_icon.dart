import 'package:flutter/material.dart';

/// Clean, scalable isometric stacked-coin icon matching the reference design.
///
/// Features 3 stacked cylindrical coin disks with smooth rounded outline stroke.
class CoinStackIcon extends StatelessWidget {
  const CoinStackIcon({
    super.key,
    this.size = 20,
    this.color = Colors.white,
    this.strokeWidth,
  });

  final double size;
  final Color color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CoinStackPainter(
          color: color,
          strokeWidth: strokeWidth ?? (size * 0.08).clamp(1.2, 2.2),
        ),
      ),
    );
  }
}

class _CoinStackPainter extends CustomPainter {
  const _CoinStackPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Radius of the horizontal ellipse for each coin
    final rx = w * 0.42;
    final ry = h * 0.16;

    // Vertical spacing between coins
    final stepY = h * 0.22;
    final y1 = h * 0.26; // Center of top coin
    final y2 = y1 + stepY; // Center of middle coin
    final y3 = y2 + stepY; // Center of bottom coin

    // 1. Top coin (complete ellipse)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y1), width: rx * 2, height: ry * 2),
      paint,
    );

    // 2. Middle coin (right line down, bottom arc, left line up)
    final path2 = Path()
      ..moveTo(cx + rx, y1)
      ..lineTo(cx + rx, y2)
      ..arcTo(
        Rect.fromCenter(center: Offset(cx, y2), width: rx * 2, height: ry * 2),
        0,
        3.141592653589793,
        false,
      )
      ..lineTo(cx - rx, y1);
    canvas.drawPath(path2, paint);

    // 3. Bottom coin (right line down, bottom arc, left line up)
    final path3 = Path()
      ..moveTo(cx + rx, y2)
      ..lineTo(cx + rx, y3)
      ..arcTo(
        Rect.fromCenter(center: Offset(cx, y3), width: rx * 2, height: ry * 2),
        0,
        3.141592653589793,
        false,
      )
      ..lineTo(cx - rx, y2);
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant _CoinStackPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
