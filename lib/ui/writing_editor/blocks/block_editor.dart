// lib/ui/writing_editor/blocks/block_editor.dart
import 'dart:ui' show Rect;
import 'package:flutter/material.dart';
import '../models/text_block.dart';

/// Generic result from an editor popup.
class BlockEditResult {
  final bool delete; // request delete
  final TextBlock? updatedBlock; // same range/type; updated fields
  const BlockEditResult({this.delete = false, this.updatedBlock});
}

/// Contract for per-block editor UIs (sheets, dialogs, etc.)
abstract class BlockEditor {
  Future<BlockEditResult?> show(
    BuildContext context, {
    required TextBlock block,

    /// Where the tap happened (pill’s screen rect) if available.
    Rect? sourceRect, // NEW
  });
}
