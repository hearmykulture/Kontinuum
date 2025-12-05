// lib/services/workout_po_pipeline.dart
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/po_engine.dart' as po;
import 'package:kontinuum/core/time/app_clock.dart';

/// What the session actually produced (per exercise)
class LoggedSet {
  final int? reps;
  final double? loadKg; // your SetLog just uses `load`, we’ll map this over
  final int? timeSec;
  final int? rpe;

  const LoggedSet({
    this.reps,
    this.loadKg,
    this.timeSec,
    this.rpe,
  });
}

class ExerciseSessionResult {
  final String exerciseId;
  final List<LoggedSet> sets;

  const ExerciseSessionResult({
    required this.exerciseId,
    required this.sets,
  });
}

class WorkoutSessionResult {
  final String workoutId;
  final List<ExerciseSessionResult> exercises;

  const WorkoutSessionResult({
    required this.workoutId,
    required this.exercises,
  });
}

/// This takes the workout you had in Hive + what the user actually did
/// and updates each WorkoutItem using your PO engine.
class WorkoutPoPipeline {
  static Workout apply({
    required Workout workout,
    required WorkoutSessionResult session,
    bool poEnabled = true,
  }) {
    if (!poEnabled) return workout;

    final newBlocks = <WorkoutBlock>[];

    for (final block in workout.blocks) {
      final newItems = <WorkoutItem>[];

      for (final item in block.items) {
        // find what the user actually did for this exercise
        final exResult = session.exercises.firstWhere(
          (e) => e.exerciseId == item.exerciseId,
          orElse: () => ExerciseSessionResult(
            exerciseId: item.exerciseId,
            sets: const [],
          ),
        );

        // convert LoggedSet -> SetLog so it matches your real engine
        final performedSets = exResult.sets.map((s) {
          return SetLog(
            reps: s.reps,
            load: s.loadKg, // we treat this as the same unit your app uses
            rpe: s.rpe != null ? s.rpe!.toDouble() : null,
            tsMs: AppClock.now().millisecondsSinceEpoch,
          );
        }).toList();

        // call your real engine API
        final preview = po.ProgressiveOverloadEngine.computeNextTarget(
          poEnabled: poEnabled,
          item: item,
          performedSets: performedSets,
        );

        // WorkoutItem has no copyWith → rebuild manually
        final currentMisses = item.consecutiveMisses ?? 0;
        final nextMisses = _nextMisses(currentMisses, preview.status);

        final updatedItem = WorkoutItem(
          exerciseId: item.exerciseId,
          targetSets: item.targetSets,
          targetReps: item.targetReps,
          targetTimeSec: item.targetTimeSec,
          restSec: item.restSec,
          targetLoad: item.targetLoad,
          notes: item.notes,
          cueChips: List<String>.from(item.cueChips),
          formChecks: List<String>.from(item.formChecks),
          consecutiveMisses: nextMisses,
          lastSuggestedLoadKg: preview.nextLoadKg ?? item.lastSuggestedLoadKg,
          lastTargetReps: preview.nextRepsTarget ?? item.lastTargetReps,
          lastLoggedRpe: item.lastLoggedRpe,
          adaptiveSetsEnabled: item.adaptiveSetsEnabled,
          adaptivePercent: item.adaptivePercent,
        );

        newItems.add(updatedItem);
      }

      newBlocks.add(
        WorkoutBlock(
          type: block.type,
          title: block.title,
          items: newItems,
        ),
      );
    }

    // return a new Workout with updated blocks
    return Workout(
      id: workout.id,
      title: workout.title,
      notes: workout.notes,
      blocks: newBlocks,
    );
  }

  static int _nextMisses(int current, po.PoStatus status) {
    switch (status) {
      case po.PoStatus.progress:
        return 0;
      case po.PoStatus.hold:
        return current;
      case po.PoStatus.deload:
        return current + 1;
    }
  }
}
