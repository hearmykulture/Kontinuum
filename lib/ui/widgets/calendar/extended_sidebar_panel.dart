import 'dart:math' as math;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kontinuum/ui/screens/day_detail_page.dart' as day;
import 'package:kontinuum/ui/widgets/calendar/year_overview_page.dart';

/// Left-anchored, width-capped extended panel beside the rail.
/// Perf: This widget is intended to be *prebuilt* and not rebuilt per anim tick.
/// Only the agenda subsection listens to DayPlanStore.
class ExtendedSidebarPanel extends StatelessWidget {
  const ExtendedSidebarPanel({
    super.key,
    required this.monthAnchor,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onPick,
  });

  final DateTime monthAnchor; // first of the month currently shown
  final DateTime selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onPick;

  // Style tokens
  static const _bg = Color(0xFF000000);
  static const _rose = Color(0xFFE54878); // header + outline tint
  static const _muted = Color(0x99FFFFFF);

  // Layout tokens
  static const double _maxContentW = 280;
  static const double _leftPad = 12;
  static const double _rightPad = 8;
  static const double _vPadTop = 10;
  static const double _vPadBot = 10;

  static const double _gridSpacing = 6;
  static const double _weekdayFont = 12;
  static const double _dayTextSize = 14;
  static const double _dayCircleMax = 28;

  // Date formats (cached)
  static final DateFormat _fmtYear = DateFormat.y();
  static final DateFormat _fmtMonthFull = DateFormat.MMMM();
  static final DateFormat _fmtToday = DateFormat('EEE d');

  // Reused text styles (const where possible)
  static const TextStyle _yearStyle = TextStyle(
    color: Colors.white70,
    fontSize: 30,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
  );
  static const TextStyle _monthStyle = TextStyle(
    color: _rose,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );
  static const TextStyle _dowStyle = TextStyle(
    color: Colors.white60,
    fontSize: _weekdayFont,
    letterSpacing: 1.2,
  );
  static const TextStyle _todayAddStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );
  static const TextStyle _agendaTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle _agendaTimeStyle = TextStyle(
    color: _muted,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: .2,
  );

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _id(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  List<DateTime> _grid(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leading = (first.weekday % 7); // Sun=0
    final days = DateTime(month.year, month.month + 1, 0).day;
    final total = leading + days;
    final trailing = (total % 7 == 0) ? 0 : 7 - (total % 7);

    final out = <DateTime>[];
    for (int i = leading - 1; i >= 0; i--) {
      out.add(first.subtract(Duration(days: i + 1)));
    }
    for (int d = 0; d < days; d++) {
      out.add(DateTime(month.year, month.month, d + 1));
    }
    for (int i = 0; i < trailing; i++) {
      out.add(DateTime(month.year, month.month, days + i + 1));
    }
    while (out.length < 42) {
      out.add(out.last.add(const Duration(days: 1)));
    }
    return out;
  }

  bool _inRange(DateTime d) {
    final a = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final b = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(a) && !x.isAfter(b);
  }

  /// Has-items probe (agenda or tasks).
  bool _hasItems(DateTime d) {
    final a = day.DayPlanStore.I.agendaFor(d);
    return a.events.isNotEmpty ||
        a.scheduled.isNotEmpty ||
        a.allDay.isNotEmpty ||
        a.overdue.isNotEmpty ||
        a.unscheduled.isNotEmpty;
  }

  Color _markerFor(String seed) {
    const palette = <Color>[
      Color(0xFFB672FF), // purple
      Color(0xFFFF5BAD), // magenta
      Color(0xFF47C7FF), // blue
      Color(0xFFB24D4D), // brick
      Color(0xFF6E6E6E), // gray
    ];
    final h = seed.hashCode;
    return palette[(h & 0x7fffffff) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    // One-time per-build values.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final grid = _grid(monthAnchor);
    final year = _fmtYear.format(monthAnchor);
    final month = _fmtMonthFull.format(monthAnchor).toUpperCase();

    final isTodaySelected = _sameDay(selected, today);
    final visibleDay = selected;

    // Precompute which of the 42 cells have items.
    final Map<int, bool> hasItemsCache = <int, bool>{};
    for (final d in grid) {
      hasItemsCache[_id(DateTime(d.year, d.month, d.day))] = _hasItems(d);
    }

    return Material(
      color: _bg,
      clipBehavior: Clip.none,
      child: SafeArea(
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double contentW = math.min(
              constraints.maxWidth,
              _maxContentW,
            );

            return Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints.tightFor(width: contentW),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _leftPad,
                    _vPadTop,
                    _rightPad,
                    _vPadBot,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // YEAR + MONTH — tap for full-year overview (SharedAxis scale)
                      InkWell(
                        splashFactory: NoSplash.splashFactory,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        overlayColor: const MaterialStatePropertyAll(
                          Colors.transparent,
                        ),
                        onTap: () async {
                          final picked = await Navigator.of(context)
                              .push<YearOverviewResult>(
                                PageRouteBuilder(
                                  transitionDuration: const Duration(
                                    milliseconds: 360,
                                  ),
                                  reverseTransitionDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  pageBuilder: (_, __, ___) => YearOverviewPage(
                                    anchorDate: selected,
                                    firstDate: firstDate,
                                    lastDate: lastDate,
                                    accent: const Color(0xFFB672FF),
                                  ),
                                  transitionsBuilder: (_, anim, sec, child) {
                                    final curvedIn = CurvedAnimation(
                                      parent: anim,
                                      curve: Curves.easeOutCubic,
                                    );
                                    final curvedOut = CurvedAnimation(
                                      parent: sec,
                                      curve: Curves.easeOutCubic,
                                    );
                                    return SharedAxisTransition(
                                      animation: curvedIn,
                                      secondaryAnimation: curvedOut,
                                      transitionType:
                                          SharedAxisTransitionType.scaled,
                                      fillColor: Colors.transparent,
                                      child: child,
                                    );
                                  },
                                ),
                              );

                          if (picked != null) {
                            final target = picked.monthOnly
                                ? DateTime(
                                    picked.date.year,
                                    picked.date.month,
                                    1,
                                  )
                                : DateTime(
                                    picked.date.year,
                                    picked.date.month,
                                    picked.date.day,
                                  );
                            onPick(target);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              year,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _yearStyle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              month,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _monthStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Week headers (simple, correct labels)
                      LayoutBuilder(
                        builder: (_, box) {
                          final totalSpacing = _gridSpacing * 6;
                          final double cell =
                              ((box.maxWidth - totalSpacing) / 7).clamp(
                                12.0,
                                40.0,
                              );
                          const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(7, (i) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: i < 6 ? _gridSpacing : 0,
                                ),
                                child: SizedBox(
                                  width: cell,
                                  child: Center(
                                    child: Text(labels[i], style: _dowStyle),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // Month grid (6x7) — never scrollable, cheap to paint.
                      LayoutBuilder(
                        builder: (_, box) {
                          final totalSpacing = _gridSpacing * 6;
                          final double cellW =
                              ((box.maxWidth - totalSpacing) / 7).clamp(
                                20.0,
                                44.0,
                              );
                          final double circle = math.min(
                            _dayCircleMax,
                            cellW - 2,
                          );

                          return GridView.builder(
                            itemCount: 42,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisSpacing: _gridSpacing,
                                  crossAxisSpacing: _gridSpacing,
                                  childAspectRatio: 1.0,
                                ),
                            itemBuilder: (_, i) {
                              final d = grid[i];
                              final inMonth = d.month == monthAnchor.month;
                              final isToday = _sameDay(d, today);
                              final isSel = _sameDay(d, selected);
                              final enabled = _inRange(d);
                              final hasItems =
                                  hasItemsCache[_id(
                                    DateTime(d.year, d.month, d.day),
                                  )] ??
                                  false;

                              BoxDecoration? deco;
                              if (isToday) {
                                deco = BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.0,
                                  ),
                                );
                              } else if (hasItems) {
                                deco = BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _rose, width: 2.0),
                                );
                              }

                              final textColor = inMonth
                                  ? Colors.white
                                  : Colors.white38;

                              return Opacity(
                                opacity: enabled ? 1 : 0.35,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    circle / 2,
                                  ),
                                  onTap: enabled
                                      ? () => onPick(
                                          DateTime(d.year, d.month, d.day),
                                        )
                                      : null,
                                  child: Center(
                                    child: Container(
                                      width: circle,
                                      height: circle,
                                      decoration: deco,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${d.day}',
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: _dayTextSize,
                                          fontWeight: isSel
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // TODAY + add
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isTodaySelected
                                  ? 'TODAY'
                                  : _fmtToday.format(visibleDay).toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _todayAddStyle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Add',
                            onPressed: () => onPick(visibleDay),
                            icon: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Mixed agenda list — ONLY this part listens.
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: day.DayPlanStore.I,
                          builder: (_, __) {
                            final agenda = day.DayPlanStore.I.agendaFor(
                              visibleDay,
                            );

                            final lines =
                                <_AgendaLine>[
                                  ...agenda.events.map((r) {
                                    final startMin = (r.start == null)
                                        ? null
                                        : (r.start!.hour * 60 +
                                              r.start!.minute);
                                    return _AgendaLine(
                                      title: r.title,
                                      startMin: startMin,
                                      isTask: false,
                                    );
                                  }),
                                  ...agenda.scheduled.map((t) {
                                    final s = t.scheduledStart!;
                                    return _AgendaLine(
                                      title: t.title,
                                      startMin: s.hour * 60 + s.minute,
                                      isTask: true,
                                    );
                                  }),
                                  ...agenda.allDay.map(
                                    (t) => _AgendaLine(
                                      title: t.title,
                                      startMin: null,
                                      isTask: true,
                                    ),
                                  ),
                                ]..sort((a, b) {
                                  if (a.startMin == null &&
                                      b.startMin == null) {
                                    return 0;
                                  }
                                  if (a.startMin == null) return 1;
                                  if (b.startMin == null) return -1;
                                  return a.startMin!.compareTo(b.startMin!);
                                });

                            if (lines.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  'No items',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: List.generate(lines.length, (i) {
                                final l = lines[i];
                                final Color color = _markerFor(l.title);
                                final String? timeLabel = () {
                                  if (l.startMin == null) return 'ALL DAY';
                                  final h = (l.startMin! ~/ 60);
                                  final m = (l.startMin! % 60);
                                  return TimeOfDay(
                                    hour: h,
                                    minute: m,
                                  ).format(context);
                                }();

                                return InkWell(
                                  onTap: () {},
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                      left: 0,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: _agendaTitleStyle,
                                              ),
                                              if (timeLabel != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                  child: Text(
                                                    timeLabel,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: _agendaTimeStyle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.event,
                                          size: 16,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),

                      const Spacer(),

                      // 3-dot round button (pinned left)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0E0E0E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 26,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  3,
                                  (_) => Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _AgendaLine {
  const _AgendaLine({
    required this.title,
    required this.startMin,
    required this.isTask,
  });

  final String title;
  final int? startMin; // null => all-day/unscheduled
  final bool isTask;
}
