// lib/ui/writing_editor/blocks/block_behavior.dart
import 'package:flutter/services.dart';
import '../models/text_block.dart';

abstract class BlockBehavior {
  /// If caret lands inside the block, return the snapped offset (usually start or end).
  /// Return null to allow caret inside.
  int? snapCaret(int rawOffset, TextBlock block);

  /// Handle backspace/delete near/right at the block’s edges.
  /// Return:
  /// - true if you handled it (editor should NOT delete text now),
  /// - false to let the editor do its normal deletion.
  bool onBackspace({
    required bool isSecondHit,
    required int caretOffset,
    required TextBlock block,
    required void Function(TextBlock updated) updateBlock,
    required void Function(TextBlock block) removeBlock,
  }) => false;

  /// Optional: key handling (tab, arrows, etc.)
  bool onKey(RawKeyEvent event, TextBlock block) => false;
}
