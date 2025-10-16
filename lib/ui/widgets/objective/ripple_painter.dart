// lib/ui/widgets/objective/ripple_painter.dart
import 'package:flutter/material.dart';

class RipplePainter extends CustomPainter {
  final double progress; // 0..1
  final double rrectRadius;
  final Color color;
  const RipplePainter({
    required this.progress,
    required this.rrectRadius,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(rrectRadius),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    final center = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide * 0.45;
    final r = base * (0.7 + 0.9 * progress);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (1.4 * (1 - progress))
      ..color = color.withValues(alpha: 0.25 * (1 - progress));

    canvas.drawCircle(center, r, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RipplePainter old) =>
      old.progress != progress ||
      old.rrectRadius != rrectRadius ||
      old.color != color;
}
