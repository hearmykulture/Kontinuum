import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';

import 'blocks/block_registry.dart';
import 'core/block_input_handler.dart';
import 'core/block_manager.dart';
import 'core/block_text_controller.dart';
import 'core/caret_manager.dart';
import 'core/editor_layout.dart';
import 'core/glyph_scanner.dart';
import 'core/meaning_flipper.dart';
import 'core/paste_rebuilder.dart';
import 'core/typing_coalescer.dart';
import 'models/text_block.dart' as we; // we.TextBlock, we.BlockType
import 'widgets/bar_bench.dart';
import 'widgets/bar_row.dart';
import 'widgets/editor_header.dart';
import 'package:kontinuum/ui/writing_editor/core/editor_history.dart';

// ⬇️ NEW: notify rows when blocks change so tails/lines recompute immediately
import 'blocks/block_handler.dart' show BlocksChangedNotification;

// ⬇️ NEW: keep soft line-wrap estimate in sync with fragmenter epsilon
import 'core/block_fragment_computer.dart' show BlockFragmentComputer;

class NextBarIntent extends Intent {
  const NextBarIntent();
}

class PreviousBarIntent extends Intent {
  const PreviousBarIntent();
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class BlockTextEditor extends StatefulWidget {
  const BlockTextEditor({
    super.key,
    this.onLoadBeat,
    this.isLoadingBeat = false,
  });
  final VoidCallback? onLoadBeat;
  final bool isLoadingBeat;

  @override
  State<BlockTextEditor> createState() => _BlockTextEditorState();
}

class _BlockTextEditorState extends State<BlockTextEditor> {
  // === Core editor state ===
  static const int barCount = 16;
  static const _coalesceWindow = Duration(milliseconds: 650);

  final EditorHistory _history = EditorHistory();

  final List<BlockInputHandler> _inputHandlers = List.generate(
    barCount,
    (_) => BlockInputHandler(),
  );
  final List<BlockManager> _barManagers = List.generate(
    barCount,
    (_) => BlockManager(),
  );

  late final List<BlockTextController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<String> _prevTexts;
  late final List<TextSelection?> _prevSels;

  late final List<CaretManager> _carets;
  late final PasteRebuilder _paste;
  late final TypingCoalescer _coalescer;

  // background timers / effects
  late final Timer _meaningFlipper;

  // Rich-copy recency
  String? _lastRichCopiedText;
  DateTime? _lastRichCopiedAt;

  // Live actual line counts reported by BarRow → RenderEditable
  late final List<int> _actualLines;

  // NEW: live per-row baseline→baseline stride from RenderEditable
  late final List<double> _rowStrides;

  StrutStyle get _lineStrut => const StrutStyle(
    fontSize: EditorLayout.fontSize,
    height: EditorLayout.lineHeightMult,
    forceStrutHeight: true,
    leadingDistribution: TextLeadingDistribution.even,
  );

  @override
  void initState() {
    super.initState();

    _paste = PasteRebuilder();
    _coalescer = TypingCoalescer(barCount: barCount, window: _coalesceWindow);

    _focusNodes = List.generate(barCount, (_) => FocusNode());
    _prevTexts = List.generate(barCount, (_) => '');
    _prevSels = List.generate(
      barCount,
      (_) => const TextSelection.collapsed(offset: 0),
    );

    _actualLines = List.filled(barCount, 1, growable: false);

    final defaultStride = EditorLayout.lineStride();
    _rowStrides = List<double>.filled(barCount, defaultStride, growable: false);

    // Controllers (renderers) per bar
    _controllers = List.generate(barCount, (i) {
      BlockTextController? weak;
      final handler = _inputHandlers[i];

      final ctrl = BlockTextController(
        blockManager: _barManagers[i],
        onTapBlock: (block, rect) {
          final c = weak!;
          c.selectedKeys = {block.stableId};
          c.value = c.value.copyWith(
            text: c.text,
            selection: c.selection,
            composing: c.value.composing,
          );
          if (mounted) setState(() {});
          _showBlockEditor(i, block, sourceRect: rect);
        },
        // Inline updates from inside a pill (Simile typing, etc.)
        onRequestUpdate: (before, after) {
          final mgr = _barManagers[i];

          final idx = mgr.blocks.indexWhere(
            (b) =>
                b.start == before.start &&
                b.end == before.end &&
                b.type == before.type,
          );
          if (idx == -1) return;

          final snapshotSel = _controllers[i].selection;

          _history.push(
            HistoryEntry(
              undo: () {
                mgr.blocks[idx] = before;
                _focusBarAndSetSelection(i, snapshotSel);
                _queueSetState(() {});
                // 🔔 notify this bar’s row to recompute now
                BlocksChangedNotification(barIndex: -1).dispatch(context);
              },
              redo: () {
                mgr.blocks[idx] = after;
                _focusBarAndSetSelection(i, snapshotSel);
                _queueSetState(() {});
                // 🔔
                BlocksChangedNotification(barIndex: -1).dispatch(context);
              },
            ),
          );

          _queueSetState(() {
            mgr.blocks[idx] = after;
            final c = _controllers[i];
            c.value = c.value.copyWith(
              text: c.text,
              selection: c.selection,
              composing: c.value.composing,
            );
            // 🔔 dispatch for immediate recompute
            BlocksChangedNotification(barIndex: i).dispatch(context);
          });
        },
      )..selection = const TextSelection.collapsed(offset: 0);

      ctrl.setBeforeProgrammaticInsert(handler.suppressNextInsert);

      weak = ctrl;

      _inputHandlers[i].init('', 0);
      ctrl.addListener(() => _onBarChanged(i));
      return ctrl;
    });

    _carets = List.generate(barCount, (i) {
      return CaretManager(
        blocks: _barManagers[i].blocks,
        getSelection: () => _controllers[i].selection,
        setSelection: (sel) => _controllers[i].selection = sel,
        requestRebuild: () => setState(() {}),
        removeBlock: (b) {
          final ctrl = _controllers[i];
          final mgr = _barManagers[i];

          // Remove the glyph from the raw text (this will trigger _onBarChanged).
          final glyph = BlockRegistry.instance.placeholderGlyph(b.type);
          final start = b.start;
          final end = b.end; // this is start + glyph.length

          // Remove block from the model first so the soon-firing listener
          // doesn't try to remove it again in handleDeletion.
          mgr.blocks.remove(b);

          // Apply the text edit (delta < 0) — this will invoke _onBarChanged,
          // which will shift subsequent blocks and dispatch BlocksChangedNotification.
          ctrl.text = ctrl.text.replaceRange(start, end, '');
        },

        updateBlock: (u) {
          final idx = _barManagers[i].blocks.indexWhere(
            (x) => x.start == u.start && x.end == u.end && x.type == u.type,
          );
          if (idx >= 0) _barManagers[i].blocks[idx] = u;
        },
        updateArmedVisual: (armedKey, armedTick) {
          final ctrl = _controllers[i];
          ctrl.armedKey = armedKey;
          ctrl.armedTick = armedTick;
          ctrl.value = ctrl.value.copyWith(
            text: ctrl.text,
            selection: ctrl.selection,
            composing: ctrl.value.composing,
          );
          if (mounted) setState(() {});
        },
        onDeleteConfirmed: (deletedBlock) {
          _pushHistoryDelete(i, deletedBlock);
          // 🔔 deleting a block changes fragments immediately
          BlocksChangedNotification(barIndex: i).dispatch(context);
        },
        updateSelectedVisual: (selectedKeys) {
          final ctrl = _controllers[i];
          ctrl.selectedKeys = selectedKeys;
          ctrl.value = ctrl.value.copyWith(
            text: ctrl.text,
            selection: ctrl.selection,
            composing: ctrl.value.composing,
          );
          if (mounted) setState(() {});
        },
        // ⬇️ NEW: ensure behavior-driven inline edits trigger immediate recompute
        notifyGeometryChange: () {
          BlocksChangedNotification(barIndex: i).dispatch(context);
        },
      );
    });

    _meaningFlipper = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _flipMeanings(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCarets());
  }

  @override
  void dispose() {
    _commitAllTyping(reason: 'dispose');
    _meaningFlipper.cancel();
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // === Typing coalescing helpers ===

  List<we.TextBlock> _cloneBlocks(List<we.TextBlock> src) =>
      src.map((b) => b.copyWith()).toList();

  TypingSnapshot _snapshot(int i) => TypingSnapshot(
    text: _controllers[i].text,
    blocks: _cloneBlocks(_barManagers[i].blocks),
    sel: _controllers[i].selection,
  );

  void _startOrExtendTypingGroup(int i) {
    final ctrl = _controllers[i];
    final composing = ctrl.value.composing;
    if (composing.isValid) return;

    _coalescer.startOrExtend(
      i,
      _snapshot(i),
      onTimeoutCommit: (barIdx) {
        _coalescer.commit(
          barIdx,
          onCommit: (pre, post) => _pushTypingHistory(barIdx, pre, post),
        );
      },
    );
  }

  void _commitTypingGroup(int i, {String reason = 'timeout'}) {
    _coalescer.commit(
      i,
      onCommit: (pre, post) => _pushTypingHistory(i, pre, post),
    );
  }

  void _commitAllTyping({String reason = 'global'}) {
    _coalescer.commitAll(
      onCommit: (i, pre, post) => _pushTypingHistory(i, pre, post),
    );
  }

  void _pushTypingHistory(int i, TypingSnapshot pre, TypingSnapshot post) {
    final ctrl = _controllers[i];
    final mgr = _barManagers[i];

    final changed =
        pre.text != post.text || pre.blocks.length != post.blocks.length;
    if (!changed) return;

    _history.push(
      HistoryEntry(
        undo: () {
          _exitInlineEditAll(repaint: false);
          mgr.blocks
            ..clear()
            ..addAll(_cloneBlocks(pre.blocks));
          ctrl.text = pre.text;
          _focusBarAndSetSelection(i, pre.sel, force: true);
          setState(() {});
          // 🔔
          BlocksChangedNotification(barIndex: i).dispatch(context);
        },
        redo: () {
          _exitInlineEditAll(repaint: false);
          mgr.blocks
            ..clear()
            ..addAll(_cloneBlocks(post.blocks));
          ctrl.text = post.text;
          _focusBarAndSetSelection(i, post.sel, force: true);
          setState(() {});
          // 🔔
          BlocksChangedNotification(barIndex: i).dispatch(context);
        },
      ),
    );
  }

  // === Meaning cap helper ===
  List<String> _enforceEntendreMeaningLimit(List<String> inList) {
    final max = EditorLayout.maxEntendreMeaningChars;
    return inList.map((m) => m.characters.take(max).toString()).toList();
  }

  // === Inline exit helpers ===

  void _exitInlineEverywhere() {
    FocusManager.instance.primaryFocus?.unfocus();
    for (final c in _carets) {
      c.setInlineEditActive(false);
    }
    if (mounted) setState(() {});
  }

  void _exitInlineEditAll({bool repaint = true}) {
    bool changed = false;
    for (final c in _carets) {
      if (c.inlineEditActive) {
        c.setInlineEditActive(false);
        changed = true;
      }
    }
    if (changed && repaint && mounted) {
      setState(() {});
    }
  }

  // === Focus / selection helpers ===

  void _focusBarAndSetSelection(
    int barIdx,
    TextSelection sel, {
    bool force = false,
  }) {
    if (barIdx < 0 || barIdx >= barCount) return;
    if (_carets[barIdx].inlineEditActive && !force) return;

    _focusNodes[barIdx].requestFocus();
    final ctrl = _controllers[barIdx];
    ctrl.selection = sel;
    ctrl.value = ctrl.value.copyWith(
      text: ctrl.text,
      selection: sel,
      composing: ctrl.value.composing,
    );
  }

  void _setBlockMeaningIndex({
    required int barIdx,
    required we.TextBlock target,
    required int newIndex,
    bool recordHistory = true,
  }) {
    final mgr = _barManagers[barIdx];
    final ci = mgr.blocks.indexWhere(
      (b) =>
          b.start == target.start &&
          b.end == target.end &&
          b.type == target.type,
    );
    if (ci == -1) return;

    final old = mgr.blocks[ci];
    if (old.currentMeaning == newIndex) return;

    final before = old;
    final after = old.copyWith(currentMeaning: newIndex);

    setState(() {
      mgr.blocks[ci] = after;
    });

    final ctrl = _controllers[barIdx];
    ctrl.value = ctrl.value.copyWith(
      text: ctrl.text,
      selection: ctrl.selection,
      composing: ctrl.value.composing,
    );

    // 🔔 tails/lines may change with a different meaning length
    BlocksChangedNotification(barIndex: barIdx).dispatch(context);

    if (!recordHistory) return;
    final selSnapshot = ctrl.selection;

    _history.push(
      HistoryEntry(
        undo: () {
          _exitInlineEditAll(repaint: false);
          mgr.blocks[ci] = before;
          _focusBarAndSetSelection(barIdx, selSnapshot, force: true);
          setState(() {});
          // 🔔
          BlocksChangedNotification(barIndex: barIdx).dispatch(context);
        },
        redo: () {
          _exitInlineEditAll(repaint: false);
          mgr.blocks[ci] = after;
          _focusBarAndSetSelection(barIdx, selSnapshot, force: true);
          setState(() {});
          // 🔔
          BlocksChangedNotification(barIndex: barIdx).dispatch(context);
        },
      ),
    );
  }

  void _handleUndo() {
    _commitAllTyping(reason: 'undo');
    _exitInlineEditAll(repaint: false);
    if (_history.canUndo) {
      _history.undo();
      _refreshCarets();
    }
  }

  void _handleRedo() {
    _commitAllTyping(reason: 'redo');
    _exitInlineEditAll(repaint: false);
    if (_history.canRedo) {
      _history.redo();
      _refreshCarets();
    }
  }

  void _refreshCarets() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in _carets) {
        c.onSelectionChanged();
      }
    });
  }

  void _pushHistoryDelete(int barIndex, we.TextBlock deletedBlock) {
    final mgr = _barManagers[barIndex];
    final ctrl = _controllers[barIndex];
    final glyph = BlockRegistry.instance.placeholderGlyph(deletedBlock.type);
    final off = deletedBlock.start;
    final selBefore = TextSelection.collapsed(offset: off + glyph.length);
    final selAfter = TextSelection.collapsed(offset: off);

    _history.push(
      HistoryEntry(
        undo: () {
          _exitInlineEditAll(repaint: false);
          mgr.insertBlock(deletedBlock, visualLength: glyph.length);
          ctrl.text = ctrl.text.replaceRange(off, off, glyph);
          _focusBarAndSetSelection(barIndex, selBefore, force: true);
          setState(() {});
          // 🔔
          BlocksChangedNotification(barIndex: barIndex).dispatch(context);
        },
        redo: () {
          _exitInlineEditAll(repaint: false);
          mgr.blocks.remove(deletedBlock);
          ctrl.text = ctrl.text.replaceRange(off, off + glyph.length, '');
          _focusBarAndSetSelection(barIndex, selAfter, force: true);
          setState(() {});
          // 🔔
          BlocksChangedNotification(barIndex: barIndex).dispatch(context);
        },
      ),
    );
  }

  void _flipMeanings() {
    final changed = MeaningFlipper.flipEntendres(_barManagers);
    if (!changed) return;

    setState(() {});
    for (final ctrl in _controllers) {
      ctrl.value = ctrl.value.copyWith(
        text: ctrl.text,
        selection: ctrl.selection,
        composing: ctrl.value.composing,
      );
    }
    // 🔔 flip can change label widths
    BlocksChangedNotification(barIndex: -1).dispatch(context);
  }

  void _moveBarFocus(int delta) {
    _commitAllTyping(reason: 'moveBarFocus');

    final current = _focusNodes.indexWhere((f) => f.hasFocus);
    if (current == -1) return;
    final clamped = (current + delta).clamp(0, barCount - 1);
    final int next = clamped.toInt();
    _focusNodes[next].requestFocus();
    final ctrl = _controllers[next];
    ctrl.selection = TextSelection.collapsed(
      offset: delta > 0 ? 0 : ctrl.text.length,
    );
  }

  Future<void> _showBlockEditor(
    int barIdx,
    we.TextBlock block, {
    Rect? sourceRect,
  }) async {
    final editor = BlockRegistry.instance.editorFor(block.type);
    if (editor == null) return;

    final ctrl = _controllers[barIdx];

    try {
      final result = await editor.show(
        context,
        block: block,
        sourceRect: sourceRect,
      );
      if (result == null) return;

      if (result.delete) {
        final mgr = _barManagers[barIdx];
        final glyph = BlockRegistry.instance.placeholderGlyph(block.type);
        final off = block.start;

        _history.push(
          HistoryEntry(
            undo: () {
              _exitInlineEditAll(repaint: false);
              mgr.insertBlock(block, visualLength: glyph.length);
              ctrl.text = ctrl.text.replaceRange(off, off, glyph);
              _focusBarAndSetSelection(
                barIdx,
                TextSelection.collapsed(offset: off + glyph.length),
                force: true,
              );
              setState(() {});
              // 🔔
              BlocksChangedNotification(barIndex: barIdx).dispatch(context);
            },
            redo: () {
              _exitInlineEditAll(repaint: false);
              mgr.blocks.remove(block);
              ctrl.text = ctrl.text.replaceRange(off, off + glyph.length, '');
              _focusBarAndSetSelection(
                barIdx,
                TextSelection.collapsed(offset: off),
                force: true,
              );
              setState(() {});
              // 🔔
              BlocksChangedNotification(barIndex: barIdx).dispatch(context);
            },
          ),
        );

        setState(() {
          mgr.blocks.remove(block);
          ctrl.text = ctrl.text.replaceRange(off, off + glyph.length, '');
        });
        // 🔔 immediate recompute
        BlocksChangedNotification(barIndex: barIdx).dispatch(context);
        return;
      }

      if (result.updatedBlock != null) {
        final updated = result.updatedBlock!;
        _updateBlockMeanings(barIdx, block, updated.meanings);
        _setBlockMeaningIndex(
          barIdx: barIdx,
          target: updated,
          newIndex: updated.currentMeaning,
          recordHistory: true,
        );
        // 🔔 (redundant, but ensures immediate recompute after modal closes)
        BlocksChangedNotification(barIndex: barIdx).dispatch(context);
      }
    } finally {
      // ensure the visual selection clears after the editor dismisses
      ctrl.selectedKeys = const {};
      ctrl.value = ctrl.value.copyWith(
        text: ctrl.text,
        selection: ctrl.selection,
        composing: ctrl.value.composing,
      );
      if (mounted) setState(() {});
    }
  }

  void _updateBlockMeanings(int barIdx, we.TextBlock oldB, List<String> newM) {
    final mgr = _barManagers[barIdx];
    final ctrl = _controllers[barIdx];

    final idx = mgr.blocks.indexWhere(
      (b) => b.start == oldB.start && b.end == oldB.end && b.type == oldB.type,
    );
    if (idx == -1) return;

    final trimmed = _enforceEntendreMeaningLimit(newM);

    final before = mgr.blocks[idx];
    final after = before.copyWith(meanings: trimmed, currentMeaning: 0);
    final selSnapshot = ctrl.selection;

    setState(() {
      mgr.blocks[idx] = after;
    });
    ctrl.value = ctrl.value.copyWith(
      text: ctrl.text,
      selection: ctrl.selection,
      composing: ctrl.value.composing,
    );

    // 🔔 meanings length affects head min width → recompute tails immediately
    BlocksChangedNotification(barIndex: barIdx).dispatch(context);

    _history.push(
      HistoryEntry(
        undo: () {
          _exitInlineEditAll(repaint: false);
          mgr.blocks[idx] = before;
          _focusBarAndSetSelection(barIdx, selSnapshot, force: true);
          setState(() {});
          // 🔔
          BlocksChangedNotification(barIndex: barIdx).dispatch(context);
        },
        redo: () {
          _exitInlineEditAll(repaint: false);
          mgr.blocks[idx] = after;
          _focusBarAndSetSelection(barIdx, selSnapshot, force: true);
          setState(() {});
          // 🔔
          BlocksChangedNotification(barIndex: barIdx).dispatch(context);
        },
      ),
    );
  }

  // === Change feed from each TextEditingController ===

  void _onBarChanged(int i) {
    final handler = _inputHandlers[i];
    final mgr = _barManagers[i];
    final ctrl = _controllers[i];

    if (_carets[i].inlineEditActive) {
      _prevTexts[i] = ctrl.text;
      _prevSels[i] = ctrl.selection;
      return;
    }

    if (handler.shouldSkip()) {
      _prevTexts[i] = ctrl.text;
      _prevSels[i] = ctrl.selection;
      return;
    }

    final sel = ctrl.selection;
    final composing = ctrl.value.composing;
    final text = ctrl.text;

    if (!sel.isValid || !sel.isCollapsed) {
      final prevText = _prevTexts[i];
      final prevSel = _prevSels[i] ?? const TextSelection.collapsed(offset: 0);

      if (text.length == prevText.length) {
        _commitTypingGroup(i, reason: 'nonCollapsedSelection');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _carets[i].onSelectionChanged();
        });

        _prevTexts[i] = text;
        _prevSels[i] = sel;
        return;
      }

      final start = prevSel.start;
      final end = prevSel.end;
      if (start >= 0 && end >= 0 && end > start) {
        final blocksBefore = _cloneBlocks(mgr.blocks);
        final textBefore = prevText;
        final selBefore = prevSel;

        // fully-contained placeholders inside the selection (for clarity only)
        final removedBlocks = mgr.blocks
            .where((b) => b.start >= start && b.end <= end)
            .map((b) => b.copyWith())
            .toList();

        for (final b in removedBlocks) {
          mgr.blocks.removeWhere(
            (x) => x.start == b.start && x.end == b.end && x.type == b.type,
          );
        }

        // ⬇️ optional: also remove partial overlaps by snapping them out entirely
        mgr.blocks.removeWhere((b) => b.start < end && b.end > start);

        final delta = start - end; // negative
        for (var bi = 0; bi < mgr.blocks.length; bi++) {
          final b = mgr.blocks[bi];
          if (b.start >= end) {
            mgr.blocks[bi] = b.copyWith(
              start: b.start + delta,
              end: b.end + delta,
            );
          }
        }
        setState(() {});

        // 🔔 selection delete changed blocks
        BlocksChangedNotification(barIndex: i).dispatch(context);

        final blocksAfter = _cloneBlocks(mgr.blocks);
        final textAfter = text;
        final selAfter = TextSelection.collapsed(offset: start);

        _history.push(
          HistoryEntry(
            undo: () {
              _exitInlineEditAll(repaint: false);
              ctrl.text = textBefore;
              mgr.blocks
                ..clear()
                ..addAll(blocksBefore);
              _focusBarAndSetSelection(i, selBefore, force: true);
              setState(() {});
              // 🔔
              BlocksChangedNotification(barIndex: i).dispatch(context);
            },
            redo: () {
              _exitInlineEditAll(repaint: false);
              ctrl.text = textAfter;
              mgr.blocks
                ..clear()
                ..addAll(blocksAfter);
              _focusBarAndSetSelection(i, selAfter, force: true);
              setState(() {});
              // 🔔
              BlocksChangedNotification(barIndex: i).dispatch(context);
            },
          ),
        );

        _prevTexts[i] = text;
        _prevSels[i] = sel;
        return;
      }

      _commitTypingGroup(i, reason: 'nonCollapsedSelection');
      _prevTexts[i] = text;
      _prevSels[i] = sel;
      return;
    }

    // Collapsed caret path
    final offset = sel.baseOffset;
    final prevText = _prevTexts[i];
    final prevSel = _prevSels[i];
    final delta = text.length - prevText.length;

    if (delta < 0) {
      mgr.handleDeletion(offset, delta);
      setState(() {});
      // 🔔 deletion shifts blocks
      BlocksChangedNotification(barIndex: i).dispatch(context);
      if (!composing.isValid) _startOrExtendTypingGroup(i);
    } else if (delta > 0 && offset == (prevSel?.baseOffset ?? -1) + 1) {
      // Simple insertion (this includes ENTER → '\n')
      final insertStart = offset - delta;
      final inserted = text.substring(insertStart, insertStart + delta);

      // Shift existing blocks for the text insertion
      mgr.shiftForInsert(insertStart, delta);
      setState(() {});
      // 🔔 insertion shifts blocks
      BlocksChangedNotification(barIndex: i).dispatch(context);

      final glyphHits = GlyphScanner.scanAll(inserted);
      if (glyphHits.isNotEmpty) {
        final textBefore = _prevTexts[i];
        final blocksBefore = _cloneBlocks(mgr.blocks);
        final selBefore =
            _prevSels[i] ?? TextSelection.collapsed(offset: insertStart);

        _paste.apply(
          barIdx: i,
          mgr: mgr,
          ctrl: ctrl,
          insertStart: insertStart,
          insertedText: inserted,
          pushHistory: (e) => _history.push(e),
          textBefore: textBefore,
          blocksBefore: blocksBefore,
          selBefore: selBefore,
        );

        // 🔔 pasted glyphs definitely change fragments
        BlocksChangedNotification(barIndex: i).dispatch(context);
      }

      if (!composing.isValid) _startOrExtendTypingGroup(i);
    } else if (delta != 0) {
      if (delta > 0) {
        final oldSel = _prevSels[i];
        final insertedStart = (oldSel != null)
            ? oldSel.baseOffset
            : (offset - delta);
        final safeStartNum = insertedStart.clamp(0, ctrl.text.length - delta);
        final int safeStart = safeStartNum is int
            ? safeStartNum
            : safeStartNum.toInt();

        final inserted = ctrl.text.substring(safeStart, safeStart + delta);

        mgr.shiftForInsert(safeStart, delta);
        setState(() {});
        // 🔔
        BlocksChangedNotification(barIndex: i).dispatch(context);

        final glyphHits = GlyphScanner.scanAll(inserted);
        if (glyphHits.isNotEmpty) {
          final textBefore = _prevTexts[i];
          final blocksBefore = _cloneBlocks(mgr.blocks);
          final selBefore =
              _prevSels[i] ?? TextSelection.collapsed(offset: safeStart);

          _paste.apply(
            barIdx: i,
            mgr: mgr,
            ctrl: ctrl,
            insertStart: safeStart,
            insertedText: inserted,
            pushHistory: (e) => _history.push(e),
            textBefore: textBefore,
            blocksBefore: blocksBefore,
            selBefore: selBefore,
          );

          // 🔔
          BlocksChangedNotification(barIndex: i).dispatch(context);
        }
      } else {
        mgr.handleDeletion(offset, delta);
        setState(() {});
        // 🔔
        BlocksChangedNotification(barIndex: i).dispatch(context);
      }

      if (!composing.isValid) _startOrExtendTypingGroup(i);
    } else {
      _commitTypingGroup(i, reason: 'pureSelectionMove');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _carets[i].onSelectionChanged();
      });
    }

    _prevTexts[i] = text;
    _prevSels[i] = sel;
  }

  void _handleLoadBeatPressed() {
    _commitAllTyping(reason: 'loadBeat');

    if (widget.onLoadBeat != null) {
      widget.onLoadBeat!.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No onLoadBeat handler provided by parent screen.'),
        ),
      );
    }
  }

  void _handleQuickInsert(String data) {
    _commitAllTyping(reason: 'quickInsert');
    _exitInlineEditAll(repaint: false);

    int barIdx = _focusNodes.indexWhere((f) => f.hasFocus);
    if (barIdx == -1) barIdx = 0;

    final type = (data == 'simile')
        ? we.BlockType.simile
        : we.BlockType.entendre;

    _controllers[barIdx].insertBlock(type);
    setState(() {});
    // 🔔 programmatic insert should recompute immediately
    BlocksChangedNotification(barIndex: barIdx).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    final header = EditorHeader(
      onLoadBeat: _handleLoadBeatPressed,
      isLoadingBeat: widget.isLoadingBeat,
    );

    final body = LayoutBuilder(
      builder: (ctx, constraints) {
        final double bodyHeight = constraints.maxHeight;
        const int totalBars = barCount;

        final double totalDividersHeight =
            EditorLayout.lineThickness * totalBars;

        final double barsAreaHeight = (bodyHeight - totalDividersHeight).clamp(
          0.0,
          double.infinity,
        );

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: totalBars,
          itemBuilder: (ctx, i) {
            final double textColumnWidth =
                constraints.maxWidth -
                EditorLayout.numColumnWidth -
                EditorLayout.textLeftPadding;

            final int measuredLines = _softLineCountForBar(
              context,
              i,
              textColumnWidth,
            );

            final int liveLines = _actualLines[i];
            final int lineCount = (measuredLines > liveLines)
                ? measuredLines
                : liveLines;

            final int visualLines = (lineCount < EditorLayout.minLinesPerBar)
                ? EditorLayout.minLinesPerBar
                : lineCount;

            final double naturalBarHeight =
                (EditorLayout.barVerticalPad * 2) +
                (_rowStrides[i] * visualLines) +
                EditorLayout.rowBottomPad;

            final double rawFill = barsAreaHeight / totalBars;
            final double snappedFill = _snapToStride(
              rawFill,
              EditorLayout.lineStride(),
            );

            final double barHeight = (snappedFill > naturalBarHeight)
                ? snappedFill
                : naturalBarHeight;

            return AnimatedSize(
              key: ValueKey('bar-anim-$i'),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.none,
              child: Column(
                children: [
                  BarRow(
                    index: i,
                    height: barHeight,
                    minLines: visualLines,
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    caret: _carets[i],
                    onCommitTypingNav: () =>
                        _commitTypingGroup(i, reason: 'nav'),
                    onCommitTypingBlur: () =>
                        _commitTypingGroup(i, reason: 'blur'),
                    requestRebuild: () => setState(() {}),
                    onPlainCopied: () {
                      _lastRichCopiedText = null;
                      _lastRichCopiedAt = null;
                    },
                    onRichCopied: (raw) {
                      _lastRichCopiedText = raw;
                      _lastRichCopiedAt = DateTime.now();
                    },
                    exitInlineAll: _exitInlineEverywhere,
                    onReportVisualLines: (barIdx, lines, stride) {
                      if (barIdx < 0 || barIdx >= barCount) return;
                      EditorLayout.setMeasuredStride(stride);

                      final int clamped = lines <= 0 ? 1 : lines;
                      final bool linesChanged = _actualLines[barIdx] != clamped;
                      final bool strideChanged =
                          (_rowStrides[barIdx] - stride).abs() >= 0.001;

                      if (linesChanged || strideChanged) {
                        setState(() {
                          _actualLines[barIdx] = clamped;
                          _rowStrides[barIdx] = stride;
                        });
                      }
                    },
                  ),
                  Divider(
                    height: EditorLayout.lineThickness,
                    thickness: EditorLayout.lineThickness,
                    color: EditorColors.gridLine(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
            const UndoIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ): const RedoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            const UndoIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ): const RedoIntent(),
      },
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              _handleUndo();
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              _handleRedo();
              return null;
            },
          ),
        },
        child: BarBench(
          body: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Column(
                  children: [
                    header,
                    const SizedBox(height: 4),
                    Divider(
                      height: EditorLayout.lineThickness,
                      thickness: EditorLayout.lineThickness,
                      color: EditorColors.gridLine(context),
                    ),
                    Expanded(child: body),
                  ],
                ),
                Positioned(
                  left: EditorLayout.dividerX(),
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: Container(color: EditorColors.margin),
                ),
              ],
            ),
          ),
          onQuickInsert: _handleQuickInsert,
        ),
      ),
    );
  }

  int _softLineCountForBar(BuildContext context, int i, double maxTextWidth) {
    String stripAllGlyphs(String s) {
      var out = s;
      for (final g in GlyphScanner.glyphMap().values) {
        if (g.isNotEmpty) out = out.replaceAll(g, '');
      }
      return out;
    }

    // ⬇️ Use the same epsilon the fragmenter uses, so our soft wrap estimate
    // matches head/tail wrap decisions as closely as possible.
    final double wrapBiasPx = BlockFragmentComputer.wrapEps;

    final double widthForMeasure = (maxTextWidth - wrapBiasPx).clamp(
      1.0,
      double.infinity,
    );

    final raw = _controllers[i].text;
    final textForMeasure = stripAllGlyphs(raw);
    if (textForMeasure.isEmpty) return 1;

    final span = TextSpan(
      text: textForMeasure,
      style: const TextStyle(
        fontSize: EditorLayout.fontSize,
        height: EditorLayout.lineHeightMult,
        color: Colors.white,
      ),
    );

    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: null,
      strutStyle: _lineStrut,
    )..layout(minWidth: 0, maxWidth: widthForMeasure);

    final lines = tp.computeLineMetrics().length;
    return lines <= 0 ? 1 : lines;
  }

  void _queueSetState(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  double _snapToStride(double raw, double strideMeasured) {
    final base =
        (EditorLayout.barVerticalPad * 2) +
        strideMeasured +
        EditorLayout.rowBottomPad;
    return (raw / base).round() * base;
  }
}
