import '../models/text_block.dart' as we;
import 'block_manager.dart';

/// Utility for flipping meanings on all entendre blocks across multiple bars.
class MeaningFlipper {
  /// Flips the `currentMeaning` index for all [we.BlockType.entendre] blocks
  /// in the given list of [BlockManager]s.
  ///
  /// Returns `true` if at least one block was updated.
  static bool flipEntendres(List<BlockManager> managers) {
    var changed = false;

    for (final mgr in managers) {
      for (var j = 0; j < mgr.blocks.length; j++) {
        final block = mgr.blocks[j];
        if (block.type == we.BlockType.entendre && block.meanings.length == 2) {
          mgr.blocks[j] = block.copyWith(
            currentMeaning: (block.currentMeaning + 1) % 2,
          );
          changed = true;
        }
      }
    }

    return changed;
  }
}
