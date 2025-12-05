// lib/core/today/today_state.dart

/// Lightweight snapshot of objective progress for a single calendar day.
class TodayState {
  final int ymd;
  final int activeObjectives; // unlocked objectives scheduled that day
  final int completedObjectives; // subset of activeObjectives marked complete
  final int rawMinutes; // proxy for time spent (typically base XP)

  const TodayState({
    required this.ymd,
    required this.activeObjectives,
    required this.completedObjectives,
    required this.rawMinutes,
  });
}
