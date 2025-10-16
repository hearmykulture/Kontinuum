import 'package:flutter/widgets.dart';
import '../models/text_block.dart';
import '../blocks/block_registry.dart';
import 'block_manager.dart';
import 'editor_history.dart';
import 'glyph_scanner.dart';

class PasteRebuilder {
  String? _lastSig;
  DateTime? _lastAt;

  bool _isDup(String sig) {
    final now = DateTime.now();
    if (_lastSig == sig &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(milliseconds: 400)) {
      return true;
    }
    _lastSig = sig;
    _lastAt = now;
    return false;
  }

  /// Rebuilds block objects for any placeholder glyphs in the inserted text,
  /// and pushes **one** history entry covering text+blocks+caret.
  ///
  /// Returns true if blocks were inserted and history was pushed.
  bool apply({
    required int barIdx,
    required BlockManager mgr,
    required TextEditingController ctrl,
    required int insertStart,
    required String insertedText,
    required void Function(HistoryEntry) pushHistory,
    required String textBefore,
    required List<TextBlock> blocksBefore,
    required TextSelection selBefore,
  }) {
    if (insertedText.isEmpty) return false;
    if (_isDup('$barIdx|$insertStart|$insertedText')) return false;

    final hits = GlyphScanner.scanAll(insertedText);
    if (hits.isEmpty) return false;

    // Dedup by absolute offset and skip overlaps with existing same-type blocks.
    final seenAbs = <int>{};
    final toInsert = <({BlockType type, int abs, int len})>[];

    for (final h in hits) {
      final abs = insertStart + h.relOffset;
      if (!seenAbs.add(abs)) continue;

      final exists = mgr.blocks.any((b) {
        if (b.type != h.type) return false;
        final existingLen = BlockRegistry.instance
            .placeholderGlyph(b.type)
            .length;
        final bStart = b.start, bEnd = b.start + existingLen;
        final newStart = abs, newEnd = abs + h.length;
        return !(newEnd <= bStart || bEnd <= newStart); // overlap?
      });
      if (!exists) {
        toInsert.add((type: h.type, abs: abs, len: h.length));
      }
    }

    if (toInsert.isEmpty) return false;

    toInsert.sort((a, b) => a.abs.compareTo(b.abs));
    for (final it in toInsert) {
      final block = BlockRegistry.instance.createPlaceholderBlock(
        type: it.type,
        offset: it.abs,
      );
      mgr.insertBlock(block, visualLength: it.len);
    }

    // AFTER snapshots (TextField has already applied the text change)
    final textAfter = ctrl.text;
    final blocksAfter = mgr.blocks.map((b) => b.copyWith()).toList();
    final selAfter = TextSelection.collapsed(
      offset: insertStart + insertedText.length,
    );

    pushHistory(
      HistoryEntry(
        undo: () {
          // Use value.copyWith to ensure an immediate repaint and preserve composing.
          ctrl.value = ctrl.value.copyWith(
            text: textBefore,
            selection: selBefore,
            composing: ctrl.value.composing,
          );
          mgr.blocks
            ..clear()
            ..addAll(blocksBefore);
        },
        redo: () {
          ctrl.value = ctrl.value.copyWith(
            text: textAfter,
            selection: selAfter,
            composing: ctrl.value.composing,
          );
          mgr.blocks
            ..clear()
            ..addAll(blocksAfter);
        },
      ),
    );

    return true;
  }
}
