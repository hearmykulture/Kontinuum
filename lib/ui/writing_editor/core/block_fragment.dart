// lib/ui/writing_editor/core/block_fragment.dart
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show TextSelection;

/// A single visual slice of an inline block (pill) that appears on one text line.
class BlockFragment {
  final String blockId;
  final int lineIndex; // index into TextPainter.computeLineMetrics()
  final Rect rect; // local-to-RichText line coords (not global)
  final bool isFirstInBlock; // first visual line of this block
  final bool isLastInBlock; // last visual line of this block

  const BlockFragment({
    required this.blockId,
    required this.lineIndex,
    required this.rect,
    required this.isFirstInBlock,
    required this.isLastInBlock,
  });

  @override
  String toString() =>
      'Frag($blockId line=$lineIndex rect=$rect first=$isFirstInBlock last=$isLastInBlock)';
}

/// Convenience: the (start, end) text offsets for a block in the paragraph.
@immutable
class BlockTextRange {
  final int start;
  final int end; // exclusive

  const BlockTextRange(this.start, this.end);

  TextSelection toSelection() =>
      TextSelection(baseOffset: start, extentOffset: end);
}
