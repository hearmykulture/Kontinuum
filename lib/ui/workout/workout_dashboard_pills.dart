part of 'workout_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Swipe background (delete) — visual only for now
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      decoration: BoxDecoration(
        color: const Color(0x33FF3B30),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 14),
      child:
          const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline workout pills with actions + schedule strip + expandable details
// ─────────────────────────────────────────────────────────────────────────────
class _WorkoutListPill extends StatefulWidget {
  const _WorkoutListPill({
    required this.label,
    required this.onTap,
    this.isPrimary = false,

    // Optional: actions shown for real workouts
    this.workoutId,
    this.onStart,
    this.onInfo,
    this.onEdit,

    // Collapsed context data (optional; hidden if null)
    this.focusLabel,
    this.targetMinutes,
    this.blockCount,
    this.exerciseCount,
    this.timesCompleted,
    this.onViewTimeline,

    // Optional: schedule toggles (only when workoutId != null)
    this.daySelections,
    this.onToggleDay,
    this.disabledDays,
    this.scheduleMode = RepetitionMode.weekly,
    this.routineRestSchedule,
    this.intervalSummaryLabel,
    this.intervalEditable = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  // Actions
  final String? workoutId;
  final VoidCallback? onStart;
  final VoidCallback? onInfo;
  final VoidCallback? onEdit;

  // Collapsed context data
  final String? focusLabel;
  final int? targetMinutes;
  final int? blockCount;
  final int? exerciseCount;
  final int? timesCompleted;
  final VoidCallback? onViewTimeline;

  // Day toggles
  final List<bool>? daySelections; // length 7
  final void Function(int index)? onToggleDay;
  final List<bool>? disabledDays;
  final RepetitionMode scheduleMode;
  final RestSchedule? routineRestSchedule;
  final String? intervalSummaryLabel;
  final bool intervalEditable;

  @override
  State<_WorkoutListPill> createState() => _WorkoutListPillState();
}

enum _RepeatMode { weekly, interval }

enum _RepeatUnit { days, weeks, months, years }

extension _RepeatUnitLabel on _RepeatUnit {
  String get label {
    switch (this) {
      case _RepeatUnit.days:
        return 'days';
      case _RepeatUnit.weeks:
        return 'weeks';
      case _RepeatUnit.months:
        return 'months';
      case _RepeatUnit.years:
        return 'years';
    }
  }
}

class _WorkoutListPillState extends State<_WorkoutListPill>
    with SingleTickerProviderStateMixin {
  static const _basePill = Color(0xFF161F2A);
  static const _bodyHeight = 48.0;
  static const _scheduleHeight = 30.0;
  static const _thinHandleHeight = 22.0;
  static const _stripeBg = Color(0x29000000); // slightly darker stripe

  bool _expanded = false;

  bool get _isWeeklyMode =>
      widget.scheduleMode == RepetitionMode.weekly;
  bool get _isIntervalMode =>
      widget.scheduleMode == RepetitionMode.interval;
  bool get _canEditInterval =>
      _isIntervalMode && widget.intervalEditable;
  _RepeatMode get _repeatMode =>
      _isWeeklyMode ? _RepeatMode.weekly : _RepeatMode.interval;

  // "Every X <unit>"
  int _everyValue = 2;
  _RepeatUnit _everyUnit = _RepeatUnit.days;

  // ── Schedule readers that handle Map or typed Hive objects ────────────────
  String? _sWid(dynamic s) {
    if (s == null) return null;

    // Map first (avoid `.workoutId` on _Map)
    if (s is Map) {
      final v = s['workoutId'] ?? s['wid'] ?? s['workout_id'];
      if (v is String && v.isNotEmpty) return v;
      return null;
    }

    try {
      final v = (s as dynamic).workoutId;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  RepetitionMode _sMode(dynamic s) {
    // Map first
    if (s is Map) {
      final m = s['mode'];
      if (m is RepetitionMode) return m;
      if (m is String) {
        return (m.toLowerCase() == 'interval')
            ? RepetitionMode.interval
            : RepetitionMode.weekly;
      }
      if (m is int) {
        // 0=weekly, 1=interval (best guess)
        return m == 1 ? RepetitionMode.interval : RepetitionMode.weekly;
      }
      return RepetitionMode.weekly;
    }

    // Typed object
    try {
      final m = (s as dynamic).mode;
      if (m is RepetitionMode) return m;
    } catch (_) {}
    return RepetitionMode.weekly;
  }

  List<bool> _sWeeklyDays(dynamic s) {
    // Map first
    if (s is Map) {
      final w = s['weeklyDays'];
      if (w is List) {
        return List<bool>.generate(
          7,
          (i) => i < w.length && (w[i] == true),
        );
      }
      return List<bool>.filled(7, false);
    }

    // Typed object
    try {
      final w = (s as dynamic).weeklyDays;
      if (w is List<bool> && w.length >= 7) return List<bool>.from(w);
    } catch (_) {}
    return List<bool>.filled(7, false);
  }

  int _sIntervalValue(dynamic s) {
    // Map first
    if (s is Map) {
      final v = s['intervalValue'];
      if (v is int && v > 0) return v;
      if (v is num && v > 0) return v.toInt();
      return 2;
    }

    // Typed
    try {
      final v = (s as dynamic).intervalValue;
      if (v is int && v > 0) return v;
    } catch (_) {}
    return 2;
  }

  RepetitionUnit _sIntervalUnit(dynamic s) {
    // Map first
    if (s is Map) {
      final u = s['intervalUnit'];
      if (u is RepetitionUnit) return u;
      if (u is String) {
        switch (u.toLowerCase()) {
          case 'weeks':
            return RepetitionUnit.weeks;
          case 'months':
            return RepetitionUnit.months;
          case 'years':
            return RepetitionUnit.years;
          default:
            return RepetitionUnit.days;
        }
      }
      if (u is int) {
        // 0=days,1=weeks,2=months,3=years (best guess)
        switch (u) {
          case 1:
            return RepetitionUnit.weeks;
          case 2:
            return RepetitionUnit.months;
          case 3:
            return RepetitionUnit.years;
          default:
            return RepetitionUnit.days;
        }
      }
      return RepetitionUnit.days;
    }

    // Typed
    try {
      final u = (s as dynamic).intervalUnit;
      if (u is RepetitionUnit) return u;
    } catch (_) {}
    return RepetitionUnit.days;
  }

  _RepeatUnit _mapRepetitionUnit(RepetitionUnit unit) {
    switch (unit) {
      case RepetitionUnit.days:
        return _RepeatUnit.days;
      case RepetitionUnit.weeks:
        return _RepeatUnit.weeks;
      case RepetitionUnit.months:
        return _RepeatUnit.months;
      case RepetitionUnit.years:
        return _RepeatUnit.years;
    }
  }

  RepetitionUnit _mapToRepetitionUnit(_RepeatUnit unit) {
    switch (unit) {
      case _RepeatUnit.days:
        return RepetitionUnit.days;
      case _RepeatUnit.weeks:
        return RepetitionUnit.weeks;
      case _RepeatUnit.months:
        return RepetitionUnit.months;
      case _RepeatUnit.years:
        return RepetitionUnit.years;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  @override
  void didUpdateWidget(covariant _WorkoutListPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleMode != widget.scheduleMode) {
      _loadSchedule();
      return;
    }
    if (_isIntervalMode &&
        (oldWidget.routineRestSchedule?.intervalValue !=
                widget.routineRestSchedule?.intervalValue ||
            oldWidget.routineRestSchedule?.intervalUnit !=
                widget.routineRestSchedule?.intervalUnit)) {
      _syncIntervalFromRoutine();
    }
  }

  void _loadSchedule() {
    if (widget.workoutId == null) return;

    try {
      final schedulesBox = WorkoutBoxes.schedulesBox;

      dynamic existing;
      for (final s in schedulesBox.values) {
        if (_sWid(s) == widget.workoutId) {
          existing = s;
          break;
        }
      }

      if (!mounted) return;

      if (existing == null) {
        // No schedule yet — keep defaults, leave daySelections untouched.
        return;
      }

      final mode = _sMode(existing);
      final weeklyDays = _sWeeklyDays(existing);
      final intervalValue = _sIntervalValue(existing);
      final intervalUnit = _sIntervalUnit(existing);

      setState(() {
        _everyValue = intervalValue;
        _everyUnit = _mapRepetitionUnit(intervalUnit);

        if (widget.daySelections != null &&
            widget.scheduleMode == RepetitionMode.weekly &&
            weeklyDays.length >= 7) {
          for (int i = 0; i < 7; i++) {
            widget.daySelections![i] = weeklyDays[i];
          }
        }
      });

      _syncIntervalFromRoutine();
    } catch (_) {
      // ignore — fall back to defaults
    }
  }

  void _syncIntervalFromRoutine() {
    if (!_isIntervalMode) return;
    final rest = widget.routineRestSchedule;
    if (rest == null) return;
    final int value = rest.intervalValue <= 0 ? 1 : rest.intervalValue;
    final _RepeatUnit unit = _mapRepetitionUnit(rest.intervalUnit);
    if (_everyValue == value && _everyUnit == unit) return;
    if (!mounted) return;
    setState(() {
      _everyValue = value;
      _everyUnit = unit;
    });
  }

  void _saveSchedule() {
    if (widget.workoutId == null) return;

    try {
      final schedulesBox = WorkoutBoxes.schedulesBox;

      dynamic existingKey;
      for (final key in schedulesBox.keys) {
        final s = schedulesBox.get(key);
        if (_sWid(s) == widget.workoutId) {
          existingKey = key;
          break;
        }
      }

      final schedule = WorkoutSchedule(
        workoutId: widget.workoutId!,
        mode: widget.scheduleMode,
        weeklyDays: widget.daySelections ?? List<bool>.filled(7, false),
        intervalValue: _everyValue,
        intervalUnit: _mapToRepetitionUnit(_everyUnit),
        intervalStartDateIso: DateTime.now().toIso8601String(),
      );

      if (existingKey != null) {
        schedulesBox.put(existingKey, schedule);
      } else {
        schedulesBox.add(schedule);
      }
    } catch (e) {
      _wdLog('Error saving workout schedule: $e');
    }
  }

  void _incEvery() {
    if (!_canEditInterval) return;
    setState(() => _everyValue = (_everyValue + 1).clamp(1, 60));
    _saveSchedule();
  }

  void _decEvery() {
    if (!_canEditInterval) return;
    setState(() => _everyValue = (_everyValue - 1).clamp(1, 60));
    _saveSchedule();
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = _basePill.withValues(alpha: 0.55);
    final Color borderColor = widget.isPrimary
        ? _WorkoutPalette.accent.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.12);

    final bool showActions = !widget.isPrimary && widget.workoutId != null;
    final bool hasScheduleInputs = showActions &&
        widget.daySelections != null &&
        widget.onToggleDay != null;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: borderColor,
              width: widget.isPrimary ? 1.2 : 0.9,
            ),
          ),
          color: baseColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top body row (label + actions)
            InkWell(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(hasScheduleInputs ? 0 : 16),
                bottomRight: Radius.circular(hasScheduleInputs ? 0 : 16),
              ),
              onTap: widget.onTap,
              splashColor: Colors.white.withValues(alpha: .08),
              highlightColor: Colors.white.withValues(alpha: .04),
              child: SizedBox(
                height: _bodyHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Label + optional interval badge
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (_isIntervalMode &&
                                widget.intervalSummaryLabel != null &&
                                widget.intervalSummaryLabel!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _IntervalBadge(
                                label: widget.intervalSummaryLabel!,
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (widget.isPrimary) const SizedBox(width: 6),

                      // Actions (compact)
                      if (showActions) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _IconChip(
                              icon: Icons.play_arrow_rounded,
                              tooltip: 'Start',
                              onTap: widget.onStart,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            _IconChip(
                              icon: Icons.info_outline_rounded,
                              tooltip: 'Timeline',
                              onTap: widget.onInfo,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            _IconChip(
                              icon: Icons.edit_rounded,
                              tooltip: 'Edit',
                              onTap: widget.onEdit,
                              size: 18,
                            ),
                          ],
                        ),
                      ],

                      if (widget.isPrimary)
                        const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.white70,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (hasScheduleInputs) ...[
              // Divider under the body row
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),

              // Details / chips directly under the divider
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? _ExpandedDetails(
                        focusLabel: widget.focusLabel,
                        targetMinutes: widget.targetMinutes,
                        blockCount: widget.blockCount,
                        exerciseCount: widget.exerciseCount,
                        timesCompleted: widget.timesCompleted,
                      )
                    : _CollapsedContextBar(
                        focusLabel: widget.focusLabel,
                        targetMinutes: widget.targetMinutes,
                        blockCount: widget.blockCount,
                        exerciseCount: widget.exerciseCount,
                        timesCompleted: widget.timesCompleted,
                      ),
              ),

              // View timeline — only when expanded, and above the 7-day toggles
              if (_expanded && widget.onViewTimeline != null)
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _stripeBg,
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _timelineAction(widget.onViewTimeline!),
                    ],
                  ),
                ),

              // Schedule section: weekly row (7 day toggles) + interval row
              _ScheduleSection(
                mode: _repeatMode,
                scheduleHeight: _scheduleHeight,
                weeklyRow: _WeeklyRow(
                  expanded: _expanded,
                  active: _isWeeklyMode,
                  selections: widget.daySelections!,
                  disabledDays: widget.disabledDays,
                  onToggleDay: (i) {
                    widget.onToggleDay!(i);
                    _saveSchedule();
                  },
                ),
                intervalRow: _IntervalRow(
                  expanded: _expanded,
                  active: _isIntervalMode,
                  value: _everyValue,
                  unit: _everyUnit,
                  editable: _canEditInterval,
                  onInc: _incEvery,
                  onDec: _decEvery,
                  onUnitChanged: (u) {
                    if (!_canEditInterval) return;
                    setState(() => _everyUnit = u);
                    _saveSchedule();
                  },
                ),
              ),

              // ── dropdown handle BELOW the schedule (under the 7-day toggles) ──
              _ExpandHandle(
                height: _thinHandleHeight,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ] else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  // “Details” block used only when expanded.
  Widget _ExpandedDetails({
    String? focusLabel,
    int? targetMinutes,
    int? blockCount,
    int? exerciseCount,
    int? timesCompleted,
  }) {
    final chips = <Widget>[];

    if (focusLabel != null && focusLabel.trim().isNotEmpty) {
      chips.add(_chip('Focus: $focusLabel'));
    }
    if (targetMinutes != null && targetMinutes > 0) {
      chips.add(_chip('$targetMinutes min'));
    }
    if (blockCount != null) {
      chips.add(_chip('Blocks: $blockCount'));
    }
    if (exerciseCount != null) {
      chips.add(_chip('Exercises: $exerciseCount'));
    }
    if (timesCompleted != null) {
      chips.add(_chip('Completed: ${timesCompleted}×'));
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _stripeBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFFB9C2CC),
          fontSize: 12.5,
          height: 1.32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Details',
              style: TextStyle(
                color: Color(0xFFE8EDF2),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            if (chips.isEmpty)
              const Text(
                'Wire expectations here later: notes, target duration, sets, last session link, etc.',
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips,
              ),
          ],
        ),
      ),
    );
  }

  // Collapsed one-line context bar (chips only — no timeline button here)
  Widget _CollapsedContextBar({
    String? focusLabel,
    int? targetMinutes,
    int? blockCount,
    int? exerciseCount,
    int? timesCompleted,
  }) {
    final pills = <Widget>[];

    if (focusLabel != null && focusLabel.trim().isNotEmpty) {
      pills.add(_contextChip('Focus: $focusLabel'));
    }
    if (targetMinutes != null && targetMinutes > 0) {
      pills.add(_contextChip('$targetMinutes min'));
    }
    if (blockCount != null) {
      pills.add(_contextChip('Blocks: $blockCount'));
    }
    if (exerciseCount != null) {
      pills.add(_contextChip('Exercises: $exerciseCount'));
    }
    if (timesCompleted != null) {
      pills.add(_contextChip('Completed: ${timesCompleted}×'));
    }

    if (pills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: _stripeBg),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: pills,
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A333D).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF2A333D).withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFB9C2CC), fontSize: 11.5),
      ),
    );
  }

  Widget _timelineAction(VoidCallback onTap) {
    final c = _WorkoutPalette.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.55), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline_rounded, size: 16, color: c),
            const SizedBox(width: 6),
            Text(
              'View timeline',
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A333D).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF2A333D).withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFB9C2CC), fontSize: 11.5),
      ),
    );
  }
}

// Schedule section that handles collapsed/expanded layout + dividers.
class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.mode,
    required this.scheduleHeight,
    required this.weeklyRow,
    required this.intervalRow,
  });

  final _RepeatMode mode;
  final double scheduleHeight;
  final Widget weeklyRow;
  final Widget intervalRow;

  static const _stripeBg = Color(0x29000000);

  @override
  Widget build(BuildContext context) {
    final Widget child =
        mode == _RepeatMode.weekly ? weeklyRow : intervalRow;

    return Container(
      height: scheduleHeight,
      decoration: BoxDecoration(
        color: _stripeBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }
}

// Blue dot (animated) shown only when expanded (parent controls visibility).
class _ModeDot extends StatelessWidget {
  const _ModeDot({required this.active, required this.visible});

  final bool active;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final Color on = _WorkoutPalette.accent;
    final Color off = Colors.white.withValues(alpha: 0.25);

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: active ? on : off,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

// Weekly row with animated greying when inactive.
class _WeeklyRow extends StatelessWidget {
  const _WeeklyRow({
    required this.expanded,
    required this.active,
    required this.selections,
    required this.onToggleDay,
    this.disabledDays,
  });

  final bool expanded;
  final bool active;
  final List<bool> selections;
  final void Function(int) onToggleDay;
  final List<bool>? disabledDays;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeDot(active: active, visible: expanded),
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            opacity: active ? 1.0 : 0.6,
            child: _DayToggleRow(
              selections: selections,
              onToggle: onToggleDay,
              enabled: active,
              disabledDays: disabledDays,
            ),
          ),
        ),
      ],
    );
  }
}

// Interval row ("Every X <unit>") centered, with animated text when inactive.
class _IntervalRow extends StatelessWidget {
  const _IntervalRow({
    required this.expanded,
    required this.active,
    required this.value,
    required this.unit,
    required this.editable,
    required this.onInc,
    required this.onDec,
    required this.onUnitChanged,
  });

  final bool expanded;
  final bool active;
  final int value;
  final _RepeatUnit unit;
  final bool editable;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final ValueChanged<_RepeatUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final textColor =
        active ? Colors.white : Colors.white.withValues(alpha: 0.65);
    final bool canEdit = active && editable;

    return Row(
      children: [
        _ModeDot(active: active, visible: expanded),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Every"
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                  ),
                  child: const Text('Every'),
                ),

                const SizedBox(width: 12),

                // [-]  X  [+]
                _TinyIconButton(
                  icon: Icons.remove_rounded,
                  onTap: canEdit ? onDec : null,
                ),
                SizedBox(
                  width: 32,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                      child: Text('$value'),
                    ),
                  ),
                ),
                _TinyIconButton(
                  icon: Icons.add_rounded,
                  onTap: canEdit ? onInc : null,
                ),

                const SizedBox(width: 6),

                _UnitDropdownChip(
                  label: unit.label,
                  enabled: canEdit,
                  onSelected: (u) {
                    if (canEdit) onUnitChanged(u);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IntervalBadge extends StatelessWidget {
  const _IntervalBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = _WorkoutPalette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c.withValues(alpha: 0.95),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 20,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: size + 3,
        child: Icon(
          icon,
          size: size,
          color: Colors.white.withValues(alpha: onTap == null ? 0.35 : 0.9),
        ),
      ),
    );
  }
}

class _DayToggleRow extends StatelessWidget {
  const _DayToggleRow({
    required this.selections,
    required this.onToggle,
    required this.enabled,
    this.disabledDays,
  });

  final List<bool> selections; // len 7
  final void Function(int index) onToggle;
  final bool enabled;
  final List<bool>? disabledDays;

  static const List<String> _labels = <String>[
    'M',
    'T',
    'W',
    'Th',
    'F',
    'S',
    'Su',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List<Widget>.generate(7, (i) {
        final selected = i < selections.length ? selections[i] : false;
        final bool restDisabled =
            disabledDays != null && i < disabledDays!.length
                ? disabledDays![i]
                : false;
        final bool dayEnabled = enabled && !restDisabled;
        return _DayDot(
          label: _labels[i],
          selected: selected,
          enabled: dayEnabled,
          disabled: restDisabled,
          onTap: dayEnabled ? () => onToggle(i) : null,
        );
      }),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color on = _WorkoutPalette.accent;
    final Color offBorder = Colors.white.withValues(alpha: 0.20);
    final Color offText = Colors.white.withValues(alpha: 0.70);

    final Color borderColor = disabled
        ? offBorder.withValues(alpha: 0.25)
        : selected
            ? on.withValues(alpha: enabled ? 0.85 : 0.55)
            : offBorder.withValues(alpha: enabled ? 1.0 : 0.5);

    final Color fillColor = disabled
        ? Colors.white.withValues(alpha: 0.04)
        : selected
            ? on.withValues(alpha: enabled ? 0.18 : 0.10)
            : Colors.transparent;

    final Color textColor = disabled
        ? offText.withValues(alpha: 0.35)
        : selected
            ? (enabled ? on : on.withValues(alpha: 0.7))
            : (enabled ? offText : offText.withValues(alpha: 0.55));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.15,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// Thin double-line handle used to expand details.
class _ExpandHandle extends StatelessWidget {
  const _ExpandHandle({required this.onTap, this.height = 22});

  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x29000000),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _line(24),
                const SizedBox(height: 3),
                _line(18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(double width) {
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: const Color(0xFF2A333D).withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// Unit dropdown chip for the interval row.
class _UnitDropdownChip extends StatelessWidget {
  const _UnitDropdownChip({
    required this.label,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final bool enabled;
  final ValueChanged<_RepeatUnit> onSelected;

  @override
  Widget build(BuildContext context) {
    final Color text =
        enabled ? Colors.white : Colors.white.withValues(alpha: 0.65);

    return PopupMenuButton<_RepeatUnit>(
      tooltip: 'Interval unit',
      onSelected: onSelected,
      enabled: enabled,
      elevation: 4,
      color: const Color(0xFF12181F),
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: _RepeatUnit.days, child: Text('days')),
        PopupMenuItem(value: _RepeatUnit.weeks, child: Text('weeks')),
        PopupMenuItem(value: _RepeatUnit.months, child: Text('months')),
        PopupMenuItem(value: _RepeatUnit.years, child: Text('years')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: 0.2,
            ),
            child: Text(label),
          ),
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 16, color: text),
        ],
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rest-day palette + badge shared by TODAY widgets
// ─────────────────────────────────────────────────────────────────────────────
class _RestDayPalette {
  // Light blue circle + supporting tones
  static const Color accent = Color(0xFF7DD3FC); // light aqua / cyan
  static const Color accentSoft = Color(0x337DD3FC);
  static const Color border = Color(0xFF38BDF8); // stronger edge
  static const Color background = Color(0xFF0B1720);
  static const Color text = Color(0xFFE2F3FF);
}

class _RestDayBadge extends StatelessWidget {
  const _RestDayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _RestDayPalette.accentSoft,
        border: Border.all(
          color: _RestDayPalette.accent,
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.bedtime_rounded,
        size: 18,
        color: _RestDayPalette.accent,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TODAY base pill (shared layout for workout / log / rest-day)
// ─────────────────────────────────────────────────────────────────────────────
class _TodayBasePill extends StatelessWidget {
  const _TodayBasePill({
    required this.label,
    required this.leading,
    required this.actions,
    required this.borderColor,
    required this.backgroundColor,
    required this.onTap,
    this.opacity = 1.0,
    this.labelColor = Colors.white,
  });

  final String label;
  final Widget leading;
  final List<Widget> actions;
  final Color borderColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final double opacity;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: 1.5),
            ),
            color: backgroundColor,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: .08),
            highlightColor: Colors.white.withValues(alpha: .04),
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today workout pill - shows prescribed workouts with green border
// ─────────────────────────────────────────────────────────────────────────────
class _TodayWorkoutPill extends StatelessWidget {
  const _TodayWorkoutPill({
    required this.label,
    required this.completionPercent,
    required this.onStart,
    required this.onInfo,
  });

  final String label;
  final int completionPercent;
  final VoidCallback onStart;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = completionPercent >= 100;

    const Color greenBorder = Color(0xFF4ADE80); // Tailwind green-400
    const Color greyBorder = Color(0xFF6B7280); // Tailwind gray-500
    final Color baseColor = const Color(0xFF161F2A).withValues(alpha: 0.55);
    final Color greyBaseColor = const Color(0xFF161F2A).withValues(alpha: 0.25);

    // Card border/background still grey out when completed...
    final Color borderColor = isCompleted ? greyBorder : greenBorder;
    final Color backgroundColor = isCompleted ? greyBaseColor : baseColor;

    // ...but the completion badge/text stays green in both states.
    final Color percentColor = greenBorder;

    return _TodayBasePill(
      label: label,
      onTap: onStart,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      opacity: isCompleted ? 0.6 : 1.0,
      labelColor: isCompleted ? Colors.white60 : Colors.white,
      leading: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: percentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: percentColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Text(
          '$completionPercent%',
          style: TextStyle(
            color: percentColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      actions: [
        _IconChip(
          icon: Icons.play_arrow_rounded,
          tooltip: 'Start',
          onTap: onStart,
          size: 20,
        ),
        const SizedBox(width: 10),
        _IconChip(
          icon: Icons.info_outline_rounded,
          tooltip: 'Overview',
          onTap: onInfo,
          size: 20,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today REST-DAY pill – replaces workout cards on scheduled rest days
// ─────────────────────────────────────────────────────────────────────────────
class _TodayRestDayPill extends StatelessWidget {
  const _TodayRestDayPill({
    required this.onTap,
    this.message =
        'Scheduled rest day – recovery counts as progress. Tap for guidance.',
  });

  /// Tapping can open an education sheet / “what to do on rest days” page.
  final VoidCallback onTap;

  /// Single-line supportive copy surfaced on the card.
  final String message;

  @override
  Widget build(BuildContext context) {
    return _TodayBasePill(
      label: message,
      onTap: onTap,
      borderColor: _RestDayPalette.border,
      backgroundColor: _RestDayPalette.background.withValues(alpha: 0.95),
      labelColor: _RestDayPalette.text,
      leading: const _RestDayBadge(), // light-blue circle = “complete (rest)”
      actions: [
        _IconChip(
          icon: Icons.self_improvement_rounded,
          tooltip: 'Rest-day ideas',
          onTap: onTap,
          size: 20,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today "Log progress" pill – DUE / DONE + pencil sheet
// Also supports scheduled rest days (treated as “complete” with blue circle).
// ─────────────────────────────────────────────────────────────────────────────
class _TodayLogProgressPill extends StatelessWidget {
  const _TodayLogProgressPill({
    required this.isDone,
    required this.onTap,

    /// When true, this day is a scheduled REST day.
    /// The pill uses the rest-day palette + circle and is treated as complete.
    this.isRestDay = false,
  });

  final bool isDone;
  final bool isRestDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color greenBorder = Color(0xFF4ADE80);
    const Color greyBorder = Color(0xFF6B7280);
    final Color baseColor = const Color(0xFF161F2A).withValues(alpha: 0.55);
    final Color greyBaseColor = const Color(0xFF161F2A).withValues(alpha: 0.25);

    // “Complete” semantics: training completion OR scheduled rest.
    final bool effectiveDone = isDone || isRestDay;

    late final Color borderColor;
    late final Color backgroundColor;
    late final double opacity;
    late final Color labelColor;
    late final Widget leading;
    late final String labelText;

    if (isRestDay) {
      // Rest-day: use the light-blue circle + supportive copy.
      borderColor = _RestDayPalette.border;
      backgroundColor = _RestDayPalette.background.withValues(alpha: 0.95);
      opacity = 1.0; // rest should feel affirming, not greyed out
      labelColor = _RestDayPalette.text;
      labelText = 'Rest-day check-in';
      leading = const _RestDayBadge();
    } else {
      // Regular training day DUE / DONE logic.
      borderColor = effectiveDone ? greyBorder : greenBorder;
      backgroundColor = effectiveDone ? greyBaseColor : baseColor;
      opacity = effectiveDone ? 0.6 : 1.0;
      labelColor = effectiveDone ? Colors.white60 : Colors.white;
      labelText = 'Log progress';

      final Color badgeColor = greenBorder;
      final String statusText = effectiveDone ? 'DONE' : 'DUE';

      leading = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            color: badgeColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    return _TodayBasePill(
      label: labelText,
      onTap: onTap,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      opacity: opacity,
      labelColor: labelColor,
      leading: leading,
      actions: [
        _IconChip(
          icon: Icons.edit_rounded,
          tooltip: isRestDay
              ? 'Reflect on today’s recovery'
              : 'Log today’s progress',
          onTap: onTap,
          size: 20,
        ),
      ],
    );
  }
}
