// lib/ui/workout/workout_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/services/workout_stat_engine.dart';
import 'package:kontinuum/utils/text_format.dart';

import 'workout_editor_constants.dart';
import 'add_exercise_popup_route.dart';
import 'session_screen_args.dart';
import 'empty_session_screen.dart';
import 'workout_timeline_screen.dart';
import 'session_widgets/action_bar_widgets.dart';
import 'session_widgets/muscle_utils.dart';
import 'session_widgets/overview_screen_widgets.dart';
import 'session_widgets/session_screen_widgets.dart'
    show DifficultyRatingSection, ExerciseRadarChart;
import 'session_widgets/workout_elapsed_tracker.dart';
import 'package:kontinuum/core/time/app_clock.dart';

const String _kActionBarHeroTag = 'workoutActionBarHero';

typedef WorkoutOverviewStartOverride = Future<void> Function({
  bool resume,
  required int focusedBlockIndex,
});

class WorkoutOverviewScreen extends StatefulWidget {
  const WorkoutOverviewScreen({super.key, this.args, this.onStartOverride});
  final SessionScreenArgs? args;
  final WorkoutOverviewStartOverride? onStartOverride;

  @override
  State<WorkoutOverviewScreen> createState() => _WorkoutOverviewScreenState();
}

class _WorkoutOverviewScreenState extends State<WorkoutOverviewScreen> {
  late final PageController _pageCtrl;

  // Notes state (controller is shared; focus is managed per-scope)
  final TextEditingController _notesCtrl = TextEditingController();
  bool _showNotesEditor = true;

  final WeightUnit _weightUnit = WeightUnit.kg;

  Workout? _workout;
  String? _attachToRoutineId;
  DateTime? _scheduledDate;
  WorkoutStatSummary? _sessionStats;

  bool _showContent = false;
  bool _exitingToSession = false;
  int _focusedBlockIndex = 0;
  int _focusedItemIndex = 0;
  bool _hasResumableSession = false;

  // Which exercise card (by key) is expanded in the session overview.
  String? _expandedExercisePillKey;

  @override
  void initState() {
    super.initState();
    final int initialPage =
        widget.onStartOverride != null ? _focusedBlockIndex : _focusedItemIndex;
    _pageCtrl = PageController(initialPage: initialPage);
    _checkForResumableSession();
  }

  void _checkForResumableSession() {
    final workout = _workout;
    if (workout == null || workout.id.isEmpty) {
      if (_hasResumableSession) {
        setState(() => _hasResumableSession = false);
      }
      return;
    }

    final DateTime effectiveDate = _scheduledDate ?? AppClock.now();
    final String ymd = SessionPersistenceService.dateTimeToYmd(effectiveDate);

    final session = SessionPersistenceService.getSessionFor(
      workoutId: workout.id,
      scheduledDateYmd: ymd,
    );

    final bool hasSession = session != null;
    if (hasSession != _hasResumableSession) {
      setState(() => _hasResumableSession = hasSession);
    }
  }

  void _recomputeSessionStats() {
    if (widget.onStartOverride == null) {
      _sessionStats = null;
      return;
    }
    final workout = _workout;
    if (workout == null) {
      _sessionStats = null;
      return;
    }
    FitnessProfileProvider? profileProvider;
    try {
      profileProvider =
          Provider.of<FitnessProfileProvider>(context, listen: false);
    } catch (_) {
      profileProvider = null;
    }
    final profile = profileProvider?.profile;
    _sessionStats = WorkoutStatEngine.instance
        .summarize(workout: workout, profile: profile);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_workout != null) return;

    final Object? routeArgs = ModalRoute.of(context)?.settings.arguments;
    final SessionScreenArgs? incoming =
        widget.args ?? (routeArgs is SessionScreenArgs ? routeArgs : null);
    final wp = context.read<WorkoutProvider>();
    final draft = wp.activeDraft;

    final String? workoutId = incoming?.workoutId ?? draft?.workoutId;
    _attachToRoutineId = incoming?.attachToRoutineId ?? draft?.routineId;
    _scheduledDate = incoming?.scheduledDate;

    if (incoming?.focusedBlockIndex != null) {
      _focusedBlockIndex = incoming!.focusedBlockIndex!;
    } else if (workoutId != null && workoutId.isNotEmpty) {
      final savedSession = SessionPersistenceService.getCurrentSession();
      if (savedSession != null && savedSession.workoutId == workoutId) {
        _focusedBlockIndex = savedSession.currentBlockIndex;
        _focusedItemIndex = savedSession.currentExerciseIndex;
      }
    }

    if (workoutId != null) {
      final existing = wp.getWorkoutById(workoutId);
      if (existing != null) {
        _workout = Workout(
          id: existing.id,
          title: existing.title,
          notes: existing.notes,
          blocks: existing.blocks
              .map(
                (b) => WorkoutBlock(
                  type: b.type,
                  title: b.title,
                  items: b.items
                      .map(
                        (it) => WorkoutItem(
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
                        ),
                      )
                      .toList(),
                  note: b.note,
                ),
              )
              .toList(),
        );
      }
    }

    _workout ??=
        Workout(id: '', title: '', notes: null, blocks: <WorkoutBlock>[]);

    _ensureFocusWithinBounds();
    _syncNotesFromCurrentItem();
    _recomputeSessionStats();

    if (!_showContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) setState(() => _showContent = true);
        });
      });
    }

    _checkForResumableSession();
    setState(() {});
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) nav.pop();
  }

  void _openTimeline() {
    final workout = _workout;
    if (workout == null) return;
    final trackerState = WorkoutElapsedTracker.instance.value;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutTimelineScreen(
          workout: workout,
          currentBlockIndex: _focusedBlockIndex,
          currentExerciseIndex: _focusedItemIndex,
          initialElapsed: trackerState.elapsed,
          initialTimerRunning: trackerState.running,
          initialAnchor: trackerState.anchor,
        ),
      ),
    );
  }

  void _setBlocks(List<WorkoutBlock> blocks) {
    setState(() {
      _workout = Workout(
        id: _workout!.id,
        title: _workout!.title,
        notes: _workout!.notes,
        blocks: blocks,
      );
      _ensureFocusWithinBounds();
      final int itemCount = _workout!.blocks.isEmpty
          ? 0
          : _workout!.blocks[_focusedBlockIndex].items.length;
      final int newIndex =
          itemCount == 0 ? 0 : _focusedItemIndex.clamp(0, itemCount - 1);
      if (_pageCtrl.hasClients && newIndex != _focusedItemIndex) {
        _focusedItemIndex = newIndex;
        _pageCtrl.jumpToPage(newIndex);
      }
      _syncNotesFromCurrentItem();
      _recomputeSessionStats();
    });
  }

  double _kgToLb(double kg) => kg * 2.2046226218;

  void _ensureFocusWithinBounds() {
    final Workout? workout = _workout;
    if (workout == null || workout.blocks.isEmpty) {
      _focusedBlockIndex = 0;
      _focusedItemIndex = 0;
      return;
    }
    if (_focusedBlockIndex < 0) {
      _focusedBlockIndex = 0;
    } else if (_focusedBlockIndex >= workout.blocks.length) {
      _focusedBlockIndex = workout.blocks.length - 1;
    }
    final items = workout.blocks[_focusedBlockIndex].items;
    if (items.isEmpty) {
      _focusedItemIndex = 0;
    } else {
      if (_focusedItemIndex < 0) {
        _focusedItemIndex = 0;
      } else if (_focusedItemIndex >= items.length) {
        _focusedItemIndex = items.length - 1;
      }
    }
  }

  WorkoutBlock? get _currentBlock {
    final workout = _workout;
    if (workout == null || workout.blocks.isEmpty) return null;
    final int index = _focusedBlockIndex.clamp(0, workout.blocks.length - 1);
    return workout.blocks[index];
  }

  WorkoutItem? get _currentItem {
    final block = _currentBlock;
    if (block == null || block.items.isEmpty) return null;
    final int index = _focusedItemIndex.clamp(0, block.items.length - 1);
    return block.items[index];
  }

  void _syncNotesFromCurrentItem() {
    final current = _currentItem;
    if (current == null) {
      _notesCtrl.text = '';
      return;
    }
    final text = current.notes ?? '';
    if (_notesCtrl.text != text) {
      _notesCtrl.text = text;
      _notesCtrl.selection =
          TextSelection.collapsed(offset: _notesCtrl.text.length);
    }
    // Notes preview stays available.
  }

  Future<void> _saveNotesFromEditor() async {
    final item = _currentItem;
    if (item == null) return;
    _updateWorkoutItemNote(
      blockIndex: _focusedBlockIndex,
      itemIndex: _focusedItemIndex,
      note: _notesCtrl.text,
    );
  }

  String _formatDurationShort(int seconds) {
    if (seconds <= 0) return '0s';
    if (seconds < 60) return '${seconds}s';
    final int minutes = seconds ~/ 60;
    final int remaining = seconds % 60;
    if (remaining == 0) return '${minutes}m';
    return '${minutes}m ${remaining}s';
  }

  String _formatLoadDisplay(double loadKg) {
    final double display =
        _weightUnit == WeightUnit.kg ? loadKg : _kgToLb(loadKg);
    final double absDisplay = display.abs();
    final bool isWhole = (absDisplay - absDisplay.round()).abs() < 0.01;
    final int precision = isWhole ? 0 : (absDisplay < 10 ? 2 : 1);
    final String value = display.toStringAsFixed(precision);
    return '$value ${_weightUnit.label}';
  }

  void _handleToggleExercisePill(String key) {
    setState(() {
      _expandedExercisePillKey = _expandedExercisePillKey == key ? null : key;
    });
  }

  WorkoutItem? _getWorkoutItem(int blockIndex, int itemIndex) {
    final blocks = _workout?.blocks;
    if (blocks == null ||
        blockIndex < 0 ||
        blockIndex >= blocks.length ||
        itemIndex < 0 ||
        itemIndex >= blocks[blockIndex].items.length) {
      return null;
    }
    return blocks[blockIndex].items[itemIndex];
  }

  void _updateWorkoutItemNote({
    required int blockIndex,
    required int itemIndex,
    String? note,
  }) {
    final item = _getWorkoutItem(blockIndex, itemIndex);
    if (item == null) return;
    final trimmed = note?.trim();
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    final block = blocks[blockIndex];
    final items = List<WorkoutItem>.from(block.items);
    final idx = itemIndex;
    final updated = WorkoutItem(
      exerciseId: item.exerciseId,
      targetSets: item.targetSets,
      targetReps: item.targetReps,
      targetTimeSec: item.targetTimeSec,
      restSec: item.restSec,
      targetLoad: item.targetLoad,
      notes: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      cueChips: List<String>.from(item.cueChips),
      formChecks: List<String>.from(item.formChecks),
      consecutiveMisses: item.consecutiveMisses,
      lastSuggestedLoadKg: item.lastSuggestedLoadKg,
      lastTargetReps: item.lastTargetReps,
      lastLoggedRpe: item.lastLoggedRpe,
      adaptiveSetsEnabled: item.adaptiveSetsEnabled,
      adaptivePercent: item.adaptivePercent,
    );
    items[idx] = updated;
    block.items = items;
    _setBlocks(blocks);
  }

  Future<void> _viewExerciseDetails(int blockIndex, int itemIndex) async {
    final blocks = _workout?.blocks;
    if (blocks == null || blockIndex < 0 || blockIndex >= blocks.length) return;
    final WorkoutBlock block = blocks[blockIndex];
    if (itemIndex < 0 || itemIndex >= block.items.length) return;

    final WorkoutItem item = block.items[itemIndex];
    await Navigator.of(context).push(
      ExerciseDetailsPopupRoute(exerciseId: item.exerciseId),
    );
  }

  Future<void> _openExerciseDetailsById(String exerciseId) async {
    if (exerciseId.isEmpty) return;
    await Navigator.of(context).push(
      ExerciseDetailsPopupRoute(exerciseId: exerciseId),
    );
  }

  Future<void> _handleResetSession() async {
    final workout = _workout;
    if (workout == null || workout.id.isEmpty) return;

    final DateTime effectiveDate = _scheduledDate ?? AppClock.now();
    final String ymd = SessionPersistenceService.dateTimeToYmd(effectiveDate);

    final existing = SessionPersistenceService.getSessionFor(
      workoutId: workout.id,
      scheduledDateYmd: ymd,
    );
    if (existing == null) {
      // No in-progress session for this workout on this day.
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15171E),
        title: const Text(
          'Reset today\'s progress?',
          style: TextStyle(
            color: kPrimaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'This will clear your in-progress session for this workout today. '
          'Logged workouts and history will stay saved.',
          style: TextStyle(
            color: kSecondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await SessionPersistenceService.clearSessionFor(
      workoutId: workout.id,
      scheduledDateYmd: ymd,
    );

    // Reset timers/elapsed state so the UI falls back to zero.
    WorkoutElapsedTracker.instance.reset();

    if (!mounted) return;

    _checkForResumableSession();
  }

  Future<void> _handleResume() async => _handleStart(resume: true);

  Future<void> _handleStart({bool resume = false}) async {
    final override = widget.onStartOverride;
    if (override != null) {
      await override(
        resume: resume,
        focusedBlockIndex: _focusedBlockIndex,
      );
      return;
    }

    if (_exitingToSession) return;

    final block = _currentBlock;
    final item = _currentItem;
    final exercise = (item == null)
        ? null
        : ExerciseLibraryService.instance.getById(item.exerciseId);

    final String safeBlockLabel = block != null
        ? (block.title?.trim().isNotEmpty == true
            ? block.title!.trim()
            : 'Block ${_focusedBlockIndex + 1}')
        : 'No block';
    final String safeBlockTypeLabel = block?.type != null
        ? blockTypeInfo[block!.type]!.label.toUpperCase()
        : '—';
    final List<WorkoutItem> blockExercises = block == null
        ? const <WorkoutItem>[]
        : List<WorkoutItem>.from(block.items);
    if (blockExercises.isEmpty) return;

    int startExerciseIndex = 0;
    if (resume) {
      final session = SessionPersistenceService.getCurrentSession();
      if (session != null &&
          session.workoutId == _workout?.id &&
          session.currentBlockIndex == _focusedBlockIndex &&
          session.currentExerciseIndex >= 0 &&
          session.currentExerciseIndex < blockExercises.length) {
        startExerciseIndex = session.currentExerciseIndex;
      }
    }

    final WorkoutItem startItem = blockExercises[startExerciseIndex];
    final exerciseData =
        ExerciseLibraryService.instance.getById(startItem.exerciseId);
    final String safeExerciseTitle = formatTitleCase(
        exerciseData?.name ?? exercise?.name ?? 'Unknown exercise');
    final String muscles = block != null
        ? formatMuscleSummary(buildBlockMuscleSummary(block))
        : '';
    final String? safeMuscleSummary = muscles.isEmpty ? null : muscles;
    final String? imageUrl = exerciseData?.mediaUrl ?? exercise?.mediaUrl;

    setState(() => _exitingToSession = true);
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    await Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, anim, _) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: EmptyWorkoutSessionScreen(
            blockLabel: safeBlockLabel,
            blockTypeLabel: safeBlockTypeLabel,
            exerciseTitle: safeExerciseTitle,
            muscleSummary: safeMuscleSummary,
            exerciseImageUrl: imageUrl,
            exerciseId: startItem.exerciseId,
            workoutId: _workout?.id,
            routineId: _attachToRoutineId,
            currentBlockIndex: _focusedBlockIndex,
            totalBlocks: _workout?.blocks.length ?? 1,
            targetSets: startItem.targetSets,
            targetReps: startItem.targetReps,
            targetLoadLb: startItem.targetLoad,
            targetWorkSeconds: startItem.targetTimeSec,
            targetRestSeconds: startItem.restSec,
            blockItems: blockExercises,
            exerciseIndex: startExerciseIndex,
            workout: _workout,
            scheduledDate: _scheduledDate, // Pass the scheduled date
          ),
        );
      },
      transitionsBuilder: (context, anim, _, child) => child,
    ));

    if (!mounted) return;
    setState(() => _exitingToSession = false);
    _checkForResumableSession();
  }

  List<MetricTileData> _buildPrescriptionMetrics({
    required WorkoutBlock? block,
    required WorkoutItem? item,
  }) {
    final List<MetricTileData> metrics = <MetricTileData>[];
    final BlockType? blockType = block?.type;

    final bool durationRelevant = blockType == BlockType.circuit ||
        blockType == BlockType.emom ||
        blockType == BlockType.amrap;
    final int? durationSeconds = item?.targetTimeSec;
    final String durationValue = durationSeconds != null
        ? _formatDurationShort(durationSeconds)
        : (durationRelevant ? 'Set in block type' : '—');
    metrics.add(MetricTileData(
        label: 'Duration',
        value: durationValue,
        isPlaceholder: durationSeconds == null && durationRelevant,
        fullWidth: false));

    final double? targetLoad = item?.targetLoad;
    metrics.add(MetricTileData(
        label: 'Load',
        value: targetLoad != null ? _formatLoadDisplay(targetLoad) : '—',
        isPlaceholder: targetLoad == null,
        fullWidth: false));

    final int sets = item?.targetSets ?? 0;
    metrics.add(MetricTileData(
        label: 'Sets',
        value: sets > 0 ? '$sets' : '—',
        isPlaceholder: sets <= 0,
        fullWidth: false));

    final bool repsRelevant =
        blockType != BlockType.emom && blockType != BlockType.amrap;
    final int? reps = item?.targetReps;
    final String repsValue =
        repsRelevant ? (reps != null ? '$reps' : '—') : 'Set in block type';
    metrics.add(MetricTileData(
        label: 'Reps',
        value: repsValue,
        isPlaceholder: repsRelevant && reps == null,
        fullWidth: false));

    final bool restRelevant = blockType == null ||
        blockType == BlockType.set ||
        blockType == BlockType.superset ||
        blockType == BlockType.circuit;
    final int? restSec = item?.restSec;
    final String restValue = restSec != null
        ? _formatDurationShort(restSec)
        : (restRelevant ? '—' : 'Set in block type');
    metrics.add(MetricTileData(
        label: 'Rest',
        value: restValue,
        isPlaceholder: restRelevant && restSec == null,
        fullWidth: true));

    return metrics;
  }

  void _openNotesPopup(String heroTag) {
    Navigator.of(context).push(_NotesPopupRoute<void>(
      barrierLabel: 'Close',
      builder: (ctx) => _NotesEditorPopup(
        heroTag: heroTag,
        controller: _notesCtrl,
        onSave: () async {
          await _saveNotesFromEditor();
          if (!ctx.mounted) return;
          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
        },
        onClear: () async {
          _notesCtrl.clear();
          await _saveNotesFromEditor();
          if (!ctx.mounted) return;
          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
        },
        onClose: () {
          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
        },
      ),
    ));
  }

  // Notes button in the action bar should open notes for the *current* exercise.
  void _openCurrentNotesPopup() {
    final item = _currentItem;
    if (item == null) return;

    final String heroTag =
        'notesHero-${item.exerciseId}-$_focusedBlockIndex-$_focusedItemIndex';
    _openNotesPopup(heroTag);
  }

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    if (workout == null) {
      return const Scaffold(
        backgroundColor: kEditorBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final mq = MediaQuery.of(context);
    final bottomSafe = mq.padding.bottom;

    // When onStartOverride is non-null, this widget is being used
    // as the "session variant" inside the live Session screen.
    final bool sessionVariant = widget.onStartOverride != null;

    final List<WorkoutBlock> allBlocks = workout.blocks;
    WorkoutBlock? block = _currentBlock;
    if (sessionVariant) {
      if (allBlocks.isNotEmpty) {
        final int safeIndex = _focusedBlockIndex.clamp(0, allBlocks.length - 1);
        block = allBlocks[safeIndex];
      } else {
        block = null;
      }
    }

    final String workoutTitle = workout.title?.trim().isNotEmpty == true
        ? workout.title!.trim()
        : 'Workout';
    final String blockName = block != null
        ? (block.title?.trim().isNotEmpty == true
            ? block.title!.trim()
            : 'Block ${_focusedBlockIndex + 1}')
        : 'No block';
    String blockTypeLabel;
    if (block != null && block.type != null) {
      blockTypeLabel = blockTypeInfo[block.type]!.label.toUpperCase();
    } else {
      blockTypeLabel = '—';
    }
    final String headerPrimary = sessionVariant ? workoutTitle : blockName;
    final String headerSecondary = sessionVariant ? '' : blockTypeLabel;
    final double? starRating =
        sessionVariant ? _sessionStats?.starRating : null;

    final int itemCount = block?.items.length ?? 0;
    final int pageCount = sessionVariant
        ? (allBlocks.isEmpty ? 1 : allBlocks.length)
        : (itemCount == 0 ? 1 : itemCount);

    const double actionButtonSize = 52;
    final double actionRowBottomSpacing = bottomSafe + 24;
    final double reservedBottom = actionButtonSize + actionRowBottomSpacing;

    final double viewportH = mq.size.height - mq.padding.top;
    final double topVisualBase = (viewportH * 0.06).clamp(28.0, 80.0);
    final double headerSpacer =
        (topVisualBase - (_showNotesEditor ? 36.0 : 0.0)).clamp(0.0, 9999.0);

    final bool hasExercise = block?.items.isNotEmpty ?? false;

    // Reset/Resume wiring for the session variant.
    final bool resetEnabled = _hasResumableSession && hasExercise;
    final bool showResumeHere = _hasResumableSession && hasExercise;

    return Scaffold(
      backgroundColor: kEditorBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: true,
              bottom: false,
              child: AnimatedOpacity(
                opacity: (_showContent && !_exitingToSession) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        height: headerSpacer,
                      ),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: OverviewBlockHeader(
                            blockLabel: headerPrimary,
                            blockTypeLabel: headerSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: PageView.builder(
                              controller: _pageCtrl,
                              itemCount: pageCount,
                              onPageChanged: (i) {
                                setState(() {
                                  // Reset any expanded exercise when swiping pages.
                                  _expandedExercisePillKey = null;

                                  if (sessionVariant) {
                                    final int maxIndex =
                                        (pageCount <= 0 ? 0 : pageCount - 1);
                                    _focusedBlockIndex = i.clamp(0, maxIndex);
                                    _focusedItemIndex = 0;
                                  } else {
                                    _focusedItemIndex = i;
                                    _syncNotesFromCurrentItem();
                                  }
                                });
                              },
                              physics: pageCount > 1
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                WorkoutBlock? pageBlock;
                                WorkoutItem? pageItem;
                                if (sessionVariant) {
                                  if (index >= 0 && index < allBlocks.length) {
                                    pageBlock = allBlocks[index];
                                    if (pageBlock.items.isNotEmpty) {
                                      pageItem = pageBlock.items.first;
                                    }
                                  }
                                } else {
                                  pageBlock = block;
                                  if (pageBlock != null && itemCount > 0) {
                                    pageItem = pageBlock.items[index];
                                  }
                                }

                                final Exercise? exercise = pageItem == null
                                    ? null
                                    : ExerciseLibraryService.instance
                                        .getById(pageItem.exerciseId);

                                final String exerciseTitle = sessionVariant
                                    ? (pageBlock != null
                                        ? (pageBlock.title?.trim().isNotEmpty ==
                                                true
                                            ? pageBlock.title!.trim()
                                            : 'Block ${index + 1}')
                                        : 'No block')
                                    : (pageItem == null
                                        ? 'No exercise selected'
                                        : formatTitleCase(exercise?.name ??
                                            'Unknown exercise'));

                                final String muscleSummary = pageBlock != null
                                    ? formatMuscleSummary(
                                        buildBlockMuscleSummary(pageBlock))
                                    : '';
                                final bool showMuscles =
                                    muscleSummary.isNotEmpty;

                                final Map<String, double>? coverage =
                                    sessionVariant && pageBlock != null
                                        ? computeBlockCoverage(pageBlock)
                                        : null;

                                final List<_ExercisePillData> exercisePills =
                                    <_ExercisePillData>[];
                                if (sessionVariant && pageBlock != null) {
                                  for (int i = 0;
                                      i < pageBlock.items.length;
                                      i++) {
                                    final item = pageBlock.items[i];
                                    final exerciseData = ExerciseLibraryService
                                        .instance
                                        .getById(item.exerciseId);
                                    final String title = formatTitleCase(
                                        exerciseData?.name ?? 'Exercise');

                                    final String key =
                                        'block-$index-item-$i-${item.exerciseId}';

                                    final String? loadLabel =
                                        item.targetLoad != null
                                            ? _formatLoadDisplay(
                                                item.targetLoad!,
                                              )
                                            : null;

                                    final String? setsLabel =
                                        (item.targetSets > 0)
                                            ? '${item.targetSets}'
                                            : null;

                                    final String? repsLabel =
                                        (item.targetReps != null &&
                                                item.targetReps! > 0)
                                            ? '${item.targetReps}'
                                            : null;

                                    exercisePills.add(_ExercisePillData(
                                      exerciseId: item.exerciseId,
                                      title: title,
                                      key: key,
                                      loadLabel: loadLabel,
                                      setsLabel: setsLabel,
                                      repsLabel: repsLabel,
                                    ));
                                  }
                                }

                                final List<MetricTileData> metrics =
                                    _buildPrescriptionMetrics(
                                  block: pageBlock,
                                  item: pageItem,
                                );

                                final String heroTag =
                                    'notesHero-${pageItem?.exerciseId ?? 'none'}-$_focusedBlockIndex-$index';

                                return Align(
                                  alignment: Alignment.topCenter,
                                  child: _ExercisePage(
                                    exerciseTitle: exerciseTitle,
                                    muscleSummary:
                                        showMuscles ? muscleSummary : null,
                                    exerciseImageUrl: sessionVariant
                                        ? null
                                        : exercise?.mediaUrl,
                                    radarCoverage: coverage,
                                    starRating:
                                        sessionVariant ? starRating : null,
                                    exercisePills: exercisePills,
                                    expandedPillKey: _expandedExercisePillKey,
                                    onTogglePill: _handleToggleExercisePill,
                                    onExerciseInfoTap: _openExerciseDetailsById,
                                    metrics: metrics,
                                    showPrescription: !sessionVariant,
                                    hasExercise: pageItem != null,
                                    showNotesPreview: !sessionVariant &&
                                        _showNotesEditor &&
                                        pageItem != null,
                                    notesText: _notesCtrl.text,
                                    notesHeroTag: heroTag,
                                    onOpenNotesPopup: () =>
                                        _openNotesPopup(heroTag),
                                    onClearNotes: () async {
                                      _notesCtrl.clear();
                                      await _saveNotesFromEditor();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: reservedBottom),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Timeline
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: AnimatedOpacity(
              opacity: (_showContent && !_exitingToSession) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: IconButton(
                tooltip: 'Workout timeline',
                visualDensity: VisualDensity.compact,
                onPressed: _openTimeline,
                icon: const Icon(Icons.timeline_rounded,
                    size: 26, color: kPrimaryText),
              ),
            ),
          ),

          // Close
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: AnimatedOpacity(
              opacity: (_showContent && !_exitingToSession) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: IconButton(
                tooltip: 'Close preview',
                visualDensity: VisualDensity.compact,
                onPressed: _close,
                icon: const Icon(Icons.close_rounded,
                    size: 26, color: kPrimaryText),
              ),
            ),
          ),

          // Dots
          Positioned(
            left: 0,
            right: 0,
            bottom: actionRowBottomSpacing + actionButtonSize + 12,
            child: AnimatedOpacity(
              opacity: (_showContent && !_exitingToSession) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Center(
                child: PageDotsIndicator(
                  count: pageCount,
                  index: () {
                    final int rawIndex =
                        sessionVariant ? _focusedBlockIndex : _focusedItemIndex;
                    if (rawIndex < 0) return 0;
                    if (rawIndex >= pageCount) {
                      return pageCount <= 0 ? 0 : pageCount - 1;
                    }
                    return rawIndex;
                  }(),
                ),
              ),
            ),
          ),

          // Action bar
          Positioned(
            left: 0,
            right: 0,
            bottom: actionRowBottomSpacing,
            child: Hero(
              tag: _kActionBarHeroTag,
              flightShuttleBuilder: (context, anim, dir, fromCtx, toCtx) {
                return toCtx.widget;
              },
              child: OverviewActionBarRow(
                // When used from SessionScreen (sessionVariant == true),
                // the leading pill is Reset. Otherwise it's Notes.
                mode: sessionVariant
                    ? OverviewActionBarMode.reset
                    : OverviewActionBarMode.notes,

                // Reset wiring (session variant only).
                resetEnabled: sessionVariant ? resetEnabled : false,
                onResetTap:
                    sessionVariant && resetEnabled ? _handleResetSession : null,

                // Notes wiring (overview variant only).
                notesEnabled: !sessionVariant && hasExercise,
                onNotesTap: !sessionVariant && hasExercise
                    ? _openCurrentNotesPopup
                    : null,

                showResumeButton: showResumeHere,
                onResumeTap: showResumeHere ? _handleResume : null,
                onPlayTap: hasExercise ? _handleStart : null,
                onInfoTap: hasExercise
                    ? () => _viewExerciseDetails(
                        _focusedBlockIndex, _focusedItemIndex)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paged content per exercise
class _ExercisePage extends StatelessWidget {
  const _ExercisePage({
    required this.exerciseTitle,
    required this.metrics,
    this.muscleSummary,
    this.exerciseImageUrl,
    this.radarCoverage,
    this.starRating,
    required this.exercisePills,
    required this.expandedPillKey,
    required this.onTogglePill,
    required this.onExerciseInfoTap,
    required this.showPrescription,
    required this.hasExercise,
    // notes
    required this.showNotesPreview,
    required this.notesText,
    required this.notesHeroTag,
    required this.onOpenNotesPopup,
    required this.onClearNotes,
  });

  final String exerciseTitle;
  final String? muscleSummary;
  final String? exerciseImageUrl;
  final Map<String, double>? radarCoverage;
  final List<MetricTileData> metrics;
  final double? starRating;
  final List<_ExercisePillData> exercisePills;
  final String? expandedPillKey;
  final void Function(String pillKey) onTogglePill;
  final void Function(String exerciseId) onExerciseInfoTap;
  final bool showPrescription;
  final bool hasExercise;

  final bool showNotesPreview;
  final String notesText;
  final String notesHeroTag;
  final VoidCallback onOpenNotesPopup;
  final Future<void> Function() onClearNotes;

  @override
  Widget build(BuildContext context) {
    final bool showMuscles = muscleSummary != null && muscleSummary!.isNotEmpty;
    final bool showRadar = radarCoverage != null;
    final bool showStar = starRating != null;
    final bool showPills = exercisePills.isNotEmpty;
    final bool displayPrescription = showPrescription && metrics.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exerciseTitle,
                  style: const TextStyle(
                    color: kPrimaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showMuscles) ...[
                  const SizedBox(height: 4),
                  Text(
                    muscleSummary!,
                    style: TextStyle(
                      color: kSecondaryText.withValues(alpha: 0.85),
                      fontSize: 13.5,
                      height: 1.24,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 24),

                if (showRadar)
                  SizedBox(
                    height: 220,
                    child: ExerciseRadarChart(
                      coverage: radarCoverage!,
                      accentColor: const Color(0xFF21D07A),
                    ),
                  )
                else
                  OverviewExerciseThumbnail(url: exerciseImageUrl),

                if (showStar) ...[
                  const SizedBox(height: 18),
                  DifficultyRatingSection(rating: starRating),
                ],

                if (showPills) ...[
                  const SizedBox(height: 18),
                  _ExercisePillStrip(
                    pills: exercisePills,
                    expandedKey: expandedPillKey,
                    onToggleExpanded: onTogglePill,
                    onInfoTap: onExerciseInfoTap,
                  ),
                ],

                if (displayPrescription) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Prescription',
                    style: TextStyle(
                      color: kSecondaryText.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  PrescriptionMetricsGrid(metrics: metrics),
                ] else ...[
                  const SizedBox(height: 28),
                ],

                // Notes preview: two lines + ellipsis + Hero to popup
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: (hasExercise && showNotesPreview)
                      ? Padding(
                          key: const ValueKey('notes-preview'),
                          padding: const EdgeInsets.only(top: 10),
                          child: _NotesPreviewCard(
                            heroTag: notesHeroTag,
                            text: notesText,
                            onTap: onOpenNotesPopup,
                            onClear: onClearNotes,
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('notes-hidden')),
                ),

                if (!hasExercise)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: EmptyBlockState(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExercisePillData {
  const _ExercisePillData({
    required this.exerciseId,
    required this.title,
    required this.key,
    this.loadLabel,
    this.setsLabel,
    this.repsLabel,
  });

  final String exerciseId;
  final String title;
  final String key;
  final String? loadLabel;
  final String? setsLabel;
  final String? repsLabel;

  bool get hasPrescription =>
      (loadLabel != null && loadLabel!.isNotEmpty) ||
      (setsLabel != null && setsLabel!.isNotEmpty) ||
      (repsLabel != null && repsLabel!.isNotEmpty);
}

/// Scrollable stack of full-width exercise cards with dropdown details.
/// Cards match the workout box visual (rounded rect, border, dark fill).
class _ExercisePillStrip extends StatelessWidget {
  const _ExercisePillStrip({
    required this.pills,
    required this.expandedKey,
    required this.onToggleExpanded,
    required this.onInfoTap,
  });

  final List<_ExercisePillData> pills;
  final String? expandedKey;
  final void Function(String key) onToggleExpanded;
  final void Function(String exerciseId) onInfoTap;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();

    const int noScrollThreshold = 3;
    final bool needsScroll = pills.length > noScrollThreshold;

    final List<Widget> children = [
      for (int i = 0; i < pills.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        _ExercisePill(
          data: pills[i],
          isExpanded: expandedKey == pills[i].key,
          onToggleExpanded: () => onToggleExpanded(pills[i].key),
          onInfoTap: () => onInfoTap(pills[i].exerciseId),
        ),
      ],
    ];

    if (!needsScroll) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.7, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            children: children,
          ),
        ),
      ),
    );
  }
}

class _ExercisePill extends StatelessWidget {
  const _ExercisePill({
    required this.data,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onInfoTap,
  });

  final _ExercisePillData data;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onInfoTap;

  static const Color _cardBase = Color(0xFF161F2A);
  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = Colors.white.withValues(alpha: 0.14);
    final Color detailBg = const Color(0xFF0F141C).withValues(alpha: 0.96);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: BorderSide(
              color: borderColor,
              width: 1.1,
            ),
          ),
          color: _cardBase.withValues(alpha: 0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(_radius),
              onTap: onToggleExpanded,
              splashColor: Colors.white.withValues(alpha: 0.06),
              highlightColor: Colors.white.withValues(alpha: 0.03),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kPrimaryText,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onInfoTap,
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      splashRadius: 18,
                      tooltip: 'Exercise details',
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      turns: isExpanded ? 0.5 : 0.0,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded && data.hasPrescription)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: detailBg,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(_radius),
                    bottomRight: Radius.circular(_radius),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _PrescriptionColumn(
                        label: 'Load',
                        value: data.loadLabel ?? '—',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrescriptionColumn(
                        label: 'Sets',
                        value: data.setsLabel ?? '—',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrescriptionColumn(
                        label: 'Reps',
                        value: data.repsLabel ?? '—',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionColumn extends StatelessWidget {
  const _PrescriptionColumn({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: kSecondaryText.withValues(alpha: 0.72),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: kPrimaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Read-only two-line preview with ellipsis. Taps Hero into the editor popup.
class _NotesPreviewCard extends StatelessWidget {
  const _NotesPreviewCard({
    required this.heroTag,
    required this.text,
    required this.onTap,
    required this.onClear,
  });

  final String heroTag;
  final String text;
  final VoidCallback onTap;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final String display = text.isEmpty ? 'Add a note…' : text;

    return Hero(
      tag: heroTag,
      flightShuttleBuilder: (ctx, anim, dir, from, to) => to.widget,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF15171E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Writing notes',
                  style: TextStyle(
                    color: kPrimaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D2028),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  constraints: const BoxConstraints(minHeight: 72),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text.isEmpty
                          ? kSecondaryText.withValues(alpha: 0.7)
                          : kPrimaryText,
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await onClear();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: kSecondaryText.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Row(
                      children: [
                        Icon(Icons.open_in_full_rounded,
                            color: kPrimaryText, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Expand',
                          style: TextStyle(
                            color: kPrimaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full notes editor popup — scrollable, keyboard-safe, no overflow.
class _NotesEditorPopup extends StatelessWidget {
  const _NotesEditorPopup({
    required this.heroTag,
    required this.controller,
    required this.onSave,
    required this.onClear,
    required this.onClose,
  });

  final String heroTag;
  final TextEditingController controller;
  final Future<void> Function() onSave;
  final Future<void> Function() onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.82; // keep some breathing room
    final kb = mq.viewInsets.bottom; // keyboard

    return SafeArea(
      child: Center(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: kb),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Hero(
              tag: heroTag,
              child: Material(
                color: const Color(0xFF15171E),
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Writing notes',
                              style: TextStyle(
                                color: kPrimaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: onClose,
                              icon: const Icon(Icons.close_rounded,
                                  color: kPrimaryText),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D2028),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x33FFFFFF)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            keyboardType: TextInputType.multiline,
                            minLines: 6, // fits comfortably
                            maxLines: 12, // allow growth before scrolling page
                            style: const TextStyle(
                              color: kPrimaryText,
                              fontSize: 16,
                              height: 1.28,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Type your note…',
                              hintStyle: TextStyle(color: Color(0x99FFFFFF)),
                              isCollapsed: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: onClear,
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  color: kSecondaryText.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: onSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade+scale route for popup.
class _NotesPopupRoute<T> extends PageRoute<T> {
  _NotesPopupRoute({required this.builder, this.barrierLabel});
  final WidgetBuilder builder;

  @override
  final String? barrierLabel;

  @override
  Color get barrierColor => Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }

  @override
  bool get opaque => false;
}
