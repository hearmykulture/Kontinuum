// lib/ui/writing_editor/core/block_text_controller.dart
import 'dart:ui' show Rect;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals, debugPrint, kDebugMode;

import '../models/text_block.dart';
import '../blocks/block_registry.dart';
import '../blocks/block_handler.dart';
import 'block_manager.dart';
import 'block_text_renderer.dart';

class BlockTextController extends TextEditingController {
  final BlockManager blockManager;

  /// Provides the tapped block AND its screen rect.
  final void Function(TextBlock, Rect) onTapBlock;

  /// Allow handlers to request inline block updates (with history upstream).
  final void Function(TextBlock before, TextBlock after)? onRequestUpdate;

  // Transient visuals (set by CaretManager)
  String? armedKey; // use TextBlock.stableId
  int armedTick = 0;

  /// Which blocks are visually selected right now (stable IDs).
  Set<String> selectedKeys = <String>{};

  /// Per-block head width caps (stableId → px), provided by BarRow after fragment compute.
  Map<String, double> _headWidthCaps = const {};

  // Optional guard so the editor can suppress the next listener tick
  // (pair this with BlockInputHandler.suppressNextInsert).
  VoidCallback? _beforeProgrammaticInsert;
  void setBeforeProgrammaticInsert(VoidCallback? guard) {
    _beforeProgrammaticInsert = guard;
  }

  BlockTextController({
    required this.blockManager,
    required this.onTapBlock,
    this.onRequestUpdate,
    String? initialText,
  }) : super(text: initialText ?? '');

  // --------------------------------------------------------------------------
  // Head width caps from BarRow (measured available px after caret at start)
  // --------------------------------------------------------------------------

  /// Setter for head width caps (called by BarRow after fragment compute).
  void setHeadWidthCaps(Map<String, double> caps) {
    if (mapEquals(_headWidthCaps, caps)) return; // de-dupe
    _headWidthCaps = Map<String, double>.unmodifiable(caps);

    if (kDebugMode) {
      if (caps.isNotEmpty) {
        final preview = caps.entries
            .take(3)
            .map((e) => '${e.key}:${e.value.toStringAsFixed(1)}')
            .join(', ');
        debugPrint(
          '[BlockTextController] setHeadWidthCaps n=${caps.length} {$preview${caps.length > 3 ? ', …' : ''}}',
        );
      } else {
        debugPrint('[BlockTextController] setHeadWidthCaps cleared');
      }
    }

    // Nudge so spans rebuild immediately with new constraints.
    value = value.copyWith(
      text: text,
      selection: selection,
      composing: value.composing,
    );
  }

  /// Convenience accessor for a single cap. Returns `double.infinity` if none.
  double headWidthCapFor(String stableId) =>
      _headWidthCaps[stableId] ?? double.infinity;

  // --------------------------------------------------------------------------
  // Selection helpers (visual-only selection of heads by stableId)
  // --------------------------------------------------------------------------

  bool isSelected(String key) => selectedKeys.contains(key);

  void select(String key) {
    if (selectedKeys.add(key)) {
      value = value.copyWith(
        text: text,
        selection: selection,
        composing: value.composing,
      );
    }
  }

  void deselect(String key) {
    if (selectedKeys.remove(key)) {
      value = value.copyWith(
        text: text,
        selection: selection,
        composing: value.composing,
      );
    }
  }

  /// Clear all visual selection and nudge the renderer to repaint immediately.
  void clearSelection() {
    if (selectedKeys.isEmpty) return;
    selectedKeys = <String>{};
    value = value.copyWith(
      text: text,
      selection: selection,
      composing: value.composing,
    );
  }

  // --------------------------------------------------------------------------
  // Block insertion (single source of truth via BlockRegistry)
  // --------------------------------------------------------------------------

  void insertBlock(
    BlockType type, {
    int? atOffset,
    List<String>? meanings,
    String? preText,
    String? postText,
    bool placeCaretAfter = true,
  }) {
    final reg = BlockRegistry.instance;

    // Resolve insertion point
    final int currentOffset = selection.baseOffset;
    final int offset = (atOffset ?? currentOffset).clamp(0, text.length);

    // Build the TextBlock from the single source of truth
    TextBlock newBlock = reg.createPlaceholderBlock(
      type: type,
      offset: offset,
      meanings: meanings,
    );

    if (type == BlockType.simile) {
      newBlock = newBlock.copyWith(
        preText: preText ?? newBlock.preText,
        postText: postText ?? newBlock.postText,
      );
    }

    // Visual glyph for this type (length drives caret math)
    final String glyph = reg.placeholderGlyph(type);

    _beforeProgrammaticInsert?.call();

    // Atomically update text + selection
    final String newText = text.replaceRange(offset, offset, glyph);
    final newSelection = TextSelection.collapsed(
      offset: placeCaretAfter ? (offset + glyph.length) : offset,
    );

    // Tell the model about the new block (shift others by glyph length)
    blockManager.insertBlock(newBlock, visualLength: glyph.length);

    // Commit to the controller in one value update to avoid flicker
    value = value.copyWith(
      text: newText,
      selection: newSelection,
      composing: value.composing,
    );
  }

  // --------------------------------------------------------------------------
  // Rendering bridge to BlockTextRenderer
  // --------------------------------------------------------------------------

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return BlockTextRenderer.build(
      context,
      text: text,
      blocks: blockManager.blocks,
      onTapBlock: onTapBlock,
      style: style,
      armedKey: armedKey,
      armedTick: armedTick,
      selectedKeys: selectedKeys, // stable IDs
      // forward inline updates to editor
      requestUpdate: onRequestUpdate,
      // provide caps to the renderer (used by EntendreHandler head)
      headWidthCaps: _headWidthCaps,
    );
  }
}
