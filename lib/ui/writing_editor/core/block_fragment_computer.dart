// lib/ui/writing_editor/core/block_fragment_computer.dart
import 'dart:math' as math;
import 'dart:ui' show Rect, TextBox, LineMetrics, TextPosition, TextDirection;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextStyle, TextWidthBasis;
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:characters/characters.dart'; // ✅ grapheme-safe splitting

import 'block_fragment.dart';
// Shared visuals (pads/guards)
import '../blocks/visuals/entendre_visuals.dart' show EntendreVisuals;

class BlockFragmentComputer {
  const BlockFragmentComputer();

  /// Master debug switch (effective only in kDebugMode).
  static const bool _debugLogs = true;

  /// Small positive epsilon that biases wrap decisions so synthetic fragments
  /// line up with what the engine/UI do.
  static const double wrapEps = 0.75;

  /// Extra conservative guard **only at the cap** so the head never steals the
  /// first grapheme that should belong to the tail.
  static const double capGuardPx = -0.75;

  /// Minimum pixel width for a *final* tail line worth drawing.
  static const double minTailWidthPx = 6.0;

  /// NEW: “decision slack” (measure-time). If the next grapheme's width
  /// would exceed the remaining inner width by less than this amount,
  /// we still treat it as NOT FITTING and push it to the tail.
  /// Keep in sync with EntendreVisuals.fitDecisionSlackPx.
  static const double fitDecisionSlackPx = 0;

  /// Tiny positive slack so borderline graphemes don’t get dropped.
  static const double glyphRoundingSlackPx = 0.50;

  // --------------------------------------------------------------------------
  // 🔴 Single source of truth: how many graphemes fit into a one-line cap
  // --------------------------------------------------------------------------

  /// Still exposed for tail painter word-slicing and other callers.
  static int countGraphemesThatFitOneLine({
    required String text,
    required TextStyle style,
    required double maxInnerWidth,
    bool isCapped = false,
    double decisionSlackPx = fitDecisionSlackPx,
  }) {
    if (!maxInnerWidth.isFinite || maxInnerWidth <= 0) return 0;
    final chars = text.characters;
    if (chars.isEmpty) return 0;

    double _measure(String s) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        // ✅ match pill: parent basis with *finite* layout
        textWidthBasis: TextWidthBasis.parent,
        maxLines: 1,
      )..layout(maxWidth: maxInnerWidth); // 🔑 finite width
      return tp.width;
    }

    bool fits(int take) {
      final slice = chars.take(take).toString();
      final w = _measure(slice);
      // Allow tiny positive slack so we don't shave at the threshold.
      return w <= (maxInnerWidth + glyphRoundingSlackPx);
    }

    int lo = 0, hi = chars.length;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }

    // Optional conservative backoff when capped and the slice barely fits.
    if (isCapped && lo > 0 && lo < chars.length && decisionSlackPx > 0) {
      final slice = chars.take(lo).toString();
      final w = _measure(slice);
      final remaining = maxInnerWidth - w;
      if (remaining < decisionSlackPx) {
        lo = math.max(0, lo - 1);
      }
    }

    return lo;
  }

  // --------------------------------------------------------------------------
  // Focused TRACE controls
  // --------------------------------------------------------------------------

  static const String? _traceId = null;
  static const bool _traceFit = true;

  bool _shouldTrace(String id) =>
      _debugLogs && _traceFit && (_traceId == null || _traceId == id);

  double _measure1(String s, TextStyle style, double maxW) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      // ✅ match pill: parent basis
      textWidthBasis: TextWidthBasis.parent,
      maxLines: 1,
    )..layout(maxWidth: maxW.isFinite ? maxW : double.infinity);
    return tp.width;
  }

  // --------------------------------------------------------------------------
  // Phase 0 — use engine geometry when available
  // --------------------------------------------------------------------------

  List<BlockFragment> computeFromRenderEditable({
    required RenderEditable renderEditable,
    required Map<String, BlockTextRange> blockRanges,
  }) {
    if (blockRanges.isEmpty) return const [];

    if (_debugLogs && kDebugMode) {
      debugPrint(
        '[FragComp] Phase0.computeFromRenderEditable: ranges=${blockRanges.length}',
      );
    }

    final out = <BlockFragment>[];

    for (final entry in blockRanges.entries) {
      final id = entry.key;
      final sel = entry.value.toSelection();

      List<TextBox> boxes;
      try {
        boxes = renderEditable.getBoxesForSelection(sel);
      } catch (_) {
        boxes = const <TextBox>[];
      }
      if (_shouldTrace(id)) {
        debugPrint('  [FragComp][Phase0] id=$id engineBoxes=${boxes.length}');
      }
      if (boxes.isEmpty) continue;

      final bands = _groupIntoYBands(boxes)
        ..sort((a, b) => a.top.compareTo(b.top));
      if (_shouldTrace(id)) {
        debugPrint('  [FragComp][Phase0] id=$id yBands=${bands.length}');
      }

      for (int i = 0; i < bands.length; i++) {
        final rect = _mergeBoxes(bands[i].boxes);
        if (rect.isEmpty) continue;
        out.add(
          BlockFragment(
            blockId: id,
            lineIndex: i,
            rect: rect,
            isFirstInBlock: i == 0,
            isLastInBlock: i == bands.length - 1,
          ),
        );
      }
    }

    out.sort(_stableOrder);

    if (_debugLogs && kDebugMode) {
      debugPrint('[FragComp] Phase0 done → fragments=${out.length}');
    }
    return out;
  }

  List<BlockFragment> computeFromTextPainter({
    required TextPainter tp,
    required List<LineMetrics> lineMetrics,
    required Map<String, BlockTextRange> blockRanges,
  }) {
    if (blockRanges.isEmpty || lineMetrics.isEmpty) return const [];

    if (_debugLogs && kDebugMode) {
      debugPrint(
        '[FragComp] Phase0b.computeFromTextPainter: ranges=${blockRanges.length} lines=${lineMetrics.length}',
      );
    }

    final out = <BlockFragment>[];

    for (final entry in blockRanges.entries) {
      final id = entry.key;
      final sel = entry.value.toSelection();

      List<TextBox> boxes;
      try {
        boxes = tp.getBoxesForSelection(sel);
      } catch (_) {
        boxes = const <TextBox>[];
      }
      if (_shouldTrace(id)) {
        debugPrint('  [FragComp][Phase0b] id=$id painterBoxes=${boxes.length}');
      }
      if (boxes.isEmpty) continue;

      final byLine = <int, List<TextBox>>{};
      for (final b in boxes) {
        final midY = (b.top + b.bottom) * 0.5;
        final li = _lineIndexForY(midY, lineMetrics);
        if (li >= 0) byLine.putIfAbsent(li, () => <TextBox>[]).add(b);
      }

      final keys = byLine.keys.toList()..sort();
      for (int i = 0; i < keys.length; i++) {
        final li = keys[i];
        final rect = _mergeBoxes(byLine[li]!);
        if (rect.isEmpty) continue;
        out.add(
          BlockFragment(
            blockId: id,
            lineIndex: li,
            rect: rect,
            isFirstInBlock: i == 0,
            isLastInBlock: i == keys.length - 1,
          ),
        );
      }
    }

    out.sort(_stableOrder);

    if (_debugLogs && kDebugMode) {
      debugPrint('[FragComp] Phase0b done → fragments=${out.length}');
    }
    return out;
  }

  // --------------------------------------------------------------------------
  // Phase 1 — synthetic fragmenter for WidgetSpans (head + tails)
  // --------------------------------------------------------------------------

  List<BlockFragment> computeSyntheticFromMeasurements({
    required RenderEditable renderEditable,
    required Map<String, BlockTextRange> blockRanges,
    required Map<String, double> blockPixelWidths,
    required double lineStride,
    required double paragraphWidth,
    double firstLineLeftPad = 0.0, // ← was 2.0
    double tailLeftPad = 0.0, // ← was 7.0
    double tailRightInsetOnLast =
        0.0, // leave 0 (callsite already handles -wrapEps when desired)
    double headRightSafety = 0.0, // ← was 4.0
    // Character-accurate sizing inputs
    Map<String, String>? blockLabels,
    TextStyle? labelTextStyle,
    double headInnerHPad = 0.0, // ← was 14.0
    double tailInnerHPad = 0.0, // ← was 14.0
    Map<String, double> headRightReserves = const <String, double>{},

    int capEdgeSqueezeMaxGraphemes = 0,
    double capEdgeSqueezeForgiveness = wrapEps + 0.75,
  }) {
    if (blockRanges.isEmpty) return const [];

    if (_debugLogs && kDebugMode) {
      debugPrint(
        '[FragComp] Phase1.computeSyntheticFromMeasurements: '
        'ranges=${blockRanges.length} stride=$lineStride paraW=$paragraphWidth '
        'firstPad=$firstLineLeftPad tailPad=$tailLeftPad insetLast=$tailRightInsetOnLast '
        'headSafety=$headRightSafety headInnerHPad=$headInnerHPad '
        'precise=${blockLabels != null && labelTextStyle != null} '
        'hasReserves=${headRightReserves.isNotEmpty} '
        'squeeze=${capEdgeSqueezeMaxGraphemes > 0}',
      );
    }

    Rect? safeCaretRectAt(int offset) {
      try {
        return renderEditable.getLocalRectForCaret(
          TextPosition(offset: offset),
        );
      } catch (_) {
        return null;
      }
    }

    // ---- Tail fitter (word-friendly) ---------------------------------------
    int fitWordSafeWords({
      required Characters chars,
      required TextStyle style,
      required double maxW,
    }) {
      if (!maxW.isFinite || maxW <= 0) return 0;

      final String s = chars.toString();
      if (s.isEmpty) return 0;

      final re = RegExp(r'\s+|\S+');
      final tokens = re.allMatches(s).map((m) => m.group(0)!).toList();
      if (tokens.isEmpty) return 0;

      double widthOf(String piece) {
        final tp = TextPainter(
          text: TextSpan(text: piece, style: style),
          textDirection: TextDirection.ltr,
          // ✅ match pill: parent basis
          textWidthBasis: TextWidthBasis.parent,
          maxLines: 1,
        )..layout(maxWidth: maxW); // finite
        return tp.didExceedMaxLines ? double.infinity : tp.width;
      }

      int takenGraphemes = 0;
      String line = '';

      for (final tok in tokens) {
        final candidate = line + tok;
        final w = widthOf(candidate);

        if (w <= maxW) {
          line = candidate;
          takenGraphemes += Characters(tok).length;
          continue;
        }

        if (line.isEmpty) {
          final Characters g = Characters(tok);
          int lo = 0, hi = g.length;
          while (lo < hi) {
            final mid = (lo + hi + 1) >> 1;
            final slice = g.take(mid).toString();
            if (widthOf(slice) <= maxW) {
              lo = mid;
            } else {
              hi = mid - 1;
            }
          }
          return lo;
        }

        break;
      }

      return takenGraphemes;
    }
    // ------------------------------------------------------------------------

    final out = <BlockFragment>[];

    for (final entry in blockRanges.entries) {
      final id = entry.key;
      final range = entry.value;

      final measuredWidth = blockPixelWidths[id];
      if (measuredWidth == null || measuredWidth <= 0) continue;

      final Rect? startCaret = safeCaretRectAt(range.start);
      if (startCaret == null) continue;

      final double headTop = startCaret.top;
      final double headBottom = startCaret.bottom;
      final double headLeft = startCaret.right + firstLineLeftPad;
      final double lineRight = paragraphWidth;

      // MUST match BarRow cap calculation.
      final double headAvail =
          (lineRight - headLeft - headRightSafety + wrapEps).clamp(
            0.0,
            double.infinity,
          );

      final String? labelStr = blockLabels != null ? blockLabels[id] : null;
      final bool preciseByText = (labelStr != null && labelTextStyle != null);

      if (_shouldTrace(id)) {
        debugPrint(
          '[FRAG][HEAD@start] id=$id '
          'headLeft=${headLeft.toStringAsFixed(2)} '
          'headAvail=${headAvail.toStringAsFixed(2)} '
          'measuredMin=${measuredWidth.toStringAsFixed(2)} '
          'precise=$preciseByText',
        );
      }

      double remainingPixels = measuredWidth;

      // ---- Head -------------------------------------------------------------
      final double headWidth = math.min(remainingPixels, headAvail);
      final Rect headRect = Rect.fromLTRB(
        headLeft,
        headTop,
        (headLeft + headWidth).clamp(headLeft, lineRight),
        headBottom,
      );

      const int headLineIndex = 0;

      if (headRect.width > 0.5 && headRect.height > 0.5) {
        out.add(
          BlockFragment(
            blockId: id,
            lineIndex: headLineIndex,
            rect: headRect,
            isFirstInBlock: true,
            isLastInBlock: false, // temporary; updated later
          ),
        );
      }

      // ---- Consume text/pixels used by the head (✅ new rule) ---------------
      Characters remainingChars = Characters(labelStr ?? '');
      int consumedForHead = 0;

      if (preciseByText) {
        // Decide “capped” by comparing required width vs available with slack.
        final bool atCap = (measuredWidth - headAvail) >= 0.75;

        if (!atCap) {
          // Not capped → head renders full label.
          consumedForHead = remainingChars.length;
        } else {
          // Capped → conservative guard so the head doesn’t steal from the tail.
          final double reservePx = (headRightReserves[id] ?? 0.0).clamp(
            0.0,
            double.infinity,
          );

          // Painter-aligned inner width available to label content (no safety/clip).
          final double innerBase = math.max(
            0.0,
            headWidth -
                EntendreVisuals.pillPad.horizontal -
                EntendreVisuals.headTextExtraLeftPad -
                EntendreVisuals.headTextExtraRightPad -
                EntendreVisuals.headEndcapPx -
                reservePx,
          );

          // Positive slack instead of shrinking.
          final double innerForMeasure = math.max(
            0.0,
            innerBase + glyphRoundingSlackPx,
          );

          consumedForHead = innerForMeasure <= 0
              ? 0
              : BlockFragmentComputer.countGraphemesThatFitOneLine(
                  text: remainingChars.toString(),
                  style: labelTextStyle!,
                  maxInnerWidth: innerForMeasure,
                  isCapped: true,
                );

          // Safety net: if we trimmed but the full label actually fits, keep it whole.
          if (labelStr != null && labelTextStyle != null) {
            final total = Characters(labelStr).length;
            if (consumedForHead < total && innerForMeasure > 0) {
              final tpFull = TextPainter(
                text: TextSpan(text: labelStr, style: labelTextStyle),
                textDirection: TextDirection.ltr,
                textWidthBasis: TextWidthBasis.parent,
                maxLines: 1,
              )..layout(maxWidth: innerForMeasure);
              if (!tpFull.didExceedMaxLines &&
                  tpFull.width <= innerForMeasure + glyphRoundingSlackPx) {
                consumedForHead = total;
              }
            }
          }
        }

        if (consumedForHead > 0) {
          remainingChars = remainingChars.skip(consumedForHead);
        }

        if (_shouldTrace(id)) {
          final remainingLen = remainingChars.length;
          debugPrint(
            '[FRAG][HEAD@consume] id=$id atCap=$atCap '
            'outer=${headWidth.toStringAsFixed(2)} take=$consumedForHead rem=$remainingLen',
          );
        }

        // Debug guardrail: we should never trim the head if not capped.
        assert(() {
          if (!atCap && consumedForHead < Characters(labelStr ?? '').length) {
            debugPrint('⚠️ Fragmenter trimmed head without cap (id=$id).');
          }
          return true;
        }());
      } else {
        remainingPixels -= headWidth;
      }

      // ---- Tails ------------------------------------------------------------
      final bool nothingLeft = preciseByText
          ? remainingChars.isEmpty
          : remainingPixels <= 0.0;

      if (nothingLeft) {
        if (out.isNotEmpty &&
            out.last.blockId == id &&
            out.last.isFirstInBlock) {
          final prev = out.removeLast();
          out.add(
            BlockFragment(
              blockId: id,
              lineIndex: prev.lineIndex,
              rect: prev.rect,
              isFirstInBlock: true,
              isLastInBlock: true,
            ),
          );
        }
        if (_shouldTrace(id)) {
          debugPrint('[FRAG][TAIL] id=$id none (head-only)');
        }
        continue;
      }

      int tailLocalIndex = headLineIndex + 1;
      double top = headTop + lineStride;
      double bottom = headBottom + lineStride;
      int tailCount = 0;

      while (preciseByText
          ? remainingChars.isNotEmpty
          : remainingPixels > 0.0) {
        final double thisLeft = tailLeftPad;
        final double thisRightMax = lineRight;

        final double thisCapAvail =
            (thisRightMax - thisLeft - headRightSafety + wrapEps).clamp(
              0.0,
              double.infinity,
            );

        if (thisCapAvail <= 0.5) {
          if (_shouldTrace(id)) {
            debugPrint('[FRAG][TAIL] id=$id zero avail for line; break');
          }
          break;
        }

        double drawWidth;
        bool wouldBeLast;

        if (preciseByText) {
          final double thisInnerAvail = (thisCapAvail - tailInnerHPad - wrapEps)
              .clamp(0.0, double.infinity);

          final style = labelTextStyle!;
          final int takeCount = fitWordSafeWords(
            chars: remainingChars,
            style: style,
            maxW: thisInnerAvail,
          );

          final String slice = takeCount > 0
              ? remainingChars.take(takeCount).toString()
              : '';

          final wTp = TextPainter(
            text: TextSpan(text: slice, style: style),
            textDirection: TextDirection.ltr,
            // ✅ match pill: parent basis
            textWidthBasis: TextWidthBasis.parent,
            maxLines: 1,
          )..layout(maxWidth: thisInnerAvail); // finite

          final double textW = wTp.width;

          drawWidth = math.min(thisCapAvail, textW + tailInnerHPad);
          wouldBeLast = takeCount >= remainingChars.length;

          if (_shouldTrace(id)) {
            debugPrint(
              '[FRAG][TAIL] id=$id line=$tailLocalIndex '
              'innerAvail=${thisInnerAvail.toStringAsFixed(2)} '
              'take=$takeCount slice="|$slice|" '
              'textW=${textW.toStringAsFixed(2)} drawW=${drawWidth.toStringAsFixed(2)} '
              'last=$wouldBeLast',
            );
          }

          if (wouldBeLast && textW < minTailWidthPx && textW > 0) {
            bool merged = false;
            for (int j = out.length - 1; j >= 0; j--) {
              final prev = out[j];
              if (prev.blockId != id) break;
              if (!prev.isFirstInBlock && !prev.isLastInBlock) {
                final Rect pr = prev.rect;
                final double rawRight = math.min(
                  pr.right + textW + tailInnerHPad,
                  thisRightMax,
                );
                final double widenedRight = math.max(
                  pr.right,
                  rawRight - tailRightInsetOnLast,
                );
                final Rect widened = Rect.fromLTRB(
                  pr.left,
                  pr.top,
                  widenedRight.clamp(pr.left, thisRightMax),
                  pr.bottom,
                );
                out[j] = BlockFragment(
                  blockId: prev.blockId,
                  lineIndex: prev.lineIndex,
                  rect: widened,
                  isFirstInBlock: false,
                  isLastInBlock: true,
                );
                remainingChars = Characters('');
                merged = true;
                if (_shouldTrace(id)) {
                  debugPrint(
                    '[FRAG][TAIL] id=$id merged tiny last (${textW.toStringAsFixed(2)}px + pad) into prev',
                  );
                }
                break;
              }
            }
            if (merged) continue;
          }

          if (takeCount > 0) {
            remainingChars = remainingChars.skip(takeCount);
          } else {
            if (_shouldTrace(id)) {
              debugPrint('[FRAG][TAIL] id=$id nothing fits this line; break');
            }
            break;
          }
        } else {
          wouldBeLast = remainingPixels <= thisCapAvail + wrapEps;
          drawWidth = math.min(remainingPixels, thisCapAvail);
        }

        final double rightInset = wouldBeLast ? tailRightInsetOnLast : 0.0;
        final double tailRight = thisLeft + drawWidth - rightInset;

        final Rect tailRect = Rect.fromLTRB(
          thisLeft,
          top,
          math.max(thisLeft, math.min(tailRight, thisRightMax)),
          bottom,
        );

        if (tailRect.width > 0.5 && tailRect.height > 0.5) {
          out.add(
            BlockFragment(
              blockId: id,
              lineIndex: tailLocalIndex,
              rect: tailRect,
              isFirstInBlock: false,
              isLastInBlock: wouldBeLast,
            ),
          );
          tailCount++;
        }

        if (!preciseByText) {
          remainingPixels -= drawWidth;
        }
        tailLocalIndex += 1;
        top += lineStride;
        bottom += lineStride;
      }

      // Patch head’s isLast flag using actual tail count.
      final bool headIsLast = tailCount == 0;
      if (headIsLast) {
        if (out.isNotEmpty) {
          for (int j = out.length - 1; j >= 0; j--) {
            if (out[j].blockId == id) {
              if (out[j].isFirstInBlock) {
                final prev = out.removeAt(j);
                out.insert(
                  j,
                  BlockFragment(
                    blockId: prev.blockId,
                    lineIndex: prev.lineIndex,
                    rect: prev.rect,
                    isFirstInBlock: true,
                    isLastInBlock: true,
                  ),
                );
              }
              break;
            }
          }
        }
      }

      if (_shouldTrace(id)) {
        debugPrint(
          '[FRAG][END] id=$id headWidth=${headRect.width.toStringAsFixed(2)} '
          'tailCount=$tailCount headIsLast=$headIsLast',
        );
      }
    }

    out.sort(_stableOrder);

    if (_debugLogs && kDebugMode) {
      debugPrint('[FragComp] Phase1 done → fragments=${out.length}');
    }
    return out;
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  int _lineIndexForY(double y, List<LineMetrics> lines) {
    for (var i = 0; i < lines.length; i++) {
      final lm = lines[i];
      final top = lm.baseline - lm.ascent;
      final bottom = lm.baseline + lm.descent;
      if (y >= top - 0.5 && y <= bottom + 0.5) return i;
    }
    double best = double.infinity;
    int idx = -1;
    for (var i = 0; i < lines.length; i++) {
      final lm = lines[i];
      final mid = (lm.baseline - lm.ascent + lm.baseline + lm.descent) / 2.0;
      final d = (y - mid).abs();
      if (d < best) {
        best = d;
        idx = i;
      }
    }
    return idx;
  }

  Rect _mergeBoxes(List<TextBox> boxes) {
    double left = double.infinity, right = -double.infinity;
    double top = double.infinity, bottom = -double.infinity;
    for (final b in boxes) {
      final bl = math.min(b.left, b.right);
      final br = math.max(b.left, b.right);
      left = math.min(left, bl);
      right = math.max(right, br);
      top = math.min(top, b.top);
      bottom = math.max(bottom, b.bottom);
    }
    if (left == double.infinity) return Rect.zero;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  List<_YBand> _groupIntoYBands(List<TextBox> boxes) {
    final bands = <_YBand>[];
    for (final tb in boxes) {
      final t = math.min(tb.top, tb.bottom);
      final b = math.max(tb.top, tb.bottom);
      final mid = (t + b) / 2.0;

      int idx = -1;
      for (int i = 0; i < bands.length; i++) {
        if (bands[i].contains(mid)) {
          idx = i;
          break;
        }
      }
      if (idx == -1) {
        bands.add(_YBand.from(t, b));
        idx = bands.length - 1;
      }
      bands[idx].add(tb);
    }
    return bands;
  }

  int _stableOrder(BlockFragment a, BlockFragment b) {
    final c1 = a.blockId.compareTo(b.blockId);
    if (c1 != 0) return c1;
    final c2 = a.rect.top.compareTo(b.rect.top);
    if (c2 != 0) return c2;
    return a.rect.left.compareTo(b.rect.left);
  }

  bool _fitsOneLine({
    required String s,
    required TextStyle? style,
    required double maxW,
  }) {
    if (style == null) return true;
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      // ✅ match pill: parent basis
      textWidthBasis: TextWidthBasis.parent,
      maxLines: 1,
    )..layout(maxWidth: maxW.isFinite ? maxW : double.infinity);
    return !tp.didExceedMaxLines && tp.width <= maxW; // strict
  }
}

class _YBand {
  double top;
  double bottom;
  final List<TextBox> boxes;

  _YBand._(this.top, this.bottom, this.boxes);

  factory _YBand.from(double top, double bottom) =>
      _YBand._(top, bottom, <TextBox>[]);

  bool contains(double y) {
    const tol = 1.0;
    return y >= (top - tol) && y <= (bottom + tol);
  }

  void add(TextBox b) {
    final t = math.min(b.top, b.bottom);
    final bt = math.max(b.top, b.bottom);
    top = math.min(top, t);
    bottom = math.max(bottom, bt);
    boxes.add(b);
  }
}
