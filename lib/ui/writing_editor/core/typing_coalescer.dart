import 'dart:async';
import 'package:flutter/services.dart';
import '../models/text_block.dart' as we;

class TypingSnapshot {
  final String text;
  final List<we.TextBlock> blocks; // pass in clones
  final TextSelection sel;
  const TypingSnapshot({
    required this.text,
    required this.blocks,
    required this.sel,
  });
}

class TypingCoalescer {
  final int barCount;
  final Duration window;
  TypingCoalescer({
    required this.barCount,
    this.window = const Duration(milliseconds: 650),
  }) : _groups = List<_Group?>.filled(barCount, null);

  final List<_Group?> _groups;

  void startOrExtend(
    int i,
    TypingSnapshot current, {
    required void Function(int barIdx) onTimeoutCommit,
  }) {
    final g = _groups[i];
    if (g == null) {
      final ng = _Group(pre: current, post: current);
      _groups[i] = ng..bump(window, () => onTimeoutCommit(i));
    } else {
      g.post = current;
      g.bump(window, () => onTimeoutCommit(i));
    }
  }

  bool commit(
    int i, {
    required void Function(TypingSnapshot pre, TypingSnapshot post) onCommit,
  }) {
    final g = _groups[i];
    if (g == null) return false;

    g.dispose();
    _groups[i] = null;

    final pre = g.pre;
    final post = g.post;

    final changed =
        pre.text != post.text || pre.blocks.length != post.blocks.length;
    if (!changed) return false;

    onCommit(pre, post);
    return true;
  }

  void commitAll({
    required void Function(int i, TypingSnapshot pre, TypingSnapshot post)
    onCommit,
  }) {
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      if (g == null) continue;
      g.dispose();
      _groups[i] = null;

      final pre = g.pre;
      final post = g.post;

      final changed =
          pre.text != post.text || pre.blocks.length != post.blocks.length;
      if (changed) onCommit(i, pre, post);
    }
  }

  void discard(int i) {
    _groups[i]?.dispose();
    _groups[i] = null;
  }
}

class _Group {
  _Group({required this.pre, required this.post});
  final TypingSnapshot pre;
  TypingSnapshot post;
  Timer? _timer;

  void bump(Duration d, void Function() onTimeout) {
    _timer?.cancel();
    _timer = Timer(d, onTimeout);
  }

  void dispose() => _timer?.cancel();
}
