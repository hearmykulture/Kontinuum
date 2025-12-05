import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/ui/workout/session_widgets/workout_elapsed_tracker.dart';
import 'package:kontinuum/ui/workout/workout_editor_constants.dart';
import 'package:kontinuum/utils/text_format.dart';
import 'package:kontinuum/core/time/app_clock.dart';

const Color _kBgColor = Color(0xFF0A0A0A);
const Color _kRailBase = Color(0xFF252525);
const Color _kCardBg = Color(0xFF151515);
const Color _kBorderSoft = Color(0xFF323232);
const Color _kAccent = Color(0xFF00F5A8);
const int _kBlockGapSeconds = 60;
const int _kDefaultSetSeconds = 75;
const int _kDefaultWarmupSeconds = 240;
const int _kDefaultCooldownSeconds = 180;

class WorkoutTimelineScreen extends StatelessWidget {
  const WorkoutTimelineScreen({
    super.key,
    this.data,
    this.workout,
    this.currentFlatIndex,
    this.currentBlockIndex,
    this.currentExerciseIndex,
    this.currentSetIndex = 0,
    this.initialElapsed,
    this.initialTimerRunning,
    this.initialAnchor,
  });

  /// Optional: pass in real workout timeline data.
  final WorkoutTimelineData? data;

  /// Optional: full workout definition; takes precedence over [data].
  final Workout? workout;

  /// Flat index into the flattened timeline (workout header, blocks, exercises).
  /// 0 = workout header, 1 = first block, 2 = first exercise, ...
  final int? currentFlatIndex;

  /// Currently focused block and exercise indices.
  final int? currentBlockIndex;
  final int? currentExerciseIndex;

  /// Current set index (0-based) for the *current exercise*.
  final int currentSetIndex;
  final Duration? initialElapsed;
  final bool? initialTimerRunning;
  final DateTime? initialAnchor;

  @override
  Widget build(BuildContext context) {
    final WorkoutTimelineData workoutData =
        workout != null ? _buildTimelineDataFromWorkout(workout!) : (data ?? _mockWorkout);

    final List<_TimelineItem> items = _buildTimelineItems(workoutData);

    int? derivedIndex;
    if (workout != null) {
      derivedIndex = _findFlatIndexFor(
        items: items,
        blockIndex: currentBlockIndex,
        exerciseIndex: currentExerciseIndex,
      );
    }

    final int safeCurrentIndex = items.isEmpty
        ? 0
        : (currentFlatIndex ?? derivedIndex ?? 0)
            .clamp(0, items.length - 1);

    final _TimelineItem currentItem = items[safeCurrentIndex];

    return ValueListenableBuilder<WorkoutElapsedState>(
      valueListenable: WorkoutElapsedTracker.instance,
      builder: (context, state, _) {
        final bool trackerActive =
            state.elapsed > Duration.zero || state.running;
        final Duration elapsed = trackerActive
            ? state.elapsed
            : (initialElapsed ?? Duration.zero);
        final bool timerRunning =
            trackerActive ? state.running : (initialTimerRunning ?? false);
        final DateTime baseTime =
            state.anchor ??
                initialAnchor ??
                AppClock.now().subtract(elapsed);

        return Scaffold(
          backgroundColor: _kBgColor,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 56),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 8.0),
                          child: _CurrentStatusHeader(
                            workout: workoutData,
                            items: items,
                            currentItem: currentItem,
                            currentSetIndex: currentSetIndex,
                            elapsed: elapsed,
                            timerRunning: timerRunning,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final _TimelineItem item = items[index];
                              final bool isFirst = index == 0;
                              final bool isLast = index == items.length - 1;
                              final bool isCurrent = index == safeCurrentIndex;
                              final bool isCompleted = index < safeCurrentIndex;

                              final bool isExercise =
                                  item.type == _TimelineItemType.exercise;
                              final int? totalSets = item.sets;

                              int? filledSets;
                              if (isExercise &&
                                  totalSets != null &&
                                  totalSets > 0) {
                                if (isCompleted) {
                                  filledSets = totalSets;
                                } else if (isCurrent) {
                                  filledSets =
                                      (currentSetIndex + 1).clamp(0, totalSets);
                                } else {
                                  filledSets = 0;
                                }
                              }

                              final String timeLabel = _formatTimeOfDay(
                                baseTime.add(
                                  Duration(seconds: item.timelineSeconds),
                                ),
                              );

                              return _TimelineRow(
                                item: item,
                                isFirst: isFirst,
                                isLast: isLast,
                                isCurrent: isCurrent,
                                isCompleted: isCompleted,
                                totalSets: totalSets,
                                filledSets: filledSets,
                                timeLabel: timeLabel,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 16,
                  child: IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ──────────────────────────────────────────────────────────────
   CURRENT STATUS HEADER
   Shows "what block / exercise / set you're on"
   ────────────────────────────────────────────────────────────── */

class _CurrentStatusHeader extends StatelessWidget {
  const _CurrentStatusHeader({
    required this.workout,
    required this.items,
    required this.currentItem,
    required this.currentSetIndex,
    required this.elapsed,
    required this.timerRunning,
  });

  final WorkoutTimelineData workout;
  final List<_TimelineItem> items;
  final _TimelineItem currentItem;
  final int currentSetIndex;
  final Duration elapsed;
  final bool timerRunning;

  @override
  Widget build(BuildContext context) {
    final String blockLabel = currentItem.type == _TimelineItemType.block
        ? currentItem.title
        : (currentItem.parentBlockName ?? '—');

    final String exerciseLabel = currentItem.type == _TimelineItemType.exercise
        ? currentItem.title
        : '—';

    final int? totalSets = currentItem.type == _TimelineItemType.exercise
        ? currentItem.sets
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  workout.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              _ElapsedChip(duration: elapsed, running: timerRunning),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.radio_button_checked,
                size: 14,
                color: _kAccent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Block: $blockLabel',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.fitness_center,
                size: 14,
                color: _kAccent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Exercise: $exerciseLabel',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (totalSets != null && totalSets > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.repeat,
                  size: 14,
                  color: _kAccent.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  'Set ${(currentSetIndex + 1).clamp(1, totalSets)} of $totalSets',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ElapsedChip extends StatelessWidget {
  const _ElapsedChip({required this.duration, required this.running});

  final Duration duration;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final String text = _formatElapsed(duration);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: running
            ? _kAccent.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: running
              ? _kAccent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: running ? _kAccent : Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: running ? _kAccent : Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/* ──────────────────────────────────────────────────────────────
   TIMELINE ROW (rail + node + card)
   ────────────────────────────────────────────────────────────── */

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    required this.isCompleted,
    this.totalSets,
    this.filledSets,
    required this.timeLabel,
  });

  final _TimelineItem item;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final bool isCompleted;
  final int? totalSets;
  final int? filledSets;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final bool isWorkout = item.type == _TimelineItemType.workoutHeader;
    final bool isBlock = item.type == _TimelineItemType.block;
    final bool isExercise = item.type == _TimelineItemType.exercise;

    final double nodeSize = isWorkout
        ? 18
        : isBlock
            ? 14
            : 10;

    final Color railColorTop = isFirst
        ? Colors.transparent
        : (isCompleted || isCurrent ? _kAccent : _kRailBase);

    final Color railColorBottom =
        isLast ? Colors.transparent : (isCompleted ? _kAccent : _kRailBase);

    final Color nodeBorderColor =
        (isCompleted || isCurrent) ? _kAccent : _kRailBase;

    final Color nodeFillColor = isCurrent
        ? _kAccent
        : (isCompleted ? _kAccent.withValues(alpha: 0.65) : _kBgColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2,
                      color: railColorTop,
                    ),
                  ),
                  Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      color: nodeFillColor,
                      shape: isExercise ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius:
                          isExercise ? BorderRadius.circular(3) : null,
                      border: Border.all(
                        color: nodeBorderColor,
                        width: isWorkout ? 2.2 : 1.6,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: railColorBottom,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TimelineCard(
                item: item,
                isCurrent: isCurrent,
                isCompleted: isCompleted,
                totalSets: totalSets,
                filledSets: filledSets,
                timeLabel: timeLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ──────────────────────────────────────────────────────────────
   TIMELINE CARD (workout / block / exercise)
   ────────────────────────────────────────────────────────────── */

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.item,
    required this.isCurrent,
    required this.isCompleted,
    this.totalSets,
    this.filledSets,
    required this.timeLabel,
  });

  final _TimelineItem item;
  final bool isCurrent;
  final bool isCompleted;
  final int? totalSets;
  final int? filledSets;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final bool isWorkout = item.type == _TimelineItemType.workoutHeader;
    final bool isBlock = item.type == _TimelineItemType.block;
    final bool isExercise = item.type == _TimelineItemType.exercise;

    final double radius = isWorkout ? 20 : 14;
    final EdgeInsets padding = isWorkout
        ? const EdgeInsets.all(16)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    final Color borderColor = isCurrent
        ? _kAccent.withValues(alpha: 0.9)
        : (isCompleted ? _kAccent.withValues(alpha: 0.4) : _kBorderSoft);

    // Local copies so Dart can promote them (fields don't promote).
    final int? localTotalSets = totalSets;
    final int? localFilledSets = filledSets;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWorkout
                    ? Icons.timeline
                    : isBlock
                        ? Icons.segment
                        : Icons.fitness_center,
                size: 16,
                color: _kAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWorkout ? 15 : 14,
                    fontWeight: isWorkout ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'NOW',
                    style: TextStyle(
                      color: _kAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ]
              else if (!isWorkout && isCompleted) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: _kAccent.withValues(alpha: 0.95),
                ),
              ],
            ],
          ),
          if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.subtitle!,
              maxLines: isWorkout ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
          if (isExercise &&
              localTotalSets != null &&
              localTotalSets > 0 &&
              localFilledSets != null) ...[
            const SizedBox(height: 8),
            _SetDotsRow(
              totalSets: localTotalSets,
              filledSets: localFilledSets,
            ),
          ],
        ],
      ),
    );
  }
}

/* ──────────────────────────────────────────────────────────────
   SET DOTS ROW (shows prescription progress per exercise)
   ────────────────────────────────────────────────────────────── */

class _SetDotsRow extends StatelessWidget {
  const _SetDotsRow({
    required this.totalSets,
    required this.filledSets,
  });

  final int totalSets;
  final int filledSets;

  @override
  Widget build(BuildContext context) {
    // Manual clamp to stay in 0..totalSets as int.
    final int safeFilled =
        filledSets < 0 ? 0 : (filledSets > totalSets ? totalSets : filledSets);

    return Row(
      children: [
        for (int i = 0; i < totalSets; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < safeFilled
                    ? _kAccent
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          '$safeFilled / $totalSets sets',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/* ──────────────────────────────────────────────────────────────
   DATA MODELS FOR THE TIMELINE
   (You can map your existing Workout/Block/Exercise models to these)
   ────────────────────────────────────────────────────────────── */

class WorkoutTimelineData {
  const WorkoutTimelineData({
    required this.name,
    required this.blocks,
  });

  final String name;
  final List<WorkoutTimelineBlockData> blocks;
}

class WorkoutTimelineBlockData {
  const WorkoutTimelineBlockData({
    required this.name,
    this.subtitle,
    required this.exercises,
    this.standaloneDurationSeconds,
    this.isBreak = false,
  });

  final String name;
  final String? subtitle;
  final List<WorkoutTimelineExerciseData> exercises;
  final int? standaloneDurationSeconds;
  final bool isBreak;
}

class WorkoutTimelineExerciseData {
  const WorkoutTimelineExerciseData({
    required this.name,
    required this.prescription,
    required this.sets,
    this.estimatedSeconds,
  });

  final String name;
  final String prescription;
  final int sets;
  final int? estimatedSeconds;
}

/* ──────────────────────────────────────────────────────────────
   INTERNAL FLATTENED TIMELINE ITEMS
   ────────────────────────────────────────────────────────────── */

enum _TimelineItemType { workoutHeader, block, exercise }

class _TimelineItem {
  const _TimelineItem._({
    required this.type,
    required this.title,
    this.subtitle,
    this.parentBlockName,
    this.blockIndex,
    this.exerciseIndex,
    this.sets,
    required this.timelineSeconds,
  });

  final _TimelineItemType type;
  final String title;
  final String? subtitle;
  final String? parentBlockName;
  final int? blockIndex;
  final int? exerciseIndex;
  final int? sets;
  final int timelineSeconds;

  factory _TimelineItem.workoutHeader({
    required String title,
    required int timelineSeconds,
  }) {
    return _TimelineItem._(
      type: _TimelineItemType.workoutHeader,
      title: title,
      timelineSeconds: timelineSeconds,
    );
  }

  factory _TimelineItem.block({
    required String title,
    String? subtitle,
    required int blockIndex,
    required int timelineSeconds,
  }) {
    return _TimelineItem._(
      type: _TimelineItemType.block,
      title: title,
      subtitle: subtitle,
      blockIndex: blockIndex,
      timelineSeconds: timelineSeconds,
    );
  }

  factory _TimelineItem.exercise({
    required String title,
    String? subtitle,
    required String parentBlockName,
    required int blockIndex,
    required int exerciseIndex,
    required int sets,
    required int timelineSeconds,
  }) {
    return _TimelineItem._(
      type: _TimelineItemType.exercise,
      title: title,
      subtitle: subtitle,
      parentBlockName: parentBlockName,
      blockIndex: blockIndex,
      exerciseIndex: exerciseIndex,
      sets: sets,
      timelineSeconds: timelineSeconds,
    );
  }
}

List<_TimelineItem> _buildTimelineItems(WorkoutTimelineData workout) {
  final List<_TimelineItem> items = <_TimelineItem>[];
  int cursorSeconds = 0;

  items.add(
    _TimelineItem.workoutHeader(
      title: workout.name,
      timelineSeconds: cursorSeconds,
    ),
  );

  for (int bi = 0; bi < workout.blocks.length; bi++) {
    final WorkoutTimelineBlockData block = workout.blocks[bi];

    items.add(
      _TimelineItem.block(
        title: block.name,
        subtitle: block.subtitle,
        blockIndex: bi,
        timelineSeconds: cursorSeconds,
      ),
    );

    final bool hasExercises = block.exercises.isNotEmpty;
    if (!hasExercises &&
        block.standaloneDurationSeconds != null &&
        block.standaloneDurationSeconds! > 0) {
      cursorSeconds += block.standaloneDurationSeconds!;
    }

    for (int ei = 0; ei < block.exercises.length; ei++) {
      final WorkoutTimelineExerciseData ex = block.exercises[ei];
      final int estimate =
          ex.estimatedSeconds ?? _defaultExerciseDuration(ex.sets);

      items.add(
        _TimelineItem.exercise(
          title: formatTitleCase(ex.name),
          subtitle: ex.prescription,
          parentBlockName: block.name,
          blockIndex: bi,
          exerciseIndex: ei,
          sets: ex.sets,
          timelineSeconds: cursorSeconds,
        ),
      );
      cursorSeconds += estimate;
    }

    cursorSeconds += _blockGapAfter(block);
  }

  return items;
}

WorkoutTimelineData _buildTimelineDataFromWorkout(Workout workout) {
  final ExerciseLibraryService library = ExerciseLibraryService.instance;

  final List<WorkoutTimelineBlockData> blocks = <WorkoutTimelineBlockData>[];

  for (int bi = 0; bi < workout.blocks.length; bi++) {
    final WorkoutBlock block = workout.blocks[bi];
    final String blockName = (block.title?.trim().isNotEmpty ?? false)
        ? block.title!.trim()
        : 'Block ${bi + 1}';
    String? blockSubtitle = _formatBlockSubtitle(block);
    final _BreakInfo? breakInfo = _parseBreakBlock(block);
    final bool isWarmup = _isWarmupBlock(block);
    final bool isCooldown = _isCooldownBlock(block);
    int? standaloneDuration;
    bool isBreak = false;

    if (breakInfo != null) {
      standaloneDuration = breakInfo.durationSeconds;
      isBreak = true;
      final String durationLabel =
          _formatDurationShort(breakInfo.durationSeconds);
      final String notes = breakInfo.notes.isNotEmpty
          ? ' • ${breakInfo.notes}'
          : '';
      blockSubtitle = 'Break • $durationLabel$notes';
    } else if ((isWarmup || isCooldown) && block.items.isEmpty) {
      standaloneDuration =
          isWarmup ? _kDefaultWarmupSeconds : _kDefaultCooldownSeconds;
      blockSubtitle ??=
          isWarmup ? 'Warm-up' : 'Cooldown';
    }

    final List<WorkoutTimelineExerciseData> exercises =
        <WorkoutTimelineExerciseData>[];

    for (int ei = 0; ei < block.items.length; ei++) {
      final WorkoutItem item = block.items[ei];
      final exercise =
          library.getById(item.exerciseId); // may be null if deleted
      final String exerciseName =
          exercise?.name ?? 'Exercise ${ei + 1}';
      final String prescription = _formatExercisePrescription(item);
      final int sets = item.targetSets < 0 ? 0 : item.targetSets;
      final int estimate = _estimateExerciseDurationFromItem(item);

      exercises.add(
        WorkoutTimelineExerciseData(
          name: exerciseName,
          prescription: prescription,
          sets: sets,
          estimatedSeconds: estimate,
        ),
      );
    }

    blocks.add(
      WorkoutTimelineBlockData(
        name: blockName,
        subtitle: blockSubtitle,
        exercises: exercises,
        standaloneDurationSeconds: standaloneDuration,
        isBreak: isBreak,
      ),
    );
  }

  final String workoutName =
      workout.title.trim().isEmpty ? 'Workout' : workout.title.trim();

  return WorkoutTimelineData(name: workoutName, blocks: blocks);
}

String? _formatBlockSubtitle(WorkoutBlock block) {
  final List<String> parts = <String>[];
  if (block.type != null) {
    final info = blockTypeInfo[block.type!];
    if (info != null) {
      parts.add(info.label);
    }
  }
  final String? note = block.note?.trim();
  if (note != null && note.isNotEmpty) {
    parts.add(note);
  }
  if (parts.isEmpty) return null;
  return parts.join(' • ');
}

String _formatExercisePrescription(WorkoutItem item) {
  final List<String> parts = <String>[];
  final int sets = item.targetSets;
  final int? reps = item.targetReps;
  final int? timeSec = item.targetTimeSec;
  if (sets > 0) {
    final String primary;
    if (reps != null && reps > 0) {
      primary = '$sets × $reps';
    } else if (timeSec != null && timeSec > 0) {
      primary = '$sets × ${_formatDurationShort(timeSec)}';
    } else {
      primary = '$sets sets';
    }
    parts.add(primary);
  } else if (timeSec != null && timeSec > 0) {
    parts.add(_formatDurationShort(timeSec));
  }

  final double? load = item.targetLoad;
  if (load != null && load > 0) {
    parts.add('@ ${_formatLoad(load)} kg');
  }

  final int? restSec = item.restSec;
  if (restSec != null && restSec > 0) {
    parts.add('Rest ${_formatDurationShort(restSec)}');
  }

  if (parts.isEmpty) {
    return '—';
  }
  return parts.join(' • ');
}

String _formatDurationShort(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final int minutes = seconds ~/ 60;
  final int remaining = seconds % 60;
  if (remaining == 0) return '${minutes}m';
  return '${minutes}m ${remaining}s';
}

String _formatLoad(double loadKg) {
  final double absValue = loadKg.abs();
  final bool isWhole =
      (absValue - absValue.round()).abs() < 0.01;
  return loadKg.toStringAsFixed(isWhole ? 0 : (absValue < 10 ? 2 : 1));
}

int _estimateExerciseDurationFromItem(WorkoutItem item) {
  final int sets = item.targetSets > 0 ? item.targetSets : 1;
  final int restSec =
      item.restSec != null && item.restSec! > 0 ? item.restSec! : 45;
  if (item.targetTimeSec != null && item.targetTimeSec! > 0) {
    return sets * (item.targetTimeSec! + restSec);
  }
  if (item.targetReps != null && item.targetReps! > 0) {
    final int movement = (item.targetReps! * 2).clamp(20, 120);
    return sets * (movement + restSec);
  }
  return sets * (45 + restSec);
}

int _defaultExerciseDuration(int sets) {
  final int safeSets = sets > 0 ? sets : 1;
  return safeSets * _kDefaultSetSeconds;
}

int _blockGapAfter(WorkoutTimelineBlockData block) {
  if (block.isBreak) return 0;
  if ((block.standaloneDurationSeconds ?? 0) > 0 &&
      block.exercises.isEmpty) {
    return 0;
  }
  return _kBlockGapSeconds;
}

int? _findFlatIndexFor({
  required List<_TimelineItem> items,
  int? blockIndex,
  int? exerciseIndex,
}) {
  if (items.isEmpty) return null;
  int? blockMatch;
  for (int i = 0; i < items.length; i++) {
    final _TimelineItem item = items[i];
    if (exerciseIndex != null &&
        item.type == _TimelineItemType.exercise &&
        item.blockIndex == blockIndex &&
        item.exerciseIndex == exerciseIndex) {
      return i;
    }
    if (blockIndex != null &&
        item.type == _TimelineItemType.block &&
        item.blockIndex == blockIndex) {
      blockMatch ??= i;
    }
  }
  return blockMatch;
}

String _formatElapsed(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes % 60;
  final int seconds = duration.inSeconds % 60;
  final String mm = minutes.toString().padLeft(2, '0');
  final String ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final String hh = hours.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
  return '$mm:$ss';
}

String _formatTimeOfDay(DateTime time) {
  return DateFormat.jm().format(time);
}

class _BreakInfo {
  final int durationSeconds;
  final String type;
  final String notes;
  _BreakInfo({
    required this.durationSeconds,
    required this.type,
    required this.notes,
  });
}

_BreakInfo? _parseBreakBlock(WorkoutBlock block) {
  if (block.type != null) return null;
  final note = block.note ?? '';
  if (!note.startsWith('duration:') || !note.contains('type:')) return null;
  int duration = 300;
  String breakType = 'break';
  String customNotes = '';
  for (final part in note.split('|')) {
    if (part.startsWith('duration:')) {
      duration = int.tryParse(part.substring(9)) ?? duration;
    } else if (part.startsWith('type:')) {
      breakType = part.substring(5);
    } else if (part.startsWith('notes:')) {
      customNotes = part.substring(6);
    }
  }
  final String label =
      breakType.isEmpty ? 'break' : breakType.replaceAll('_', ' ');
  final String notesLabel = customNotes.isNotEmpty
      ? customNotes
      : label[0].toUpperCase() + label.substring(1);
  return _BreakInfo(
    durationSeconds: duration.clamp(60, 1800),
    type: breakType,
    notes: notesLabel,
  );
}

bool _isWarmupBlock(WorkoutBlock block) {
  if (block.note == 'type:warmup') return true;
  if ((block.note ?? '').isEmpty) {
    final title = block.title?.toLowerCase() ?? '';
    return title.contains('warmup') || title.contains('warm-up');
  }
  return false;
}

bool _isCooldownBlock(WorkoutBlock block) {
  if (block.note == 'type:cooldown') return true;
  if ((block.note ?? '').isEmpty) {
    final title = block.title?.toLowerCase() ?? '';
    return title.contains('cooldown') || title.contains('cool-down');
  }
  return false;
}

/* ──────────────────────────────────────────────────────────────
   MOCK DATA (so the screen renders immediately)
   Replace with real data from your WorkoutProvider / session.
   ────────────────────────────────────────────────────────────── */

const WorkoutTimelineData _mockWorkout = WorkoutTimelineData(
  name: 'Upper Body Power',
  blocks: <WorkoutTimelineBlockData>[
    WorkoutTimelineBlockData(
      name: 'Warm-up & Activation',
      subtitle: 'Ramp-up / mobility',
      exercises: <WorkoutTimelineExerciseData>[
        WorkoutTimelineExerciseData(
          name: 'Band Pull-Aparts',
          prescription: '2 × 20 • light tension',
          sets: 2,
          estimatedSeconds: 180,
        ),
        WorkoutTimelineExerciseData(
          name: 'Scap Push-Ups',
          prescription: '2 × 12 • bodyweight',
          sets: 2,
          estimatedSeconds: 180,
        ),
      ],
    ),
    WorkoutTimelineBlockData(
      name: 'Main Strength',
      subtitle: 'Heavy compounds',
      exercises: <WorkoutTimelineExerciseData>[
        WorkoutTimelineExerciseData(
          name: 'Barbell Bench Press',
          prescription: '4 × 5 @ RPE 7–8',
          sets: 4,
          estimatedSeconds: 600,
        ),
        WorkoutTimelineExerciseData(
          name: 'Pendlay Row',
          prescription: '4 × 6–8 @ RPE 7',
          sets: 4,
          estimatedSeconds: 600,
        ),
      ],
    ),
    WorkoutTimelineBlockData(
      name: 'Finisher',
      subtitle: 'Conditioning / pump',
      exercises: <WorkoutTimelineExerciseData>[
        WorkoutTimelineExerciseData(
          name: 'Battle Ropes',
          prescription: '3 × 30s • hard',
          sets: 3,
          estimatedSeconds: 420,
        ),
      ],
    ),
  ],
);
