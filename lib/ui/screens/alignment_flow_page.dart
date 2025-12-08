import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/alignment_schedule_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/services/workout_boxes.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/models/session_state.dart';
import 'package:kontinuum/services/workout_progress_service.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/ui/screens/day_detail_page.dart' as day;
import 'package:kontinuum/ui/workout/session_screen.dart';
import 'package:kontinuum/ui/workout/session_screen_args.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';
import 'package:kontinuum/ui/screens/budget/utils/recurring_schedule.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class AlignmentFlowPage extends StatefulWidget {
  const AlignmentFlowPage({required this.heroTag});

  final String heroTag;

  @override
  State<AlignmentFlowPage> createState() => _AlignmentFlowPageState();
}

enum _AlignmentFlowPhase {
  overview,
  morningRoutine,
  objectives,
  missions,
  calendar,
  workouts,
  budget,
  complete,
}

class _AlignmentFlowPageState extends State<AlignmentFlowPage> {
  static const String _userName = 'Skyler';
  _AlignmentFlowPhase _phase = _AlignmentFlowPhase.overview;
  bool _morningRoutineComplete = false;
  bool _morningRoutineSeen = false;
  Map<String, int> _latestGlanceSnapshot = {};
  void _handleMorningRoutineCompletionChanged(bool isComplete) {
    if (_morningRoutineComplete == isComplete) return;
    setState(() {
      _morningRoutineComplete = isComplete;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final animation = ModalRoute.of(context)?.animation;
    final curved = animation == null
        ? null
        : CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                color: Colors.black.withValues(alpha: .55),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: media.padding.top + 24,
                left: 16,
                right: 16,
              ),
              child: FadeTransition(
                opacity: curved ?? const AlwaysStoppedAnimation(1.0),
                child: Hero(
                  tag: widget.heroTag,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: (size.width * 0.92).clamp(300.0, 720.0),
                      maxHeight: size.height * 0.78,
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202A3A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .14),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 22,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                    opacity: animation, child: child),
                            child: Column(
                              key: ValueKey(_phase),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildPhaseBody()),
                                const SizedBox(height: 12),
                                _buildPhaseActions(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final dateLabel = DateFormat.yMMMMEEEEd().format(AppClock.now());
    final bool showBack = _phase != _AlignmentFlowPhase.overview &&
        _phase != _AlignmentFlowPhase.complete;
    return Row(
      children: [
        if (showBack)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            onPressed: () =>
                setState(() => _phase = _AlignmentFlowPhase.overview),
          )
        else
          const SizedBox(width: 40),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Daily Alignment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildPhaseBody() {
    switch (_phase) {
      case _AlignmentFlowPhase.morningRoutine:
        final shouldShowMorning = _shouldShowMorningRoutine(context);
        if (!shouldShowMorning) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_phase == _AlignmentFlowPhase.morningRoutine) {
              setState(() {
                _morningRoutineSeen = true;
                _phase = _AlignmentFlowPhase.objectives;
              });
            }
          });
          return const SizedBox.shrink();
        }
        return _MorningRoutineAlignmentView(
          onCompletionChanged: _handleMorningRoutineCompletionChanged,
        );
      case _AlignmentFlowPhase.objectives:
        return const _ObjectiveAlignmentView();
      case _AlignmentFlowPhase.missions:
        return const _MissionAlignmentView();
      case _AlignmentFlowPhase.workouts:
        return const _WorkoutAlignmentView();
      case _AlignmentFlowPhase.budget:
        return const _BudgetAlignmentView();
      case _AlignmentFlowPhase.complete:
        return const _AlignmentCompleteView();
      case _AlignmentFlowPhase.calendar:
        return const _CalendarAlignmentView();
      case _AlignmentFlowPhase.overview:
      default:
        return Consumer<AlignmentScheduleProvider>(
          builder: (context, alignment, _) {
            final int completed = alignment.completedTodayCount;
            final int total = alignment.totalCheckIns;
            final bool isFirstVisitToday = completed == 0;
            final bool isInProgress = completed > 0 && completed < total;

            if (!isFirstVisitToday && !isInProgress) {
              return Center(
                child: Text(
                  'Alignment flow coming soon',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            final String headline = isFirstVisitToday
                ? 'Welcome back, $_userName!'
                : 'Progress so far · ${completed}/${total} check-ins';
            final String subhead = isFirstVisitToday
                ? 'Set your intent and move through today with purpose.'
                : 'Momentum check: ${completed}/${total} done. You’re on the board—keep stacking wins.';

            final glanceItems = _buildGlanceItemsWithDelta(context, alignment);

            return SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subhead,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .75),
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Your day at a glance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .86),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GlancePillList(items: glanceItems),
                  ],
                ),
              ),
            );
          },
        );
    }
  }

  bool _shouldShowMorningRoutine(BuildContext context) {
    if (_morningRoutineSeen) return false;
    final alignment = context.read<AlignmentScheduleProvider>();
    final completed = alignment.completedTodayCount;
    return completed == 0;
  }

  void _persistGlanceSnapshot() {
    if (_latestGlanceSnapshot.isEmpty) return;
    final alignment = context.read<AlignmentScheduleProvider>();
    alignment.cacheGlanceSnapshot(_latestGlanceSnapshot);
  }

  List<_GlanceItem> _buildGlanceItemsWithDelta(
    BuildContext context,
    AlignmentScheduleProvider alignment,
  ) {
    final DateTime today = AppClock.now();
    final raw = _gatherGlanceItems(context, today);
    _latestGlanceSnapshot = {
      for (final item in raw) item.label: item.value,
    };
    final baseline = alignment.glanceSnapshotForToday();
    if (baseline == null || baseline.isEmpty) {
      return raw;
    }
    return raw
        .map(
          (item) => item.copyWith(
            delta: baseline.containsKey(item.label)
                ? item.value - baseline[item.label]!
                : null,
          ),
        )
        .toList();
  }

  List<_GlanceItem> _gatherGlanceItems(BuildContext context, DateTime day) {
    final DateTime today = DateTime(day.year, day.month, day.day);
    final List<_GlanceItem> out = [];

    try {
      final obj = context.read<ObjectiveProvider>();
      final todays = obj.getObjectivesForDay(today);
      final int completed = todays.where((o) => o.isCompleted).length;
      out.add(_GlanceItem(label: 'Objectives due', value: todays.length));
      out.add(_GlanceItem(label: 'Objectives complete', value: completed));
    } catch (_) {}

    try {
      final wp = context.read<WorkoutProvider>();
      final fp = context.read<FitnessProfileProvider>();
      int due = 0;
      int complete = 0;

      final routineId = fp.profile?.currentRoutineId;
      if (routineId != null) {
        final routine = wp.getRoutineById(routineId);
        due = routine?.workoutIds.length ?? 0;
      } else {
        due = wp.workouts.length;
      }
      complete = _countCompletedWorkoutsToday();

      out.add(_GlanceItem(label: 'Workouts due', value: due));
      out.add(_GlanceItem(label: 'Workouts complete', value: complete));
    } catch (_) {}

    try {
      final mp = context.read<MissionProvider>();
      final accepted = mp.acceptedMissions.length;
      final completed = mp.completedMissions.length;
      out.add(_GlanceItem(label: 'Missions active', value: accepted));
      out.add(_GlanceItem(label: 'Missions complete', value: completed));
    } catch (_) {}

    out.add(const _GlanceItem(label: 'Reminders & tasks', value: 0));
    out.add(const _GlanceItem(label: 'Bills today', value: 0));

    return out;
  }

  int _countCompletedWorkoutsToday() {
    final DateTime today = AppClock.now();
    int count = 0;

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    DateTime? extractDate(dynamic log) {
      if (log is Map) {
        final v = log['dateYmd'] ??
            log['date'] ??
            log['completedAt'] ??
            log['startedAt'];
        if (v is String) {
          if (v.length == 8 && int.tryParse(v) != null) {
            final y = int.tryParse(v.substring(0, 4));
            final m = int.tryParse(v.substring(4, 6));
            final d = int.tryParse(v.substring(6, 8));
            if (y != null && m != null && d != null) return DateTime(y, m, d);
          }
          final parsed = DateTime.tryParse(v);
          if (parsed != null) {
            return DateTime(parsed.year, parsed.month, parsed.day);
          }
        } else if (v is DateTime) {
          return DateTime(v.year, v.month, v.day);
        }
      } else if (log is WorkoutLog) {
        final d = DateTime.tryParse(log.dateYmd);
        if (d != null) {
          return DateTime(d.year, d.month, d.day);
        }
      }
      return null;
    }

    bool isCompleted(dynamic log) {
      if (log == null) return false;
      if (log is Map) {
        for (final k in ['isCompleted', 'completed', 'finished', 'done']) {
          final v = log[k];
          if (v is bool && v) return true;
        }
        final exCount = log['exerciseCount'];
        if (exCount is int && exCount > 0) return true;
        final vol = log['volume'] ?? log['totalVolume'];
        if (vol is num && vol > 0) return true;
        return false;
      }
      if (log is WorkoutLog) {
        return log.exerciseLogs.isNotEmpty;
      }
      return false;
    }

    try {
      for (final raw in WorkoutBoxes.logsBox.values) {
        final d = extractDate(raw);
        if (d != null && sameDay(d, today) && isCompleted(raw)) {
          count++;
        }
      }
    } catch (_) {}

    return count;
  }

  Widget _buildPhaseActions() {
    if (_phase == _AlignmentFlowPhase.morningRoutine) {
      final bool canProceed = _morningRoutineComplete;
      final theme = Theme.of(context);
      final ButtonStyle nextStyle = FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ).copyWith(
        backgroundColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.disabled)
              ? Colors.white.withValues(alpha: 0.18)
              : theme.colorScheme.primary,
        ),
        foregroundColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.disabled)
              ? Colors.white.withValues(alpha: 0.6)
              : theme.colorScheme.onPrimary,
        ),
      );
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.overview),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: canProceed
                  ? () => setState(() {
                        _morningRoutineSeen = true;
                        _phase = _AlignmentFlowPhase.objectives;
                      })
                  : null,
              style: nextStyle,
              child: const Text('Next'),
            ),
          ),
        ],
      );
    }
    if (_phase == _AlignmentFlowPhase.objectives) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                if (_morningRoutineSeen) {
                  _phase = _AlignmentFlowPhase.overview;
                } else {
                  _phase = _AlignmentFlowPhase.morningRoutine;
                }
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.missions),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      );
    }
    if (_phase == _AlignmentFlowPhase.missions) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.objectives),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.calendar),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      );
    }
    if (_phase == _AlignmentFlowPhase.calendar) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.missions),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.workouts),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      );
    }
    if (_phase == _AlignmentFlowPhase.workouts) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.calendar),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.budget),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      );
    }
    if (_phase == _AlignmentFlowPhase.budget) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.workouts),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () =>
                  setState(() => _phase = _AlignmentFlowPhase.complete),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Complete'),
            ),
          ),
        ],
      );
    }
    if (_phase == _AlignmentFlowPhase.complete) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () async {
            final provider = context.read<AlignmentScheduleProvider>();
            await provider.completeNextCheckIn();
            if (mounted) {
              Navigator.of(context).maybePop();
            }
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Done'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () {
          _persistGlanceSnapshot();
          setState(() => _phase = _AlignmentFlowPhase.morningRoutine);
        },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text(
          'Start',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AlignmentSectionHeader extends StatelessWidget {
  const _AlignmentSectionHeader({
    required this.title,
    required this.subtitle,
    this.bottomSpacing = 12,
    this.subtitleSpacing = 6,
  });

  final String title;
  final String subtitle;
  final double bottomSpacing;
  final double subtitleSpacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: subtitleSpacing),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .7),
              fontSize: 12,
            ),
          ),
          SizedBox(height: bottomSpacing),
        ],
      ),
    );
  }
}

class _MorningRoutineAlignmentView extends StatefulWidget {
  const _MorningRoutineAlignmentView({required this.onCompletionChanged});

  final ValueChanged<bool> onCompletionChanged;

  @override
  State<_MorningRoutineAlignmentView> createState() =>
      _MorningRoutineAlignmentViewState();
}

class _MorningRoutineAlignmentViewState
    extends State<_MorningRoutineAlignmentView> {
  final List<_RoutineTask> _tasks = [
    _RoutineTask(id: 'water', title: 'Drink a glass of water'),
    _RoutineTask(id: 'shower', title: 'Shower'),
    _RoutineTask(id: 'brush', title: 'Brush your teeth'),
  ];

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _notifyCompletionChanged(
      deferToPostFrame: true,
    );
  }

  void _notifyCompletionChanged({bool deferToPostFrame = false}) {
    final bool allComplete =
        _tasks.isNotEmpty && _tasks.every((task) => task.isComplete);
    if (deferToPostFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onCompletionChanged(allComplete);
      });
    } else {
      widget.onCompletionChanged(allComplete);
    }
  }

  void _toggleTask(String id) {
    setState(() {
      final task = _tasks.firstWhere((task) => task.id == id);
      task.isComplete = !task.isComplete;
    });
    _notifyCompletionChanged();
  }

  void _toggleEditing() {
    setState(() => _isEditing = !_isEditing);
    if (!_isEditing) {
      FocusScope.of(context).unfocus();
    }
  }

  void _handleAddTask() {
    if (!_isEditing) return;
    final task = _RoutineTask(
      id: 'custom_${AppClock.now().millisecondsSinceEpoch}',
      title: '',
    );
    setState(() => _tasks.add(task));
    _notifyCompletionChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      task.focusNode.requestFocus();
    });
  }

  void _focusTask(_RoutineTask task) {
    if (!_isEditing) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      task.focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final task in _tasks) {
      task.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlignmentSectionHeader(
          title: 'Morning Routine Alignment',
          subtitle:
              'Preview your morning anchors before you commit to objectives.',
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Flow for today',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          onPressed: _toggleEditing,
                          tooltip: _isEditing ? 'Done editing' : 'Edit flow',
                          splashRadius: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 28, height: 28),
                          icon: Icon(
                            _isEditing ? Icons.check : Icons.edit,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEditing
                      ? 'Reorder, remove, or add quick hits to this routine.'
                      : 'Tap a step as you complete it to keep momentum.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _tasks.length + (_isEditing ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index < _tasks.length) {
                        final task = _tasks[index];
                        return _RoutinePill(
                          key: ValueKey(task.id),
                          controller: task.controller,
                          focusNode: task.focusNode,
                          isComplete: task.isComplete,
                          onToggle: () => _toggleTask(task.id),
                          editing: _isEditing,
                          onTextChanged: (_) => setState(() {}),
                          onRequestFocus: () => _focusTask(task),
                          placeholder: 'New task',
                        );
                      }
                      return _AddRoutineTaskPill(onTap: _handleAddTask);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineTask {
  _RoutineTask({
    required this.id,
    required String title,
    this.isComplete = false,
  }) : controller = TextEditingController(text: title) {
    focusNode = FocusNode();
  }

  final String id;
  bool isComplete;
  final TextEditingController controller;
  late final FocusNode focusNode;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _RoutinePill extends StatefulWidget {
  const _RoutinePill({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isComplete,
    required this.onToggle,
    required this.editing,
    required this.onTextChanged,
    required this.onRequestFocus,
    required this.placeholder,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isComplete;
  final VoidCallback onToggle;
  final bool editing;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onRequestFocus;
  final String placeholder;

  @override
  State<_RoutinePill> createState() => _RoutinePillState();
}

class _RoutinePillState extends State<_RoutinePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fillController;
  late final Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.isComplete ? 1 : 0,
    );
    _fillAnimation = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _RoutinePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isComplete != widget.isComplete) {
      _fillController.animateTo(
        widget.isComplete ? 1.0 : 0.0,
        curve: widget.isComplete ? Curves.easeOutCubic : Curves.easeInCubic,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isComplete = widget.isComplete;
    final Color borderColor =
        isComplete ? Colors.white10 : Colors.white.withValues(alpha: 0.18);
    final Color bgColor = isComplete
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.07);
    final TextStyle baseTextStyle = TextStyle(
      color: Colors.white.withValues(alpha: isComplete ? 0.6 : 0.95),
      fontWeight: FontWeight.w600,
      fontSize: 15,
      height: 1.2,
    );
    final TextStyle hintStyle = baseTextStyle.copyWith(
      color: Colors.white.withValues(alpha: 0.35),
    );
    final StrutStyle strutStyle = StrutStyle(
      fontSize: baseTextStyle.fontSize,
      height: baseTextStyle.height,
      fontWeight: baseTextStyle.fontWeight,
      forceStrutHeight: true,
    );
    const textHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: true,
      applyHeightToLastDescent: true,
    );

    Widget pillContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            behavior: HitTestBehavior.translucent,
            child: _AnimatedCheckCircle(
              animation: _fillAnimation,
              isDisabled: false,
              isComplete: isComplete,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: widget.editing
                ? TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    style: baseTextStyle,
                    strutStyle: strutStyle,
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      hintStyle: hintStyle,
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    cursorColor: Colors.greenAccent,
                    textCapitalization: TextCapitalization.sentences,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: widget.onTextChanged,
                    onTap: widget.onRequestFocus,
                  )
                : Text(
                    widget.controller.text.isEmpty
                        ? widget.placeholder
                        : widget.controller.text,
                    style: baseTextStyle,
                    strutStyle: strutStyle,
                    textHeightBehavior: textHeightBehavior,
                  ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: isComplete
                ? Icon(
                    Icons.check,
                    key: ValueKey('${widget.controller.text}_check'),
                    color: Colors.greenAccent.withValues(alpha: 0.9),
                    size: 16,
                  )
                : const SizedBox(width: 16, height: 16),
          ),
        ],
      ),
    );

    if (widget.editing) {
      return GestureDetector(
        onTap: widget.onRequestFocus,
        behavior: HitTestBehavior.opaque,
        child: pillContent,
      );
    }

    return GestureDetector(
      onTap: widget.onToggle,
      behavior: HitTestBehavior.opaque,
      child: pillContent,
    );
  }
}

class _AddRoutineTaskPill extends StatelessWidget {
  const _AddRoutineTaskPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.2,
          ),
          color: Colors.white.withValues(alpha: 0.015),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 12),
            Text(
              'Add task',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectiveAlignmentView extends StatelessWidget {
  const _ObjectiveAlignmentView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ObjectiveProvider>();
    final DateTime selected =
        provider.selectedDateNotifier.value ?? AppClock.now();
    final objectives = provider.getObjectivesForDay(selected);
    final incomplete =
        objectives.where((obj) => !obj.isCompleted).toList(growable: false);
    final complete =
        objectives.where((obj) => obj.isCompleted).toList(growable: false);

    if (objectives.isEmpty) {
      return Center(
        child: Text(
          'No objectives for today',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .7),
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlignmentSectionHeader(
          title: 'Objective Alignment',
          subtitle:
              'AEA · incomplete objectives stay here until everything is done.',
          bottomSpacing: 0,
          subtitleSpacing: 4,
        ),
        Expanded(
          child: ListView(
            children: [
              ..._buildCategorySections(
                incomplete,
                highlight: true,
                selectedDate: selected,
              ),
              if (complete.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Completed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildCategorySections(
                  complete,
                  highlight: false,
                  selectedDate: selected,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategorySections(
    List<Objective> objectives, {
    required bool highlight,
    required DateTime selectedDate,
  }) {
    if (objectives.isEmpty) return const [];

    final Map<String, List<Objective>> grouped = {};
    for (final obj in objectives) {
      if (obj.isAbstinence) {
        continue;
      }
      final label =
          obj.categoryIds.isNotEmpty ? obj.categoryIds.first : 'Uncategorized';
      grouped.putIfAbsent(label, () => []).add(obj);
    }

    int priority(String label) {
      if (label == 'Uncategorized') return 2;
      return 1;
    }

    final labels = grouped.keys.toList()
      ..sort((a, b) {
        final pa = priority(a);
        final pb = priority(b);
        if (pa != pb) return pa.compareTo(pb);
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    final List<Widget> sections = [];
    for (final label in labels) {
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      for (final obj in grouped[label]!) {
        sections.add(
          _ObjectiveTile(
            key: ValueKey(obj.id),
            objective: obj,
            highlight: highlight,
            selectedDate: selectedDate,
          ),
        );
        sections.add(const SizedBox(height: 6));
      }
      if (sections.isNotEmpty) {
        sections.removeLast(); // remove trailing spacer for each section
        sections.add(const SizedBox(height: 10));
      }
    }
    if (sections.isNotEmpty) {
      sections.removeLast(); // remove last spacer
    }
    return sections;
  }
}

class _ObjectiveTile extends StatefulWidget {
  const _ObjectiveTile({
    super.key,
    required this.objective,
    required this.highlight,
    required this.selectedDate,
  });

  final Objective objective;
  final bool highlight;
  final DateTime selectedDate;

  @override
  State<_ObjectiveTile> createState() => _ObjectiveTileState();
}

class _ObjectiveTileState extends State<_ObjectiveTile>
    with TickerProviderStateMixin {
  late final AnimationController _fillController;
  late final Animation<double> _fillAnimation;
  bool _isAnimatingTap = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.highlight ? 0 : 1,
    );
    _fillAnimation = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _ObjectiveTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight != oldWidget.highlight &&
        !_fillController.isAnimating) {
      final target = widget.highlight ? 0.0 : 1.0;
      _fillController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: widget.highlight ? Curves.easeInCubic : Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  Future<void> _handleToggle() async {
    if (_isAnimatingTap || widget.objective.isLocked) return;
    setState(() => _isAnimatingTap = true);
    final provider = context.read<ObjectiveProvider>();
    if (widget.highlight) {
      await _fillController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      setState(() => _removed = true);
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      provider.toggleObjectiveCompletion(
        widget.selectedDate,
        widget.objective.id,
      );
    } else {
      await _fillController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInCubic,
      );
      if (!mounted) return;
      provider.toggleObjectiveCompletion(
        widget.selectedDate,
        widget.objective.id,
      );
    }
    if (mounted) {
      setState(() {
        _isAnimatingTap = false;
        _removed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = !widget.highlight;
    final bool isLocked = widget.objective.isLocked;
    final bool isDisabled = isLocked || _isAnimatingTap;
    final Color borderColor =
        isCompleted ? Colors.white10 : Colors.white.withValues(alpha: 0.18);
    final Color bgColor = isCompleted
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.08);

    final Widget card = AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isDisabled ? null : _handleToggle,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              _AnimatedCheckCircle(
                animation: _fillAnimation,
                isDisabled: isDisabled,
                isComplete: isCompleted,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.objective.title,
                      style: TextStyle(
                        color: isLocked
                            ? Colors.white.withValues(alpha: 0.35)
                            : (isCompleted
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.white),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.objective.lockedReason != null && isLocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.objective.lockedReason!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.greenAccent,
                        size: 18,
                      )
                    : const SizedBox(width: 18, height: 18),
              ),
            ],
          ),
        ),
      ),
    );

    final animatedCard = AnimatedBuilder(
      animation: _fillAnimation,
      child: card,
      builder: (context, child) {
        final double translateY =
            widget.highlight ? _fillAnimation.value * 10 : 0.0;
        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: isLocked ? 0.7 : 1.0,
            child: child,
          ),
        );
      },
    );

    final keyedCard = KeyedSubtree(
      key: ValueKey('${widget.highlight}_${widget.objective.id}'),
      child: animatedCard,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _removed ? const SizedBox.shrink() : keyedCard,
    );
  }
}

class _AnimatedCheckCircle extends StatelessWidget {
  const _AnimatedCheckCircle({
    required this.animation,
    required this.isDisabled,
    required this.isComplete,
    this.size = 28,
  });

  final Animation<double> animation;
  final bool isDisabled;
  final bool isComplete;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color ringColor = isComplete
        ? Colors.greenAccent.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: isDisabled ? 0.45 : 0.85);
    final Color fillColor =
        isDisabled ? Colors.white.withValues(alpha: 0.35) : Colors.greenAccent;

    final double ringDiameter = size - 4;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final double progress = animation.value.clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ringDiameter,
                height: ringDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 2),
                ),
              ),
              Transform.scale(
                scale: progress,
                child: Container(
                  width: ringDiameter,
                  height: ringDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fillColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MissionAlignmentView extends StatelessWidget {
  const _MissionAlignmentView();

  @override
  Widget build(BuildContext context) {
    final missionProvider = context.watch<MissionProvider>();
    final missions = missionProvider.acceptedMissions;

    final dueSoon = missions
        .where((mission) => mission.isAccepted && !mission.isCompleted)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlignmentSectionHeader(
          title: 'Mission Alignment',
          subtitle:
              'AEA · keep your accepted missions on radar until every one is handled.',
        ),
        Expanded(
          child: dueSoon.isEmpty
              ? Center(
                  child: Text(
                    "You're all clear!",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: dueSoon.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final mission = dueSoon[index];
                    final tag = mission.categoryIds.isNotEmpty
                        ? mission.categoryIds.first
                        : 'General';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mission.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Category: $tag',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.flag, color: Colors.orangeAccent),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CalendarAlignmentView extends StatelessWidget {
  const _CalendarAlignmentView();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: day.DayPlanStore.I,
      builder: (context, _) {
        final DateTime today = AppClock.now();
        final DateTime dayOnly = day.DayPlanStore.dateOnly(today);
        final reminders = day.DayPlanStore.I.reminders(dayOnly);
        final tasks = day.DayPlanStore.I.tasks(dayOnly);
        final events = _buildEvents(context, dayOnly, reminders, tasks);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AlignmentSectionHeader(
              title: 'Calendar Alignment',
              subtitle: 'AEA · review events & reminders happening today.',
            ),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        "You're all caught up!",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _iconForEvent(event),
                                color: _colorForEvent(event),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event.subtitle,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: .6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<_CalendarEvent> _buildEvents(
    BuildContext context,
    DateTime dayOnly,
    List<day.Reminder> reminders,
    List<day.Task> tasks,
  ) {
    final events = <_CalendarEvent>[];
    final localizations = MaterialLocalizations.of(context);

    DateTime combine(TimeOfDay t) =>
        DateTime(dayOnly.year, dayOnly.month, dayOnly.day, t.hour, t.minute);

    for (final reminder in reminders) {
      final hasStart = reminder.start != null;
      final hasEnd = reminder.end != null;
      final String subtitle;
      DateTime? sortKey;

      if (hasStart && hasEnd) {
        final startLabel = localizations.formatTimeOfDay(reminder.start!);
        final endLabel = localizations.formatTimeOfDay(reminder.end!);
        subtitle = '$startLabel – $endLabel';
        sortKey = combine(reminder.start!);
      } else if (hasStart) {
        subtitle = localizations.formatTimeOfDay(reminder.start!);
        sortKey = combine(reminder.start!);
      } else if (hasEnd) {
        subtitle = 'Ends ${localizations.formatTimeOfDay(reminder.end!)}';
        sortKey = combine(reminder.end!);
      } else {
        subtitle = 'All day';
        sortKey = DateTime(dayOnly.year, dayOnly.month, dayOnly.day, 0, 0);
      }

      events.add(
        _CalendarEvent(
          title: reminder.title,
          subtitle: subtitle,
          type: _CalendarEventType.reminder,
          sortTime: sortKey,
        ),
      );
    }

    DateTime? pickTaskTime(day.Task task) {
      if (task.scheduledStart != null) return task.scheduledStart;
      if (task.due != null) return task.due;
      if (task.remindAt != null) return task.remindAt;
      return null;
    }

    String taskSubtitle(day.Task task) {
      if (task.done) return 'Completed';
      if (task.scheduledStart != null) {
        return 'Scheduled ${DateFormat.jm().format(task.scheduledStart!)}';
      }
      if (task.due != null) {
        return 'Due ${DateFormat.jm().format(task.due!)}';
      }
      if (task.remindAt != null) {
        return 'Reminder ${DateFormat.jm().format(task.remindAt!)}';
      }
      return 'No time set';
    }

    for (final task in tasks) {
      events.add(
        _CalendarEvent(
          title: task.title,
          subtitle: taskSubtitle(task),
          type: _CalendarEventType.task,
          sortTime: pickTaskTime(task),
          isDone: task.done,
        ),
      );
    }

    events.sort((a, b) {
      final DateTime fallbackA =
          DateTime(dayOnly.year, dayOnly.month, dayOnly.day, 23, 59);
      final DateTime fallbackB = fallbackA;
      final ta = a.sortTime ?? fallbackA;
      final tb = b.sortTime ?? fallbackB;
      final cmp = ta.compareTo(tb);
      if (cmp != 0) return cmp;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return events;
  }

  IconData _iconForEvent(_CalendarEvent event) {
    switch (event.type) {
      case _CalendarEventType.task:
        return event.isDone ? Icons.check_circle : Icons.check_circle_outline;
      case _CalendarEventType.reminder:
      default:
        return Icons.event;
    }
  }

  Color _colorForEvent(_CalendarEvent event) {
    switch (event.type) {
      case _CalendarEventType.task:
        return event.isDone ? Colors.greenAccent : Colors.orangeAccent;
      case _CalendarEventType.reminder:
      default:
        return Colors.lightBlueAccent;
    }
  }
}

enum _CalendarEventType {
  reminder,
  task,
}

class _CalendarEvent {
  final String title;
  final String subtitle;
  final _CalendarEventType type;
  final DateTime? sortTime;
  final bool isDone;

  const _CalendarEvent({
    required this.title,
    required this.subtitle,
    required this.type,
    this.sortTime,
    this.isDone = false,
  });
}

class _WorkoutAlignmentView extends StatelessWidget {
  const _WorkoutAlignmentView();

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final profile = context.watch<FitnessProfileProvider>().profile;
    final today = AppClock.now();
    final normalized = DateTime(today.year, today.month, today.day);

    if (profile?.currentRoutineId == null) {
      return _buildMessage('Link a routine to track workout alignment.');
    }

    final routineId = profile!.currentRoutineId!;
    final routine = workoutProvider.getRoutineById(routineId);
    if (routine == null) {
      return _buildMessage('No routine found for your current profile.');
    }

    final bool isRestDay = workoutProvider.isRestDay(routineId, normalized);
    final Set<String> prescribedIds =
        WorkoutProgressService.getPrescribedWorkouts(
      routineId: routineId,
      date: normalized,
    );

    final List<_WorkoutAlignmentItem> dueWorkouts = [];
    final String ymd = DateFormat('yyyy-MM-dd').format(normalized);
    for (final wid in prescribedIds) {
      final workout = workoutProvider.getWorkoutById(wid);
      if (workout == null || workout.isLogicallyRestTemplate) continue;
      final session = SessionPersistenceService.getSessionFor(
        workoutId: wid,
        scheduledDateYmd: ymd,
      );
      dueWorkouts
          .add(_WorkoutAlignmentItem(workout: workout, session: session));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlignmentSectionHeader(
          title: 'Workout Alignment',
          subtitle:
              'AEA · double-check what training is due today (or enjoy the rest).',
        ),
        Expanded(
          child: isRestDay
              ? _buildMessage('Rest day · recharge and log recovery.')
              : (dueWorkouts.isEmpty
                  ? _buildMessage('No workouts prescribed for today.')
                  : ListView.separated(
                      itemCount: dueWorkouts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = dueWorkouts[index];
                        final workout = item.workout;
                        final session = item.session;
                        final bool inProgress =
                            session != null && session.totalCompletedSets > 0;
                        final String status = inProgress
                            ? 'Progress · ${session!.totalCompletedSets} sets logged'
                            : 'Not started';

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.fitness_center,
                                  color: Colors.lightGreenAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      workout.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: .6,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: inProgress ? 'Resume' : 'Start',
                                onPressed: () => _launchWorkout(
                                  context,
                                  routineId,
                                  workout,
                                  normalized,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildMessage(String copy) {
    return Center(
      child: Text(
        copy,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .72),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showSessionStartError(
    BuildContext context,
    SessionStartResult result,
  ) {
    final message =
        result.message ?? 'Unable to start this workout session right now.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _launchWorkout(
    BuildContext context,
    String routineId,
    Workout workout,
    DateTime scheduled,
  ) async {
    final wp = context.read<WorkoutProvider>();
    final bool alreadyActive = wp.activeDraft?.workoutId == workout.id;
    if (!alreadyActive) {
      final result = wp.startSession(
        routineId: routineId,
        workoutId: workout.id,
        source: 'alignment_flow',
        calendarDayOverride: scheduled,
      );
      if (!result.started) {
        _showSessionStartError(context, result);
        return;
      }
    }

    final args = SessionScreenArgs(
      routineId: routineId,
      workoutId: workout.id,
      source: 'alignment_flow',
      attachToRoutineId: routineId,
      scheduledDate: scheduled,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScreen(args: args),
        settings: const RouteSettings(name: 'session_from_alignment'),
      ),
    );
  }
}

class _BudgetAlignmentView extends StatelessWidget {
  const _BudgetAlignmentView();

  Budget? _selectCurrentBudget(List<Budget> budgets) {
    if (budgets.isEmpty) return null;
    return budgets.reduce(
      (a, b) => (b.updatedAt).isAfter(a.updatedAt) ? b : a,
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final delta = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: delta < 0 ? 6 : delta));
  }

  DateTime _endOfWeek(DateTime start) =>
      DateTime(start.year, start.month, start.day).add(const Duration(days: 6));

  List<_WeeklyCashflow> _buildWeeklyCashflow(Budget budget) {
    final List<_WeeklyCashflow> rows = [];
    final DateTime today = AppClock.now();
    final DateTime thisWeekStart = _startOfWeek(today);
    final int weeklyAllocation = budget.amountCentsForSpan(
      BudgetTimeSpan.weekly,
    );

    for (int i = 0; i < 7; i++) {
      final DateTime weekStart = thisWeekStart.subtract(Duration(days: 7 * i));
      final DateTime weekEnd = _endOfWeek(weekStart);
      final int recurringCents = budget.recurrings.fold(
        0,
        (sum, expense) =>
            sum + expenseAmountInWindow(expense, weekStart, weekEnd),
      );
      rows.add(
        _WeeklyCashflow(
          start: weekStart,
          end: weekEnd,
          inflowCents: weeklyAllocation,
          outflowCents: recurringCents,
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();
    final budgets = provider.budgets;
    final Budget? budget = _selectCurrentBudget(budgets);

    final NumberFormat currencyFmt = NumberFormat.simpleCurrency();

    final rows =
        budget == null ? <_WeeklyCashflow>[] : _buildWeeklyCashflow(budget);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AlignmentSectionHeader(
          title: 'Budget Alignment',
          subtitle: budget == null
              ? 'AEA · add a budget to start tracking cash flow.'
              : 'AEA · ${budget.title} · last 7 weeks of projected cash flow.',
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: budget == null
                ? const Center(
                    child: Text(
                      'No budgets yet. Create one to see cash flow trends.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly allocation: ${currencyFmt.format(budget.amountCentsForSpan(BudgetTimeSpan.weekly) / 100)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comparing allocation vs. scheduled recurring spend.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = rows[index];
                            final bool isCurrentWeek = index == 0;
                            if (isCurrentWeek) {
                              return Column(
                                children: [
                                  _WeeklyCashflowTile(
                                    data: data,
                                    currencyFmt: currencyFmt,
                                    highlight: true,
                                  ),
                                  const SizedBox(height: 8),
                                  const _LogTransactionTile(),
                                ],
                              );
                            }
                            return _WeeklyCashflowTile(
                              data: data,
                              currencyFmt: currencyFmt,
                              highlight: false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyCashflow {
  const _WeeklyCashflow({
    required this.start,
    required this.end,
    required this.inflowCents,
    required this.outflowCents,
  });

  final DateTime start;
  final DateTime end;
  final int inflowCents;
  final int outflowCents;

  int get netCents => inflowCents - outflowCents;
}

class _WeeklyCashflowTile extends StatelessWidget {
  const _WeeklyCashflowTile({
    required this.data,
    required this.currencyFmt,
    required this.highlight,
  });

  final _WeeklyCashflow data;
  final NumberFormat currencyFmt;
  final bool highlight;

  double get _spendRatio {
    if (data.inflowCents <= 0) return 0;
    return data.outflowCents / data.inflowCents.clamp(0.0, 1.5);
  }

  @override
  Widget build(BuildContext context) {
    final String label = highlight
        ? 'This week'
        : '${DateFormat.MMMd().format(data.start)} – ${DateFormat.MMMd().format(data.end)}';
    final Color netColor =
        data.netCents >= 0 ? Colors.greenAccent : Colors.redAccent;
    final String netLabel =
        '${data.netCents >= 0 ? '+' : '-'}${currencyFmt.format(data.netCents.abs() / 100)}';
    final progressValue = _spendRatio.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: highlight ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                netLabel,
                style: TextStyle(
                  color: netColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                progressValue <= 1.0
                    ? Colors.greenAccent.withValues(alpha: 0.8)
                    : Colors.redAccent.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Inflow: ${currencyFmt.format(data.inflowCents / 100)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                'Outflow: ${currencyFmt.format(data.outflowCents / 100)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogTransactionTile extends StatelessWidget {
  const _LogTransactionTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle_outline,
            color: Colors.white.withValues(alpha: 0.9),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Log transaction',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlignmentCompleteView extends StatelessWidget {
  const _AlignmentCompleteView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.greenAccent,
            size: 54,
          ),
          const SizedBox(height: 16),
          const Text(
            'Thank you for checking in!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Daily alignment status updated.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutAlignmentItem {
  final Workout workout;
  final WorkoutSessionState? session;

  const _WorkoutAlignmentItem({
    required this.workout,
    this.session,
  });
}

class _GlancePillList extends StatelessWidget {
  const _GlancePillList({required this.items});

  final List<_GlanceItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Text(
          'No items for today',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .7),
            fontSize: 12.5,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final item in items) ...[
          _GlancePill(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _GlanceItem {
  final String label;
  final int value;
  final int? delta;

  const _GlanceItem({
    required this.label,
    required this.value,
    this.delta,
  });

  _GlanceItem copyWith({int? value, int? delta}) {
    return _GlanceItem(
      label: label,
      value: value ?? this.value,
      delta: delta ?? this.delta,
    );
  }
}

class _GlancePill extends StatelessWidget {
  final _GlanceItem item;

  const _GlancePill({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: .14),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.delta != null && item.delta != 0) ...[
                Text(
                  item.delta! > 0 ? '+${item.delta}' : item.delta!.toString(),
                  style: TextStyle(
                    color:
                        item.delta! > 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                item.value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
