// lib/ui/writing_editor/core/editor_layout.dart
import 'package:flutter/material.dart';

class EditorLayout {
  // spacing
  static const double outerPadding = 16;
  static const double numColumnWidth = 32;
  static const double textLeftPadding = 24;

  // type
  static const double fontSize = 16;
  static const double lineHeightMult = 1.9;

  // meanings
  static const int maxEntendreMeaningChars = 75; // cap per meaning

  // lines/divider
  static const double lineThickness = 0.5;

  // bar rhythm
  /// Inner *top* padding inside each bar (keeps text off the grid line).
  static const double barVerticalPad = 3.0;

  /// Extra padding at the *bottom* of each row to prevent visual collisions
  /// with the divider and give the text a little breathing room.
  static const double rowBottomPad = 6.0; // ← was 2.0

  /// Minimum number of visual lines a bar should occupy (applies always).
  static const int minLinesPerBar = 1;

  // ----- Measured stride -----------------------------------------------------
  /// Baseline→baseline stride (in logical pixels) as reported by
  /// `RenderEditable.preferredLineHeight`. If unavailable, falls back to
  /// `fontSize * lineHeightMult`.
  static double? _measuredStride;

  /// Called by BarRow after it learns `RenderEditable.preferredLineHeight`.
  static void setMeasuredStride(double stride) {
    if (stride > 0) _measuredStride = stride;
  }

  /// Baseline→baseline stride everyone should use (falls back to config).
  static double lineStride() => _measuredStride ?? (fontSize * lineHeightMult);

  // ----- Computed sizes ------------------------------------------------------

  /// Full bar height for a single visual line (top pad + 1 stride + bottom pad).
  /// IMPORTANT: includes vertical padding so containers and paint stay in sync.
  static double rowHeight() =>
      (barVerticalPad * 2) + lineStride() + rowBottomPad;

  /// Full bar height for N visual lines (top pad + N * stride + bottom pad).
  static double rowHeightForLines(int lines) {
    final clamped = lines < minLinesPerBar ? minLinesPerBar : lines;
    return (barVerticalPad * 2) + (lineStride() * clamped) + rowBottomPad;
  }

  /// Header is ~3 text lines + padding + chrome.
  static double headerHeight() =>
      (barVerticalPad * 2) + (lineStride() * 3) + rowBottomPad + 24;

  /// Useful when snapping “even-fill” heights so dividers align to the text grid.
  /// One unit = top pad + one stride + bottom pad.
  static double evenFillUnit() =>
      (barVerticalPad * 2) + lineStride() + rowBottomPad;

  /// X-position of the vertical margin guide.
  static double dividerX() => outerPadding + numColumnWidth;
}

class EditorColors {
  static const Color margin = Color(0xFF4A148C);

  /// Subtle grid line color used for dividers.
  static Color gridLine(BuildContext _) => Colors.grey.withValues(alpha: 0.3);
}
