// lib/ui/writing_editor/models/text_block.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

enum BlockType { entendre, simile }

class TextBlock {
  /// Absolute offsets in the paragraph text (end is exclusive).
  final int start;
  final int end;

  final BlockType type;

  /// Optional persistent identity separate from offsets.
  /// Use this when you want a key that survives edits/relayout.
  final String? id;

  /// Entendre: alternate readings.
  /// Simile: comparator options (e.g., "like", "as", ...).
  final List<String> meanings;

  /// Index into meanings.
  final int currentMeaning;

  /// NEW (Simile): text before and after the comparator (mad-lib style).
  /// For Entendre these are usually empty strings.
  final String preText;
  final String postText;

  TextBlock({
    required this.start,
    required this.end,
    required this.type,
    required this.meanings,
    this.id, // NEW
    this.currentMeaning = 0,
    this.preText = '',
    this.postText = '',
  }) : assert(start >= 0, 'start must be >= 0'),
       assert(end > start, 'end must be > start'),
       assert(currentMeaning >= 0, 'currentMeaning must be >= 0');

  /// The comparator / primary label shown inside the pill.
  String get label {
    if (meanings.isEmpty) return '';
    final i = currentMeaning.clamp(0, meanings.length - 1);
    return meanings[i];
  }

  /// Convenience when you want to preview the full simile text inline.
  /// (Renderer paints its own parts; this is just for utilities/debug.)
  String get composed {
    final left = preText.trim();
    final right = postText.trim();
    final mid = label.trim();
    return [
      if (left.isNotEmpty) left,
      if (mid.isNotEmpty) mid,
      if (right.isNotEmpty) right,
    ].join(' ');
  }

  // Semantic aliases (handy when thinking of Simile as options/selectedIndex).
  List<String> get options => meanings;
  int get selectedIndex => currentMeaning;

  /// Legacy positional key (derived from offsets + type).
  String get key => '${type.name}:$start:$end';

  /// Stable selection/paint id. Prefer this everywhere (e.g., selectedKeys).
  String get stableId => id ?? key;

  bool get isEntendre => type == BlockType.entendre;
  bool get isSimile => type == BlockType.simile;

  int get length => end - start;
  bool containsOffset(int o) => o >= start && o < end;
  bool overlaps(int a, int b) => start < b && end > a;

  TextBlock copyWith({
    int? start,
    int? end,
    BlockType? type,
    String? id, // NEW
    List<String>? meanings,
    int? currentMeaning,
    String? preText,
    String? postText,
  }) {
    // Clamp defensively so we never construct an invalid block.
    final ns = math.max(0, start ?? this.start);
    int ne = end ?? this.end;
    if (ne < ns) ne = ns; // never below start
    if (ne == ns) ne = ns + 1; // keep end > start (non-empty)

    return TextBlock(
      start: ns,
      end: ne,
      type: type ?? this.type,
      id: id ?? this.id, // NEW
      meanings: meanings ?? this.meanings,
      currentMeaning: currentMeaning ?? this.currentMeaning,
      preText: preText ?? this.preText,
      postText: postText ?? this.postText,
    );
  }

  @override
  String toString() =>
      '[$type] "${preText.isNotEmpty ? '$preText ' : ''}$label${postText.isNotEmpty ? ' $postText' : ''}" '
      '@ [$start–$end]${id != null ? ' id=$id' : ''}';

  // Value semantics (keep old behavior: ignore `id` so content equality remains stable).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextBlock &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          type == other.type &&
          listEquals(meanings, other.meanings) &&
          currentMeaning == other.currentMeaning &&
          preText == other.preText &&
          postText == other.postText;

  @override
  int get hashCode => Object.hash(
    start,
    end,
    type,
    Object.hashAll(meanings),
    currentMeaning,
    preText,
    postText,
  );
}
