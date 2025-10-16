import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthProgressBar extends StatefulWidget {
  final DateTime selectedDate;
  final double Function(DateTime) getProgressForDay;
  final ValueChanged<DateTime> onDateSelected;

  const MonthProgressBar({
    super.key,
    required this.selectedDate,
    required this.getProgressForDay,
    required this.onDateSelected,
  });

  @override
  State<MonthProgressBar> createState() => _MonthProgressBarState();
}

class _MonthProgressBarState extends State<MonthProgressBar> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  // ✂️ Tighter layout constants
  static const double _itemWidth = 56;
  static const double _listHeight = 76; // was 100
  static const double _circleSize = 40; // was 48
  static const double _ringStroke = 4; // was 5
  static const double _weekdayFont = 12; // was 14
  static const double _dayFont = 13; // was 14

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
  void didUpdateWidget(covariant MonthProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCenter(widget.selectedDate);
      });
    }
  }

  void _scrollToCenter(DateTime date, {bool jump = false}) {
    final startOfMonth = DateTime(date.year, date.month, 1);
    final index = date.difference(startOfMonth).inDays; // 0-based
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (index * _itemWidth) - (screenWidth / 2 - _itemWidth / 2);

    void run() {
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
      run();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    }
  }

  double _scaleFor(double itemCenter, double screenCenter) {
    final distance = (itemCenter - screenCenter).abs();
    const maxDistance = 200.0;
    final t = (distance / maxDistance).clamp(0.0, 1.0);
    // 1.0 down to 0.7 like before, but with smaller base size this stays compact
    return 1.0 - (0.3 * t);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedDate;
    final firstOfMonth = DateTime(selected.year, selected.month, 1);
    final totalDays = _daysInMonth(selected);
    final monthPct = (selected.day / totalDays).clamp(0.0, 1.0);
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date line
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Center(
            child: Text(
              DateFormat.yMMMMEEEEd().format(selected),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),

        // Compact month progress under the date
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: monthPct,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    "${selected.day} / $totalDays days",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    "${(monthPct * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Day scroller (denser)
        SizedBox(
          height: _listHeight,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: totalDays,
            itemBuilder: (context, index) {
              final day = firstOfMonth.add(Duration(days: index));
              final isToday = _sameDay(day, DateTime.now());
              final isSelected = _sameDay(day, selected);
              final progress = widget.getProgressForDay(day);

              final itemStart = index * _itemWidth;
              final itemCenter = itemStart + _itemWidth / 2;
              final screenCenter = _scrollOffset + screenWidth / 2;
              final scale = _scaleFor(itemCenter, screenCenter);

              Color dayTextColor = Colors.white;
              if (isToday) dayTextColor = Colors.purpleAccent;
              if (isSelected) dayTextColor = Colors.amber;

              return GestureDetector(
                onTap: () {
                  widget.onDateSelected(day);
                  _scrollToCenter(day);
                },
                child: SizedBox(
                  width: _itemWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat.E().format(day),
                        style: TextStyle(fontSize: _weekdayFont),
                      ),
                      const SizedBox(height: 2), // tighter
                      Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: _circleSize,
                              height: _circleSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.amber,
                                        width: 2.5,
                                      )
                                    : null,
                              ),
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: _ringStroke,
                                backgroundColor: Colors.grey.shade800,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _dayFont,
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
