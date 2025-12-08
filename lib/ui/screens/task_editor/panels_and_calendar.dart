import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/providers/objective_provider.dart';
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
      widget.controller.dateN.value = r.someday ? null : r.date;
      widget.controller.somedayN.value = r.someday;
      widget.controller.repeatsDailyN.value = r.repeatsDaily;
    }
  }

  Future<void> _openDeadlineCalendar(BuildContext context) async {
    final initialDeadline = widget.controller.deadlineN.value;
    final fallback = widget.controller.dateN.value ?? DateTime.now();
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
        initialDate: initialDeadline ?? fallback,
        initialRepeatsDaily: false,
      ),
    );

    if (r != null && r.date != null) {
      widget.controller.deadlineN.value = r.date;
      widget.controller.hasDeadlineN.value = true;
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

        // Row 2: Deadline
        ValueListenableBuilder2<DateTime?, bool>(
          first: controller.deadlineN,
          second: controller.hasDeadlineN,
          builder: (_, deadline, hasDeadline, __) {
            final hasDate = hasDeadline && deadline != null;
            final title = hasDate
                ? 'Due ${_dateTitle(deadline, false)}'
                : 'No Deadline';
            return RowTile(
              title: title,
              subtitle:
                  hasDate ? 'Long-press to clear' : 'Tap to pick a deadline',
              trailingIcon: Icons.hourglass_bottom_rounded,
              onTap: () => _openDeadlineCalendar(context),
              onLongPress: hasDate
                  ? () {
                      controller.deadlineN.value = null;
                      controller.hasDeadlineN.value = false;
                    }
                  : null,
            );
          },
        ),
        const DividerRow(),

        // Row 3: Stats (multi-select, expands inline)
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

  void _closeWithDate(DateTime date) {
    Navigator.of(context).pop(
      DateSheetResult(
        date: date,
        repeatsDaily: _repeatsDaily,
        someday: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayDT = DateTime.now();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          // Grid now shrink-wraps to its content so the sheet height hugs the calendar.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
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
                  onTap: () => _closeWithDate(d),
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

          SizedBox(height: bottomPad + 18),
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
    this.onLongPress,
  });

  final String title;
  final String? subtitle;
  final IconData trailingIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
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
  const StatPicker({super.key, required this.controller});
  final TaskOptionsController controller;

  @override
  State<StatPicker> createState() => _StatPickerState();
}

class _StatLite {
  const _StatLite({
    required this.id,
    required this.display,
    required this.categorySlug,
  });

  final String id;
  final String display;
  final String categorySlug;
}

class _StatPickerState extends State<StatPicker> {
  String? _categoryFilter;
  bool _creatingStat = false;
  bool _creatingSkill = false;

  final ScrollController _catCtrl = ScrollController();
  final Map<String, GlobalKey> _catKeys = {};
  final Map<String, TextEditingController> _customCtrls = {};
  final Map<String, FocusNode> _customFocus = {};

  final TextEditingController _statNameCtrl = TextEditingController();
  final TextEditingController _statDescCtrl = TextEditingController();
  final FocusNode _statNameFocus = FocusNode();
  String? _statCategorySelection;
  String? _statEmojiSelection;
  final Set<String> _statSkillSelections = <String>{};

  final TextEditingController _skillNameCtrl = TextEditingController();
  final FocusNode _skillNameFocus = FocusNode();
  String? _skillCategorySelection;
  String? _skillEmojiSelection;
  Color? _skillColorSelection;
  SkillWeightOption _skillWeight = SkillWeightOption.medium;

  GlobalKey _keyFor(String? id) =>
      _catKeys.putIfAbsent(id ?? '__ALL__', () => GlobalKey());

  List<String> get _categories {
    final statCats = <String>{
      for (final meta in StatRepository.getAll())
        _categorySlug(meta.categoryId),
    };
    final ordered = <String>[];
    final seen = <String>{};
    void push(String slug) {
      if (slug.isEmpty || !seen.add(slug)) return;
      ordered.add(slug);
    }
    for (final slug in _kMissionCategories.keys) {
      push(slug);
    }
    final extras =
        statCats.where((slug) => !seen.contains(slug)).toList()..sort();
    for (final extra in extras) {
      push(extra);
    }
    push('general');
    return ordered;
  }

  List<_StatLite> _fetchStats() {
    final raw = StatRepository.getAll();
    final mapped = raw
        .map<_StatLite>(
          (s) => _StatLite(
            id: s.id,
            display: s.display,
            categorySlug: _categorySlug(s.categoryId),
          ),
        )
        .toList(growable: false);
    if (_categoryFilter == null) return mapped;
    return mapped
        .where((s) => s.categorySlug == _categoryFilter)
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
    _statNameCtrl.dispose();
    _statDescCtrl.dispose();
    _statNameFocus.dispose();
    _skillNameCtrl.dispose();
    _skillNameFocus.dispose();
    super.dispose();
  }

  void _scrollToCategory(String? slug) {
    final key = _keyFor(slug);
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

  void _toggleCreateStat() {
    setState(() {
      _creatingStat = !_creatingStat;
      if (_creatingStat) {
        final fallback =
            _categoryFilter ?? (_categories.isNotEmpty ? _categories.first : null);
        _statCategorySelection =
            _statCategorySelection ?? fallback ?? _kDefaultCategorySlug;
        _statEmojiSelection ??= _kStatEmojiChoices.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _statNameFocus.requestFocus();
        });
      } else {
        _statNameCtrl.clear();
        _statDescCtrl.clear();
        _statCategorySelection = null;
        _statEmojiSelection = null;
        _statSkillSelections.clear();
        _creatingSkill = false;
      }
    });
  }

  void _toggleCreateSkill() {
    setState(() {
      _creatingSkill = !_creatingSkill;
      if (_creatingSkill) {
        final fallback = _skillCategorySelection ??
            _statCategorySelection ??
            _categoryFilter ??
            (_categories.isNotEmpty ? _categories.first : null);
        _skillCategorySelection =
            (fallback ?? _kDefaultCategorySlug).toLowerCase();
        _skillEmojiSelection ??= _kStatEmojiChoices.first;
        _skillColorSelection ??= _kCategoryColorChoices.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _skillNameFocus.requestFocus();
        });
      } else {
        _skillNameCtrl.clear();
        _skillCategorySelection = null;
        _skillEmojiSelection = null;
        _skillColorSelection = null;
        _skillWeight = SkillWeightOption.medium;
      }
    });
  }

  void _handleSaveStat() {
    final provider = context.read<ObjectiveProvider>();
    final name = _statNameCtrl.text.trim();
    final categorySlug =
        _statCategorySelection ?? _categoryFilter ?? _kDefaultCategorySlug;
    final emoji = _statEmojiSelection;
    if (name.isEmpty || categorySlug.isEmpty || emoji == null) {
      _showSnack('Add a name, emoji, and category for the stat.');
      return;
    }

    final statId = _derivedStatId;
    if (provider.stats.containsKey(statId) ||
        StatRepository.getById(statId) != null) {
      _showSnack('A stat with that ID already exists.');
      return;
    }

    final canonicalCategory = _canonicalCategoryId(categorySlug);
    provider.ensureCategoryExists(
      canonicalCategory,
      displayName: _categoryDisplayName(categorySlug),
      colorInt: _categoryColorForAny(categorySlug).toARGB32(),
    );

    final description = _statDescCtrl.text.trim();
    final metadata = StatMetadata(
      id: statId,
      label: name,
      categoryId: canonicalCategory,
      emoji: emoji,
      description: description.isEmpty ? null : description,
    );
    StatRepository.upsert(metadata);

    final statModel = Stat(
      id: statId,
      label: name,
      averageMinutesPerUnit: 1,
      repsForMastery: 1,
      categoryId: canonicalCategory,
      emoji: emoji,
      description: description.isEmpty ? null : description,
    );
    provider.registerStat(statModel);
    if (_statSkillSelections.isNotEmpty) {
      provider.attachStatToSkills(statId, _statSkillSelections);
    }
    provider.persistStats();

    setState(() {
      _creatingStat = false;
      _creatingSkill = false;
      _statNameCtrl.clear();
      _statDescCtrl.clear();
      _statSkillSelections.clear();
      _skillNameCtrl.clear();
      _skillCategorySelection = null;
      _skillEmojiSelection = null;
      _skillColorSelection = null;
      _skillWeight = SkillWeightOption.medium;
      _categoryFilter = _categorySlug(canonicalCategory);
    });

    widget.controller.toggleStat(statId);
    FocusScope.of(context).unfocus();
    _showSnack('Stat saved.');
  }

  void _handleSaveSkill() {
    final provider = context.read<ObjectiveProvider>();
    final name = _skillNameCtrl.text.trim();
    final categorySlug =
        _skillCategorySelection ??
            _statCategorySelection ??
            _categoryFilter ??
            _kDefaultCategorySlug;
    final emoji = _skillEmojiSelection;
    final color = _skillColorSelection;
    if (name.isEmpty || categorySlug.isEmpty || emoji == null || color == null) {
      _showSnack('Fill all fields to save the skill.');
      return;
    }

    final skillId = _derivedSkillId;
    if (provider.skills.containsKey(skillId)) {
      _showSnack('A skill with that ID already exists.');
      return;
    }

    final canonicalCategory = _canonicalCategoryId(categorySlug);
    provider.ensureCategoryExists(
      canonicalCategory,
      displayName: _categoryDisplayName(categorySlug),
      colorInt: color.toARGB32(),
    );

    final skill = Skill(
      id: skillId,
      label: name,
      categoryId: canonicalCategory,
      weight: _weightValue(_skillWeight),
      stats: const [],
    );
    provider.registerSkill(skillId, skill);
    provider.persistSkills();

    setState(() {
      _statSkillSelections.add(skillId);
      _creatingSkill = false;
      _skillNameCtrl.clear();
      _skillCategorySelection = null;
      _skillEmojiSelection = null;
      _skillColorSelection = null;
      _skillWeight = SkillWeightOption.medium;
    });

    FocusScope.of(context).unfocus();
    _showSnack('Skill saved.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _derivedStatId {
    final raw = _statNameCtrl.text.trim().toLowerCase();
    final slug = raw
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp('^_|_\$'), '');
    return slug.isEmpty ? 'new_stat' : slug;
  }

  String get _derivedSkillId {
    final raw = _skillNameCtrl.text.trim().toLowerCase();
    final slug = raw
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp('^_|_\$'), '');
    return slug.isEmpty ? 'new_skill' : slug;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _fetchStats();
    final controller = widget.controller;
    final objectiveProvider = context.watch<ObjectiveProvider>();

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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: child,
              ),
            ),
            child: _creatingStat
                ? KeyedSubtree(
                    key: const ValueKey('stat_form'),
                    child: _StatCreationForm(
                      nameController: _statNameCtrl,
                      descController: _statDescCtrl,
                      focusNode: _statNameFocus,
                      selectedCategory: _statCategorySelection,
                      onCategorySelected: (id) =>
                          setState(() => _statCategorySelection = id),
                      availableSkills:
                          objectiveProvider.skills.values.toList(),
                      selectedSkills: _statSkillSelections,
                      onSkillToggled: (id) {
                        setState(() {
                          if (_statSkillSelections.contains(id)) {
                            _statSkillSelections.remove(id);
                          } else {
                            _statSkillSelections.add(id);
                          }
                        });
                      },
                      selectedEmoji: _statEmojiSelection,
                      onEmojiSelected: (emoji) =>
                          setState(() => _statEmojiSelection = emoji),
                      derivedId: _derivedStatId,
                      onNameChanged: (_) => setState(() {}),
                      onClose: _toggleCreateStat,
                      onSubmit: _handleSaveStat,
                      showSkillComposer: _creatingSkill,
                      onSkillCreateTapped: _toggleCreateSkill,
                      skillComposer: _SkillCreationForm(
                        nameController: _skillNameCtrl,
                        focusNode: _skillNameFocus,
                        derivedId: _derivedSkillId,
                        selectedCategory: _skillCategorySelection,
                        onCategorySelected: (id) =>
                            setState(() => _skillCategorySelection = id),
                        selectedEmoji: _skillEmojiSelection,
                        onEmojiSelected: (emoji) =>
                            setState(() => _skillEmojiSelection = emoji),
                        selectedColor: _skillColorSelection,
                        onColorSelected: (color) =>
                            setState(() => _skillColorSelection = color),
                        selectedWeight: _skillWeight,
                        onWeightChanged: (weight) =>
                            setState(() => _skillWeight = weight),
                        onClose: _toggleCreateSkill,
                        onSubmit: _handleSaveSkill,
                      ),
                    ),
                  )
                : Column(
                    key: const ValueKey('stat_tabs'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        controller: _catCtrl,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(
                          left: 2,
                          right: 2,
                          bottom: 6,
                        ),
                        child: Row(
                          children: [
                            KeyedSubtree(
                              key: _keyFor(null),
                              child: _MissionCatChip(
                                label: 'ALL',
                                selected: _categoryFilter == null,
                                onTap: () {
                                  setState(() => _categoryFilter = null);
                                  WidgetsBinding.instance
                                      .addPostFrameCallback(
                                    (_) => _scrollToCategory(null),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            ..._categories.map(
                              (slug) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: KeyedSubtree(
                                  key: _keyFor(slug),
                                  child: _MissionCatChip(
                                    label: _categoryDisplayName(slug)
                                        .toUpperCase(),
                                    selected: _categoryFilter == slug,
                                    accentColor: _categoryColorForAny(slug),
                                    onTap: () {
                                      setState(() => _categoryFilter = slug);
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                        (_) => _scrollToCategory(slug),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: _MissionCatChip(
                          label: '+ CREATE',
                          selected: false,
                          onTap: _toggleCreateStat,
                        ),
                      ),
                    ],
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !_creatingStat
                ? Column(
                    key: const ValueKey('stat_bank'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 22),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: (currentChild, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (currentChild != null) currentChild,
                          ],
                        ),
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
                          key: ValueKey<String>(_categoryFilter ?? 'ALL'),
                          child: stats.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No stats in this category',
                                    style: TextStyle(
                                      color: Color(0x66FFFFFF),
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final s in stats)
                                      ValueListenableBuilder<List<StatPick>>(
                                        valueListenable: controller.statsN,
                                        builder: (_, picks, __) {
                                          final isSelected = picks
                                              .any((p) => p.id == s.id);
                                          return _MissionStatChip(
                                            label: s.display,
                                            selected: isSelected,
                                            onTap: () =>
                                                controller.toggleStat(s.id),
                                            compact: true,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('stat_bank_empty')),
          ),
          ValueListenableBuilder<List<StatPick>>(
            valueListenable: widget.controller.statsN,
            builder: (_, picks, __) {
              if (picks.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 12, bottom: 6),
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
                    final display = StatRepository.getDisplay(p.id);
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
                        display: display,
                        amount: p.amount,
                        controller: textCtrl,
                        focusNode: focus,
                        onAmountChanged: (value) =>
                            widget.controller.setStatAmount(p.id, value),
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

/* ───────────────────────────────
   Mission stat picker helpers
   ─────────────────────────────── */

class _StatCreationForm extends StatelessWidget {
  const _StatCreationForm({
    required this.nameController,
    required this.descController,
    required this.focusNode,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.availableSkills,
    required this.selectedSkills,
    required this.onSkillToggled,
    required this.selectedEmoji,
    required this.onEmojiSelected,
    required this.derivedId,
    required this.onClose,
    required this.onNameChanged,
    required this.onSubmit,
    required this.showSkillComposer,
    required this.onSkillCreateTapped,
    required this.skillComposer,
  });

  final TextEditingController nameController;
  final TextEditingController descController;
  final FocusNode focusNode;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final List<Skill> availableSkills;
  final Set<String> selectedSkills;
  final ValueChanged<String> onSkillToggled;
  final String? selectedEmoji;
  final ValueChanged<String> onEmojiSelected;
  final String derivedId;
  final VoidCallback onClose;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSubmit;
  final bool showSkillComposer;
  final VoidCallback onSkillCreateTapped;
  final Widget skillComposer;

  @override
  Widget build(BuildContext context) {
    final statReady = nameController.text.trim().isNotEmpty &&
        selectedCategory != null &&
        selectedEmoji != null;
    final selectionSlug = selectedCategory?.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            controller: nameController,
            focusNode: focusNode,
            cursorColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Beats Made, Samples Chopped…',
              hintStyle: TextStyle(color: Colors.white38),
              isCollapsed: true,
            ),
            onChanged: onNameChanged,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ID preview • $derivedId',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 12),
        const Text(
          'Emoji',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final emoji in _kStatEmojiChoices)
                _EmojiChip(
                  emoji: emoji,
                  selected: selectedEmoji == emoji,
                  onTap: () => onEmojiSelected(emoji),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Category',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in _kMissionCategories.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _MissionCatChip(
                    label: entry.value.toUpperCase(),
                    selected: selectionSlug == entry.key,
                    accentColor: _categoryColor(entry.key),
                    onTap: () => onCategorySelected(entry.key),
                  ),
                ),
            ],
          ),
        ),
        if (availableSkills.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Skill',
            style: TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final skill in availableSkills)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _MissionCatChip(
                      label: skill.label.toUpperCase(),
                      selected: selectedSkills.contains(skill.id),
                      accentColor: _categoryColor(skill.categoryId),
                      onTap: () => onSkillToggled(skill.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        showSkillComposer
            ? skillComposer
            : Center(
                child: _MissionCatChip(
                  label: '+ CREATE',
                  selected: false,
                  onTap: onSkillCreateTapped,
                ),
              ),
        const SizedBox(height: 12),
        const Text(
          'Description',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: descController,
            cursorColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Optional short description',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: statReady ? onSubmit : onClose,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              backgroundColor: statReady
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              foregroundColor: statReady ? Colors.black : Colors.white70,
              shape: const StadiumBorder(),
            ),
            child: Text(statReady ? 'Save Stat' : 'Close'),
          ),
        ),
      ],
    );
  }
}

class _SkillCreationForm extends StatelessWidget {
  const _SkillCreationForm({
    required this.nameController,
    required this.focusNode,
    required this.derivedId,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.selectedEmoji,
    required this.onEmojiSelected,
    required this.selectedColor,
    required this.onColorSelected,
    required this.selectedWeight,
    required this.onWeightChanged,
    required this.onClose,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final FocusNode focusNode;
  final String derivedId;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final String? selectedEmoji;
  final ValueChanged<String> onEmojiSelected;
  final Color? selectedColor;
  final ValueChanged<Color> onColorSelected;
  final SkillWeightOption selectedWeight;
  final ValueChanged<SkillWeightOption> onWeightChanged;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final skillReady = nameController.text.trim().isNotEmpty &&
        selectedCategory != null &&
        selectedEmoji != null &&
        selectedColor != null;
    final selectionSlug = selectedCategory?.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            controller: nameController,
            focusNode: focusNode,
            cursorColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Skill name (e.g. Songwriting)',
              hintStyle: TextStyle(color: Colors.white38),
              isCollapsed: true,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ID preview • $derivedId',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 12),
        const Text(
          'Emoji',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final emoji in _kStatEmojiChoices)
                _EmojiChip(
                  emoji: emoji,
                  selected: selectedEmoji == emoji,
                  onTap: () => onEmojiSelected(emoji),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Category',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in _kMissionCategories.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _MissionCatChip(
                    label: entry.value.toUpperCase(),
                    selected: selectionSlug == entry.key,
                    accentColor: _categoryColor(entry.key),
                    onTap: () => onCategorySelected(entry.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Color',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final color in _kCategoryColorChoices)
                _ColorChoiceChip(
                  color: color,
                  selected: selectedColor == color,
                  onTap: () => onColorSelected(color),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Weight',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final opt in SkillWeightOption.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _WeightChip(
                  label: _weightLabel(opt),
                  selected: selectedWeight == opt,
                  onTap: () => onWeightChanged(opt),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: skillReady ? onSubmit : onClose,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              backgroundColor: skillReady
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              foregroundColor: skillReady ? Colors.black : Colors.white70,
              shape: const StadiumBorder(),
            ),
            child: Text(skillReady ? 'Save Skill' : 'Close'),
          ),
        ),
      ],
    );
  }
}

class _ColorChoiceChip extends StatelessWidget {
  const _ColorChoiceChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class _WeightChip extends StatelessWidget {
  const _WeightChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: 16,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MissionCatChip extends StatelessWidget {
  const _MissionCatChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        accentColor ?? (selected ? Colors.black : Colors.white);
    final Color bgColor =
        selected ? Colors.white : const Color(0x33222222);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _MissionStatChip extends StatelessWidget {
  const _MissionStatChip({
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

/* ───────────────────────────────
   Mission stat picker constants / utils
   ─────────────────────────────── */

const String _kDefaultCategorySlug = 'production';

const Map<String, String> _kMissionCategories = <String, String>{
  'rap': 'Rap',
  'production': 'Production',
  'health': 'Health',
  'knowledge': 'Knowledge',
  'business': 'Business',
};

const Map<String, Color> _kMissionCategoryColors = <String, Color>{
  'rap': Color(0xFFFF6B6B),
  'production': Color(0xFF64C5EB),
  'health': Color(0xFF58D68D),
  'knowledge': Color(0xFFFFB74D),
  'business': Color(0xFFB388FF),
};

const List<Color> _kCategoryColorChoices = <Color>[
  Color(0xFFFF6B6B),
  Color(0xFFFFB74D),
  Color(0xFFFDD835),
  Color(0xFF58D68D),
  Color(0xFF64C5EB),
  Color(0xFF5C6BC0),
  Color(0xFFB388FF),
  Color(0xFFFF80AB),
];

const List<String> _kStatEmojiChoices = <String>[
  '🎧',
  '🔪',
  '📩',
  '🧃',
  '💬',
  '📱',
  '📨',
  '☁️',
  '🔁',
  '🧠',
  '🎥',
  '📚',
  '💧',
  '🥗',
  '🏃🏻',
  '🧘🏾',
  '⚡️',
];

const Map<String, String> _kCategorySlugToCanonical = <String, String>{
  'rap': 'RAPPING',
  'production': 'PRODUCTION',
  'health': 'HEALTH',
  'knowledge': 'KNOWLEDGE',
  'business': 'BUSINESS',
};

const Map<String, String> _kCanonicalToSlug = <String, String>{
  'RAPPING': 'rap',
  'PRODUCTION': 'production',
  'HEALTH': 'health',
  'KNOWLEDGE': 'knowledge',
  'BUSINESS': 'business',
};

Color _categoryColor(String id) {
  return _kMissionCategoryColors[id] ?? _kCategoryColorChoices.first;
}

String _canonicalCategoryId(String? value) {
  if (value == null || value.isEmpty) {
    return _kCategorySlugToCanonical[_kDefaultCategorySlug] ??
        _kDefaultCategorySlug.toUpperCase();
  }
  final lower = value.toLowerCase();
  return _kCategorySlugToCanonical[lower] ?? value.toUpperCase();
}

String _categorySlug(String? value) {
  if (value == null || value.isEmpty) return _kDefaultCategorySlug;
  final lower = value.toLowerCase();
  if (_kMissionCategories.containsKey(lower)) return lower;
  final canonical = value.toUpperCase();
  return _kCanonicalToSlug[canonical] ?? lower;
}

String _categoryDisplayName(String? value) {
  if (value == null || value.isEmpty) return 'General';
  final slug = _categorySlug(value);
  return _kMissionCategories[slug] ?? value;
}

Color _categoryColorForAny(String? value) {
  final slug = _categorySlug(value);
  return _kMissionCategoryColors[slug] ?? _kCategoryColorChoices.first;
}

enum SkillWeightOption { low, medium, high }

String _weightLabel(SkillWeightOption opt) {
  switch (opt) {
    case SkillWeightOption.low:
      return 'Low';
    case SkillWeightOption.medium:
      return 'Medium';
    case SkillWeightOption.high:
      return 'High';
  }
}

double _weightValue(SkillWeightOption opt) {
  switch (opt) {
    case SkillWeightOption.low:
      return 0.2;
    case SkillWeightOption.medium:
      return 0.33;
    case SkillWeightOption.high:
      return 0.5;
  }
}
