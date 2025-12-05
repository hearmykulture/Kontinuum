// lib/core/time/rollover_service.dart
import 'package:hive/hive.dart';
import 'package:kontinuum/core/time/day_id.dart';
import 'package:kontinuum/core/streaks/streak_engine.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/core/time/app_clock.dart';

/// Runs “virtual midnight” whenever the calendar day changes while the app
/// was closed/inactive.
/// - Autocollects category streak claims for the day.
/// - Evaluates the day streak.
/// - Breaks missed objective streaks (respecting skips).
class RolloverService {
  final Box<dynamic> _meta; // stores 'lastSeenYmd' as an int
  final StreakEngine _engine;
  final ObjectiveProvider _objectives;

  RolloverService(this._meta, this._engine, this._objectives);

  void maybeRoll() {
    // Hive returns dynamic, so coerce robustly to int.
    final Object? raw = _meta.get('lastSeenYmd');
    final int last =
        (raw is int) ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;

    final DateTime now = AppClock.now();
    final int today = ymd(now);

    if (last == 0) {
      _meta.put('lastSeenYmd', today);
      return;
    }
    if (last == today) return;

    // Walk each missing day (usually just one).
    DateTime cursor = DateTime(last ~/ 10000, (last ~/ 100) % 100, last % 100);
    while (ymd(cursor) < today) {
      final int dayId = ymd(cursor);

      // 1) Autocollect category bonuses left unclaimed that day.
      _engine.autocollectCategoryBonusesForYmd(dayId);

      // 2) Evaluate day streak for that day (locks requirement if needed).
      _engine.finalizeDayAndEvalDayStreak(cursor, _objectives);

      // 3) Break missed objective streaks for that day (skips protect).
      final List<Objective> todays = _objectives.getObjectivesForDay(cursor);
      _engine.breakMissedObjectiveStreaks(cursor, todays);

      // Advance one day.
      cursor = cursor.add(const Duration(days: 1));
    }

    _meta.put('lastSeenYmd', today);
  }
}
