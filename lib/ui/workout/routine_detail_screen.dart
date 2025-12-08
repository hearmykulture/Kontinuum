// lib/ui/workout/routine_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/ui/workout/workout_editor_screen.dart';
import 'package:kontinuum/ui/workout/session_screen.dart' show SessionScreen;
import 'package:kontinuum/ui/workout/session_screen_args.dart';
import 'package:kontinuum/ui/workout/workout_editor_widgets.dart'
    show SchedulePatternConfig, SchedulePatternMode, SchedulePatternPicker;
import 'package:kontinuum/ui/theme/app_colors.dart';

class RoutineDetailArgs {
  final String routineId;
  const RoutineDetailArgs({required this.routineId});
}

/// Match WorkoutDashboard blue/black style.
/// - bg: #090A0E
/// - surfaces: translucent white overlays
/// - accent: blueAccent
class _RoutineDetailPalette {
  static const Color background = Color(0xFF090A0E); // dashboard bg
  static Color get card => Colors.white.withValues(alpha: .03);
  static Color get cardBright => Colors.white.withValues(alpha: .06);
  static Color get cardSoft => Colors.white.withValues(alpha: .03);

  static const Color onCardPrimary = Colors.white;
  static const Color onCardSecondary = Color(0xA8FFFFFF);

  static const Color divider = Color(0x11FFFFFF); // subtle like dashboard
  static const Color accent = AppColors.accentBlue;
  static const Color danger = Color(0xFFFF6B81);
}

class RoutineDetailScreen extends StatelessWidget {
  const RoutineDetailScreen({super.key});

  Routine? _findRoutineById(List<Routine> list, String id) {
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  }

  // create first → then open editor
  Future<void> _openAddWorkoutEditor(
    BuildContext context,
    Routine routine,
  ) async {
    final wp = context.read<WorkoutProvider>();

    final newWorkout = await wp.createWorkout(
      title: 'New workout',
      attachToRoutineId: routine.id,
    );

    if (!context.mounted) return;

    await Navigator.of(context).pushNamed(
      '/workoutEditor',
      arguments: WorkoutEditorArgs(
        workoutId: newWorkout.id,
        attachToRoutineId: routine.id,
      ),
    );
  }

  Future<void> _openEditWorkout(
    BuildContext context,
    Workout workout,
  ) async {
    await Navigator.of(context).pushNamed(
      '/workoutEditor',
      arguments: WorkoutEditorArgs(
        workoutId: workout.id,
      ),
    );
  }

  // duplicate → attach → toast → open
  Future<void> _duplicateWorkout(
    BuildContext context, {
    required Routine routine,
    required Workout workout,
  }) async {
    final wp = context.read<WorkoutProvider>();

    // shallow clone blocks/items
    final clonedBlocks = workout.blocks.map((b) {
      return WorkoutBlock(
        type: b.type,
        title: b.title,
        items: b.items.map((it) {
          return WorkoutItem(
            exerciseId: it.exerciseId,
            targetSets: it.targetSets,
            targetReps: it.targetReps,
            targetTimeSec: it.targetTimeSec,
            restSec: it.restSec,
            targetLoad: it.targetLoad,
            notes: it.notes,
            cueChips: List<String>.from(it.cueChips),
            formChecks: List<String>.from(it.formChecks),
            consecutiveMisses: it.consecutiveMisses,
            lastSuggestedLoadKg: it.lastSuggestedLoadKg,
            lastTargetReps: it.lastTargetReps,
            lastLoggedRpe: it.lastLoggedRpe,
            adaptiveSetsEnabled: it.adaptiveSetsEnabled,
            adaptivePercent: it.adaptivePercent,
          );
        }).toList(),
      );
    }).toList();

    final created = await wp.createWorkout(
      title: '${workout.title} (copy)',
      notes: workout.notes,
      blocks: clonedBlocks,
      attachToRoutineId: routine.id,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "${workout.title}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await Navigator.of(context).pushNamed(
      '/workoutEditor',
      arguments: WorkoutEditorArgs(
        workoutId: created.id,
        attachToRoutineId: routine.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as RoutineDetailArgs?;
    if (args == null) {
      return const Scaffold(
        backgroundColor: _RoutineDetailPalette.background,
        body: Center(
          child: Text(
            'No routine selected',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final workoutProv = context.watch<WorkoutProvider>();
    final routine = _findRoutineById(workoutProv.routines, args.routineId);

    if (routine == null) {
      return const Scaffold(
        backgroundColor: _RoutineDetailPalette.background,
        body: Center(
          child: Text(
            'Routine not found',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // workouts that belong to this routine, preserving order
    final allWorkouts = workoutProv.workouts;
    final routineWorkouts = <Workout>[
      for (final wid in routine.workoutIds)
        ...allWorkouts.where((w) => w.id == wid),
    ];

    Future<void> confirmDeleteRoutine() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: _RoutineDetailPalette.background,
            title: const Text(
              'Delete routine?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'This will remove "${routine.name}" from your workouts.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: _RoutineDetailPalette.danger),
                ),
              ),
            ],
          );
        },
      );

      if (ok == true) {
        await context.read<WorkoutProvider>().deleteRoutine(routine.id);

        if (!context.mounted) return;

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${routine.name}"')),
        );
      }
    }

    final mediaPadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: _RoutineDetailPalette.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _AddWorkoutFab(
        onTap: () => _openAddWorkoutEditor(context, routine),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: mediaPadding.top,
          bottom: mediaPadding.bottom,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: double.infinity,
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 140),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 28,
                  ),
                  child: _RoutineDetailCard(
                    routine: routine,
                    workouts: routineWorkouts,
                    onAddWorkout: () => _openAddWorkoutEditor(context, routine),
                    onStartWorkout: (workout) {
                      final prov = context.read<WorkoutProvider>();

                      final result = prov.startSession(
                        routineId: routine.id,
                        workoutId: workout.id,
                        source: 'routine_detail',
                      );
                      if (!result.started) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.message ??
                                  'Unable to start that workout session.',
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
                              source: 'routine_detail',
                            ),
                          ),
                          settings:
                              const RouteSettings(name: 'session_from_routine'),
                        ),
                      );
                    },
                    onEditWorkout: (workout) =>
                        _openEditWorkout(context, workout),
                    onCopyWorkout: (workout) => _duplicateWorkout(
                      context,
                      routine: routine,
                      workout: workout,
                    ),
                    onDeleteWorkout: (workout) async {
                      final prov = context.read<WorkoutProvider>();
                      await prov.deleteWorkout(workout.id);

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Deleted "${workout.title}"')),
                      );
                    },
                    onBack: () => Navigator.of(context).maybePop(),
                    onDeleteRoutine: confirmDeleteRoutine,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoutineDetailCard extends StatelessWidget {
  final Routine routine;
  final List<Workout> workouts;
  final VoidCallback onAddWorkout;
  final void Function(Workout) onStartWorkout;
  final void Function(Workout) onEditWorkout;
  final void Function(Workout) onCopyWorkout;
  final Future<void> Function(Workout) onDeleteWorkout;
  final VoidCallback onBack;
  final Future<void> Function() onDeleteRoutine;

  const _RoutineDetailCard({
    required this.routine,
    required this.workouts,
    required this.onAddWorkout,
    required this.onStartWorkout,
    required this.onEditWorkout,
    required this.onCopyWorkout,
    required this.onDeleteWorkout,
    required this.onBack,
    required this.onDeleteRoutine,
  });

  String _goalLabel(DietGoal goal) {
    switch (goal) {
      case DietGoal.cut:
        return 'Cut';
      case DietGoal.maintain:
        return 'Maintain';
      case DietGoal.bulk:
        return 'Bulk';
    }
  }

  String _strictLabel(DietStrictness strictness) {
    switch (strictness) {
      case DietStrictness.soft:
        return 'Soft';
      case DietStrictness.hard:
        return 'Hard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdDate =
        DateTime.fromMillisecondsSinceEpoch(routine.createdAtMs).toLocal();

    final dietSummary =
        '${_goalLabel(routine.diet.goal)} • ${routine.diet.kcalPerDay} kcal • '
        '${routine.diet.proteinTargetG}g protein • ${_strictLabel(routine.diet.strictness)}';

    final nudgeText =
        (routine.poEnabled && routine.diet.strictness == DietStrictness.soft)
            ? 'Add protein on training days for better progress.'
            : null;

    // Removed soft glow: no outer shadow wrapper
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _RoutineDetailPalette.onCardPrimary,
              ),
            ),
            Expanded(
              child: Text(
                routine.name,
                style: const TextStyle(
                  color: _RoutineDetailPalette.onCardPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Delete routine',
              onPressed: () {
                onDeleteRoutine();
              },
              icon: const Icon(
                Icons.delete_outline,
                color: _RoutineDetailPalette.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _PoChip(enabled: routine.poEnabled),
              const SizedBox(width: 12),
              Text(
                'Created ${createdDate.toString().split(' ').first}',
                style: const TextStyle(
                  color: _RoutineDetailPalette.onCardSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _InfoBlock(
            icon: Icons.local_fire_department_outlined,
            text: dietSummary,
          ),
        ),
        if (nudgeText != null) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _InfoBlock(
              icon: Icons.info_outline,
              text: nudgeText,
              highlight: true,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _RoutineScheduleSection(routine: routine),
        ),
        const SizedBox(height: 28),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: _RoutineDivider(),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Workouts',
            style: TextStyle(
              color: _RoutineDetailPalette.onCardPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (workouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _RoutineEmptyState(onAddWorkout: onAddWorkout),
          )
        else ...[
          for (final workout in workouts) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _RoutineWorkoutTile(
                workout: workout,
                onStart: () => onStartWorkout(workout),
                onEdit: () => onEditWorkout(workout),
                onCopy: () => onCopyWorkout(workout),
                onDelete: () => onDeleteWorkout(workout),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _RoutineAddWorkoutTile(onTap: onAddWorkout),
        ),
      ],
    );
  }
}

class _RoutineDivider extends StatelessWidget {
  const _RoutineDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: double.infinity,
      color: _RoutineDetailPalette.divider,
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _InfoBlock({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color background = highlight
        ? _RoutineDetailPalette.cardBright
        : _RoutineDetailPalette.cardSoft;
    final Color iconColor = Colors.white.withValues(alpha: highlight ? 1 : 0.85);
    final TextStyle style = TextStyle(
      color: Colors.white.withValues(alpha: highlight ? 0.95 : 0.78),
      fontSize: 13,
      fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
      height: 1.4,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: highlight ? 0.10 : 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineScheduleSection extends StatefulWidget {
  final Routine routine;

  const _RoutineScheduleSection({required this.routine});

  @override
  State<_RoutineScheduleSection> createState() =>
      _RoutineScheduleSectionState();
}

class _RoutineScheduleSectionState extends State<_RoutineScheduleSection> {
  // NOTE: 1 = Mon, ... 7 = Sun
  static const List<String> _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  late SchedulePatternConfig _workoutConfig;
  late SchedulePatternConfig _restConfig;
  bool _restOnOffDays = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();

    // These defaults are UI-only. Once your Routine model exposes schedule
    // metadata, hydrate from it instead of the hard-coded patterns.
    _workoutConfig = const SchedulePatternConfig.weekly({1, 3, 5});
    _restConfig = const SchedulePatternConfig.weekly({2, 4, 6, 7});

    // If you already have saved rest/workout patterns on the routine,
    // map them into the configs here.
    //
    // Example (pseudo):
    // final meta = widget.routine.scheduleMeta;
    // _workoutConfig = meta.toWorkoutConfig();
    // _restConfig = meta.toRestConfig();
  }

  void _onWorkoutChanged(SchedulePatternConfig cfg) {
    setState(() {
      _workoutConfig = cfg;
      _dirty = true;
    });

    if (_restOnOffDays) {
      _syncRestFromWorkout(cfg);
    }
  }

  void _syncRestFromWorkout(SchedulePatternConfig workCfg) {
    setState(() {
      if (workCfg.mode == SchedulePatternMode.weekly) {
        const allDays = {1, 2, 3, 4, 5, 6, 7};
        final restDays = allDays.difference(workCfg.weeklyDays);
        _restConfig = SchedulePatternConfig.weekly(
          restDays.isEmpty ? allDays : restDays,
        );
      } else {
        _restConfig = SchedulePatternConfig.interval(workCfg.intervalDays);
      }
      _dirty = true;
    });
  }

  bool get _isValid => _workoutConfig.isValid && _restConfig.isValid;

  String _describeConfig(String label, SchedulePatternConfig cfg) {
    if (cfg.mode == SchedulePatternMode.weekly) {
      if (cfg.weeklyDays.isEmpty) {
        return '$label: —';
      }
      final days = cfg.weeklyDays.toList()..sort();
      final names = days.map((d) {
        final idx = (d - 1).clamp(0, _weekdayNames.length - 1);
        return _weekdayNames[idx];
      }).join(', ');
      return '$label: $names';
    } else {
      final n = cfg.intervalDays;
      return '$label: Every $n day${n == 1 ? '' : 's'}';
    }
  }

  String _buildSummary() {
    final work = _describeConfig('Workout', _workoutConfig);
    final rest = _describeConfig('Rest', _restConfig);
    return '$work • $rest';
  }

  Future<void> _save() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose at least one workout day and a valid rest pattern.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // TODO: Persist schedule + rest metadata into the Routine model.
    //
    // You likely want something like:
    //
    // final prov = context.read<WorkoutProvider>();
    // await prov.updateRoutineSchedules(
    //   widget.routine.id,
    //   workoutConfig: _workoutConfig,
    //   restConfig: _restConfig,
    // );
    //
    // And a corresponding value object (e.g. RoutineScheduleMeta) on Routine.

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated schedule for "${widget.routine.name}".'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _buildSummary();
    final restValid = _restConfig.isValid;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: _RoutineDetailPalette.cardSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule & rest days',
                      style: TextStyle(
                        color: _RoutineDetailPalette.onCardPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Shared with dashboard, reminders & deload logic.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ScheduleStatusPill(
                label:
                    restValid ? (_dirty ? 'Unsaved' : 'OK') : 'Rest required',
                color: restValid
                    ? (_dirty
                        ? _RoutineDetailPalette.accent.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.10))
                    : _RoutineDetailPalette.danger.withValues(alpha: 0.16),
                textColor: restValid
                    ? (_dirty
                        ? _RoutineDetailPalette.accent
                        : Colors.white.withValues(alpha: 0.88))
                    : _RoutineDetailPalette.danger,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SchedulePatternPicker(
            title: 'Workout schedule',
            subtitle: 'When this routine is active',
            value: _workoutConfig,
            onChanged: _onWorkoutChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: _restOnOffDays,
                activeColor: _RoutineDetailPalette.accent,
                onChanged: (v) {
                  setState(() => _restOnOffDays = v);
                  if (v) {
                    _syncRestFromWorkout(_workoutConfig);
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Automatically rest on non-workout days.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _syncRestFromWorkout(_workoutConfig),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy pattern'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SchedulePatternPicker(
            title: 'Rest schedule',
            subtitle: 'Explicit off-days / deload pattern',
            value: _restConfig,
            onChanged: (cfg) {
              setState(() {
                _restConfig = cfg;
                _dirty = true;
              });
            },
          ),
          const SizedBox(height: 10),
          _SchedulePreviewChip(summary: summary),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isValid ? _save : null,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save schedule'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _ScheduleStatusPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SchedulePreviewChip extends StatelessWidget {
  final String summary;

  const _SchedulePreviewChip({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 16,
            color: Colors.white.withValues(alpha: 0.82),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoChip extends StatelessWidget {
  final bool enabled;
  const _PoChip({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final Color background = Colors.white.withValues(alpha: enabled ? 0.14 : 0.07);
    final Color textColor = Colors.white.withValues(alpha: enabled ? 0.95 : 0.65);
    final IconData icon =
        enabled ? Icons.trending_up : Icons.pause_circle_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            enabled ? 'PO ON' : 'PO OFF',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineEmptyState extends StatelessWidget {
  final VoidCallback onAddWorkout;

  const _RoutineEmptyState({required this.onAddWorkout});

  @override
  Widget build(BuildContext context) {
    final Color outline = Colors.white.withValues(alpha: 0.06);
    return GestureDetector(
      onTap: onAddWorkout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: _RoutineDetailPalette.cardSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_run_outlined,
              size: 36,
              color: Colors.white.withValues(alpha: 0.82),
            ),
            const SizedBox(height: 12),
            const Text(
              'No workouts yet',
              style: TextStyle(
                color: _RoutineDetailPalette.onCardPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to add your first workout to this routine.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineWorkoutTile extends StatelessWidget {
  final Workout workout;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final Future<void> Function() onDelete;

  const _RoutineWorkoutTile({
    required this.workout,
    required this.onStart,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color border = Colors.white.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: _RoutineDetailPalette.cardBright,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    workout.title,
                    style: const TextStyle(
                      color: _RoutineDetailPalette.onCardPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${workout.blocks.length} blocks',
                  style: const TextStyle(
                    color: _RoutineDetailPalette.onCardSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (workout.notes != null && workout.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                workout.notes!.trim(),
                style: const TextStyle(
                  color: _RoutineDetailPalette.onCardSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RoutineActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Start',
                  onTap: onStart,
                  primary: true,
                ),
                _RoutineActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: onEdit,
                ),
                _RoutineActionButton(
                  icon: Icons.copy_outlined,
                  label: 'Copy',
                  onTap: onCopy,
                ),
                _RoutineActionButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onTap: () async {
                    await onDelete();
                  },
                  danger: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  const _RoutineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    if (danger) {
      background = _RoutineDetailPalette.cardSoft;
    } else if (primary) {
      background = _RoutineDetailPalette.accent.withValues(alpha: .18);
    } else {
      background = _RoutineDetailPalette.cardSoft;
    }

    final Color borderColor = danger
        ? _RoutineDetailPalette.danger.withValues(alpha: 0.38)
        : primary
            ? _RoutineDetailPalette.accent.withValues(alpha: .28)
            : Colors.white.withValues(alpha: 0.12);
    final Color textColor = danger
        ? _RoutineDetailPalette.danger
        : Colors.white.withValues(alpha: primary ? 0.95 : 0.85);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineAddWorkoutTile extends StatelessWidget {
  final VoidCallback onTap;
  const _RoutineAddWorkoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color border = Colors.white.withValues(alpha: 0.12);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _RoutineDetailPalette.cardSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            const Text(
              'Add workout',
              style: TextStyle(
                color: _RoutineDetailPalette.onCardPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWorkoutFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddWorkoutFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add, color: Colors.black),
            SizedBox(width: 10),
            Text(
              'Add workout',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
