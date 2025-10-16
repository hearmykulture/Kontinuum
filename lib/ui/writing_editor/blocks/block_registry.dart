// lib/ui/writing_editor/blocks/block_registry.dart
import 'package:flutter/foundation.dart' show UniqueKey;

import '../models/text_block.dart';
import 'block_handler.dart';
import 'block_behavior.dart';
import 'block_editor.dart';

class BlockRegistry {
  BlockRegistry._();
  static final BlockRegistry instance = BlockRegistry._();

  final Map<BlockType, BlockHandler> _handlers = {};
  final Map<BlockType, BlockBehavior> _behaviors = {};
  final Map<BlockType, BlockEditor> _editors = {};

  // === Handlers (rendering) ===
  void registerHandler(BlockHandler handler) {
    _handlers[handler.type] = handler;
  }

  BlockHandler? handlerFor(BlockType type) => _handlers[type];

  // === Behaviors (caret/backspace) ===
  void registerBehavior(BlockType type, BlockBehavior behavior) {
    _behaviors[type] = behavior;
  }

  BlockBehavior? behaviorFor(BlockType type) => _behaviors[type];

  // === Editors (popup/inspector UI) ===
  void registerEditor(BlockType type, BlockEditor editor) {
    _editors[type] = editor;
  }

  BlockEditor? editorFor(BlockType type) => _editors[type];

  // ===== Placeholder factory =====

  /// The literal text inserted into the editor for this block type.
  /// Keep to a short glyph (length drives caret math).
  /// NOTE: Simile is deprecated; we fall back to the entendre glyph.
  String placeholderGlyph(BlockType type) {
    switch (type) {
      case BlockType.entendre:
        return '█';
      default: // BlockType.simile (deprecated)
        return '█';
    }
  }

  /// Default meanings/options if none provided by caller.
  /// Entendre only. Simile is deprecated; fall back to an entendre label.
  List<String> defaultMeanings(BlockType type) {
    switch (type) {
      case BlockType.entendre:
        return const ['Entendre', 'Entendre'];
      default: // BlockType.simile (deprecated)
        return const ['Entendre', 'Entendre'];
    }
  }

  /// Build a new TextBlock at [offset] for [type].
  /// NOTE: we assign a persistent `id` so selection/caps survive edits.
  TextBlock createPlaceholderBlock({
    required BlockType type,
    required int offset,
    List<String>? meanings,
  }) {
    final glyph = placeholderGlyph(type);
    final m = meanings ?? defaultMeanings(type);
    return TextBlock(
      id: UniqueKey().toString(), // ← persistent identity
      start: offset,
      end: offset + glyph.length,
      type: type,
      meanings: m,
      currentMeaning: 0,
    );
  }
}
