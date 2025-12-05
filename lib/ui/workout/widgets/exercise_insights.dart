import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';

const List<String> kExerciseMuscleAxes = <String>[
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Core',
  'Glutes',
  'Quads',
  'Hamstrings',
];

Map<String, double> computeExerciseCoverage(Exercise? exercise) {
  final Map<String, double> totals = <String, double>{
    for (final axis in kExerciseMuscleAxes) axis: 0.0,
  };
  if (exercise == null) return totals;

  bool tracked = false;
  tracked = _accumulateMuscles(
        totals: totals,
        muscles: exercise.primaryMuscles,
        weight: 1.0,
      ) ||
      tracked;

  tracked = _accumulateMuscles(
        totals: totals,
        muscles: exercise.secondaryMuscles,
        weight: 0.6,
      ) ||
      tracked;

  if (!tracked) {
    tracked = _accumulateMuscles(
      totals: totals,
      muscles: exercise.muscles,
      weight: 0.8,
    );
  }

  if (!tracked) return totals;

  final double maxValue = totals.values.fold<double>(
    0.0,
    (prev, value) => value > prev ? value : prev,
  );
  if (maxValue <= 0) return totals;

  totals.updateAll((_, value) => value / maxValue);
  return totals;
}

bool _accumulateMuscles({
  required Map<String, double> totals,
  required List<String> muscles,
  required double weight,
}) {
  bool any = false;
  for (final muscle in muscles) {
    final String? axis = _axisForMuscle(muscle);
    if (axis == null) continue;
    totals[axis] = (totals[axis] ?? 0.0) + weight;
    any = true;
  }
  return any;
}

String? _axisForMuscle(String muscle) {
  final String normalized = muscle.trim().toLowerCase();
  for (final MapEntry<String, List<String>> entry
      in _kCategoryAliases.entries) {
    if (entry.value.contains(normalized)) {
      return entry.key;
    }
  }
  for (final String axis in kExerciseMuscleAxes) {
    if (axis.toLowerCase() == normalized) return axis;
  }
  return null;
}

const Map<String, List<String>> _kCategoryAliases = <String, List<String>>{
  'Chest': <String>[
    'chest',
    'pecs',
    'pectorals',
    'upper chest',
    'lower chest',
  ],
  'Back': <String>[
    'back',
    'upper back',
    'mid back',
    'lower back',
    'lats',
    'latissimus dorsi',
    'traps',
  ],
  'Shoulders': <String>[
    'shoulders',
    'delts',
    'front delts',
    'rear delts',
    'side delts',
  ],
  'Arms': <String>[
    'arms',
    'biceps',
    'triceps',
    'forearms',
  ],
  'Core': <String>[
    'core',
    'abs',
    'abdominals',
    'obliques',
  ],
  'Glutes': <String>[
    'glutes',
    'gluteus maximus',
    'gluteus medius',
    'gluteus minimus',
    'hip flexors',
  ],
  'Quads': <String>[
    'quads',
    'quadriceps',
    'vastus lateralis',
    'vastus medialis',
    'vastus intermedius',
    'rectus femoris',
  ],
  'Hamstrings': <String>[
    'hamstrings',
    'posterior chain',
    'biceps femoris',
    'semitendinosus',
    'semimembranosus',
    'calves',
    'gastrocnemius',
    'soleus',
  ],
};

class ExercisePreviewImage extends StatelessWidget {
  const ExercisePreviewImage({
    super.key,
    required this.url,
  });

  final String url;

  @override
  Widget build(BuildContext context) {
    final Color bg = Colors.grey.shade100;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Container(color: bg),
        ),
        Positioned.fill(
          child: _AnimatedExerciseImage(url: url),
        ),
      ],
    );
  }
}

/// Wraps [Image.network] so 404s don't trip the debugger (only logs) but still
/// allows animated GIF playback.
class _AnimatedExerciseImage extends StatefulWidget {
  const _AnimatedExerciseImage({required this.url});

  final String url;

  @override
  State<_AnimatedExerciseImage> createState() => _AnimatedExerciseImageState();
}

class _AnimatedExerciseImageState extends State<_AnimatedExerciseImage> {
  bool _hadError = false;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSync) {
        if (_hadError) {
          return const ExercisePreviewPlaceholder();
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        // Swallow repeated 404s – only show placeholder.
        _hadError = true;
        return const ExercisePreviewPlaceholder();
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _PreviewLoading();
      },
    );
  }
}

class ExercisePreviewPlaceholder extends StatelessWidget {
  const ExercisePreviewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.fitness_center, size: 42, color: Colors.black38),
          SizedBox(height: 12),
          Text(
            'Select an exercise to preview',
            style: TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ExerciseChartPlaceholder extends StatelessWidget {
  const ExerciseChartPlaceholder({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = Colors.black.withValues(alpha: 0.3);
    final Color textColor = Colors.black.withValues(alpha: 0.45);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 36, color: iconColor),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ExerciseInstructionSlide extends StatelessWidget {
  const ExerciseInstructionSlide({
    super.key,
    required this.steps,
  });

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = TextStyle(
      color: Colors.black.withValues(alpha: 0.75),
      fontWeight: FontWeight.w700,
      fontSize: 14,
      letterSpacing: -0.1,
    );
    final TextStyle stepStyle = TextStyle(
      color: Colors.black.withValues(alpha: 0.7),
      fontSize: 12.5,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instructions', style: titleStyle),
        const SizedBox(height: 8),
        Expanded(
          child: Scrollbar(
            radius: const Radius.circular(10),
            thickness: 3,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final String step = steps[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '${index + 1}.',
                        style: stepStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step,
                        style: stepStyle,
                      ),
                    ),
                  ],
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: steps.length,
            ),
          ),
        ),
      ],
    );
  }
}

class ExerciseRadar extends StatelessWidget {
  const ExerciseRadar({
    super.key,
    required this.coverage,
    required this.accentColor,
  });

  final Map<String, double> coverage;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final List<RadarEntry> entries = <RadarEntry>[
      for (final axis in kExerciseMuscleAxes)
        RadarEntry(value: coverage[axis] ?? 0.0),
    ];
    final bool hasData = entries.any((entry) => entry.value > 0);

    if (!hasData) {
      return const ExerciseChartPlaceholder(
        icon: Icons.insights_outlined,
        message: 'Coverage data unavailable',
      );
    }

    // Updated: session-style polygon radar, soft grid, subtle fill, no dots.
    return RadarChart(
      RadarChartData(
        dataSets: [
          RadarDataSet(
            dataEntries: entries,
            fillColor: accentColor.withValues(alpha: 0.22),
            borderColor: accentColor,
            borderWidth: 2.2,
            entryRadius: 0, // no dots, just the shape
          ),
        ],
        radarBackgroundColor: Colors.transparent,
        radarBorderData: BorderSide(
          color: Colors.black.withValues(alpha: 0.04),
          width: 0.6,
        ),
        radarShape: RadarShape.polygon,
        titleTextStyle: TextStyle(
          color: Colors.black.withValues(alpha: 0.78),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        getTitle: (index, angle) => RadarChartTitle(
          text: kExerciseMuscleAxes[index],
          angle: angle,
        ),
        tickCount: 4,
        ticksTextStyle: TextStyle(
          color: Colors.black.withValues(alpha: 0.35),
          fontSize: 9,
        ),
        tickBorderData: BorderSide(
          color: Colors.black.withValues(alpha: 0.08),
          width: 0.7,
        ),
        gridBorderData: BorderSide(
          color: Colors.black.withValues(alpha: 0.12),
          width: 0.8,
        ),
        radarTouchData: RadarTouchData(enabled: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black45),
        ),
      ),
    );
  }
}
