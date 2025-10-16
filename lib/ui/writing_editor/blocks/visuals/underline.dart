// lib/ui/writing_editor/blocks/visuals/underline.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/editor_layout.dart';
import 'entendre_visuals.dart';

/// Single source of truth for the underline look & geometry under pills.
/// Paint-only: no layout, no state.
class Underline {
  /// Base color of the underline.
  final Color color;

  /// Vertical nudge in pixels (+ moves underline lower). Tuned to visually
  /// “hug” the pill while clearing the grid line.
  final double dy;

  /// Corner radius of the underline to match pill rounding.
  final double radius;

  /// Opacity [0..1].
  final double opacity;

  const Underline({
    this.color = const Color(0xFF3C2286),
    this.dy = 1.6,
    this.radius = EntendreVisuals.headCornerRadius,
    this.opacity = 1.0,
  });

  /// Paint a rounded underline directly beneath the provided [pillRect].
  ///
  /// Typically:
  ///  - heads call this with `Offset.zero & size` inside a CustomPainter
  ///    wrapped around the pill widget;
  ///  - tails call this with their computed `shapeRect`.
  ///
  /// If [clipSize] is provided, we skip painting when the shifted rect would
  /// fall entirely outside the clip to avoid overdraw.
  void paintPill(Canvas canvas, Rect pillRect, {Size? clipSize}) {
    if (pillRect.isEmpty) return;

    final Rect r = pillRect.shift(Offset(0, dy));
    if (clipSize != null && !r.overlaps(Offset.zero & clipSize)) return;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      paint,
    );
  }

  /// Helper that returns the **pill height** and **content top** for a single
  /// line, mirroring the math used by the head/tail pills so the underline
  /// sits perfectly aligned.
  ///
  /// - [lineStride] is the baseline→baseline distance (`preferredLineHeight`).
  /// - [lineTop] should be the fragment’s top (local to the Editable area).
  /// - [insetTop]/[insetBottom]/[heightFactor]/[yNudge] mirror Entendre visuals.
  ({double pillH, double contentTop}) geometryForLine({
    required double lineStride,
    required double lineTop,
    double insetTop = EntendreVisuals.headInsetTop,
    double insetBottom = EntendreVisuals.headInsetBottom,
    double heightFactor = EntendreVisuals.headHeightFactor,
    double yNudge = EntendreVisuals.tailAlignYOffsetPx, // tails use this
  }) {
    final double pillH = math.min(
      lineStride - (insetTop + insetBottom),
      lineStride * heightFactor,
    );

    // Vertical centering inside the line band (same as head/tail pills)
    final double bandTopOffset =
        insetTop + ((lineStride - insetTop - insetBottom) - pillH) / 2.0;

    final double contentTop = lineTop + bandTopOffset + yNudge;
    return (pillH: pillH, contentTop: contentTop);
  }
}
