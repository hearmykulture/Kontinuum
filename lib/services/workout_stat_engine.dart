// lib/services/workout_stat_engine.dart
import 'dart:math' as math;

import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/exercise_library_service.dart';

/// Encapsulates quick heuristics around workout volume, intensity, and how it
/// might feel for the current athlete. We'll expand this to account for BMI,
/// nutrition, recovery scores, etc. as those systems come online.
class WorkoutStatEngine {
  WorkoutStatEngine._();

  static final WorkoutStatEngine instance = WorkoutStatEngine._();

  final ExerciseLibraryService _exerciseLibrary =
      ExerciseLibraryService.instance;

  WorkoutStatSummary summarize({
    required Workout workout,
    FitnessNutritionProfile? profile,
  }) {
    int totalSets = 0;
    int totalReps = 0;
    double totalLoad = 0.0;
    double weightedDifficulty = 0.0;
    double totalDifficultyWeight = 0.0;
    final Set<String> muscles = <String>{};
    int exerciseCount = 0;

    for (final block in workout.blocks) {
      for (final item in block.items) {
        exerciseCount++;
        totalSets += item.targetSets;

        final int repsPerSet = item.targetReps ?? 0;
        if (repsPerSet > 0) {
          totalReps += repsPerSet * item.targetSets;
        }

        final double? loadPerRep = item.targetLoad;
        if (loadPerRep != null && loadPerRep > 0 && repsPerSet > 0) {
          totalLoad += loadPerRep * repsPerSet * item.targetSets;
        }

        final exercise = _exerciseLibrary.getById(item.exerciseId);
        if (exercise != null) {
          final double exerciseDifficultyScore =
              _mapDifficulty(exercise.difficulty);
          weightedDifficulty += exerciseDifficultyScore * item.targetSets;
          totalDifficultyWeight += item.targetSets;

          muscles.addAll(
            exercise.primaryMuscles.map(_normalizeMuscleName),
          );
          muscles.addAll(
            exercise.secondaryMuscles.map(_normalizeMuscleName),
          );
        }
      }
    }

    final double averageDifficulty = totalDifficultyWeight > 0
        ? weightedDifficulty / totalDifficultyWeight
        : 0.5; // default mid difficulty when data missing

    final double perceivedDifficulty = _computePerceivedDifficulty(
      averageDifficulty: averageDifficulty,
      totalSets: totalSets,
      totalReps: totalReps,
      totalLoadKg: totalLoad,
      profile: profile,
    );

    final double starRating = _convertDifficultyToStars(perceivedDifficulty);

    return WorkoutStatSummary(
      starRating: starRating,
      averageDifficulty: averageDifficulty,
      totalSets: totalSets,
      totalReps: totalReps,
      estimatedLoadKg: totalLoad,
      muscles: muscles.where((m) => m.isNotEmpty).toSet(),
      blockCount: workout.blocks.length,
      exerciseCount: exerciseCount,
    );
  }

  double _computePerceivedDifficulty({
    required double averageDifficulty,
    required int totalSets,
    required int totalReps,
    required double totalLoadKg,
    FitnessNutritionProfile? profile,
  }) {
    final double volumeScore =
        totalSets > 0 ? math.min(totalSets / 18.0, 1.2) : 0.0;

    final double repScore =
        totalReps > 0 ? math.min(totalReps / 140.0, 1.0) : 0.0;

    double loadScore = 0.0;
    final double referenceWeight = profile?.weightKg ?? 75.0;
    if (totalLoadKg > 0 && referenceWeight > 0) {
      loadScore = math.min(totalLoadKg / (referenceWeight * 90.0), 1.2);
    } else if (repScore > 0) {
      // fallback when we only have bodyweight work tracked via reps
      loadScore = repScore * 0.6;
    }

    final double exerciseScore =
        averageDifficulty > 0 ? math.min(averageDifficulty, 1.0) : 0.4;

    double aggregate = (exerciseScore * 0.45) +
        (volumeScore * 0.3) +
        (loadScore * 0.15) +
        (repScore * 0.1);

    aggregate *= _experienceModifier(profile?.experienceLevel);

    // keep the result in a nice bounded range [0, 1.2] so downstream mapping
    // has predictable behaviour.
    return aggregate.clamp(0.0, 1.2);
  }

  double _experienceModifier(ExperienceLevel? level) {
    switch (level) {
      case ExperienceLevel.newLifter:
        return 1.25;
      case ExperienceLevel.threeToTwelveMonths:
        return 1.12;
      case ExperienceLevel.oneToThreeYears:
        return 1.0;
      case ExperienceLevel.threePlusYears:
        return 0.9;
      case null:
        return 1.05;
    }
  }

  double _convertDifficultyToStars(double perceivedDifficulty) {
    // perceivedDifficulty is ~0-1.2. Map 0 => 1 star, 1.2 => 5 stars linearly.
    const double minStars = 1.0;
    const double maxStars = 5.0;
    const double maxDifficulty = 1.2;
    final double normalized =
        (perceivedDifficulty / maxDifficulty).clamp(0.0, 1.0); // 0-1 scale
    final double stars = minStars + normalized * (maxStars - minStars);
    // round to the nearest half-star for display.
    return stars * 2.round() / 2.0;
  }

  double _mapDifficulty(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.beginner:
        return 0.4;
      case ExerciseDifficulty.intermediate:
        return 0.7;
      case ExerciseDifficulty.advanced:
        return 1.0;
    }
  }

  String _normalizeMuscleName(String raw) {
    final key = raw.trim().toLowerCase();
    if (key.isEmpty) return '';
    final alias = _muscleAliases[key];
    if (alias != null) return alias;
    final parts = key.split(RegExp(r'\s+'));
    return parts
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

class WorkoutStatSummary {
  const WorkoutStatSummary({
    required this.starRating,
    required this.averageDifficulty,
    required this.totalSets,
    required this.totalReps,
    required this.estimatedLoadKg,
    required this.muscles,
    required this.blockCount,
    required this.exerciseCount,
  });

  final double starRating;
  final double averageDifficulty;
  final int totalSets;
  final int totalReps;
  final double estimatedLoadKg;
  final Set<String> muscles;
  final int blockCount;
  final int exerciseCount;
}

const Map<String, String> _muscleAliases = <String, String>{
  'chest': 'Chest',
  'pecs': 'Chest',
  'pectorals': 'Chest',
  'upper chest': 'Chest',
  'lower chest': 'Chest',
  'back': 'Back',
  'upper back': 'Back',
  'mid back': 'Back',
  'lower back': 'Back',
  'lats': 'Back',
  'latissimus dorsi': 'Back',
  'traps': 'Back',
  'shoulders': 'Shoulders',
  'delts': 'Shoulders',
  'front delts': 'Shoulders',
  'rear delts': 'Shoulders',
  'side delts': 'Shoulders',
  'biceps': 'Arms',
  'triceps': 'Arms',
  'forearms': 'Arms',
  'arms': 'Arms',
  'core': 'Core',
  'abs': 'Core',
  'abdominals': 'Core',
  'obliques': 'Core',
  'glutes': 'Glutes',
  'gluteus maximus': 'Glutes',
  'gluteus medius': 'Glutes',
  'gluteus minimus': 'Glutes',
  'hip flexors': 'Glutes',
  'quads': 'Quads',
  'quadriceps': 'Quads',
  'vastus lateralis': 'Quads',
  'vastus medialis': 'Quads',
  'vastus intermedius': 'Quads',
  'rectus femoris': 'Quads',
  'hamstrings': 'Hamstrings',
  'posterior chain': 'Hamstrings',
  'biceps femoris': 'Hamstrings',
  'semitendinosus': 'Hamstrings',
  'semimembranosus': 'Hamstrings',
  'calves': 'Calves',
  'gastrocnemius': 'Calves',
  'soleus': 'Calves',
  'trunk': 'Core',
  'midline': 'Core',
};
