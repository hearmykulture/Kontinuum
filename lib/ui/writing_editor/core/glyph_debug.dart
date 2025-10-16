// lib/ui/writing_editor/core/glyph_debug.dart
import 'package:flutter/foundation.dart';
import 'glyph_scanner.dart';
import '../models/text_block.dart' as we;

class GlyphDebug {
  static const bool enabled = true; // ← flip to false to silence

  static bool _hasGlyphs(String s) {
    for (final g in GlyphScanner.glyphMap().values) {
      if (g.isNotEmpty && s.contains(g)) return true;
    }
    return false;
  }

  static String stripAll(String s, {String? tag}) {
    var out = s;
    for (final g in GlyphScanner.glyphMap().values) {
      if (g.isNotEmpty) out = out.replaceAll(g, '');
    }
    if (enabled && out != s) {
      debugPrint(
        '🧽 [GlyphDebug] Stripped glyphs${tag != null ? " <$tag>" : ""}: '
        '"${_preview(s)}" → "${_preview(out)}"',
      );
    }
    return out;
  }

  static void logScan({
    required String src,
    required String text,
    List<we.TextBlock>? blocks,
  }) {
    if (!enabled) return;
    final hits = GlyphScanner.scanAll(text);
    if (hits.isEmpty) return;

    debugPrint(
      '🔎 [GlyphDebug/$src] ${hits.length} glyph hit(s) in buffer len=${text.length}',
    );
    for (final h in hits) {
      final snippet = _snippet(text, h.relOffset, h.length);
      final insideBlock =
          blocks?.any(
            (b) => h.relOffset >= b.start && (h.relOffset + h.length) <= b.end,
          ) ??
          false;
      debugPrint(
        ' • ${h.type} @ ${h.relOffset} len=${h.length} '
        '${insideBlock ? "(inside block)" : "⚠️ OUTSIDE block"}  '
        '→ "${_preview(snippet)}"',
      );
    }
  }

  static String _snippet(String s, int off, int len, {int pad = 8}) {
    final start = (off - pad) < 0 ? 0 : off - pad;
    final end = (off + len + pad) > s.length ? s.length : off + len + pad;
    return s.substring(start, end);
  }

  static String _preview(String s, {int max = 60}) {
    final clean = s.replaceAll('\n', '⏎');
    return clean.length <= max ? clean : '${clean.substring(0, max)}…';
  }
}
