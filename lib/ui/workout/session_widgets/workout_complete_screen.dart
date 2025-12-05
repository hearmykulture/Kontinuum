// lib/ui/workout/session_widgets/workout_complete_screen.dart
import 'package:flutter/material.dart';

class WorkoutSetStat {
  final int index;
  final Duration elapsed;
  final double loadLb;
  final int reps;
  final DateTime timestamp;

  const WorkoutSetStat({
    required this.index,
    required this.elapsed,
    required this.loadLb,
    required this.reps,
    required this.timestamp,
  });
}

class WorkoutCompleteScreen extends StatelessWidget {
  const WorkoutCompleteScreen({
    super.key,
    required this.stats,
    this.title = 'Session summary',
    this.currentBlockIndex = 0,
    this.totalBlocks = 1,
    this.onNextBlock,
    this.onNextExercise,
    this.nextExerciseLabel,
    this.onFinishWorkout,
    this.workoutId,
    this.routineId,
  });

  final List<WorkoutSetStat> stats;
  final String title;
  final int currentBlockIndex;
  final int totalBlocks;
  final VoidCallback? onNextBlock;
  final VoidCallback? onNextExercise;
  final String? nextExerciseLabel;
  final VoidCallback? onFinishWorkout;
  final String? workoutId;
  final String? routineId;

  String _fmtDur(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = stats.fold<Duration>(Duration.zero, (a, b) => a + b.elapsed);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () {
            // If finishing the workout, call the finish handler
            // which will save the log and navigate properly
            if (onFinishWorkout != null &&
                currentBlockIndex >= totalBlocks - 1) {
              onFinishWorkout!();
            } else {
              // Otherwise just go back
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.black87),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Total duration',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _fmtDur(total),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final s in stats) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      'Set ${s.index}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${s.loadLb.toStringAsFixed(s.loadLb % 1 == 0 ? 0 : 1)} lb × ${s.reps}',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule_rounded,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      _fmtDur(s.elapsed),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (onNextExercise != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNextExercise,
                  icon: const Icon(Icons.redo_rounded),
                  label: Text(
                    nextExerciseLabel ?? 'Next Exercise',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            // Next Block button (if more blocks remaining)
            if (currentBlockIndex < totalBlocks - 1 && onNextBlock != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNextBlock,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    'Next Block (${currentBlockIndex + 2}/$totalBlocks)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            if (onNextBlock == null && onFinishWorkout != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onFinishWorkout,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Finish Workout',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
