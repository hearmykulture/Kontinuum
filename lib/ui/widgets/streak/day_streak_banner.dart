import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/core/time/app_clock.dart';
import 'package:kontinuum/core/streaks/streak_engine.dart';

class DayStreakBanner extends StatelessWidget {
  const DayStreakBanner({
    super.key,
    this.selectedDate,
  });

  /// Only for the "Progress ... / ..." line.
  final DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ObjectiveProvider>();
    final streakEngine = context.read<StreakEngine>();

    // progress row day
    final DateTime today = _strip(AppClock.now());
    final DateTime viewingDay =
        selectedDate != null ? _strip(selectedDate!) : today;

    final viewingState = provider.getTodayState(viewingDay);
    final int done = viewingState.completedObjectives;
    final int total = viewingState.activeObjectives;

    final bool hasTasks = total > 0;

    return ValueListenableBuilder(
      valueListenable: streakEngine.dayListenable(),
      builder: (_, __, ___) {
        final dayStreak = streakEngine.getDayStreak();
        final int streak = dayStreak.current;
        final int lockedRequirement =
            dayStreak.lockedRequiredCount > 0 ? dayStreak.lockedRequiredCount : 1;

        final String requirementText = hasTasks
            ? 'Keep it: complete ${_requirementLabel(lockedRequirement)}'
            : 'Keep it: log time or finish any objective';

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C1F2A), Color(0xFF111319)],
            ),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.orangeAccent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day streak • $streak day${streak == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      requirementText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Progress ${_fmt(viewingDay)}: $done / $total  •  (viewing day)',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────── helper logic ────────────────────────────────

  static String _requirementLabel(int lockedCount) {
    if (lockedCount <= 1) return 'any 1 objective';
    return '$lockedCount objectives';
  }

  static DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _fmt(DateTime d) {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(d.year, d.month, d.day);
    if (t == today) return 'today';
    return '${d.month}/${d.day}';
  }
}
