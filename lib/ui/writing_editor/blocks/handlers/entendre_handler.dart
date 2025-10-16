// lib/ui/writing_editor/blocks/handlers/entendre_handler.dart
import 'dart:math' as math;
import 'dart:ui' as ui; // Rect, Offset
import 'package:flutter/material.dart';
import 'package:characters/characters.dart';

import 'package:kontinuum/ui/writing_editor/models/text_block.dart';
import 'package:kontinuum/ui/writing_editor/blocks/visuals/entendre_visuals.dart';
import 'package:kontinuum/ui/writing_editor/blocks/visuals/underline.dart';

import '../../core/editor_layout.dart'; // for line stride
import '../../core/block_fragment_computer.dart'; // for wrap/guard + grapheme fit
import '../block_handler.dart';

double _headLeftGap() => EntendreVisuals.firstLineLeftPadPx;

/// Visual-only extra right padding inside the head pill. Keep 0 to avoid any hidden runway.
const double _headRightPadBoostPx = 0;

// ----------------- Notifications -----------------
class InlineBlockFocusNotification extends Notification {
  final bool active;
  final TextBlock block;
  InlineBlockFocusNotification({required this.active, required this.block});
}

class InlineBlockGeometryNotification extends Notification {
  final String stableId;
  final ui.Rect globalRect;
  InlineBlockGeometryNotification({
    required this.stableId,
    required this.globalRect,
  });
}
// =================================================

class EntendreHandler implements MeasurableBlockHandler {
  @override
  BlockType get type => BlockType.entendre;

  static const int _meaningMaxGraphemes = 75;
  static String _trimMeaning(String s) =>
      s.characters.take(_meaningMaxGraphemes).toString();

  static double _measureTextWidth(String s, TextStyle style, {double? maxW}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: maxW ?? double.infinity);
    return tp.width;
  }

  /// Ink-aware width using glyph ink boxes (more conservative near the edge).
  static double _measureInkWidth(String s, TextStyle style, {double? maxW}) {
    if (s.isEmpty) return 0;
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: maxW ?? double.infinity);

    final boxes = tp.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1 << 30),
    );
    if (boxes.isEmpty) return tp.width;

    double minL = boxes.first.left, maxR = boxes.first.right;
    for (final b in boxes) {
      if (b.left < minL) minL = b.left;
      if (b.right > maxR) maxR = b.right;
    }
    return (maxR - minL).clamp(0.0, double.infinity);
  }

  static double _computeInnerCap({
    required double capMax,
    required EdgeInsets pillPad,
    double border = 0,
  }) {
    if (!capMax.isFinite) return double.infinity;
    final inner = capMax - pillPad.horizontal - (border * 2);
    return inner <= 0 ? 0 : inner;
  }

  // ---------- measuring ----------
  @override
  double measureMinWidth({
    required BuildContext context,
    required TextBlock block,
    required TextStyle baseStyle,
  }) {
    final labelText = _trimMeaning(block.label);

    // Ink-aware + tiny right runway so uncapped heads never shave.
    final wLabel =
        _measureInkWidth(labelText, EntendreVisuals.labelTextStyle) +
        EntendreVisuals.headClipRightPadPx;

    final leftGap = _headLeftGap();

    if (block.postText.isEmpty) {
      return leftGap +
          wLabel +
          EntendreVisuals.pillPad.horizontal +
          EntendreVisuals.headExtraLeftPad +
          EntendreVisuals.headExtraRightPad +
          EntendreVisuals.headEndcapPx +
          EntendreVisuals.headRightSafety +
          _headRightPadBoostPx;
    }

    final rightTextW = _measureTextWidth(block.postText, baseStyle);
    final wRight =
        EntendreVisuals.gap +
        math.max(EntendreVisuals.rightSeedWidth, rightTextW);

    return leftGap +
        wLabel +
        wRight +
        EntendreVisuals.pillPad.horizontal +
        EntendreVisuals.headExtraLeftPad +
        EntendreVisuals.headExtraRightPad +
        EntendreVisuals.headEndcapPx +
        EntendreVisuals.headRightSafety +
        _headRightPadBoostPx;
  }

  // ---------- span ----------
  @override
  InlineSpan buildSpan({
    required BuildContext context,
    required TextBlock block,
    required TextStyle baseStyle,
    required void Function(TextBlock, ui.Rect) onTap,
    double? minWidth,
    double? maxHeadWidth,
    bool isArmed = false,
    int armedTick = 0,
    bool isSelected = false,
    void Function(TextBlock before, TextBlock after)? requestUpdate,
  }) {
    final String id = block.stableId;
    final String labelText = _trimMeaning(block.label);

    final double minWMeasured = (minWidth ?? 0).clamp(0.0, double.infinity);
    final double capW = (maxHeadWidth ?? double.infinity).clamp(
      0.0,
      double.infinity,
    );

    // Pads + ink + safety + left gap (+ tiny runway)
    final double labelOnlyMin =
        _measureInkWidth(labelText, EntendreVisuals.labelTextStyle) +
        EntendreVisuals.headClipRightPadPx +
        EntendreVisuals.pillPad.horizontal +
        EntendreVisuals.headExtraLeftPad +
        EntendreVisuals.headExtraRightPad +
        EntendreVisuals.headEndcapPx +
        EntendreVisuals.headRightSafety +
        _headRightPadBoostPx +
        _headLeftGap();

    final screenW = MediaQuery.sizeOf(context).width;
    final capMaxOuter = capW.isFinite ? capW : screenW;

    // 🔑 Content-only cap (remove external left gap)
    final double leftGap = _headLeftGap();
    final Widget capped = LayoutBuilder(
      builder: (ctx, incoming) {
        final incomingMaxOuter = incoming.maxWidth.isFinite
            ? incoming.maxWidth
            : screenW;

        // No DPR snapping here — use the exact outer cap we receive
        final double hardMaxOuterAligned = math.min(
          incomingMaxOuter,
          capMaxOuter,
        );

        final bool rightIsEmpty = block.postText.isEmpty;
        final double headMinWhole = rightIsEmpty ? labelOnlyMin : minWMeasured;
        final double effectiveMinOuter = math.min(
          headMinWhole,
          hardMaxOuterAligned,
        );

        // Convert whole-constraints → content-only constraints (no snapping)
        final double hardMaxContent = math.max(
          0.0,
          hardMaxOuterAligned - leftGap,
        );
        final double minContent = math.max(0.0, effectiveMinOuter - leftGap);

        // Pass content-only cap to the pill so fitter measures correctly.
        double headCapForWidget = hardMaxContent;

        // First-frame fallback
        if (headCapForWidget <= 0) {
          headCapForWidget = math.max(0.0, minContent);
          if (headCapForWidget <= 0) headCapForWidget = double.infinity;
        }

        final face = Builder(
          builder: (pillCtx) {
            ui.Rect pillRectGlobal() {
              final rb = pillCtx.findRenderObject() as RenderBox?;
              if (rb == null) return ui.Rect.zero;
              final topLeft = rb.localToGlobal(ui.Offset.zero);
              final size = rb.size;
              return topLeft & size;
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!pillCtx.mounted) return;
              InlineBlockGeometryNotification(
                stableId: id,
                globalRect: pillRectGlobal(),
              ).dispatch(pillCtx);
            });

            return _InlineCenterLabelRightEditablePill(
              key: ValueKey('entendre-pill-$id'),
              baseStyle: baseStyle,
              label: labelText,
              initialRightText: block.postText,
              minRightWidth: EntendreVisuals.rightSeedWidth,
              gap: EntendreVisuals.gap,
              pillRadius: EntendreVisuals.pillRadius,
              pillPadding: EntendreVisuals.pillPad,
              headOuterCapMax: headCapForWidget, // ✅ content-only cap
              onTapLabel: () {
                final rect = pillRectGlobal();
                onTap(block, rect);
              },
              onChangedRight: (text) {
                requestUpdate?.call(block, block.copyWith(postText: text));
              },
              blockForNotification: block,
              meaningAnimDuration: EntendreVisuals.meaningAnimDuration,
              meaningAnimCurveIn: EntendreVisuals.meaningAnimCurveIn,
              meaningAnimCurveOut: EntendreVisuals.meaningAnimCurveOut,
            );
          },
        );

        // Constrain ONLY the content; add the left gap outside the constraints.
        final constrainedContent = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minContent,
            maxWidth: hardMaxContent,
          ),
          child: face,
        );

        // Padding for the left gap applied outside, so it doesn’t reduce content cap.
        final withLeftGapOutside = Padding(
          padding: EdgeInsets.only(left: leftGap),
          child: constrainedContent,
        );

        // Outer box keeps the whole head (gap + content) aligned left.
        return SizedBox(
          width: hardMaxOuterAligned,
          child: Align(
            alignment: Alignment.centerLeft,
            child: withLeftGapOutside,
          ),
        );
      },
    );

    final headBox = KeyedSubtree(
      key: ValueKey('entendre-head-$id'),
      child: capped,
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: RepaintBoundary(child: headBox),
    );
  }
}

// -------------- widget -----------------

class _InlineCenterLabelRightEditablePill extends StatefulWidget {
  final TextStyle baseStyle;
  final String label;
  final String initialRightText;
  final double minRightWidth;
  final double gap;
  final double pillRadius;
  final EdgeInsets pillPadding;
  final double? headOuterCapMax; // content-only cap from handler
  final VoidCallback onTapLabel;
  final ValueChanged<String> onChangedRight;
  final TextBlock blockForNotification;

  final Duration meaningAnimDuration;
  final Curve meaningAnimCurveIn;
  final Curve meaningAnimCurveOut;

  const _InlineCenterLabelRightEditablePill({
    super.key,
    required this.baseStyle,
    required this.label,
    required this.initialRightText,
    required this.minRightWidth,
    required this.gap,
    required this.pillRadius,
    required this.pillPadding,
    required this.headOuterCapMax,
    required this.onTapLabel,
    required this.onChangedRight,
    required this.blockForNotification,
    required this.meaningAnimDuration,
    required this.meaningAnimCurveIn,
    required this.meaningAnimCurveOut,
  });

  @override
  State<_InlineCenterLabelRightEditablePill> createState() =>
      _InlineCenterLabelRightEditablePillState();
}

class _InlineCenterLabelRightEditablePillState
    extends State<_InlineCenterLabelRightEditablePill> {
  late final TextEditingController _rightCtrl;
  late final FocusNode _rightFocus;
  late String _lastRightText;

  double _oneDevicePixel(double dpr) => 1.0 / dpr;
  double _snapUp(double v, BuildContext ctx) {
    final dpr = MediaQuery.devicePixelRatioOf(ctx);
    return (v * dpr).ceilToDouble() / dpr;
  }

  @override
  void initState() {
    super.initState();
    _rightCtrl = TextEditingController(text: widget.initialRightText);
    _lastRightText = widget.initialRightText;

    _rightCtrl.addListener(() {
      final curr = _rightCtrl.text;
      if (curr != _lastRightText) {
        _lastRightText = curr;
        widget.onChangedRight(curr);
        setState(() {}); // relayout when right field width changes
      }
    });

    _rightFocus = FocusNode(debugLabel: 'entendre-right');
    _rightFocus.addListener(_notifyFocusChanged);
  }

  void _notifyFocusChanged() {
    if (!mounted) return;
    InlineBlockFocusNotification(
      active: _rightFocus.hasFocus,
      block: widget.blockForNotification,
    ).dispatch(context);
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant _InlineCenterLabelRightEditablePill old) {
    super.didUpdateWidget(old);
    if (!_rightFocus.hasFocus && _rightCtrl.text != widget.initialRightText) {
      _rightCtrl.text = widget.initialRightText;
      _rightCtrl.selection = TextSelection.collapsed(
        offset: _rightCtrl.text.length,
      );
      _lastRightText = _rightCtrl.text;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _rightFocus.removeListener(_notifyFocusChanged);
    if (mounted) {
      InlineBlockFocusNotification(
        active: false,
        block: widget.blockForNotification,
      ).dispatch(context);
    }
    _rightCtrl.dispose();
    _rightFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Baseline that matches the editor
    final tpLine = TextPainter(
      text: const TextSpan(text: 'M', style: EntendreVisuals.labelTextStyle),
      strutStyle: const StrutStyle(
        fontSize: EditorLayout.fontSize,
        height: EditorLayout.lineHeightMult,
        leadingDistribution: TextLeadingDistribution.even,
        forceStrutHeight: true,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textWidthBasis: TextWidthBasis.parent,
    )..layout();
    final lmLine = tpLine.computeLineMetrics();
    final double baselinePx = lmLine.isNotEmpty
        ? lmLine.first.baseline
        : tpLine.height;

    final bool showRight = _rightFocus.hasFocus || _rightCtrl.text.isNotEmpty;
    final double minRightW = showRight ? widget.minRightWidth : 0.0;

    // Reserve for the right field so label gets the true leftover.
    final TextStyle rightStyle = widget.baseStyle.copyWith(
      color: Colors.white,
      height: 1.0,
    );
    final double rightTextW = showRight
        ? EntendreHandler._measureTextWidth(_rightCtrl.text, rightStyle)
        : 0.0;
    final double rightTargetW = showRight
        ? math.max(minRightW, rightTextW)
        : 0.0;
    final double rightReserve = showRight ? (widget.gap + rightTargetW) : 0.0;

    // ===== Cap logic: compute inner content cap for the label =============
    final double outerCap =
        (widget.headOuterCapMax == null || (widget.headOuterCapMax ?? 0) <= 0)
        ? double.infinity
        : widget.headOuterCapMax!;

    // Base inner content width available to the label (no extra pads / right field)
    const double extraHPads =
        EntendreVisuals.headExtraLeftPad +
        EntendreVisuals.headExtraRightPad +
        EntendreVisuals.headEndcapPx;

    final double innerCapBase = EntendreHandler._computeInnerCap(
      capMax: outerCap,
      pillPad: widget.pillPadding,
    );

    final double innerBase = math.max(
      0.0,
      innerCapBase - extraHPads - rightReserve,
    );

    // --- Unified cap-aware fitter (binary search) --------------------------
    const TextStyle headTextStyle = EntendreVisuals.labelTextStyle;

    // Available content width for the label (no pads/right field)
    final double contentInkCap = math.max(0.0, innerBase);

    // Minimal runway we always want next to the last glyph to avoid shaving
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double runway =
        math.max(EntendreVisuals.headClipRightPadPx, 0.5 / dpr) +
        EntendreVisuals.glyphBleedGuardPx;

    // Helpers (respect innerBase)
    double inkW(String s) =>
        EntendreHandler._measureInkWidth(s, headTextStyle, maxW: innerBase);
    double advW(String s) =>
        EntendreHandler._measureTextWidth(s, headTextStyle, maxW: innerBase);
    double paintW(String s) => math.max(inkW(s), advW(s));
    double need(String s) => paintW(s) + runway;

    // Binary search: max graphemes such that need(slice) <= contentInkCap
    final chars = widget.label.characters;
    int lo = 0, hi = chars.length;

    bool fits(int take) {
      if (!outerCap.isFinite) return true; // no cap → everything fits
      final slice = chars.take(take).toString();
      return need(slice) <= contentInkCap + 1e-3;
    }

    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }

    String visible = chars.take(lo).toString();
    // Safety: if there is no cap, render full label
    if (!outerCap.isFinite) visible = widget.label;

    final String headVisibleText = visible;

    // --- Final width: snap UP to device pixels after adding a tiny fudge ----
    final double pw = paintW(headVisibleText);

    // extra 0.75px/dpr so we never under-allocate due to subpixel rounding
    final double fudge = 0.75 / dpr;

    double widthTarget = pw + runway + fudge;

    if (outerCap.isFinite) {
      widthTarget = math.min(widthTarget, contentInkCap);
    }

    // Snap up to physical pixels, then re-clamp to the cap, never below paint width
    widthTarget = _snapUp(widthTarget, context);
    if (outerCap.isFinite) {
      widthTarget = math.min(widthTarget, contentInkCap);
    }
    widthTarget = math.max(widthTarget, pw);

    // DEBUG (debug mode only)
    assert(() {
      debugPrint(
        '[Entendre] vis="$headVisibleText" pw=${pw.toStringAsFixed(3)} '
        'runway=${runway.toStringAsFixed(3)} fudge=${fudge.toStringAsFixed(3)} '
        'cap=${outerCap.isFinite ? contentInkCap.toStringAsFixed(3) : "∞"} '
        'final=${widthTarget.toStringAsFixed(3)}',
      );
      return true;
    }());
    // -----------------------------------------------------------------------

    final Widget labelCore = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _rightFocus.requestFocus();
        widget.onTapLabel();
      },
      child: _AnimatedMeaningLabel(
        key: ValueKey('lbl-${widget.blockForNotification.stableId}'),
        text: headVisibleText,
        style: headTextStyle,
        duration: widget.meaningAnimDuration,
        curveIn: widget.meaningAnimCurveIn,
        curveOut: widget.meaningAnimCurveOut,
      ),
    );

    // Clip is ON; pill grows to `widthTarget`, which is <= cap and >= paint width.
    final Widget label = ClipRect(
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: widthTarget,
        child: RepaintBoundary(child: labelCore),
      ),
    );

    // Right field fixed-width so Row never steals from the label runway.
    final rightFieldCore = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: rightTargetW,
        maxWidth: rightTargetW,
      ),
      child: Focus(
        focusNode: _rightFocus,
        canRequestFocus: true,
        onKeyEvent: (_, __) => KeyEventResult.ignored,
        child: TextField(
          controller: _rightCtrl,
          focusNode: _rightFocus,
          cursorColor: Colors.white,
          style: widget.baseStyle.copyWith(color: Colors.white, height: 1.0),
          decoration: const InputDecoration.collapsed(hintText: ''),
          maxLines: 1,
          textAlign: TextAlign.left,
          onTap: () => _rightFocus.requestFocus(),
          onTapOutside: (_) {
            if (_rightFocus.hasFocus) _rightFocus.unfocus();
          },
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.done,
        ),
      ),
    );

    final rightField = AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      child: showRight ? rightFieldCore : const SizedBox.shrink(),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        label,
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeInOut,
          width: showRight ? widget.gap : 0.0,
        ),
        rightField,
      ],
    );

    // --- Make the head pill compact like tails
    final double lineStride = EditorLayout.lineStride();
    final double pillH = math.min(
      lineStride -
          (EntendreVisuals.headInsetTop + EntendreVisuals.headInsetBottom),
      lineStride * EntendreVisuals.headHeightFactor,
    );

    // Vertical centering inside the pill using actual text heights
    final tpHead = TextPainter(
      text: const TextSpan(text: 'Mg', style: EntendreVisuals.labelTextStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textWidthBasis: TextWidthBasis.parent,
    )..layout();
    final tpRightProbe = TextPainter(
      text: TextSpan(text: 'Mg', style: widget.baseStyle.copyWith(height: 1.0)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textWidthBasis: TextWidthBasis.parent,
    )..layout();

    final double contentH = math.max(tpHead.height, tpRightProbe.height);
    final double vPadHalf = math.max(0.0, (pillH - contentH) / 2.0);

    final double padL =
        EntendreVisuals.pillPad.left + EntendreVisuals.headExtraLeftPad;
    final double padR =
        EntendreVisuals.pillPad.right +
        EntendreVisuals.headExtraRightPad +
        EntendreVisuals.headEndcapPx;

    final pillSurfaceCore = DecoratedBox(
      decoration: EntendreVisuals.headBoxDecoration(color: Colors.black),
      child: Padding(
        padding: EdgeInsets.fromLTRB(padL, vPadHalf, padR, vPadHalf),
        child: content,
      ),
    );

    // Underline behind the head pill surface.
    final underline = Underline(
      dy: EntendreVisuals.underlineDy,
      radius: EntendreVisuals.headCornerRadius,
    );

    final Widget pillSurface = CustomPaint(
      painter: _HeadUnderlinePainter(underline),
      child: pillSurfaceCore,
    );

    return FocusScope(
      canRequestFocus: true,
      child: Baseline(
        baseline: baselinePx,
        baselineType: TextBaseline.alphabetic,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: lineStride,
            child: Padding(
              padding: const EdgeInsets.only(
                top: EntendreVisuals.headInsetTop,
                bottom: EntendreVisuals.headInsetBottom,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: pillH,
                  child: Transform.translate(
                    offset: const Offset(0, EntendreVisuals.headAlignYOffsetPx),
                    child: Align(
                      alignment: const Alignment(
                        0,
                        EntendreVisuals.headAlignYOffset,
                      ),
                      child: pillSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMeaningLabel extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Duration duration;
  final Curve curveIn;
  final Curve curveOut;

  const _AnimatedMeaningLabel({
    super.key,
    required this.text,
    required this.style,
    required this.duration,
    required this.curveIn,
    required this.curveOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curveIn,
      switchOutCurve: curveOut,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: curveIn));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textWidthBasis: TextWidthBasis.parent,
        textAlign: TextAlign.left,
      ),
    );
  }
}

/// Background painter that draws the pill-shaped underline under the head.
class _HeadUnderlinePainter extends CustomPainter {
  final Underline underline;
  const _HeadUnderlinePainter(this.underline);

  @override
  void paint(Canvas canvas, Size size) {
    underline.paintPill(canvas, Offset.zero & size, clipSize: size);
  }

  @override
  bool shouldRepaint(covariant _HeadUnderlinePainter oldDelegate) {
    return oldDelegate.underline.color != underline.color ||
        oldDelegate.underline.opacity != underline.opacity ||
        (oldDelegate.underline.dy - underline.dy).abs() > 0.001 ||
        (oldDelegate.underline.radius - underline.radius).abs() > 0.001;
  }
}
