// lib/ui/workout/session_screen_args.dart

class SessionScreenArgs {
  final String? routineId;
  final String? workoutId;
  final String? source;
  final String? missionId;
  final String? scheduledDateIso;
  final String? attachToRoutineId;
  final int? focusedBlockIndex;
  final DateTime? scheduledDate;
  final bool showResetButtonOnSessionScreen;
  final String? invalidationReason;

  /// NEW: controls whether the SessionScreen should show the reset
  /// button in its action bar, or only show notes.
  const SessionScreenArgs({
    this.routineId,
    this.workoutId,
    this.source,
    this.missionId,
    this.scheduledDateIso,
    this.attachToRoutineId,
    this.focusedBlockIndex,
    this.scheduledDate,
    this.showResetButtonOnSessionScreen = false,
    this.invalidationReason,
  });
}
