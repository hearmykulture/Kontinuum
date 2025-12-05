import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:kontinuum/core/time/app_clock.dart';
import 'package:kontinuum/models/app_notification.dart';

class NotificationCenterProvider extends ChangeNotifier {
  NotificationCenterProvider(this._box) {
    _loadFromStorage();
  }

  static const String _boxKeyActive = 'active';
  static const String _boxKeyQueued = 'queued';
  static const String _boxKeyQuiet = 'quiet_hours';

  final Box<dynamic> _box;
  final List<NotificationItem> _active = [];
  final List<NotificationItem> _queued = [];
  final Map<String, Timer> _snoozeTimers = {};
  final Uuid _uuid = const Uuid();
  bool _quietHoursEnabled = false;

  List<NotificationItem> get activeNotifications =>
      List.unmodifiable(_active.reversed.toList());
  List<NotificationItem> get queuedNotifications =>
      List.unmodifiable(_queued.reversed.toList());
  bool get quietHoursEnabled => _quietHoursEnabled;

  Map<NotificationModule, List<NotificationItem>>
      groupedActiveNotifications() {
    final Map<NotificationModule, List<NotificationItem>> grouped = {};
    for (final item in activeNotifications) {
      grouped.putIfAbsent(item.module, () => []).add(item);
    }
    return grouped;
  }

  Future<void> add(NotificationItem item) async {
    final target = _shouldQueue(item) ? _queued : _active;
    _insertOrBundle(target, item);
    await _persist();
    notifyListeners();
  }

  Future<void> addAll(Iterable<NotificationItem> items) async {
    for (final item in items) {
      final target = _shouldQueue(item) ? _queued : _active;
      _insertOrBundle(target, item);
    }
    await _persist();
    notifyListeners();
  }

  Future<bool> dismiss(String id) async {
    final beforeActive = _active.length;
    _active.removeWhere((n) => n.id == id);
    final beforeQueued = _queued.length;
    _queued.removeWhere((n) => n.id == id);
    final removed =
        _active.length != beforeActive || _queued.length != beforeQueued;
    if (removed) {
      await _persist();
      notifyListeners();
    }
    _cancelSnooze(id);
    return removed;
  }

  Future<void> clearAll() async {
    _active.clear();
    _queued.clear();
    for (final timer in _snoozeTimers.values) {
      timer.cancel();
    }
    _snoozeTimers.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> clearNonCritical() async {
    _active.removeWhere(
        (n) => n.severity == NotificationSeverity.nonCritical);
    await _persist();
    notifyListeners();
  }

  Future<void> snooze(String id, Duration duration) async {
    final idx = _active.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final item = _active.removeAt(idx);
    await _persist();
    notifyListeners();

    _cancelSnooze(id);
    _snoozeTimers[id] = Timer(duration, () {
      _snoozeTimers.remove(id);
      add(item.copyWith(
        createdAt: AppClock.now(),
      ));
    });
  }

  Future<void> toggleQuietHours(bool enabled) async {
    if (_quietHoursEnabled == enabled) return;
    _quietHoursEnabled = enabled;
    if (enabled) {
      // move non-critical to queued
      final moving = _active
          .where((n) => n.severity == NotificationSeverity.nonCritical)
          .toList();
      _active.removeWhere(
          (n) => n.severity == NotificationSeverity.nonCritical);
      for (final n in moving) {
        _insertOrBundle(_queued, n);
      }
    } else {
      final released = _queued.toList();
      _queued.clear();
      for (final n in released) {
        _insertOrBundle(_active, n);
      }
      if (released.isNotEmpty) {
        final count = released.length;
        final notice = NotificationItem(
          id: _uuid.v4(),
          module: NotificationModule.tasks,
          kind: NotificationKind.taskDueToday,
          title: 'Quiet hours off',
          detail: 'Delivered $count queued alert${count == 1 ? '' : 's'}.',
          meta: 'Now',
          severity: NotificationSeverity.nonCritical,
          createdAt: AppClock.now(),
          actions: const [],
          groupKey: 'quiet_release',
          payload: {'releasedCount': count},
        );
        _insertOrBundle(_active, notice);
      }
    }
    await _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _snoozeTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  // ---------- Helpers ----------
  bool _shouldQueue(NotificationItem item) =>
      _quietHoursEnabled &&
      item.severity == NotificationSeverity.nonCritical;

  void _insertOrBundle(List<NotificationItem> list, NotificationItem item) {
    if (item.groupKey != null) {
      final index = list.indexWhere(
        (n) =>
            n.groupKey == item.groupKey && n.module == item.module,
      );
      if (index != -1) {
        final existing = list[index];
        final mergedPayload = _mergePayloadIds(existing.payload, item.payload);
        final newCount = existing.bundleCount + item.bundleCount;
        list[index] = existing.copyWith(
          title: _formatBundledTitle(item.title, newCount),
          detail: item.detail,
          meta: item.meta ?? existing.meta,
          payload: mergedPayload,
          createdAt: item.createdAt.isAfter(existing.createdAt)
              ? item.createdAt
              : existing.createdAt,
          bundleCount: newCount,
        );
        return;
      }
    }
    list.add(item);
  }

  Map<String, dynamic>? _mergePayloadIds(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    final ids = <String>{};
    void collect(Map<String, dynamic>? source) {
      final raw = source?['ids'];
      if (raw is List) {
        ids.addAll(raw.whereType<String>());
      }
    }

    collect(a);
    collect(b);

    if (ids.isEmpty) return b ?? a;
    final out = <String, dynamic>{};
    out.addAll(a ?? {});
    out.addAll(b ?? {});
    out['ids'] = ids.toList();
    return out;
  }

  String _formatBundledTitle(String base, int count) {
    if (count <= 1) return base;
    final sanitized = base.replaceFirst(RegExp(r'^\d+x?\s+'), '');
    return '${count}x $sanitized';
  }

  Future<void> _loadFromStorage() async {
    _quietHoursEnabled = _box.get(_boxKeyQuiet) as bool? ?? false;
    final rawActive =
        (_box.get(_boxKeyActive) as List?)?.whereType<Map>().toList() ?? [];
    final rawQueued =
        (_box.get(_boxKeyQueued) as List?)?.whereType<Map>().toList() ?? [];

    final now = AppClock.now();
    final activeItems = rawActive
        .map(NotificationItem.fromMap)
        .where((n) => !_isExpired(n, now))
        .toList();
    final queuedItems = rawQueued
        .map(NotificationItem.fromMap)
        .where((n) => !_isExpired(n, now))
        .toList();

    _active
      ..clear()
      ..addAll(activeItems);
    _queued
      ..clear()
      ..addAll(queuedItems);

    notifyListeners();
  }

  Future<void> _persist() async {
    await _box.putAll({
      _boxKeyActive: _active.map((n) => n.toMap()).toList(),
      _boxKeyQueued: _queued.map((n) => n.toMap()).toList(),
      _boxKeyQuiet: _quietHoursEnabled,
    });
  }

  void _cancelSnooze(String id) {
    _snoozeTimers.remove(id)?.cancel();
  }

  bool _isExpired(NotificationItem item, DateTime now) {
    if (item.expiresAt != null && item.expiresAt!.isBefore(now)) {
      return true;
    }
    switch (item.kind) {
      case NotificationKind.eventStartingSoon:
      case NotificationKind.reminderDue:
      case NotificationKind.overlappingEvents:
      case NotificationKind.taskDueToday:
        return item.createdAt.isBefore(now.subtract(const Duration(days: 1)));
      default:
        return false;
    }
  }
}
