// lib/ui/writing_editor/core/block_manager.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/text_block.dart';

/// Holds & updates the list of blocks, handling insert/delete/shift.
class BlockManager {
  final List<TextBlock> blocks = [];

  /// Shift *all* blocks to the right by [delta] if they start at or after [insertionPoint].
  void shiftForInsert(int insertionPoint, int delta) {
    if (delta == 0) return;
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.start >= insertionPoint) {
        final shifted = b.copyWith(start: b.start + delta, end: b.end + delta);
        debugPrint("↪️ Shifting block $b → $shifted");
        blocks[i] = shifted;
      }
    }
  }

  /// (OLD API) Kept for backward compatibility.
  void insertPlaceholder(int offset, {String label = 'Entendre'}) {
    debugPrint("➕ Inserting placeholder at $offset");
    shiftForInsert(offset, 1);
    final newBlock = TextBlock(
      start: offset,
      end: offset + 1,
      type: BlockType.entendre,
      meanings: [label, label],
    );
    blocks.add(newBlock);
    debugPrint("✅ Added new block: $newBlock");
  }

  /// (NEW) Insert a fully-formed block and shift others by its visual length.
  void insertBlock(TextBlock block, {required int visualLength}) {
    debugPrint("➕ Inserting ${block.type} at ${block.start}");
    shiftForInsert(block.start, visualLength);
    blocks.add(block);
    debugPrint("✅ Added new block: $block");
  }

  // --- Deletion helpers ------------------------------------------------------

  /// Shift a single position for a deletion of `len` chars at `at`.
  /// Collapses anything inside the deleted range to `at`.
  static int _shiftPosForDelete(int pos, int at, int len) {
    if (len <= 0) return pos; // nothing deleted
    final delStart = at;
    final delEnd = at + len; // exclusive

    if (pos >= delEnd) return pos - len; // after range
    if (pos >= delStart && pos < delEnd) return at; // inside range
    return pos; // before range
  }

  /// Delete text and update blocks accordingly.
  ///
  /// `delta` is negative. The deleted text range is `[deletionPoint + delta, deletionPoint)`.
  /// - Removes any block whose placeholder fell entirely within the deleted range.
  /// - Safely shifts edges of remaining blocks using grapheme-safe rules.
  void handleDeletion(int deletionPoint, int delta) {
    debugPrint("🗑️ Handling deletion of ${-delta} chars at $deletionPoint");
    if (delta >= 0) return; // not a deletion

    // Deleted text occupies [delStart, delEnd)
    final int delStart = deletionPoint + delta;
    final int delEnd = deletionPoint;
    final int len = delEnd - delStart; // positive

    // Remove blocks wholly inside the deleted span.
    blocks.removeWhere((b) => b.start >= delStart && b.end <= delEnd);

    // Shift/clip remaining blocks safely.
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];

      int ns = _shiftPosForDelete(b.start, delStart, len);
      int ne = _shiftPosForDelete(b.end, delStart, len);

      // Clamp to invariants
      ns = math.max(0, ns);
      ne = math.max(ns + 1, ne); // ensure end > start (non-empty)

      final shifted = b.copyWith(start: ns, end: ne);
      if (shifted.start != b.start || shifted.end != b.end) {
        debugPrint("↪️ Shifting block $b → $shifted");
      }
      blocks[i] = shifted;
    }
  }
}
