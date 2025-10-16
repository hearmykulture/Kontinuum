import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// What this page returns via Navigator.pop:
/// - [date]: the date to act on
/// - [monthOnly] = true when the user tapped the month tile (not a specific day)
class YearOverviewResult {
  final DateTime date;
  final bool monthOnly;
  const YearOverviewResult(this.date, {this.monthOnly = false});

  factory YearOverviewResult.month(DateTime firstOfMonth) => YearOverviewResult(
    DateTime(firstOfMonth.year, firstOfMonth.month, 1),
    monthOnly: true,
  );

  factory YearOverviewResult.day(DateTime day) =>
      YearOverviewResult(DateTime(day.year, day.month, day.day));
}

/// Full-year overview with 12 compact month grids.
class YearOverviewPage extends StatefulWidget {
  const YearOverviewPage({
    super.key,
    required this.anchorDate,
    required this.firstDate,
    required this.lastDate,
    this.accent = const Color(0xFFB672FF),
    this.bg = const Color(0xFF000000),
  });

  final DateTime anchorDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Color accent;
  final Color bg;

  @override
  State<YearOverviewPage> createState() => _YearOverviewPageState();
}

class _YearOverviewPageState extends State<YearOverviewPage> {
  // Reuse formatters across rebuilds
  static final DateFormat _fmtMMM = DateFormat.MMM();

  late int _year;
  late DateTime _selected;
  bool _showGrid = false;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      widget.anchorDate.year,
      widget.anchorDate.month,
      widget.anchorDate.day,
    );
    _year = _selected.year;

    // Defer heavy grid build to next frame for snappier entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showGrid = true);
    });
  }

  bool _inRange(DateTime d) {
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

  Future<void> _pickYear() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: const Color(0xFF101015),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: SizedBox(
            width: 360,
            height: 360,
            child: YearPicker(
              firstDate: DateTime(widget.firstDate.year, 1, 1),
              lastDate: DateTime(widget.lastDate.year, 12, 31),
              initialDate: DateTime(_year, 1, 1),
              selectedDate: DateTime(_year, 1, 1),
              onChanged: (d) => Navigator.of(context).pop(d.year),
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _year = picked);
  }

  @override
  Widget build(BuildContext context) {
    const months = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]; // const list
    final mq = MediaQuery.of(context);

    // Normalize once; pass down so tiles don't call DateTime.now repeatedly.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return MediaQuery(
      data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: widget.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Year (tap to change) + Close
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickYear,
                      child: Text(
                        '$_year',
                        style: TextStyle(
                          color: widget.accent,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 12-month grid (deferred for snappy entry)
                Expanded(
                  child: _showGrid
                      ? LayoutBuilder(
                          builder: (ctx, c) {
                            final cols = c.maxWidth < 420 ? 2 : 3;
                            final aspect = cols == 2 ? 0.86 : 0.92;
                            return GridView.builder(
                              key: ValueKey('y$_year-$cols'),
                              physics: const BouncingScrollPhysics(),
                              cacheExtent:
                                  1200, // prebuild a bit to reduce jank
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: aspect,
                                  ),
                              itemCount: months.length,
                              itemBuilder: (_, i) => RepaintBoundary(
                                child: _MonthMini(
                                  key: ValueKey('y$_year-m${months[i]}'),
                                  year: _year,
                                  month: months[i],
                                  selected: _selected,
                                  today: today,
                                  accent: widget.accent,
                                  fmtMMM: _fmtMMM,
                                  enabledPredicate: _inRange,
                                  onTapMonth: (firstOfMonth) {
                                    Navigator.of(context).pop(
                                      YearOverviewResult.month(firstOfMonth),
                                    );
                                  },
                                  onTapDay: (day) {
                                    if (_inRange(day)) {
                                      Navigator.of(
                                        context,
                                      ).pop(YearOverviewResult.day(day));
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        )
                      : const SizedBox.expand(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthMini extends StatefulWidget {
  const _MonthMini({
    super.key,
    required this.year,
    required this.month,
    required this.selected,
    required this.today,
    required this.accent,
    required this.fmtMMM,
    required this.enabledPredicate,
    required this.onTapMonth,
    required this.onTapDay,
  });

  final int year;
  final int month;
  final DateTime selected;
  final DateTime today;
  final Color accent;
  final DateFormat fmtMMM;
  final bool Function(DateTime d) enabledPredicate;
  final ValueChanged<DateTime> onTapMonth;
  final ValueChanged<DateTime> onTapDay;

  @override
  State<_MonthMini> createState() => _MonthMiniState();
}

class _MonthMiniState extends State<_MonthMini> {
  late final List<DateTime> _dates; // 42 cells, cached
  late final String _monthName; // cached uppercase "JAN", "FEB", ...
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _buildGridDates(int year, int month) {
    final first = DateTime(year, month, 1);
    final leading = (first.weekday % 7); // Sun=0
    final days = DateTime(year, month + 1, 0).day;

    final out = <DateTime>[];
    for (int i = leading - 1; i >= 0; i--) {
      out.add(first.subtract(Duration(days: i + 1)));
    }
    for (int d = 1; d <= days; d++) {
      out.add(DateTime(year, month, d));
    }
    while (out.length % 7 != 0) out.add(out.last.add(const Duration(days: 1)));
    while (out.length < 42) out.add(out.last.add(const Duration(days: 1)));
    return out;
  }

  @override
  void initState() {
    super.initState();
    _dates = _buildGridDates(widget.year, widget.month);
    _monthName = widget.fmtMMM
        .format(DateTime(widget.year, widget.month, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Outer tile
    final tile = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x17FFFFFF)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month label
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _monthName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Weekday headers
          Row(
            children: _weekdayLabels
                .map(
                  (w) => const Expanded(
                    child: Center(
                      child: Text(
                        '', // replaced below to keep const TextStyle
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          // Replace labels (fast path, no extra layout work)
          // (We generate a new row to keep code simple/readable)
          Row(
            children: _weekdayLabels
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),

          // 6x7 grid; day text scales down by formula (no FittedBox)
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) {
                const spacing = 6.0;
                final cellW = (box.maxWidth - spacing * 6) / 7.0;
                final circle = math.max(0.0, cellW - 2.0);
                final baseFont = (circle * 0.58).clamp(9.0, 14.0);

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: 1,
                  ),
                  itemCount: 42,
                  itemBuilder: (_, i) {
                    final d = _dates[i];
                    final inMonth =
                        d.month == widget.month && d.year == widget.year;
                    final isToday = _sameDay(d, widget.today);
                    final isSel = _sameDay(d, widget.selected);
                    final enabled = widget.enabledPredicate(d);

                    // Colors without opacity layers (cheaper than wrapping in Opacity)
                    final Color textColor = enabled
                        ? (inMonth ? Colors.white : Colors.white38)
                        : const Color(0x55FFFFFF);

                    BoxDecoration? deco;
                    if (isToday) {
                      deco = BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      );
                    }
                    if (isSel) {
                      deco = BoxDecoration(
                        color: widget.accent.withOpacity(0.90),
                        shape: BoxShape.circle,
                      );
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled ? () => widget.onTapDay(d) : null,
                      child: Center(
                        child: Container(
                          width: circle,
                          height: circle,
                          decoration: deco,
                          alignment: Alignment.center,
                          child: Text(
                            '${d.day}',
                            maxLines: 1,
                            style: TextStyle(
                              color: isSel ? Colors.black : textColor,
                              fontSize: baseFont,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    // Make the whole tile tappable to jump to the month (no ink/splash overhead)
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTapMonth(DateTime(widget.year, widget.month, 1)),
      child: tile,
    );
  }
}
