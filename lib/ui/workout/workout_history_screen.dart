// lib/ui/workout/workout_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/ui/workout/workout_summary_screen.dart';
import 'package:kontinuum/ui/workout/session_screen.dart' show SessionScreen;
import 'package:kontinuum/ui/workout/session_screen_args.dart';
import 'package:kontinuum/ui/workout/workout_overview_screen.dart';
import 'package:kontinuum/ui/theme/app_colors.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

enum _HistoryFilter {
  all,
  last7,
  last30,
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  List<WorkoutLog> _filterLogs(List<WorkoutLog> logs) {
    if (_filter == _HistoryFilter.all) return logs;
    final now = AppClock.now();
    final cutoff = _filter == _HistoryFilter.last7
        ? now.subtract(const Duration(days: 7))
        : now.subtract(const Duration(days: 30));

    return logs.where((log) {
      final dt = _parseYmd(log.dateYmd);
      return dt != null && (dt.isAfter(cutoff) || _isSameDay(dt, cutoff));
    }).toList();
  }

  DateTime? _parseYmd(String ymd) {
    if (ymd.length != 8) return null;
    final y = int.tryParse(ymd.substring(0, 4));
    final m = int.tryParse(ymd.substring(4, 6));
    final d = int.tryParse(ymd.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();

    // newest first
    final all = wp.history.reversed.toList();
    final shown = _filterLogs(all);

    final totalWorkouts = all.length;
    final totalVolume = all.fold<double>(
      0,
      (sum, log) => sum + log.totals.volume,
    );
    final lastDate = all.isNotEmpty ? all.first.dateYmd : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Workout History',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: shown.isEmpty
          ? const Center(
              child: Text(
                'No workouts yet',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _HistoryMetricsHeader(
                  totalWorkouts: totalWorkouts,
                  totalVolume: totalVolume,
                  lastDate: lastDate,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == _HistoryFilter.all,
                      onTap: () => setState(() {
                        _filter = _HistoryFilter.all;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Last 7 days',
                      selected: _filter == _HistoryFilter.last7,
                      onTap: () => setState(() {
                        _filter = _HistoryFilter.last7;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Last 30 days',
                      selected: _filter == _HistoryFilter.last30,
                      onTap: () => setState(() {
                        _filter = _HistoryFilter.last30;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final log in shown)
                  _HistoryTile(
                    log: log,
                    routineName:
                        wp.getRoutineById(log.routineId)?.name ?? 'Routine',
                    workoutName:
                        wp.getWorkoutById(log.workoutId)?.title ?? 'Workout',
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/sessionSummary',
                        arguments: WorkoutSummaryArgs(
                          logId: log.id,
                          xpEarned:
                              wp.computeXpFromStatDelta(log.totals.statDeltas),
                        ),
                      );
                    },
                    onRepeat: () {
                      _restartFromLog(context, log);
                    },
                  ),
              ],
            ),
    );
  }

  void _restartFromLog(BuildContext context, WorkoutLog log) {
    final wp = context.read<WorkoutProvider>();
    final routine = wp.getRoutineById(log.routineId);
    final workout = wp.getWorkoutById(log.workoutId);

    if (routine == null || workout == null) {
      return;
    }

    final DateTime today = AppClock.now();
    final DateTime fallback = DateTime(today.year, today.month, today.day);
    final DateTime scheduledDay = _parseYmd(log.dateYmd) ?? fallback;

    final result = wp.startSession(
      routineId: routine.id,
      workoutId: workout.id,
      source: 'history',
      calendarDayOverride: scheduledDay,
    );
    if (!result.started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'Unable to start that workout session.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          args: SessionScreenArgs(
            workoutId: workout.id,
            attachToRoutineId: routine.id,
            source: 'history',
            scheduledDate: scheduledDay,
          ),
        ),
        settings: const RouteSettings(name: 'session_from_history'),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.log,
    required this.routineName,
    required this.workoutName,
    required this.onTap,
    required this.onRepeat,
  });

  final WorkoutLog log;
  final String routineName;
  final String workoutName;
  final VoidCallback onTap;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final totalSets = log.exerciseLogs.fold<int>(
      0,
      (prev, e) => prev + e.sets.length,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: .05),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        title: Text(
          workoutName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$routineName • ${log.dateYmd} • ${log.totals.volume.toStringAsFixed(1)} lb • $totalSets sets',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .5),
              fontSize: 12.5,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.replay, size: 18, color: Colors.white70),
              onPressed: onRepeat,
              tooltip: 'Repeat this workout',
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: .4),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _HistoryMetricsHeader extends StatelessWidget {
  const _HistoryMetricsHeader({
    required this.totalWorkouts,
    required this.totalVolume,
    required this.lastDate,
  });

  final int totalWorkouts;
  final double totalVolume;
  final String? lastDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricCard(
          label: 'Workouts',
          value: '$totalWorkouts',
        ),
        const SizedBox(width: 10),
        _MetricCard(
          label: 'Total Volume',
          value: '${totalVolume.toStringAsFixed(0)} lb',
        ),
        const SizedBox(width: 10),
        _MetricCard(
          label: 'Last',
          value: lastDate ?? '—',
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .55),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.accentBlue.withValues(alpha: .16)
        : Colors.white.withValues(alpha: .03);
    final border = selected
        ? AppColors.accentBlue.withValues(alpha: .6)
        : Colors.white.withValues(alpha: .12);
    final txt = selected
        ? AppColors.accentBlue.withValues(alpha: 1)
        : Colors.white.withValues(alpha: .8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: txt,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
