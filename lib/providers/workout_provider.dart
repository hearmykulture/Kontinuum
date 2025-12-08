import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/workout_boxes.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';

import 'package:kontinuum/services/analytics_service.dart';
import 'package:kontinuum/core/analytics/analytics_events.dart';

// ⬇️ your PO engine
import 'package:kontinuum/services/po_engine.dart';
import 'package:kontinuum/core/time/app_clock.dart';
import 'package:kontinuum/services/notification_dispatcher.dart';
import 'package:kontinuum/models/app_notification.dart';
import 'package:kontinuum/utils/date_keys.dart';
import 'package:kontinuum/services/workout_progress_service.dart';

/// In-memory state for a single exercise during an active session.
class DraftExerciseState {
  final String exerciseId;
  final List<SetLog> sets;
  bool completed;
  StatDelta statDelta;

  DraftExerciseState({
    required this.exerciseId,
    List<SetLog>? sets,
    this.completed = false,
    StatDelta? statDelta,
  })  : sets = sets ?? <SetLog>[],
        statDelta = statDelta ?? StatDelta();
}

/// Ephemeral “I’m currently training” session.
class SessionDraft {
  final String id;
  final String routineId;
  final String workoutId;
  final String source; // 'dashboard' | 'mission' | 'routine_detail' | etc.
  final String? missionId;
  final DateTime startTime;

  /// The calendar day this session is associated with (midnight-local).
  final DateTime calendarDay;

  /// True if this calendar day is considered a rest day for the routine
  /// according to all attached workout schedules + overrides.
  final bool isRoutineRestDay;

  /// True if this specific workout is scheduled for [calendarDay]
  /// (after honoring rest overrides).
  final bool isWorkoutScheduledForDay;

  /// UI render order
  final List<String> exerciseOrder;

  /// exerciseId -> DraftExerciseState
  final Map<String, DraftExerciseState> exercises;

  bool finished;

  SessionDraft({
    required this.id,
    required this.routineId,
    required this.workoutId,
    required this.source,
    this.missionId,
    required this.startTime,
    required this.calendarDay,
    required this.isRoutineRestDay,
    required this.isWorkoutScheduledForDay,
    required this.exerciseOrder,
    Map<String, DraftExerciseState>? exercises,
    this.finished = false,
  }) : exercises = exercises ?? <String, DraftExerciseState>{};
}

enum SessionStartError {
  missingRoutineSelection,
  routineNotFound,
  workoutNotFound,
}

class SessionStartResult {
  const SessionStartResult._(this.started, this.error, this.message);

  final bool started;
  final SessionStartError? error;
  final String? message;

  factory SessionStartResult.success() =>
      const SessionStartResult._(true, null, null);

  factory SessionStartResult.failure(
    SessionStartError error,
    String message,
  ) {
    return SessionStartResult._(false, error, message);
  }
}

/// bridge so we can call it from here even if MissionProvider is still minimal
extension MissionProviderWorkoutBridge on MissionProvider {
  void markMissionCompleted(String missionId) {
    debugPrint('MissionProvider.markMissionCompleted stub: $missionId');

    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.missionCompleted,
      {'missionId': missionId},
    );
  }
}

class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider(this._objectiveProvider, this._missionProvider) {
    _syncFromHive();
  }

  final ObjectiveProvider _objectiveProvider;
  final MissionProvider _missionProvider;

  // XP goes here after workouts
  static const String _healthCategoryId = 'HEALTH';

  static const List<String> muscleRadarAxes = <String>[
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Core',
    'Glutes',
    'Quads',
    'Hamstrings',
  ];

  static const Map<String, String> _muscleAxisAliases = <String, String>{
    'chest': 'Chest',
    'pecs': 'Chest',
    'pectorals': 'Chest',
    'upper chest': 'Chest',
    'lower chest': 'Chest',
    'back': 'Back',
    'upper back': 'Back',
    'mid back': 'Back',
    'lower back': 'Back',
    'lats': 'Back',
    'latissimus dorsi': 'Back',
    'traps': 'Back',
    'shoulders': 'Shoulders',
    'delts': 'Shoulders',
    'front delts': 'Shoulders',
    'rear delts': 'Shoulders',
    'side delts': 'Shoulders',
    'biceps': 'Arms',
    'triceps': 'Arms',
    'forearms': 'Arms',
    'arms': 'Arms',
    'core': 'Core',
    'abs': 'Core',
    'abdominals': 'Core',
    'obliques': 'Core',
    'glutes': 'Glutes',
    'gluteus maximus': 'Glutes',
    'gluteus medius': 'Glutes',
    'gluteus minimus': 'Glutes',
    'hip flexors': 'Glutes',
    'quads': 'Quads',
    'quadriceps': 'Quads',
    'vastus lateralis': 'Quads',
    'vastus medialis': 'Quads',
    'vastus intermedius': 'Quads',
    'rectus femoris': 'Quads',
    'hamstrings': 'Hamstrings',
    'posterior chain': 'Hamstrings',
    'biceps femoris': 'Hamstrings',
    'semitendinosus': 'Hamstrings',
    'semimembranosus': 'Hamstrings',
    'calves': 'Hamstrings',
    'gastrocnemius': 'Hamstrings',
    'soleus': 'Hamstrings',
  };

  // ---------------------------------------------------------------------------
  // Local caches
  // ---------------------------------------------------------------------------
  List<Routine> _routines = [];
  List<Workout> _workouts = [];
  List<WorkoutLog> _history = [];
  List<WorkoutSchedule> _schedules = [];

  SessionDraft? _activeDraft;

  // ---------------------------------------------------------------------------
  // Public views
  // ---------------------------------------------------------------------------
  UnmodifiableListView<Routine> get routines => UnmodifiableListView(_routines);
  UnmodifiableListView<Workout> get workouts => UnmodifiableListView(_workouts);
  UnmodifiableListView<WorkoutLog> get history =>
      UnmodifiableListView(_history);
  UnmodifiableListView<WorkoutSchedule> get schedules =>
      UnmodifiableListView(_schedules);

  SessionDraft? get activeDraft => _activeDraft;
  SessionInvalidationNotice? _pendingSessionInvalidation;
  SessionInvalidationNotice? consumeSessionInvalidation() {
    final pending = _pendingSessionInvalidation;
    _pendingSessionInvalidation = null;
    return pending;
  }
  Future<void> reloadFromStorage() async {
    _activeDraft = null;
    _syncFromHive();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Hive sync
  // ---------------------------------------------------------------------------
  void _syncFromHive() {
    _routines = WorkoutBoxes.routinesBox.values.toList(growable: false);
    _workouts = WorkoutBoxes.workoutsBox.values.toList(growable: false);
    _history = WorkoutBoxes.logsBox.values.toList(growable: false);
    _schedules = WorkoutBoxes.schedulesBox.values.toList(growable: false);
  }

  Future<void> _saveLog(WorkoutLog log) async {
    debugPrint(
      '[WorkoutProvider] _saveLog() → '
      'id=${log.id}, '
      'workoutId=${log.workoutId}, '
      'dateYmd=${log.dateYmd}, '
      'exerciseCount=${log.exerciseLogs.length}, '
      'volume=${log.totals.volume}',
    );

    // Check if we're overwriting an existing log
    final existing = WorkoutBoxes.logsBox.get(log.id);
    if (existing != null) {
      debugPrint(
        '[WorkoutProvider] ⚠️ OVERWRITING existing log → '
        'existingId=${existing.id}, '
        'existingDate=${existing.dateYmd}, '
        'existingVolume=${existing.totals.volume}',
      );
    }

    await WorkoutBoxes.logsBox.put(log.id, log);

    // Verify what's actually in the box after saving
    final saved = WorkoutBoxes.logsBox.get(log.id);
    debugPrint(
      '[WorkoutProvider] _saveLog() verified → '
      'savedId=${saved?.id}, '
      'savedDate=${saved?.dateYmd}',
    );

    // Debug: print all logs for this workout
    debugPrint('[WorkoutProvider] All logs for workout ${log.workoutId}:');
    for (final l in WorkoutBoxes.logsBox.values) {
      if (l.workoutId == log.workoutId) {
        debugPrint(
          '  - id=${l.id}, date=${l.dateYmd}, volume=${l.totals.volume}',
        );
      }
    }

    _syncFromHive();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ID helper
  // ---------------------------------------------------------------------------
  String _newId() {
    final t = AppClock.now().microsecondsSinceEpoch;
    final r = math.Random().nextInt(99999);
    return '${t}_$r';
  }

  String _generateLogId(String workoutId, String dateYmd) {
    final String base = '${workoutId}_$dateYmd';
    final box = WorkoutBoxes.logsBox;
    if (!box.containsKey(base)) return base;

    int counter = 2;
    String candidate = '${base}_r$counter';
    while (box.containsKey(candidate)) {
      counter++;
      candidate = '${base}_r$counter';
    }
    debugPrint(
      '[WorkoutProvider] Existing log for $base detected, issuing unique id=$candidate',
    );
    return candidate;
  }

  // ---------------------------------------------------------------------------
  // ROUTINE CRUD
  // ---------------------------------------------------------------------------
  Future<Routine> createRoutine({
    required String name,
    required DietSettings diet,
    bool poEnabled = true,
    RestSchedule? restSchedule,
    RepetitionMode scheduleMode = RepetitionMode.weekly,
  }) async {
    final routine = Routine(
      id: _newId(),
      name: name,
      poEnabled: poEnabled,
      diet: diet,
      workoutIds: <String>[],
      createdAtMs: AppClock.now().millisecondsSinceEpoch,
      restSchedule: restSchedule,
      scheduleMode: scheduleMode,
    );
    await WorkoutBoxes.routinesBox.put(routine.id, routine);
    _syncFromHive();
    notifyListeners();
    return routine;
  }

  Future<void> updateRoutine(Routine updated) async {
    await WorkoutBoxes.routinesBox.put(updated.id, updated);
    await SessionPersistenceService.clearSessionsForRoutine(updated);
    _syncFromHive();
    notifyListeners();
  }

  /// hard delete (and keep workouts orphaned for now)
  Future<void> deleteRoutine(String routineId) async {
    await WorkoutBoxes.routinesBox.delete(routineId);
    _syncFromHive();
    notifyListeners();
  }

  /// nicer name for UI → same behavior
  Future<void> removeRoutine(String routineId) async {
    await WorkoutBoxes.routinesBox.delete(routineId);
    _syncFromHive();
    notifyListeners();
  }

  Future<void> addWorkoutToRoutine(String routineId, String workoutId) async {
    final routine = WorkoutBoxes.routinesBox.get(routineId);
    if (routine == null) return;
    if (!routine.workoutIds.contains(workoutId)) {
      routine.workoutIds.add(workoutId);
      await WorkoutBoxes.routinesBox.put(routine.id, routine);
      _syncFromHive();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // WORKOUT CRUD
  // ---------------------------------------------------------------------------
  Future<Workout> createWorkout({
    required String title,
    List<WorkoutBlock>? blocks,
    String? notes,
    String? attachToRoutineId,
    bool isRestTemplate = false,
  }) async {
    final workout = Workout(
      id: _newId(),
      title: title,
      blocks: blocks ?? <WorkoutBlock>[],
      notes: notes,
      isRestTemplate: isRestTemplate,
    );

    await WorkoutBoxes.workoutsBox.put(workout.id, workout);

    if (attachToRoutineId != null && attachToRoutineId.isNotEmpty) {
      await addWorkoutToRoutine(attachToRoutineId, workout.id);
    } else {
      _syncFromHive();
      notifyListeners();
    }

    return workout;
  }

  Future<void> updateWorkout(Workout updated) async {
    await WorkoutBoxes.workoutsBox.put(updated.id, updated);
    final SessionDraft? clearedDraft =
        _activeDraft?.workoutId == updated.id ? _activeDraft : null;
    if (clearedDraft != null) {
      _activeDraft = null;
      _pendingSessionInvalidation =
          SessionInvalidationNotice(workoutId: updated.id, draft: clearedDraft);
    }
    await SessionPersistenceService.clearSessionsForWorkout(updated.id);
    _syncFromHive();
    notifyListeners();
    if (clearedDraft != null) {
      debugPrint(
        '[WorkoutProvider] Active session for workout ${updated.id} cleared due to workout edit.',
      );
    }
  }


  /// central, deep-copy duplication
  Future<Workout> duplicateWorkout({
    required Workout source,
    String? attachToRoutineId,
  }) async {
    final copiedBlocks = source.blocks.map((b) {
      return WorkoutBlock(
        type: b.type,
        title: b.title,
        note: b.note,
        items: b.items.map((it) {
          return WorkoutItem(
            exerciseId: it.exerciseId,
            targetSets: it.targetSets,
            targetReps: it.targetReps,
            targetTimeSec: it.targetTimeSec,
            restSec: it.restSec,
            targetLoad: it.targetLoad,
            notes: it.notes,
            cueChips: List<String>.from(it.cueChips),
            formChecks: List<String>.from(it.formChecks),
            consecutiveMisses: it.consecutiveMisses,
            lastSuggestedLoadKg: it.lastSuggestedLoadKg,
            lastTargetReps: it.lastTargetReps,
            lastLoggedRpe: it.lastLoggedRpe,
            adaptiveSetsEnabled: it.adaptiveSetsEnabled,
            adaptivePercent: it.adaptivePercent,
          );
        }).toList(),
      );
    }).toList();

    final copy = await createWorkout(
      title: '${source.title} (copy)',
      notes: source.notes,
      blocks: copiedBlocks,
      attachToRoutineId: attachToRoutineId,
      isRestTemplate: source.isRestTemplate,
    );

    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.workoutCopied,
      {
        'sourceWorkoutId': source.id,
        'newWorkoutId': copy.id,
        if (attachToRoutineId != null) 'routineId': attachToRoutineId,
      },
    );

    return copy;
  }

  /// convenience: duplicate by id (used by dashboards/routine detail)
  Future<Workout?> duplicateWorkoutById(
    String workoutId, {
    String? attachToRoutineId,
  }) async {
    final original = getWorkoutById(workoutId);
    if (original == null) return null;
    return duplicateWorkout(
      source: original,
      attachToRoutineId: attachToRoutineId,
    );
  }

  Future<void> deleteWorkout(String workoutId) async {
    await WorkoutBoxes.workoutsBox.delete(workoutId);

    for (final r in WorkoutBoxes.routinesBox.values) {
      if (r.workoutIds.remove(workoutId)) {
        await WorkoutBoxes.routinesBox.put(r.id, r);
      }
    }

    _syncFromHive();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // lookups
  // ---------------------------------------------------------------------------
  Routine? getRoutineById(String id) {
    for (final r in _routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  Workout? getWorkoutById(String id) {
    for (final w in _workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  WorkoutLog? getLogById(String id) {
    for (final l in _history) {
      if (l.id == id) return l;
    }
    return null;
  }

  List<WorkoutSchedule> _schedulesForWorkout(String workoutId) {
    if (_schedules.isEmpty) return const <WorkoutSchedule>[];
    return _schedules
        .where((s) => s.workoutId == workoutId)
        .toList(growable: false);
  }

  List<WorkoutSchedule> _schedulesForRoutine(String routineId) {
    final routine = getRoutineById(routineId);
    if (routine == null || routine.workoutIds.isEmpty) {
      return const <WorkoutSchedule>[];
    }
    final ids = Set<String>.from(routine.workoutIds);
    return _schedules
        .where((s) => ids.contains(s.workoutId))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // REST-DAY AWARE HELPERS
  // ---------------------------------------------------------------------------

  /// Global one-off rest override:
  /// Returns true if this [date] is currently flagged as a one-off rest day
  /// (e.g. via "Skip workout today"), *and* the day has not already passed.
  bool _isGlobalRestOverrideActiveFor(DateTime date) {
    final now = AppClock.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    // Once the calendar day has passed, treat overrides as expired at the
    // provider level even if the raw entry still exists on disk.
    if (d.isBefore(today)) {
      return false;
    }

    return WorkoutBoxes.hasRestOverrideFor(d);
  }

  /// Public helper: does this calendar day have a one-off rest override?
  bool hasOneOffRestOverride(DateTime date) {
    return _isGlobalRestOverrideActiveFor(date);
  }

  /// Returns true if this specific [workoutId] is scheduled to be performed
  /// on [date], honoring per-workout rest schedule and global one-off rest
  /// overrides (skip-today).
  bool isWorkoutScheduledForDay(String workoutId, DateTime date) {
    // Global one-off skip wins over per-workout schedule.
    if (_isGlobalRestOverrideActiveFor(date)) {
      return false;
    }

    final schedules = _schedulesForWorkout(workoutId);
    if (schedules.isEmpty) return false;

    for (final schedule in schedules) {
      final bool workout = schedule.isPrescribedFor(date);
      final bool rest = schedule.isRestDay(date);
      if (workout && !rest) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if *any* workout belonging to [routineId] is scheduled
  /// to be performed on [date], honoring rest overrides.
  bool isAnyWorkoutScheduledForRoutineOn(String routineId, DateTime date) {
    // Global one-off skip wins here as well.
    if (_isGlobalRestOverrideActiveFor(date)) {
      return false;
    }

    final routine = getRoutineById(routineId);
    if (routine == null) return false;
    for (final workoutId in routine.workoutIds) {
      if (isWorkoutScheduledForDay(workoutId, date)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if [date] should be treated as a *rest* day for this routine.
  ///
  /// Logic:
  ///   - If a global one-off rest override exists for [date] → true.
  ///   - If the routine has no schedules at all → returns false (no schedule data).
  ///   - If any attached workout schedule marks the day as a non-rest
  ///     workout day (prescribed + not overridden as rest) → false.
  ///   - Otherwise:
  ///       • If at least one schedule marks the date as a rest day (override
  ///         or implicit) → true.
  ///       • If no schedules fire at all on that date → true (off day = rest).
  bool isRestDay(String routineId, DateTime date) {
    // Global one-off skip wins immediately and does not mutate schedules.
    if (_isGlobalRestOverrideActiveFor(date)) {
      return true;
    }

    final routine = getRoutineById(routineId);
    final RestSchedule? routineRest = routine?.restSchedule;
    final bool? restFromRoutine =
        routineRest != null ? routineRest.isRestOn(date) : null;

    final routineSchedules = _schedulesForRoutine(routineId);
    if (routineSchedules.isEmpty) {
      // If there's no per-workout schedule data, defer to the routine-level
      // rest schedule (if any). Otherwise treat as unscheduled (non-rest).
      return restFromRoutine ?? false;
    }

    bool anyWorkout = false;
    bool anyScheduleSeen = false;
    bool anyRest = false;

    for (final schedule in routineSchedules) {
      anyScheduleSeen = true;
      final bool workout = schedule.isPrescribedFor(date);
      final bool rest = schedule.isRestDay(date);

      if (workout && !rest) {
        anyWorkout = true;
      }
      if (rest) {
        anyRest = true;
      }
    }

    // Explicit routine rest schedule overrides per-workout inference.
    if (restFromRoutine != null) {
      return restFromRoutine;
    }

    if (anyWorkout) return false;
    if (!anyScheduleSeen) return false;

    // If nothing is scheduled and nothing overrides → it's a rest day.
    if (!anyRest && !anyWorkout) return true;

    // Only rest overrides (or implicit rests) remained.
    return anyRest || !anyWorkout;
  }

  /// Convenience wrapper for int day-id.
  bool isRestDayYmd(String routineId, int dayId) {
    final d = DateTime(
      dayId ~/ 10000,
      (dayId % 10000) ~/ 100,
      dayId % 100,
    );
    return isRestDay(routineId, d);
  }

  /// Set / clear a *per-workout* rest override for a specific calendar day.
  ///
  /// NOTE: With the current model, we only support *global* one-off rest
  /// overrides. For now:
  ///   - isRest == true  → mark this calendar day as a one-off rest day
  ///                       (via [skipWorkoutForDay]).
  ///   - isRest == false or null → no-op; repeating schedule remains as-is.
  Future<void> setRestOverrideForWorkout({
    required String workoutId,
    required DateTime date,
    required bool? isRest,
  }) async {
    if (isRest == true) {
      await skipWorkoutForDay(
        date: date,
        source: 'per_workout_override',
        reason: 'per-workout rest toggle',
      );
    } else {
      debugPrint(
        '[WorkoutProvider] setRestOverrideForWorkout($workoutId, $date, '
        'isRest=$isRest) → no-op (only global one-off rest supported currently)',
      );
    }
  }

  /// Convenience: set a rest override for *all* workouts in a routine.
  Future<void> setRestOverrideForRoutine({
    required String routineId,
    required DateTime date,
    required bool? isRest,
  }) async {
    final routine = getRoutineById(routineId);
    if (routine == null) return;
    for (final workoutId in routine.workoutIds) {
      await setRestOverrideForWorkout(
        workoutId: workoutId,
        date: date,
        isRest: isRest,
      );
    }
  }

  /// Mark a specific calendar [date] as a one-off rest override
  /// (e.g. "Skip workout today") without mutating repeating schedules.
  ///
  /// Dashboards should consult [hasOneOffRestOverride] / [isRestDay] /
  /// [isWorkoutScheduledForDay] to respect this until the day passes.
  Future<void> skipWorkoutForDay({
    required DateTime date,
    String source = 'dashboard',
    String? reason,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);

    await WorkoutBoxes.upsertRestOverrideFor(
      normalized,
      source: source,
      reason: reason,
    );
    await SessionPersistenceService.clearSessionsForDate(normalized);

    AnalyticsService.instance.log(
      'workout_skip_today',
      {
        'dateYmd': _formatYmd(normalized),
        'source': source,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Notifications (schedule-based)
  // ---------------------------------------------------------------------------
  Future<void> emitScheduleNotifications({
    required String routineId,
    DateTime? now,
  }) async {
    final DateTime today = DateKeys.dateOnly(now ?? AppClock.now());
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    await _emitRestDayReminder(routineId: routineId, day: today);
    await _emitMissedWorkout(routineId: routineId, day: yesterday);
  }

  Future<void> _emitRestDayReminder({
    required String routineId,
    required DateTime day,
  }) async {
    if (!isRestDay(routineId, day)) return;
    final groupKey = 'rest_day_${_formatYmd(day)}';
    if (_hasNotificationWithGroup(groupKey)) return;

    await NotificationDispatcher.add(
      NotificationItem(
        id: 'rest_${_formatYmd(day)}',
        module: NotificationModule.workouts,
        kind: NotificationKind.restDayReminder,
        title: 'Rest day',
        detail: 'Log recovery or mobility',
        meta: 'Today',
        severity: NotificationSeverity.nonCritical,
        groupKey: groupKey,
        actions: const [
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
          NotificationAction(
            label: 'Dismiss',
            type: NotificationActionType.dismiss,
          ),
        ],
      ),
    );
  }

  Future<void> _emitMissedWorkout({
    required String routineId,
    required DateTime day,
  }) async {
    final prescribed = WorkoutProgressService.getPrescribedWorkouts(
      routineId: routineId,
      date: day,
    );
    if (prescribed.isEmpty) return;
    final completed = <String>{};
    for (final String wid in prescribed) {
      if (_isWorkoutCompletedOnDate(wid, day)) {
        completed.add(wid);
      }
    }
    final missing = prescribed.where((wid) => !completed.contains(wid)).toList();
    if (missing.isEmpty) return;

    final groupKey = 'missed_${_formatYmd(day)}';
    if (_hasNotificationWithGroup(groupKey)) return;

    await NotificationDispatcher.add(
      NotificationItem(
        id: 'missed_${_formatYmd(day)}',
        module: NotificationModule.workouts,
        kind: NotificationKind.missedWorkout,
        title: missing.length > 1
            ? '${missing.length} workouts missed'
            : 'Workout missed',
        detail: 'Catch up from ${DateFormat.MMMd().format(day)}',
        meta: 'Missed ${missing.length}/${prescribed.length}',
        severity: NotificationSeverity.nonCritical,
        groupKey: groupKey,
        actions: const [
          NotificationAction(
            label: 'Reschedule',
            type: NotificationActionType.reschedule,
          ),
          NotificationAction(
            label: 'Dismiss',
            type: NotificationActionType.dismiss,
          ),
        ],
        payload: {
          'routineId': routineId,
          'workoutIds': missing,
          'dateYmd': _formatYmd(day),
        },
      ),
    );
  }

  bool _isWorkoutCompletedOnDate(String workoutId, DateTime day) {
    try {
      for (final log in WorkoutBoxes.logsBox.values) {
        if (log is! WorkoutLog) continue;
        if (log.workoutId != workoutId) continue;
        final parsed = DateTime.tryParse(log.dateYmd);
        if (parsed == null) continue;
        final normalized = DateTime(parsed.year, parsed.month, parsed.day);
        if (normalized == day && log.exerciseLogs.isNotEmpty) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  bool _hasNotificationWithGroup(String groupKey) {
    final center = NotificationDispatcher.center;
    if (center == null) return false;
    return center.activeNotifications.any((n) => n.groupKey == groupKey) ||
        center.queuedNotifications.any((n) => n.groupKey == groupKey);
  }

  /// Convenience wrapper for skipping *today* from UI.
  Future<void> skipWorkoutToday({
    String source = 'dashboard',
    String? reason,
  }) async {
    await skipWorkoutForDay(
      date: AppClock.now(),
      source: source,
      reason: reason,
    );
  }

  // ---------------------------------------------------------------------------
  // SESSION LIFECYCLE
  // ---------------------------------------------------------------------------
  List<String> _extractExerciseOrder(Workout workout) {
    final ordered = <String>[];
    for (final block in workout.blocks) {
      for (final item in block.items) {
        if (!ordered.contains(item.exerciseId)) {
          ordered.add(item.exerciseId);
        }
      }
    }
    return ordered;
  }

  SessionStartResult startSession({
    required String routineId,
    required String workoutId,
    String source = 'dashboard',
    String? missionId,
    DateTime? calendarDayOverride,
  }) {
    if (routineId.isEmpty) {
      debugPrint(
        '[WorkoutProvider] startSession blocked: no routine selected for workout $workoutId',
      );
      return SessionStartResult.failure(
        SessionStartError.missingRoutineSelection,
        'Select a routine before starting this workout.',
      );
    }
    final Routine? maybeRoutine = WorkoutBoxes.routinesBox.get(routineId);
    if (maybeRoutine == null) {
      debugPrint(
        '[WorkoutProvider] startSession blocked: routine $routineId not found for workout $workoutId',
      );
      return SessionStartResult.failure(
        SessionStartError.routineNotFound,
        'That routine is no longer available.',
      );
    }
    final workout = WorkoutBoxes.workoutsBox.get(workoutId);
    if (workout == null) {
      debugPrint('⚠️ WorkoutProvider.startSession: bad workout ID');
      return SessionStartResult.failure(
        SessionStartError.workoutNotFound,
        'This workout could not be found.',
      );
    }
    final Routine routine = maybeRoutine;

    final now = AppClock.now();
    final DateTime baseDay = calendarDayOverride ?? now;
    final DateTime calendarDay =
        DateTime(baseDay.year, baseDay.month, baseDay.day);

    final bool routineRest = isRestDay(routine.id, calendarDay);
    final bool workoutScheduled = isWorkoutScheduledForDay(
      workoutId,
      calendarDay,
    );

    _activeDraft = SessionDraft(
      id: _newId(),
      routineId: routine.id,
      workoutId: workoutId,
      source: source,
      missionId: missionId,
      startTime: now,
      calendarDay: calendarDay,
      isRoutineRestDay: routineRest,
      isWorkoutScheduledForDay: workoutScheduled,
      exerciseOrder: _extractExerciseOrder(workout),
    );
    notifyListeners();

    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.sessionStarted,
      {
        'routineId': routineId,
        'workoutId': workoutId,
        'source': source,
        if (missionId != null) 'missionId': missionId,
        'isRoutineRestDay': routineRest,
        'isWorkoutScheduledForDay': workoutScheduled,
      },
    );

    NotificationDispatcher.add(
      NotificationItem(
        id: 'session_${workout.id}',
        module: NotificationModule.workouts,
        kind: NotificationKind.sessionInProgress,
        title: 'Session in progress',
        detail: workout.title,
        meta: 'Started now',
        severity: NotificationSeverity.nonCritical,
        createdAt: now,
        groupKey: 'session_${workout.id}',
        actions: [
          NotificationAction(
            label: 'Resume',
            type: NotificationActionType.resume,
            payload: {
              'routineId': routineId,
              'workoutId': workoutId,
              'dateYmd': _formatYmd(calendarDay),
            },
          ),
          NotificationAction(
            label: 'End',
            type: NotificationActionType.end,
            payload: {
              'workoutId': workoutId,
              'routineId': routineId,
              'dateYmd': _formatYmd(calendarDay),
            },
          ),
        ],
        payload: {
          'routineId': routineId,
          'workoutId': workoutId,
          'dateYmd': _formatYmd(calendarDay),
        },
        expiresAt: now.add(const Duration(hours: 6)),
      ),
    );

    return SessionStartResult.success();
  }

  /// recreate a session from a past log (used by history/summary “repeat”)
  void startSessionFromLog(
    WorkoutLog log, {
    String source = 'history',
  }) {
    final order = <String>[
      for (final e in log.exerciseLogs) e.exerciseId,
    ];

    final exercises = <String, DraftExerciseState>{
      for (final e in log.exerciseLogs)
        e.exerciseId: DraftExerciseState(
          exerciseId: e.exerciseId,
          // start empty, user will log again
          sets: const [],
          completed: false,
        ),
    };

    DateTime calendarDay = AppClock.now();
    final parsed = _parseYmd(log.dateYmd);
    if (parsed != null) {
      calendarDay = DateTime(parsed.year, parsed.month, parsed.day);
    }

    final bool routineRest = isRestDay(log.routineId, calendarDay);
    final bool workoutScheduled =
        isWorkoutScheduledForDay(log.workoutId, calendarDay);

    _activeDraft = SessionDraft(
      id: _newId(),
      routineId: log.routineId,
      workoutId: log.workoutId,
      source: source,
      missionId: log.missionId,
      startTime: AppClock.now(),
      calendarDay: calendarDay,
      isRoutineRestDay: routineRest,
      isWorkoutScheduledForDay: workoutScheduled,
      exerciseOrder: order,
      exercises: exercises,
    );

    notifyListeners();

    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.sessionStarted,
      {
        'routineId': log.routineId,
        'workoutId': log.workoutId,
        'source': source,
        'fromLog': true,
        'isRoutineRestDay': routineRest,
        'isWorkoutScheduledForDay': workoutScheduled,
      },
    );
  }

  void clearActiveSession() {
    if (_activeDraft == null) return;
    _activeDraft = null;
    notifyListeners();
  }

  void logSet({
    required String exerciseId,
    required int? reps,
    required double? load,
    required double? rpe,
    String? notes,
  }) {
    final draft = _activeDraft;
    if (draft == null) return;

    final exerciseState = draft.exercises[exerciseId] ??
        DraftExerciseState(exerciseId: exerciseId);

    exerciseState.sets.add(
      SetLog(
        reps: reps,
        load: load,
        rpe: rpe,
        notes: notes,
        tsMs: AppClock.now().millisecondsSinceEpoch,
      ),
    );

    draft.exercises[exerciseId] = exerciseState;

    // record in recents so picker shows it
    ExerciseLibraryService.instance.recordRecent(exerciseId);

    notifyListeners();

    // base analytics
    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.setSaved,
      {
        'exerciseId': exerciseId,
        'reps': reps,
        'load': load,
        'rpe': rpe,
      },
    );
  }

  StatDelta completeExercise(String exerciseId) {
    final draft = _activeDraft;
    if (draft == null) return StatDelta();

    final state = draft.exercises[exerciseId];
    if (state == null) {
      final newState = DraftExerciseState(
        exerciseId: exerciseId,
        completed: true,
        statDelta: _calcStatDeltaForExercise(exerciseId),
      );
      draft.exercises[exerciseId] = newState;
      notifyListeners();

      AnalyticsService.instance.log(
        WorkoutAnalyticsEvents.exerciseCompleted,
        {'exerciseId': exerciseId},
      );

      return newState.statDelta;
    }

    if (!state.completed) {
      state.completed = true;
      state.statDelta = _calcStatDeltaForExercise(exerciseId);
      notifyListeners();

      AnalyticsService.instance.log(
        WorkoutAnalyticsEvents.exerciseCompleted,
        {'exerciseId': exerciseId},
      );
    }

    return state.statDelta;
  }

  StatDelta _calcStatDeltaForExercise(String exerciseId) {
    final ex = ExerciseLibraryService.instance.getById(exerciseId);
    if (ex == null) {
      return StatDelta();
    }

    switch (ex.intent) {
      case ExerciseIntent.strength:
        return StatDelta(strength: 3);
      case ExerciseIntent.hypertrophy:
        return StatDelta(hypertrophy: 2);
      case ExerciseIntent.mobility:
        return StatDelta(mobility: 1);
      case ExerciseIntent.endurance:
      case ExerciseIntent.conditioning:
        return StatDelta(endurance: 1);
    }
  }

  /// Public helper so other layers can estimate XP gains for a given exercise.
  StatDelta statDeltaForExercise(String exerciseId) {
    return _calcStatDeltaForExercise(exerciseId);
  }

  int computeXpFromStatDelta(StatDelta delta) {
    return delta.strength +
        delta.hypertrophy +
        delta.endurance +
        delta.mobility;
  }

  // Helper: canonical ymd string "yyyyMMdd"
  String _formatYmd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// Flexible parser for date-ish strings: "yyyyMMdd", "yyyy-MM-dd",
  /// or full ISO like "2025-11-20T03:12:00Z".
  DateTime? _parseYmdFlexible(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // "yyyyMMdd"
    if (s.length == 8 && !s.contains('-') && !s.contains('/')) {
      final y = int.tryParse(s.substring(0, 4));
      final m = int.tryParse(s.substring(4, 6));
      final d = int.tryParse(s.substring(6, 8));
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }

    // "yyyy-MM-dd" or ISO; DateTime will handle both.
    final parsed = DateTime.tryParse(s);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return null;
  }

  Future<WorkoutLog?> finishSession() async {
    final draft = _activeDraft;
    if (draft == null) return null;
    if (draft.finished) return null;
    draft.finished = true;

    final exerciseLogs = <ExerciseLog>[];
    StatDelta sessionStatDelta = StatDelta();
    double totalVolume = 0;
    int totalPrs = 0;

    debugPrint(
      '[WorkoutProvider] finishSession() → draft.exercises.length=${draft.exercises.length}',
    );

    draft.exercises.forEach((exerciseId, state) {
      debugPrint(
        '[WorkoutProvider]   - exerciseId=$exerciseId, sets.length=${state.sets.length}',
      );
      double vol = 0;
      for (final s in state.sets) {
        vol += (s.load ?? 0) * (s.reps ?? 0);
        debugPrint(
          '[WorkoutProvider]     - set: load=${s.load}, reps=${s.reps}, vol=${(s.load ?? 0) * (s.reps ?? 0)}',
        );
      }
      totalVolume += vol;
      sessionStatDelta = sessionStatDelta + state.statDelta;

      exerciseLogs.add(
        ExerciseLog(
          exerciseId: exerciseId,
          sets: state.sets,
          volume: vol,
          prFlags: const <String>[],
          statDelta: state.statDelta,
        ),
      );
    });

    final now = AppClock.now();

    // Resolve the calendar day this session should count toward using the
    // draft’s bound calendarDay.
    final DateTime effectiveDay = DateTime(
      draft.calendarDay.year,
      draft.calendarDay.month,
      draft.calendarDay.day,
    );
    final String dateYmd = _formatYmd(effectiveDay);

    debugPrint(
      '[WorkoutProvider] finishSession() resolved day → '
      'effectiveDay=$effectiveDay, dateYmd=$dateYmd',
    );

    // Generate unique log ID per completion: workoutId + date (+ suffix for repeats)
    final String logId = _generateLogId(draft.workoutId, dateYmd);

    debugPrint(
      '[WorkoutProvider] finishSession() → '
      'workoutId=${draft.workoutId}, '
      'dateYmd=$dateYmd, '
      'logId=$logId, '
      'exerciseCount=${exerciseLogs.length}, '
      'totalVolume=$totalVolume',
    );

    final log = WorkoutLog(
      id: logId,
      routineId: draft.routineId,
      workoutId: draft.workoutId,
      dateYmd: dateYmd,
      exerciseLogs: exerciseLogs,
      totals: SessionTotals(
        volume: totalVolume,
        timeSec: now.difference(draft.startTime).inSeconds,
        prCount: totalPrs,
        statDeltas: sessionStatDelta,
      ),
      source: draft.source,
      missionId: draft.missionId,
    );

    // persist
    await _saveLog(log);

    // push PO back on workout
    final routine = getRoutineById(log.routineId);
    final workout = getWorkoutById(log.workoutId);
    if (routine != null && workout != null) {
      await _applyPoUpdatesFromLog(
        routine: routine,
        workout: workout,
        log: log,
      );
    }

    // XP / streak / mission
    final xpAward = computeXpFromStatDelta(sessionStatDelta);
    try {
      _objectiveProvider.addXpToCategory(_healthCategoryId, xpAward);
    } catch (err, st) {
      debugPrint('⚠️ addXpToCategory failed: $err\n$st');
    }

    if (draft.missionId != null && draft.missionId!.trim().isNotEmpty) {
      try {
        _missionProvider.markMissionCompleted(draft.missionId!);
      } catch (err, st) {
        debugPrint('⚠️ markMissionCompleted failed: $err\n$st');
      }
    }

    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.sessionCompleted,
      {
        'routineId': draft.routineId,
        'workoutId': draft.workoutId,
        'missionId': draft.missionId,
        'volume': totalVolume,
        'timeSec': now.difference(draft.startTime).inSeconds,
        'xpAward': xpAward,
        'prCount': totalPrs,
        'exerciseCount': exerciseLogs.length,
      },
    );

    await NotificationDispatcher.dismiss('session_${draft.workoutId}');
    _activeDraft = null;

    // Clear both the scoped session (workout+day) and the generic pointer now
    // that the log is written, so no “Resume” badge lingers after completion.
    try {
      await SessionPersistenceService.clearSessionFor(
        workoutId: draft.workoutId,
        scheduledDateYmd: dateYmd,
      );
      await SessionPersistenceService.clearSession();
      debugPrint(
        '[WorkoutProvider] finishSession() cleared persisted session '
        'for workout ${draft.workoutId} on $dateYmd',
      );
    } catch (e, st) {
      debugPrint(
        '[WorkoutProvider] finishSession() error clearing session: $e\n$st',
      );
    }

    notifyListeners();
    return log;
  }

  // ---------------------------------------------------------------------------
  // EXTRA HELPERS FOR UI (from session_screen.dart)
  // ---------------------------------------------------------------------------

  /// UI calls this right after saving a set in the bottom sheet.
  void emitSetSavedEvent({
    required String exerciseId,
    int? reps,
    double? load,
    double? rpe,
  }) {
    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.setSaved,
      {
        'exerciseId': exerciseId,
        'reps': reps,
        'load': load,
        'rpe': rpe,
        'source': 'session_ui',
      },
    );
  }

  /// UI calls this right after marking an exercise complete.
  void emitExerciseCompletedEvent({
    required String exerciseId,
    required StatDelta delta,
  }) {
    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.exerciseCompleted,
      {
        'exerciseId': exerciseId,
        'strength': delta.strength,
        'hypertrophy': delta.hypertrophy,
        'endurance': delta.endurance,
        'mobility': delta.mobility,
        'source': 'session_ui',
      },
    );
  }

  /// UI calls this when it wants to repeat a workout but swap 1 exercise.
  void swapExerciseInActiveDraft({
    required String oldExerciseId,
    required String newExerciseId,
  }) {
    final draft = _activeDraft;
    if (draft == null) return;

    final idx = draft.exerciseOrder.indexOf(oldExerciseId);
    if (idx == -1) return;

    // 1) replace in order
    draft.exerciseOrder[idx] = newExerciseId;

    // 2) carry over state if present
    final oldState = draft.exercises[oldExerciseId];
    if (oldState != null) {
      draft.exercises[newExerciseId] = DraftExerciseState(
        exerciseId: newExerciseId,
        sets: oldState.sets,
        completed: oldState.completed,
        statDelta: oldState.statDelta,
      );
      draft.exercises.remove(oldExerciseId);
    } else {
      draft.exercises.putIfAbsent(
        newExerciseId,
        () => DraftExerciseState(exerciseId: newExerciseId),
      );
    }

    // 3) record in recents so library picker surfaces it
    ExerciseLibraryService.instance.recordRecent(newExerciseId);

    notifyListeners();
  }

  /// NEW: session can append a brand-new exercise (from library) to the draft.
  void addExerciseToActiveDraft(String exerciseId) {
    final draft = _activeDraft;
    if (draft == null) return;

    // append to order if not already there
    if (!draft.exerciseOrder.contains(exerciseId)) {
      draft.exerciseOrder.add(exerciseId);
    }

    // ensure state exists
    draft.exercises.putIfAbsent(
      exerciseId,
      () => DraftExerciseState(exerciseId: exerciseId),
    );

    // surface in recents
    ExerciseLibraryService.instance.recordRecent(exerciseId);

    notifyListeners();

    // log with a generic name so we don't break if the constant doesn't exist
    AnalyticsService.instance.log(
      'workout_exercise_added_to_session',
      {'exerciseId': exerciseId},
    );
  }

  /// UI calls this after navigator → Summary so we know where it came from.
  void emitSessionCompletedEvent({
    required double volume,
    required int timeSec,
    required StatDelta statDeltas,
    required String source,
  }) {
    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.sessionCompleted,
      {
        'volume': volume,
        'timeSec': timeSec,
        'source': source,
        'strength': statDeltas.strength,
        'hypertrophy': statDeltas.hypertrophy,
        'endurance': statDeltas.endurance,
        'mobility': statDeltas.mobility,
        'from': 'session_screen',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PO write-back
  // ---------------------------------------------------------------------------
  Future<void> _applyPoUpdatesFromLog({
    required Routine routine,
    required Workout workout,
    required WorkoutLog log,
  }) async {
    // PO off? do nothing
    if (!routine.poEnabled) return;

    // index today's performed exercises
    final Map<String, ExerciseLog> logsByExerciseId = {
      for (final e in log.exerciseLogs) e.exerciseId: e,
    };

    bool workoutChanged = false;

    for (final block in workout.blocks) {
      for (final item in block.items) {
        final exLog = logsByExerciseId[item.exerciseId];
        if (exLog == null) {
          // didn’t perform → we could soft-miss later
          continue;
        }

        final preview = ProgressiveOverloadEngine.computeNextTarget(
          poEnabled: true,
          item: item,
          performedSets: exLog.sets,
        );

        // 1) next load
        if (preview.nextLoadKg != null) {
          item.lastSuggestedLoadKg = preview.nextLoadKg;
        }
        // 2) next reps
        if (preview.nextRepsTarget != null) {
          item.lastTargetReps = preview.nextRepsTarget;
        }
        // 3) consecutive misses (non-nullable in your model)
        final currentMisses = item.consecutiveMisses;
        switch (preview.status) {
          case PoStatus.progress:
            item.consecutiveMisses = 0;
            break;
          case PoStatus.hold:
            item.consecutiveMisses = currentMisses;
            break;
          case PoStatus.deload:
            item.consecutiveMisses = currentMisses + 1;
            break;
        }

        workoutChanged = true;
      }
    }

    if (workoutChanged) {
      await WorkoutBoxes.workoutsBox.put(workout.id, workout);
      _syncFromHive();
      notifyListeners();
      // could emit a PO-updated event here later
    }
  }

  // ---------------------------------------------------------------------------
  // library passthrough
  // ---------------------------------------------------------------------------
  List<Exercise> libraryAll() => ExerciseLibraryService.instance.allExercises();

  List<Exercise> libraryFilter({
    List<String>? muscles,
    List<String>? equipment,
    ExerciseDifficulty? difficulty,
    ExerciseIntent? intent,
    String? query,
  }) {
    return ExerciseLibraryService.instance.filter(
      muscles: muscles,
      equipment: equipment,
      difficulty: difficulty,
      intent: intent,
      query: query,
    );
  }

  List<Exercise> libraryFavorites() =>
      ExerciseLibraryService.instance.favorites();

  List<Exercise> libraryRecents() => ExerciseLibraryService.instance.recents();

  void favoriteExercise(String exerciseId) {
    ExerciseLibraryService.instance.favoriteExercise(exerciseId);
    notifyListeners();
  }

  List<Exercise> similarExercises(String exerciseId) =>
      ExerciseLibraryService.instance.similarTo(exerciseId);

  // ---------------------------------------------------------------------------
  // PO preview for current draft
  // ---------------------------------------------------------------------------
  Map<String, PoPreview> buildPoPreviewForDraft() {
    final draft = _activeDraft;
    if (draft == null) return const <String, PoPreview>{};

    final routine = getRoutineById(draft.routineId);
    final workout = getWorkoutById(draft.workoutId);
    if (routine == null || workout == null) {
      return const <String, PoPreview>{};
    }

    final bool poEnabled = routine.poEnabled;
    final out = <String, PoPreview>{};

    // current in-progress sets
    final Map<String, List<SetLog>> setsByExercise = {
      for (final entry in draft.exercises.entries) entry.key: entry.value.sets,
    };

    for (final block in workout.blocks) {
      for (final item in block.items) {
        final sets = setsByExercise[item.exerciseId] ?? const <SetLog>[];
        final preview = ProgressiveOverloadEngine.computeNextTarget(
          poEnabled: poEnabled,
          item: item,
          performedSets: sets,
        );
        out[item.exerciseId] = preview;
      }
    }

    return out;
  }

  // ---------------------------------------------------------------------------
  // Muscle coverage aggregation
  // ---------------------------------------------------------------------------

  String? _axisForMuscle(String raw) {
    final key = raw.toLowerCase().trim();
    final direct = _muscleAxisAliases[key];
    if (direct != null) return direct;

    if (key.contains('chest') || key.contains('pec')) return 'Chest';
    if (key.contains('lat') || key.contains('back') || key.contains('trap')) {
      return 'Back';
    }
    if (key.contains('shoulder') || key.contains('delt')) return 'Shoulders';
    if (key.contains('bicep') ||
        key.contains('tricep') ||
        key.contains('arm') ||
        key.contains('forearm')) {
      return 'Arms';
    }
    if (key.contains('core') ||
        key.contains('abs') ||
        key.contains('oblique') ||
        key.contains('torso')) {
      return 'Core';
    }
    if (key.contains('glute') || key.contains('hip')) return 'Glutes';
    if (key.contains('quad') ||
        key.contains('vastus') ||
        key.contains('rectus')) {
      return 'Quads';
    }
    if (key.contains('hamstring') ||
        key.contains('posterior') ||
        key.contains('calf') ||
        key.contains('gastrocnemius') ||
        key.contains('soleus')) {
      return 'Hamstrings';
    }
    return null;
  }

  void _accumulateMuscleLoad({
    required Map<String, double> totals,
    required Exercise exercise,
    double weightMultiplier = 1.0,
  }) {
    const double primaryWeight = 1.0;
    const double secondaryWeight = 0.5;
    const double fallbackWeight = 0.75;

    bool tracked = false;

    for (final muscle in exercise.primaryMuscles) {
      final axis = _axisForMuscle(muscle);
      if (axis == null) continue;
      totals[axis] = (totals[axis] ?? 0.0) + primaryWeight * weightMultiplier;
      tracked = true;
    }

    for (final muscle in exercise.secondaryMuscles) {
      final axis = _axisForMuscle(muscle);
      if (axis == null) continue;
      totals[axis] = (totals[axis] ?? 0.0) + secondaryWeight * weightMultiplier;
      tracked = true;
    }

    if (!tracked) {
      for (final muscle in exercise.muscles) {
        final axis = _axisForMuscle(muscle);
        if (axis == null) continue;
        totals[axis] =
            (totals[axis] ?? 0.0) + fallbackWeight * weightMultiplier;
      }
    }
  }

  Map<String, double> muscleCoverageForRoutine(
    String routineId, {
    bool normalize = true,
  }) {
    final totals = <String, double>{
      for (final axis in muscleRadarAxes) axis: 0.0,
    };

    final routine = getRoutineById(routineId);
    if (routine == null) {
      return Map<String, double>.unmodifiable(totals);
    }

    final SessionDraft? draft =
        _activeDraft != null && _activeDraft!.routineId == routineId
            ? _activeDraft
            : null;
    final Set<String> sessionExercises = <String>{};

    if (draft != null) {
      for (final exerciseId in draft.exerciseOrder) {
        final exercise = ExerciseLibraryService.instance.getById(exerciseId);
        if (exercise == null) continue;
        sessionExercises.add(exerciseId);
        final state = draft.exercises[exerciseId];
        final double multiplier = state != null && state.sets.isNotEmpty
            ? state.sets.length.toDouble()
            : 1.0;
        _accumulateMuscleLoad(
          totals: totals,
          exercise: exercise,
          weightMultiplier: multiplier,
        );
      }
    }

    for (final workoutId in routine.workoutIds) {
      final workout = getWorkoutById(workoutId);
      if (workout == null) continue;

      final bool skipSessionExercise =
          draft != null && draft.workoutId == workout.id;

      for (final block in workout.blocks) {
        for (final item in block.items) {
          if (skipSessionExercise &&
              sessionExercises.contains(item.exerciseId)) {
            continue;
          }
          final exercise =
              ExerciseLibraryService.instance.getById(item.exerciseId);
          if (exercise == null) continue;

          final double multiplier =
              item.targetSets > 0 ? item.targetSets.toDouble() : 1.0;
          _accumulateMuscleLoad(
            totals: totals,
            exercise: exercise,
            weightMultiplier: multiplier,
          );
        }
      }
    }

    if (!normalize) {
      return Map<String, double>.unmodifiable(totals);
    }

    final double maxLoad = totals.values.fold<double>(
      0,
      (prev, value) => value > prev ? value : prev,
    );
    if (maxLoad <= 0) {
      return Map<String, double>.unmodifiable(totals);
    }

    final normalized = <String, double>{
      for (final entry in totals.entries)
        entry.key: (entry.value / maxLoad).clamp(0.0, 1.0),
    };

    return Map<String, double>.unmodifiable(normalized);
  }

  // ---------------------------------------------------------------------------
  // 🔥 Derived metrics / streaks / quick aggregates
  // ---------------------------------------------------------------------------

  /// Flexible parser for log.dateYmd which may be "yyyyMMdd", "yyyy-MM-dd",
  /// or something ISO-like.
  DateTime? _parseYmd(String ymdStr) {
    return _parseYmdFlexible(ymdStr);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Total volume across all time (whatever unit your logs are in right now).
  double get totalVolumeAllTime {
    return _history.fold<double>(
      0,
      (sum, log) => sum + log.totals.volume,
    );
  }

  /// Sessions done in the last [days] (default 7).
  int sessionsLastNDays([int days = 7]) {
    final now = AppClock.now();
    final cutoff = now.subtract(Duration(days: days));
    int count = 0;
    for (final log in _history) {
      final dt = _parseYmd(log.dateYmd);
      if (dt == null) continue;
      if (dt.isAfter(cutoff) || _isSameDay(dt, cutoff)) {
        count++;
      }
    }
    return count;
  }

  /// Volume done in the last [days] (default 7).
  double volumeLastNDays([int days = 7]) {
    final now = AppClock.now();
    final cutoff = now.subtract(Duration(days: days));
    double vol = 0;
    for (final log in _history) {
      final dt = _parseYmd(log.dateYmd);
      if (dt == null) continue;
      if (dt.isAfter(cutoff) || _isSameDay(dt, cutoff)) {
        vol += log.totals.volume;
      }
    }
    return vol;
  }

  /// Current workout streak: how many CONSECUTIVE days ending TODAY
  /// have at least 1 workout.
  int get currentWorkoutStreak {
    if (_history.isEmpty) return 0;

    // Build a set of normalized day keys for fast membership checks
    final Set<String> daysHit = <String>{};
    for (final log in _history) {
      final dt = _parseYmd(log.dateYmd);
      if (dt != null) {
        daysHit.add(_formatYmd(dt));
      }
    }

    if (daysHit.isEmpty) return 0;

    int streak = 0;
    DateTime cursor = AppClock.now();

    while (true) {
      final cursorKey = _formatYmd(cursor);
      if (daysHit.contains(cursorKey)) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Last workout date (DateTime) or null.
  DateTime? get lastWorkoutDate {
    if (_history.isEmpty) return null;
    DateTime? latest;
    for (final log in _history) {
      final dt = _parseYmd(log.dateYmd);
      if (dt == null) continue;
      if (latest == null || dt.isAfter(latest)) {
        latest = dt;
      }
    }
    return latest;
  }

  /// Returns true if today has a workout.
  bool get didWorkoutToday {
    final today = AppClock.now();
    for (final log in _history) {
      final dt = _parseYmd(log.dateYmd);
      if (dt != null && _isSameDay(dt, today)) {
        return true;
      }
    }
    return false;
  }

  /// Simple map for charts: last N days → volume
  Map<DateTime, double> volumeByDayLastNDays(int days) {
    final now = AppClock.now();
    final start = now.subtract(Duration(days: days - 1));
    final out = <DateTime, double>{};

    // init with zeros
    for (int i = 0; i < days; i++) {
      final d =
          DateTime(start.year, start.month, start.day).add(Duration(days: i));
      out[d] = 0;
    }

    for (final log in _history) {
      final dt = _parseYmd(log.dateYmd);
      if (dt == null) continue;
      if (dt.isBefore(start)) continue;
      final key = DateTime(dt.year, dt.month, dt.day);
      if (!out.containsKey(key)) {
        out[key] = log.totals.volume;
      } else {
        out[key] = (out[key] ?? 0) + log.totals.volume;
      }
    }

    return out;
  }
}

class SessionInvalidationNotice {
  SessionInvalidationNotice({required this.workoutId, required this.draft});
  final String workoutId;
  final SessionDraft draft;
}
