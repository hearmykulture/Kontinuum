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

  /// NEW: controls whether the SessionScreen should show the reset
  /// button in its action bar, or only show notes.
  final bool showResetButtonOnSessionScreen;

  const SessionScreenArgs({
    this.routineId,
    this.workoutId,
    this.source,
    this.missionId,
    this.scheduledDateIso,
    this.attachToRoutineId,
    this.focusedBlockIndex,
    this.scheduledDate,

    /// NEW: default to false so the session screen shows NOTES by default.
    this.showResetButtonOnSessionScreen = false,
  });
}
