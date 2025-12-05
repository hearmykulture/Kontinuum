// lib/providers/project_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:kontinuum/models/project_model.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class ProjectProvider extends ChangeNotifier {
  final List<Project> _projects = [];
  final List<Notebook> _notebooks = [];
  bool _notifyScheduled = false;
  bool _disposed = false;

  List<Project> get projects => List.unmodifiable(_projects);
  List<Notebook> get notebooks => List.unmodifiable(_notebooks);

  /// Create a new project. If [silent] is true, listeners won't be notified immediately.
  /// Use [silent] when calling from initState/build to avoid "setState during build" errors.
  Project createProject({String? name, bool silent = false}) {
    final id = AppClock.now().microsecondsSinceEpoch.toString();
    final count = _projects.length + 1;
    final trimmed = name ?? '').trim();
    final project =
        Project(id: id, name: trimmed.isEmpty ? 'Project $count' : trimmed);

    _projects.insert(0, project); // latest first

    if (!silent) _notifySafely();
    return project;
  }

  Project? byId(String id) {
    for (final p in _projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// If [maybeId] exists, return it; otherwise create one *silently* (no rebuild during init).
  Project ensureOrCreate({String? maybeId, String? name}) {
    if (maybeId != null) {
      final found = byId(maybeId);
      if (found != null) return found;
    }
    // Silent to avoid rebuilds during initState/build.
    return createProject(name: name, silent: true);
  }

  void rename(String id, String newName) {
    final p = byId(id);
    if (p == null) return;
    final trimmed = newName.trim();
    p.name = trimmed.isEmpty ? 'Untitled Project' : trimmed;
    _notifySafely();
  }

  void addTrack(String id, String trackName) {
    final p = byId(id);
    if (p == null) return;
    p.tracks.add(trackName);
    _notifySafely();
  }

  void renameTrack(String id, int index, String newName) {
    final p = byId(id);
    if (p == null) return;
    if (index < 0 || index >= p.tracks.length) return;
    p.tracks[index] = newName;
    _notifySafely();
  }

  void delete(String id) {
    _projects.removeWhere((p) => p.id == id);
    _notifySafely();
  }

  /// Manually trigger a safe refresh (e.g., after navigation completes).
  void refresh() => _notifySafely();

  // ===================== NOTEBOOK METHODS =====================

  /// Create a new notebook
  Notebook createNotebook({
    required String title,
    required String icon,
    required int color,
    String? projectId,
    List<String>? tags,
    List<String>? collaborators,
    String? password,
    bool silent = false,
  }) {
    final id = AppClock.now().microsecondsSinceEpoch.toString();
    final notebook = Notebook(
      id: id,
      title: title,
      icon: icon,
      color: color,
      projectId: projectId,
      tags: tags,
      collaborators: collaborators,
      password: password,
    );

    _notebooks.insert(0, notebook); // latest first

    if (!silent) _notifySafely();
    return notebook;
  }

  Notebook? notebookById(String id) {
    for (final n in _notebooks) {
      if (n.id == id) return n;
    }
    return null;
  }

  void reset() {
    _projects.clear();
    _notebooks.clear();
    _notifySafely();
  }

  void deleteNotebook(String id) {
    _notebooks.removeWhere((n) => n.id == id);
    _notifySafely();
  }

  void _notifySafely() {
    if (_disposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;

    // Notify immediately only when safe (idle or already in post-frame callbacks).
    final canNotifyNow = phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks;

    if (canNotifyNow) {
      super.notifyListeners();
      return;
    }

    // Coalesce multiple requests within the same frame.
    if (_notifyScheduled) return;
    _notifyScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) return;
      super.notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
