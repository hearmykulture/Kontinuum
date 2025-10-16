import '../blocks/block_registry.dart';
import '../models/text_block.dart';

class GlyphHit {
  final BlockType type;
  final int relOffset;
  final int length;
  const GlyphHit(this.type, this.relOffset, this.length);
}

class GlyphScanner {
  static Map<BlockType, String> glyphMap() => {
    for (final t in BlockType.values)
      t: BlockRegistry.instance.placeholderGlyph(t),
  };

  /// Find ALL glyphs (all types) in `chunk`, ordered by offset.
  static List<GlyphHit> scanAll(String chunk) {
    final hits = <GlyphHit>[];
    final glyphs = glyphMap();
    for (final entry in glyphs.entries) {
      final type = entry.key;
      final glyph = entry.value;
      if (glyph.isEmpty) continue;
      var pos = chunk.indexOf(glyph);
      while (pos != -1) {
        hits.add(GlyphHit(type, pos, glyph.length));
        pos = chunk.indexOf(glyph, pos + glyph.length);
      }
    }
    hits.sort((a, b) => a.relOffset.compareTo(b.relOffset));
    return hits;
  }
}
