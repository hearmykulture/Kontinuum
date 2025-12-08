import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter,
        TextSelection,
        SystemChannels;
import 'package:intl/intl.dart';
import 'package:kontinuum/models/objective.dart' show ObjectiveType;
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/screens/task_editor/models.dart' show StatPick;
import 'package:kontinuum/ui/widgets/corner_icons.dart';
import 'package:provider/provider.dart';

/// ===============================
/// Mission Editor (Create / Edit) clone for objective revamp.
/// ===============================

const double _kFooterBarH = 44;
const int _kMaxTitleChars = 100;

enum ObjectiveSchedulePreset { daily, weekdays, custom }

String _objectiveTypeLabel(ObjectiveType type) {
  switch (type) {
    case ObjectiveType.standard:
      return 'Standard';
    case ObjectiveType.tally:
      return 'Tally';
    case ObjectiveType.stopwatch:
      return 'Stopwatch';
    case ObjectiveType.subtask:
      return 'Checklist';
    case ObjectiveType.abstinence:
      return 'Abstinence';
  }
}

IconData _objectiveTypeIcon(ObjectiveType type) {
  switch (type) {
    case ObjectiveType.standard:
      return Icons.flag_outlined;
    case ObjectiveType.tally:
      return Icons.checklist_rtl;
    case ObjectiveType.stopwatch:
      return Icons.timer_outlined;
    case ObjectiveType.subtask:
      return Icons.view_list_rounded;
    case ObjectiveType.abstinence:
      return Icons.block;
  }
}

const List<String> _kWeekdayLabels = ['M', 'T', 'W', 'Th', 'F', 'S', 'Su'];

String _weekdaySummary(List<bool> enabled) {
  if (enabled.every((v) => v)) return 'Every day';
  final labels = <String>[];
  for (var i = 0; i < enabled.length && i < _kWeekdayLabels.length; i++) {
    if (enabled[i]) labels.add(_kWeekdayLabels[i]);
  }
  if (labels.isEmpty) return 'No days selected';
  return labels.join(' · ');
}

/// Public result object returned on save().
class ObjectiveRevampResult {
  final String title;
  final String? description;
  final String? categoryId;
  final ObjectiveType objectiveType;
  final ObjectiveSchedulePreset schedule;
  final List<int> activeWeekdays;
  final bool usesIntervalSchedule;
  final int intervalDays;
  final int xpReward; // objective-level XP
  final List<StatPick> stats; // multi-select, with per-stat amounts
  const ObjectiveRevampResult({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.objectiveType,
    required this.schedule,
    required this.activeWeekdays,
    required this.usesIntervalSchedule,
    required this.intervalDays,
    required this.xpReward,
    required this.stats,
  });
}

/// Holds all mutable options with ValueNotifiers.
class ObjectiveRevampOptionsController {
  // Description, Category, Objective Type, Schedule, XP, Stats
  final ValueNotifier<String?> descriptionN = ValueNotifier<String?>(null);
  final ValueNotifier<String?> categoryIdN = ValueNotifier<String?>(null);
  final ValueNotifier<ObjectiveType> objectiveTypeN =
      ValueNotifier<ObjectiveType>(ObjectiveType.standard);
  final ValueNotifier<ObjectiveSchedulePreset> scheduleN =
      ValueNotifier<ObjectiveSchedulePreset>(ObjectiveSchedulePreset.daily);
  final ValueNotifier<List<bool>> weekdaySelectionsN =
      ValueNotifier<List<bool>>(List<bool>.filled(7, true));
  final ValueNotifier<bool> intervalModeN = ValueNotifier<bool>(false);
  final ValueNotifier<int> intervalDaysN = ValueNotifier<int>(2);
  final ValueNotifier<int> xpRewardN = ValueNotifier<int>(100);
  final ValueNotifier<List<StatPick>> statsN =
      ValueNotifier<List<StatPick>>(<StatPick>[]);

  // ---- Stats helpers ----
  void toggleStat(String id) {
    final list = List<StatPick>.from(statsN.value);
    final i = list.indexWhere((p) => p.id == id);
    if (i >= 0) {
      list.removeAt(i);
    } else {
      list.add(StatPick(id: id, amount: 100)); // default amount
    }
    statsN.value = list;
  }

  void setStatAmount(String id, int amount) {
    final list = List<StatPick>.from(statsN.value);
    final i = list.indexWhere((p) => p.id == id);
    if (i >= 0) {
      list[i] = StatPick(id: id, amount: amount);
      statsN.value = list;
    }
  }

  void removeStat(String id) {
    final list = List<StatPick>.from(statsN.value)
      ..removeWhere((p) => p.id == id);
    statsN.value = list;
  }

  void dispose() {
    descriptionN.dispose();
    categoryIdN.dispose();
    objectiveTypeN.dispose();
    scheduleN.dispose();
    weekdaySelectionsN.dispose();
    intervalModeN.dispose();
    intervalDaysN.dispose();
    xpRewardN.dispose();
    statsN.dispose();
  }

  void toggleWeekday(int index) {
    final list = List<bool>.from(weekdaySelectionsN.value);
    if (index < 0 || index >= list.length) return;
    if (list[index] && list.where((v) => v).length == 1) {
      return; // keep at least one day active
    }
    list[index] = !list[index];
    weekdaySelectionsN.value = list;
  }

  void setIntervalMode(bool enabled) {
    intervalModeN.value = enabled;
    scheduleN.value = enabled
        ? ObjectiveSchedulePreset.custom
        : ObjectiveSchedulePreset.daily;
  }

  void adjustIntervalDays(int delta) {
    final next = (intervalDaysN.value + delta).clamp(1, 90);
    intervalDaysN.value = next;
  }
}

/// Full-screen mission creator styled like TaskEditorPage.
class CreateObjectiveScreen2 extends StatefulWidget {
  const CreateObjectiveScreen2({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.initialCategoryId,
    this.initialObjectiveType = ObjectiveType.standard,
    this.initialSchedule = ObjectiveSchedulePreset.daily,
    this.initialXpReward = 100,
    this.initialStats,
  });

  final String? initialTitle;
  final String? initialDescription;
  final String? initialCategoryId;
  final ObjectiveType initialObjectiveType;
  final ObjectiveSchedulePreset initialSchedule;
  final int initialXpReward;
  final List<StatPick>? initialStats;

  @override
  State<CreateObjectiveScreen2> createState() => _CreateObjectiveScreen2State();
}

class _CreateObjectiveScreen2State extends State<CreateObjectiveScreen2> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final ObjectiveRevampOptionsController _opts =
      ObjectiveRevampOptionsController();

  bool _closing = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle ?? '';
    _opts.descriptionN.value = widget.initialDescription;
    _opts.categoryIdN.value = widget.initialCategoryId;
    _opts.objectiveTypeN.value = widget.initialObjectiveType;
    _opts.scheduleN.value = widget.initialSchedule;
    _opts.xpRewardN.value = widget.initialXpReward;
    _opts.statsN.value = List<StatPick>.from(widget.initialStats ?? const []);

    // Autofocus the title like the Task page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _titleFocus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    _opts.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing || _popped) return;
    _closing = true;
    _popped = true;
    Navigator.of(context).pop();
  }

  Future<void> _deleteMission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Discard mission?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will close the editor without saving.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _close();
    }
  }

  void _save() {
    if (_closing || _popped) return;
    FocusScope.of(context).unfocus();
    final title =
        _titleCtrl.text.trim().isEmpty ? 'Mission' : _titleCtrl.text.trim();
    final activeWeekdays = _opts.weekdaySelectionsN.value
        .asMap()
        .entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    final res = ObjectiveRevampResult(
      title: title,
      description: _opts.descriptionN.value,
      categoryId: _opts.categoryIdN.value,
      objectiveType: _opts.objectiveTypeN.value,
      schedule: _opts.scheduleN.value,
      activeWeekdays: activeWeekdays,
      usesIntervalSchedule: _opts.intervalModeN.value,
      intervalDays: _opts.intervalDaysN.value,
      xpReward: _opts.xpRewardN.value,
      stats: List<StatPick>.from(_opts.statsN.value),
    );
    _persistObjective(res);
    _closing = true;
    _popped = true;
    Navigator.of(context).pop(res);
  }

  void _persistObjective(ObjectiveRevampResult res) {
    final provider = context.read<ObjectiveProvider>();
    final categorySlug = res.categoryId ?? _kDefaultCategorySlug;
    final canonicalCategory = _canonicalCategoryId(categorySlug);

    provider.ensureCategoryExists(
      canonicalCategory,
      displayName: _categoryDisplayName(categorySlug),
      colorInt: _categoryColorForAny(categorySlug).value,
    );

    final statIds = res.stats.map((s) => s.id).toList();
    for (final statId in statIds) {
      if (!provider.stats.containsKey(statId)) {
        provider.registerStat(
          Stat(
            id: statId,
            label: StatRepository.getDisplay(statId),
            averageMinutesPerUnit: 1,
            repsForMastery: 1,
          ),
        );
      }
    }
    if (statIds.isNotEmpty) {
      provider.persistStats();
    }

    final activeDays = _buildActiveDays(res.activeWeekdays);
    final DateTime startDate =
        DateTime.now(); // normalized below for clarity
    final DateTime startDateOnly =
        DateTime(startDate.year, startDate.month, startDate.day);

    provider.addObjective(
      title: res.title,
      type: res.objectiveType,
      categoryIds: [canonicalCategory],
      statIds: statIds,
      xpReward: res.xpReward,
      startDate: startDateOnly,
      activeDays: activeDays,
      description: res.description,
      repeatEveryNDays: res.usesIntervalSchedule ? res.intervalDays : null,
      repeatAnchorDate:
          res.usesIntervalSchedule ? startDateOnly : null,
      isStatic: true,
    );
  }

  Map<int, bool> _buildActiveDays(List<int> enabled) {
    final set = enabled.toSet();
    final map = <int, bool>{};
    for (var day = 1; day <= 7; day++) {
      map[day] = set.contains(day - 1);
    }
    if (!map.containsValue(true)) {
      for (var day = 1; day <= 7; day++) {
        map[day] = true;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets; // keyboard
    final pad = mq.padding;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Content above keyboard + pinned footer
          Positioned.fill(
            bottom: insets.bottom + _kFooterBarH,
            child: SafeArea(
              top: true,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  final caretY = box.maxHeight * 0.20;
                  final contentTop = caretY + 110;

                  return Stack(
                    children: [
                      // Top-left & Top-right: Corner icons (delete + close)
                      CornerIcons(
                        top: 0,
                        leftIcon: Icons.delete_outline,
                        onLeftPressed: _deleteMission,
                        leftTooltip: 'Discard',
                        rightIcon: Icons.close,
                        onRightPressed: _close,
                        rightTooltip: 'Close',
                      ),

                      // Centered title input, same style as Task editor
                      Positioned(
                        top: caretY,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _CenteredTitleField(
                              controller: _titleCtrl,
                              focusNode: _titleFocus,
                              onDone: _save,
                            ),
                          ),
                        ),
                      ),

                      // Scrollable options
                      Positioned.fill(
                        top: contentTop,
                        child: ScrollConfiguration(
                          behavior: const _NoGlowScrollBehavior(),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            // Key ensures Flutter keeps the same stateful element
                            child: ObjectiveRevampOptionsPanel(
                              key: const ValueKey('mission_opts'),
                              controller: _opts,
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

          // Footer bar
          Positioned(
            left: 0,
            right: 0,
            bottom: insets.bottom,
            child: Container(
              height: _kFooterBarH + pad.bottom,
              color: Colors.black,
              padding: EdgeInsets.only(left: 16, right: 16, bottom: pad.bottom),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _save,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Text('Done',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
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

/// ===============================
/// Mission Options (inline dropdowns)
/// ===============================

class ObjectiveRevampOptionsPanel extends StatefulWidget {
  const ObjectiveRevampOptionsPanel({super.key, required this.controller});
  final ObjectiveRevampOptionsController controller;

  @override
  State<ObjectiveRevampOptionsPanel> createState() => _ObjectiveRevampOptionsPanelState();
}

enum _OpenSection { none, type, schedule, desc, cat, stats, xp }

class _ObjectiveRevampOptionsPanelState extends State<ObjectiveRevampOptionsPanel>
    with AutomaticKeepAliveClientMixin {
  // Single source of truth: which section is open
  _OpenSection _open = _OpenSection.none;

  // Description text field state
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.controller.descriptionN.value ?? '');
  final FocusNode _descFocus = FocusNode();
  late final TextEditingController _xpCtrl;

  @override
  void initState() {
    super.initState();
    _xpCtrl = TextEditingController(
        text: widget.controller.xpRewardN.value.clamp(1, 999).toString());
    widget.controller.xpRewardN.addListener(_syncXpField);
  }

  void _syncXpField() {
    if (!mounted) return;
    final clamped = widget.controller.xpRewardN.value.clamp(1, 999);
    final nextText = clamped.toString();
    if (_xpCtrl.text == nextText) return;
    _xpCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  bool get wantKeepAlive => true;

  String _categoryTitle(String? id) {
    if (id == null) return 'Pick one';
    return _kMissionCategories[id] ?? id;
  }

  String _statsSummary(List<StatPick> picks) {
    if (picks.isEmpty) return 'No Stats';
    final parts = <String>[];
    for (final p in picks.take(2)) {
      parts.add(StatRepository.getDisplay(p.id));
    }
    final extra = picks.length - 2;
    return extra > 0 ? '${parts.join(", ")} +$extra more' : parts.join(', ');
  }

  @override
  void dispose() {
    widget.controller.xpRewardN.removeListener(_syncXpField);
    _xpCtrl.dispose();
    _descCtrl.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  void _toggleSection(_OpenSection s, {bool requestDescFocus = false}) {
    // Unfocus first to avoid keyboard/layout churn racing with the tap.
    FocusScope.of(context).unfocus();

    // Defer the state change until after the current pointer/tap completes.
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _open = (_open == s) ? _OpenSection.none : s;
      });
      if (requestDescFocus && _open == _OpenSection.desc) {
        // Wait one frame so the field is in the tree with its final size.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _descFocus.requestFocus();
        });
      }
    });
  }

  bool _isOpen(_OpenSection s) => _open == s;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Rounded group ----
        _RoundedGroup(
          radius: 16,
          children: [
            // ===== OBJECTIVE TYPE =====
            ValueListenableBuilder<ObjectiveType>(
              valueListenable: c.objectiveTypeN,
              builder: (_, type, __) => _RowTile(
                title: 'Objective Type',
                subtitle: _objectiveTypeLabel(type),
                trailingIcon: Icons.dashboard_customize_rounded,
                onTap: () => _toggleSection(_OpenSection.type),
              ),
            ),
            _InlineDrop(
              expanded: _isOpen(_OpenSection.type),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: ValueListenableBuilder<ObjectiveType>(
                  valueListenable: c.objectiveTypeN,
                  builder: (_, selected, __) {
                    final chips = ObjectiveType.values
                        .map((option) => _ObjectiveTypeChip(
                              label: _objectiveTypeLabel(option),
                              type: option,
                              selected: selected == option,
                              onTap: () => c.objectiveTypeN.value = option,
                            ))
                        .toList();
                    return Column(
                      children: [
                        _ObjectiveTypeRow(chips: chips.take(2).toList()),
                        const SizedBox(height: 8),
                        _ObjectiveTypeRow(
                            chips: chips.skip(2).take(2).toList()),
                        const SizedBox(height: 8),
                        Center(child: chips.last),
                      ],
                    );
                  },
                ),
              ),
            ),
            const _DividerRow(),

            // ===== CATEGORY =====
            ValueListenableBuilder<String?>(
              valueListenable: c.categoryIdN,
              builder: (_, catId, __) => _RowTile(
                title: 'Category',
                subtitle: _categoryTitle(catId),
                trailingIcon: Icons.folder_rounded,
                onTap: () => _toggleSection(_OpenSection.cat),
              ),
            ),
            // CATEGORY STRIP — ALL corners straight
            _InlineDrop(
              expanded: _isOpen(_OpenSection.cat),
              child: _CategoryStrip(controller: c),
            ),
            const _DividerRow(),

            // ===== SCHEDULE =====
            ValueListenableBuilder<bool>(
              valueListenable: c.intervalModeN,
              builder: (_, intervalMode, __) => ValueListenableBuilder<List<bool>>(
                valueListenable: c.weekdaySelectionsN,
                builder: (_, weekdays, __) => ValueListenableBuilder<int>(
                  valueListenable: c.intervalDaysN,
                  builder: (_, intervalDays, __) => _RowTile(
                    title: 'Schedule',
                    subtitle: intervalMode
                        ? 'Every $intervalDays days'
                        : _weekdaySummary(weekdays),
                    trailingIcon: Icons.calendar_month_rounded,
                    onTap: () => _toggleSection(_OpenSection.schedule),
                  ),
                ),
              ),
            ),
            _InlineDrop(
              expanded: _isOpen(_OpenSection.schedule),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  children: [
                    _WeeklyScheduleSection(controller: c),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0x22FFFFFF)),
                    const SizedBox(height: 6),
                    _IntervalScheduleRow(controller: c),
                  ],
                ),
              ),
            ),
            const _DividerRow(),

            // ===== STATS =====
            ValueListenableBuilder<List<StatPick>>(
              valueListenable: c.statsN,
              builder: (_, picks, __) => _RowTile(
                title: 'Stats',
                subtitle: _statsSummary(picks),
                trailingIcon: Icons.trending_up_rounded,
                onTap: () => _toggleSection(_OpenSection.stats),
              ),
            ),
            _InlineDrop(
              expanded: _isOpen(_OpenSection.stats),
              child: const _MissionStatPicker(
                key: ValueKey('mission_stat_picker'),
              ),
            ),
            const _DividerRow(),

            // ===== XP REWARD =====
            ValueListenableBuilder<int>(
              valueListenable: c.xpRewardN,
              builder: (_, xp, __) => _RowTile(
                title: 'XP Reward',
                subtitle: NumberFormat.compact().format(xp),
                trailingIcon: Icons.bolt_rounded,
                onTap: () => _toggleSection(_OpenSection.xp),
              ),
            ),
            _InlineDrop(
              expanded: _isOpen(_OpenSection.xp),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: c.xpRewardN,
                      builder: (_, v, __) {
                        final display = v.clamp(1, 999);
                        return Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white24),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '×',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 56,
                                  child: TextField(
                                    controller: _xpCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                    onChanged: (raw) {
                                      if (raw.isEmpty) return;
                                      final parsed = int.tryParse(raw);
                                      if (parsed == null) return;
                                      final clamped = parsed.clamp(1, 999);
                                      if (c.xpRewardN.value != clamped) {
                                        c.xpRewardN.value = clamped;
                                      }
                                      if (clamped.toString() != raw) {
                                        _xpCtrl.value = TextEditingValue(
                                          text: clamped.toString(),
                                          selection: TextSelection.collapsed(
                                              offset:
                                                  clamped.toString().length),
                                        );
                                      }
                                    },
                                    onEditingComplete: () {
                                      final parsed = int.tryParse(_xpCtrl.text);
                                      final clamped = (parsed ?? display)
                                          .clamp(1, 999);
                                      if (c.xpRewardN.value != clamped) {
                                        c.xpRewardN.value = clamped;
                                      }
                                      final text = clamped.toString();
                                      _xpCtrl.value = TextEditingValue(
                                        text: text,
                                        selection: TextSelection.collapsed(
                                            offset: text.length),
                                      );
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: c.xpRewardN,
                      builder: (_, v, __) => _MissionXpSliderBar(
                        value: v.clamp(1, 999),
                        min: 1,
                        max: 999,
                        onChanged: (x) => c.xpRewardN.value = x,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _DividerRow(),

            // ===== DESCRIPTION =====
            ValueListenableBuilder<String?>(
              valueListenable: c.descriptionN,
              builder: (_, desc, __) => _RowTile(
                title: 'Description',
                subtitle: (desc == null || desc.isEmpty)
                    ? 'Optional'
                    : _trimOneLine(desc),
                trailingIcon: Icons.notes_rounded,
                onTap: () =>
                    _toggleSection(_OpenSection.desc, requestDescFocus: true),
              ),
            ),
            _InlineDrop(
              expanded: _isOpen(_OpenSection.desc),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF232323),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: const Color(0x22FFFFFF), width: 1),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    controller: _descCtrl,
                    focusNode: _descFocus,
                    minLines: 3,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Optional details…',
                      hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                      isCollapsed: true,
                    ),
                    onChanged: (t) =>
                        c.descriptionN.value = t.trim().isEmpty ? null : t,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-bleed Category strip with STRAIGHT corners (no rounding).
class _CategoryStrip extends StatefulWidget {
  const _CategoryStrip({required this.controller});
  final ObjectiveRevampOptionsController controller;

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip>
    with TickerProviderStateMixin {
  bool _creating = false;
  bool _showComplete = false;
  bool _editing = false;
  final TextEditingController _createCtrl = TextEditingController();
  final FocusNode _createFocus = FocusNode();
  int _colorIndex = 0;
  late final List<_CategoryChipData> _categories = [
    for (final entry in _kMissionCategories.entries)
      _CategoryChipData(
        id: entry.key,
        label: entry.value,
        color: _categoryColor(entry.key),
      ),
  ];

  ObjectiveRevampOptionsController get _controller => widget.controller;

  @override
  void dispose() {
    _createCtrl.dispose();
    _createFocus.dispose();
    super.dispose();
  }

  void _toggleCreate() {
    setState(() {
      _creating = !_creating;
      if (_creating) _editing = false;
      if (!_creating) {
        _createCtrl.clear();
        _colorIndex = 0;
        _showComplete = false;
        FocusScope.of(context).unfocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _createFocus.requestFocus();
        });
      }
    });
  }

  void _toggleEditing() {
    setState(() {
      _editing = !_editing;
      if (_editing) {
        _creating = false;
        _showComplete = false;
        _createCtrl.clear();
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _handleCreateChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText != _showComplete) {
      setState(() => _showComplete = hasText);
    }
  }

  void _completeCreate() {
    final raw = _createCtrl.text.trim();
    if (raw.isEmpty) return;
    final base = raw
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp('^_|_\$'), '');
    var candidate = base.isEmpty ? 'category' : base;
    var idx = 1;
    while (_categories.any((c) => c.id == candidate)) {
      candidate = '${base.isEmpty ? 'category' : base}_$idx';
      idx++;
    }
    final color =
        _kCategoryColorChoices[_colorIndex % _kCategoryColorChoices.length];
    setState(() {
      _categories.add(
        _CategoryChipData(id: candidate, label: raw, color: color),
      );
      _rememberCategoryColor(candidate, color);
      _controller.categoryIdN.value = candidate;
      _creating = false;
      _showComplete = false;
      _createCtrl.clear();
      _colorIndex = 0;
    });
    FocusScope.of(context).unfocus();
  }

  Future<bool> _confirmDeleteSequence(String label) async {
    final first = await _showConfirmDialog(
      title: 'Delete "$label"?',
      message: 'This category will be removed.',
      confirmLabel: 'Delete',
    );
    if (first != true) return false;
    final second = await _showConfirmDialog(
      title: 'Are you REALLY sure?',
      message: 'This cannot be undone.',
      confirmLabel: 'Yes, delete it',
    );
    return second == true;
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101010),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteCategory(_CategoryChipData data) async {
    final confirmed = await _confirmDeleteSequence(data.label);
    if (!confirmed) return;
    if (!mounted) return;
    setState(() {
      _categories.removeWhere((c) => c.id == data.id);
      _forgetCategoryColor(data.id);
      if (_controller.categoryIdN.value == data.id) {
        _controller.categoryIdN.value =
            _categories.isNotEmpty ? _categories.first.id : null;
      }
      if (_categories.isEmpty) {
        _editing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        borderRadius: BorderRadius.zero,
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: ValueListenableBuilder<String?>(
        valueListenable: _controller.categoryIdN,
        builder: (_, selected, __) {
          return Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_categories.length),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.only(left: 2, right: 2, top: 10),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (final entry in _categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _CategoryChipWithDelete(
                              data: entry,
                              selected: selected == entry.id,
                              editing: _editing,
                              onTap: () => _controller.categoryIdN.value =
                                  entry.id,
                              onDelete: () => _handleDeleteCategory(entry),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _creating
                            ? _CreateCategoryInput(
                                key: const ValueKey('create_input'),
                                controller: _createCtrl,
                                focusNode: _createFocus,
                                onChanged: _handleCreateChanged,
                                onClose: _toggleCreate,
                              )
                            : _MissionCatChip(
                                key: const ValueKey('create_pill'),
                                label: '+ CREATE',
                                selected: false,
                                onTap: _toggleCreate,
                              ),
                      ),
                    ),
                    if (!_creating)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          padding: const EdgeInsets.all(4),
                          iconSize: 18,
                          icon: Icon(
                            _editing ? Icons.check_rounded : Icons.edit_rounded,
                            color: Colors.white70,
                          ),
                          tooltip: _editing ? 'Done' : 'Edit categories',
                          onPressed:
                              _categories.isEmpty ? null : _toggleEditing,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: !_creating
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          const SizedBox(height: 14),
                          _CategoryColorPicker(
                            selectedIndex: _colorIndex,
                            onColorSelected: (index) {
                              setState(() => _colorIndex = index);
                            },
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: !_showComplete
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _CompleteCategoryButton(
                                      key: const ValueKey('complete_btn'),
                                      onTap: _completeCreate,
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Smooth height+opacity expander (CrossFade avoids switcher-child reuse hiccups).
class _InlineDrop extends StatelessWidget {
  const _InlineDrop({required this.expanded, required this.child});
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 240),
      crossFadeState:
          expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstCurve: Curves.easeInCubic,
      secondCurve: Curves.easeOutCubic,
      sizeCurve: Curves.easeOutCubic,
      firstChild: const SizedBox.shrink(),
      secondChild: child,
    );
  }
}

/// ===============================
/// Shared UI
/// ===============================

class _CenteredTitleField extends StatelessWidget {
  const _CenteredTitleField({
    required this.controller,
    required this.focusNode,
    required this.onDone,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
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
      onTapOutside: (_) {
        if (focusNode.hasFocus) {
          focusNode.unfocus();
        }
      },
      inputFormatters: [
        FilteringTextInputFormatter.singleLineFormatter,
        LengthLimitingTextInputFormatter(_kMaxTitleChars),
      ],
    );
  }
}

class _RoundedGroup extends StatelessWidget {
  const _RoundedGroup({required this.children, this.radius = 16});
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
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        )),
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

class _ObjectiveTypeChip extends StatelessWidget {
  const _ObjectiveTypeChip({
    required this.label,
    required this.type,
    required this.selected,
    this.onTap,
  });

  final String label;
  final ObjectiveType type;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const abstinenceColor = Color(0xFFFF5C5C);
    final bool isAbstinence = type == ObjectiveType.abstinence;
    final Color bg = isAbstinence
        ? (selected ? abstinenceColor : abstinenceColor.withOpacity(0.12))
        : (selected ? Colors.white : const Color(0xFF232323));
    final Color fg = isAbstinence
        ? (selected ? Colors.white : abstinenceColor)
        : (selected ? Colors.black : Colors.white);
    final Color iconColor = isAbstinence
        ? fg
        : (selected ? Colors.black : Colors.white70);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAbstinence
                ? abstinenceColor.withOpacity(selected ? 0.0 : 0.8)
                : (selected ? Colors.transparent : const Color(0x22FFFFFF)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_objectiveTypeIcon(type), size: 18, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectiveTypeRow extends StatelessWidget {
  const _ObjectiveTypeRow({required this.chips});

  final List<_ObjectiveTypeChip> chips;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          chips[i],
          if (i != chips.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _WeeklyScheduleSection extends StatelessWidget {
  const _WeeklyScheduleSection({required this.controller});

  final ObjectiveRevampOptionsController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.intervalModeN,
      builder: (_, intervalMode, __) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.setIntervalMode(false),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: intervalMode ? Colors.white38 : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
              child: const Text('Weekly'),
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<List<bool>>(
              valueListenable: controller.weekdaySelectionsN,
              builder: (_, selections, __) => AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                opacity: intervalMode ? 0.35 : 1.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _kWeekdayLabels.length,
                    (index) => _WeekdayToggleButton(
                      label: _kWeekdayLabels[index],
                      active: selections[index],
                      disabled: intervalMode,
                      onTap: () => controller.toggleWeekday(index),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayToggleButton extends StatelessWidget {
  const _WeekdayToggleButton({
    required this.label,
    required this.active,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = disabled
        ? const Color(0xFF1E1E1E)
        : (active ? Colors.white : const Color(0xFF2A2A2A));
    final Color fg = disabled
        ? Colors.white24
        : (active ? Colors.black : Colors.white70);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: disabled
                ? Colors.white12
                : (active ? Colors.transparent : Colors.white24),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: label.length > 1 ? -0.5 : 0.5,
          ),
        ),
      ),
    );
  }
}

class _IntervalScheduleRow extends StatelessWidget {
  const _IntervalScheduleRow({required this.controller});

  final ObjectiveRevampOptionsController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.intervalModeN,
      builder: (_, intervalMode, __) => ValueListenableBuilder<int>(
        valueListenable: controller.intervalDaysN,
        builder: (_, days, __) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.setIntervalMode(true),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            opacity: intervalMode ? 1.0 : 0.35,
            child: Column(
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: intervalMode ? Colors.white70 : Colors.white38,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                  child: const Text('Every X Days'),
                ),
                const SizedBox(height: 4),
                Center(
                  child: _IntervalStepper(
                    value: days,
                    enabled: intervalMode,
                    onIncrement: intervalMode
                        ? () => controller.adjustIntervalDays(1)
                        : null,
                    onDecrement: intervalMode
                        ? () => controller.adjustIntervalDays(-1)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({
    required this.value,
    required this.enabled,
    this.onIncrement,
    this.onDecrement,
  });

  final int value;
  final bool enabled;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    Color bg(bool active) => active
        ? Colors.white
        : const Color(0x22FFFFFF);

    Color fg(bool active) => active ? Colors.black : Colors.white54;

    Widget button(IconData icon, VoidCallback? handler) {
      final active = handler != null && enabled;
      return GestureDetector(
        onTap: active ? handler : null,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg(active),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? Colors.transparent : Colors.white24,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: fg(active)),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove, onDecrement),
        const SizedBox(width: 10),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 10),
        button(Icons.add, onIncrement),
      ],
    );
  }
}

class _DividerRow extends StatelessWidget {
  const _DividerRow();
  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0x14FFFFFF),
        indent: 14,
        endIndent: 14,
      );
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// ===============================
/// Inline Stat Picker (keeps per-stat sliders)
/// ===============================
class _MissionStatPicker extends StatefulWidget {
  const _MissionStatPicker({super.key});

  @override
  State<_MissionStatPicker> createState() => _MissionStatPickerState();
}

class _MissionStatPickerState extends State<_MissionStatPicker> {
  String? _categoryFilter; // null => ALL
  final ScrollController _catCtrl = ScrollController();
  final Map<String, GlobalKey> _catKeys = {};
  GlobalKey _keyFor(String? id) =>
      _catKeys.putIfAbsent(id ?? '__ALL__', () => GlobalKey());
  bool _creatingStat = false;
  bool _creatingSkill = false;
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
  ObjectiveRevampOptionsController get _optionsController =>
      context
          .findAncestorStateOfType<_ObjectiveRevampOptionsPanelState>()!
          .widget
          .controller;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

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

    final extras = statCats
        .where((slug) => !seen.contains(slug))
        .toList()
      ..sort();
    for (final extra in extras) {
      push(extra);
    }

    // Ensure the fallback GENERAL bucket is always available (at the end).
    push('general');

    return ordered;
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    _statNameCtrl.dispose();
    _statDescCtrl.dispose();
    _statNameFocus.dispose();
    _skillNameCtrl.dispose();
    _skillNameFocus.dispose();
    super.dispose();
  }

  void _scrollToCategory(String? id) {
    final key = _keyFor(id);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          alignment: 0.35);
    }
  }

  void _toggleCreateStat() {
    setState(() {
      _creatingStat = !_creatingStat;
      if (!_creatingStat) _creatingSkill = false;
      if (_creatingStat) {
        final fallback =
            _categoryFilter ?? (_categories.isNotEmpty ? _categories.first : null);
        final seed = _statCategorySelection ?? fallback;
        _statCategorySelection =
            (seed ?? _kDefaultCategorySlug).toLowerCase();
        _statEmojiSelection ??= _kStatEmojiChoices.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _statNameFocus.requestFocus();
        });
      } else {
        _statNameCtrl.clear();
        _statDescCtrl.clear();
        _statSkillSelections.clear();
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
    final name = _statNameCtrl.text.trim();
    final categorySlug =
        _statCategorySelection ??
            _optionsController.categoryIdN.value ??
            _kDefaultCategorySlug;
    final emoji = _statEmojiSelection;
    if (name.isEmpty || categorySlug.isEmpty || emoji == null) {
      _showSnack('Add a name, emoji, and category for the stat.');
      return;
    }
    final statId = _derivedStatId;
    final provider = context.read<ObjectiveProvider>();
    if (provider.stats.containsKey(statId) ||
        StatRepository.getById(statId) != null) {
      _showSnack('A stat with that ID already exists.');
      return;
    }

    final canonicalCategory = _canonicalCategoryId(categorySlug);
    provider.ensureCategoryExists(
      canonicalCategory,
      displayName: _categoryDisplayName(categorySlug),
      colorInt: _categoryColorForAny(categorySlug).value,
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

    FocusScope.of(context).unfocus();
    _showSnack('Stat saved.');
    _toggleCreateStat();
  }

  void _handleSaveSkill() {
    final name = _skillNameCtrl.text.trim();
    final categorySlug =
        _skillCategorySelection ??
            _statCategorySelection ??
            _optionsController.categoryIdN.value ??
            _kDefaultCategorySlug;
    final emoji = _skillEmojiSelection;
    final color = _skillColorSelection;
    if (name.isEmpty ||
        categorySlug.isEmpty ||
        emoji == null ||
        color == null) {
      _showSnack('Fill all fields to save the skill.');
      return;
    }

    final skillId = _derivedSkillId;
    final provider = context.read<ObjectiveProvider>();
    if (provider.skills.containsKey(skillId)) {
      _showSnack('A skill with that ID already exists.');
      return;
    }

    final canonicalCategory = _canonicalCategoryId(categorySlug);
    provider.ensureCategoryExists(
      canonicalCategory,
      displayName: _categoryDisplayName(categorySlug),
      colorInt: color.value,
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

    FocusScope.of(context).unfocus();
    setState(() {
      _statSkillSelections.add(skillId);
    });
    _showSnack('Skill saved.');
    _toggleCreateSkill();
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
    final controller = _optionsController;
    final objectiveProvider = context.watch<ObjectiveProvider>();

    // Build list for current filter
    final stats = (_categoryFilter == null
            ? StatRepository.getAll()
            : StatRepository.getByCategory(
                _canonicalCategoryId(_categoryFilter!),
              ))
        .map((s) => (id: s.id, display: s.display))
        .toList(growable: false);

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
                    key: const ValueKey('stat_tabs_and_button'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        controller: _catCtrl,
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.only(left: 2, right: 2, bottom: 6),
                        child: Row(
                          children: [
                            KeyedSubtree(
                              key: _keyFor(null),
                              child: _MissionCatChip(
                                label: 'ALL',
                                selected: _categoryFilter == null,
                                onTap: () {
                                  setState(() => _categoryFilter = null);
                                  WidgetsBinding.instance.addPostFrameCallback(
                                      (_) => _scrollToCategory(null));
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            ..._categories.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: KeyedSubtree(
                                  key: _keyFor(c),
                                  child: _MissionCatChip(
                                    label: _categoryDisplayName(c).toUpperCase(),
                                    selected: _categoryFilter == c,
                                    accentColor: _categoryColorForAny(c),
                                    onTap: () {
                                      setState(() => _categoryFilter = c);
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                              (_) => _scrollToCategory(c));
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
                        layoutBuilder:
                            (currentChild, previousChildren) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [if (currentChild != null) currentChild],
                        ),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(0.0, .05),
                                    end: Offset.zero)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey<String>(_categoryFilter ?? 'ALL'),
                          child: stats.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('No stats in this category',
                                      style: TextStyle(
                                          color: Color(0x66FFFFFF),
                                          fontSize: 13)),
                                )
                              : Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
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
                      ),
                      const SizedBox(height: 8),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('stat_bank_empty')),
          ),
        ],
      ),
    );
  }
}

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              backgroundColor:
                  statReady ? Colors.white : Colors.white.withOpacity(0.15),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              backgroundColor:
                  skillReady ? Colors.white : Colors.white.withOpacity(0.15),
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
                    color: color.withOpacity(0.4),
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
/// ---- Chips used by both the Stats category row and Category picker ----
class _MissionCatChip extends StatelessWidget {
  const _MissionCatChip({
    super.key,
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
    final Color textColor = accentColor ??
        (selected ? Colors.black : Colors.white);
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

class _CategoryChipWithDelete extends StatelessWidget {
  const _CategoryChipWithDelete({
    required this.data,
    required this.selected,
    required this.editing,
    required this.onTap,
    required this.onDelete,
  });

  final _CategoryChipData data;
  final bool selected;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final chip = _MissionCatChip(
      label: data.label.toUpperCase(),
      selected: selected,
      accentColor: data.color,
      onTap: onTap,
    );

    if (!editing) return chip;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        chip,
        Positioned(
          top: -6,
          left: -6,
          child: _DeleteBadge(onTap: onDelete),
        ),
      ],
    );
  }
}

class _DeleteBadge extends StatelessWidget {
  const _DeleteBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFF4D4F),
        ),
        alignment: Alignment.center,
        child: const Text(
          '-',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
              width: 1),
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

class _CreateCategoryInput extends StatelessWidget {
  const _CreateCategoryInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x33222222),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Category name',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onChanged: onChanged,
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, size: 16, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryColorPicker extends StatelessWidget {
  const _CategoryColorPicker({
    required this.selectedIndex,
    required this.onColorSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: _kCategoryColorChoices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final color = _kCategoryColorChoices[index];
          return _ColorDot(
            color: color,
            selected: index == selectedIndex,
            onTap: () => onColorSelected(index),
          );
        },
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: selected ? 34 : 28,
        height: selected ? 34 : 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

class _CompleteCategoryButton extends StatelessWidget {
  const _CompleteCategoryButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF2B2B2B),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            'Complete',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChipData {
  const _CategoryChipData({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}


class _MissionXpSliderBar extends StatelessWidget {
  const _MissionXpSliderBar({
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
        if (w <= 0) return const SizedBox(height: 34, width: double.infinity);

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

        final double upper = w - thumbR * 2;
        final double safeUpper = upper < 0 ? 0.0 : upper;
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
                          Color(0xFFFF6FD8)
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
                            offset: Offset(0, 2))
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

/// ===============================
/// Local helpers / constants
/// ===============================

final Map<String, Color> _customCategoryColors = <String, Color>{};

void _rememberCategoryColor(String? slug, Color color) {
  if (slug == null || slug.isEmpty) return;
  _customCategoryColors[slug.toLowerCase()] = color;
}

void _forgetCategoryColor(String? slug) {
  if (slug == null || slug.isEmpty) return;
  _customCategoryColors.remove(slug.toLowerCase());
}

String _trimOneLine(String t) {
  final s = t.trim();
  return s.length <= 64 ? s : '${s.substring(0, 64)}…';
}

/// Temporary list for categories to avoid external dep here.
/// Replace with your real repository if available.
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
  return _customCategoryColors[slug] ??
      _kMissionCategoryColors[slug] ??
      _kCategoryColorChoices.first;
}

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

enum SkillWeightOption { low, medium, high }
