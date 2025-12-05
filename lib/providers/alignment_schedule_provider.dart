import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kontinuum/core/time/app_clock.dart';

DateTime _stripDate(DateTime date) => DateTime(date.year, date.month, date.day);
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class AlignmentAutoPrompt {
  AlignmentAutoPrompt({
    required this.date,
    required this.index,
    required this.scheduledTime,
  });

  final DateTime date;
  final int index;
  final DateTime scheduledTime;
}

class AlignmentScheduleProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  AlignmentScheduleProvider(this._box) {
    _loadConfig();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    _evaluateAutoPrompt(force: true);
  }

  final Box<dynamic> _box;

  static const String _configKey = 'config';
  static const String _dayKeyPrefix = 'day_';

  static const List<String> _defaultTimeStrings = [
    '08:00',
    '13:00',
    '18:00',
    '23:00',
  ];

  List<String> _timeStrings = List<String>.from(_defaultTimeStrings);
  AlignmentAutoPrompt? _pendingPrompt;
  Timer? _ticker;
  Map<String, int>? _glanceSnapshot;
  DateTime? _glanceSnapshotDate;

  List<TimeOfDay> get scheduledTimes =>
      _timeStrings.map(_decodeTimeString).toList(growable: false);

  int get totalCheckIns => _timeStrings.length;

  int completedCountFor(DateTime date) =>
      _getDayRecord(_stripDate(date)).completedCount;

  int get completedTodayCount => completedCountFor(AppClock.now());
  Map<String, int>? glanceSnapshotForToday() {
    final today = _stripDate(AppClock.now());
    if (_glanceSnapshot == null ||
        _glanceSnapshotDate == null ||
        !_isSameDay(_glanceSnapshotDate!, today)) {
      return null;
    }
    return Map<String, int>.unmodifiable(_glanceSnapshot!);
  }

  void cacheGlanceSnapshot(Map<String, int> snapshot) {
    _glanceSnapshot = Map<String, int>.from(snapshot);
    _glanceSnapshotDate = _stripDate(AppClock.now());
  }

  AlignmentAutoPrompt? peekPendingPrompt() => _pendingPrompt;

  AlignmentAutoPrompt? consumePendingPrompt() {
    final prompt = _pendingPrompt;
    if (prompt == null) return null;
    _pendingPrompt = null;
    final record = _getDayRecord(prompt.date);
    record.markPrompted(prompt.index, AppClock.now());
    _saveDayRecord(record);
    notifyListeners();
    return prompt;
  }

  DateTime? get nextCheckInTime {
    final now = AppClock.now();
    final date = _stripDate(now);
    final record = _getDayRecord(date);
    for (int i = 0; i < _timeStrings.length; i++) {
      if (record.completed[i]) continue;
      return _dateTimeFor(date, _decodeTimeString(_timeStrings[i]));
    }
    return null;
  }

  Future<bool> completeNextCheckIn({DateTime? date}) async {
    final targetDate = _stripDate(date ?? AppClock.now());
    final record = _getDayRecord(targetDate);
    final idx = record.firstIncompleteIndex;
    if (idx == null) return false;
    record.markCompleted(idx, AppClock.now());
    _pendingPrompt = null;
    _saveDayRecord(record);
    _evaluateAutoPrompt(force: true);
    notifyListeners();
    return true;
  }

  Future<bool> snoozeNextCheckIn(Duration duration) async {
    final now = AppClock.now();
    final date = _stripDate(now);
    final record = _getDayRecord(date);
    final idx = record.currentDueIndex(now, _timeStrings);
    if (idx == null) return false;
    record.setSnooze(idx, now.add(duration));
    record.clearPrompt(idx);
    _pendingPrompt = null;
    _saveDayRecord(record);
    _evaluateAutoPrompt(force: true);
    notifyListeners();
    return true;
  }

  Future<void> updateTimeAt(int index, TimeOfDay time) async {
    final list = scheduledTimes;
    if (index < 0 || index >= list.length) return;
    list[index] = time;
    await _applyNewSchedule(list);
  }

  Future<void> resetSchedule() async {
    await _applyNewSchedule(
      _defaultTimeStrings.map(_decodeTimeString).toList(growable: false),
    );
  }

  /// Debug helper: clear all progress for *today* only.
  Future<void> resetTodayProgress() async {
    final DateTime today = _stripDate(AppClock.now());
    final fresh = _AlignmentDayRecord.empty(today, _timeStrings.length);
    _saveDayRecord(fresh);
    _pendingPrompt = null;
    _evaluateAutoPrompt(force: true);
    notifyListeners();
  }

  void reevaluate() => _evaluateAutoPrompt(force: true);

  Future<void> _applyNewSchedule(List<TimeOfDay> times) async {
    final sorted = List<TimeOfDay>.from(times)
      ..sort((a, b) =>
          (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    _timeStrings = sorted.map(_encodeTimeOfDay).toList(growable: false);
    await _box.put(_configKey, {'times': _timeStrings});
    _realignExistingDays();
    _evaluateAutoPrompt(force: true);
    notifyListeners();
  }

  void _realignExistingDays() {
    final now = _stripDate(AppClock.now());
    final key = _dayKey(now);
    final raw = _box.get(key);
    if (raw is Map) {
      final record = _AlignmentDayRecord.fromMap(now, raw, _timeStrings.length);
      _saveDayRecord(record);
    }
  }

  void _loadConfig() {
    final raw = _box.get(_configKey);
    if (raw is Map && raw['times'] is List) {
      final list = (raw['times'] as List)
          .whereType<String>()
          .where((t) => t.contains(':'))
          .toList();
      if (list.length == _defaultTimeStrings.length) {
        _timeStrings = list;
      }
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      _evaluateAutoPrompt();
    });
  }

  void _evaluateAutoPrompt({bool force = false}) {
    final now = AppClock.now();
    final date = _stripDate(now);
    final record = _getDayRecord(date);
    final dueIndex = record.nextPromptableIndex(now, _timeStrings);
    AlignmentAutoPrompt? nextPrompt;
    if (dueIndex != null) {
      nextPrompt = AlignmentAutoPrompt(
        date: date,
        index: dueIndex,
        scheduledTime: _dateTimeFor(date, _decodeTimeString(_timeStrings[dueIndex])),
      );
    }
    if (force || nextPrompt?.index != _pendingPrompt?.index) {
      _pendingPrompt = nextPrompt;
      if (nextPrompt != null) {
        _cleanupOldDays();
      }
      notifyListeners();
    }
  }

  void _cleanupOldDays() {
    final threshold = AppClock.now().subtract(const Duration(days: 10));
    final keys = _box.keys.whereType<String>().where(
          (key) => key.startsWith(_dayKeyPrefix),
        );
    for (final key in keys) {
      final date = _parseDayKey(key);
      if (date != null && date.isBefore(threshold)) {
        _box.delete(key);
      }
    }
  }

  _AlignmentDayRecord _getDayRecord(DateTime date) {
    final key = _dayKey(date);
    final raw = _box.get(key);
    if (raw is Map) {
      final record =
          _AlignmentDayRecord.fromMap(date, raw, _timeStrings.length);
      return record;
    }
    final record = _AlignmentDayRecord.empty(date, _timeStrings.length);
    _box.put(key, record.toMap());
    return record;
  }

  void _saveDayRecord(_AlignmentDayRecord record) {
    _box.put(_dayKey(record.date), record.toMap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _evaluateAutoPrompt(force: true);
    }
  }

  static String _dayKey(DateTime date) =>
      '$_dayKeyPrefix${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDayKey(String key) {
    if (!key.startsWith(_dayKeyPrefix)) return null;
    final raw = key.substring(_dayKeyPrefix.length);
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static TimeOfDay _decodeTimeString(String value) {
    final parts = value.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _encodeTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  static DateTime _dateTimeFor(DateTime day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }
}

class _AlignmentDayRecord {
  _AlignmentDayRecord({
    required this.date,
    required this.completed,
    required this.completedAt,
    required this.snoozeUntil,
    required this.promptedAt,
  });

  final DateTime date;
  final List<bool> completed;
  final List<int?> completedAt;
  final List<int?> snoozeUntil;
  final List<int?> promptedAt;

  int get completedCount => completed.where((c) => c).length;

  int? get firstIncompleteIndex {
    for (int i = 0; i < completed.length; i++) {
      if (!completed[i]) return i;
    }
    return null;
  }

  int? currentDueIndex(DateTime now, List<String> times) {
    for (int i = 0; i < completed.length; i++) {
      if (completed[i]) continue;
      final scheduled =
          AlignmentScheduleProvider._dateTimeFor(date, AlignmentScheduleProvider._decodeTimeString(times[i]));
      if (scheduled.isAfter(now)) break;
      final snoozeMs = snoozeUntil[i];
      if (snoozeMs != null &&
          DateTime.fromMillisecondsSinceEpoch(snoozeMs).isAfter(now)) {
        continue;
      }
      return i;
    }
    return null;
  }

  int? nextPromptableIndex(DateTime now, List<String> times) {
    for (int i = 0; i < completed.length; i++) {
      if (completed[i]) continue;
      final scheduled =
          AlignmentScheduleProvider._dateTimeFor(date, AlignmentScheduleProvider._decodeTimeString(times[i]));
      if (scheduled.isAfter(now)) return null;
      final snoozeMs = snoozeUntil[i];
      if (snoozeMs != null &&
          DateTime.fromMillisecondsSinceEpoch(snoozeMs).isAfter(now)) {
        continue;
      }
      if (promptedAt[i] != null) continue;
      return i;
    }
    return null;
  }

  void markCompleted(int index, DateTime timestamp) {
    if (index < 0 || index >= completed.length) return;
    completed[index] = true;
    completedAt[index] = timestamp.millisecondsSinceEpoch;
    snoozeUntil[index] = null;
    promptedAt[index] = null;
  }

  void markPrompted(int index, DateTime timestamp) {
    if (index < 0 || index >= promptedAt.length) return;
    promptedAt[index] = timestamp.millisecondsSinceEpoch;
  }

  void clearPrompt(int index) {
    if (index < 0 || index >= promptedAt.length) return;
    promptedAt[index] = null;
  }

  void setSnooze(int index, DateTime until) {
    if (index < 0 || index >= snoozeUntil.length) return;
    snoozeUntil[index] = until.millisecondsSinceEpoch;
  }

  Map<String, dynamic> toMap() => {
        'completed': completed,
        'completedAt': completedAt,
        'snoozeUntil': snoozeUntil,
        'promptedAt': promptedAt,
      };

  factory _AlignmentDayRecord.fromMap(
    DateTime date,
    Map<dynamic, dynamic> raw,
    int length,
  ) {
    List<bool> completed = _castBoolList(raw['completed'], length);
    List<int?> completedAt = _castIntList(raw['completedAt'], length);
    List<int?> snoozeUntil = _castIntList(raw['snoozeUntil'], length);
    List<int?> promptedAt = _castIntList(raw['promptedAt'], length);
    return _AlignmentDayRecord(
      date: _stripDate(date),
      completed: completed,
      completedAt: completedAt,
      snoozeUntil: snoozeUntil,
      promptedAt: promptedAt,
    );
  }

  factory _AlignmentDayRecord.empty(DateTime date, int length) {
    return _AlignmentDayRecord(
      date: _stripDate(date),
      completed: List<bool>.filled(length, false),
      completedAt: List<int?>.filled(length, null),
      snoozeUntil: List<int?>.filled(length, null),
      promptedAt: List<int?>.filled(length, null),
    );
  }

  static List<bool> _castBoolList(dynamic raw, int length) {
    final list = List<bool>.filled(length, false);
    if (raw is List) {
      for (int i = 0; i < length && i < raw.length; i++) {
        list[i] = raw[i] == true;
      }
    }
    return list;
  }

  static List<int?> _castIntList(dynamic raw, int length) {
    final list = List<int?>.filled(length, null);
    if (raw is List) {
      for (int i = 0; i < length && i < raw.length; i++) {
        final value = raw[i];
        if (value is int) list[i] = value;
      }
    }
    return list;
  }
}
