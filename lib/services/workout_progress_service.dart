import 'package:hive/hive.dart';

import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/services/workout_boxes.dart';

/// Convenience result object so callers can choose percent or raw counts.
class WorkoutProgressSnapshot {
  final double percent; // 0.0 – 1.0
  final int completedSets;
  final int totalSets;
  final bool hasFinishedLog;
  final bool hasActiveSession;

  const WorkoutProgressSnapshot({
    required this.percent,
    required this.completedSets,
    required this.totalSets,
    required this.hasFinishedLog,
    required this.hasActiveSession,
  });
}

/// Central place for workout/day completion logic.
///
/// Rules:
///   1. If there is a finished WorkoutLog for (workoutId, ymd), we always
///      report 100% (log is the source of truth for completion).
///   2. Else, if there is an active session for (workoutId, ymd), we compute
///      completion as `session.totalCompletedSets / totalTargetSets`.
///   3. Else, 0%.
class WorkoutProgressService {
  WorkoutProgressService._();

  static final WorkoutProgressService instance = WorkoutProgressService._();

  // ---- Public API ---------------------------------------------------------

  /// Returns a 0.0–1.0 completion fraction for [workout] on the given day.
  ///
  /// This is what the dashboard ring / timeline currently uses.
  double completionForDay({
    required Workout workout,
    required DateTime scheduledDate,
  }) {
    final snapshot = snapshotForDay(
      workout: workout,
      scheduledDate: scheduledDate,
    );
    return snapshot.percent;
  }

  /// Rich snapshot – use this when you want percent + raw counts.
  WorkoutProgressSnapshot snapshotForDay({
    required Workout workout,
    required DateTime scheduledDate,
  }) {
    final String ymd = _formatYmd(scheduledDate);

    // 1) Finished log takes precedence.
    final bool hasFinishedLog =
        _hasFinishedLogForDay(workoutId: workout.id, ymd: ymd);

    if (hasFinishedLog) {
      final int totalSets = _computeTotalTargetSets(workout);
      return WorkoutProgressSnapshot(
        percent: 1.0,
        completedSets: totalSets,
        totalSets: totalSets,
        hasFinishedLog: true,
        hasActiveSession: false,
      );
    }

    // 2) Active / partial session for that workout + date.
    final session = SessionPersistenceService.getSessionFor(
      workoutId: workout.id,
      scheduledDateYmd: ymd,
    );

    if (session == null) {
      // Nothing done yet.
      final int totalSets = _computeTotalTargetSets(workout);
      return WorkoutProgressSnapshot(
        percent: 0.0,
        completedSets: 0,
        totalSets: totalSets,
        hasFinishedLog: false,
        hasActiveSession: false,
      );
    }

    final int totalSets = _computeTotalTargetSets(workout);

    // --- IMPORTANT PART: use aggregated completed sets --------------------
    //
    // New model (as per your SessionState):
    //   - session.completedSets:       per-exercise cumulative counts
    //   - session.totalCompletedSets:  helper that sums the map
    //
    // We *do not* rely on `completedSetsList.length` anymore, because that
    // only reflects the current exercise in multi-exercise workouts.
    //
    int completedSets = 0;

    // Try to use totalCompletedSets if present.
    try {
      final dynamic s = session;
      final dynamic mapTotal = s.totalCompletedSets;
      if (mapTotal is int) {
        completedSets = mapTotal;
      }
    } catch (_) {
      // ignore – we'll fall back below.
    }

    // Backwards-compat: for any legacy snapshots that don't have the map,
    // fall back to the per-session list length.
    if (completedSets <= 0) {
      try {
        final dynamic s = session;
        final dynamic list = s.completedSetsList;
        if (list is List) {
          completedSets = list.length;
        }
      } catch (_) {
        // ignore – leave at 0
      }
    }

    if (totalSets <= 0) {
      return WorkoutProgressSnapshot(
        percent: 0.0,
        completedSets: completedSets,
        totalSets: 0,
        hasFinishedLog: false,
        hasActiveSession: true,
      );
    }

    final double rawFraction = completedSets / totalSets;
    final double clamped = rawFraction.clamp(0.0, 1.0);

    return WorkoutProgressSnapshot(
      percent: clamped,
      completedSets: completedSets,
      totalSets: totalSets,
      hasFinishedLog: false,
      hasActiveSession: true,
    );
  }

  // ---- Scheduling helpers -------------------------------------------------
  //
  // Scheduling helpers used by dashboards/notifications.

  /// Determine which workouts are prescribed for [routineId] on [date], honoring
  /// global one-off rest overrides and routine-level rest schedules.
  static Set<String> getPrescribedWorkouts({
    String? routineId,
    DateTime? date,
  }) {
    if (routineId == null || routineId.isEmpty) return <String>{};
    if (date == null) return <String>{};

    final routine = WorkoutBoxes.routinesBox.get(routineId);
    if (routine == null || routine.workoutIds.isEmpty) {
      return <String>{};
    }

    final DateTime day = DateTime(date.year, date.month, date.day);

    // Global one-off rest overrides mean nothing is prescribed that day.
    if (WorkoutBoxes.hasRestOverrideFor(day)) {
      return <String>{};
    }

    final bool routineRest =
        routine.restSchedule != null && routine.restSchedule!.isRestOn(day);
    if (routineRest) {
      return <String>{};
    }

    final schedulesBox = WorkoutBoxes.schedulesBox;
    final Map<String, WorkoutSchedule> schedulesByWorkout =
        <String, WorkoutSchedule>{};
    for (final WorkoutSchedule schedule in schedulesBox.values) {
      schedule.normalizeWeeklyLength();
      schedulesByWorkout[schedule.workoutId] = schedule;
    }

    final Set<String> prescribed = <String>{};
    for (final wid in routine.workoutIds) {
      final schedule = schedulesByWorkout[wid];
      if (schedule == null) continue;

      if (!schedule.isPrescribedFor(day)) continue;
      if (schedule.isRestDay(day)) continue;

      prescribed.add(wid);
    }

    return prescribed;
  }

  /// Optional hook: persist a weekday-schedule toggle for a workout.
  ///
  /// Dashboard calls this whenever the user toggles one of the M/T/W/Th/F/S/Su
  /// pills on the WORKOUTS list. Right now this is a no-op; you can
  /// implement workout schedule persistence here later without changing
  /// the UI layer again.
  static void setWorkoutScheduledOnWeekday({
    required String routineId,
    required String workoutId,
    required int weekday, // 1=Mon … 7=Sun
    required bool enabled,
  }) {
    if (weekday < 1 || weekday > 7) return;
    final box = WorkoutBoxes.schedulesBox;
    WorkoutSchedule? schedule;
    dynamic key;
    for (final k in box.keys) {
      final s = box.get(k);
      if (s?.workoutId == workoutId) {
        schedule = s;
        key = k;
        break;
      }
    }
    schedule ??= WorkoutSchedule(
      workoutId: workoutId,
      mode: RepetitionMode.weekly,
      weeklyDays: List<bool>.filled(7, false),
      intervalValue: 1,
      intervalUnit: RepetitionUnit.days,
      intervalStartDateIso: DateTime.now().toIso8601String(),
    );
    schedule.normalizeWeeklyLength();
    schedule.weeklyDays[weekday - 1] = enabled;
    schedule.restSchedule ??=
        RestSchedule.complementOfWeekly(schedule.weeklyDays);
    _normalizeRestLength(schedule.restSchedule!);
    if (key != null) {
      box.put(key, schedule);
    } else {
      box.add(schedule);
    }
  }

  /// Shift an entire routine's schedule (including rest overrides) forward
  /// or backward by [deltaDays]. Positive values shift forward.
  static Future<void> shiftRoutineSchedule({
    required Routine routine,
    required int deltaDays,
  }) async {
    if (deltaDays == 0) return;
    final box = WorkoutBoxes.schedulesBox;
    for (final k in box.keys) {
      final schedule = box.get(k);
      if (schedule == null) continue;
      if (!routine.workoutIds.contains(schedule.workoutId)) continue;

      schedule.normalizeWeeklyLength();

      if (schedule.mode == RepetitionMode.weekly) {
        schedule.weeklyDays = _rotate(schedule.weeklyDays, deltaDays);
        final rest = schedule.restSchedule;
        if (rest != null) {
          _normalizeRestLength(rest);
          rest.weeklyDays = _rotate(rest.weeklyDays, deltaDays);
        }
      } else {
        // Interval mode → shift anchor date.
        if (schedule.intervalStartDateIso != null) {
          final parsed = DateTime.tryParse(schedule.intervalStartDateIso!);
          if (parsed != null) {
            final shifted = parsed.add(Duration(days: deltaDays));
            schedule.intervalStartDateIso = shifted.toIso8601String();
          }
        }
      }

      // Shift rest overrides.
      final overrides = schedule.restOverrides;
      if (overrides != null && overrides.isNotEmpty) {
        final Map<String, bool> shifted = {};
        overrides.forEach((ymd, isRest) {
          final dt = DateTime.tryParse(ymd);
          if (dt == null) return;
          final newDt = dt.add(Duration(days: deltaDays));
          shifted[_formatYmd(newDt)] = isRest;
        });
        schedule.restOverrides = shifted;
      }

      await schedule.save();
    }

    // Shift routine-level rest schedule if present.
    final rest = routine.restSchedule;
    if (rest != null) {
      _normalizeRestLength(rest);
      if (rest.mode == RepetitionMode.weekly) {
        rest.weeklyDays = _rotate(rest.weeklyDays, deltaDays);
      } else if (rest.intervalStartDateIso != null) {
        final parsed = DateTime.tryParse(rest.intervalStartDateIso!);
        if (parsed != null) {
          rest.intervalStartDateIso =
              parsed.add(Duration(days: deltaDays)).toIso8601String();
        }
      }
      final routinesBox = WorkoutBoxes.routinesBox;
      await routinesBox.put(routine.id, routine);
    }
  }

  // ---- Internal helpers ---------------------------------------------------

  /// Simple yyyy-MM-dd formatter so we don't depend on external utils.
  static String _formatYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static List<bool> _rotate(List<bool> list, int delta) {
    final len = list.length;
    if (len == 0) return list;
    final out = List<bool>.filled(len, false);
    final shift = ((delta % len) + len) % len;
    for (int i = 0; i < len; i++) {
      final newIndex = (i + shift) % len;
      out[newIndex] = list[i];
    }
    return out;
  }

  static void _normalizeRestLength(RestSchedule rest) {
    if (rest.weeklyDays.length == 7) return;
    final normalized = List<bool>.generate(
      7,
      (i) => i < rest.weeklyDays.length ? rest.weeklyDays[i] : false,
    );
    rest.weeklyDays = normalized;
  }

  /// Map/Object-safe: read a workoutId out of any log shape.
  static String? _readWorkoutId(dynamic x) {
    if (x == null) return null;

    // 1) Map-based payloads (Hive Map, JSON, etc.)
    if (x is Map) {
      for (final k in const [
        'workoutId',
        'currentWorkoutId',
        'wid',
        'workout_id',
        'id',
      ]) {
        final v = x[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    // 2) Typed objects (legacy Hive classes, etc.)
    try {
      final v = (x as dynamic).workoutId;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = (x as dynamic).currentWorkoutId;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = (x as dynamic).wid;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}

    return null;
  }

  /// Map/Object-safe: extract a timestamp representing the log date.
  static DateTime? _extractLogDate(dynamic log) {
    if (log == null) return null;

    DateTime? parseFlexible(String s) {
      final trimmed = s.trim();
      if (trimmed.isEmpty) return null;

      // "yyyyMMdd" (compact format)
      if (trimmed.length == 8 &&
          !trimmed.contains('-') &&
          !trimmed.contains('/')) {
        final y = int.tryParse(trimmed.substring(0, 4));
        final m = int.tryParse(trimmed.substring(4, 6));
        final d = int.tryParse(trimmed.substring(6, 8));
        if (y != null && m != null && d != null) {
          return DateTime(y, m, d);
        }
      }

      // "yyyy-MM-dd" or full ISO; DateTime will handle both
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }

      return null;
    }

    // 0) Typed WorkoutLog shortcut
    if (log is WorkoutLog) {
      final parsed = DateTime.tryParse(log.dateYmd);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    // 1) Map payloads
    if (log is Map) {
      DateTime? tryStr(String k) {
        final v = log[k];
        if (v is String) return parseFlexible(v);
        if (v is DateTime) return v;
        return null;
      }

      DateTime? tryMs(String k) {
        final v = log[k];
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
        return null;
      }

      for (final k in [
        'scheduledDateYmd',
        'dateYmd',
        'date',
        'startedAt',
        'completedAt',
        'dateIso',
        'startedAtIso',
        'completedAtIso',
      ]) {
        final d = tryStr(k);
        if (d != null) return d;
      }

      for (final k in ['startedAtMs', 'completedAtMs', 'dateMs']) {
        final d = tryMs(k);
        if (d != null) return d;
      }

      return null;
    }

    // 2) Typed objects – try a few conventional field names.
    try {
      if ((log as dynamic).scheduledDateYmd is String) {
        final d = parseFlexible((log as dynamic).scheduledDateYmd as String);
        if (d != null) return d;
      }
    } catch (_) {}

    try {
      if ((log as dynamic).dateYmd is String) {
        final d = parseFlexible((log as dynamic).dateYmd as String);
        if (d != null) return d;
      }
    } catch (_) {}

    try {
      if ((log as dynamic).date is DateTime) {
        return (log as dynamic).date as DateTime;
      }
    } catch (_) {}

    try {
      if ((log as dynamic).startedAt is DateTime) {
        return (log as dynamic).startedAt as DateTime;
      }
    } catch (_) {}

    try {
      if ((log as dynamic).completedAt is DateTime) {
        return (log as dynamic).completedAt as DateTime;
      }
    } catch (_) {}

    try {
      if ((log as dynamic).dateIso is String) {
        final d = parseFlexible((log as dynamic).dateIso as String);
        if (d != null) return d;
      }
    } catch (_) {}

    try {
      if ((log as dynamic).startedAtIso is String) {
        final d = parseFlexible((log as dynamic).startedAtIso as String);
        if (d != null) return d;
      }
    } catch (_) {}

    try {
      if ((log as dynamic).completedAtIso is String) {
        final d = parseFlexible((log as dynamic).completedAtIso as String);
        if (d != null) return d;
      }
    } catch (_) {}

    try {
      if ((log as dynamic).startedAtMs is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          (log as dynamic).startedAtMs as int,
        );
      }
    } catch (_) {}

    try {
      if ((log as dynamic).completedAtMs is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          (log as dynamic).completedAtMs as int,
        );
      }
    } catch (_) {}

    return null;
  }

  /// Heuristic: treat log as "finished" if we find a truthy completed flag,
  /// or a non-null "completedAt" timestamp.
  static bool _isLogFinished(dynamic log) {
    if (log == null) return false;

    // Typed WorkoutLog: consider any log with exercise entries finished.
    if (log is WorkoutLog) {
      return log.exerciseLogs.isNotEmpty;
    }

    // Map-based
    if (log is Map) {
      for (final key in const [
        'isFinished',
        'finished',
        'isComplete',
        'complete',
        'completed',
      ]) {
        final v = log[key];
        if (v is bool && v) return true;
      }

      for (final key in const [
        'completedAt',
        'completedAtIso',
        'completedAtMs'
      ]) {
        final v = log[key];
        if (v != null) return true;
      }
      return false;
    }

    // Object-based
    try {
      final v = (log as dynamic).isFinished;
      if (v is bool && v) return true;
    } catch (_) {}
    try {
      final v = (log as dynamic).finished;
      if (v is bool && v) return true;
    } catch (_) {}
    try {
      final v = (log as dynamic).isComplete;
      if (v is bool && v) return true;
    } catch (_) {}
    try {
      final v = (log as dynamic).complete;
      if (v is bool && v) return true;
    } catch (_) {}
    try {
      final v = (log as dynamic).completed;
      if (v is bool && v) return true;
    } catch (_) {}

    try {
      final v = (log as dynamic).completedAt;
      if (v != null) return true;
    } catch (_) {}
    try {
      final v = (log as dynamic).completedAtIso;
      if (v != null) return true;
    } catch (_) {}
    try {
      final v = (log as dynamic).completedAtMs;
      if (v != null) return true;
    } catch (_) {}

    return false;
  }

  bool _hasFinishedLogForDay({
    required String workoutId,
    required String ymd,
  }) {
    final Box<WorkoutLog> box = WorkoutBoxes.logsBox;

    for (final WorkoutLog log in box.values) {
      final dynamic dyn = log;

      final String? wid = _readWorkoutId(dyn);
      if (wid != workoutId) continue;

      final DateTime? d = _extractLogDate(dyn);
      if (d == null || _formatYmd(d) != ymd) continue;

      if (_isLogFinished(dyn)) {
        return true;
      }
    }

    return false;
  }

  /// Sums all target sets across **all main blocks/items** of this workout.
  ///
  /// We:
  ///   - skip pure "break" or "note" blocks
  ///   - include warmup/cooldown exercise sets, unless their targetSets is null
  ///   - treat null targetSets as 0
  int _computeTotalTargetSets(Workout workout) {
    var total = 0;

    for (final block in workout.blocks) {
      // Skip non-exercise blocks if your model uses a kind/enum for that.
      if (block.isPureNoteBlock == true || block.isBreakBlock == true) {
        continue;
      }

      for (final item in block.items) {
        final int sets = item.targetSets;
        if (sets > 0) {
          total += sets;
        }
      }
    }

    return total;
  }
}
