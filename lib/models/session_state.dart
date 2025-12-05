// lib/models/session_state.dart
import 'package:hive/hive.dart';
import 'package:kontinuum/core/time/app_clock.dart';

part 'session_state.g.dart';

/// Data for a single completed set
@HiveType(typeId: 222)
class SavedSetData extends HiveObject {
  @HiveField(0)
  int index;

  @HiveField(1)
  double loadLb;

  @HiveField(2)
  int reps;

  @HiveField(3)
  String timestampIso;

  @HiveField(4)
  int elapsedSeconds;

  SavedSetData({
    required this.index,
    required this.loadLb,
    required this.reps,
    required this.timestampIso,
    required this.elapsedSeconds,
  });
}

/// Persisted state of an in-progress workout session.
/// Saved when user exits mid-workout, restored when resuming.
@HiveType(typeId: 223)
class WorkoutSessionState extends HiveObject {
  /// ID of the workout being performed
  @HiveField(0)
  String workoutId;

  /// Optional routine ID if workout is part of a routine
  @HiveField(1)
  String? routineId;

  /// Current block index (0-based)
  @HiveField(2)
  int currentBlockIndex;

  /// Current exercise index within the block (0-based)
  @HiveField(3)
  int currentExerciseIndex;

  /// Stopwatch elapsed time in seconds
  @HiveField(4)
  int elapsedSeconds;

  /// Whether stopwatch was running when paused
  @HiveField(5)
  bool wasRunning;

  /// Timer mode: 'stopwatch' or 'rest'
  @HiveField(6)
  String timerMode;

  /// Rest timer: total seconds
  @HiveField(7)
  int restTotalSeconds;

  /// Rest timer: remaining seconds
  @HiveField(8)
  int restRemainingSeconds;

  /// Whether rest timer was paused
  @HiveField(9)
  bool restWasPaused;

  /// Map of exercise indices to completed set counts, cumulative across
  /// the entire workout.
  ///
  /// Key format: "blockIndex:exerciseIndex"
  /// Value: number of completed sets for that exercise.
  @HiveField(10)
  Map<String, int> completedSets;

  /// Timestamp when session was saved (ISO 8601 string)
  @HiveField(11)
  String savedAtIso;

  /// Notes for the current exercise
  @HiveField(12)
  String? currentExerciseNotes;

  /// List of completed sets for the **current exercise only**, with full
  /// data (load, reps, timestamp). This list is reset when advancing to a
  /// new exercise, while [completedSets] remains cumulative.
  @HiveField(13)
  List<SavedSetData> completedSetsList;

  /// Track whether the final rest window has started or completed so we can
  /// restore the UI state accurately when resuming a session.
  @HiveField(14)
  bool finalRestStarted;

  @HiveField(15)
  bool finalRestDone;

  /// The calendar date this session counts toward (YYYY-MM-DD ISO format).
  /// This is the date selected on the dashboard when the workout was started,
  /// NOT the date/time when the session was saved.
  @HiveField(16)
  String? scheduledDateIso;

  WorkoutSessionState({
    required this.workoutId,
    this.routineId,
    required this.currentBlockIndex,
    required this.currentExerciseIndex,
    required this.elapsedSeconds,
    required this.wasRunning,
    required this.timerMode,
    required this.restTotalSeconds,
    required this.restRemainingSeconds,
    required this.restWasPaused,
    required this.completedSets,
    required this.savedAtIso,
    this.currentExerciseNotes,
    List<SavedSetData>? completedSetsList,
    bool? finalRestStarted,
    bool? finalRestDone,
    this.scheduledDateIso,
  })  : completedSetsList = completedSetsList ?? [],
        finalRestStarted = finalRestStarted ?? false,
        finalRestDone = finalRestDone ?? false;

  /// Helper to get completed sets for a specific exercise
  int getCompletedSets(int blockIndex, int exerciseIndex) {
    final key = '$blockIndex:$exerciseIndex';
    return completedSets[key] ?? 0;
  }

  /// Helper to set completed sets for a specific exercise
  void setCompletedSets(int blockIndex, int exerciseIndex, int count) {
    final key = '$blockIndex:$exerciseIndex';
    completedSets[key] = count;
  }

  /// Total completed sets across the whole workout (sum of [completedSets]).
  ///
  /// For legacy snapshots where [completedSets] might be empty, this falls
  /// back to [completedSetsList.length] so old data still contributes to
  /// progress calculations.
  int get totalCompletedSets {
    if (completedSets.isNotEmpty) {
      return completedSets.values.fold(0, (sum, value) => sum + value);
    }
    return completedSetsList.length;
  }

  /// Check if this session is still valid (not too old)
  bool get isValid {
    try {
      final saved = DateTime.parse(savedAtIso);
      final now = AppClock.now();
      final diff = now.difference(saved);
      // Consider session valid if saved within last 24 hours
      return diff.inHours < 24;
    } catch (_) {
      return false;
    }
  }

  /// Create a detached copy so we can store the same logical snapshot under
  /// multiple Hive keys without reusing the same HiveObject instance.
  WorkoutSessionState copyDetached() {
    return WorkoutSessionState(
      workoutId: workoutId,
      routineId: routineId,
      currentBlockIndex: currentBlockIndex,
      currentExerciseIndex: currentExerciseIndex,
      elapsedSeconds: elapsedSeconds,
      wasRunning: wasRunning,
      timerMode: timerMode,
      restTotalSeconds: restTotalSeconds,
      restRemainingSeconds: restRemainingSeconds,
      restWasPaused: restWasPaused,
      completedSets: Map<String, int>.from(completedSets),
      savedAtIso: savedAtIso,
      currentExerciseNotes: currentExerciseNotes,
      completedSetsList: completedSetsList
          .map(
            (s) => SavedSetData(
              index: s.index,
              loadLb: s.loadLb,
              reps: s.reps,
              timestampIso: s.timestampIso,
              elapsedSeconds: s.elapsedSeconds,
            ),
          )
          .toList(),
      finalRestStarted: finalRestStarted,
      finalRestDone: finalRestDone,
      scheduledDateIso: scheduledDateIso,
    );
  }
}
