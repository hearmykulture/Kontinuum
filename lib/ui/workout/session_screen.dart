import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/services/workout_stat_engine.dart';

import 'workout_editor_constants.dart';
import 'workout_overview_screen.dart';
import 'session_screen_args.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key, this.args});

  final SessionScreenArgs? args;

  SessionScreenArgs _resolveArgs(BuildContext context) {
    if (args != null) return args!;
    final Object? routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is SessionScreenArgs) return routeArgs;
    return const SessionScreenArgs();
  }

  @override
  Widget build(BuildContext context) {
    final SessionScreenArgs resolvedArgs = _resolveArgs(context);

    final workoutProvider = context.watch<WorkoutProvider>();
    final FitnessNutritionProfile? profile =
        context.watch<FitnessProfileProvider>().profile;

    final SessionDraft? activeDraft = workoutProvider.activeDraft;
    final String? workoutId =
        resolvedArgs.workoutId ?? activeDraft?.workoutId;
    final Workout? workout =
        workoutId != null ? workoutProvider.getWorkoutById(workoutId) : null;

    final WorkoutStatSummary? summary = workout != null
        ? WorkoutStatEngine.instance
            .summarize(workout: workout, profile: profile)
        : null;

    final SessionScreenArgs navArgs = SessionScreenArgs(
      workoutId: workout?.id ?? resolvedArgs.workoutId ?? activeDraft?.workoutId,
      attachToRoutineId: resolvedArgs.attachToRoutineId ?? activeDraft?.routineId,
    );

    return Scaffold(
      backgroundColor: kEditorBg,
      appBar: AppBar(
        backgroundColor: kEditorBg,
        foregroundColor: kPrimaryText,
        elevation: 0,
        title: const Text('Session'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: workout == null
              ? _EmptyWorkoutState(onStartPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutOverviewScreen(args: navArgs),
                    ),
                  );
                })
              : _SessionOverview(
                  workout: workout,
                  summary: summary,
                  onStartPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorkoutOverviewScreen(args: navArgs),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _SessionOverview extends StatelessWidget {
  const _SessionOverview({
    required this.workout,
    required this.summary,
    required this.onStartPressed,
  });

  final Workout workout;
  final WorkoutStatSummary? summary;
  final VoidCallback onStartPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final WorkoutStatSummary? stats = summary;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    workout.title.isEmpty ? 'Untitled Workout' : workout.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: kPrimaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (stats != null) ...[
                    _DifficultyRow(rating: stats.starRating),
                    const SizedBox(height: 12),
                    _DifficultyLabel(rating: stats.starRating),
                    const SizedBox(height: 24),
                    _MuscleGroupSection(muscles: stats.muscles),
                  ] else ...[
                    Text(
                      'We\'ll tailor difficulty once you add exercises to this workout.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: kSecondaryText),
                    ),
                  ],
                  if ((workout.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _NotesCard(notes: workout.notes!),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onStartPressed,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start'),
            style: FilledButton.styleFrom(
              backgroundColor: kEditorAccent,
              foregroundColor: kEditorBg,
              minimumSize: const Size.fromHeight(56),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(5, (index) {
          final starPosition = index + 1;
          IconData icon;
          if (rating >= starPosition) {
            icon = Icons.star_rounded;
          } else if (rating >= starPosition - 0.5) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_border_rounded;
          }
          return Padding(
            padding: EdgeInsets.only(right: index == 4 ? 0 : 4),
            child: Icon(
              icon,
              color: kEditorAccent,
              size: 24,
            ),
          );
        }),
      ],
    );
  }
}

class _DifficultyLabel extends StatelessWidget {
  const _DifficultyLabel({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          rating.toStringAsFixed(rating == rating.roundToDouble() ? 0 : 1),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: kPrimaryText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Difficulty',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kSecondaryText,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _MuscleGroupSection extends StatelessWidget {
  const _MuscleGroupSection({required this.muscles});

  final Set<String> muscles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (muscles.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Targeted Muscles',
            style: theme.textTheme.titleMedium?.copyWith(
              color: kPrimaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll surface muscle groups once each exercise is mapped.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: kSecondaryText),
          ),
        ],
      );
    }

    final List<String> sortedMuscles = muscles.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Targeted Muscles',
          style: theme.textTheme.titleMedium?.copyWith(
            color: kPrimaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sortedMuscles.join(', '),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: kSecondaryText,
          ),
        ),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kEditorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kEditorOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coach Notes',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: kPrimaryText,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: kPrimaryText),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkoutState extends StatelessWidget {
  const _EmptyWorkoutState({required this.onStartPressed});

  final VoidCallback onStartPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.fitness_center,
          color: kSecondaryText,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'No workout selected yet.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: kPrimaryText,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick a workout to see session details and jump in.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: kSecondaryText),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: onStartPressed,
          icon: const Icon(Icons.view_week_rounded),
          label: const Text('Choose Workout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryText,
            foregroundColor: kEditorBg,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}
