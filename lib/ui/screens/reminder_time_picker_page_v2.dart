import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // ValueListenable, ValueNotifier
import 'package:intl/intl.dart';

// Hook into your calendar/store models
import 'package:kontinuum/ui/screens/day_detail_page.dart'
    show DayPlanStore, Reminder;

// Popup day→hour sheet (now returns DateTimeRange-like with start/end DateTimes)
import 'package:kontinuum/ui/widgets/mini_day_hour_sheet.dart' as dh;

// Date-only mini calendar (kept for ALL DAY flow)
import 'package:kontinuum/ui/widgets/mini_calendar_sheet.dart' as sheet;

// ===== Tokens =====
const _bg = Color(0xFF4B0B19);
const _pill = Color(0xFF6A2531);
const _pillOverlay = Color(0x22FFFFFF);
const _segBg = Color(0xFF5A1E29);
const _segOn = Color(0xFF7E2E3C);
const double _kBarH = 44; // Cancel/Done bar height

class EmptyReminderTimePage extends StatefulWidget {
  const EmptyReminderTimePage({
    super.key,
    this.day,
    this.existing, // open an existing reminder (single slice)
    this.autofocusTitle = true,
    this.showDelete = false,
  });

  /// Optional: which day this reminder belongs to (date-only). Defaults to today.
  final DateTime? day;

  final Reminder? existing;
  final bool autofocusTitle;
  final bool showDelete;

  @override
  State<EmptyReminderTimePage> createState() => _EmptyReminderTimePageState();
}

class _EmptyReminderTimePageState extends State<EmptyReminderTimePage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _popped = false;

  // Cached formatters (intl objects are relatively heavy).
  late final DateFormat _dateFmt = DateFormat('EEE MMM d');
  late final DateFormat _timeFmt = DateFormat('hh:mm a');

  // Reactive state: use ValueNotifiers so only small parts rebuild.
  late final ValueNotifier<DateTime> _startN;
  late final ValueNotifier<DateTime> _endN;
  late final ValueNotifier<DateTime> _dayN;
  late final ValueNotifier<bool> _allDayN;

  // Anchors for popovers
  final _startPillKey = GlobalKey();
  final _endPillKey = GlobalKey();

  DateTime get _start => _startN.value;
  set _start(DateTime v) => _startN.value = v;

  DateTime get _end => _endN.value;
  set _end(DateTime v) => _endN.value = v;

  DateTime get _day => _dayN.value;
  set _day(DateTime v) => _dayN.value = v;

  bool get _allDay => _allDayN.value;
  set _allDay(bool v) => _allDayN.value = v;

  @override
  void initState() {
    super.initState();

    final anchor = widget.day ?? DateTime.now();
    final initialDay = DateTime(anchor.year, anchor.month, anchor.day);

    // Defaults: 9–10 AM
    final defaultStart = DateTime(
      initialDay.year,
      initialDay.month,
      initialDay.day,
      9,
      0,
    );
    final defaultEnd = DateTime(
      initialDay.year,
      initialDay.month,
      initialDay.day,
      10,
      0,
    );

    _startN = ValueNotifier<DateTime>(defaultStart);
    _endN = ValueNotifier<DateTime>(defaultEnd);
    _dayN = ValueNotifier<DateTime>(initialDay);
    _allDayN = ValueNotifier<bool>(false);

    if (widget.existing != null) {
      _ctrl.text = widget.existing!.title;
      _prefillFromSlice(widget.existing!);
    }

    // One-time keyboard open; only if desired
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autofocusTitle) _requestKeyboard();
    });
  }

  void _prefillFromSlice(Reminder slice) {
    final anchorDay = _day; // already date-only
    final allDay = slice.start == null && slice.end == null;
    _allDay = allDay;

    if (allDay) {
      _start = DateTime(anchorDay.year, anchorDay.month, anchorDay.day, 0, 0);
      _end = DateTime(anchorDay.year, anchorDay.month, anchorDay.day, 23, 59);
    } else {
      final s = slice.start!;
      final endTOD = slice.end ?? TimeOfDay(hour: s.hour + 1, minute: s.minute);
      _start = DateTime(
        anchorDay.year,
        anchorDay.month,
        anchorDay.day,
        s.hour,
        s.minute,
      );
      var computedEnd = DateTime(
        anchorDay.year,
        anchorDay.month,
        anchorDay.day,
        endTOD.hour,
        endTOD.minute,
      );
      if (!computedEnd.isAfter(_start))
        computedEnd = _start.add(const Duration(hours: 1));
      _end = computedEnd;
    }
  }

  void _requestKeyboard() {
    _focus.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _closeOnce() {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(); // cancel, no save
  }

  void _deleteOnce() {
    if (_popped) return;
    if (widget.existing != null) {
      DayPlanStore.I.removeReminderGroup(widget.existing!.groupId);
    }
    _popped = true;
    Navigator.of(context).pop();
  }

  String _dateLabel(DateTime d) => _dateFmt.format(d).toUpperCase();
  String _timeLabel(DateTime d) =>
      _timeFmt.format(d).replaceAll(' ', '\u00A0'); // no wrap

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Rect _rectFor(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return Rect.zero;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return Rect.zero;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  // ---------- Pickers ----------

  /// ALL DAY: pick date only for start/end. Updates via notifiers for minimal rebuilds.
  Future<void> _pickAllDayDateOnly(bool forStart) async {
    final baseline = _day;
    final first = DateTime(baseline.year - 2, 1, 1);
    final last = DateTime(baseline.year + 2, 12, 31);

    final anchorRect = _rectFor(forStart ? _startPillKey : _endPillKey);

    void handle(DateTime d) {
      // function declaration for linter
      final picked = _dateOnly(d);
      if (forStart) {
        _start = DateTime(picked.year, picked.month, picked.day, 0, 0);
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(days: 1));
        }
      } else {
        _end = DateTime(picked.year, picked.month, picked.day, 23, 59);
        if (!_end.isAfter(_start)) {
          final s = _end.subtract(const Duration(days: 1));
          _start = DateTime(s.year, s.month, s.day, 0, 0);
        }
      }
      _day = _dateOnly(_start);
    }

    if (anchorRect == Rect.zero) {
      await sheet.MiniCalendarSheet.show(
        context,
        initialDate: forStart ? _start : _end,
        firstDate: first,
        lastDate: last,
        onSelected: handle,
      );
    } else {
      await sheet.MiniCalendarSheet.showAnchored(
        context,
        anchorRect: anchorRect,
        initialDate: forStart ? _start : _end,
        firstDate: first,
        lastDate: last,
        onSelected: handle,
      );
    }

    if (widget.autofocusTitle) _requestKeyboard();
  }

  /// Start: day→hour popup (returns DateTimeRange-like)
  Future<void> _pickStartDayHour() async {
    final baseline = _day;
    final first = DateTime(baseline.year - 2, 1, 1);
    final last = DateTime(baseline.year + 2, 12, 31);

    final range = await dh.MiniDayHourSheet.show(
      context,
      initialStart: _start,
      initialEnd: _end,
      firstDate: first,
      lastDate: last,
      onSelected: (_) {},
    );

    if (range != null) {
      _start = range.start;
      _end = range.end.isAfter(range.start)
          ? range.end
          : range.start.add(const Duration(hours: 1));
      _day = _dateOnly(_start);
    }
    if (widget.autofocusTitle) _requestKeyboard();
  }

  /// End: day→hour popup (returns DateTimeRange-like)
  Future<void> _pickEndDayHour() async {
    final baseline = _day;
    final first = DateTime(baseline.year - 2, 1, 1);
    final last = DateTime(baseline.year + 2, 12, 31);

    final range = await dh.MiniDayHourSheet.show(
      context,
      initialStart: _start,
      initialEnd: _end,
      firstDate: first,
      lastDate: last,
      onSelected: (_) {},
    );

    if (range != null) {
      _start = range.start;
      _end = range.end.isAfter(range.start)
          ? range.end
          : range.start.add(const Duration(hours: 1));
    }
    if (widget.autofocusTitle) _requestKeyboard();
  }

  // ---------- Save (slices multi-day into per-day entries) ----------

  void _saveOnce() {
    if (_popped) return;
    final title = _ctrl.text.trim().isEmpty ? 'Reminder' : _ctrl.text.trim();

    // Normalize
    DateTime start = _start;
    DateTime end = _end;
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));

    // Build all day slices
    final startDay = _dateOnly(start);
    final endDay = _dateOnly(end);
    final totalDays = endDay.difference(startDay).inDays;

    // Use existing groupId when editing; otherwise create a brand new group id.
    final groupId = widget.existing?.groupId ?? _newGroupId();

    // When editing, remove the entire group first (so we don't leave orphans).
    if (widget.existing != null) {
      DayPlanStore.I.removeReminderGroup(widget.existing!.groupId);
    }

    // Create per-day slices so existing store/timeline just works.
    for (int i = 0; i <= totalDays; i++) {
      final d = startDay.add(Duration(days: i));

      TimeOfDay? segStart;
      TimeOfDay? segEnd;

      if (_allDay) {
        segStart = null;
        segEnd = null;
      } else {
        if (i == 0 && i == totalDays) {
          // single-day
          segStart = TimeOfDay(hour: start.hour, minute: start.minute);
          segEnd = TimeOfDay(hour: end.hour, minute: end.minute);
        } else if (i == 0) {
          // first day → until end of day
          segStart = TimeOfDay(hour: start.hour, minute: start.minute);
          segEnd = const TimeOfDay(hour: 23, minute: 59);
        } else if (i == totalDays) {
          // last day → from start of day
          segStart = const TimeOfDay(hour: 0, minute: 0);
          segEnd = TimeOfDay(hour: end.hour, minute: end.minute);
        } else {
          // middle day → full day
          segStart = const TimeOfDay(hour: 0, minute: 0);
          segEnd = const TimeOfDay(hour: 23, minute: 59);
        }
      }

      final slice = Reminder(
        id: UniqueKey().toString(), // independent slice id
        title: title,
        start: segStart,
        end: segEnd,
        groupId: groupId, // keep slices linked
      );

      DayPlanStore.I.addReminder(d, slice);
    }

    _popped = true;
    Navigator.of(context).pop(); // store already updated
  }

  // Local group id generator
  String _newGroupId() =>
      'grp_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${UniqueKey()}';

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _startN.dispose();
    _endN.dispose();
    _dayN.dispose();
    _allDayN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets;
    final pad = mq.padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ===== Usable area (excludes keyboard + footer height) =====
          Positioned.fill(
            bottom: insets.bottom + _kBarH,
            child: SafeArea(
              top: true,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  final caretY = box.maxHeight * 0.20;
                  return Stack(
                    children: [
                      // Caret / name field
                      Positioned(
                        top: caretY,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _NameField(
                              controller: _ctrl,
                              focusNode: _focus,
                              onDone: _saveOnce,
                              autofocus: widget.autofocusTitle,
                            ),
                          ),
                        ),
                      ),

                      // Close / Delete
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showDelete && widget.existing != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                tooltip: 'Delete',
                                onPressed: _deleteOnce,
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              tooltip: 'Close',
                              onPressed: _closeOnce,
                            ),
                          ],
                        ),
                      ),

                      // Middle content
                      Align(
                        alignment: const Alignment(0, 0.18),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child:
                                          ValueListenableBuilder2<
                                            bool,
                                            DateTime
                                          >(
                                            first: _allDayN,
                                            second: _startN,
                                            builder: (_, allDay, start, __) {
                                              return _TimePill(
                                                key: _startPillKey,
                                                dateTop: _dateLabel(start),
                                                timeBottom: allDay
                                                    ? 'ALL DAY'
                                                    : _timeLabel(start),
                                                onTapDate: allDay
                                                    ? () => _pickAllDayDateOnly(
                                                        true,
                                                      )
                                                    : _pickStartDayHour,
                                                onTapTime: _pickStartDayHour,
                                                timeDisabled: allDay,
                                              );
                                            },
                                          ),
                                    ),
                                    const SizedBox(width: 12),
                                    const _ArrowPill(),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child:
                                          ValueListenableBuilder2<
                                            bool,
                                            DateTime
                                          >(
                                            first: _allDayN,
                                            second: _endN,
                                            builder: (_, allDay, end, __) {
                                              return _TimePill(
                                                key: _endPillKey,
                                                dateTop: _dateLabel(end),
                                                timeBottom: allDay
                                                    ? 'ALL DAY'
                                                    : _timeLabel(end),
                                                onTapDate: allDay
                                                    ? () => _pickAllDayDateOnly(
                                                        false,
                                                      )
                                                    : _pickEndDayHour,
                                                onTapTime: _pickEndDayHour,
                                                timeDisabled: allDay,
                                              );
                                            },
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                ValueListenableBuilder<bool>(
                                  valueListenable: _allDayN,
                                  builder: (_, allDay, __) => _Segmented(
                                    leftLabel: 'SET TIME',
                                    rightLabel: 'ALL DAY',
                                    valueRight: allDay,
                                    onChanged: (v) => _allDay = v,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ===== Footer =====
          Positioned(
            left: 0,
            right: 0,
            bottom: insets.bottom,
            child: Container(
              height: _kBarH + pad,
              color: Colors.black,
              padding: EdgeInsets.only(left: 16, right: 16, bottom: pad),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeOnce,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saveOnce,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Name field =====
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.onDone,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDone;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      textAlign: TextAlign.center,
      cursorColor: Colors.white,
      cursorWidth: 3,
      cursorHeight: 48,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: '',
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onDone(),
      onEditingComplete: onDone,
      onTapOutside: (_) => focusNode.requestFocus(),
    );
  }
}

// ===== Sub-widgets =====

class _TimePill extends StatelessWidget {
  const _TimePill({
    super.key,
    required this.dateTop,
    required this.timeBottom,
    required this.onTapDate,
    required this.onTapTime,
    this.timeDisabled = false,
  });

  final String dateTop;
  final String timeBottom;
  final VoidCallback onTapDate;
  final VoidCallback onTapTime;
  final bool timeDisabled;

  @override
  Widget build(BuildContext context) {
    final timeColor = timeDisabled
        ? Colors.white.withOpacity(0.55)
        : Colors.white;

    return Container(
      height: 108,
      decoration: BoxDecoration(
        color: _pill,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            offset: Offset(0, 8),
            color: Colors.black26,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // sheen
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 44,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  color: _pillOverlay,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // date line → open calendar
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTapDate,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      dateTop,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // time line → open hour grid (disabled in ALL DAY)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: timeDisabled ? null : onTapTime,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      timeBottom,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: timeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPill extends StatelessWidget {
  const _ArrowPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: 44,
      decoration: BoxDecoration(
        color: _pill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Icon(
          Icons.arrow_right_alt_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.leftLabel,
    required this.rightLabel,
    required this.valueRight,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool valueRight;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _segBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _SegButton(
            label: leftLabel,
            selected: !valueRight,
            onTap: () => onChanged(false),
          ),
          _SegButton(
            label: rightLabel,
            selected: valueRight,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? _segOn : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(selected ? 1.0 : 0.8),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to listen to two ValueListenables at once with tight rebuild scope.
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
