// lib/ui/workout/workout_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/services/po_engine.dart'; // ProgressiveOverloadEngine, PoStatus
import 'package:kontinuum/ui/theme/app_colors.dart';

class WorkoutSummaryArgs {
  final String logId;
  final int xpEarned;

  const WorkoutSummaryArgs({
    required this.logId,
    required this.xpEarned,
  });
}

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as WorkoutSummaryArgs?;
    final wp = context.watch<WorkoutProvider>();

    WorkoutLog? log;
    if (args != null) {
      log = wp.getLogById(args.logId);
    }

    // if null → simple state
    if (log == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Workout Summary',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const SafeArea(
          child: Center(
            child: Text(
              'No summary data',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    // from here on, log is non-null
    final nonNullLog = log;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Workout Summary',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay, color: Colors.white),
            tooltip: 'Repeat this workout',
            onPressed: () {
              _restartFromLog(context, nonNullLog);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (args != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: .4),
                          ),
                        ),
                        child: Text(
                          '+${args.xpEarned} XP to HEALTH',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatPill(
                          label: 'Volume',
                          value:
                              '${nonNullLog.totals.volume.toStringAsFixed(1)} lb',
                        ),
                        const SizedBox(width: 10),
                        _StatPill(
                          label: 'Duration',
                          value:
                              '${(nonNullLog.totals.timeSec / 60).ceil()} min',
                        ),
                        const SizedBox(width: 10),
                        _StatPill(
                          label: 'Exercises',
                          value: '${nonNullLog.exerciseLogs.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Exercises',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // exercises
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final exLog = nonNullLog.exerciseLogs[index];

                  // resolve exercise name
                  final ex =
                      ExerciseLibraryService.instance.getById(exLog.exerciseId);
                  final exName = ex?.name ?? exLog.exerciseId;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .06),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // header row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    exName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${exLog.volume.toStringAsFixed(1)} lb',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (var i = 0; i < exLog.sets.length; i++)
                              _SetLine(
                                index: i + 1,
                                setLog: exLog.sets[i],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: nonNullLog.exerciseLogs.length,
              ),
            ),

            // next targets
            SliverToBoxAdapter(
              child: _NextTargetsSection(log: nonNullLog),
            ),

            // run again button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.replay),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _restartFromLog(context, nonNullLog);
                    },
                    label: const Text(
                      'Run this workout again',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Restart using the provider's "from log" so it preserves order + added exercises.
  void _restartFromLog(BuildContext context, WorkoutLog log) {
    final wp = context.read<WorkoutProvider>();

    // this recreates the draft with the same exercise order + adds blank states
    wp.startSessionFromLog(
      log,
      source: 'summary',
    );

    Navigator.of(context).pushReplacementNamed('/session');
  }
}

class _NextTargetsSection extends StatelessWidget {
  const _NextTargetsSection({required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();

    final routine = wp.getRoutineById(log.routineId);
    final workout = wp.getWorkoutById(log.workoutId);

    if (routine == null || workout == null) {
      return const SizedBox.shrink();
    }

    // index logs by exerciseId
    final Map<String, ExerciseLog> logsByEx = {
      for (final e in log.exerciseLogs) e.exerciseId: e,
    };

    final rows = <_NextTargetRowData>[];

    for (final block in workout.blocks) {
      for (final item in block.items) {
        final exLog = logsByEx[item.exerciseId];
        final performedSets = exLog?.sets ?? const <SetLog>[];

        final preview = ProgressiveOverloadEngine.computeNextTarget(
          poEnabled: routine.poEnabled,
          item: item,
          performedSets: performedSets,
        );

        final bool hasMeaningfulChange = preview.nextLoadKg != null ||
            preview.nextRepsTarget != null ||
            preview.status == PoStatus.deload;

        if (!hasMeaningfulChange) continue;

        final ex = ExerciseLibraryService.instance.getById(item.exerciseId);
        final exName = ex?.name ?? item.exerciseId;

        rows.add(
          _NextTargetRowData(
            exerciseName: exName,
            status: preview.status,
            nextLoadKg: preview.nextLoadKg,
            nextReps: preview.nextRepsTarget,
          ),
        );
      }
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Next targets',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) _NextTargetTile(data: row),
        ],
      ),
    );
  }
}

class _NextTargetRowData {
  final String exerciseName;
  final PoStatus status;
  final double? nextLoadKg;
  final int? nextReps;

  _NextTargetRowData({
    required this.exerciseName,
    required this.status,
    this.nextLoadKg,
    this.nextReps,
  });
}

class _NextTargetTile extends StatelessWidget {
  const _NextTargetTile({required this.data});

  final _NextTargetRowData data;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color dot;
    String statusLabel;

    switch (data.status) {
      case PoStatus.progress:
        bg = const Color(0xFF0F2F1A);
        dot = const Color(0xFF4ADE80);
        statusLabel = 'Progress';
        break;
      case PoStatus.hold:
        bg = const Color(0xFF2F2A12);
        dot = const Color(0xFFFCD34D);
        statusLabel = 'Hold';
        break;
      case PoStatus.deload:
        bg = const Color(0xFF3C1B1F);
        dot = const Color(0xFFF43F5E);
        statusLabel = 'Deload';
        break;
    }

    final loadStr = data.nextLoadKg != null
        ? '${data.nextLoadKg!.toStringAsFixed(1)} kg'
        : null;
    final repsStr = data.nextReps != null ? '${data.nextReps} reps' : null;

    final detail = [
      if (loadStr != null) loadStr,
      if (repsStr != null) repsStr,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: .35),
        border: Border.all(color: bg.withValues(alpha: .7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.exerciseName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (detail.isNotEmpty)
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .5),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .02),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .45),
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetLine extends StatelessWidget {
  const _SetLine({
    required this.index,
    required this.setLog,
  });

  final int index;
  final SetLog setLog;

  @override
  Widget build(BuildContext context) {
    final repsTxt = setLog.reps != null ? '${setLog.reps} reps' : '— reps';
    final loadTxt = setLog.load != null ? '${setLog.load} lb' : '— lb';
    final rpeTxt = setLog.rpe != null ? 'RPE ${setLog.rpe}' : 'RPE —';
    final notes = setLog.notes?.trim();
    final showNotes = notes != null && notes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set $index · $repsTxt · $loadTxt · $rpeTxt',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              fontSize: 12.5,
            ),
          ),
          if (showNotes)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                notes,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
