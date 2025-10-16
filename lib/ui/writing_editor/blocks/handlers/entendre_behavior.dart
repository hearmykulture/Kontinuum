import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // for RawKeyEvent
import 'package:kontinuum/ui/writing_editor/blocks/block_behavior.dart';
import 'package:kontinuum/ui/writing_editor/models/text_block.dart';

class EntendreBehavior implements BlockBehavior {
  @override
  int? snapCaret(int rawOffset, TextBlock b) {
    if (rawOffset > b.start && rawOffset < b.end) {
      final left = rawOffset - b.start;
      final right = b.end - rawOffset;
      return left <= right ? b.start : b.end;
    }
    return null;
  }

  @override
  bool onBackspace({
    required bool isSecondHit,
    required int caretOffset,
    required TextBlock block,
    required void Function(TextBlock updated) updateBlock,
    required void Function(TextBlock block) removeBlock,
  }) {
    if (caretOffset != block.end) return false;

    if (!isSecondHit) {
      if (kDebugMode) {
        // First hit “arms” the delete; underline is handled by selection visuals.
        // No model change here.
        // (Editor triggers redraw; BarRow shows armed underline.)
      }
      return true;
    }

    if (kDebugMode) {
      // Second hit: remove the whole block atomically.
    }
    removeBlock(block);
    return true;
  }

  @override
  bool onKey(RawKeyEvent event, TextBlock block) {
    // No special key handling yet. Return true if you consume an event.
    return false;
  }
}
