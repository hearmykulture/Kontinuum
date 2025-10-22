import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/ui/screens/task_editor/models.dart';

/* ──────────────────────────────────────────────────────────────
   TASK OPTIONS PANEL (Date/Reminder/Deadline + inline Stat picker)
   ────────────────────────────────────────────────────────────── */

class TaskOptionsPanel extends StatefulWidget {
  const TaskOptionsPanel({super.key, required this.controller});
  final TaskOptionsController controller;

  @override
  State<TaskOptionsPanel> createState() => _TaskOptionsPanelState();
}

class _TaskOptionsPanelState extends State<TaskOptionsPanel> {
  bool _statExpanded = false;

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
    final v = widget.controller.value;
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
      widget.controller.value = v.copyWith(
        date: r.someday ? null : r.date,
        someday: r.someday,
        repeatsDaily: r.repeatsDaily,
      );
    }
  }

  String _statsSummary(List<StatPick> picks) {
    if (picks.isEmpty) return 'No Stats';
    final parts = <String>[];
    for (final p in picks.take(2)) {
      parts.add('${StatRepository.getDisplay(p.id)} ×${p.amount}');
    }
    final extra = picks.length - 2;
    return extra > 0 ? '${parts.join(", ")} +$extra more' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return RoundedGroup(
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
              builder: (_, repeats, __) => RowTile(
                title: title,
                subtitle: repeats ? 'Repeats every day' : 'Repeats never',
                trailingIcon: Icons.calendar_month_rounded,
                onTap: () => _openMiniCalendar(context),
              ),
            );
          },
        ),
        const DividerRow(),

        // Row 2: Reminders
        ValueListenableBuilder<bool>(
          valueListenable: controller.hasReminderN,
          builder: (_, hasReminder, __) => RowTile(
            title: hasReminder ? 'Has Reminders' : 'No Reminders',
            trailingIcon: Icons.notifications_rounded,
            onTap: () => controller.hasReminderN.value = !hasReminder,
          ),
        ),
        const DividerRow(),

        // Row 3: Deadline
        ValueListenableBuilder<bool>(
          valueListenable: controller.hasDeadlineN,
          builder: (_, hasDeadline, __) => RowTile(
            title: hasDeadline ? 'Has Deadline' : 'No Deadline',
            trailingIcon: Icons.hourglass_bottom_rounded,
            onTap: () => controller.hasDeadlineN.value = !hasDeadline,
          ),
        ),
        const DividerRow(),

        // Row 4: Stats (multi-select, expands inline)
        ValueListenableBuilder<List<StatPick>>(
          valueListenable: controller.statsN,
          builder: (_, picks, __) => RowTile(
            title: _statsSummary(picks),
            trailingIcon: Icons.trending_up_rounded,
            onTap: () => setState(() => _statExpanded = !_statExpanded),
          ),
        ),

        // Expand/collapse with stable layout
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _statExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: StatPicker(
            key: const ValueKey('picker'),
            controller: controller,
            onClose: () => setState(() => _statExpanded = false),
          ),
          secondChild: const SizedBox.shrink(key: ValueKey('empty')),
          sizeCurve: Curves.easeOut,
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
    final start = first.subtract(Duration(days: first.weekday % 7));
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
                const Spacer(),
                Text(
                  _mmmmFmt.format(_visibleMonth).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
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
                DOWLabel('S'),
                DOWLabel('M'),
                DOWLabel('T'),
                DOWLabel('W'),
                DOWLabel('T'),
                DOWLabel('F'),
                DOWLabel('S'),
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
                          color: inMonth ? fg : fg.withValues(alpha: 0.5),
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
              children: const [
                Icon(Icons.sync, color: Colors.white, size: 42),
                SizedBox(height: 8),
              ],
            ),
          ),
          // Label
          Text(
            _repeatsDaily ? 'Repeats every day' : 'Repeats are off',
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontWeight: FontWeight.w600,
            ),
          ),

          // Bottom action chips + safe-area padding
          Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, bottomPad + 18),
            child: Row(
              children: [
                ChipBtn(
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
                ChipBtn(
                  label: 'NO DATE',
                  onTap: () {
                    Navigator.pop(
                      context,
                      const DateSheetResult(
                        date: null,
                        repeatsDaily: false,
                        someday: false,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                ChipBtn(
                  label: 'SOMEDAY',
                  onTap: () {
                    Navigator.pop(
                      context,
                      const DateSheetResult(
                        date: null,
                        repeatsDaily: false,
                        someday: true,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Small UI bits (local to the panel) ---------------- */

class RoundedGroup extends StatelessWidget {
  const RoundedGroup({super.key, required this.children, this.radius = 20});
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

class RowTile extends StatelessWidget {
  const RowTile({
    super.key,
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

class DividerRow extends StatelessWidget {
  const DividerRow({super.key});

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

class DOWLabel extends StatelessWidget {
  const DOWLabel(this.t, {super.key});
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

class ChipBtn extends StatelessWidget {
  const ChipBtn(
      {super.key, required this.label, this.onTap, this.filled = false});
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

/* ───────────────────────────────
   STAT PICKER (inline, multi-select)
   ─────────────────────────────── */

class StatPicker extends StatefulWidget {
  const StatPicker(
      {super.key, required this.controller, required this.onClose});
  final TaskOptionsController controller;
  final VoidCallback onClose;

  @override
  State<StatPicker> createState() => _StatPickerState();
}

// Typed view of repository items (no unnecessary casts)
class _StatLite {
  final String id;
  final String display;
  final String categoryId;
  const _StatLite(
      {required this.id, required this.display, required this.categoryId});
}

class _StatPickerState extends State<StatPicker> {
  String? _categoryFilter; // null => ALL
  final Map<String, TextEditingController> _customCtrls = {};
  final Map<String, FocusNode> _customFocus = {};

  final ScrollController _catCtrl = ScrollController();
  final Map<String, GlobalKey> _catKeys = {};
  GlobalKey _keyFor(String? id) =>
      _catKeys.putIfAbsent(id ?? '__ALL__', () => GlobalKey());

  List<String> get _categories {
    final all = StatRepository.getAll();
    final set = <String>{};
    for (final m in all) {
      set.add(m.categoryId);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<_StatLite> _fetchStats() {
    final raw = _categoryFilter == null
        ? StatRepository.getAll()
        : StatRepository.getByCategory(_categoryFilter!);
    return raw
        .map<_StatLite>((s) => _StatLite(
              id: s.id,
              display: s.display,
              categoryId: s.categoryId,
            ))
        .toList(growable: false);
  }

  TextEditingController _ctrlFor(String id, int initial) => _customCtrls
      .putIfAbsent(id, () => TextEditingController(text: '$initial'));
  FocusNode _focusFor(String id) =>
      _customFocus.putIfAbsent(id, () => FocusNode());

  @override
  void dispose() {
    for (final c in _customCtrls.values) {
      c.dispose();
    }
    for (final f in _customFocus.values) {
      f.dispose();
    }
    _catCtrl.dispose();
    super.dispose();
  }

  void _scrollToCategory(String? id) {
    final key = _keyFor(id);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        alignment: 0.35,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _fetchStats();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filter (animated scroll to selection)
          SingleChildScrollView(
            controller: _catCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6),
            child: Row(
              children: [
                KeyedSubtree(
                  key: _keyFor(null),
                  child: CatChip(
                    label: 'ALL',
                    selected: _categoryFilter == null,
                    onTap: () {
                      setState(() => _categoryFilter = null);
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToCategory(null));
                    },
                  ),
                ),
                const SizedBox(width: 6),
                ..._categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: KeyedSubtree(
                      key: _keyFor(c),
                      child: CatChip(
                        label: c,
                        selected: _categoryFilter == c,
                        onTap: () {
                          setState(() => _categoryFilter = c);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToCategory(c),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- Stat chips grid (typed; always paints) ----
          _StatsGridAnimated(
            categoryKey: ValueKey<String>(_categoryFilter ?? 'ALL'),
            stats: stats,
            controller: widget.controller,
          ),

          const SizedBox(height: 8),

          // Selected stat editors + label
          ValueListenableBuilder<List<StatPick>>(
            valueListenable: widget.controller.statsN,
            builder: (_, picks, __) {
              if (picks.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      'XP Reward',
                      style: TextStyle(
                        color: Color(0x99FFFFFF),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...picks.map((p) {
                    final disp = StatRepository.getDisplay(p.id);
                    final textCtrl = _ctrlFor(p.id, p.amount);
                    final desired = '${p.amount}';
                    if (textCtrl.text != desired) {
                      textCtrl.text = desired;
                      textCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: textCtrl.text.length),
                      );
                    }
                    final focus = _focusFor(p.id);

                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _SelectedStatEditor(
                        display: disp,
                        amount: p.amount,
                        controller: textCtrl,
                        focusNode: focus,
                        onAmountChanged: (v) =>
                            widget.controller.setStatAmount(p.id, v),
                        onRemove: () {
                          widget.controller.removeStat(p.id);
                          _customCtrls.remove(p.id)?.dispose();
                          _customFocus.remove(p.id)?.dispose();
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Ensures the grid always paints a visible, sized widget (fixes “invisible chips”).
class _StatsGridAnimated extends StatelessWidget {
  const _StatsGridAnimated({
    required this.categoryKey,
    required this.stats,
    required this.controller,
  });

  final Key categoryKey;
  final List<_StatLite> stats;
  final TaskOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final Widget gridChild = stats.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No stats in this category',
              style: TextStyle(color: Color(0x66FFFFFF), fontSize: 13),
            ),
          )
        : Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in stats)
                  ValueListenableBuilder<List<StatPick>>(
                    valueListenable: controller.statsN,
                    builder: (_, picks, __) {
                      final isSelected = picks.any((p) => p.id == s.id);
                      return StatChip(
                        label: s.display,
                        selected: isSelected,
                        onTap: () => controller.toggleStat(s.id),
                        compact: true,
                      );
                    },
                  ),
              ],
            ),
          );

    // Fade + slight slide; wrapped in Column to give layout height.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, .05),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: categoryKey,
        child: gridChild,
      ),
    );
  }
}

class _SelectedStatEditor extends StatelessWidget {
  const _SelectedStatEditor({
    required this.display,
    required this.amount,
    required this.controller,
    required this.focusNode,
    required this.onAmountChanged,
    required this.onRemove,
  });

  final String display;
  final int amount;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<int> onAmountChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Row(
          children: [
            Text(
              display,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '×$amount',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Full-width XP slider (1..999 visual range)
        _XpSliderBar(
          value: amount.clamp(1, 999),
          min: 1,
          max: 999,
          onChanged: onAmountChanged,
        ),
        const SizedBox(height: 10),
        // Custom amount + Remove
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF232323),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x22FFFFFF), width: 1),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  // ✅ remove const here (digitsOnly is not const)
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'Custom XP',
                    hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                  ),
                  onChanged: (txt) {
                    if (txt.isEmpty) return;
                    final v = int.tryParse(txt);
                    if (v != null && v > 0) onAmountChanged(v.clamp(1, 999999));
                  },
                  onSubmitted: (txt) {
                    final v = int.tryParse(txt) ?? 1;
                    onAmountChanged(v.clamp(1, 999999));
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              label:
                  const Text('Remove', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

class _XpSliderBar extends StatelessWidget {
  const _XpSliderBar({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final double w = box.maxWidth;

        // Bail out gracefully if we somehow have zero/negative width.
        if (w <= 0) {
          return const SizedBox(height: 34, width: double.infinity);
        }

        final int clamped = value.clamp(min, max);
        final double t =
            (clamped - min) / ((max - min) == 0 ? 1 : (max - min).toDouble());
        final double fillW = (w * t).clamp(0.0, w);
        const double trackH = 14;
        const double thumbR = 10;

        void updateAt(double dx) {
          final double ratio = dx <= 0 ? 0 : (dx >= w ? 1 : dx / w);
          final int next = (min + ratio * (max - min)).round().clamp(min, max);
          onChanged(next);
        }

        // ---- SAFE thumb position (no throwing clamp) ----
        final double upper = w - thumbR * 2;
        final double safeUpper = upper < 0 ? 0.0 : upper; // non-negative
        final double base = fillW - thumbR;
        final double thumbL =
            base < 0.0 ? 0.0 : (base > safeUpper ? safeUpper : base);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => updateAt(d.localPosition.dx),
          onPanUpdate: (d) => updateAt(d.localPosition.dx),
          onTapDown: (d) => updateAt(d.localPosition.dx),
          child: SizedBox(
            height: 34,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: trackH,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(trackH / 2),
                  ),
                ),
                Positioned(
                  left: 0,
                  width: fillW,
                  child: Container(
                    height: trackH,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF3AA2FF),
                          Color(0xFF9E7BFF),
                          Color(0xFFFF6FD8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(trackH / 2),
                    ),
                  ),
                ),
                Positioned(
                  left: thumbL,
                  child: Container(
                    width: thumbR * 2,
                    height: thumbR * 2,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
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
    );
  }
}

class CatChip extends StatelessWidget {
  const CatChip(
      {super.key, required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x33222222),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double padH = compact ? 10 : 12;
    final double padV = compact ? 6 : 8;
    final double radius = compact ? 14 : 16;
    final double fontSize = compact ? 13 : 15;
    final double minH = compact ? 34 : 40;

    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minH),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF232323),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0x22FFFFFF),
            width: 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}
