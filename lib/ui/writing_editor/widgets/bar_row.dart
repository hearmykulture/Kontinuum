// BAR ROW (underline integrated for tails via Underline helper)
// -------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
// (dart:ui types are re-exported by Flutter; no extra import needed)

import 'package:flutter/rendering.dart' show RenderEditable;
// import 'package:characters/characters.dart'; // Unnecessary; re-exported by Flutter

import '../core/editor_layout.dart';
import '../core/block_text_controller.dart';
import '../core/caret_manager.dart';
import '../models/text_block.dart' as model;

// Phase-0/1 types
import '../core/block_fragment.dart';
import '../core/block_fragment_cache.dart';
import '../core/block_fragment_computer.dart';

// Handlers/registry
import '../blocks/block_registry.dart';
import '../blocks/block_handler.dart'
    show MeasurableBlockHandler, BlocksChangedNotification;

// Inline pill notifications
import '../blocks/handlers/entendre_handler.dart'
    show InlineBlockFocusNotification, InlineBlockGeometryNotification;

// Entendre visuals (canonical constants & styles)
import '../blocks/visuals/entendre_visuals.dart' show EntendreVisuals;

// NEW: shared underline helper
import '../blocks/visuals/underline.dart';

class BarRow extends StatefulWidget {
  final int index;
  final double height;
  final int minLines;

  final BlockTextController controller;
  final FocusNode focusNode;
  final CaretManager caret;

  final VoidCallback onCommitTypingNav;
  final VoidCallback onCommitTypingBlur;
  final VoidCallback requestRebuild;

  final VoidCallback onPlainCopied;
  final void Function(String raw) onRichCopied;

  final VoidCallback exitInlineAll;

  /// Parent callback to set the real row height.
  /// Includes the measured stride (preferredLineHeight).
  final void Function(int index, int visualLines, double stride)?
  onReportVisualLines;

  const BarRow({
    super.key,
    required this.index,
    required this.height,
    required this.minLines,
    required this.controller,
    required this.focusNode,
    required this.caret,
    required this.onCommitTypingNav,
    required this.onCommitTypingBlur,
    required this.requestRebuild,
    required this.onPlainCopied,
    required this.onRichCopied,
    required this.exitInlineAll,
    this.onReportVisualLines,
  });

  @override
  State<BarRow> createState() => _BarRowState();
}

class _BarRowState extends State<BarRow> {
  // 🔼 Lift ONLY the content (tails + editor + caret) above the grid lines.
  static const double _rowContentLiftPx = 4.0; // tweak 3–6 to taste

  bool _inlineActive = false;
  bool _absorbOneTap = false;

  final GlobalKey<EditableTextState> _editableKey = GlobalKey();
  late final ScrollController _editScrollCtrl;

  // We set this on Backspace-down when deleting a newline; handled post-frame.
  bool _mergeUpPending = false;

  int? _lastReportedLines;

  final BlockFragmentCache _fragCache = BlockFragmentCache();
  final BlockFragmentComputer _fragComputer = const BlockFragmentComputer();
  int _lastLayoutTextHash = 0;

  /// Synthetic (local) head rects derived from fragmenter (fallback).
  final Map<String, Rect> _headLocalRects = <String, Rect>{};

  /// Live head rects in GLOBAL space reported by the WidgetSpan face.
  final Map<String, Rect> _headGlobalRects = <String, Rect>{};

  /// Track which block currently has its RIGHT FIELD focused/active.
  final Set<String> _rightActive = <String>{};

  // Field default now uses EditorLayout.lineStride() (falls back to cfg)
  double _currentStride = EditorLayout.lineStride();

  /// Repaint epoch for the tails overlay; bump when fragment content changes.
  int _fragEpoch = 0;

  /// per-block head width caps (available width on the head line).
  Map<String, double> _headCaps = const {};

  /// debounce guard for _reportLinesAfterFrames
  bool _reportScheduled = false;

  @override
  void initState() {
    super.initState();
    _editScrollCtrl = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recomputeThenReportPostFrame(force: true);
      _reportLinesAfterFrames(2);
    });
  }

  @override
  void dispose() {
    _editScrollCtrl.dispose();
    super.dispose();
  }

  // --- Tiny utilities --------------------------------------------------------

  void _absorbPointerOneFrame() {
    if (!mounted) return;
    setState(() => _absorbOneTap = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _absorbOneTap = false);
      }
    });
  }

  void _postFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  void _nudgeCursorPaint() {
    widget.controller.value = widget.controller.value.copyWith(
      text: widget.controller.text,
      selection: widget.controller.selection,
      composing: widget.controller.value.composing,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _setCaret(int offset, {bool rememberAfter = true}) {
    widget.caret.suppressSnapOnce();
    if (rememberAfter) widget.caret.forceAfterOnce(offset);

    widget.controller.selection = TextSelection.collapsed(offset: offset);
    widget.caret.neutralizeDirection();

    if (!widget.focusNode.hasFocus) {
      // ❗️ Request focus after the frame to avoid down/up desync
      _postFrame(() => widget.focusNode.requestFocus());
    }

    _nudgeCursorPaint();

    _postFrame(() {
      if (mounted) widget.caret.onSelectionChanged();
    });
  }

  void _resetInnerScrollToTop() {
    if (!_editScrollCtrl.hasClients) return;
    if (_editScrollCtrl.offset != 0.0) {
      _editScrollCtrl.jumpTo(0.0);
    }
  }

  Rect? _safeCaretRect(RenderEditable re, int offset, {String where = ''}) {
    try {
      return re.getLocalRectForCaret(TextPosition(offset: offset));
    } catch (_) {
      return null;
    }
  }

  /// Ensure selection is valid before inserting a block.
  void _ensureValidSelectionForInsert() {
    final len = widget.controller.text.length;
    final sel = widget.controller.selection;
    if (!sel.isValid || sel.baseOffset < 0 || sel.baseOffset > len) {
      widget.controller.selection = TextSelection.collapsed(offset: len);
    }
    if (!widget.focusNode.hasFocus) {
      _postFrame(() => widget.focusNode.requestFocus());
    }
  }

  /// Measure actual painted lines from content only (no container height).
  int? _measureVisualLines() {
    final st = _editableKey.currentState;
    if (st == null) return null;
    final re = st.renderEditable;

    final double stride = re.preferredLineHeight > 0
        ? re.preferredLineHeight
        : _currentStride;

    double maxBottom = 0.0;

    // 1) Last text line bottom
    final int eol = widget.controller.text.length;
    final eolRect = _safeCaretRect(re, eol, where: 'measure.eol');
    if (eolRect != null) {
      maxBottom = eolRect.bottom;
    }

    // 2) Engine frags if any
    final ranges = <String, BlockTextRange>{
      for (final b in widget.caret.blocks)
        b.stableId: BlockTextRange(b.start, b.end),
    };
    if (ranges.isNotEmpty) {
      final engineFrags = _fragComputer.computeFromRenderEditable(
        renderEditable: re,
        blockRanges: ranges,
      );
      for (final f in engineFrags) {
        if (f.rect.bottom > maxBottom) maxBottom = f.rect.bottom;
      }
    }

    // 3) Synthetic tails
    for (int li = 0; li < 2048; li++) {
      final frags = _fragCache.forLine(li);
      if (frags.isEmpty) break;
      for (final f in frags) {
        if (f.rect.bottom > maxBottom) maxBottom = f.rect.bottom;
      }
    }

    if (maxBottom <= 0.0) maxBottom = stride;
    final lines = math.max(1, (maxBottom / stride).ceil());
    return lines;
  }

  void _reportActualLinesPostFrame({bool force = false}) {
    if (widget.onReportVisualLines == null) return;

    _postFrame(() {
      final lines = _measureVisualLines();
      if (lines == null) return;

      if (!force && _lastReportedLines != null && _lastReportedLines == lines) {
        return;
      }

      _lastReportedLines = lines;

      final st2 = _editableKey.currentState;
      final double stride =
          (st2 != null && st2.renderEditable.preferredLineHeight > 0)
          ? st2.renderEditable.preferredLineHeight
          : _currentStride;

      EditorLayout.setMeasuredStride(stride);
      widget.onReportVisualLines!.call(widget.index, lines, stride);
    });
  }

  void _reportLinesAfterFrames(int frames) {
    if (widget.onReportVisualLines == null) return;
    if (_reportScheduled) return; // debounce
    _reportScheduled = true;

    void chain(int remaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _reportScheduled = false;
          return;
        }
        if (remaining > 1) {
          chain(remaining - 1);
        } else {
          final lines = _measureVisualLines();
          _reportScheduled = false;
          if (lines == null) return;
          if (_lastReportedLines != null && _lastReportedLines == lines) {
            return;
          }
          _lastReportedLines = lines;

          final st2 = _editableKey.currentState;
          final double stride =
              (st2 != null && st2.renderEditable.preferredLineHeight > 0)
              ? st2.renderEditable.preferredLineHeight
              : _currentStride;

          EditorLayout.setMeasuredStride(stride);
          widget.onReportVisualLines!.call(widget.index, lines, stride);
        }
      });
    }

    chain(frames);
  }

  /// Do both in the correct order on the next frame.
  void _recomputeThenReportPostFrame({bool force = false}) {
    _postFrame(() {
      if (!mounted) return;
      _recomputeFragmentsNow();
      if (mounted) setState(() {});
      _reportActualLinesPostFrame(force: force);
      _reportLinesAfterFrames(2);
    });
  }

  String _blockId(model.TextBlock b) => b.stableId;

  void _recomputeFragmentsNow() {
    final st = _editableKey.currentState;
    if (st == null) return;

    // 1) Ranges
    final ranges = <String, BlockTextRange>{
      for (final b in widget.caret.blocks)
        _blockId(b): BlockTextRange(b.start, b.end),
    };

    if (ranges.isEmpty) {
      _fragCache.clear();
      _headLocalRects.clear();
      widget.controller.setHeadWidthCaps(const {});
      _headCaps = const {};
      _fragEpoch++;
      return;
    }

    // 2) Measure heads (min pill widths)
    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: EditorLayout.fontSize,
    );

    final minHeadWidths = <String, double>{};
    for (final b in widget.caret.blocks) {
      final handler = BlockRegistry.instance.handlerFor(b.type);
      final w = handler is MeasurableBlockHandler
          ? handler.measureMinWidth(
              context: context,
              block: b,
              baseStyle: baseStyle,
            )
          : EditorLayout.fontSize * 8.0;
      minHeadWidths[_blockId(b)] = w;
    }

    // 3) Build fragments on OUR row grid — synthetic only for WidgetSpans.
    final stRE = st.renderEditable;

    _currentStride = stRE.preferredLineHeight > 0
        ? stRE.preferredLineHeight
        : _currentStride;

    final double lineStride = _currentStride;
    final double paragraphWidth = stRE.size.width;

    // Provide label text + style so the fragmenter can slice by characters.
    final Map<String, String> labelsForBlocks = {
      for (final b in widget.caret.blocks) _blockId(b): b.label,
    };
    const TextStyle labelMeasureStyle = EntendreVisuals.labelTextStyle;

    // Reserve gap+seed for right input when focused or non-empty
    final Map<String, double> headRightReserves = {
      for (final b in widget.caret.blocks)
        _blockId(
          b,
        ): (_rightActive.contains(_blockId(b)) || b.postText.isNotEmpty)
            ? (EntendreVisuals.gap + EntendreVisuals.rightSeedWidth)
            : 0.0,
    };

    // 🔁 UPDATED: head/tail inner H padding pulled from EntendreVisuals
    final List<BlockFragment> frags = _fragComputer
        .computeSyntheticFromMeasurements(
          renderEditable: stRE,
          blockRanges: ranges,
          blockPixelWidths: minHeadWidths,
          lineStride: lineStride,
          paragraphWidth: paragraphWidth,
          firstLineLeftPad: EntendreVisuals.firstLineLeftPadPx,
          tailLeftPad: 0.25,
          tailRightInsetOnLast: -BlockFragmentComputer.wrapEps,
          headRightSafety: EntendreVisuals.headRightSafety,
          blockLabels: labelsForBlocks,
          labelTextStyle: labelMeasureStyle,
          // MUST match EntendreHandler & _TailPainter:
          headInnerHPad:
              EntendreVisuals.pillPad.horizontal +
              EntendreVisuals.headTextExtraLeftPad +
              EntendreVisuals.headTextExtraRightPad +
              EntendreVisuals.headEndcapPx,
          tailInnerHPad:
              EntendreVisuals.pillPad.horizontal +
              EntendreVisuals.headTextExtraLeftPad +
              EntendreVisuals.headTextExtraRightPad,
          headRightReserves: headRightReserves,
        );

    // 🔧 prevent stale/ghost fragments when blocks are inserted/removed
    _fragCache
      ..clear()
      ..putAll(frags);

    _fragEpoch++;
    _lastReportedLines = null;

    // 4) Cache head rects (LOCAL) as fallback for opening on tail taps.
    _headLocalRects.clear();
    for (final id in ranges.keys) {
      final heads = _fragCache.forBlock(id);
      if (heads.isNotEmpty) {
        final head = heads.firstWhere(
          (f) => f.isFirstInBlock,
          orElse: () => heads.first,
        );
        _headLocalRects[id] = head.rect;
      }
    }

    // 5) Compute true head width *availability caps* from caret start.
    final caps = <String, double>{};
    for (final entry in ranges.entries) {
      final id = entry.key;
      final range = entry.value;

      final startCaret = _safeCaretRect(stRE, range.start, where: 'cap.start');
      if (startCaret == null) continue;

      final double headLeft =
          startCaret.right + EntendreVisuals.firstLineLeftPadPx;
      final double headAvail =
          (paragraphWidth -
                  headLeft -
                  EntendreVisuals.headRightSafety +
                  BlockFragmentComputer.wrapEps)
              .clamp(0.0, double.infinity);

      caps[id] = headAvail;
    }

    // 6) Decide actual head face widths (cap if tails, min if head-only)
    final Map<String, double> headWidthsForFace = <String, double>{};
    for (final id in ranges.keys) {
      final blockFrags = _fragCache.forBlock(id);
      final bool hasTail = blockFrags.any((f) => !f.isFirstInBlock);
      final double cap = caps[id] ?? double.infinity;
      final double minW = (minHeadWidths[id] ?? 0.0).clamp(0.0, cap);
      headWidthsForFace[id] = hasTail ? cap : minW;
    }

    widget.controller.setHeadWidthCaps(headWidthsForFace);
    _headCaps = caps;

    _reportLinesAfterFrames(2);
  }

  // --- Phase 4: vertical caret snapping over tails --------------------------

  bool _maybeSnapVerticalCaret(LogicalKeyboardKey key) {
    final st = _editableKey.currentState;
    if (st == null) return false;

    final re = st.renderEditable;

    final sel = widget.controller.selection;
    final textLen = widget.controller.text.length;
    final base = sel.baseOffset.clamp(0, textLen);

    final caret = _safeCaretRect(re, base, where: 'snap.base');
    if (caret == null) return false;

    final double stride = _currentStride;
    final double dy = (key == LogicalKeyboardKey.arrowUp) ? -stride : stride;

    final double targetY = ((caret.top + caret.bottom) * 0.5) + dy;
    final double targetX = caret.left;

    const double ySlack = 4.0;

    for (int li = 0; li < 2048; li++) {
      final frags = _fragCache.forLine(li);
      if (frags.isEmpty) continue;

      for (final f in frags) {
        if (f.isFirstInBlock) continue;

        final r = f.rect;
        final verticallyHits =
            targetY >= (r.top - ySlack) && targetY <= (r.bottom + ySlack);
        final horizontallyHits = targetX >= r.left && targetX <= r.right;
        if (!verticallyHits || !horizontallyHits) continue;

        model.TextBlock? block;
        for (final b in widget.caret.blocks) {
          if (_blockId(b) == f.blockId) {
            block = b;
            break;
          }
        }
        if (block == null) continue;

        final mid = (r.left + r.right) * 0.5;
        final int edge = (targetX < mid) ? block.start : block.end;

        _setCaret(edge);
        _recomputeThenReportPostFrame();
        return true;
      }
    }

    return false;
  }

  // ---------- Fake caret support (draw at the end of the last tail) ----------

  Rect? _fakeCaretRectIfNeeded() {
    if (_inlineActive || !widget.focusNode.hasFocus) return null;

    final sel = widget.controller.selection;
    if (!sel.isValid || !sel.isCollapsed) return null;

    final int off = sel.baseOffset;

    model.TextBlock? blk;
    for (final b in widget.caret.blocks) {
      if (b.end == off) {
        blk = b;
        break;
      }
    }
    if (blk == null) return null;

    final List<BlockFragment> frags = _fragCache.forBlock(blk.stableId);
    final tails = frags.where((f) => !f.isFirstInBlock).toList();
    if (tails.isEmpty) return null;

    final BlockFragment lastTail = tails.last;
    final double x = lastTail.rect.right;
    final Rect r = Rect.fromLTWH(
      x,
      lastTail.rect.top,
      0.0,
      lastTail.rect.height,
    );
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final int layoutHash = Object.hash(
      widget.controller.text.hashCode,
      widget.controller.selection.baseOffset,
      widget.controller.selection.extentOffset,
      widget.caret.blocks.length,
      _blocksSignature(),
      _inlineActive,
      Object.hashAll(_rightActive),
    );

    if (layoutHash != _lastLayoutTextHash) {
      _lastLayoutTextHash = layoutHash;
      _recomputeThenReportPostFrame();
    }

    final st2 = _editableKey.currentState;
    final double painterStride =
        (st2 != null && st2.renderEditable.preferredLineHeight > 0)
        ? st2.renderEditable.preferredLineHeight
        : _currentStride;

    final Map<String, String> labelsMap = {
      for (final b in widget.caret.blocks) b.stableId: b.label,
    };

    final Rect? fakeCaretRect = _fakeCaretRectIfNeeded();

    return SizedBox(
      height: widget.height,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data == 'entendre',
        onAcceptWithDetails: (details) {
          _absorbPointerOneFrame();
          if (details.data == 'entendre') {
            _ensureValidSelectionForInsert(); // ✅ guard
            _postFrame(
              () => widget.controller.insertBlock(model.BlockType.entendre),
            );
          }
          _postFrame(() {
            _recomputeThenReportPostFrame(force: true);
            _reportLinesAfterFrames(2);
          });
        },
        builder: (_, candidateData, __) {
          final hover = candidateData.isNotEmpty;
          return Container(
            color: hover ? Colors.white12 : Colors.transparent,
            child: NotificationListener<BlocksChangedNotification>(
              onNotification: (n) {
                if (n.barIndex >= 0 && n.barIndex != widget.index) {
                  return false;
                }
                _recomputeThenReportPostFrame(force: true);
                return true;
              },
              child: NotificationListener<InlineBlockGeometryNotification>(
                onNotification: (g) {
                  _headGlobalRects[g.stableId] = g.globalRect;
                  return false;
                },
                child: NotificationListener<InlineBlockFocusNotification>(
                  onNotification: (n) {
                    if (_inlineActive != n.active) {
                      setState(() => _inlineActive = n.active);
                    }
                    widget.caret.setInlineEditActive(n.active);

                    final id = n.block.stableId;
                    final changed = n.active
                        ? _rightActive.add(id)
                        : _rightActive.remove(id);
                    if (changed) {
                      _recomputeThenReportPostFrame();
                    }
                    return false;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: EditorLayout.barVerticalPad,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: EditorLayout.numColumnWidth,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              '${widget.index + 1}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                height: 1,
                              ),
                            ),
                          ),
                        ),

                        // Editable area
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: EditorLayout.textLeftPadding,
                            ),
                            child: SizedBox.expand(
                              child: Focus(
                                canRequestFocus: true,
                                onFocusChange: (hasFocus) {
                                  setState(() {});
                                  _recomputeThenReportPostFrame();

                                  if (!hasFocus && !_inlineActive) {
                                    _postFrame(() {
                                      widget.caret.resetArming();
                                      widget.controller.clearSelection();
                                      widget.controller.value = widget
                                          .controller
                                          .value
                                          .copyWith(
                                            text: widget.controller.text,
                                            selection:
                                                widget.controller.selection,
                                            composing: TextRange.empty,
                                          );
                                      widget.requestRebuild();
                                      widget.onCommitTypingBlur();
                                    });
                                  }
                                },

                                // ⚠️ Important: only act on KeyDown; defer side-effects.
                                onKeyEvent: (node, event) {
                                  // If an inline pill is active, let its handler manage.
                                  if (_inlineActive) {
                                    return KeyEventResult.skipRemainingHandlers;
                                  }

                                  // Ignore all KeyUp/Repeat here to avoid down/up desync.
                                  if (event is KeyUpEvent) {
                                    return KeyEventResult.ignored;
                                  }

                                  if (event is! KeyDownEvent) {
                                    return KeyEventResult.ignored;
                                  }

                                  final k = event.logicalKey;
                                  final isCmd =
                                      HardwareKeyboard.instance.isMetaPressed ||
                                      HardwareKeyboard
                                          .instance
                                          .isControlPressed;
                                  final isAlt =
                                      HardwareKeyboard.instance.isAltPressed;

                                  if (k == LogicalKeyboardKey.backspace) {
                                    // Mark pending work (like merge-up) and handle after the frame.
                                    final sel = widget.controller.selection;
                                    final text = widget.controller.text;
                                    if (sel.isCollapsed && sel.baseOffset > 0) {
                                      final int i = sel.baseOffset;
                                      if (i <= text.length &&
                                          text[i - 1] == '\n') {
                                        _mergeUpPending = true;
                                      }
                                    }
                                    _postFrame(() {
                                      if (!mounted) return;
                                      if (_mergeUpPending) {
                                        _mergeUpPending = false;
                                      }
                                      // Recompute regardless; the field may change.
                                      _recomputeThenReportPostFrame();
                                    });
                                  }

                                  // ⬇️ Let Alt+Arrow bubble to Shortcuts for bar navigation.
                                  if ((k == LogicalKeyboardKey.arrowUp ||
                                          k == LogicalKeyboardKey.arrowDown) &&
                                      isAlt) {
                                    return KeyEventResult.ignored;
                                  }

                                  if (k == LogicalKeyboardKey.arrowUp ||
                                      k == LogicalKeyboardKey.arrowDown) {
                                    if (_maybeSnapVerticalCaret(k)) {
                                      // Do not do more work right now; state already scheduled.
                                      return KeyEventResult.handled;
                                    }
                                  }

                                  if (isCmd &&
                                      (k == LogicalKeyboardKey.keyC ||
                                          k == LogicalKeyboardKey.keyV ||
                                          k == LogicalKeyboardKey.keyX ||
                                          k == LogicalKeyboardKey.keyZ ||
                                          k == LogicalKeyboardKey.keyY ||
                                          k == LogicalKeyboardKey.keyA)) {
                                    return KeyEventResult.ignored;
                                  }

                                  final nav =
                                      k == LogicalKeyboardKey.arrowLeft ||
                                      k == LogicalKeyboardKey.arrowRight ||
                                      k == LogicalKeyboardKey.arrowUp ||
                                      k == LogicalKeyboardKey.arrowDown ||
                                      k == LogicalKeyboardKey.enter ||
                                      k == LogicalKeyboardKey.tab ||
                                      k == LogicalKeyboardKey.escape;
                                  if (nav) {
                                    // Defer any nav-commit side effects too.
                                    _postFrame(widget.onCommitTypingNav);
                                  }

                                  // Pass through to caret manager LAST, but only with KeyDown.
                                  return widget.caret.onKey(
                                    event,
                                    textLength: widget.controller.text.length,
                                  );
                                },
                                child: IgnorePointer(
                                  ignoring: _inlineActive || _absorbOneTap,
                                  child: Stack(
                                    alignment: Alignment.topLeft,
                                    children: [
                                      // 1) GRID (unchanged position)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          ignoring: true,
                                          child: CustomPaint(
                                            painter: _LineGridPainter(
                                              lineHeight: painterStride,
                                              insets: const EdgeInsets.only(
                                                left: 0,
                                                right: 0,
                                                top: 0,
                                                bottom: 0,
                                              ),
                                              color: const Color(0x33B388FF),
                                              strokeWidth: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 2) CONTENT shifted up (tails + editor + caret)
                                      Transform.translate(
                                        offset: const Offset(
                                          0,
                                          -_rowContentLiftPx,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.topLeft,
                                          children: [
                                            // tails overlay BELOW the editor
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                ignoring: true,
                                                child: RepaintBoundary(
                                                  child: _TailOverlay(
                                                    cache: _fragCache,
                                                    selectedIds: widget
                                                        .controller
                                                        .selectedKeys,
                                                    // ✅ Only add when non-null to keep Set<String>
                                                    armedIds: {
                                                      if (widget
                                                              .controller
                                                              .armedKey !=
                                                          null)
                                                        widget
                                                            .controller
                                                            .armedKey!,
                                                    },
                                                    stride: painterStride,
                                                    epoch: _fragEpoch,
                                                    labels: labelsMap,
                                                    headRightReserves: {
                                                      for (final b
                                                          in widget
                                                              .caret
                                                              .blocks)
                                                        b.stableId:
                                                            (_rightActive
                                                                    .contains(
                                                                      b.stableId,
                                                                    ) ||
                                                                b
                                                                    .postText
                                                                    .isNotEmpty)
                                                            ? (EntendreVisuals
                                                                      .gap +
                                                                  EntendreVisuals
                                                                      .rightSeedWidth)
                                                            : 0.0,
                                                    },
                                                    headCaps: _headCaps,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Editor ON TOP
                                            Align(
                                              alignment: Alignment.topLeft,
                                              child: EditableText(
                                                key: _editableKey,
                                                controller: widget.controller,
                                                focusNode: widget.focusNode,
                                                scrollController:
                                                    _editScrollCtrl,
                                                scrollPhysics:
                                                    const NeverScrollableScrollPhysics(),
                                                scrollPadding: EdgeInsets.zero,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize:
                                                      EditorLayout.fontSize,
                                                ),
                                                strutStyle: const StrutStyle(
                                                  fontSize:
                                                      EditorLayout.fontSize,
                                                  height: EditorLayout
                                                      .lineHeightMult,
                                                  forceStrutHeight: true,
                                                  leadingDistribution:
                                                      TextLeadingDistribution
                                                          .even,
                                                ),
                                                textHeightBehavior:
                                                    const TextHeightBehavior(
                                                      applyHeightToFirstAscent:
                                                          true,
                                                      applyHeightToLastDescent:
                                                          true,
                                                    ),
                                                cursorColor: Colors.white,
                                                backgroundCursorColor:
                                                    Colors.white24,
                                                cursorHeight:
                                                    EditorLayout.fontSize * 1.2,
                                                keyboardType:
                                                    TextInputType.multiline,
                                                textInputAction:
                                                    TextInputAction.newline,
                                                maxLines: null,
                                                readOnly: false,
                                                enableInteractiveSelection:
                                                    !_inlineActive,
                                                // Hide native cursor when we render a fake caret.
                                                showCursor:
                                                    widget.focusNode.hasFocus &&
                                                    !_inlineActive &&
                                                    fakeCaretRect == null,
                                                paintCursorAboveText: true,
                                                onChanged: (_) {
                                                  widget.requestRebuild();
                                                  _resetInnerScrollToTop();
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback((
                                                        _,
                                                      ) {
                                                        _resetInnerScrollToTop();
                                                      });

                                                  if (_mergeUpPending) {
                                                    _mergeUpPending = false;
                                                    _recomputeThenReportPostFrame(
                                                      force: true,
                                                    );
                                                    _reportLinesAfterFrames(2);
                                                  } else {
                                                    _recomputeThenReportPostFrame();
                                                    _reportLinesAfterFrames(2);
                                                  }
                                                },
                                                onSelectionChanged: (sel, cause) {
                                                  widget.caret
                                                      .onSelectionChanged();
                                                  _recomputeThenReportPostFrame();
                                                },
                                                selectionColor: const Color(
                                                  0x335C6BFF,
                                                ),
                                              ),
                                            ),

                                            // Fake caret overlay ABOVE the editor
                                            if (fakeCaretRect != null)
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  ignoring: true,
                                                  child: _FakeCaretOverlay(
                                                    rect: fakeCaretRect,
                                                    color: Colors.white,
                                                    thickness: 2.0,
                                                    epoch: _fragEpoch,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  int _blocksSignature() {
    final items = widget.caret.blocks.map(
      (b) => Object.hash(
        b.start,
        b.end,
        b.type.index,
        b.currentMeaning,
        Object.hashAll(b.meanings),
        b.label.hashCode,
        b.preText.hashCode,
        b.postText.hashCode,
      ),
    );
    return Object.hashAll(items);
  }
}

// ------- Phase 2 Painter -----------------------------------------------------

class _TailOverlay extends StatelessWidget {
  final BlockFragmentCache cache;
  final Set<String> selectedIds; // kept for compatibility, no longer used
  final Set<String> armedIds; // blocks to render with drop shadow (future)
  final double stride; // measured preferredLineHeight
  final int epoch;

  // label text to render inside tails
  final Map<String, String> labels; // stableId -> label

  // how much width the head reserved for the right field
  final Map<String, double> headRightReserves; // stableId -> px

  // per-block head caps computed from BarRow
  final Map<String, double> headCaps; // stableId -> px

  const _TailOverlay({
    required this.cache,
    required this.selectedIds,
    required this.armedIds,
    required this.stride,
    required this.epoch,
    required this.labels,
    required this.headRightReserves,
    required this.headCaps,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TailPainter(
        cache: cache,
        selectedIds: selectedIds,
        armedIds: armedIds,
        stride: stride,
        epoch: epoch,
        labels: labels,
        headRightReserves: headRightReserves,
        headCaps: headCaps,
      ),
    );
  }
}

// ------- Phase 2 Painter (tails + underline) -------------------------

class _TailPainter extends CustomPainter {
  final BlockFragmentCache cache;
  final Set<String> selectedIds; // not used for paint anymore
  final Set<String> armedIds; // armed blocks get drop shadow later
  final double stride; // measured preferredLineHeight
  final int epoch;

  final Map<String, String> labels; // stableId -> label text
  final Map<String, double> headRightReserves;
  final Map<String, double> headCaps;

  // Keep in sync with handler math
  static const double _uiSyncEps = BlockFragmentComputer.wrapEps;

  // Use the same “extra” inner padding as the head
  static const double _headExtraLeftPad = EntendreVisuals.headTextExtraLeftPad;
  static const double _headExtraRightPad =
      EntendreVisuals.headTextExtraRightPad;

  // Visual right end-cap used by the head pill (include for text fit)
  static const double _headEndcapPx = EntendreVisuals.headEndcapPx;

  // Measure tweaks
  static const double _headTextShrinkPx = 0.0;
  static const double _tailTextGrowPx = 0.0;

  // Underline style for tails (kept in sync with head)
  static const Underline _tailUnderline = Underline(
    dy: 2.5,
    radius: EntendreVisuals.headCornerRadius,
    // color/opacity use defaults; tweak in visuals if needed
  );

  const _TailPainter({
    required this.cache,
    required this.selectedIds,
    required this.armedIds,
    required this.stride,
    required this.epoch,
    required this.labels,
    required this.headRightReserves,
    required this.headCaps,
  });

  int _fitWordSafe(Characters chars, double maxW, TextStyle style) {
    if (!maxW.isFinite || maxW <= 0) return 0;
    final s = chars.toString();
    if (s.isEmpty) return 0;

    final re = RegExp(r'\s+|\S+');
    final tokens = re.allMatches(s).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return 0;

    double wOf(String text) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textWidthBasis: TextWidthBasis.parent,
      )..layout(maxWidth: maxW);
      return tp.didExceedMaxLines ? double.infinity : tp.width;
    }

    int taken = 0;
    String line = '';
    for (final tok in tokens) {
      final cand = line + tok;
      final w = wOf(cand);
      if (w <= maxW) {
        line = cand;
        taken += Characters(tok).length;
        continue;
      }
      if (line.isEmpty) {
        final g = Characters(tok);
        int lo = 0, hi = g.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) >> 1;
          if (wOf(g.take(mid).toString()) <= maxW) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        return lo;
      }
      break;
    }
    return taken;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (cache.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // ---- Tail pill shapes ---------------------------------------------------
    final Paint bgPaint = Paint()..color = Colors.black;
    final Paint outlinePaint = Paint()
      ..color = const Color(0x00000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.0;

    // Must match head
    const labelStyle = EntendreVisuals.labelTextStyle;
    const double cornerR = EntendreVisuals.headCornerRadius;

    // Compute the *same* pill height and vertical centering as the head:
    final double lineStride = stride;
    final double insetTop = EntendreVisuals.headInsetTop;
    final double insetBottom = EntendreVisuals.headInsetBottom;
    final double pillH = math.min(
      lineStride - (insetTop + insetBottom),
      lineStride * EntendreVisuals.headHeightFactor,
    );

    // Base offset that centers the pill within the line band (like head)
    final double bandTopOffset =
        insetTop + ((lineStride - insetTop - insetBottom) - pillH) / 2.0;

    // Extra offset to move the WHOLE tail pill up/down to match head spacing
    final double yNudge = EntendreVisuals.tailAlignYOffsetPx;

    for (final entry in cache.forEachBlock()) {
      final String blockId = entry.key;
      final List<BlockFragment> allFrags = entry.value;
      if (allFrags.isEmpty) continue;

      final String fullLabel = labels[blockId] ?? '';

      // ---------- shared head numbers (also used by text) --------------------
      final Rect headR = allFrags.first.rect;
      final double reserve = headRightReserves[blockId] ?? 0.0;

      // Are we visually at cap on the first line for this block?
      final double capAvail = headCaps[blockId] ?? double.infinity;
      final bool atCap =
          headR.width >= (capAvail - BlockFragmentComputer.wrapEps);

      // Width used by the head’s text (must mirror handler + pill widget)
      // NOTE: add a tiny overscan only when NOT capped to avoid shaving
      // the last glyph without changing wrap decisions.
      final double headInnerW =
          (headR.width -
                  EntendreVisuals.pillPad.horizontal -
                  _headExtraLeftPad -
                  _headExtraRightPad -
                  _headEndcapPx -
                  reserve -
                  _uiSyncEps -
                  _headTextShrinkPx +
                  (atCap ? 0.0 : EntendreVisuals.glyphRightOverscanPx))
              .clamp(0.0, double.infinity);

      // Measure how much of the label actually sits on the head (for tail text).
      Characters remaining = Characters(fullLabel);
      final int headTake = BlockFragmentComputer.countGraphemesThatFitOneLine(
        text: remaining.toString(),
        style: labelStyle,
        maxInnerWidth: headInnerW,
        isCapped: atCap, // keep conservative backoff when capped
      );

      // ===== 1) TAIL PILL SHAPES (actual black pills for tails only) ========
      final tails = allFrags.where((f) => !f.isFirstInBlock).toList();
      final shapePath = Path();

      // Collect tail rects for the underline pass
      final List<Rect> tailRects = <Rect>[];

      for (final f in tails) {
        final Rect base = f.rect;

        final double contentTop = base.top + bandTopOffset + yNudge;
        final Rect shapeRect = Rect.fromLTRB(
          base.left.clamp(0.0, size.width),
          contentTop,
          base.right.clamp(0.0, size.width),
          (contentTop + pillH).clamp(0.0, size.height),
        );

        if (shapeRect.width > 0.5 && shapeRect.height > 0.5) {
          shapePath.addRRect(
            RRect.fromRectAndRadius(shapeRect, Radius.circular(cornerR)),
          );
          tailRects.add(shapeRect);
        }
      }

      if (shapePath.computeMetrics().isNotEmpty) {
        // --- Underline FIRST so the pill sits on top of it ---
        for (final r in tailRects) {
          _tailUnderline.paintPill(canvas, r, clipSize: size);
        }
        // Then fill tails (black pill)
        canvas.drawPath(shapePath, bgPaint);
        if (outlinePaint.color.a > 0.0) {
          canvas.drawPath(shapePath, outlinePaint);
        }
      }

      // ===== 2) CONTINUATION TEXT INSIDE TAILS ===============================
      if (fullLabel.isEmpty || tails.isEmpty) continue;

      if (headTake > 0) remaining = remaining.skip(headTake);

      for (final f in tails) {
        if (remaining.isEmpty) break;

        final Rect base = f.rect;
        final double contentTop = base.top + bandTopOffset + yNudge;

        // Same inner padding as head
        final double padL = EntendreVisuals.pillPad.left + _headExtraLeftPad;
        final double padR = EntendreVisuals.pillPad.right + _headExtraRightPad;

        final Rect textRect = Rect.fromLTRB(
          (base.left + padL).clamp(0.0, size.width),
          contentTop,
          (base.right - padR).clamp(0.0, size.width),
          contentTop + pillH,
        );

        final double measureW = (textRect.width - _uiSyncEps + _tailTextGrowPx)
            .clamp(0.0, double.infinity);

        final int take = _fitWordSafe(remaining, measureW, labelStyle);
        if (take <= 0) continue;

        final String slice = remaining.take(take).toString();

        final tp = TextPainter(
          text: TextSpan(text: slice, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          textWidthBasis: TextWidthBasis.parent,
        )..layout(maxWidth: measureW);

        final double dy =
            textRect.top +
            (textRect.height - tp.height) / 2.0 +
            EntendreVisuals.tailTextYOffsetPx;

        final double dx = textRect.left;
        tp.paint(canvas, Offset(dx, dy));

        remaining = remaining.skip(take);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) {
    return old.epoch != epoch ||
        old.cache != cache ||
        (old.stride - stride).abs() > 0.001 ||
        old.labels != labels ||
        old.headRightReserves != headRightReserves ||
        old.headCaps != headCaps ||
        old.armedIds.length != armedIds.length ||
        !old.armedIds.containsAll(armedIds) ||
        !armedIds.containsAll(old.armedIds);
  }
}

// ------- Fake caret painter --------------------------------------------------

class _FakeCaretOverlay extends StatelessWidget {
  final Rect rect; // local coords
  final Color color;
  final double thickness;
  final int epoch;

  const _FakeCaretOverlay({
    required this.rect,
    required this.color,
    required this.thickness,
    required this.epoch,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FakeCaretPainter(
        rect: rect,
        color: color,
        thickness: thickness,
        epoch: epoch,
      ),
    );
  }
}

class _FakeCaretPainter extends CustomPainter {
  final Rect rect;
  final Color color;
  final double thickness;
  final int epoch;

  const _FakeCaretPainter({
    required this.rect,
    required this.color,
    required this.thickness,
    required this.epoch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double x = rect.left.clamp(0.0, size.width - 1.0);
    final double top = rect.top + 2.0;
    final double bottom = rect.bottom - 2.0;

    final Paint p = Paint()
      ..color = color
      ..strokeWidth = thickness;

    canvas.drawLine(Offset(x, top), Offset(x, bottom), p);
  }

  @override
  bool shouldRepaint(covariant _FakeCaretPainter old) {
    return old.epoch != epoch ||
        old.rect != rect ||
        old.color != color ||
        old.thickness != thickness;
  }
}

// ------- Per-line grid painter (debug visual dividers) -----------------------

class _LineGridPainter extends CustomPainter {
  final double lineHeight;
  final EdgeInsets insets;
  final Color color;
  final double strokeWidth;

  const _LineGridPainter({
    required this.lineHeight,
    this.insets = EdgeInsets.zero,
    this.color = const Color(0x33B388FF),
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    final left = insets.left;
    final right = size.width - insets.right;

    for (
      double y = insets.top + lineHeight;
      y <= size.height - insets.bottom + 0.5;
      y += lineHeight
    ) {
      final yy = y.floorToDouble();
      canvas.drawLine(Offset(left, yy), Offset(right, yy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineGridPainter old) =>
      old.lineHeight != lineHeight ||
      old.insets != insets ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
