// lib/ui/writing_editor/blocks/visuals/entendre_visuals.dart
import 'package:flutter/material.dart';
import '../../core/editor_layout.dart';

class EntendreVisuals {
  // Layout
  static const double pillRadius = 8;
  static const double headHeightFactor = .70;
  static const EdgeInsets pillPad = EdgeInsets.symmetric(horizontal: 5.0);
  static const double gap = 6;
  static const double rightSeedWidth = 24;

  // Horizontal/vertical alignment
  static const double firstLineLeftPadPx = 0.0;
  static const double headAlignYOffsetPx = 0.0;
  static const double headAlignYOffset = -0.25;
  static const double tailAlignYOffsetPx = -0.9;
  static const double tailTextYOffsetPx = 1.0;

  // Guards / runways (tuned to prevent right-edge shaving)
  static const double headRightSafety = 0.75; // used in fragmenter cap
  static const double glyphBleedGuardPx = 0.55; // ink bleed guard near clip
  static const double glyphRightOverscanPx = 1.00; // when not capped
  static const double headClipRightPadPx = 2.0; // minimal runway inside clip

  // Text
  static const TextStyle labelTextStyle = TextStyle(
    color: Colors.white,
    fontSize: EditorLayout.fontSize,
    height: 1.0,
  );

  // Head geometry
  static const double headCornerRadius = 6.0;
  static const double headEndcapPx = 0.0;
  static const double headExtraRightPad = 0.0;
  static const double headExtraLeftPad = 0.0;
  static const double headInsetTop = 2.0;
  static const double headInsetBottom = 2.0;

  static const double headTextExtraLeftPad = headExtraLeftPad;
  static const double headTextExtraRightPad = headExtraRightPad;

  // Underline
  static const double underlineDy = 2.5;
  static const double underlineOpacity = 0.28;
  static const Color underlineColor = Colors.white;
  static Paint underlinePaint() =>
      Paint()..color = underlineColor.withOpacity(underlineOpacity);

  // Anim
  static const Duration meaningAnimDuration = Duration(milliseconds: 160);
  static const Curve meaningAnimCurveIn = Curves.easeOut;
  static const Curve meaningAnimCurveOut = Curves.easeIn;

  // Paint slack (small positive helps against subpixel under-allocation)
  static const double paintSlackPx = 0.15;

  static BoxDecoration headBoxDecoration({Color color = Colors.black}) {
    const r = Radius.circular(headCornerRadius);
    return const BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.only(
        topLeft: r,
        bottomLeft: r,
        topRight: r,
        bottomRight: r,
      ),
    ).copyWith(color: color);
  }
}
