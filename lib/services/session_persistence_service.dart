// lib/services/session_persistence_service.dart
import 'dart:async';

import 'package:hive/hive.dart';

import 'package:kontinuum/models/session_state.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/workout_boxes.dart';

/// Centralized persistence for in-progress workout sessions.
///
/// Storage layout:
///   - Box name: 'workout_session_state'
///   - Keys:
///       * '_current_session_v2'           → last active session (any day)
///       * '<workoutId>|<YYYY-MM-DD>'      → session bound to that day
class SessionPersistenceService {
  static const String _kBoxName = 'workout_session_state';
  static const String _kCurrentKey = '_current_session_v2';

  /// Public getter for consumers that need to manage the underlying box.
  static String get boxName => _kBoxName;

  /// NOTE: we deliberately use `Box<dynamic>` here so Hive does not try
  /// to cast legacy Map snapshots to `WorkoutSessionState` internally.
  static Box<dynamic> get _box => Hive.box<dynamic>(_kBoxName);

  /// Safe wrapper around [_box.get] which only returns a value if it is
  /// actually a [WorkoutSessionState]. Legacy Map/object shapes are ignored.
  static WorkoutSessionState? _safeGet(dynamic key) {
    try {
      final dynamic v = _box.get(key);
      return v is WorkoutSessionState ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// Call this once at app startup (e.g. in main()).
  ///
  /// IMPORTANT: we open the box as `dynamic` so the underlying BoxImpl
  /// is parameterized with `dynamic`, which means `get()` will not try
  /// to cast stored values to `WorkoutSessionState` automatically.
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_kBoxName)) {
      await Hive.openBox<dynamic>(_kBoxName);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save / get
  // ─────────────────────────────────────────────────────────────────────────

  /// Save (or update) a session snapshot.
  ///
  /// This:
  ///   1) Writes it as the global "_current" session.
  ///   2) If it has a [workoutId] and [scheduledDateIso], also stores it under
  ///      "<workoutId>|<YYYY-MM-DD>" so it can be looked up per day.
  ///
  static Future<void> saveSession(WorkoutSessionState state) async {
    // If this snapshot belongs to a programmed REST day, don't persist it.
    if (isRestDayForSession(state)) {
      final String workoutId = state.workoutId;
      final String? ymd =
          _extractYmd(state.scheduledDateIso ?? state.savedAtIso);

      if (workoutId.isNotEmpty && ymd != null) {
        await clearSessionFor(workoutId: workoutId, scheduledDateYmd: ymd);
      }
      return;
    }

    final box = _box;

    // Always keep a "current" pointer.
    await box.put(_kCurrentKey, state.copyDetached());

    // Also bind to a specific workout+date if we can.
    final String workoutId = state.workoutId;
    final String? ymd = _extractYmd(state.scheduledDateIso ?? state.savedAtIso);

    if (workoutId.isEmpty || ymd == null) {
      return;
    }

    final String key = _compoundKey(workoutId, ymd);
    await box.put(key, state.copyDetached());
  }

  /// Return the last active session (if still valid and not on a rest day).
  static WorkoutSessionState? getCurrentSession() {
    final WorkoutSessionState? state = _safeGet(_kCurrentKey);
    if (state == null || !state.isValid) return null;
    if ((state.routineId ?? '').isEmpty) return null;
    if (isRestDayForSession(state)) {
      return null;
    }
    return state;
  }

  /// Lookup a session for a specific [workoutId] and calendar day
  /// (`scheduledDateYmd` is "YYYY-MM-DD").
  static WorkoutSessionState? getSessionFor({
    required String workoutId,
    required String scheduledDateYmd,
  }) {
    final box = _box;

    // Fast path: compound key.
    final String key = _compoundKey(workoutId, scheduledDateYmd);
    final WorkoutSessionState? direct = _safeGet(key);
    if (direct != null &&
        direct.isValid &&
        (direct.routineId ?? '').isNotEmpty &&
        !isRestDayForSession(direct)) {
      return direct;
    }

    // Fallback: scan values to handle any older / differently-keyed entries.
    WorkoutSessionState? candidate;
    for (final dynamic rawKey in box.keys) {
      if (rawKey == _kCurrentKey) continue;

      final WorkoutSessionState? s = _safeGet(rawKey);
      if (s == null || !s.isValid) continue; // ignore legacy map/object shapes
      if ((s.routineId ?? '').isEmpty) continue;
      if (s.workoutId != workoutId) continue;
      if (isRestDayForSession(s)) continue;

      final String? ymd = _extractYmd(s.scheduledDateIso ?? s.savedAtIso);
      if (ymd == scheduledDateYmd) {
        candidate = s;
        break;
      }
    }
    return candidate;
  }

  /// Return the most recently-saved *valid* session for this workout,
  /// regardless of calendar day, **excluding rest days**.
  static WorkoutSessionState? getMostRecentSessionForWorkout(
    String workoutId,
  ) {
    final box = _box;
    WorkoutSessionState? best;
    DateTime? bestSaved;

    for (final dynamic key in box.keys) {
      final WorkoutSessionState? s = _safeGet(key);
      if (s == null || !s.isValid) continue;
      if (s.workoutId != workoutId) continue;
      if (isRestDayForSession(s)) continue;

      DateTime saved;
      try {
        saved = DateTime.parse(s.savedAtIso);
      } catch (_) {
        continue;
      }

      if (best == null || saved.isAfter(bestSaved!)) {
        best = s;
        bestSaved = saved;
      }
    }

    return best;
  }

  /// True if there's any valid, non-rest-day session for this workout (any day).
  static bool hasValidSessionForWorkout(String workoutId) {
    return getMostRecentSessionForWorkout(workoutId) != null;
  }

  /// True if the given [state] corresponds to a programmed rest day according
  /// to the current [WorkoutSchedule] records.
  ///
  /// This does **not** mutate the stored snapshot; instead it derives rest
  /// status from the schedule at lookup time, so legacy drafts remain valid.
  static bool isRestDayForSession(WorkoutSessionState state) {
    final String workoutId = state.workoutId;
    if (workoutId.isEmpty) return false;

    final String? ymd = _extractYmd(state.scheduledDateIso ?? state.savedAtIso);
    if (ymd == null) return false;

    DateTime date;
    try {
      // We only care about the date portion; time components can be zero.
      date = DateTime.parse(ymd);
    } catch (_) {
      return false;
    }

    // Global one-off "skip today" overrides take priority.
    if (WorkoutBoxes.hasRestOverrideFor(date)) {
      return true;
    }

    // Routine-level rest schedule (if known) is authoritative, just like
    // WorkoutProvider.isRestDay.
    bool? restFromRoutine;
    final String? routineId = state.routineId;
    if (routineId != null && routineId.isNotEmpty) {
      try {
        final Routine? routine = WorkoutBoxes.routinesBox.get(routineId);
        if (routine?.restSchedule != null) {
          restFromRoutine = routine!.restSchedule!.isRestOn(date);
        }
      } catch (_) {
        // best-effort
      }
    }

    bool scheduleRest = false;
    for (final schedule in WorkoutBoxes.schedulesBox.values) {
      try {
        final dynamic s = schedule;
        if (s.workoutId != workoutId) continue;
        s.normalizeWeeklyLength();
        if (s.isRestDay(date) == true) {
          scheduleRest = true;
          break;
        }
      } catch (_) {
        // Ignore mis-shaped schedule entries.
      }
    }

    if (restFromRoutine != null) {
      return restFromRoutine!;
    }

    if (scheduleRest) return true;

    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Clear / reset
  // ─────────────────────────────────────────────────────────────────────────

  /// Clear the session bound to [workoutId] + [scheduledDateYmd].
  ///
  /// Also clears the "_current" session if it belongs to the same
  /// workout+day pair.
  static Future<void> clearSessionFor({
    required String workoutId,
    required String scheduledDateYmd,
  }) async {
    final box = _box;

    // Delete the keyed entry.
    final String key = _compoundKey(workoutId, scheduledDateYmd);
    if (box.containsKey(key)) {
      await box.delete(key);
    }

    // If the "_current" session is the same workout+day, drop that too.
    final WorkoutSessionState? current = _safeGet(_kCurrentKey);
    if (current != null &&
        current.workoutId == workoutId &&
        _extractYmd(current.scheduledDateIso ?? current.savedAtIso) ==
            scheduledDateYmd) {
      await box.delete(_kCurrentKey);
    }
  }

  /// Clear every session snapshot (regardless of workout) tied to [date].
  ///
  /// Used when a one-off rest override is created so stale drafts cannot be
  /// resumed for a day that now counts as "skipped".
  static Future<void> clearSessionsForDate(DateTime date) async {
    final box = _box;
    final String targetYmd = dateTimeToYmd(date);
    final List<dynamic> keysToDelete = <dynamic>[];

    for (final dynamic key in box.keys) {
      if (key == _kCurrentKey) continue;

      final WorkoutSessionState? state = _safeGet(key);
      if (state != null) {
        final String? ymd =
            _extractYmd(state.scheduledDateIso ?? state.savedAtIso);
        if (ymd == targetYmd) {
          keysToDelete.add(key);
        }
        continue;
      }

      if (key is String && key.endsWith('|$targetYmd')) {
        keysToDelete.add(key);
      }
    }

    for (final dynamic key in keysToDelete) {
      await box.delete(key);
    }

    final WorkoutSessionState? current = _safeGet(_kCurrentKey);
    if (current != null) {
      final String? currentYmd =
          _extractYmd(current.scheduledDateIso ?? current.savedAtIso);
      if (currentYmd == targetYmd) {
        await box.delete(_kCurrentKey);
      }
    }
  }

  /// Clear any sessions tied to [routine] that now fall on a rest day according
  /// to the routine's current [RestSchedule].
  static Future<void> clearSessionsForRoutine(Routine routine) async {
    final restSchedule = routine.restSchedule;
    if (restSchedule == null) return;

    final box = _box;
    final List<dynamic> keysToDelete = <dynamic>[];

    for (final dynamic key in box.keys) {
      final WorkoutSessionState? state = _safeGet(key);
      if (state == null) continue;
      if (state.routineId != routine.id) continue;

      final String? ymd =
          _extractYmd(state.scheduledDateIso ?? state.savedAtIso);
      if (ymd == null) continue;

      DateTime? date;
      try {
        date = DateTime.parse(ymd);
      } catch (_) {
        continue;
      }

      if (restSchedule.isRestOn(date)) {
        keysToDelete.add(key);
      }
    }

    for (final dynamic key in keysToDelete) {
      await box.delete(key);
    }

    final WorkoutSessionState? current = _safeGet(_kCurrentKey);
    if (current != null && current.routineId == routine.id) {
      final String? ymd =
          _extractYmd(current.scheduledDateIso ?? current.savedAtIso);
      if (ymd != null) {
        try {
          final DateTime date = DateTime.parse(ymd);
          if (restSchedule.isRestOn(date)) {
            await box.delete(_kCurrentKey);
          }
        } catch (_) {
          // ignore malformed dates
        }
      }
    }
  }

  /// Clear any persisted session snapshots (current or per-day) for [workoutId].
  ///
  /// Used when the workout definition changes so that in-progress drafts don't
  /// refer to stale exercise structures.
  static Future<void> clearSessionsForWorkout(String workoutId) async {
    if (workoutId.isEmpty) return;
    final box = _box;
    final List<dynamic> keysToDelete = <dynamic>[];

    for (final dynamic key in box.keys) {
      final WorkoutSessionState? state = _safeGet(key);
      if (state != null && state.workoutId == workoutId) {
        keysToDelete.add(key);
      } else if (state == null &&
          key is String &&
          key.startsWith('$workoutId|')) {
        keysToDelete.add(key);
      }
    }

    for (final dynamic key in keysToDelete) {
      await box.delete(key);
    }

    final WorkoutSessionState? current = _safeGet(_kCurrentKey);
    if (current != null && current.workoutId == workoutId) {
      await box.delete(_kCurrentKey);
    }
  }

  /// Clear *all* sessions across *all* days for this workout.
  static Future<void> clearAllSessionsForWorkout(String workoutId) async {
    final box = _box;
    final List<dynamic> keysToDelete = <dynamic>[];

    for (final dynamic key in box.keys) {
      final WorkoutSessionState? s = _safeGet(key);
      if (s != null && s.workoutId == workoutId) {
        keysToDelete.add(key);
      }
    }

    for (final dynamic key in keysToDelete) {
      await box.delete(key);
    }

    // Also clear current if it belongs to this workout.
    final WorkoutSessionState? current = _safeGet(_kCurrentKey);
    if (current != null && current.workoutId == workoutId) {
      await box.delete(_kCurrentKey);
    }
  }

  /// Clear the generic "_current" session only.
  static Future<void> clearSession() async {
    final box = _box;
    if (box.containsKey(_kCurrentKey)) {
      await box.delete(_kCurrentKey);
    }
  }

  /// Nukes *all* session snapshots (use sparingly).
  static Future<void> clearAllSessions() async {
    await _box.clear();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Build a stable string key for a workout + day pair.
  /// Example: "abc123|2025-11-21"
  static String _compoundKey(String workoutId, String ymd) => '$workoutId|$ymd';

  static String _normalizeYmd(String ymd) => ymd.replaceAll('-', '');

  /// Convert a [DateTime] into a "YYYY-MM-DD" string.
  ///
  /// This is a convenience helper for callers that only care about the
  /// calendar date portion when working with per-day session keys.
  static String dateTimeToYmd(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Check whether a saved log already exists for this workout on the target day.
  ///
  /// This is wrapped in try/catch so that legacy Map-based entries don't crash
  /// even if they don't expose `workoutId` / `dateYmd` as fields.
  static bool hasLogForWorkoutOnDate({
    required String workoutId,
    required String scheduledDateYmd,
  }) {
    if (workoutId.isEmpty || scheduledDateYmd.isEmpty) return false;

    final String targetYmd = _normalizeYmd(scheduledDateYmd);
    for (final log in WorkoutBoxes.logsBox.values) {
      try {
        final dynamic dyn = log;
        final String? wid = dyn.workoutId as String?;
        if (wid != workoutId) continue;

        final String? storedYmd = dyn.dateYmd as String?;
        if (storedYmd == null) continue;

        if (_normalizeYmd(storedYmd) == targetYmd) {
          return true;
        }
      } catch (_) {
        // Ignore entries that don't match the typed shape.
      }
    }
    return false;
  }

  /// Normalize an ISO-ish date string into "YYYY-MM-DD".
  static String? _extractYmd(String? isoOrYmd) {
    if (isoOrYmd == null || isoOrYmd.isEmpty) return null;

    // If it's already in "YYYY-MM-DD…" form, just take the date slice.
    if (isoOrYmd.length >= 10 && isoOrYmd[4] == '-' && isoOrYmd[7] == '-') {
      return isoOrYmd.substring(0, 10);
    }

    final DateTime? parsed = DateTime.tryParse(isoOrYmd);
    if (parsed == null) return null;

    final String y = parsed.year.toString().padLeft(4, '0');
    final String m = parsed.month.toString().padLeft(2, '0');
    final String d = parsed.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
