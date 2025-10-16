class HistoryEntry {
  final void Function() undo;
  final void Function() redo;
  HistoryEntry({required this.undo, required this.redo});
}

class EditorHistory {
  final _undo = <HistoryEntry>[];
  final _redo = <HistoryEntry>[];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void push(HistoryEntry e) {
    _undo.add(e);
    _redo.clear();
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final e = _undo.removeLast();
    e.undo();
    _redo.add(e);
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final e = _redo.removeLast();
    e.redo();
    _undo.add(e);
    return true;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
