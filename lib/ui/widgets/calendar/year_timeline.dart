import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

import 'package:kontinuum/ui/screens/day_detail_page.dart' as day;

/* --- Shared spacing so reminders and tasks align exactly --- */
const double _kAccentW = 12; // width of the accent slot (pill/checkbox)
const double _kAccentH = 22; // height of the accent slot
const double _kTextGap = 10; // gap between accent and text

/// Public YearTimeline widget (previously _YearTimeline).
class YearTimeline extends StatefulWidget {
  const YearTimeline({
    super.key,
    required this.year,
    required this.selected,
    required this.accent,
    required this.sidebarW,
    required this.rowMinH,
    required this.hPad,
    required this.railColor,
    required this.laneColor,
    required this.onPick,
    required this.onMonthOverlay, // (current, next, t)
    required this.railProgress, // 0..1 amount faded (1 = fully faded)
  });

  final int year;
  final DateTime selected;
  final Color accent;
  final double sidebarW;
  final double rowMinH;
  final double hPad;
  final Color railColor;
  final Color laneColor;
  final ValueChanged<DateTime> onPick;
  final void Function(String currentLabel, String nextLabel, double t)
  onMonthOverlay;
  final double railProgress;

  @override
  YearTimelineState createState() => YearTimelineState();
}

class YearTimelineState extends State<YearTimeline> {
  static const _muted = Color(0xB3FFFFFF);
  static const _line = Color(0x1AFFFFFF);
  static const double _alignSelected = 0.48;

  // Reuse date formatter (locale-aware)
  static final DateFormat _fmtJM = DateFormat.jm();

  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _dayKeys = <int, GlobalKey>{};
  final Map<int, GlobalKey> _monthKeys = <int, GlobalKey>{};
  final GlobalKey _listKey = GlobalKey();

  late DateTime _startOfYear;
  late int _totalDays;
  late final DateTime _today; // computed once per session
  bool _didInitialScroll = false;

  // Throttle overlay computation to once-per-frame.
  bool _overlayScheduled = false;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _id(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  String _spaced(String s) => s.split('').join(' ');
  String _overlayLabelFor(DateTime d) {
    final mon = DateFormat.MMM().format(d).toUpperCase();
    final yr = DateFormat.y().format(d);
    return '${_spaced(mon)} ${_spaced(yr)}';
  }

  /// SAME palette + hashing as ExtendedSidebarPanel so colors match exactly.
  Color _markerFor(String seed) {
    const palette = <Color>[
      Color(0xFFB672FF), // purple
      Color(0xFFFF5BAD), // magenta
      Color(0xFF47C7FF), // blue
      Color(0xFFB24D4D), // brick
      Color(0xFF6E6E6E), // gray
    ];
    final idx = (seed.hashCode & 0x7fffffff) % palette.length;
    return palette[idx];
  }

  @override
  void initState() {
    super.initState();
    _startOfYear = DateTime(widget.year, 1, 1);
    final end = DateTime(widget.year + 1, 1, 0);
    _totalDays = end.difference(_startOfYear).inDays + 1;

    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    _scroll.addListener(_handleScroll);
    _scheduleInitialScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitOverlay());
  }

  @override
  void didUpdateWidget(covariant YearTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year) {
      _startOfYear = DateTime(widget.year, 1, 1);
      final end = DateTime(widget.year + 1, 1, 0);
      _totalDays = end.difference(_startOfYear).inDays + 1;
      _dayKeys.clear();
      _monthKeys.clear();
      _didInitialScroll = false;
    }
    if (!_sameDay(oldWidget.selected, widget.selected)) {
      _didInitialScroll = false;
      _scheduleInitialScroll();
    }
  }

  void _scheduleInitialScroll() {
    if (_didInitialScroll) return;
    _didInitialScroll = true;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      await scrollToDate(widget.selected);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_overlayScheduled) return;
    _overlayScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayScheduled = false;
      if (mounted) _emitOverlay();
    });
  }

  void _emitOverlay() {
    final listCtx = _listKey.currentContext;
    if (listCtx == null) return;
    final listBox = listCtx.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.attached) return;

    final listTop = listBox.localToGlobal(Offset.zero).dy;
    final listH = listBox.size.height;
    final centerY = listTop + listH / 2;

    final positions = <int, double>{}; // month -> y
    for (int m = 1; m <= 12; m++) {
      final k = _monthKeys[m];
      final ctx = k?.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        positions[m] = box.localToGlobal(Offset.zero).dy;
      }
    }
    if (positions.isEmpty) return;

    final months = positions.keys.toList()..sort();
    int prevIdx = 0;
    for (int i = 0; i < months.length; i++) {
      final y = positions[months[i]]!;
      if (y <= centerY) {
        prevIdx = i;
      } else {
        break;
      }
    }
    final int nextIdx = (prevIdx < months.length - 1) ? prevIdx + 1 : prevIdx;

    final prevMonth = months[prevIdx];
    final nextMonth = months[nextIdx];

    final yPrev = positions[prevMonth]!;
    final yNext = positions[nextMonth]!;

    double t = 0.0;
    final dy = yNext - yPrev;
    if (dy.abs() > 0.001) t = ((centerY - yPrev) / dy).clamp(0.0, 1.0);

    final curLabel = _overlayLabelFor(DateTime(widget.year, prevMonth, 1));
    final nextLabel = _overlayLabelFor(DateTime(widget.year, nextMonth, 1));
    widget.onMonthOverlay(curLabel, nextLabel, t);
  }

  void _notifyOverlayFor(DateTime date) {
    final label = _overlayLabelFor(DateTime(date.year, date.month, 1));
    widget.onMonthOverlay(label, label, 1.0);
  }

  /// Public API: scroll the list so that [date] is brought into view.
  Future<void> scrollToDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final id = _id(normalized);
    final key = _dayKeys[id];

    // If the target isn't laid out yet, jump approximately near it first.
    if ((key?.currentContext == null) && _scroll.hasClients) {
      final index = normalized.difference(_startOfYear).inDays.clamp(0, 366);
      final approxRowH = widget.rowMinH + 1.0; // + divider
      final target = index * approxRowH;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(target.clamp(0.0, max));
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: _alignSelected,
      );
    }

    _notifyOverlayFor(normalized);
    _emitOverlay();
  }

  String? _chipTime(BuildContext context, day.Reminder r) {
    // Keep TimeOfDay.format (locale-aware); only compute what's needed.
    if (r.start != null && r.end != null) {
      return '${r.start!.format(context)} \u2192 ${r.end!.format(context)}';
    } else if (r.start != null) {
      return r.start!.format(context);
    }
    return null; // all-day
  }

  String? _taskTime(day.Task t) {
    final s = t.scheduledStart;
    if (s != null) return _fmtJM.format(s);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: We still listen to the store at the list level; Flutter only
    // builds visible items, so this is typically fine. If needed later,
    // move chips into their own Listenable widgets keyed per day.
    return AnimatedBuilder(
      animation: day.DayPlanStore.I,
      builder: (_, __) {
        return ListView.separated(
          key: _listKey,
          controller: _scroll,
          padding: EdgeInsets.zero,
          // render a bit more offscreen to reduce jank while flinging
          cacheExtent: 1400,
          // lower framework overhead
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
          itemCount: _totalDays,
          separatorBuilder: (_, __) => Container(
            margin: EdgeInsets.only(left: widget.sidebarW),
            height: 1,
            color: _line,
          ),
          itemBuilder: (_, i) {
            final d = _startOfYear.add(Duration(days: i));
            final dayKey = _dayKeys.putIfAbsent(_id(d), () => GlobalKey());
            if (d.day == 1) _monthKeys[d.month] = dayKey;

            // ----- Reminders (existing) -----
            final reminders = day.DayPlanStore.I.reminders(d).toList()
              ..sort((a, b) {
                final aMin = a.start == null
                    ? 1 << 20
                    : a.start!.hour * 60 + a.start!.minute;
                final bMin = b.start == null
                    ? 1 << 20
                    : b.start!.hour * 60 + b.start!.minute;
                return aMin.compareTo(bMin);
              });

            // ----- Tasks (OPEN + DONE; open first) -----
            final tasks = day.DayPlanStore.I.tasks(d).toList()
              ..sort((a, b) {
                if (a.done != b.done) return a.done ? 1 : -1; // open first
                final as = a.scheduledStart;
                final bs = b.scheduledStart;
                if (as != null && bs != null) return as.compareTo(bs);
                if (as != null) return -1;
                if (bs != null) return 1;
                return b.priority.compareTo(a.priority);
              });

            const double chipSpacing = 2.0;

            final chips = <Widget>[
              // Reminders → colored pills
              ...reminders.map((r) {
                final t = _chipTime(context, r);
                final color = _markerFor(r.title); // match Extended panel
                return Padding(
                  padding: const EdgeInsets.only(bottom: chipSpacing),
                  child: _EventPill(title: r.title, time: t, dotColor: color),
                );
              }),
              // Tasks → compact checkbox rows (stay visible when completed)
              ...tasks.map((t) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: chipSpacing),
                  child: _TaskMiniChip(
                    title: t.title,
                    checked: t.done,
                    time: _taskTime(t),
                    onToggle: (bool value) => day.DayPlanStore.I.toggleTask(
                      DateTime(d.year, d.month, d.day),
                      t.id,
                      value,
                    ),
                  ),
                );
              }),
            ];

            return KeyedSubtree(
              key: dayKey,
              child: RepaintBoundary(
                child: _DayRow(
                  day: d,
                  today: _today,
                  isSelected: _sameDay(d, widget.selected),
                  sidebarW: widget.sidebarW,
                  rowMinH: widget.rowMinH,
                  hPad: widget.hPad,
                  railLabelColor: _muted,
                  railColor: widget.railColor,
                  laneColor: widget.laneColor,
                  railProgress: widget.railProgress,
                  chips: chips.isEmpty ? const [SizedBox(height: 2)] : chips,
                  onTap: () => widget.onPick(DateTime(d.year, d.month, d.day)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ===== Row widgets (private to this file) =====

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.today,
    required this.isSelected,
    required this.sidebarW,
    required this.rowMinH,
    required this.hPad,
    required this.railLabelColor,
    required this.onTap,
    required this.railColor,
    required this.laneColor,
    required this.railProgress, // 0..1
    this.chips = const <Widget>[],
  });

  final DateTime day;
  final DateTime today;
  final bool isSelected;
  final double sidebarW;
  final double rowMinH;
  final double hPad;
  final Color railLabelColor;
  final Color railColor;
  final Color laneColor;
  final double railProgress; // 0..1
  final VoidCallback onTap;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    // Badge sizing; hug right edge of the black rail.
    const double badgeW = 48;
    const double badgeH = 64;
    const double badgeRightInset = 6;

    // Precompute fade factor (1 - railProgress).
    final double f = (1.0 - railProgress).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: rowMinH),
          child: Stack(
            children: [
              // Backgrounds: black rail + lane
              Positioned.fill(
                child: Row(
                  children: [
                    Container(width: sidebarW, color: railColor),
                    Expanded(child: Container(color: laneColor)),
                  ],
                ),
              ),

              // Date badge on the rail, aligned to the rail's right edge
              Positioned(
                left: sidebarW - badgeRightInset - badgeW,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: badgeW,
                  child: Center(
                    // Remove Opacity(saveLayer). Fade via color tints in badge.
                    child: _DateBadge(
                      day: day,
                      today: today,
                      width: badgeW,
                      height: badgeH,
                      isSelected: isSelected,
                      weekdayColor: Color.fromRGBO(
                        255,
                        255,
                        255,
                        0.70 * f,
                      ), // _muted * f
                      railColor: railColor,
                      fade: f,
                    ),
                  ),
                ),
              ),

              // Right lane (chips)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: sidebarW),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: chips,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.day,
    required this.today,
    this.width = 48,
    this.height = 64,
    this.isSelected = false,
    this.weekdayColor = const Color(0xB3FFFFFF),
    this.railColor = Colors.black,
    this.fade = 1.0, // 0..1 final alpha multiplier (no saveLayer)
  });

  final DateTime day;
  final DateTime today;
  final double width;
  final double height;
  final bool isSelected; // selected or today outline
  final Color weekdayColor;
  final Color railColor;
  final double fade;

  static const List<String> _dow = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final dow = _dow[day.weekday - 1];
    final showOutline = isSelected || _sameDay(day, today);

    // Apply fade by tinting colors (cheaper than Opacity layer)
    final Color outline = showOutline
        ? Color.fromRGBO(255, 255, 255, 1.0 * fade)
        : Colors.transparent;
    final Color dayNum = Color.fromRGBO(255, 255, 255, 1.0 * fade);

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: railColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outline, width: 2.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dow,
              style: TextStyle(
                color: weekdayColor,
                fontSize: 10,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${day.day}',
              style: TextStyle(
                color: dayNum,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventPill extends StatelessWidget {
  const _EventPill({
    required this.title,
    required this.time,
    required this.dotColor,
  });

  final String title;
  final String? time;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _kAccentW,
            height: _kAccentH,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: _kTextGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 0.5),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                    height: 1.0,
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 1.5),
                  Text(
                    time!,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.25,
                      height: 1.05,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact task row with a **square** checkbox.
/// When checked, we keep the task visible, fade it, and animate a strikethrough.
class _TaskMiniChip extends StatefulWidget {
  const _TaskMiniChip({
    required this.title,
    required this.checked,
    required this.onToggle,
    this.time,
  });

  final String title;
  final bool checked;
  final String? time;

  /// Called with the new value when toggled.
  final ValueChanged<bool> onToggle;

  @override
  State<_TaskMiniChip> createState() => _TaskMiniChipState();
}

class _TaskMiniChipState extends State<_TaskMiniChip>
    with SingleTickerProviderStateMixin {
  late bool _checked;
  late final AnimationController _strikeCtrl; // 0..1

  static const _strikeDur = Duration(milliseconds: 220);
  static const _popDur = Duration(milliseconds: 140);

  @override
  void initState() {
    super.initState();
    _checked = widget.checked;
    _strikeCtrl =
        AnimationController(
          vsync: this,
          duration: _strikeDur,
          value: _checked ? 1.0 : 0.0,
        )..addListener(() {
          if (mounted) setState(() {});
        });
  }

  @override
  void didUpdateWidget(covariant _TaskMiniChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checked != widget.checked) {
      _checked = widget.checked;
      _strikeCtrl.animateTo(
        _checked ? 1.0 : 0.0,
        duration: _strikeDur,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _strikeCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !_checked;
    setState(() => _checked = next);
    _strikeCtrl.animateTo(
      next ? 1.0 : 0.0,
      duration: _strikeDur,
      curve: Curves.easeOut,
    );
    widget.onToggle(next);
  }

  @override
  Widget build(BuildContext context) {
    const mutedText = Color(0x88FFFFFF);
    final strikeT = _strikeCtrl.value;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      opacity: _checked ? 0.60 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox in the same accent slot as the reminder pill
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: SizedBox(
                width: _kAccentW,
                height: _kAccentH,
                child: Center(
                  child: AnimatedScale(
                    duration: _popDur,
                    curve: Curves.easeOutBack,
                    scale: _checked ? 1.06 : 1.0,
                    child: AnimatedContainer(
                      duration: _strikeDur,
                      curve: Curves.easeOut,
                      width: _kAccentW, // slightly larger square
                      height: _kAccentW,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white, width: 2),
                        color: _checked ? Colors.white : Colors.transparent,
                      ),
                      child: AnimatedSwitcher(
                        duration: _popDur,
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        child: _checked
                            ? const Icon(
                                Icons.check_rounded,
                                key: ValueKey('on'),
                                size: 10,
                                color: Colors.black,
                              )
                            : const SizedBox(key: ValueKey('off')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: _kTextGap),

            // Title + optional time (tap text to toggle as well)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with animated strikethrough
                    _StrikeTitle(
                      text: widget.title,
                      crossedProgress: strikeT,
                      color: _checked ? mutedText : Colors.white,
                    ),
                    if (widget.time != null) ...[
                      const SizedBox(height: 1.5),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          color: _checked ? mutedText : const Color(0xCCFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                        child: Text(
                          widget.time!,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to avoid the `withOpacity` deprecation while keeping behavior.
Color _withOpacityCompat(Color c, double o) =>
    Color.fromRGBO(c.red, c.green, c.blue, o);

/// Renders the title text and animates a strikethrough using [crossedProgress].
class _StrikeTitle extends StatelessWidget {
  const _StrikeTitle({
    required this.text,
    required this.crossedProgress, // 0..1
    required this.color,
  });

  final String text;
  final double crossedProgress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final lineColor = _withOpacityCompat(color, 0.85);

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        // Animated strikethrough that grows left -> right
        IgnorePointer(
          ignoring: true,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth * crossedProgress;
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: w.clamp(0.0, box.maxWidth),
                  height: 2,
                  margin: const EdgeInsets.symmetric(vertical: 1.0),
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
