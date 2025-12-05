// lib/ui/screens/create_objective_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'task_editor/checklist.dart';
import 'task_editor/panels_and_calendar.dart'; // ⟵ re-use the exact pill pieces
import 'package:kontinuum/ui/widgets/corner_icons.dart';

// App state / data
import 'package:provider/provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/ui/screens/task_editor/models.dart' show StatPick;
import 'package:kontinuum/utils/date_keys.dart';

const double _kBarH = 44;

enum _OptionSection {
  none,
  category,
  type,
  repetition,
  target,
  xp,
  stats,
  description,
}

/// Full-screen “Create Objective” page (visuals 1:1 with Task Editor).
class CreateObjectiveScreen extends StatefulWidget {
  const CreateObjectiveScreen({
    super.key,
    this.initialTitle,
    this.autofocusTitle = true,
    this.showDelete = false,
    this.onDelete,
    this.categoryLabel = 'Category',
    this.typeLabel = 'Objective Type',
    this.repetitionLabel = 'Repetition',
    this.xpLabel = 'XP Reward',
    this.statsLabel = 'Stats',
    this.descriptionLabel = 'Description',
    this.showDescriptionTab = false,
    this.categoryOverride,
    this.useAmountSlider = false,
    this.useAccountPills = false,
    this.accountOptions,
    this.useCashflowPills = false,
    this.cashflowOptions,
  });

  final String? initialTitle;
  final bool autofocusTitle;
  final bool showDelete;
  final VoidCallback? onDelete;
  final String categoryLabel;
  final String typeLabel;
  final String repetitionLabel;
  final String xpLabel;
  final String statsLabel;
  final String descriptionLabel;
  final bool showDescriptionTab;
  final List<({String id, String name, int? colorInt})>? categoryOverride;
  final bool useAmountSlider;
  final bool useAccountPills;
  final List<String>? accountOptions;
  final bool useCashflowPills;
  final List<String>? cashflowOptions;

  @override
  State<CreateObjectiveScreen> createState() => _CreateObjectiveScreenState();
}

class _CreateObjectiveScreenState extends State<CreateObjectiveScreen> {
  static const List<int> _kTargetPresets = [1, 5, 10, 25, 50];
  static const List<int> _kWeekdayOrder = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  // Title
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  // Checklist
  final _listKey = GlobalKey<AnimatedListState>();
  final List<ChecklistItemModel> _items = <ChecklistItemModel>[];

  // Options state
  String? _categoryId;
  ObjectiveType _type = ObjectiveType.standard;
  final _targetCtrl = TextEditingController(text: '1');
  int _xpValue = 10;
  final ValueNotifier<List<StatPick>> _statPicksN =
      ValueNotifier<List<StatPick>>(<StatPick>[]);
  String? _selectedAccount;
  String? _selectedCashflow;
  final Map<int, bool> _activeDays = {
    for (int i = 1; i <= 7; i++) i: true
  };
  bool _useInterval = false;
  int _repeatEvery = 1;

  _OptionSection _openSection = _OptionSection.none;

  bool get _isAbstinence => _type == ObjectiveType.abstinence;
  bool get _isSubtask => _type == ObjectiveType.subtask;

  bool _closing = false;
  bool _popped = false;

  // ----------------- Checklist helpers -----------------
  void _addItem([String initial = '']) {
    final wasEmpty = _items.isEmpty;
    final index = _items.length;
    final item = ChecklistItemModel(initial);
    _items.insert(index, item);
    _listKey.currentState
        ?.insertItem(index, duration: const Duration(milliseconds: 220));
    if (wasEmpty) setState(() {});
    WidgetsBinding.instance
        .addPostFrameCallback((_) => item.focusNode.requestFocus());
  }

  void _toggleItem(int i) {
    if (i < 0 || i >= _items.length) return;
    _items[i].done.value = !_items[i].done.value;
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final willBeEmpty = _items.length == 1;
    final removed = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => RemovedChecklistRow(
        text: removed.controller.text,
        done: removed.done.value,
        animation: animation,
      ),
      duration: const Duration(milliseconds: 220),
    );
    if (willBeEmpty) setState(() {});
    removed.dispose();
  }

  void _removeEmptyTrailing() {
    while (_items.isNotEmpty && _items.last.controller.text.trim().isEmpty) {
      _removeItemAt(_items.length - 1);
    }
  }

  void _ensureSubtaskSeed() {
    if (_items.isEmpty) {
      _addItem();
    } else {
      setState(() {});
    }
  }

  void _toggleSection(_OptionSection section) {
    FocusScope.of(context).unfocus();
    setState(() {
      _openSection =
          _openSection == section ? _OptionSection.none : section;
    });
  }

  bool _isOpen(_OptionSection section) => _openSection == section;

  int _parseControllerValue(TextEditingController ctrl, int fallback) {
    return int.tryParse(ctrl.text.trim()) ?? fallback;
  }

  void _setControllerValue(
    TextEditingController ctrl,
    int value,
    int min,
    int max,
  ) {
    final v = value.clamp(min, max);
    setState(() => ctrl.text = v.toString());
  }

  void _adjustController(
    TextEditingController ctrl,
    int delta,
    int min,
    int max,
  ) {
    final current = _parseControllerValue(ctrl, min);
    final next = (current + delta).clamp(min, max);
    setState(() => ctrl.text = next.toString());
  }

  void _clampControllerValue(
    TextEditingController ctrl,
    int min,
    int max,
  ) {
    final v = _parseControllerValue(ctrl, min).clamp(min, max);
    if (v.toString() != ctrl.text.trim()) {
      setState(() => ctrl.text = v.toString());
    } else {
      setState(() {});
    }
  }

  void _setStatPicks(List<StatPick> picks) {
    _statPicksN.value = List<StatPick>.from(picks);
    setState(() {});
  }

  void _toggleStat(String id) {
    final list = List<StatPick>.from(_statPicksN.value);
    final idx = list.indexWhere((p) => p.id == id);
    if (idx == -1) {
      list.add(StatPick(id: id, amount: 100));
    } else {
      list.removeAt(idx);
    }
    _setStatPicks(list);
  }

  void _setStatAmount(String id, int amount) {
    final list = List<StatPick>.from(_statPicksN.value);
    final idx = list.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    list[idx] = StatPick(id: id, amount: amount.clamp(1, 999).toInt());
    _setStatPicks(list);
  }

  void _removeStat(String id) {
    final list = List<StatPick>.from(_statPicksN.value)
      ..removeWhere((p) => p.id == id);
    _setStatPicks(list);
  }

  // ----------------- Nav helpers -----------------
  void _requestKeyboard() {
    _titleFocus.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _close() {
    if (_closing || _popped) return;
    _closing = true;
    _popped = true;
    Navigator.of(context).pop();
  }

  Future<void> _deleteObjective() async {
    if (widget.onDelete != null) {
      widget.onDelete!();
      return;
    }

    // Default delete behavior: confirm and close
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Discard objective?',
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

  Future<void> _save() async {
    if (_closing || _popped) return;
    _removeEmptyTrailing();

    final title =
        _titleCtrl.text.trim().isEmpty ? 'Objective' : _titleCtrl.text.trim();
    final xp = _xpValue;
    final target =
        _isAbstinence ? 1 : (int.tryParse(_targetCtrl.text.trim()) ?? 1);
    final statPicks = _statPicksN.value;
    final cat = _categoryId;
    final description = _descriptionCtrl.text.trim().isEmpty
        ? null
        : _descriptionCtrl.text.trim();
    final selectedDays = _selectedWeekdays();

    if (title.isEmpty || xp <= 0 || cat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter title, choose category, and a positive XP.'),
        ),
      );
      return;
    }
    if (!_isAbstinence &&
        statPicks.isEmpty &&
        !widget.useAccountPills) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one stat.')),
      );
      return;
    }
    if (!_useInterval && selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose at least one day.')),
      );
      return;
    }
    if (_useInterval && _repeatEvery < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repeat interval must be at least 1.')),
      );
      return;
    }

    // Defaults matched to AddItemFab “New Objective” creation.
    final startDateOnly = DateKeys.dateOnly(DateTime.now());
    final activeDays = _useInterval
        ? {for (int i = 1; i <= 7; i++) i: true}
        : {
            for (final d in _kWeekdayOrder) d: _activeDays[d] == true,
          };
    final int? repeatEveryNDays =
        _useInterval ? _repeatEvery.clamp(1, 365).toInt() : null;
    final DateTime repeatAnchorDate = startDateOnly;

    final String? finalDescription = widget.useCashflowPills &&
            _selectedCashflow != null
        ? '${description ?? ''} [Flow: $_selectedCashflow]'.trim()
        : description;

    context.read<ObjectiveProvider>().addObjective(
          title: title,
          type: _isAbstinence ? ObjectiveType.standard : _type,
          categoryIds: [cat],
          statIds: _isAbstinence
              ? const []
              : widget.useAccountPills
                  ? (_selectedAccount != null ? [_selectedAccount!] : const [])
                  : statPicks.map((p) => p.id).toList(growable: false),
          description: finalDescription,
          targetAmount: target,
          xpReward: xp,
          startDate: startDateOnly,
          activeDays: activeDays,
          repeatEveryNDays: repeatEveryNDays,
          repeatAnchorDate: repeatAnchorDate,
          abstinenceEnabled: _isAbstinence,
          abstinenceStartDate: _isAbstinence ? startDateOnly : null,
          isStatic: true,
        );

    _closing = true;
    _popped = true;
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Objective "$title" created')),
      );
    }
  }

  // ----------------- Lifecycle -----------------
  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle ?? '';
    _amountCtrl.text = _formatAmountInput(_xpValue);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autofocusTitle) _requestKeyboard();
    });
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    _titleCtrl.dispose();
    _titleFocus.dispose();
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _targetCtrl.dispose();
    _statPicksN.dispose();
    super.dispose();
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets;
    final pad = mq.padding;

    final provider = context.watch<ObjectiveProvider>();
    final categories = provider.categories.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final defaultCats = categories
        .map((c) => (id: c.id, name: c.name, colorInt: c.colorInt))
        .toList(growable: false);
    final catTuples = widget.categoryOverride ?? defaultCats;
    final bool showTarget = _type == ObjectiveType.tally;
    final bool showXp = !_isAbstinence;
    final bool showStats = !_isAbstinence;
    final bool hasAfterRepetition = showTarget || showXp || showStats;
    final bool showDescription = widget.showDescriptionTab;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ===== Body above footer =====
          Positioned.fill(
            bottom: insets.bottom + _kBarH,
            child: SafeArea(
              top: true,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  final caretY = box.maxHeight * 0.20;
                  final contentTop = caretY + 110;

                  return Stack(
                    children: [
                      // Top-right controls
                      CornerIcons(
                        top: 0,
                        leftIcon: Icons.delete_outline,
                        onLeftPressed: _deleteObjective,
                        leftTooltip: 'Discard',
                        rightIcon: Icons.close,
                        onRightPressed: _close,
                        rightTooltip: 'Close',
                      ),

                      // Centered title
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
                              autofocus: widget.autofocusTitle,
                            ),
                          ),
                        ),
                      ),

                      // Scrollable content below title
                      Positioned.fill(
                        top: contentTop,
                        child: ScrollConfiguration(
                          behavior: const NoGlowScrollBehavior(),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_isSubtask) ...[
                                  AddItemTile(onAdd: _addItem),
                                  const SizedBox(height: 12),

                                  Offstage(
                                    offstage: _items.isEmpty || !_isSubtask,
                                    child: AnimatedList(
                                      key: _listKey,
                                      initialItemCount: _items.length,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index, animation) {
                                        final item = _items[index];
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: SizeTransition(
                                            sizeFactor: CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOut,
                                            ),
                                            child: Dismissible(
                                              key: item.key,
                                              direction:
                                                  DismissDirection.horizontal,
                                              confirmDismiss:
                                                  (direction) async {
                                                _removeItemAt(index);
                                                return false;
                                              },
                                              background:
                                                  const SizedBox.shrink(),
                                              child: ChecklistRow(
                                                controller: item.controller,
                                                focusNode: item.focusNode,
                                                doneListenable: item.done,
                                                onToggle: () =>
                                                    _toggleItem(index),
                                                onSubmitted: (last) {
                                                  if (last) _addItem();
                                                },
                                                onDelete: () =>
                                                    _removeItemAt(index),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // ===== 1:1 Options Pill (reuses TaskEditor pieces) =====
                                RoundedGroup(
                                  radius: 16,
                                  children: widget.useCashflowPills
                                      ? [
                                          // Category
                                          RowTile(
                                            title: widget.categoryLabel,
                                            subtitle:
                                                _categorySubtitle(catTuples),
                                            trailingIcon:
                                                Icons.folder_rounded,
                                            onTap: () => _toggleSection(
                                                _OptionSection.category),
                                          ),
                                          _InlineDrop(
                                            expanded: _isOpen(
                                                _OptionSection.category),
                                            child: _buildCategoryOptions(
                                                catTuples),
                                          ),
                                          const DividerRow(),

                                          // Cash Flow (XP)
                                          RowTile(
                                            title: widget.xpLabel,
                                            subtitle: _xpSubtitle(),
                                            trailingIcon: Icons.bolt_rounded,
                                            onTap: () => _toggleSection(
                                                _OptionSection.xp),
                                          ),
                                          _InlineDrop(
                                            expanded:
                                                _isOpen(_OptionSection.xp),
                                            child: _buildXpOptions(),
                                          ),
                                          const DividerRow(),

                                          // Amount
                                          RowTile(
                                            title: widget.typeLabel,
                                            subtitle: widget.useAmountSlider
                                                ? _amountSubtitle()
                                                : _typeLabel(_type),
                                            trailingIcon:
                                                Icons.flag_outlined,
                                            onTap: () => _toggleSection(
                                                _OptionSection.type),
                                          ),
                                          _InlineDrop(
                                            expanded:
                                                _isOpen(_OptionSection.type),
                                            child: widget.useAmountSlider
                                                ? _buildAmountOptions()
                                                : _buildTypeOptions(),
                                          ),
                                          const DividerRow(),

                                          // Account
                                          RowTile(
                                            title: widget.statsLabel,
                                            subtitle: widget.useAccountPills
                                                ? (_selectedAccount ??
                                                    'Pick one')
                                                : _statsSummary(
                                                    _statPicksN.value),
                                            trailingIcon:
                                                Icons.trending_up_rounded,
                                            onTap: _isAbstinence
                                                ? null
                                                : () => _toggleSection(
                                                      _OptionSection.stats,
                                                    ),
                                          ),
                                          _InlineDrop(
                                            expanded: _isOpen(
                                                _OptionSection.stats),
                                            child: widget.useAccountPills
                                                ? _buildAccountOptions()
                                                : _buildStatsOptions(),
                                          ),
                                          const DividerRow(),

                                          // Repetition
                                          RowTile(
                                            title: widget.repetitionLabel,
                                            subtitle: _repetitionSubtitle(),
                                            trailingIcon: Icons
                                                .calendar_today_outlined,
                                            onTap: () => _toggleSection(
                                                _OptionSection.repetition),
                                          ),
                                          _InlineDrop(
                                            expanded: _isOpen(
                                                _OptionSection.repetition),
                                            child: _buildRepetitionOptions(
                                              roundedBottom:
                                                  !(showDescription),
                                            ),
                                          ),
                                          if (showDescription)
                                            const DividerRow(),

                                          if (showDescription) ...[
                                            RowTile(
                                              title:
                                                  widget.descriptionLabel,
                                              subtitle:
                                                  _descriptionSubtitle(),
                                              trailingIcon:
                                                  Icons.text_fields_outlined,
                                              onTap: () => _toggleSection(
                                                _OptionSection.description,
                                              ),
                                            ),
                                            _InlineDrop(
                                              expanded: _isOpen(
                                                  _OptionSection.description),
                                              child:
                                                  _buildDescriptionOptions(),
                                            ),
                                          ],
                                        ]
                                      : [
                                          // Category
                                          RowTile(
                                            title: widget.categoryLabel,
                                            subtitle:
                                                _categorySubtitle(catTuples),
                                            trailingIcon:
                                                Icons.folder_rounded,
                                            onTap: () => _toggleSection(
                                                _OptionSection.category),
                                          ),
                                          _InlineDrop(
                                            expanded: _isOpen(
                                                _OptionSection.category),
                                            child: _buildCategoryOptions(
                                                catTuples),
                                          ),
                                          const DividerRow(),

                                          // Objective type / Amount
                                          RowTile(
                                            title: widget.typeLabel,
                                            subtitle: widget.useAmountSlider
                                                ? _amountSubtitle()
                                                : _typeLabel(_type),
                                            trailingIcon:
                                                Icons.flag_outlined,
                                            onTap: () => _toggleSection(
                                                _OptionSection.type),
                                          ),
                                          _InlineDrop(
                                            expanded: _isOpen(
                                                _OptionSection.type),
                                            child: widget.useAmountSlider
                                                ? _buildAmountOptions()
                                                : _buildTypeOptions(),
                                          ),
                                          const DividerRow(),

                                          // Repetition
                                          RowTile(
                                            title: widget.repetitionLabel,
                                            subtitle: _repetitionSubtitle(),
                                            trailingIcon: Icons
                                                .calendar_today_outlined,
                                            onTap: () => _toggleSection(
                                                _OptionSection.repetition),
                                          ),
                                          _InlineDrop(
                                            expanded: _isOpen(
                                                _OptionSection.repetition),
                                            child: _buildRepetitionOptions(
                                              roundedBottom:
                                                  !hasAfterRepetition,
                                            ),
                                          ),
                                          if (hasAfterRepetition)
                                            const DividerRow(),

                                          // Target amount
                                          if (showTarget) ...[
                                            RowTile(
                                              title: 'Target Amount',
                                              subtitle: _targetSubtitle(),
                                              trailingIcon: Icons
                                                  .radio_button_checked_rounded,
                                              onTap: _isAbstinence
                                                  ? null
                                                  : () => _toggleSection(
                                                        _OptionSection.target,
                                                      ),
                                            ),
                                            _InlineDrop(
                                              expanded: _isOpen(
                                                  _OptionSection.target),
                                              child: _buildTargetOptions(),
                                            ),
                                            if (showXp || showStats)
                                              const DividerRow(),
                                          ],

                                          // XP reward
                                          if (showXp) ...[
                                            RowTile(
                                              title: widget.xpLabel,
                                              subtitle: _xpSubtitle(),
                                              trailingIcon:
                                                  Icons.bolt_rounded,
                                              onTap: () => _toggleSection(
                                                  _OptionSection.xp),
                                            ),
                                            _InlineDrop(
                                              expanded:
                                                  _isOpen(_OptionSection.xp),
                                              child: _buildXpOptions(),
                                            ),
                                            if (showStats)
                                              const DividerRow(),
                                          ],

                                          // Stats
                                          if (showStats) ...[
                                            RowTile(
                                              title: widget.statsLabel,
                                              subtitle: widget.useAccountPills
                                                  ? (_selectedAccount ??
                                                      'Pick one')
                                                  : _statsSummary(
                                                      _statPicksN.value),
                                              trailingIcon:
                                                  Icons.trending_up_rounded,
                                              onTap: _isAbstinence
                                                  ? null
                                                  : () => _toggleSection(
                                                        _OptionSection.stats,
                                                      ),
                                            ),
                                            _InlineDrop(
                                              expanded: _isOpen(
                                                  _OptionSection.stats),
                                              child: widget.useAccountPills
                                                  ? _buildAccountOptions()
                                                  : _buildStatsOptions(),
                                            ),
                                            if (showDescription)
                                              const DividerRow(),
                                          ],

                                          if (showDescription) ...[
                                            RowTile(
                                              title:
                                                  widget.descriptionLabel,
                                              subtitle:
                                                  _descriptionSubtitle(),
                                              trailingIcon:
                                                  Icons.text_fields_outlined,
                                              onTap: () => _toggleSection(
                                                _OptionSection.description,
                                              ),
                                            ),
                                            _InlineDrop(
                                              expanded: _isOpen(
                                                  _OptionSection.description),
                                              child:
                                                  _buildDescriptionOptions(),
                                            ),
                                          ],
                                        ],
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

          // ===== Footer (Cancel / Done) =====
          Positioned(
            left: 0,
            right: 0,
            bottom: insets.bottom,
            child: Container(
              height: _kBarH + pad.bottom,
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

  // -------- helpers --------
  String _typeLabel(ObjectiveType t) {
    switch (t) {
      case ObjectiveType.standard:
        return 'Standard';
      case ObjectiveType.tally:
        return 'Tally';
      case ObjectiveType.writingPrompt:
        return 'Writing prompt';
      case ObjectiveType.stopwatch:
        return 'Stopwatch';
      case ObjectiveType.subtask:
        return 'Subtask';
      case ObjectiveType.reflective:
        return 'Reflective';
      case ObjectiveType.abstinence:
        return 'Abstinence';
    }
  }

  String _catLabel(
      List<({String id, String name, int? colorInt})> cats, String? id) {
    if (id == null || id.isEmpty) return '—';
    final hit = cats.where((c) => c.id == id);
    if (hit.isEmpty) return '—';
    return hit.first.name.isEmpty ? '—' : hit.first.name;
  }

  String _categorySubtitle(
      List<({String id, String name, int? colorInt})> cats) {
    final label = _catLabel(cats, _categoryId);
    return label == '—' ? 'Pick one' : label;
  }

  String _targetSubtitle() {
    if (_isAbstinence) return 'Locked to 1';
    final value = _parseControllerValue(_targetCtrl, 1);
    return '×$value';
  }

  String _xpSubtitle() {
    if (widget.useCashflowPills) {
      return _selectedCashflow ?? 'Choose one';
    }
    return _xpValue <= 0 ? 'Set a value' : '×$_xpValue';
  }

  String _formatCurrency(num value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatAmountInput(num value) {
    return value.toStringAsFixed(2);
  }

  String _amountSubtitle() {
    final int v = _xpValue.clamp(0, 999999).toInt();
    return _formatCurrency(v);
  }

  String _descriptionSubtitle() {
    if (_descriptionCtrl.text.trim().isEmpty) return 'Add notes';
    final t = _descriptionCtrl.text.trim();
    return t.length > 40 ? '${t.substring(0, 40)}…' : t;
  }

  List<int> _selectedWeekdays() {
    return _kWeekdayOrder
        .where((d) => _activeDays[d] == true)
        .toList(growable: false);
  }

  String _weekdayAbbrev(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'TH';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'SU';
      default:
        return '';
    }
  }

  String _repetitionSubtitle() {
    if (_useInterval) {
      final n = _repeatEvery.clamp(1, 365).toInt();
      return 'Every $n day${n == 1 ? '' : 's'}';
    }
    final days = _selectedWeekdays();
    if (days.length == 7) return 'Every day';
    if (days.isEmpty) return 'Choose days';
    if (days.length == 5 &&
        !days.contains(DateTime.saturday) &&
        !days.contains(DateTime.sunday)) {
      return 'Weekdays';
    }
    if (days.length == 2 &&
        days.contains(DateTime.saturday) &&
        days.contains(DateTime.sunday)) {
      return 'Weekends';
    }
    return days.map(_weekdayAbbrev).where((l) => l.isNotEmpty).join(' ');
  }

  Widget _buildCategoryOptions(
      List<({String id, String name, int? colorInt})> cats) {
    if (!_isOpen(_OptionSection.category)) {
      return const SizedBox.shrink();
    }
    if (cats.isEmpty) {
      return _inlineInfo('No categories yet. Create one in Settings.');
    }
    return _ObjectiveCategoryStrip(
      categories: cats,
      selectedId: _categoryId,
      onSelect: (id) => setState(() => _categoryId = id),
    );
  }

  Widget _buildTypeOptions() {
    if (!_isOpen(_OptionSection.type)) {
      return const SizedBox.shrink();
    }
    final types = ObjectiveType.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          for (int i = 0; i < types.length; i++) ...[
            Builder(builder: (_) {
              final isAbstinenceChoice = types[i] == ObjectiveType.abstinence;
              return _optionTile(
                title: _typeLabel(types[i]),
                subtitle: _typeDescription(types[i]),
                selected: _type == types[i],
                baseColor:
                    isAbstinenceChoice ? const Color(0xFF2A1115) : null,
                selectedColor:
                    isAbstinenceChoice ? const Color(0xFF3A141A) : null,
                selectedTitleColor:
                    isAbstinenceChoice ? const Color(0xFFFF9BB2) : null,
                selectedSubtitleColor:
                    isAbstinenceChoice ? const Color(0xFFFFD8E3) : null,
                borderColor:
                    isAbstinenceChoice ? const Color(0x33FF6B8F) : null,
                selectedBorderColor:
                    isAbstinenceChoice ? const Color(0x55FF6B8F) : null,
                onTap: () {
                  final next = types[i];
                  setState(() {
                    _type = next;
                    if (_isAbstinence) {
                      _targetCtrl.text = '1';
                      _setStatPicks(const []);
                    }
                    _openSection = (next == ObjectiveType.tally && !_isAbstinence)
                        ? _OptionSection.target
                        : _OptionSection.none;
                  });
                  if (next == ObjectiveType.subtask) {
                    _ensureSubtaskSeed();
                  }
                },
              );
            }),
            if (i != types.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountOptions() {
    if (!_isOpen(_OptionSection.type)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 160,
              child: TextField(
                controller: _amountCtrl,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
                decoration: const InputDecoration(
                  prefixText: '\$',
                  prefixStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onTap: () => _amountCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _amountCtrl.text.length,
                ),
                onChanged: (text) {
                  final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
                  final parsed = double.tryParse(cleaned);
                  if (parsed != null) {
                    setState(() {
                      _xpValue = parsed.clamp(0.0, 999999.0).round();
                    });
                  }
                },
                onEditingComplete: () {
                  final cleaned =
                      _amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
                  final parsed = double.tryParse(cleaned) ?? 0.0;
                  final dollars = parsed.clamp(0.0, 999999.0).round();
                  setState(() {
                    _xpValue = dollars;
                    _amountCtrl.text = _formatAmountInput(_xpValue);
                    _amountCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _amountCtrl.text.length),
                    );
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          _MissionXpSliderBar(
            value: _xpValue.clamp(0, 10000).toInt(),
            min: 0,
            max: 10000,
            onChanged: (x) => setState(() {
              // Slider clamps to 10k but manual entry can exceed.
              _xpValue = x.clamp(0, 10000).toInt();
              _amountCtrl.text = _formatAmountInput(_xpValue);
            }),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [5, 10, 25, 50, 100]
                .map(
                  (v) => _choicePill(
                    label: '\$${v.toStringAsFixed(0)}',
                    selected: _xpValue == v,
                    onTap: () => setState(() {
                      _xpValue = v;
                      _amountCtrl.text = _formatAmountInput(_xpValue);
                    }),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetOptions() {
    if (!_isOpen(_OptionSection.target)) {
      return const SizedBox.shrink();
    }
    if (_isAbstinence) {
      return _inlineInfo('Abstinence objectives are locked to a target of 1.');
    }
    final current = _parseControllerValue(_targetCtrl, 1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _numberEditor(
            controller: _targetCtrl,
            min: 1,
            max: 999999,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final val in _kTargetPresets)
                _choicePill(
                  label: '×$val',
                  selected: current == val,
                  onTap: () =>
                      _setControllerValue(_targetCtrl, val, 1, 999999),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap a preset or type any amount up to 999,999.',
            style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildXpOptions() {
    if (widget.useCashflowPills) {
      return _buildCashflowOptions();
    }
    if (!_isOpen(_OptionSection.xp)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              '×$_xpValue',
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _MissionXpSliderBar(
            value: _xpValue.clamp(1, 999).toInt(),
            min: 1,
            max: 999,
            onChanged: (x) => setState(() {
              _xpValue = x.clamp(1, 999).toInt();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRepetitionOptions({required bool roundedBottom}) {
    if (!_isOpen(_OptionSection.repetition)) {
      return const SizedBox.shrink();
    }
    const Color panelBg = Color(0xFF151515);
    const Color toggleBg = Color(0xFF101010);
    const Color toggleBorder = Color(0x22FFFFFF);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: roundedBottom
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: toggleBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: toggleBorder),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _ScheduleToggleBtn(
                  label: 'Weekly',
                  selected: !_useInterval,
                  onTap: () => setState(() => _useInterval = false),
                ),
                const SizedBox(width: 6),
                _ScheduleToggleBtn(
                  label: 'Every X days',
                  selected: _useInterval,
                  onTap: () => setState(() => _useInterval = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!_useInterval) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Center(
                child: Text(
                  '(Repeat On)',
                  style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: _kWeekdayOrder
                    .map((day) => _WeekdayCircle(
                          label: _weekdayAbbrev(day),
                          selected: _activeDays[day] == true,
                          onTap: () => setState(() {
                            _activeDays[day] = !(_activeDays[day] == true);
                          }),
                        ))
                    .toList(growable: false),
              ),
            ),
            if (_selectedWeekdays().isEmpty) ...[
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Pick at least one day to keep this objective active.',
                  style: TextStyle(color: Color(0x80FFFFFF), fontSize: 12),
                ),
              ),
            ],
          ] else ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Center(
                child: Text(
                  '(Repeat Interval)',
                  style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101010),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _stepperButton(
                    icon: Icons.remove,
                    onTap: () => setState(() {
                      _repeatEvery =
                          (_repeatEvery - 1).clamp(1, 365).toInt();
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Every ',
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '$_repeatEvery ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: 'day${_repeatEvery == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  _stepperButton(
                    icon: Icons.add,
                    onTap: () => setState(() {
                      _repeatEvery =
                          (_repeatEvery + 1).clamp(1, 365).toInt();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Repeats every $_repeatEvery day${_repeatEvery == 1 ? '' : 's'}.',
              style:
                  const TextStyle(color: Color(0x80FFFFFF), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsOptions() {
    if (!_isOpen(_OptionSection.stats)) {
      return const SizedBox.shrink();
    }
    if (_isAbstinence) {
      return _inlineInfo('Stats are disabled for abstinence objectives.');
    }
    return _ObjectiveStatPicker(
      picks: _statPicksN,
      onToggleStat: _toggleStat,
      onSetAmount: _setStatAmount,
      onRemoveStat: _removeStat,
    );
  }

  Widget _buildDescriptionOptions() {
    if (!_isOpen(_OptionSection.description)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: TextField(
        controller: _descriptionCtrl,
        maxLines: 4,
        minLines: 2,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Optional description or notes',
          hintStyle: TextStyle(color: Color(0x80FFFFFF)),
          filled: true,
          fillColor: Color(0xFF101010),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0x22FFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0x22FFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.white),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCashflowOptions() {
    if (!_isOpen(_OptionSection.xp)) {
      return const SizedBox.shrink();
    }
    final list = widget.cashflowOptions ??
        const ['Income', 'Expense', 'Transfer'];

    final List<List<String>> rows = [];
    if (list.length >= 2) {
      rows.add(list.take(2).toList(growable: false));
      if (list.length > 2) {
        rows.add(list.sublist(2));
      }
    } else {
      rows.add(list);
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        children: [
          for (int r = 0; r < rows.length; r++) ...[
            Row(
              mainAxisAlignment: rows[r].length == 1
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: rows[r].map((label) {
                final selected = _selectedCashflow == label;
                return Expanded(
                  flex: rows[r].length == 1 ? 0 : 1,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: rows[r].length == 1 ? 0 : (label == rows[r].first ? 0 : 6),
                      right: rows[r].length == 1 ? 0 : (label == rows[r].first ? 6 : 0),
                      bottom: 8,
                    ),
                    child: _AccountPill(
                      label: label,
                      selected: selected,
                      onTap: () => setState(() {
                        _selectedCashflow = label;
                      }),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountOptions() {
    if (!_isOpen(_OptionSection.stats)) {
      return const SizedBox.shrink();
    }
    final options = widget.accountOptions ?? const <String>[];
    final list = options.isEmpty ? const ['No account'] : options;

    // Build rows of up to 2 pills; if a row has 1 pill, center it.
    final List<List<String>> rows = [];
    for (int i = 0; i < list.length; i += 2) {
      final end = (i + 2) > list.length ? list.length : i + 2;
      rows.add(list.sublist(i, end));
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int r = 0; r < rows.length; r++) ...[
            Row(
              mainAxisAlignment: rows[r].length == 1
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: rows[r].map((label) {
                final selected = _selectedAccount == label;
                return Expanded(
                  flex: rows[r].length == 1 ? 0 : 1,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: rows[r].length == 1 ? 0 : (label == rows[r].first ? 0 : 6),
                      right: rows[r].length == 1 ? 0 : (label == rows[r].first ? 6 : 0),
                      bottom: r == rows.length - 1 ? 0 : 8,
                    ),
                    child: _AccountPill(
                      label: label,
                      selected: selected,
                      onTap: () => setState(() {
                        _selectedAccount = label;
                      }),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberEditor({
    required TextEditingController controller,
    required int min,
    required int max,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          _stepperButton(
            icon: Icons.remove,
            onTap: () => _adjustController(controller, -1, min, max),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (_) => setState(() {}),
              onEditingComplete: () =>
                  _clampControllerValue(controller, min, max),
            ),
          ),
          _stepperButton(
            icon: Icons.add,
            onTap: () => _adjustController(controller, 1, min, max),
          ),
        ],
      ),
    );
  }

  Widget _inlineInfo(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
      ),
    );
  }

  Widget _choicePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A2A2A) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected ? const Color(0x33FFFFFF) : const Color(0x11FFFFFF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xCCFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_rounded, color: Colors.white, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required String title,
    String? subtitle,
    required bool selected,
    Widget? leading,
    Color? baseColor,
    Color? selectedColor,
    Color? selectedTitleColor,
    Color? selectedSubtitleColor,
    Color? borderColor,
    Color? selectedBorderColor,
    VoidCallback? onTap,
  }) {
    final Color bg = selected
        ? (selectedColor ?? const Color(0xFF2A2A2A))
        : (baseColor ?? const Color(0xFF141414));
    final Color border = selected
        ? (selectedBorderColor ?? const Color(0x33FFFFFF))
        : (borderColor ?? const Color(0x11FFFFFF));
    final Color titleColor =
        selected ? (selectedTitleColor ?? Colors.white) : Colors.white;
    final Color subtitleColor = selected
        ? (selectedSubtitleColor ?? const Color(0xB3FFFFFF))
        : const Color(0xB3FFFFFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: selected ? 1 : 0,
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  String? _typeDescription(ObjectiveType t) {
    switch (t) {
      case ObjectiveType.standard:
        return 'Complete it once per period';
      case ObjectiveType.tally:
        return 'Count multiple completions';
      case ObjectiveType.writingPrompt:
        return 'Answer a recurring prompt';
      case ObjectiveType.stopwatch:
        return 'Track time spent';
      case ObjectiveType.subtask:
        return 'Break work into smaller tasks';
      case ObjectiveType.reflective:
        return 'Log a short reflection';
      case ObjectiveType.abstinence:
        return 'Avoid something (locks stats & target)';
    }
  }

  String _statsSummary(List<StatPick> picks) {
    if (_isAbstinence) return 'Disabled for abstinence objectives';
    if (picks.isEmpty) return 'No Stats';
    final parts = <String>[];
    for (final p in picks.take(2)) {
      parts.add('${StatRepository.getDisplay(p.id)} ×${p.amount}');
    }
    final extra = picks.length - 2;
    return extra > 0 ? '${parts.join(", ")} +$extra more' : parts.join(', ');
  }
}

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

class _ScheduleToggleBtn extends StatelessWidget {
  const _ScheduleToggleBtn({
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
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 36,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.black : const Color(0xCCFFFFFF),
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayCircle extends StatelessWidget {
  const _WeekdayCircle({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Colors.white : const Color(0xFF1C1C1C),
          border: Border.all(
            color: selected ? Colors.white : const Color(0x22FFFFFF),
            width: 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : const Color(0xCCFFFFFF),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.white : const Color(0x33FFFFFF),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _ObjectiveCategoryStrip extends StatelessWidget {
  const _ObjectiveCategoryStrip({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<({String id, String name, int? colorInt})> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        borderRadius: BorderRadius.zero,
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 2, right: 2),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final cat in categories)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _ObjectiveCatChip(
                  label: cat.name.toUpperCase(),
                  selected: selectedId == cat.id,
                  onTap: () => onSelect(cat.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ObjectiveCatChip extends StatelessWidget {
  const _ObjectiveCatChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

class _ObjectiveStatPicker extends StatefulWidget {
  const _ObjectiveStatPicker({
    required this.picks,
    required this.onToggleStat,
    required this.onSetAmount,
    required this.onRemoveStat,
  });

  final ValueNotifier<List<StatPick>> picks;
  final void Function(String id) onToggleStat;
  final void Function(String id, int amount) onSetAmount;
  final void Function(String id) onRemoveStat;

  @override
  State<_ObjectiveStatPicker> createState() => _ObjectiveStatPickerState();
}

class _ObjectiveStatPickerState extends State<_ObjectiveStatPicker> {
  String? _categoryFilter; // null => ALL
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

  @override
  void dispose() {
    _catCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    final stats = (_categoryFilter == null
            ? StatRepository.getAll()
            : StatRepository.getByCategory(_categoryFilter!))
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
          // Category tabs
          SingleChildScrollView(
            controller: _catCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6),
            child: Row(
              children: [
                KeyedSubtree(
                  key: _keyFor(null),
                  child: _ObjectiveCatChip(
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
                ..._categories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: KeyedSubtree(
                        key: _keyFor(c),
                        child: _ObjectiveCatChip(
                          label: c,
                          selected: _categoryFilter == c,
                          onTap: () {
                            setState(() => _categoryFilter = c);
                            WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _scrollToCategory(c));
                          },
                        ),
                      ),
                    )),
              ],
            ),
          ),

          // Stat chips
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (currentChild, previousChildren) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [if (currentChild != null) currentChild],
            ),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.0, .05), end: Offset.zero)
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
                              color: Color(0x66FFFFFF), fontSize: 13)),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in stats)
                            ValueListenableBuilder<List<StatPick>>(
                              valueListenable: widget.picks,
                              builder: (_, picks, __) {
                                final isSelected =
                                    picks.any((p) => p.id == s.id);
                                return _ObjectiveStatChip(
                                  label: s.display,
                                  selected: isSelected,
                                  onTap: () => widget.onToggleStat(s.id),
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

          // Selected stat editors
          ValueListenableBuilder<List<StatPick>>(
            valueListenable: widget.picks,
            builder: (_, picks, __) {
              if (picks.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      'XP per Stat',
                      style: TextStyle(
                          color: Color(0x99FFFFFF),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2),
                    ),
                  ),
                  ...picks.map((p) {
                    final disp = StatRepository.getDisplay(p.id);

                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(disp,
                                  style: const TextStyle(
                                      color: Color(0xCCFFFFFF),
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Text('×${p.amount}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _MissionXpSliderBar(
                            value: p.amount.clamp(1, 999).toInt(),
                            min: 1,
                            max: 999,
                            onChanged: (v) =>
                                widget.onSetAmount(
                                    p.id, v.clamp(1, 999).toInt()),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => widget.onRemoveStat(p.id),
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                              label: const Text('Remove',
                                  style: TextStyle(color: Colors.white)),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white),
                            ),
                          ),
                        ],
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

class _ObjectiveStatChip extends StatelessWidget {
  const _ObjectiveStatChip({
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

// ===== Centered title input (same as Task/Editor) =====
class _CenteredTitleField extends StatelessWidget {
  const _CenteredTitleField({
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
      inputFormatters: [
        FilteringTextInputFormatter.singleLineFormatter,
        LengthLimitingTextInputFormatter(100),
      ],
    );
  }
}

class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
