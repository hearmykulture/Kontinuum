import 'package:flutter/foundation.dart'; // ValueListenable, ValueNotifier
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Immutable value for task options.
class TaskOptionsValue {
  final DateTime? date; // null => No Date (or Someday if [someday] true)
  final bool someday; // explicitly Someday
  final bool repeatsDaily; // repeat on completion (daily)
  final bool hasReminder;
  final bool hasDeadline;

  const TaskOptionsValue({
    this.date,
    this.someday = false,
    this.repeatsDaily = false,
    this.hasReminder = false,
    this.hasDeadline = false,
  });

  TaskOptionsValue copyWith({
    DateTime? date,
    bool? someday,
    bool? repeatsDaily,
    bool? hasReminder,
    bool? hasDeadline,
  }) {
    return TaskOptionsValue(
      date: date ?? this.date,
      someday: someday ?? this.someday,
      repeatsDaily: repeatsDaily ?? this.repeatsDaily,
      hasReminder: hasReminder ?? this.hasReminder,
      hasDeadline: hasDeadline ?? this.hasDeadline,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskOptionsValue &&
      other.date == date &&
      other.someday == someday &&
      other.repeatsDaily == repeatsDaily &&
      other.hasReminder == hasReminder &&
      other.hasDeadline == hasDeadline;

  @override
  int get hashCode =>
      Object.hash(date, someday, repeatsDaily, hasReminder, hasDeadline);
}

/// Controller so parent can read/write options.
/// Exposes field-level ValueNotifiers for granular rebuilds while
/// maintaining the original `.value` API for compatibility.
class TaskOptionsController extends ChangeNotifier {
  TaskOptionsController([TaskOptionsValue? initial])
    : dateN = ValueNotifier<DateTime?>(initial?.date),
      somedayN = ValueNotifier<bool>(initial?.someday ?? false),
      repeatsDailyN = ValueNotifier<bool>(initial?.repeatsDaily ?? false),
      hasReminderN = ValueNotifier<bool>(initial?.hasReminder ?? false),
      hasDeadlineN = ValueNotifier<bool>(initial?.hasDeadline ?? false) {
    // Relay field changes to external listeners (without flooding).
    void relay() {
      if (_squelch) return;
      notifyListeners();
    }

    for (final ln in _allNotifiers) {
      ln.addListener(relay);
    }
  }

  // Field-level notifiers
  final ValueNotifier<DateTime?> dateN;
  final ValueNotifier<bool> somedayN;
  final ValueNotifier<bool> repeatsDailyN;
  final ValueNotifier<bool> hasReminderN;
  final ValueNotifier<bool> hasDeadlineN;

  Iterable<Listenable> get _allNotifiers => <Listenable>[
    dateN,
    somedayN,
    repeatsDailyN,
    hasReminderN,
    hasDeadlineN,
  ];

  bool _squelch = false;

  TaskOptionsValue get value => TaskOptionsValue(
    date: dateN.value,
    someday: somedayN.value,
    repeatsDaily: repeatsDailyN.value,
    hasReminder: hasReminderN.value,
    hasDeadline: hasDeadlineN.value,
  );

  set value(TaskOptionsValue v) {
    _squelch = true;
    _setIfChanged(dateN, v.date);
    _setIfChanged(somedayN, v.someday);
    _setIfChanged(repeatsDailyN, v.repeatsDaily);
    _setIfChanged(hasReminderN, v.hasReminder);
    _setIfChanged(hasDeadlineN, v.hasDeadline);
    _squelch = false;
    notifyListeners(); // single batched tick
  }

  void update(TaskOptionsValue Function(TaskOptionsValue) fn) {
    value = fn(value);
  }

  static void _setIfChanged<T>(ValueNotifier<T> n, T newV) {
    if (n.value != newV) n.value = newV;
  }

  @override
  void dispose() {
    // Also dispose our notifiers for cleanliness.
    dateN.dispose();
    somedayN.dispose();
    repeatsDailyN.dispose();
    hasReminderN.dispose();
    hasDeadlineN.dispose();
    super.dispose();
  }
}

/// Compact, rounded panel with the three stacked rows.
class TaskOptionsPanel extends StatelessWidget {
  const TaskOptionsPanel({super.key, required this.controller});
  final TaskOptionsController controller;

  static bool _sameYMD(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateTitle(DateTime? date, bool someday) {
    if (someday) return 'Someday';
    if (date == null) return 'No Date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dOnly = DateTime(date.year, date.month, date.day);
    if (_sameYMD(dOnly, today)) return 'Today';
    return DateFormat('EEE, MMM d').format(date);
  }

  Future<void> _openMiniCalendar(BuildContext context) async {
    final v = controller.value;
    final r = await showModalBottomSheet<DateSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF171B21),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => MiniCalendarSheet(
        initialDate: v.someday ? null : v.date,
        initialRepeatsDaily: v.repeatsDaily,
      ),
    );
    if (r != null) {
      // Batch update to minimize rebuilds.
      controller.value = v.copyWith(
        date: r.someday ? null : r.date,
        someday: r.someday,
        repeatsDaily: r.repeatsDaily,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RoundedGroup(
      radius: 16,
      children: [
        // Row 1: Date + Repeats
        ValueListenableBuilder2<DateTime?, bool>(
          first: controller.dateN,
          second: controller.somedayN,
          builder: (_, date, someday, __) {
            final title = _dateTitle(date, someday);
            return ValueListenableBuilder<bool>(
              valueListenable: controller.repeatsDailyN,
              builder: (_, repeats, __) => _RowTile(
                title: title,
                subtitle: repeats ? 'Repeats every day' : 'Repeats never',
                trailingIcon: Icons.calendar_month_rounded,
                onTap: () => _openMiniCalendar(context),
              ),
            );
          },
        ),
        const _DividerRow(),

        // Row 2: Reminders
        ValueListenableBuilder<bool>(
          valueListenable: controller.hasReminderN,
          builder: (_, hasReminder, __) => _RowTile(
            title: hasReminder ? 'Has Reminders' : 'No Reminders',
            trailingIcon: Icons.notifications_rounded,
            onTap: () => controller.hasReminderN.value = !hasReminder,
          ),
        ),
        const _DividerRow(),

        // Row 3: Deadline
        ValueListenableBuilder<bool>(
          valueListenable: controller.hasDeadlineN,
          builder: (_, hasDeadline, __) => _RowTile(
            title: hasDeadline ? 'Has Deadline' : 'No Deadline',
            trailingIcon: Icons.hourglass_bottom_rounded,
            onTap: () => controller.hasDeadlineN.value = !hasDeadline,
          ),
        ),
      ],
    );
  }
}

/* ---------------- Mini Calendar (responsive) ---------------- */

class DateSheetResult {
  final DateTime? date;
  final bool repeatsDaily;
  final bool someday;
  const DateSheetResult({
    required this.date,
    required this.repeatsDaily,
    required this.someday,
  });
}

class MiniCalendarSheet extends StatefulWidget {
  const MiniCalendarSheet({
    super.key,
    required this.initialDate,
    required this.initialRepeatsDaily,
  });

  final DateTime? initialDate;
  final bool initialRepeatsDaily;

  @override
  State<MiniCalendarSheet> createState() => _MiniCalendarSheetState();
}

class _MiniCalendarSheetState extends State<MiniCalendarSheet> {
  late DateTime _visibleMonth; // 1st of month
  late List<DateTime> _visibleDays; // cached 6×7 grid for _visibleMonth
  DateTime? _selected;
  bool _repeatsDaily = false;

  // Cached Intl formatters (Intl objects are relatively heavy)
  late final DateFormat _eeeFmt = DateFormat.EEEE();
  late final DateFormat _mmmFmt = DateFormat.MMM();
  late final DateFormat _mmmmFmt = DateFormat.MMMM();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _repeatsDaily = widget.initialRepeatsDaily;
    final base = _selected ?? DateTime.now();
    _visibleMonth = DateTime(base.year, base.month, 1);
    _visibleDays = _daysForMonth(_visibleMonth);
  }

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
      _visibleDays = _daysForMonth(_visibleMonth);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
      _visibleDays = _daysForMonth(_visibleMonth);
    });
  }

  static List<DateTime> _daysForMonth(DateTime month) {
    final first = month;
    // Start week on Sunday: weekday 1..7 (Mon..Sun) → 0..6 offset
    final start = first.subtract(Duration(days: (first.weekday % 7)));
    return List<DateTime>.generate(
      42,
      (i) => DateTime(start.year, start.month, start.day + i),
      growable: false,
    );
  }

  String _header() {
    final d = _selected ?? DateTime.now();
    return '${_eeeFmt.format(d).toUpperCase()} ${_mmmFmt.format(d).toUpperCase()} ${d.day}';
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final todayDT = DateTime.now();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _header(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _mmmmFmt.format(_visibleMonth).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 6, 22, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DOW('S'),
                _DOW('M'),
                _DOW('T'),
                _DOW('W'),
                _DOW('T'),
                _DOW('F'),
                _DOW('S'),
              ],
            ),
          ),

          // Grid expands to fill remaining space; scrolls if tight.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: _visibleDays.length,
                itemBuilder: (_, i) {
                  final d = _visibleDays[i];
                  final inMonth = d.month == _visibleMonth.month;
                  final isSelected =
                      _selected != null && _isSameDay(d, _selected!);
                  final isToday = _isSameDay(d, todayDT);

                  final Color bg = isSelected
                      ? Colors.white
                      : (inMonth
                            ? const Color(0xFF222831)
                            : const Color(0x44222831));
                  final Color fg = isSelected ? Colors.black : Colors.white;

                  return GestureDetector(
                    onTap: () => setState(() => _selected = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: isToday && !isSelected
                            ? Border.all(color: Colors.white, width: 1.2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          color: inMonth ? fg : fg.withOpacity(0.5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Repeat toggle
          GestureDetector(
            onTap: () => setState(() => _repeatsDaily = !_repeatsDaily),
            child: Column(
              children: [
                AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: _repeatsDaily ? 0.25 : 0.0,
                  child: const Icon(Icons.sync, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 8),
                Text(
                  _repeatsDaily ? 'Repeats every day' : 'Repeats are off',
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Bottom action chips + safe-area padding
          Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, bottomPad + 18),
            child: Row(
              children: [
                _ChipBtn(
                  label: 'DATE',
                  filled: true,
                  onTap: () => Navigator.pop(
                    context,
                    DateSheetResult(
                      date: _selected ?? DateTime.now(),
                      repeatsDaily: _repeatsDaily,
                      someday: false,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const _ChipBtn(label: 'NO DATE').wrapOnTap(() {
                  Navigator.pop(
                    context,
                    const DateSheetResult(
                      date: null,
                      repeatsDaily: false,
                      someday: false,
                    ),
                  );
                }),
                const SizedBox(width: 10),
                const _ChipBtn(label: 'SOMEDAY').wrapOnTap(() {
                  Navigator.pop(
                    context,
                    const DateSheetResult(
                      date: null,
                      repeatsDaily: false,
                      someday: true,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Small UI bits (local to the panel) ---------------- */

class _RoundedGroup extends StatelessWidget {
  const _RoundedGroup({required this.children, this.radius = 20});
  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(children: children),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.title,
    this.subtitle,
    required this.trailingIcon,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(trailingIcon, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerRow extends StatelessWidget {
  const _DividerRow();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0x14FFFFFF),
      indent: 14,
      endIndent: 14,
    );
  }
}

class _DOW extends StatelessWidget {
  const _DOW(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Text(
    t,
    style: const TextStyle(
      color: Color(0xCCFFFFFF),
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
}

class _ChipBtn extends StatelessWidget {
  const _ChipBtn({required this.label, this.onTap, this.filled = false});
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? Colors.white : const Color(0x33222222);
    final fg = filled ? Colors.black : Colors.white;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- Tiny helpers ---------- */

/// Listen to two ValueListenables at once with tight rebuild scope.
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, child) => builder(context, a, b, child),
        );
      },
    );
  }
}

/// Syntactic sugar to attach onTap to const widgets without rebuilding callers.
extension _InkTap on Widget {
  Widget wrapOnTap(VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: this,
  );
}
