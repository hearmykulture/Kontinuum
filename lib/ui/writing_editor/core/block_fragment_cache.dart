// lib/ui/writing_editor/core/block_fragment_cache.dart
import 'dart:collection';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'block_fragment.dart';

/// Cache of per-paragraph block fragments. Invalidate on any relayout or text change.
class BlockFragmentCache {
  // Map blockId -> its ordered fragments (first..last)
  final Map<String, List<BlockFragment>> _byBlock = {};
  // Map lineIndex -> all fragments that paint on that line (tails + firsts)
  final Map<int, List<BlockFragment>> _byLine = {};

  bool get isEmpty => _byBlock.isEmpty;

  void clear() {
    _byBlock.clear();
    _byLine.clear();
  }

  /// Rebuild the cache from a flat list of fragments.
  void putAll(Iterable<BlockFragment> frags) {
    clear();

    // 1) Fill block map and collect all frags
    final all = <BlockFragment>[];
    for (final f in frags) {
      _byBlock.putIfAbsent(f.blockId, () => []).add(f);
      all.add(f);
    }

    // Keep stable order inside a block (first..last by vertical then left)
    for (final list in _byBlock.values) {
      list.sort((a, b) {
        final t = a.rect.top.compareTo(b.rect.top);
        return (t != 0) ? t : a.rect.left.compareTo(b.rect.left);
      });
    }

    // 2) Build visual line rows by Y (tolerant)
    const tol = 0.75; // pixel tolerance
    final rows = <double>[]; // sorted unique tops
    int rowIndexFor(double top) {
      for (var i = 0; i < rows.length; i++) {
        if ((rows[i] - top).abs() <= tol) return i;
      }
      rows.add(top);
      rows.sort();
      return rows.indexOf(top);
    }

    // 3) Fill byLine using visual rows
    for (final f in all) {
      final row = rowIndexFor(f.rect.top);
      _byLine.putIfAbsent(row, () => []).add(f);
    }

    // 4) Sort within each visual row left→right
    for (final list in _byLine.values) {
      list.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }
  }

  /// Fragments for a given blockId (may be 1..N lines).
  List<BlockFragment> forBlock(String blockId) =>
      UnmodifiableListView(_byBlock[blockId] ?? const <BlockFragment>[]);

  /// Fragments that appear on a specific visual line index.
  List<BlockFragment> forLine(int lineIndex) =>
      UnmodifiableListView(_byLine[lineIndex] ?? const <BlockFragment>[]);

  /// Iterate blocks safely without exposing internal maps.
  /// Yields (blockId, unmodifiable view of that block's fragments) in insertion order.
  Iterable<MapEntry<String, List<BlockFragment>>> forEachBlock() sync* {
    for (final e in _byBlock.entries) {
      yield MapEntry(e.key, UnmodifiableListView(e.value));
    }
  }
}
