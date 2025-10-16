// lib/ui/widgets/mini_day_hour_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kontinuum/ui/widgets/calendar_routes.dart' as calroutes;

enum _Phase { startDay, startHour, endDay, endHour }

class MiniDayHourSheet extends StatefulWidget {
  const MiniDayHourSheet({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected, // returns a DateTimeRange
  });

  /// New range-capable params
  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime firstDate; // day precision
  final DateTime lastDate; // day precision
  final ValueChanged<DateTimeRange> onSelected;

  /// Preferred: explicit range opener.
  static Future<DateTimeRange?> showRange(
    BuildContext context, {
    required DateTime initialStart,
    required DateTime initialEnd,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTimeRange> onSelected,
  }) {
    return calroutes.showHeroBottomSheet<DateTimeRange>(
      context: context,
      builder: (_) => MiniDayHourSheet(
        initialStart: initialStart,
        initialEnd: initialEnd,
        firstDate: firstDate,
        lastDate: lastDate,
        onSelected: onSelected,
      ),
    );
  }

  /// Back-compat helper so you don't have to rename calls immediately.
  /// If you previously called `MiniDayHourSheet.show(...)` with an
  /// `initialDateTime`, this will still work and will *return a range*.
  /// - Start = initialDateTime (or now)
  /// - End   = Start + 1 hour (if not provided)
  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTime? initialDateTime, // legacy-friendly
    DateTime? initialStart, // optional override
    DateTime? initialEnd, // optional override
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTimeRange> onSelected,
  }) {
    final start = initialStart ?? initialDateTime ?? DateTime.now();
    final end = initialEnd ?? start.add(const Duration(hours: 1));
    return showRange(
      context,
      initialStart: start,
      initialEnd: end,
      firstDate: firstDate,
      lastDate: lastDate,
      onSelected: onSelected,
    );
  }

  @override
  State<MiniDayHourSheet> createState() => _MiniDayHourSheetState();
}

class _MiniDayHourSheetState extends State<MiniDayHourSheet> {
  // Visual tokens (match your style)
  static const _panel = Color(0xFF131720);
  static const _faint = Color(0x33FFFFFF);
  static const _muted = Color(0x66FFFFFF);
  static const _text = Colors.white;
  static const _accent = Color(0xFF25D0DB);

  static const double _pillSize = 36.0;
  static const double _gridSpacing = 10.0;

  late _Phase _phase;

  late DateTime _startDate; // normalized Y-M-D
  late int _startHour; // 0..23
  late DateTime _endDate; // normalized Y-M-D
  late int _endHour; // 0..23

  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final s = widget.initialStart;
    final e = widget.initialEnd;

    _startDate = DateTime(s.year, s.month, s.day);
    _startHour = s.hour;

    final normalizedEnd = e.isBefore(s) ? s.add(const Duration(hours: 1)) : e;
    _endDate = DateTime(
      normalizedEnd.year,
      normalizedEnd.month,
      normalizedEnd.day,
    );
    _endHour = normalizedEnd.hour;

    // When opening, show the start month first
    _displayedMonth = DateTime(_startDate.year, _startDate.month, 1);
    _phase = _Phase.startDay;
  }

  // ---------- date helpers ----------
  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;
  int _sundayBasedWeekday(DateTime d) => d.weekday % 7; // Sun=0
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inRangeBounds(DateTime d) {
    final a = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final b = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(a) && !x.isAfter(b);
  }

  void _shiftMonth(int delta) {
    final next = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + delta,
      1,
    );
    final firstMonth = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      1,
    );
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month, 1);
    if (!next.isBefore(firstMonth) && !next.isAfter(lastMonth)) {
      setState(() => _displayedMonth = next);
    }
  }

  List<DateTime> _buildGridDates() {
    final first = _displayedMonth;
    final leading = _sundayBasedWeekday(first);
    final daysThisMonth = _daysInMonth(first);
    final total = leading + daysThisMonth;
    final trailing = (total % 7 == 0) ? 0 : (7 - total % 7);
    final cells = <DateTime>[];

    for (int i = leading - 1; i >= 0; i--) {
      cells.add(first.subtract(Duration(days: i + 1)));
    }
    for (int d = 0; d < daysThisMonth; d++) {
      cells.add(DateTime(first.year, first.month, d + 1));
    }
    for (int i = 0; i < trailing; i++) {
      cells.add(DateTime(first.year, first.month, daysThisMonth + i + 1));
    }
    while (cells.length < 42) {
      cells.add(cells.last.add(const Duration(days: 1)));
    }
    return cells;
  }

  // ---------- hour helpers ----------
  String _hourLabel(int h) => DateFormat('h a').format(DateTime(2000, 1, 1, h));

  void _finish() {
    DateTime start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startHour,
    );
    DateTime end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endHour,
    );

    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }

    final out = DateTimeRange(start: start, end: end);
    widget.onSelected(out);
    Navigator.of(context).pop(out);
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + insets),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _faint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                // header
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _phase == _Phase.startDay || _phase == _Phase.endDay
                      ? _RangeDayHeader(
                          key: ValueKey(
                            "${_displayedMonth.year}-${_displayedMonth.month}-${_phase.name}",
                          ),
                          displayedMonth: _displayedMonth,
                          phase: _phase,
                          onPrev: () => _shiftMonth(-1),
                          onNext: () => _shiftMonth(1),
                          onClose: () => Navigator.of(context).pop(),
                        )
                      : _RangeHourHeader(
                          key: ValueKey(
                            "${_phase.name}-${_currentEditingDate().toIso8601String()}",
                          ),
                          phase: _phase,
                          date: _currentEditingDate(),
                          onBack: () => setState(() {
                            _phase = (_phase == _Phase.startHour)
                                ? _Phase.startDay
                                : _Phase.endDay;
                          }),
                          onClose: () => Navigator.of(context).pop(),
                        ),
                ),

                const SizedBox(height: 6),

                // body
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: (_phase == _Phase.startDay || _phase == _Phase.endDay)
                      ? _buildDayGrid()
                      : _buildHourGrid(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DateTime _currentEditingDate() {
    return (_phase == _Phase.startHour) ? _startDate : _endDate;
  }

  Widget _buildDayGrid() {
    final gridDates = _buildGridDates();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      key: const ValueKey('day-grid'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // weekdays
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (w) => SizedBox(
                    width: _pillSize,
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),

        // grid
        SizedBox(
          height: (_pillSize + 10) * 6 + _gridSpacing * 5,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: _gridSpacing,
              mainAxisSpacing: _gridSpacing,
            ),
            itemBuilder: (_, i) {
              final day = gridDates[i];
              final inDisplayed = day.month == _displayedMonth.month;
              final enabled = _inRangeBounds(day);

              final isStart = _sameDay(day, _startDate);
              final isEnd = _sameDay(day, _endDate);
              final inBetween =
                  day.isAfter(_startDate) && day.isBefore(_endDate);

              final isToday = _sameDay(day, today);

              // base color for day number
              final fg = inDisplayed ? _text : _muted.withOpacity(0.35);

              BoxDecoration deco;
              if (isStart && isEnd) {
                // single-day range
                deco = const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent,
                );
              } else if (isStart || isEnd) {
                deco = BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                    ),
                  ],
                );
              } else if (inBetween) {
                // middle days (subtle fill)
                deco = BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x3325D0DB), // faint accent
                );
              } else if (isToday) {
                deco = BoxDecoration(
                  shape: BoxShape.circle,
                  color: _panel,
                  border: Border.all(color: Colors.white, width: 2.5),
                );
              } else {
                deco = BoxDecoration(
                  shape: BoxShape.circle,
                  color: inDisplayed
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x0DFFFFFF),
                );
              }

              return Opacity(
                opacity: enabled ? 1 : 0.45,
                child: InkWell(
                  borderRadius: BorderRadius.circular(_pillSize / 2),
                  onTap: enabled
                      ? () {
                          setState(() {
                            if (_phase == _Phase.startDay) {
                              _startDate = DateTime(
                                day.year,
                                day.month,
                                day.day,
                              );
                              _displayedMonth = DateTime(
                                day.year,
                                day.month,
                                1,
                              );
                              _phase = _Phase.startHour;
                            } else {
                              _endDate = DateTime(day.year, day.month, day.day);
                              _displayedMonth = DateTime(
                                day.year,
                                day.month,
                                1,
                              );
                              _phase = _Phase.endHour;
                            }
                          });
                        }
                      : null,
                  child: Center(
                    child: Container(
                      width: _pillSize,
                      height: _pillSize,
                      decoration: deco,
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: (isStart || isEnd) ? Colors.black : fg,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourGrid() {
    final selectedHour = (_phase == _Phase.startHour) ? _startHour : _endHour;

    return SizedBox(
      key: const ValueKey('hour-grid'),
      height: 6 * 56 + 5 * 10,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: 24,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
        ),
        itemBuilder: (_, h) {
          final selected = h == selectedHour;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                if (_phase == _Phase.startHour) {
                  _startHour = h;
                  _phase = _Phase.endDay;
                  // jump month view to end date for convenience
                  _displayedMonth = DateTime(_endDate.year, _endDate.month, 1);
                } else {
                  _endHour = h;
                  _finish();
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected ? _accent : const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                _hourLabel(h),
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Day header with START/END cue
class _RangeDayHeader extends StatelessWidget {
  const _RangeDayHeader({
    super.key,
    required this.displayedMonth,
    required this.phase,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final DateTime displayedMonth;
  final _Phase phase;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.MMMM().format(displayedMonth).toUpperCase();
    final year = displayedMonth.year.toString();
    final label = (phase == _Phase.startDay) ? 'START DATE' : 'END DATE';

    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          color: Colors.white,
          tooltip: 'Previous month',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _MiniDayHourSheetState._muted,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                monthName,
                style: const TextStyle(
                  color: _MiniDayHourSheetState._accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Text(
                year,
                style: const TextStyle(
                  color: _MiniDayHourSheetState._muted,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          color: Colors.white,
          tooltip: 'Next month',
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          color: Colors.white,
          tooltip: 'Close',
        ),
      ],
    );
  }
}

/// Hour header with START/END cue + date
class _RangeHourHeader extends StatelessWidget {
  const _RangeHourHeader({
    super.key,
    required this.phase,
    required this.date,
    required this.onBack,
    required this.onClose,
  });

  final _Phase phase;
  final DateTime date;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cue = (phase == _Phase.startHour) ? 'START TIME' : 'END TIME';
    final label = DateFormat('EEE MMM d').format(date).toUpperCase();

    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left),
          color: Colors.white,
          tooltip: 'Back',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cue,
                style: const TextStyle(
                  color: _MiniDayHourSheetState._muted,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: _MiniDayHourSheetState._accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          color: Colors.white,
          tooltip: 'Close',
        ),
      ],
    );
  }
}
