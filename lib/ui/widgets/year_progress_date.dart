// lib/ui/widgets/year_progress_date.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // Accent you currently use
  static const Color _kAccent = Color(0xFFA56ABD);

  // Gradient end (light green)
  static const Color _kProgressGreen = Color(0xFF8EB69B);

  // Sizes
  static const double _kProgressSize = 48;
  static const double _kProgressStroke = 5;
  static const double _kRingWidth = 1.6;
  static const double _kRingGap = 2.0;

  // Noticeable fade + subtle scale on selection ring
  static const Duration _ringFade = Duration(milliseconds: 420);
  static const double _kRingScaleMin = 0.90;

  final GlobalKey _dateTapKey = GlobalKey();

  final Map<int, double> _prevProgressByDayIndex = {};
  int? _cachedYear;
  Timer? _throttle;

  int _dayIndexUtc(DateTime d) {
    final a = DateTime.utc(d.year, 1, 1);
    final b = DateTime.utc(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

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
      if (_throttle != null) return;
      _throttle = Timer(const Duration(milliseconds: 16), () {
        _throttle = null;
        if (mounted) setState(() => _scrollOffset = _scrollController.offset);
      });
    });
  }

  @override
  void dispose() {
    _throttle?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCenter(DateTime date, {bool jump = false}) {
    final index = _dayIndexUtc(date);
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (index * itemWidth) - (screenWidth / 2 - itemWidth / 2);

    void go() {
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
      go();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
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

  Rect _globalRectFor(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return const Rect.fromLTWH(0, 0, 0, 0);
    final box = ctx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }

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
        _scrollToCenter(normalized);
      },
    );
  }

  String _weekday3(int w) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(w - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;
    final startOfYearLocal = DateTime(selectedDate.year, 1, 1);
    final daysInYear = _daysInYearUtc(selectedDate.year);
    final screenWidth = MediaQuery.of(context).size.width;
    final nowLocal = DateTime.now();

    final double ringSize = _kProgressSize + 2 * _kRingWidth + 2 * _kRingGap;

    if (_cachedYear != selectedDate.year) {
      _prevProgressByDayIndex.clear();
      _cachedYear = selectedDate.year;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        SizedBox(
          height: 100,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemExtent: itemWidth,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            addSemanticIndexes: false,
            itemCount: daysInYear,
            itemBuilder: (context, index) {
              final day = startOfYearLocal.add(Duration(days: index));
              final isToday = _isSameDay(day, nowLocal);
              final isSelected = _isSameDay(day, selectedDate);
              final currentProgress =
                  widget.getProgressForDay(day).clamp(0.0, 1.0);

              final prev = _prevProgressByDayIndex[index] ?? currentProgress;
              _prevProgressByDayIndex[index] = currentProgress;

              final itemStart = index * itemWidth;
              final itemCenter = itemStart + itemWidth / 2;
              final screenCenter = _scrollOffset + screenWidth / 2;
              final scale = _calculateScale(itemCenter, screenCenter);

              Color dayTextColor = Colors.white;
              if (isToday) dayTextColor = Colors.purpleAccent;
              if (isSelected) dayTextColor = _kAccent;

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
                      Text(_weekday3(day.weekday),
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 4),
                      Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: RepaintBoundary(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Gradient progress ring (white → light green)
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                    begin: prev, end: currentProgress),
                                duration: const Duration(milliseconds: 550),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return CustomPaint(
                                    size: const Size.square(_kProgressSize),
                                    painter: _GradientProgressPainter(
                                      progress: value.clamp(0.0, 1.0),
                                      strokeWidth: _kProgressStroke,
                                      trackColor: Colors.grey.shade800,
                                      startColor: Colors.white,
                                      endColor: _kProgressGreen,
                                      startAngle: -math.pi / 2, // top
                                    ),
                                  );
                                },
                              ),

                              // OUTER selection ring — fade + scale
                              IgnorePointer(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                      begin: 0.0, end: isSelected ? 1.0 : 0.0),
                                  duration: _ringFade,
                                  curve: Curves.easeInOutCubic,
                                  builder: (context, t, child) {
                                    final double s = _kRingScaleMin +
                                        (1.0 - _kRingScaleMin) * t;
                                    return Opacity(
                                      opacity: t,
                                      child: Transform.scale(
                                        scale: s,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: ringSize,
                                    height: ringSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _kAccent,
                                        width: _kRingWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Day number
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

/// Paints a circular track and a gradient progress arc (white → light green).
class _GradientProgressPainter extends CustomPainter {
  _GradientProgressPainter({
    required this.progress, // 0..1
    required this.strokeWidth,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
    required this.startAngle,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color startColor;
  final Color endColor;
  final double startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    // Progress
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final sweep = 2 * math.pi * clamped;

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweep,
      colors: [startColor, endColor],
      stops: const [0.0, 1.0],
    );

    final paint = Paint()
      ..shader =
          gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, startAngle, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientProgressPainter old) {
    return old.progress != progress ||
        old.strokeWidth != strokeWidth ||
        old.trackColor != trackColor ||
        old.startColor != startColor ||
        old.endColor != endColor ||
        old.startAngle != startAngle;
  }
}
