import 'package:flutter/material.dart';

class StreakConfig {
  // ==== Bonus formulas (Balanced Mode) ====

  /// Objective bonus per completion on day N of that objective’s streak:
  /// min(N, min(10, round(0.5 × baseXP)))
  static int objectiveBonus(int baseXP, int streakDays) {
    final int capByBase = (0.5 * baseXP).round().clamp(1, 10);
    return streakDays.clamp(0, capByBase);
  }

  /// Category bonus per day N (claimable; auto-collected at midnight):
  /// min(10 + (N−1), 25)
  static int categoryBonus(int streakDays) =>
      (10 + (streakDays - 1)).clamp(0, 25);

  /// Day bonus per day N of day-streak (kept if requirement met):
  /// min(2 × N, 40)
  static int dayBonus(int streakDays) => (2 * streakDays).clamp(0, 40);

  /// Daily bonus pool cap (all bonus types combined).
  static const int dailyBonusCap = 60;

  /// Overflow conversion rate: 4 XP → 1 MC.
  static const int xpPerMc = 4;

  /// Minutes threshold to keep day streak by time (OR-path).
  static const int minutesThreshold = 30;

  /// Day-streak requirement ramp: starts at 50%, ramps to 100% over N days.
  static const int rampDaysToFull = 30;

  /// Required fraction today given the *current* day streak (before today).
  /// 0.5 → 1.0 across [0, rampDaysToFull].
  static double requiredFractionForDayStreak(int dayStreakBeforeToday) {
    final double ramped = 0.5 +
        (dayStreakBeforeToday.clamp(0, rampDaysToFull) / rampDaysToFull) * 0.5;
    return ramped.clamp(0.5, 1.0);
  }

  /// Midnight end-of-day — grace window off (can reintroduce later).
  static const TimeOfDay dayEndsAt = TimeOfDay(hour: 0, minute: 0);
}
