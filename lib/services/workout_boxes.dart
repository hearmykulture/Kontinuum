import 'package:hive_flutter/hive_flutter.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class WorkoutBoxes {
  // current "nice" names
  static const routinesBoxName = 'workoutRoutines';
  static const workoutsBoxName = 'workoutWorkouts';
  static const exerciseBoxName = 'exerciseLibrary';
  static const logsBoxName = 'workoutLogs';
  static const schedulesBoxName = 'workoutSchedules';

  /// One-off rest overrides (e.g. "Skip workout today") are stored here
  /// as lightweight Map payloads keyed by an auto-increment key.
  static const restOverridesBoxName = 'workoutRestOverrides';

  // legacy / lowercase names that may exist on disk (iOS/macOS case-insensitive)
  static const _legacyRoutinesBoxName = 'workoutroutines';
  static const _legacyLogsBoxName = 'workoutlogs';
  static const legacyRoutinesBoxName = _legacyRoutinesBoxName;
  static const legacyLogsBoxName = _legacyLogsBoxName;

  static Future<void> init() async {
    // ---- adapters (guarded) ----
    if (!Hive.isAdapterRegistered(200)) {
      Hive.registerAdapter(DietGoalAdapter());
    }
    if (!Hive.isAdapterRegistered(201)) {
      Hive.registerAdapter(DietStrictnessAdapter());
    }
    if (!Hive.isAdapterRegistered(202)) {
      Hive.registerAdapter(ExerciseIntentAdapter());
    }
    if (!Hive.isAdapterRegistered(203)) {
      Hive.registerAdapter(ExerciseDifficultyAdapter());
    }
    if (!Hive.isAdapterRegistered(204)) {
      Hive.registerAdapter(BlockTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(205)) {
      Hive.registerAdapter(DietSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(206)) {
      Hive.registerAdapter(ExerciseAdapter());
    }
    if (!Hive.isAdapterRegistered(207)) {
      Hive.registerAdapter(WorkoutItemAdapter());
    }
    if (!Hive.isAdapterRegistered(208)) {
      Hive.registerAdapter(WorkoutBlockAdapter());
    }
    if (!Hive.isAdapterRegistered(209)) {
      Hive.registerAdapter(WorkoutAdapter());
    }
    if (!Hive.isAdapterRegistered(210)) {
      Hive.registerAdapter(RoutineAdapter());
    }
    if (!Hive.isAdapterRegistered(211)) {
      Hive.registerAdapter(SetLogAdapter());
    }
    if (!Hive.isAdapterRegistered(212)) {
      Hive.registerAdapter(ExerciseLogAdapter());
    }
    if (!Hive.isAdapterRegistered(213)) {
      Hive.registerAdapter(StatDeltaAdapter());
    }
    if (!Hive.isAdapterRegistered(214)) {
      Hive.registerAdapter(SessionTotalsAdapter());
    }
    if (!Hive.isAdapterRegistered(215)) {
      Hive.registerAdapter(WorkoutLogAdapter());
    }
    if (!Hive.isAdapterRegistered(218)) {
      Hive.registerAdapter(RepetitionModeAdapter());
    }
    if (!Hive.isAdapterRegistered(219)) {
      Hive.registerAdapter(RepetitionUnitAdapter());
    }
    if (!Hive.isAdapterRegistered(220)) {
      Hive.registerAdapter(WorkoutScheduleAdapter());
    }
    if (!Hive.isAdapterRegistered(221)) {
      Hive.registerAdapter(RestScheduleAdapter());
    }

    // ---- boxes (guarded, legacy-aware) ----

    // routines: prefer already-open (any casing), otherwise open current name,
    // otherwise fall back to legacy lowercase
    if (!Hive.isBoxOpen(routinesBoxName) &&
        !Hive.isBoxOpen(_legacyRoutinesBoxName)) {
      try {
        await Hive.openBox<Routine>(routinesBoxName);
      } on HiveError {
        // maybe the file on disk is lowercase
        if (!Hive.isBoxOpen(_legacyRoutinesBoxName)) {
          await Hive.openBox<Routine>(_legacyRoutinesBoxName);
        }
      }
    }

    // workouts
    if (!Hive.isBoxOpen(workoutsBoxName)) {
      await Hive.openBox<Workout>(workoutsBoxName);
    }

    // exercise library
    if (!Hive.isBoxOpen(exerciseBoxName)) {
      await Hive.openBox<Exercise>(exerciseBoxName);
    }

    // logs: same trick as routines
    if (!Hive.isBoxOpen(logsBoxName) && !Hive.isBoxOpen(_legacyLogsBoxName)) {
      try {
        await Hive.openBox<WorkoutLog>(logsBoxName);
      } on HiveError {
        if (!Hive.isBoxOpen(_legacyLogsBoxName)) {
          await Hive.openBox<WorkoutLog>(_legacyLogsBoxName);
        }
      }
    }

    // schedules
    if (!Hive.isBoxOpen(schedulesBoxName)) {
      await Hive.openBox<WorkoutSchedule>(schedulesBoxName);
    }

    // one-off rest overrides (Map payloads; no adapter needed)
    if (!Hive.isBoxOpen(restOverridesBoxName)) {
      await Hive.openBox<Map<String, dynamic>>(restOverridesBoxName);
    }

    // ---- lightweight migrations ----
    await _migrateRestScheduleDefaults();
    await _migrateRoutineScheduleModes();

    // ---- housekeeping for overrides ----
    await _purgeExpiredRestOverrides();
  }

  // Convenience getters — pick whichever is open
  static Box<Routine> get routinesBox {
    if (Hive.isBoxOpen(routinesBoxName)) {
      return Hive.box<Routine>(routinesBoxName);
    }
    return Hive.box<Routine>(_legacyRoutinesBoxName);
  }

  static Box<Workout> get workoutsBox => Hive.box<Workout>(workoutsBoxName);

  static Box<Exercise> get exerciseBox => Hive.box<Exercise>(exerciseBoxName);

  static Box<WorkoutLog> get logsBox {
    if (Hive.isBoxOpen(logsBoxName)) {
      return Hive.box<WorkoutLog>(logsBoxName);
    }
    return Hive.box<WorkoutLog>(_legacyLogsBoxName);
  }

  static Box<WorkoutSchedule> get schedulesBox =>
      Hive.box<WorkoutSchedule>(schedulesBoxName);

  /// Box containing one-off rest overrides; values are Maps with
  /// `kind: 'one_off_rest'`, `dateIso`, `createdAtIso`, etc.
  static Box<Map<String, dynamic>> get restOverridesBox =>
      Hive.box<Map<String, dynamic>>(restOverridesBoxName);

  /// Migration: ensure every [WorkoutSchedule] either has an explicit
  /// [RestSchedule] or can infer one safely. For **weekly** schedules we
  /// persist a complement-of-weeklyDays rest pattern as a sane default.
  ///
  /// Interval schedules are left without an explicit [restSchedule]; for those,
  /// callers can use `!isPrescribedFor(date)` to interpret rest.
  static Future<void> _migrateRestScheduleDefaults() async {
    if (!Hive.isBoxOpen(schedulesBoxName)) return;

    final box = Hive.box<WorkoutSchedule>(schedulesBoxName);

    for (final dynamic key in box.keys) {
      final WorkoutSchedule? schedule = box.get(key);
      if (schedule == null) continue;

      // Normalize weeklyDays length to 7 so complement maths are safe.
      schedule.normalizeWeeklyLength();

      if (schedule.restSchedule != null) {
        continue; // already migrated / newly written
      }

      if (schedule.mode == RepetitionMode.weekly) {
        // Create explicit rest schedule as complement of workout days.
        final rest = RestSchedule.complementOfWeekly(schedule.weeklyDays);
        // Reuse the same interval start date to keep interval-based workflows
        // consistent if they ever opt into interval rest later.
        rest.intervalStartDateIso = schedule.intervalStartDateIso;
        schedule.restSchedule = rest;
        await schedule.save();
      } else {
        // Interval-mode schedules get no explicit restSchedule by default.
        // Rest is interpreted as "!isPrescribedFor(date)".
        continue;
      }
    }
  }

  /// Ensure routines have an explicit scheduleMode persisted (defaults to the
  /// rest schedule's mode or weekly) and that their rest schedule stays in sync.
  static Future<void> _migrateRoutineScheduleModes() async {
    final bool routinesBoxOpen =
        Hive.isBoxOpen(routinesBoxName) || Hive.isBoxOpen(_legacyRoutinesBoxName);
    if (!routinesBoxOpen) return;

    final box = routinesBox;
    for (final dynamic key in box.keys) {
      final Routine? routine = box.get(key);
      if (routine == null) continue;

      final RestSchedule? rest = routine.restSchedule;
      final RepetitionMode desired =
          rest?.mode ?? routine.scheduleMode;

      if (routine.scheduleMode != desired) {
        routine.scheduleMode = desired;
      }
      if (rest != null && rest.mode != desired) {
        routine.restSchedule = rest.copyWith(mode: desired);
      }

      await routine.save();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // One-off rest override helpers
  // ───────────────────────────────────────────────────────────────────────────

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime? _parseOverrideDate(Map<dynamic, dynamic> map) {
    final v = map['dateIso'] ?? map['date'] ?? map['dateYmd'];
    if (v is DateTime) {
      return DateTime(v.year, v.month, v.day);
    }
    if (v is String) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return null;

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

      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return null;
  }

  /// Returns true if a one-off rest override exists for [date].
  ///
  /// This is a lightweight, synchronous helper intended for UI / providers
  /// to treat a given day as "rest" without touching the recurring schedule.
  static bool hasRestOverrideFor(DateTime date) {
    if (!Hive.isBoxOpen(restOverridesBoxName)) return false;
    final box = restOverridesBox;
    final target = DateTime(date.year, date.month, date.day);

    try {
      for (final dynamic key in box.keys) {
        final dynamic value = box.get(key);
        if (value is! Map) continue;

        final kind = value['kind'];
        if (kind != 'one_off_rest' && kind != 'rest_override') continue;

        final d = _parseOverrideDate(value as Map<dynamic, dynamic>);
        if (d != null && _sameDay(d, target)) {
          return true;
        }
      }
    } catch (_) {
      // best-effort
    }

    return false;
  }

  /// Upserts a one-off rest override for [date].
  ///
  /// - Does **not** alter the user's recurring schedule.
  /// - Intended to be called from the dashboard "Skip today" action,
  ///   LoggingSheet, or other ad-hoc flows.
  static Future<void> upsertRestOverrideFor(
    DateTime date, {
    String source = 'unknown',
    String? reason,
  }) async {
    if (!Hive.isBoxOpen(restOverridesBoxName)) {
      await Hive.openBox<Map<String, dynamic>>(restOverridesBoxName);
    }

    final box = restOverridesBox;
    final target = DateTime(date.year, date.month, date.day);

    dynamic existingKey;

    try {
      for (final dynamic key in box.keys) {
        final dynamic value = box.get(key);
        if (value is! Map) continue;

        final kind = value['kind'];
        if (kind != 'one_off_rest' && kind != 'rest_override') continue;

        final d = _parseOverrideDate(value as Map<dynamic, dynamic>);
        if (d != null && _sameDay(d, target)) {
          existingKey = key;
          break;
        }
      }
    } catch (_) {
      // ignore and treat as "no existing"
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'kind': 'one_off_rest',
      'dateIso': target.toIso8601String(),
      'createdAtIso': AppClock.now().toIso8601String(),
      'source': source,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    try {
      if (existingKey != null) {
        await box.put(existingKey, payload);
      } else {
        await box.add(payload);
      }
    } catch (_) {
      // best-effort: swallow errors so UI doesn't crash on skip
    }
  }

  /// Purge rest overrides whose date is strictly before "today".
  ///
  /// This keeps the overrides box small and ensures one-off rest flags
  /// only affect dashboards while the day is current.
  static Future<void> _purgeExpiredRestOverrides() async {
    if (!Hive.isBoxOpen(restOverridesBoxName)) return;

    final box = restOverridesBox;
    if (box.isEmpty) return;

    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<dynamic> toDelete = <dynamic>[];

    try {
      for (final dynamic key in box.keys) {
        final dynamic value = box.get(key);
        if (value is! Map) continue;

        final d = _parseOverrideDate(value as Map<dynamic, dynamic>);
        if (d == null) continue;

        final normalized = DateTime(d.year, d.month, d.day);
        if (normalized.isBefore(today)) {
          toDelete.add(key);
        }
      }
    } catch (_) {
      // best-effort: even if iteration fails, nothing catastrophic
    }

    if (toDelete.isNotEmpty) {
      await box.deleteAll(toDelete);
    }
  }
}
