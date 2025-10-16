// caret_snapper.dart
import '../models/text_block.dart';

/// If caret lands inside a block, snaps to nearest edge.
class CaretSnapper {
  static int snap(int offset, List<TextBlock> blocks) {
    for (final b in blocks) {
      if (offset > b.start && offset < b.end) {
        final distStart = offset - b.start;
        final distEnd = b.end - offset;
        return distStart < distEnd ? b.start : b.end;
      }
    }
    return offset;
  }
}
