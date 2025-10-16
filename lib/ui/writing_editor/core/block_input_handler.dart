// block_input_handler.dart
import 'package:flutter/material.dart';

enum ChangeType { none, insertion, deletion }

class InputChange {
  final ChangeType type;
  final int delta;
  final int offset;

  InputChange(this.type, this.delta, this.offset);
}

/// Detects typed vs. deleted chars, and suppresses the extra listener callbacks.
class BlockInputHandler {
  int _suppressCount = 0;
  String _prevText = '';
  int _prevOffset = 0;

  void init(String initialText, int initialOffset) {
    _prevText = initialText;
    _prevOffset = initialOffset;
  }

  /// Call before you programmatically insert.
  void suppressNextInsert() {
    _suppressCount = 2;
  }

  /// Returns true if this listener call should be skipped.
  bool shouldSkip() {
    if (_suppressCount > 0) {
      _suppressCount--;
      return true;
    }
    return false;
  }

  /// Compare new vs. old text & offset to find an insertion or deletion.
  InputChange detectChange(String newText, int newOffset) {
    final delta = newText.length - _prevText.length;
    if (delta > 0 && newOffset == _prevOffset + delta) {
      return InputChange(ChangeType.insertion, delta, newOffset - delta);
    }
    if (delta < 0) {
      return InputChange(ChangeType.deletion, delta, newOffset);
    }
    return InputChange(ChangeType.none, 0, newOffset);
  }

  void commit(String newText, int newOffset) {
    _prevText = newText;
    _prevOffset = newOffset;
  }
}