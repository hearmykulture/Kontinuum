// caret_manager.dart  (patched: top-level enum + down-only + post-frame side-effects)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/text_block.dart';
import '../blocks/block_registry.dart';

/// Top-level nav enum (can't be inside a class in Dart)
enum _Nav { left, right }

/// Toggle caret logs here.
const bool _kLogCaret = true;

void _log(String msg) {
  if (_kLogCaret) debugPrint('🧭 Caret • $msg');
}

class CaretManager {
  CaretManager({
    required this.blocks,
    required this.getSelection,
    required this.setSelection,
    required this.requestRebuild,
    required this.removeBlock,
    required this.updateBlock,
    required this.updateArmedVisual,
    required this.onDeleteConfirmed,
    required this.updateSelectedVisual,
    this.notifyGeometryChange,
  });

  // ── wiring ──────────────────────────────────────────────────────────────────
  final List<TextBlock> blocks;
  final TextSelection Function() getSelection;
  final void Function(TextSelection) setSelection;
  final VoidCallback requestRebuild;
  final void Function(TextBlock block) removeBlock;
  final void Function(TextBlock updated) updateBlock;
  final VoidCallback? notifyGeometryChange;

  final void Function(String? armedKey, int armedTick) updateArmedVisual;
  final void Function(Set<String> selectedKeys) updateSelectedVisual;
  final void Function(TextBlock deletedBlock) onDeleteConfirmed;

  // ── inline edit bridge ──────────────────────────────────────────────────────
  bool inlineEditActive = false;
  bool get isInlineEditActive => inlineEditActive;

  void setInlineEditActive(bool active) {
    if (inlineEditActive == active) return;
    inlineEditActive = active;

    if (inlineEditActive) {
      _log('inlineEditActive=TRUE → disarm + suppressNextSnap');
      _suppressNextSnap = true;
      _armedDelete = false;
      _armedKey = null;
      _cancelAutoDisarm();
      _notifyVisuals();
      _notifySelected({});
      requestRebuild();
    }
  }

  void exitInlineEdit() => setInlineEditActive(false);

  void suppressSnapOnce() {
    _log('suppressSnapOnce()');
    _suppressNextSnap = true;
  }

  void forceAfterOnce(int offset) {
    final clamped = _clampOffset(offset);
    _log('forceAfterOnce($offset → $clamped)');
    _forceAfterOnce = clamped;
    _suppressNextSnap = true;
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  bool _inside(TextBlock b, int off) => off > b.start && off < b.end;

  TextBlock? _blockStartingAt(int off) {
    for (final b in blocks) {
      if (b.start == off) return b;
    }
    return null;
  }

  TextBlock? _blockEndingAt(int off) {
    for (final b in blocks) {
      if (b.end == off) return b;
    }
    return null;
  }

  // Nearest block strictly to the left (max b.end < off)
  TextBlock? _nearestBlockLeftOf(int off) {
    TextBlock? best;
    for (final b in blocks) {
      if (b.end < off) {
        if (best == null || b.end > best.end) best = b;
      }
    }
    return best;
  }

  // Nearest block strictly to the right (min b.start > off)
  TextBlock? _nearestBlockRightOf(int off) {
    TextBlock? best;
    for (final b in blocks) {
      if (b.start > off) {
        if (best == null || b.start < best.start) best = b;
      }
    }
    return best;
  }

  Set<String> _keysFor(Iterable<TextBlock> bs) => {
    for (final b in bs) _keyFor(b),
  };

  Set<String> _selectedKeysForSelection(TextSelection sel) {
    if (!sel.isValid) return {};
    if (sel.isCollapsed) {
      final off = _clampOffset(sel.baseOffset);
      for (final b in blocks) {
        if (off == b.start || off == b.end) return {_keyFor(b)};
      }
      return {};
    }

    final a = sel.start <= sel.end ? sel.start : sel.end;
    final bEnd = sel.start <= sel.end ? sel.end : sel.start;
    final keys = <String>{};

    for (final blk in blocks) {
      final overlapStart = (a > blk.start) ? a : blk.start;
      final overlapEnd = (bEnd < blk.end) ? bEnd : blk.end;
      final overlap = overlapEnd - overlapStart;
      final edgeTouch = (a == blk.end) || (bEnd == blk.start);
      if (overlap > 0 || edgeTouch) {
        keys.add(_keyFor(blk));
      }
    }
    return keys;
  }

  void _primeSelectionIndicatorForShift({
    required bool toRight,
    required int textLength,
  }) {
    _lastKnownTextLength = textLength;

    final sel = getSelection();
    if (!sel.isValid) return;

    final primed = _selectedKeysForSelection(sel);

    if (primed.isEmpty) {
      final off = sel.extentOffset.clamp(0, textLength);
      final leftBlock = _blockEndingAt(off);
      final rightBlock = _blockStartingAt(off);
      final candidate = toRight
          ? (rightBlock ?? leftBlock)
          : (leftBlock ?? rightBlock);
      if (candidate != null) primed.add(_keyFor(candidate));
    }

    _log('primeSelectionForShift(toRight=$toRight) → ${primed.join(",")}');
    _notifySelected(primed);
    requestRebuild();
  }

  void _primeSelectionIndicatorForSelectAll({required int textLength}) {
    _lastKnownTextLength = textLength;

    if (blocks.isEmpty) {
      _log('primeSelectionForSelectAll → none (no blocks)');
      _notifySelected({});
      requestRebuild();
      return;
    }
    final all = _keysFor(blocks);
    _log('primeSelectionForSelectAll → ${all.join(",")}');
    _notifySelected(all);
    requestRebuild();
  }

  // ── state ──────────────────────────────────────────────────────────────────
  String? _armedKey;
  bool _armedDelete = false;
  int _shakeToken = 0;
  bool _suppressNextSnap = false;
  bool _handlingBackspace = false;
  Timer? _disarmTimer;
  int _lastHorizDir = 0;

  Set<String> _selectedKeys = {};
  int? _forceAfterOnce;

  static const int _stickyZone =
      1; // characters of “proximity” for left/right snaps

  // We don't own the controller, so we cache the last length the host told us.
  int _lastKnownTextLength = 0;

  String _keyFor(TextBlock b) => b.stableId;

  void _notifyVisuals() => updateArmedVisual(_armedKey, _shakeToken);
  void _notifySelected(Set<String> ks) {
    _selectedKeys = ks;
    updateSelectedVisual(_selectedKeys);
  }

  void _scheduleAutoDisarm({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    _disarmTimer?.cancel();
    _disarmTimer = Timer(delay, () {
      final sel = getSelection();
      if (_armedDelete && _armedKey != null && sel.isCollapsed) {
        _log('autoDisarm → clearing armedKey=$_armedKey');
        _armedDelete = false;
        _armedKey = null;
        _notifyVisuals();
        requestRebuild();
      }
    });
  }

  void _cancelAutoDisarm() {
    if (_disarmTimer != null) _log('cancelAutoDisarm');
    _disarmTimer?.cancel();
    _disarmTimer = null;
  }

  void resetArming() {
    _log('resetArming()');
    _armedDelete = false;
    _armedKey = null;
    _suppressNextSnap = false;
    _forceAfterOnce = null;
    _lastHorizDir = 0;
    _cancelAutoDisarm();
    _notifyVisuals();
    _notifySelected({});
  }

  // Clamp helper using our best knowledge of current text length.
  int _clampOffset(int target) {
    final len = _lastKnownTextLength;
    if (target < 0) return 0;
    if (target > len) return len;
    return target;
  }

  // Unified setter with logs (now clamps + defensive fallback).
  void _setCollapsed(int target, {String why = ''}) {
    final wanted = target;
    final clamped = _clampOffset(wanted);

    final before = getSelection();
    _log(
      'setSelection $why  ${before.baseOffset} → $clamped (req:$wanted len:$_lastKnownTextLength)',
    );
    try {
      setSelection(TextSelection.collapsed(offset: clamped));
    } catch (err) {
      _log('setSelection failed, falling back to 0: $err');
      setSelection(const TextSelection.collapsed(offset: 0));
    }
  }

  // ── selection change ───────────────────────────────────────────────────────
  void onSelectionChanged() {
    final sel = getSelection();
    _log(
      'onSelectionChanged: sel=[${sel.baseOffset},${sel.extentOffset}] '
      'collapsed=${sel.isCollapsed} '
      'armedKey=$_armedKey armedDelete=$_armedDelete '
      'suppressNextSnap=$_suppressNextSnap dir=$_lastHorizDir',
    );

    if (_forceAfterOnce != null && sel.isCollapsed) {
      final want = _forceAfterOnce!;
      _forceAfterOnce = null;
      if (sel.baseOffset != want) {
        _log('forceAfterOnce apply → $want');
        _setCollapsed(want, why: '[forceAfterOnce]');
        return;
      }
    }

    if (inlineEditActive) {
      if (_armedKey != null || _armedDelete) {
        _log('inline edit active → disarm');
        _armedDelete = false;
        _armedKey = null;
        _cancelAutoDisarm();
        _notifyVisuals();
      }
      _notifySelected({});
      return;
    }

    final bool skipSnapThisFrame = _suppressNextSnap;
    _suppressNextSnap = false;

    if (_armedKey != null && !blocks.any((b) => _keyFor(b) == _armedKey)) {
      _log('armedKey $_armedKey no longer present → clearing');
      _armedKey = null;
      _armedDelete = false;
      _cancelAutoDisarm();
      _notifyVisuals();
      requestRebuild();
    }

    if (!sel.isValid) {
      _notifySelected({});
      return;
    }

    final offRaw = sel.baseOffset < 0 ? 0 : sel.baseOffset;
    final off = _clampOffset(offRaw);

    if (_armedKey != null) {
      final stillAtSameEnd = blocks.any(
        (b) => _keyFor(b) == _armedKey && off == b.end,
      );
      if (!stillAtSameEnd) {
        _log('moved away from armed end → disarm');
        _armedKey = null;
        _armedDelete = false;
        _cancelAutoDisarm();
        _notifyVisuals();
        requestRebuild();
      }
    }

    if (!skipSnapThisFrame) {
      for (final b in blocks) {
        final beh = BlockRegistry.instance.behaviorFor(b.type);
        final snap = beh?.snapCaret(off, b);
        if (snap != null && snap != off) {
          _log('beh.snapCaret: off=$off → snap=$snap for ${b.stableId}');
          _suppressNextSnap = true;
          _setCollapsed(snap, why: '[beh.snapCaret]');
          return;
        }
        if (beh == null && off > b.start && off < b.end) {
          final distStart = off - b.start, distEnd = b.end - off;
          final target = distStart < distEnd ? b.start : b.end;
          _log('generic snap inside block ${b.stableId}: $off → $target');
          _suppressNextSnap = true;
          _setCollapsed(target, why: '[generic-inside]');
          return;
        }
      }
    }

    final atStarts = <TextBlock>[];
    final atEnds = <TextBlock>[];
    for (final b in blocks) {
      if (off == b.start) atStarts.add(b);
      if (off == b.end) atEnds.add(b);
    }

    if (atStarts.isNotEmpty || atEnds.isNotEmpty) {
      TextBlock chosen;
      if (atStarts.isNotEmpty && atEnds.isNotEmpty) {
        chosen = (_lastHorizDir >= 0) ? atStarts.first : atEnds.first;
      } else if (atStarts.isNotEmpty) {
        chosen = atStarts.first;
      } else {
        chosen = atEnds.first;
      }
      _log('selection indicator → ${_keyFor(chosen)} at off=$off');
      _notifySelected({_keyFor(chosen)});
      return;
    }

    _notifySelected({});
  }

  // ── deletion ───────────────────────────────────────────────────────────────
  bool _snapOutIfInsideCollapsedCaret(int off) {
    for (final b in blocks) {
      if (_inside(b, off)) {
        final left = off - b.start;
        final right = b.end - off;
        final target = (left <= right) ? b.start : b.end;
        _log('snapOutIfInside: $off → $target for ${b.stableId}');
        _suppressNextSnap = true;
        _setCollapsed(target, why: '[snapOutIfInside]');
        _notifySelected({_keyFor(b)});
        return true;
      }
    }
    return false;
  }

  bool onBackspace() {
    if (inlineEditActive) return false;
    if (_handlingBackspace) return true;
    _handlingBackspace = true;

    try {
      if (blocks.isEmpty) return false;

      final sel = getSelection();
      if (!sel.isValid) return false;

      if (!sel.isCollapsed) {
        _log('backspace on range → let engine delete');
        _armedDelete = false;
        _armedKey = null;
        _cancelAutoDisarm();
        _notifyVisuals();
        _notifySelected({});
        return false;
      }

      final off = _clampOffset(sel.baseOffset < 0 ? 0 : sel.baseOffset);
      _log('onBackspace at $off');

      if (_snapOutIfInsideCollapsedCaret(off)) {
        return true;
      }

      for (final b in blocks) {
        final atStart = off == b.start;
        final atEnd = off == b.end;

        if (atStart && !_armedDelete) {
          _log('arm delete on start of ${b.stableId} → move to end');
          _armedDelete = true;
          _armedKey = _keyFor(b);
          _setCollapsed(b.end, why: '[arm@start]');
          _suppressNextSnap = true;
          _shakeToken++;
          _notifyVisuals();
          _notifySelected({_keyFor(b)});
          WidgetsBinding.instance.addPostFrameCallback((_) => _notifyVisuals());
          _scheduleAutoDisarm();
          return true;
        }

        if (atEnd && !_armedDelete) {
          _log('arm delete on end of ${b.stableId}');
          _armedDelete = true;
          _armedKey = _keyFor(b);
          _shakeToken++;
          _notifyVisuals();
          _notifySelected({_keyFor(b)});
          WidgetsBinding.instance.addPostFrameCallback((_) => _notifyVisuals());
          _suppressNextSnap = true;
          _scheduleAutoDisarm();
          return true;
        }

        if (atEnd && _armedDelete && _armedKey == _keyFor(b)) {
          _log('confirmed delete of ${b.stableId}');
          final beh = BlockRegistry.instance.behaviorFor(b.type);

          if (beh != null) {
            final handled = beh.onBackspace(
              isSecondHit: true,
              caretOffset: off,
              block: b,
              updateBlock: (u) {
                updateBlock(u);
                requestRebuild();
                notifyGeometryChange?.call();
              },
              removeBlock: (x) {
                removeBlock(x);
                requestRebuild();
                notifyGeometryChange?.call();
              },
            );

            if (handled) {
              onDeleteConfirmed(b);
              _armedDelete = false;
              _armedKey = null;
              _cancelAutoDisarm();
              _notifyVisuals();
              _notifySelected({});
              notifyGeometryChange?.call();
              return true;
            }
          }

          // Default removal
          removeBlock(b);
          requestRebuild();
          onDeleteConfirmed(b);
          notifyGeometryChange?.call();

          _armedDelete = false;
          _armedKey = null;
          _cancelAutoDisarm();
          _notifyVisuals();
          _notifySelected({});
          _setCollapsed(b.start, why: '[default-removed]');
          return true;
        }
      }

      _armedDelete = false;
      if (_armedKey != null) {
        _log('backspace → clearing armedKey');
        _armedKey = null;
        _cancelAutoDisarm();
        _notifyVisuals();
      }
      _notifySelected({});
      return false;
    } finally {
      _lastHorizDir = 0;
      _handlingBackspace = false;
    }
  }

  // ── post-frame intent queue (prevents Down/Up desync) ──────────────────────
  bool _pendingBackspace = false;
  _Nav? _pendingNav;
  bool _flushScheduled = false;

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      _flushPending();
    });
  }

  void _flushPending() {
    // Snapshot and clear
    final doBackspace = _pendingBackspace;
    final nav = _pendingNav;
    _pendingBackspace = false;
    _pendingNav = null;

    if (doBackspace) {
      _log('[flush] backspace');
      onBackspace(); // already safe here (post-frame)
    }

    if (nav != null) {
      _log('[flush] nav=$nav');
      switch (nav) {
        case _Nav.left:
          _moveLeft(textLength: _lastKnownTextLength);
          break;
        case _Nav.right:
          _moveRight(textLength: _lastKnownTextLength);
          break;
      }
    }
  }

  // ── key handling (Down-only; everything else is deferred) ──────────────────
  KeyEventResult onKey(KeyEvent event, {required int textLength}) {
    if (inlineEditActive) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Track latest authoritative length from the host.
    _lastKnownTextLength = textLength;

    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final metaOrCtrl =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    final sel = getSelection();
    _log(
      'onKey ${key.keyLabel.isEmpty ? key.debugName : key.keyLabel}'
      ' shift=$shift metaOrCtrl=$metaOrCtrl sel=[${sel.baseOffset},${sel.extentOffset}] len=$_lastKnownTextLength',
    );

    // Visual priming for Shift-extend (let framework handle the selection).
    if (shift &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _primeSelectionIndicatorForShift(
          toRight: key == LogicalKeyboardKey.arrowRight,
          textLength: _lastKnownTextLength,
        );
      });
      return KeyEventResult.ignored;
    }

    if (metaOrCtrl && key == LogicalKeyboardKey.keyA) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _primeSelectionIndicatorForSelectAll(textLength: _lastKnownTextLength);
      });
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.backspace) {
      _pendingBackspace = true;
      _scheduleFlush();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _pendingNav = _Nav.left;
      _scheduleFlush();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _pendingNav = _Nav.right;
      _scheduleFlush();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── nav ops (now called only post-frame via _flushPending) ─────────────────
  bool _moveLeft({required int textLength}) {
    _lastKnownTextLength = textLength;

    final sel = getSelection();
    if (!sel.isValid || !sel.isCollapsed) return false;
    final off = sel.baseOffset.clamp(0, textLength);

    _lastHorizDir = -1;
    _log('← at $off');

    // If exactly at a block end → jump to its start.
    final endsHere = _blockEndingAt(off);
    if (endsHere != null) {
      final target = endsHere.start;
      _armedDelete = false;
      _armedKey = null;
      _cancelAutoDisarm();
      _notifyVisuals();
      _suppressNextSnap = true;
      _setCollapsed(target, why: '[end→start]');
      return true;
    }

    // Sticky zone: if just to the right of a block, jump to that block’s start.
    final left = _nearestBlockLeftOf(off);
    if (left != null && (off - left.end) <= _stickyZone) {
      final target = left.start;
      _armedDelete = false;
      _armedKey = null;
      _cancelAutoDisarm();
      _notifyVisuals();
      _suppressNextSnap = true;
      _setCollapsed(target, why: '[sticky-left]');
      return true;
    }

    // Inside a block (fallback)
    for (final b in blocks) {
      if (_inside(b, off) || off == b.end) {
        final target = b.start;
        _armedDelete = false;
        _armedKey = null;
        _cancelAutoDisarm();
        _notifyVisuals();
        _suppressNextSnap = true;
        _setCollapsed(target, why: '[inside→start]');
        return true;
      }
    }
    _log('← no-op');
    return false;
  }

  bool _moveRight({required int textLength}) {
    _lastKnownTextLength = textLength;

    final sel = getSelection();
    if (!sel.isValid || !sel.isCollapsed) return false;
    final off = sel.baseOffset.clamp(0, textLength);

    _lastHorizDir = 1;
    _log('→ at $off');

    // If we are already at a block end, just consume to avoid engine oddities.
    final endsHere = _blockEndingAt(off);
    if (endsHere != null) {
      _armedDelete = false;
      _armedKey = null;
      _cancelAutoDisarm();
      _notifyVisuals();
      _log('→ consumed at block end (${endsHere.stableId})');
      return true;
    }

    // If exactly at a block start → jump to its end.
    final startsHere = _blockStartingAt(off);
    if (startsHere != null) {
      final target = startsHere.end;
      _armedDelete = false;
      _armedKey = null;
      _cancelAutoDisarm();
      _notifyVisuals();
      _suppressNextSnap = true;
      _setCollapsed(target, why: '[start→end]');
      return true;
    }

    // Sticky zone: if just to the left of a block, jump to that block’s end.
    final right = _nearestBlockRightOf(off);
    if (right != null && (right.start - off) <= _stickyZone) {
      final target = right.end;
      _armedDelete = false;
      _armedKey = null;
      _cancelAutoDisarm();
      _notifyVisuals();
      _suppressNextSnap = true;
      _setCollapsed(target, why: '[sticky-right]');
      return true;
    }

    // Inside a block (fallback)
    for (final b in blocks) {
      if (_inside(b, off) || off == b.start) {
        final target = b.end;
        _armedDelete = false;
        _armedKey = null;
        _cancelAutoDisarm();
        _notifyVisuals();
        _suppressNextSnap = true;
        _setCollapsed(target, why: '[inside→end]');
        return true;
      }
    }
    _log('→ no-op');
    return false;
  }

  void neutralizeDirection() {
    _lastHorizDir = 0;
  }
}
