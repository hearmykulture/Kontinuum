// lib/ui/workout/session_widgets/muscle_utils.dart
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/utils/text_format.dart';

/// Body part aliases for normalizing muscle names
const Map<String, String> kBodyPartAliases = <String, String>{
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
  'calves': 'Hamstrings',
  'gastrocnemius': 'Hamstrings',
  'soleus': 'Hamstrings',
};

/// Canonical muscle group axes
const List<String> kMuscleAxes = <String>[
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Core',
  'Glutes',
  'Quads',
  'Hamstrings',
];

/// Converts raw muscle name to canonical body part
String? canonicalBodyPart(String raw) {
  final key = raw.toLowerCase().trim();
  final direct = kBodyPartAliases[key];
  if (direct != null) return direct;

  if (key.contains('chest') || key.contains('pec')) return 'Chest';
  if (key.contains('lat') || key.contains('back') || key.contains('trap')) {
    return 'Back';
  }
  if (key.contains('shoulder') || key.contains('delt')) return 'Shoulders';
  if (key.contains('bicep') ||
      key.contains('tricep') ||
      key.contains('arm') ||
      key.contains('forearm')) return 'Arms';
  if (key.contains('core') ||
      key.contains('abs') ||
      key.contains('oblique') ||
      key.contains('torso')) return 'Core';
  if (key.contains('glute') || key.contains('hip')) return 'Glutes';
  if (key.contains('quad') || key.contains('vastus') || key.contains('rectus')) {
    return 'Quads';
  }
  if (key.contains('hamstring') ||
      key.contains('posterior') ||
      key.contains('calf') ||
      key.contains('gastrocnemius') ||
      key.contains('soleus')) return 'Hamstrings';
  return null;
}

/// Accumulates muscle load from an exercise into totals map
void accumulateBodyPartLoad(
  Map<String, double> totals,
  Exercise exercise, {
  double primaryWeight = 1.0,
  double secondaryWeight = 0.6,
  double fallbackWeight = 0.8,
}) {
  bool tracked = false;

  for (final muscle in exercise.primaryMuscles) {
    final axis = (canonicalBodyPart(muscle) ?? formatTitleCase(muscle)).trim();
    if (axis.isEmpty) continue;
    totals[axis] = totals[axis] ?? 0.0) + primaryWeight;
    tracked = true;
  }

  for (final muscle in exercise.secondaryMuscles) {
    final axis = (canonicalBodyPart(muscle) ?? formatTitleCase(muscle)).trim();
    if (axis.isEmpty) continue;
    totals[axis] = totals[axis] ?? 0.0) + secondaryWeight;
    tracked = true;
  }

  if (!tracked) {
    for (final muscle in exercise.muscles) {
      final axis = (canonicalBodyPart(muscle) ?? formatTitleCase(muscle)).trim();
      if (axis.isEmpty) continue;
      totals[axis] = totals[axis] ?? 0.0) + fallbackWeight;
    }
  }
}

/// Builds muscle summary for a workout block
List<String> buildBlockMuscleSummary(WorkoutBlock block) {
  final Map<String, double> totals = <String, double>{};

  for (final item in block.items) {
    final exercise = ExerciseLibraryService.instance.getById(item.exerciseId);
    if (exercise == null) continue;
    accumulateBodyPartLoad(totals, exercise);
  }

  final entries = totals.entries
      .where((entry) => entry.value > 0)
      .toList(growable: false)
    ..sort((a, b) => b.value.compareTo(a.value));

  return entries.map((entry) => entry.key).take(6).toList(growable: false);
}

/// Builds muscle summary for an entire workout
List<String> buildWorkoutMuscleSummary(Workout workout) {
  final Map<String, double> totals = <String, double>{};

  for (final b in workout.blocks) {
    for (final it in b.items) {
      final exercise = ExerciseLibraryService.instance.getById(it.exerciseId);
      if (exercise == null) continue;
      accumulateBodyPartLoad(totals, exercise);
    }
  }

  final entries = totals.entries
      .where((e) => e.value > 0)
      .toList(growable: false)
    ..sort((a, b) => b.value.compareTo(a.value));

  return entries.map((e) => e.key).take(6).toList(growable: false);
}

/// Formats muscle list as comma-separated string
String formatMuscleSummary(List<String> muscles) {
  if (muscles.isEmpty) return '';
  return muscles.join(', ');
}

/// Computes normalized workout coverage (0-1) for radar chart
Map<String, double> computeWorkoutCoverage(Workout workout) {
  final Map<String, double> totals = {for (final a in kMuscleAxes) a: 0.0};

  for (final b in workout.blocks) {
    for (final it in b.items) {
      final exercise = ExerciseLibraryService.instance.getById(it.exerciseId);
      if (exercise == null) continue;
      accumulateBodyPartLoad(totals, exercise);
    }
  }

  final double maxV =
      totals.values.fold<double>(0.0, (p, v) => v > p ? v : p);
  if (maxV <= 0) return totals;

  totals.updateAll((_, v) => v / maxV);
  return totals;
}

/// Computes normalized coverage for a single [WorkoutBlock].
Map<String, double> computeBlockCoverage(WorkoutBlock block) {
  final Map<String, double> totals = {for (final a in kMuscleAxes) a: 0.0};

  for (final item in block.items) {
    final exercise = ExerciseLibraryService.instance.getById(item.exerciseId);
    if (exercise == null) continue;
    accumulateBodyPartLoad(totals, exercise);
  }

  final double maxV =
      totals.values.fold<double>(0.0, (p, v) => v > p ? v : p);
  if (maxV <= 0) return totals;

  totals.updateAll((_, v) => v / maxV);
  return totals;
}
