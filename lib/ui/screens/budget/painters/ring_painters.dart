import 'dart:math' as math;
import 'package:flutter/material.dart';

class RingPainter extends CustomPainter {
  RingPainter({
    required this.sweepRadians,
    required this.trackColor,
    required this.ringColor,
    required this.stroke,
    this.cap = StrokeCap.round,
  });

  final double sweepRadians;
  final Color trackColor;
  final Color ringColor;
  final double stroke;
  final StrokeCap cap;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeCap = cap
      ..strokeWidth = stroke;

    const start = -math.pi / 2;
    final sweep = math.min(sweepRadians, (2 * math.pi) - 1e-3);
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RingPainter old) {
    return old.sweepRadians != sweepRadians ||
        old.ringColor != ringColor ||
        old.trackColor != trackColor ||
        old.stroke != stroke ||
        old.cap != cap;
  }
}

class CategoryRingPainter extends CustomPainter {
  CategoryRingPainter({
    required this.colors,
    required this.progress,
    required this.splitT,
    required this.stroke,
    required this.trackColor,
    this.gapRadians = 0.02,
  });

  final List<Color> colors;
  final double progress;
  final double splitT;
  final double stroke;
  final Color trackColor;
  final double gapRadians;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (colors.isEmpty) return;

    final n = colors.length;
    final slot = (2 * math.pi) / n;
    final gap = gapRadians * splitT;
    final body = math.max(0.0, slot - gap);
    final start0 = -math.pi / 2;

    final total = (2 * math.pi - 1e-3) * progress;

    double drawn = 0.0;
    for (int i = 0; i < n; i++) {
      final segStart = start0 + i * slot + gap / 2;
      final startProg = i * slot;
      if (total <= startProg) break;

      final canSweep = math.min(body, total - startProg);
      if (canSweep <= 0) continue;

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = stroke;

      canvas.drawArc(rect, segStart, canSweep, false, paint);
      drawn += canSweep;
      if (drawn >= total) break;
    }
  }

  @override
  bool shouldRepaint(covariant CategoryRingPainter old) {
    if (progress != old.progress ||
        splitT != old.splitT ||
        stroke != old.stroke ||
        gapRadians != old.gapRadians ||
        trackColor != old.trackColor ||
        colors.length != old.colors.length) return true;

    for (int i = 0; i < colors.length; i++) {
      if (colors[i].value != old.colors[i].value) return true;
    }
    return false;
  }
}

class ProportionalRingPainter extends CustomPainter {
  ProportionalRingPainter({
    required this.values,
    required this.colors,
    required this.progress,
    required this.splitT,
    required this.stroke,
    required this.trackColor,
    this.gapRadians = 0.02,
  });

  final List<double> values;
  final List<Color> colors;
  final double progress;
  final double splitT;
  final double stroke;
  final Color trackColor;
  final double gapRadians;

  @override
  void paint(Canvas canvas, Size size) {
    final totalValue = values.fold<double>(0, (a, b) => a + b);
    final center = (Offset.zero & size).center;
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (totalValue <= 0) return;

    final start0 = -math.pi / 2;
    final totalRadians = (2 * math.pi - 1e-3) * progress;
    final gap = gapRadians * splitT;

    double angle = start0;
    double drawn = 0.0;

    for (int i = 0; i < values.length; i++) {
      final frac = values[i] / totalValue;
      final seg = (2 * math.pi) * frac - gap;
      if (seg <= 0) continue;

      final startForThis = angle + gap / 2;
      final remaining = totalRadians - drawn;
      if (remaining <= 0) break;

      final sweep = math.min(seg, remaining);
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = stroke;

      canvas.drawArc(rect, startForThis, sweep, false, paint);

      angle += (seg + gap);
      drawn += (sweep + gap);
    }
  }

  @override
  bool shouldRepaint(covariant ProportionalRingPainter old) {
    if (progress != old.progress ||
        splitT != old.splitT ||
        stroke != old.stroke ||
        gapRadians != old.gapRadians ||
        trackColor != old.trackColor ||
        values.length != old.values.length ||
        colors.length != old.colors.length) return true;

    for (int i = 0; i < values.length; i++) {
      if (values[i] != old.values[i] || colors[i] != old.colors[i]) {
        return true;
      }
    }
    return false;
  }
}
