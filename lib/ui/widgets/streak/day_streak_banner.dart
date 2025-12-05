import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/core/time/app_clock.dart';

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

    // progress row day
    final DateTime today = _strip(AppClock.now());
    final DateTime viewingDay =
        selectedDate != null ? _strip(selectedDate!) : today;

    final viewingState = provider.getTodayState(viewingDay);
    final int done = viewingState.completedObjectives;
    final int total = viewingState.activeObjectives;

    // build a sorted timeline of days we actually know about
    final datesSet = <DateTime>{
      ...provider.getAllTrackedDates().map(_strip),
      viewingDay,
      today,
    };
    final dates = datesSet.toList()..sort();

    // 1) latest kept day (past or future)
    final DateTime? anchor = _findLatestKeptDay(provider, dates);

    // 2) walk back over real consecutive days
    final int streak = anchor != null ? _walkBack(provider, dates, anchor) : 0;

    // text mirrors engine: if day has tasks → must finish ALL of them
    final bool hasTasks = total > 0;
    final String requirementText = hasTasks
        ? 'Keep it: complete ALL $total objectives'
        : 'Keep it: complete 1 objective or log time';

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
  }

  // ────────────────────────────── helper logic ────────────────────────────────

  // find the latest day (by date) that passes our strict "kept" rule
  static DateTime? _findLatestKeptDay(
    ObjectiveProvider provider,
    List<DateTime> sortedDates,
  ) {
    for (int i = sortedDates.length - 1; i >= 0; i--) {
      final d = sortedDates[i];
      if (_isKept(provider, d)) {
        return d;
      }
    }
    return null;
  }

  // walk backwards over the *sorted* list, but stop if:
  // - prev day is not exactly 1 day before
  // - or prev day is not kept
  static int _walkBack(
    ObjectiveProvider provider,
    List<DateTime> sortedDates,
    DateTime anchor,
  ) {
    int count = 1; // anchor itself counts
    final idx = sortedDates.lastIndexOf(anchor);
    for (int i = idx - 1; i >= 0; i--) {
      final prev = sortedDates[i];
      final diff = anchor.difference(prev).inDays;
      if (diff != 1) {
        break; // gap → stop streak
      }
      if (!_isKept(provider, prev)) {
        break; // day not kept → stop streak
      }
      count += 1;
      anchor = prev;
    }
    return count;
  }

  // STRICT keep rule for banner:
  // - if the day has objectives: MUST complete ALL
  // - if the day has 0 objectives: allow minutes to keep it
  static bool _isKept(ObjectiveProvider provider, DateTime day) {
    final s = provider.getTodayState(day);
    final hasTasks = s.activeObjectives > 0;
    if (hasTasks) {
      return s.completedObjectives >= s.activeObjectives;
    } else {
      return s.rawMinutes > 0;
    }
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
