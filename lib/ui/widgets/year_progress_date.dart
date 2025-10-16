// lib/ui/widgets/year_progress_date.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Use ONLY the package import, aliased.
import 'package:kontinuum/ui/widgets/mini_calendar_sheet.dart' as sheet;

class YearProgressBar extends StatefulWidget {
  const YearProgressBar({
    super.key,
    required this.selectedDate,
    required this.getProgressForDay,
    required this.onDateSelected,
    this.firstDateCap,
    this.lastDateCap,
  });

  final DateTime selectedDate; // local date
  final double Function(DateTime) getProgressForDay;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? firstDateCap;
  final DateTime? lastDateCap;

  @override
  State<YearProgressBar> createState() => _YearProgressBarState();
}

class _YearProgressBarState extends State<YearProgressBar> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  static const double itemWidth = 60;

  // Anchor for the big date label (to position the popover).
  final GlobalKey _dateTapKey = GlobalKey();

  // ---- Progress animation cache (previous values per day index) ----
  final Map<int, double> _prevProgressByDayIndex = {};
  int? _cachedYear; // reset cache when year changes

  // ---- UTC day-index helper (avoids DST off-by-one) ----
  int _dayIndexUtc(DateTime localDate) {
    final startUtc = DateTime.utc(localDate.year, 1, 1);
    final dateUtc = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
    );
    return dateUtc.difference(startUtc).inDays; // 0-based index
  }

  // Total days in the visible year (UTC-safe)
  int _daysInYearUtc(int year) {
    final a = DateTime.utc(year, 1, 1);
    final b = DateTime.utc(year + 1, 1, 1);
    return b.difference(a).inDays;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter(widget.selectedDate, jump: true);
    });

    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCenter(DateTime date, {bool jump = false}) {
    final index = _dayIndexUtc(date); // DST-proof index
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (index * itemWidth) - (screenWidth / 2 - itemWidth / 2);

    void doScroll() {
      final maxExtent = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final clamped = offset.clamp(0.0, maxExtent);

      if (jump) {
        _scrollController.jumpTo(clamped);
      } else {
        _scrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    if (_scrollController.hasClients) {
      doScroll();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    }
  }

  double _calculateScale(double itemCenter, double screenCenter) {
    final distance = (itemCenter - screenCenter).abs();
    const maxDistance = 200.0;
    final t = (distance / maxDistance).clamp(0.0, 1.0);
    return 1.0 - (0.3 * t);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Get a global rect for the anchor widget.
  Rect _globalRectFor(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return const Rect.fromLTWH(0, 0, 0, 0);
    final box = ctx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }

  // Use the ANCHORED variant so the calendar pops under the tappable date.
  Future<void> _openMiniCalendar() async {
    final now = DateTime.now();
    final first = widget.firstDateCap ?? DateTime(now.year - 5, 1, 1);
    final last = widget.lastDateCap ?? DateTime(now.year + 5, 12, 31);

    final anchor = _globalRectFor(_dateTapKey);

    await sheet.MiniCalendarSheet.showAnchored(
      context,
      anchorRect: anchor,
      initialDate: widget.selectedDate,
      firstDate: first,
      lastDate: last,
      onSelected: (picked) {
        final normalized = DateTime(picked.year, picked.month, picked.day);
        widget.onDateSelected(normalized);
        _scrollToCenter(normalized); // center the chosen day in the strip
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;
    final startOfYearLocal = DateTime(selectedDate.year, 1, 1);
    final daysInYear = _daysInYearUtc(selectedDate.year);
    final screenWidth = MediaQuery.of(context).size.width;

    // Reset per-year cache if the year changed.
    if (_cachedYear != selectedDate.year) {
      _prevProgressByDayIndex.clear();
      _cachedYear = selectedDate.year;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big tappable date (keyed for anchoring)
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
          child: Center(
            child: InkWell(
              key: _dateTapKey,
              onTap: _openMiniCalendar,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  DateFormat.yMMMMEEEEd().format(selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Day strip
        SizedBox(
          height: 100,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: daysInYear,
            itemBuilder: (context, index) {
              final day = startOfYearLocal.add(Duration(days: index)); // local
              final isToday = _isSameDay(day, DateTime.now());
              final isSelected = _isSameDay(day, selectedDate);
              final currentProgress = widget
                  .getProgressForDay(day)
                  .clamp(0.0, 1.0);

              // Progress animation: animate from previous to current.
              final prev = _prevProgressByDayIndex[index] ?? currentProgress;
              // Update cache (no setState needed; this just tracks the last seen value).
              _prevProgressByDayIndex[index] = currentProgress;

              final itemStart = index * itemWidth;
              final itemCenter = itemStart + itemWidth / 2;
              final screenCenter = _scrollOffset + screenWidth / 2;
              final scale = _calculateScale(itemCenter, screenCenter);

              Color dayTextColor = Colors.white;
              if (isToday) dayTextColor = Colors.purpleAccent;
              if (isSelected) dayTextColor = Colors.amber;

              return GestureDetector(
                onTap: () {
                  widget.onDateSelected(day);
                  _scrollToCenter(day);
                },
                child: SizedBox(
                  width: itemWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat.E().format(day),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Animated circular day progress
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: prev,
                                end: currentProgress,
                              ),
                              duration: const Duration(milliseconds: 550),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.amber,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                  child: CircularProgressIndicator(
                                    value: value.clamp(0.0, 1.0),
                                    strokeWidth: 5,
                                    backgroundColor: Colors.grey.shade800,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                  ),
                                );
                              },
                            ),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: dayTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
