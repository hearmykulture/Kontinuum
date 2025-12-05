import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/session_state.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/utils/text_format.dart';

import 'add_exercise_popup_route.dart';
import 'workout_timeline_screen.dart';
import 'workout_overview_screen.dart';
import 'session_screen_args.dart';
import 'session_widgets/timer_widgets.dart';
import 'session_widgets/action_bar_widgets.dart';
import 'session_widgets/log_set_dialog.dart';
import 'session_widgets/session_components.dart';
import 'session_widgets/workout_complete_screen.dart' as wc; // alias import
import 'session_widgets/workout_finished_screen.dart';
import 'package:kontinuum/core/time/app_clock.dart';

const String _kActionBarHeroTag = 'workoutActionBarHero';
const String kLogSetHeroTag = 'logSetHeroBubble';

/// Helper: format a DateTime as YYYY-MM-DD (local calendar day).
String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class EmptyWorkoutSessionScreen extends StatefulWidget {
  const EmptyWorkoutSessionScreen({
    super.key,
    required this.blockLabel,
    required this.blockTypeLabel,
    required this.exerciseTitle,
    this.muscleSummary,
    this.exerciseImageUrl,
    this.exerciseId,
    this.workoutId,
    this.routineId,
    this.currentBlockIndex = 0,
    this.totalBlocks = 1,
    this.targetSets,
    this.targetReps,
    this.targetLoadLb,
    this.targetWorkSeconds,
    this.targetRestSeconds,
    required List<WorkoutItem> blockItems,
    this.exerciseIndex = 0,
    this.workout,
    this.scheduledDate,
  }) : blockItems = blockItems;

  final String blockLabel;
  final String blockTypeLabel;
  final String exerciseTitle;
  final String? muscleSummary;
  final String? exerciseImageUrl;
  final String? exerciseId;
  final String? workoutId;
  final String? routineId;
  final int currentBlockIndex;
  final int totalBlocks;
  final int? targetSets;
  final int? targetReps;
  final double? targetLoadLb;
  final int? targetWorkSeconds;
  final int? targetRestSeconds;
  final List<WorkoutItem> blockItems;
  final int exerciseIndex;
  final Workout? workout;

  /// The calendar date this workout session counts toward.
  /// If null, we treat it as "today" (AppClock.now()).
  final DateTime? scheduledDate;

  @override
  State<EmptyWorkoutSessionScreen> createState() =>
      _EmptyWorkoutSessionScreenState();
}

class _EmptyWorkoutSessionScreenState extends State<EmptyWorkoutSessionScreen>
    with WidgetsBindingObserver {
  final GlobalKey<SetTimerCardState> _timerKey = GlobalKey<SetTimerCardState>();
  final GlobalKey<_TopMirrorState> _topKey = GlobalKey<_TopMirrorState>();

  bool _isActivelyCounting = false;

  int _savedCount = 0;
  bool _finalRestStarted = false;
  bool _finalRestDone = false;

  final TextEditingController _notesCtrl = TextEditingController();
  final FocusNode _notesFocus = FocusNode();
  bool _showNotesEditor = false;

  Timer? _autosaveTimer;
  WorkoutSessionState? _sessionToRestore;
  bool _hasRestoredSession = false;

  /// Normalized calendar day this session belongs to (YYYY-MM-DD, local).
  DateTime get _effectiveScheduledDate {
    final base = widget.scheduledDate ?? AppClock.now();
    return DateTime(base.year, base.month, base.day);
  }

  String get _effectiveScheduledYmd => _ymd(_effectiveScheduledDate);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForResumableSession();

    // Light autosave safety net (every 20s while screen is visible)
    _autosaveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _saveSessionState();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save aggressively on any path where the OS might background/kill us.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveSessionState();
    }
  }

  /// Check if there is a resumable session snapshot for this workout/date,
  /// and if so, restore it into this exercise *without* purging it just
  /// because finalRestDone == true. The decision to clear "finished" sessions
  /// now lives in SessionScreen._updateResumeAvailability, which also checks
  /// for an actual completion log.
  void _checkForResumableSession() {
    final workoutId = widget.workoutId;
    if (workoutId == null || workoutId.isEmpty) return;

    final String targetYmd = _effectiveScheduledYmd;

    final session = SessionPersistenceService.getSessionFor(
      workoutId: workoutId,
      scheduledDateYmd: targetYmd,
    );

    debugPrint(
      '[EmptyWorkoutSession] _checkForResumableSession → '
      'widgetWorkoutId=$workoutId, '
      'widgetScheduledDate=${widget.scheduledDate}, '
      'sessionWorkoutId=${session?.workoutId}, '
      'sessionScheduledDate=${session?.scheduledDateIso}, '
      'sessionSavedAt=${session?.savedAtIso}, '
      'block=${session?.currentBlockIndex}, '
      'exercise=${session?.currentExerciseIndex}, '
      'finalRestDone=${session?.finalRestDone}, '
      'completedSets=${session?.completedSetsList.length}',
    );

    if (session == null) {
      debugPrint(
        '[EmptyWorkoutSession] No resumable session for this workout/date '
        '→ starting fresh',
      );
      return;
    }

    final int targetSets = widget.targetSets ?? 3;
    final bool isComplete = session.finalRestDone &&
        session.completedSetsList.length >= targetSets;

    if (isComplete) {
      final bool hasLogForDay =
          SessionPersistenceService.hasLogForWorkoutOnDate(
        workoutId: workoutId,
        scheduledDateYmd: targetYmd,
      );

      if (hasLogForDay) {
        debugPrint(
          '[EmptyWorkoutSession] Session is already complete '
          '(finalRestDone=${session.finalRestDone}, '
          'sets=${session.completedSetsList.length}/$targetSets, log exists) '
          '→ clearing stale session and starting fresh',
        );
        SessionPersistenceService.clearSessionFor(
          workoutId: workoutId,
          scheduledDateYmd: targetYmd,
        );
        return;
      }

      debugPrint(
        '[EmptyWorkoutSession] Session is already complete '
        '(finalRestDone=${session.finalRestDone}, '
        'sets=${session.completedSetsList.length}/$targetSets) → '
        'keeping snapshot for resume',
      );
    }

    // Only restore if the snapshot is actually for THIS block/exercise.
    if (session.currentBlockIndex != widget.currentBlockIndex ||
        session.currentExerciseIndex != widget.exerciseIndex) {
      debugPrint(
        '[EmptyWorkoutSession] Session exists for this day but at a '
        'different block/exercise (sessionBlock=${session.currentBlockIndex}, '
        'sessionExercise=${session.currentExerciseIndex}) → not restoring '
        'into this screen',
      );
      return;
    }

    // How many sets were saved for this exercise in this snapshot?
    final int savedForExercise = session.completedSetsList.length;

    debugPrint(
      '[EmptyWorkoutSession] Session is valid and resumable → '
      'will restore $savedForExercise sets '
      '(finalRestDone=${session.finalRestDone})',
    );

    // Store session to restore, and seed local state before build.
    _sessionToRestore = session;
    _savedCount = savedForExercise;
    _finalRestStarted = session.finalRestStarted;
    _finalRestDone = session.finalRestDone;
    _notesCtrl.text = session.currentExerciseNotes ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSessionState(session);
    });
  }

  void _saveSessionState() {
    final workoutId = widget.workoutId;
    if (workoutId == null || workoutId.isEmpty) return;

    final timerState = _timerKey.currentState;
    if (timerState == null) return;

    // Get completed sets from TopMirror widget
    final topMirror = _topKey.currentState;
    final stats = topMirror?.collectStats() ?? [];

    debugPrint(
      '[EmptyWorkoutSession] _saveSessionState → '
      'workoutId=$workoutId, '
      'block=${widget.currentBlockIndex}, '
      'exercise=${widget.exerciseIndex}, '
      'sets=${stats.length}, '
      'elapsed=${timerState.elapsed.inSeconds}s, '
      'restRemaining=${timerState.restRemaining}, '
      'finalRestStarted=$_finalRestStarted, '
      'finalRestDone=$_finalRestDone',
    );

    // Convert stats to SavedSetData (per-exercise list)
    final completedSetsList = stats
        .map((s) => SavedSetData(
              index: s.index,
              loadLb: s.loadLb,
              reps: s.reps,
              timestampIso: s.timestamp.toIso8601String(),
              elapsedSeconds: s.elapsed.inSeconds,
            ))
        .toList();

    // Always bind the session to a concrete calendar day (YYYY-MM-DD).
    final String scheduledDateIso = _effectiveScheduledYmd;

    // Merge with any existing snapshot for this workout/day so that
    // completedSets stays cumulative across exercises.
    final existing = SessionPersistenceService.getSessionFor(
      workoutId: workoutId,
      scheduledDateYmd: scheduledDateIso,
    );

    final Map<String, int> mergedCompletedSets =
        Map<String, int>.from(existing?.completedSets ?? const <String, int>{});

    final String exerciseKey =
        '${widget.currentBlockIndex}:${widget.exerciseIndex}';
    mergedCompletedSets[exerciseKey] = _savedCount;

    final int totalCompletedSets =
        mergedCompletedSets.values.fold(0, (sum, v) => sum + v);

    debugPrint(
      '[EmptyWorkoutSession] _saveSessionState → '
      'scheduledDateIso=$scheduledDateIso, '
      'workoutId=$workoutId, '
      'finalRestDone=$_finalRestDone, '
      'savedCountForThisExercise=$_savedCount, '
      'totalCompletedSets=$totalCompletedSets',
    );

    final state = WorkoutSessionState(
      workoutId: workoutId,
      routineId: widget.routineId,
      currentBlockIndex: widget.currentBlockIndex,
      currentExerciseIndex: widget.exerciseIndex,
      elapsedSeconds: timerState.elapsed.inSeconds,
      wasRunning: timerState.running,
      timerMode: timerState.timerMode,
      restTotalSeconds: timerState.restTotal,
      restRemainingSeconds: timerState.restRemaining,
      restWasPaused: timerState.restPaused,
      // 🔑 cumulative across the whole workout
      completedSets: mergedCompletedSets,
      savedAtIso: AppClock.now().toIso8601String(),
      currentExerciseNotes: _notesCtrl.text.trim(),
      // 🔑 per-exercise only
      completedSetsList: completedSetsList,
      finalRestStarted: _finalRestStarted,
      finalRestDone: _finalRestDone,
      scheduledDateIso: scheduledDateIso,
    );

    SessionPersistenceService.saveSession(state);
  }

  void _restoreSessionState(WorkoutSessionState state) {
    if (!mounted) return;

    debugPrint(
      '[EmptyWorkoutSession] _restoreSessionState → '
      'elapsed=${state.elapsedSeconds}s, '
      'restRemaining=${state.restRemainingSeconds}, '
      'finalRestStarted=${state.finalRestStarted}, '
      'finalRestDone=${state.finalRestDone}',
    );

    final timerState = _timerKey.currentState;
    if (timerState == null) return;

    // Restore timer state (always paused when resuming)
    timerState.restoreState(
      elapsedSeconds: state.elapsedSeconds,
      wasRunning: false, // Always start paused when resuming
      mode: state.timerMode,
      restTotalSec: state.restTotalSeconds,
      restRemainingSec: state.restRemainingSeconds,
      restWasPaused: true, // Rest timer also paused
    );

    setState(() {
      _finalRestStarted = state.finalRestStarted;
      _finalRestDone = state.finalRestDone;
      _hasRestoredSession = true;
    });

    // TopMirror gets its initialSavedSets from _sessionToRestore
  }

  void _close() {
    _saveSessionState();
    FocusScope.of(context).unfocus();
    final nav = Navigator.maybeOf(context);
    // Pop back to the WorkoutOverviewScreen for the current block
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  void _openTimeline() {
    debugPrint(
      '[EmptyWorkoutSession] _openTimeline → '
      'block=${widget.currentBlockIndex}, '
      'exercise=${widget.exerciseIndex}, '
      'savedCount=$_savedCount',
    );

    _saveSessionState();
    Workout? workout = widget.workout;
    workout ??= _resolveWorkoutFromProvider();
    if (workout == null) return;
    final Duration elapsed = _timerKey.currentState?.elapsed ?? Duration.zero;
    final bool isRunning = _timerKey.currentState?.isStopwatchRunning ?? false;
    final DateTime anchor = AppClock.now().subtract(elapsed);
    final int setIndex = widget.targetSets != null && widget.targetSets! > 0
        ? _savedCount.clamp(0, widget.targetSets! - 1)
        : _savedCount;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutTimelineScreen(
          workout: workout,
          currentBlockIndex: widget.currentBlockIndex,
          currentExerciseIndex: widget.exerciseIndex,
          currentSetIndex: setIndex,
          initialElapsed: elapsed,
          initialTimerRunning: isRunning,
          initialAnchor: anchor,
        ),
      ),
    );
  }

  void _toggleStartPause() {
    _timerKey.currentState?.toggleStartPause();
    _saveSessionState();
  }

  void _rewind15() {
    _timerKey.currentState?.rewind15();
    _saveSessionState();
  }

  void _forward15() {
    _timerKey.currentState?.forward15();
    _saveSessionState();
  }

  /// Called when the user taps the big "Complete" button in the action bar.
  /// Now responsible for marking the workout as finished at the very end
  /// (last exercise of last block) *before* we show the summary screen.
  Future<void> _handleComplete() async {
    // Save the latest session state before processing completion.
    _saveSessionState();

    final stats = _topKey.currentState?.collectStats() ?? <wc.WorkoutSetStat>[];

    final bool hasMoreExercises =
        widget.exerciseIndex + 1 < widget.blockItems.length;
    final bool hasMoreBlocks =
        widget.currentBlockIndex < widget.totalBlocks - 1;

    debugPrint(
      '[EmptyWorkoutSession] _handleComplete tap → '
      'block=${widget.currentBlockIndex + 1}/${widget.totalBlocks}, '
      'exercise=${widget.exerciseIndex + 1}/${widget.blockItems.length}, '
      'savedCount=$_savedCount, '
      'finalRestStarted=$_finalRestStarted, '
      'finalRestDone=$_finalRestDone, '
      'hasMoreExercises=$hasMoreExercises, '
      'hasMoreBlocks=$hasMoreBlocks',
    );

    VoidCallback? onNextExercise;
    VoidCallback? onNextBlock;
    VoidCallback? onFinishWorkout;
    String? nextExerciseLabel;

    if (hasMoreExercises) {
      // More exercises remaining in this block → prime session for next exercise.
      debugPrint(
        '[EmptyWorkoutSession] _handleComplete → advancing to next exercise '
        '(nextIndex=${widget.exerciseIndex + 1})',
      );
      _primeSessionState(
        blockIndex: widget.currentBlockIndex,
        exerciseIndex: widget.exerciseIndex + 1,
      );
      nextExerciseLabel =
          'Next Exercise (${widget.exerciseIndex + 2}/${widget.blockItems.length})';
      onNextExercise = () => _goToExercise(widget.exerciseIndex + 1);
    } else if (hasMoreBlocks) {
      // No more exercises in this block, but more blocks remain → prime next block.
      debugPrint(
        '[EmptyWorkoutSession] _handleComplete → advancing to next block '
        '(nextBlockIndex=${widget.currentBlockIndex + 1})',
      );
      _primeSessionState(
        blockIndex: widget.currentBlockIndex + 1,
        exerciseIndex: 0,
      );
      onNextBlock = _goToNextBlockOverview;
    } else {
      // 🎯 Last exercise of the last block → mark workout complete *now*.
      final String scheduledYmd = _effectiveScheduledYmd;
      debugPrint(
        '[EmptyWorkoutSession] _handleComplete → last exercise of last block '
        '(workoutId=${widget.workoutId}, routineId=${widget.routineId}, '
        'scheduledYmd=$scheduledYmd)',
      );
      final String? workoutId = widget.workoutId;
      if (workoutId != null && workoutId.isNotEmpty) {
        try {
          final wp = context.read<WorkoutProvider>();
          debugPrint(
            '[EmptyWorkoutSession] Calling WorkoutProvider.finishSession()',
          );
          // finishSession() already uses the persisted scheduledDateIso
          // from SessionPersistenceService to resolve the effective log day.
          await wp.finishSession(); // writes the workout log
          debugPrint(
            '[EmptyWorkoutSession] WorkoutProvider.finishSession() completed',
          );
        } catch (e, st) {
          debugPrint(
            '[EmptyWorkoutSession] WorkoutProvider.finishSession() ERROR: $e',
          );
          debugPrint('$st');
        }
      }

      // Summary's primary action just does navigation/overlay now.
      onFinishWorkout = _goToWorkoutFinished;
    }

    if (!mounted) return;

    debugPrint(
      '[EmptyWorkoutSession] Pushing WorkoutCompleteScreen '
      '(stats=${stats.length}, '
      'onNextExercise=${onNextExercise != null}, '
      'onNextBlock=${onNextBlock != null}, '
      'onFinishWorkout=${onFinishWorkout != null})',
    );

    // Navigate to the per-exercise summary screen (unchanged UI-wise).
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => wc.WorkoutCompleteScreen(
          stats: stats,
          currentBlockIndex: widget.currentBlockIndex,
          totalBlocks: widget.totalBlocks,
          onNextBlock: onNextBlock,
          onNextExercise: onNextExercise,
          nextExerciseLabel: nextExerciseLabel,
          onFinishWorkout: onFinishWorkout,
          workoutId: widget.workoutId,
          routineId: widget.routineId,
        ),
      ),
    );
  }

  void _primeSessionState({
    required int blockIndex,
    required int exerciseIndex,
  }) {
    final workoutId = widget.workoutId;
    if (workoutId == null || workoutId.isEmpty) return;

    // Always bind the next exercise's session to the same calendar day.
    final String scheduledDateIso = _effectiveScheduledYmd;

    // Carry over cumulative completed set counts from the previous exercise.
    final existing = SessionPersistenceService.getSessionFor(
      workoutId: workoutId,
      scheduledDateYmd: scheduledDateIso,
    );

    final Map<String, int> cumulativeCompletedSets =
        Map<String, int>.from(existing?.completedSets ?? const <String, int>{});

    debugPrint(
      '[EmptyWorkoutSession] _primeSessionState → '
      'workoutId=$workoutId, blockIndex=$blockIndex, '
      'exerciseIndex=$exerciseIndex, '
      'scheduledDateIso=$scheduledDateIso, '
      'carriedCompletedSets=${cumulativeCompletedSets.toString()}',
    );

    final state = WorkoutSessionState(
      workoutId: workoutId,
      routineId: widget.routineId,
      currentBlockIndex: blockIndex,
      currentExerciseIndex: exerciseIndex,
      elapsedSeconds: 0,
      wasRunning: false,
      timerMode: 'stopwatch',
      restTotalSeconds: 0,
      restRemainingSeconds: 0,
      restWasPaused: true,
      // 🔑 keep cumulative sets across exercises
      completedSets: cumulativeCompletedSets,
      savedAtIso: AppClock.now().toIso8601String(),
      currentExerciseNotes: null,
      // 🔑 new exercise → per-ex list starts empty
      completedSetsList: const <SavedSetData>[],
      finalRestStarted: false,
      finalRestDone: false,
      scheduledDateIso: scheduledDateIso,
    );
    SessionPersistenceService.saveSession(state);
  }

  void _goToExercise(int nextIndex) {
    final List<WorkoutItem> blockItems = widget.blockItems;
    if (nextIndex < 0 || nextIndex >= blockItems.length) return;

    final nav = Navigator.of(context);
    final String blockLabel = widget.blockLabel;
    final String blockTypeLabel = widget.blockTypeLabel;
    final String? muscleSummary = widget.muscleSummary;
    final String? workoutId = widget.workoutId;
    final String? routineId = widget.routineId;
    final int currentBlockIndex = widget.currentBlockIndex;
    final int totalBlocks = widget.totalBlocks;

    // Pop summary + current session
    nav.pop();
    nav.pop();

    _pushExerciseScreen(
      nav,
      blockItems: blockItems,
      exerciseIndex: nextIndex,
      blockLabel: blockLabel,
      blockTypeLabel: blockTypeLabel,
      muscleSummary: muscleSummary,
      workoutId: workoutId,
      routineId: routineId,
      currentBlockIndex: currentBlockIndex,
      totalBlocks: totalBlocks,
    );
  }

  void _goToNextBlockOverview() {
    final nav = Navigator.of(context);
    nav.pop(); // summary
    nav.pop(); // session
    nav.pop(); // block overview
    nav.push(
      MaterialPageRoute<void>(
        builder: (context) => WorkoutOverviewScreen(
          args: SessionScreenArgs(
            workoutId: widget.workoutId,
            attachToRoutineId: widget.routineId,
            focusedBlockIndex: widget.currentBlockIndex + 1,
            // Preserve the same calendar date across the whole session.
            scheduledDate: widget.scheduledDate,
          ),
        ),
      ),
    );
  }

  Future<void> _goToWorkoutFinished() async {
    if (!mounted) return;

    final workoutId = widget.workoutId;
    final currentSession = (workoutId != null && workoutId.isNotEmpty)
        ? SessionPersistenceService.getSessionFor(
            workoutId: workoutId,
            scheduledDateYmd: _effectiveScheduledYmd,
          )
        : null;

    debugPrint(
      '[EmptyWorkoutSession] _goToWorkoutFinished → '
      'workoutId=$workoutId, routineId=${widget.routineId}, '
      'currentSession=$currentSession',
    );

    // 🔓 Clear any leftover session so no "RESUME" hangs around
    // after a fully completed workout across days.
    if (workoutId != null && workoutId.isNotEmpty) {
      await SessionPersistenceService.clearSessionFor(
        workoutId: workoutId,
        scheduledDateYmd: _effectiveScheduledYmd,
      );
    } else {
      await SessionPersistenceService.clearSession();
    }

    final nav = Navigator.of(context);

    // Pop all workout-related screens back to the root
    nav.popUntil((route) => route.isFirst);

    // Use the effective scheduled day so the dashboard opens on that date.
    final DateTime targetDay = _effectiveScheduledDate;

    // Navigate to workout dashboard, passing the target day as the initial date.
    nav.pushNamed(
      '/workout',
      arguments: targetDay,
    );

    // Show completion overlay
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const WorkoutFinishedScreen(),
      ),
    );
  }

  void _pushExerciseScreen(
    NavigatorState nav, {
    required List<WorkoutItem> blockItems,
    required int exerciseIndex,
    required String blockLabel,
    required String blockTypeLabel,
    required String? muscleSummary,
    required String? workoutId,
    required String? routineId,
    required int currentBlockIndex,
    required int totalBlocks,
  }) {
    if (exerciseIndex < 0 || exerciseIndex >= blockItems.length) return;
    final WorkoutItem item = blockItems[exerciseIndex];
    final exercise = ExerciseLibraryService.instance.getById(item.exerciseId);
    final String title = formatTitleCase(
      exercise?.name ?? 'Exercise ${exerciseIndex + 1}',
    );

    final route = PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, anim, secondary) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: EmptyWorkoutSessionScreen(
            blockLabel: blockLabel,
            blockTypeLabel: blockTypeLabel,
            exerciseTitle: title,
            muscleSummary: muscleSummary,
            exerciseImageUrl: exercise?.mediaUrl,
            exerciseId: item.exerciseId,
            workoutId: workoutId,
            routineId: routineId,
            currentBlockIndex: currentBlockIndex,
            totalBlocks: totalBlocks,
            targetSets: item.targetSets,
            targetReps: item.targetReps,
            targetLoadLb: item.targetLoad,
            targetWorkSeconds: item.targetTimeSec,
            targetRestSeconds: item.restSec,
            blockItems: blockItems,
            exerciseIndex: exerciseIndex,
            workout: widget.workout,
            // 🧷 Preserve the same scheduled date across all exercises in this session.
            scheduledDate: widget.scheduledDate,
          ),
        );
      },
      transitionsBuilder: (context, anim, secondary, child) => child,
    );

    nav.push(route);
  }

  void _toggleNotesEditor() {
    if (_showNotesEditor) {
      // Close the bottom sheet
      Navigator.of(context).pop();
    } else {
      // Open bottom sheet
      setState(() => _showNotesEditor = true);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _NotesBottomSheet(
          controller: _notesCtrl,
          focusNode: _notesFocus,
          onSave: () async {
            await _saveNotes();
          },
          onClear: () async {
            await _clearNotes();
          },
        ),
      ).then((_) {
        if (mounted) {
          setState(() => _showNotesEditor = false);
          FocusScope.of(context).unfocus();
          _saveSessionState();
        }
      });
    }
  }

  Future<void> _saveNotes() async {
    _saveSessionState();
  }

  Future<void> _clearNotes() async {
    _notesCtrl.clear();
    _saveSessionState();
  }

  void _openExerciseDetails() {
    final id = widget.exerciseId;
    if (id == null || id.isEmpty) return;
    _saveSessionState();
    Navigator.of(context).push(ExerciseDetailsPopupRoute(exerciseId: id));
  }

  Workout? _resolveWorkoutFromProvider() {
    final String? id = widget.workoutId;
    if (id == null || id.isEmpty) return null;
    try {
      final provider = context.read<WorkoutProvider>();
      return provider.getWorkoutById(id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _saveSessionState();
    WidgetsBinding.instance.removeObserver(this);
    _notesCtrl.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomSafe = mq.padding.bottom;

    final double actionRowBottomSpacing = bottomSafe + 24;
    const double actionButtonSize = 52;
    final double reservedBottom =
        actionButtonSize + actionRowBottomSpacing + 10;

    final int targetSets = (widget.targetSets ?? 3).clamp(1, 999);
    final int targetReps = widget.targetReps ?? 8;
    final double targetLoadLb = widget.targetLoadLb ?? 125;
    final int? targetWorkSeconds = widget.targetWorkSeconds;
    final int? targetRestSeconds = widget.targetRestSeconds;
    final WorkoutItem? exerciseItem = (widget.exerciseIndex >= 0 &&
            widget.exerciseIndex < widget.blockItems.length)
        ? widget.blockItems[widget.exerciseIndex]
        : null;

    double titleTopOffset() {
      const double xButtonTopMargin = 12.0;
      const double xButtonSize = 26.0;
      const double buffer = 6.0;
      const double nudgeUp = 50.0;
      final double base =
          mq.padding.top + xButtonTopMargin + xButtonSize + buffer - nudgeUp;
      return base.clamp(0.0, double.infinity);
    }

    final bool showComplete = _finalRestDone;

    final bool notesActive = _showNotesEditor || _notesCtrl.text.isNotEmpty;
    final String notesLabel = _showNotesEditor ? 'Close notes' : 'Open notes';
    final IconData notesIcon = (_showNotesEditor || notesActive)
        ? Icons.edit_note_rounded
        : Icons.sticky_note_2_outlined;

    return WillPopScope(
      onWillPop: () async {
        _saveSessionState();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // layout guard
            const Positioned.fill(child: SizedBox.shrink()),

            Positioned.fill(
              child: SafeArea(
                top: true,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: reservedBottom),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: titleTopOffset()),
                            BlockHeader(
                              blockLabel: widget.exerciseTitle,
                              blockTypeLabel: widget.blockTypeLabel,
                            ),
                            const SizedBox(height: 12),
                            TopMirror(
                              key: _topKey,
                              exerciseId: widget.exerciseId,
                              muscleSummary: widget.muscleSummary,
                              exerciseImageUrl: widget.exerciseImageUrl,
                              onCountingChanged: (v) {
                                setState(() => _isActivelyCounting = v);
                                _saveSessionState();
                              },
                              timerKey: _timerKey,
                              targetSets: targetSets,
                              targetReps: targetReps,
                              targetLoadLb: targetLoadLb,
                              targetWorkSeconds: targetWorkSeconds,
                              targetRestSeconds: targetRestSeconds,
                              onSavedCountChanged: (count) {
                                if (count != _savedCount) {
                                  setState(() {
                                    _savedCount = count;
                                    if (_savedCount < targetSets) {
                                      _finalRestStarted = false;
                                      _finalRestDone = false;
                                    }
                                  });
                                  _saveSessionState();
                                }
                              },
                              onFinalRestStarted: () {
                                setState(() {
                                  _finalRestStarted = true;
                                  _finalRestDone = false;
                                });
                                debugPrint(
                                  '[EmptyWorkoutSession] Final rest STARTED '
                                  '(block=${widget.currentBlockIndex}, '
                                  'exercise=${widget.exerciseIndex}, '
                                  'savedCount=$_savedCount)',
                                );
                                _saveSessionState();
                              },
                              onFinalRestFinished: () {
                                if (_savedCount >= targetSets) {
                                  setState(() {
                                    _finalRestDone = true;
                                  });
                                  debugPrint(
                                    '[EmptyWorkoutSession] Final rest FINISHED '
                                    '(block=${widget.currentBlockIndex}, '
                                    'exercise=${widget.exerciseIndex}, '
                                    'savedCount=$_savedCount, '
                                    'targetSets=$targetSets)',
                                  );
                                  _saveSessionState();
                                }
                              },
                              isComplete: showComplete,
                              initialSavedSets:
                                  _sessionToRestore?.completedSetsList,
                              workoutItem: exerciseItem,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Timeline button (top left)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: IconButton(
                tooltip: 'Workout timeline',
                visualDensity: VisualDensity.compact,
                onPressed: _openTimeline,
                icon: const Icon(Icons.timeline_rounded,
                    size: 26, color: Colors.black87),
              ),
            ),

            // Close X
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: _close,
                icon: const Icon(Icons.close_rounded,
                    size: 26, color: Colors.black87),
              ),
            ),

            // Bottom ACTION BAR
            Positioned(
              left: 0,
              right: 0,
              bottom: actionRowBottomSpacing,
              child: Hero(
                tag: _kActionBarHeroTag,
                flightShuttleBuilder: (context, anim, dir, fromCtx, toCtx) {
                  return dir == HeroFlightDirection.push
                      ? fromCtx.widget
                      : toCtx.widget;
                },
                child: Builder(
                  builder: (context) {
                    final baseTheme = Theme.of(context);

                    // This theme mainly affects Material buttons (kept for consistency)
                    final ButtonStyle compactButtonStyle = TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                    );

                    return Theme(
                      data: baseTheme.copyWith(
                        elevatedButtonTheme:
                            ElevatedButtonThemeData(style: compactButtonStyle),
                        filledButtonTheme:
                            FilledButtonThemeData(style: compactButtonStyle),
                        textButtonTheme:
                            TextButtonThemeData(style: compactButtonStyle),
                      ),
                      child: ActionBarRow(
                        notesIcon: notesIcon,
                        notesLabel: notesLabel,
                        notesActive: notesActive,
                        onNotesTap: _toggleNotesEditor,
                        onPlayTap: _toggleStartPause,
                        onRewind15Tap: _rewind15,
                        onFwd15Tap: _forward15,
                        onInfoTap: _openExerciseDetails,
                        animateSplitOnMount: true,
                        playing: _isActivelyCounting,
                        showComplete: showComplete,
                        // Wrap async handler so the type matches VoidCallback
                        onCompleteTap: () => _handleComplete(),
                        completeLabel: 'Complete',
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top content (adds Skip Rest button inside the ring)
class TopMirror extends StatefulWidget {
  const TopMirror({
    super.key,
    this.exerciseId,
    this.muscleSummary,
    this.exerciseImageUrl,
    required this.onCountingChanged,
    required this.timerKey,
    required this.targetSets,
    required this.targetReps,
    required this.targetLoadLb,
    this.targetWorkSeconds,
    this.targetRestSeconds,
    required this.onSavedCountChanged,
    this.onFinalRestStarted,
    this.onFinalRestFinished,
    required this.isComplete,
    this.initialSavedSets,
    this.workoutItem,
  });

  final String? exerciseId;
  final String? muscleSummary;
  final String? exerciseImageUrl;

  final ValueChanged<bool> onCountingChanged;
  final GlobalKey<SetTimerCardState> timerKey;
  final int targetSets;
  final int targetReps;
  final double targetLoadLb;
  final int? targetWorkSeconds;
  final int? targetRestSeconds;
  final ValueChanged<int> onSavedCountChanged;

  final VoidCallback? onFinalRestStarted;
  final VoidCallback? onFinalRestFinished;

  /// Initial saved sets to restore from session state
  final List<SavedSetData>? initialSavedSets;

  /// True once the final rest after the last target set has finished.
  /// Used to highlight the timer ring in green.
  final bool isComplete;

  final WorkoutItem? workoutItem;

  @override
  State<TopMirror> createState() => _TopMirrorState();
}

class _SavedSet {
  final int index;
  final double loadLb;
  final int reps;
  final DateTime timestamp;
  final Duration elapsed;
  _SavedSet({
    required this.index,
    required this.loadLb,
    required this.reps,
    required this.timestamp,
    required this.elapsed,
  });
}

class _TopMirrorState extends State<TopMirror> {
  int _totalSets = 1;
  double _currLoadLb = 0;
  int _currReps = 0;
  final List<_SavedSet> _saved = [];

  bool _isResting = false;
  DateTime? _currentSetStartedAt;

  String _formatClock(int seconds) {
    if (seconds <= 0) return '0:00';
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      final hh = duration.inHours.toString().padLeft(2, '0');
      final mm = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    final mm = duration.inMinutes;
    final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void initState() {
    super.initState();

    // Restore saved sets if provided
    if (widget.initialSavedSets != null &&
        widget.initialSavedSets!.isNotEmpty) {
      for (final set in widget.initialSavedSets!) {
        _saved.add(_SavedSet(
          index: set.index,
          loadLb: set.loadLb,
          reps: set.reps,
          timestamp: DateTime.parse(set.timestampIso),
          elapsed: Duration(seconds: set.elapsedSeconds),
        ));
      }
      // Initialize UI based on last saved set
      final last = _saved.last;
      _totalSets = widget.targetSets.clamp(_saved.length, 999);
      _currLoadLb = last.loadLb;
      _currReps = last.reps;
    } else {
      // Default initialization
      _totalSets = widget.targetSets;
      _currLoadLb = widget.targetLoadLb;
      _currReps = widget.targetReps;
    }

    debugPrint(
      '[TopMirror] initState → '
      'targetSets=${widget.targetSets}, '
      'initialSaved=${_saved.length}, '
      'targetReps=${widget.targetReps}, '
      'targetLoadLb=${widget.targetLoadLb}',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSavedCountChanged(_saved.length);
    });
  }

  void _refreshHudFromLocal() {
    final int target = widget.targetSets;
    if (_saved.isEmpty) {
      setState(() {
        _totalSets = target;
        _currLoadLb = widget.targetLoadLb;
        _currReps = widget.targetReps;
      });
      return;
    }

    final _SavedSet last = _saved.last;
    final int computedTotal = math.max(target, _saved.length);

    setState(() {
      _totalSets = computedTotal;
      _currLoadLb = last.loadLb;
      _currReps = last.reps;
    });
  }

  List<wc.WorkoutSetStat> collectStats() {
    debugPrint(
      '[TopMirror] collectStats → count=${_saved.length}',
    );
    return _saved
        .map((s) => wc.WorkoutSetStat(
              index: s.index,
              elapsed: s.elapsed,
              loadLb: s.loadLb,
              reps: s.reps,
              timestamp: s.timestamp,
            ))
        .toList(growable: false);
  }

  /// Restore previously saved sets from session state
  void restoreSavedSets(List<SavedSetData> sets) {
    debugPrint(
      '[TopMirror] restoreSavedSets → incoming=${sets.length}',
    );
    _saved.clear();
    for (final set in sets) {
      _saved.add(_SavedSet(
        index: set.index,
        loadLb: set.loadLb,
        reps: set.reps,
        timestamp: DateTime.parse(set.timestampIso),
        elapsed: Duration(seconds: set.elapsedSeconds),
      ));
    }
    _refreshHudFromLocal();
    widget.onSavedCountChanged(_saved.length);

    // 🔧 FIX: Sync restored sets to WorkoutProvider draft
    if (widget.exerciseId != null && sets.isNotEmpty) {
      try {
        final provider = context.read<WorkoutProvider>();
        for (final set in sets) {
          provider.logSet(
            exerciseId: widget.exerciseId!,
            reps: set.reps,
            load: set.loadLb,
            rpe: null,
          );
        }
        debugPrint(
          '[TopMirror] Synced ${sets.length} restored sets to WorkoutProvider draft',
        );
      } catch (e) {
        debugPrint(
            '[TopMirror] ⚠️ Error syncing restored sets to provider: $e');
      }
    }
  }

  Future<void> _handleLogTap() async {
    debugPrint(
      '[TopMirror] _handleLogTap → currentSaved=${_saved.length}/'
      '${widget.targetSets}',
    );

    final wasRunning =
        widget.timerKey.currentState?.isStopwatchRunning ?? false;
    widget.timerKey.currentState?.pauseStopwatchPublic();

    final result = await Navigator.of(context).push<LoggedSet>(
      HeroDialogRoute(
        builder: (ctx) => LogSetBubble(
          heroTag: kLogSetHeroTag,
          defaultLoadLb: _currLoadLb,
          defaultReps: _currReps,
        ),
      ),
    );

    if (!mounted) return;

    if (result == null) {
      if (wasRunning) widget.timerKey.currentState?.resumeStopwatchPublic();
      return;
    }

    final DateTime now = AppClock.now();
    final Duration elapsed = (_currentSetStartedAt != null)
        ? now.difference(_currentSetStartedAt!)
        : Duration.zero;

    final int nextIndex = _saved.length + 1;
    final _SavedSet saved = _SavedSet(
      index: nextIndex,
      loadLb: result.loadLb,
      reps: result.reps,
      timestamp: now,
      elapsed: elapsed,
    );
    _saved.add(saved);

    debugPrint(
      '[TopMirror] Logged set #$nextIndex '
      '(load=${result.loadLb}, reps=${result.reps}, '
      'elapsed=${elapsed.inSeconds}s) → totalSaved=${_saved.length}',
    );

    // 🔧 FIX: Also save to WorkoutProvider draft so finishSession() can write the log
    if (widget.exerciseId != null) {
      try {
        final provider = context.read<WorkoutProvider>();
        provider.logSet(
          exerciseId: widget.exerciseId!,
          reps: result.reps,
          load: result.loadLb,
          rpe: null,
        );
        debugPrint(
          '[TopMirror] Synced set to WorkoutProvider draft (exerciseId=${widget.exerciseId})',
        );
      } catch (e) {
        debugPrint('[TopMirror] ⚠️ Error logging set to provider: $e');
      }
    }

    setState(() {
      _isResting = true;
      _currentSetStartedAt = null;
    });

    widget.timerKey.currentState
        ?.beginRestPublic(widget.targetRestSeconds); // starts rest countdown
    _refreshHudFromLocal();
    widget.onSavedCountChanged(_saved.length);

    if (nextIndex >= widget.targetSets) {
      debugPrint(
        '[TopMirror] onFinalRestStarted callback '
        '(nextIndex=$nextIndex, targetSets=${widget.targetSets})',
      );
      widget.onFinalRestStarted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showMuscles = (widget.muscleSummary != null &&
        widget.muscleSummary!.trim().isNotEmpty);

    double gap(double normal, double tight) => normal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final double imageSize = math.min(160, maxW * 0.50);
        final double ringSize = math.min(240, maxW * 0.82);

        String topLabel() {
          if (_isResting) {
            final rest = widget.targetRestSeconds;
            if (rest != null && rest > 0) {
              return 'Rest ${_formatClock(rest)}';
            }
            return 'Rest';
          }
          final work = widget.targetWorkSeconds;
          if (work != null && work > 0) {
            return _formatClock(work);
          }
          return '+ 1:00';
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMuscles) ...[
              Text(
                widget.muscleSummary!,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.65),
                  fontSize: 13.5,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: gap(6, 2)),
            ],
            ExerciseThumbnail(url: widget.exerciseImageUrl, size: imageSize),
            SizedBox(height: gap(6, 2)),
            CurrentSetHUD(
              setIndex: _saved
                  .length, // Show completed sets count (0/3, 1/3, 2/3, 3/3)
              totalSets: _totalSets,
              targetLoadLb: _currLoadLb,
              targetReps: _currReps,
              onLogTap: _handleLogTap,
              showTargetLine: true,
            ),
            SizedBox(height: gap(6, 4)),
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SetTimerCard(
                    key: widget.timerKey,
                    ringSize: ringSize,
                    onCountingChanged: (running) {
                      widget.onCountingChanged(running);

                      final timerState = widget.timerKey.currentState;
                      final bool timerInRest = timerState?.timerMode == 'rest';
                      final bool restFinished =
                          !timerInRest || (timerState?.restRemaining ?? 0) <= 0;

                      if (timerInRest && !_isResting) {
                        setState(() {
                          _isResting = true;
                          _currentSetStartedAt = null;
                        });
                      }

                      // mark work-start edges
                      if (running &&
                          !timerInRest &&
                          _currentSetStartedAt == null) {
                        _currentSetStartedAt = AppClock.now();
                      }

                      // when counting stops during REST -> rest finished
                      if (!running && _isResting) {
                        if (!restFinished) {
                          return;
                        }
                        debugPrint(
                          '[TopMirror] Rest finished → '
                          'saved=${_saved.length}, '
                          'targetSets=${widget.targetSets}',
                        );
                        setState(() => _isResting = false);
                        if (_saved.length < widget.targetSets) {
                          _currentSetStartedAt = AppClock.now();
                        }
                        if (_saved.length >= widget.targetSets) {
                          debugPrint(
                            '[TopMirror] onFinalRestFinished callback '
                            '(saved=${_saved.length}, '
                            'targetSets=${widget.targetSets})',
                          );
                          widget.onFinalRestFinished?.call();
                        }
                      }
                    },
                    onLogTap: _handleLogTap,
                    highlightComplete: widget.isComplete,
                    countdownSeconds: widget.targetWorkSeconds,
                  ),

                  // Label inside ring (IgnorePointer ensures it doesn't block taps)
                  Align(
                    alignment: const Alignment(0, -0.72),
                    child: IgnorePointer(
                      child: Text(
                        topLabel(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isResting
                              ? Colors.black.withValues(alpha: 0.55)
                              : const Color(0xFF76C7E6).withValues(alpha: 0.95),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: gap(8, 6)),
          ],
        );
      },
    );
  }
}

/// Bottom sheet for editing exercise notes
class _NotesBottomSheet extends StatelessWidget {
  const _NotesBottomSheet({
    required this.controller,
    required this.focusNode,
    required this.onSave,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSave;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final screenHeight = mq.size.height;

    // Taller popup: up to ~55% of the screen height
    final maxHeight = screenHeight * 0.55;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight + bottomInset,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with centered title (no divider under it)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                height: 36,
                child: Center(
                  child: Text(
                    'Exercise Notes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.85),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Expanded text box – fills the available vertical space
            Flexible(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: null,
                  maxLines: null,
                  expands: true, // <- makes it stretch vertically
                  decoration: InputDecoration(
                    hintText: 'Write anything you want to remember…',
                    hintStyle: TextStyle(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.03),
                    contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.10),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Bottom action row: Clear / Done
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await onClear();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      await onSave();
                      Navigator.of(context).pop(); // close sheet
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
