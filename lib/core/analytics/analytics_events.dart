// lib/core/analytics/analytics_events.dart

class WorkoutAnalyticsEvents {
  // From ProgressScreen CTA etc.
  static const String progressWorkoutButtonTapped =
      'progress_workout_button_tapped';

  // When workout dashboard is viewed.
  static const String workoutDashboardOpened = 'workout_dashboard_opened';

  // When user taps into a routine detail page.
  static const String routineOpened = 'routine_opened';

  // When a training session is created (user hits "Start").
  static const String sessionStarted = 'session_started';

  // When the user logs/saves a set during the live session.
  // Old name:
  static const String setSaved = 'set_saved';
  // Newer name we may emit from SessionScreen:
  static const String setLogged = 'set_logged';

  // When user marks an exercise complete in-session.
  static const String exerciseCompleted = 'exercise_completed';

  // When a session is ended and committed to history.
  // Old name:
  static const String sessionCompleted = 'session_completed';
  // Newer name:
  static const String sessionFinished = 'session_finished';

  // Mission analytics hooks (optional).
  static const String missionOpened = 'mission_opened';
  static const String missionCompleted = 'mission_completed';

  // 🔥 NEW: when a workout is duplicated (from routine detail or elsewhere)
  static const String workoutCopied = 'workout_copied';
}
