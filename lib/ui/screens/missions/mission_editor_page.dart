import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter,
        SystemChannels;
import 'package:intl/intl.dart';

// Use the app's canonical rarity enum
import 'package:kontinuum/models/mission.dart' show MissionRarity;

import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/ui/screens/task_editor/models.dart' show StatPick;
import 'package:kontinuum/ui/widgets/corner_icons.dart';

/// ===============================
/// Mission Editor (Create / Edit)
/// ===============================

const double _kFooterBarH = 44;
const int _kMaxTitleChars = 100;

/// Public result object returned on save().
class MissionEditorResult {
  final String title;
  final String? description;
  final String? categoryId;
  final MissionRarity rarity;
  final int xpReward; // mission-level XP
  final List<StatPick> stats; // multi-select, with per-stat amounts
  const MissionEditorResult({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.rarity,
    required this.xpReward,
    required this.stats,
  });
}

String rarityLabel(MissionRarity r) {
  switch (r) {
    case MissionRarity.common:
      return 'Common';
    case MissionRarity.rare:
      return 'Rare';
    case MissionRarity.legendary:
      return 'Legendary';
  }
}

/// ---- Rarity colors (match MissionCard) ----
Color _rarityColor(MissionRarity r) {
  switch (r) {
    case MissionRarity.common:
      return Colors.white; // exact white
    case MissionRarity.rare:
      return Colors.blueAccent; // blue
    case MissionRarity.legendary:
      return Colors.deepPurpleAccent; // purple
  }
}

Color _textOn(Color bg) {
  final b = ThemeData.estimateBrightnessForColor(bg);
  return b == Brightness.dark ? Colors.white : Colors.black;
}

/// Holds all mutable options with ValueNotifiers.
class MissionOptionsController {
  // Description, Category, Rarity, XP, Stats
  final ValueNotifier<String?> descriptionN = ValueNotifier<String?>(null);
  final ValueNotifier<String?> categoryIdN = ValueNotifier<String?>(null);
  final ValueNotifier<MissionRarity> rarityN =
      ValueNotifier<MissionRarity>(MissionRarity.common);
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
    rarityN.dispose();
    xpRewardN.dispose();
    statsN.dispose();
  }
}

/// Full-screen mission creator styled like TaskEditorPage.
class MissionEditorPage extends StatefulWidget {
  const MissionEditorPage({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.initialCategoryId,
    this.initialRarity = MissionRarity.common,
    this.initialXpReward = 100,
    this.initialStats,
  });

  final String? initialTitle;
  final String? initialDescription;
  final String? initialCategoryId;
  final MissionRarity initialRarity;
  final int initialXpReward;
  final List<StatPick>? initialStats;

  @override
  State<MissionEditorPage> createState() => _MissionEditorPageState();
}

class _MissionEditorPageState extends State<MissionEditorPage> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final MissionOptionsController _opts = MissionOptionsController();

  bool _closing = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle ?? '';
    _opts.descriptionN.value = widget.initialDescription;
    _opts.categoryIdN.value = widget.initialCategoryId;
    _opts.rarityN.value = widget.initialRarity;
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
    final title =
        _titleCtrl.text.trim().isEmpty ? 'Mission' : _titleCtrl.text.trim();
    final res = MissionEditorResult(
      title: title,
      description: _opts.descriptionN.value,
      categoryId: _opts.categoryIdN.value,
      rarity: _opts.rarityN.value,
      xpReward: _opts.xpRewardN.value,
      stats: List<StatPick>.from(_opts.statsN.value),
    );
    _closing = true;
    _popped = true;
    Navigator.of(context).pop(res);
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
                            child: MissionOptionsPanel(
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

class MissionOptionsPanel extends StatefulWidget {
  const MissionOptionsPanel({super.key, required this.controller});
  final MissionOptionsController controller;

  @override
  State<MissionOptionsPanel> createState() => _MissionOptionsPanelState();
}

enum _OpenSection { none, rarity, desc, cat, stats, xp }

class _MissionOptionsPanelState extends State<MissionOptionsPanel>
    with AutomaticKeepAliveClientMixin {
  // Single source of truth: which section is open
  _OpenSection _open = _OpenSection.none;

  // Description text field state
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.controller.descriptionN.value ?? '');
  final FocusNode _descFocus = FocusNode();

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
      parts.add('${StatRepository.getDisplay(p.id)} ×${p.amount}');
    }
    final extra = picks.length - 2;
    return extra > 0 ? '${parts.join(", ")} +$extra more' : parts.join(', ');
  }

  @override
  void dispose() {
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
            // ===== RARITY =====
            ValueListenableBuilder<MissionRarity>(
              valueListenable: c.rarityN,
              builder: (_, rar, __) => _RowTile(
                title: 'Rarity',
                subtitle: rarityLabel(rar),
                trailingIcon: Icons.emoji_events_rounded,
                onTap: () => _toggleSection(_OpenSection.rarity),
              ),
            ),
            _InlineDrop(
              expanded: _isOpen(_OpenSection.rarity),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: ValueListenableBuilder<MissionRarity>(
                  valueListenable: c.rarityN,
                  builder: (_, selected, __) {
                    Widget chip(MissionRarity r, String label) => _RarityChip(
                          rarity: r,
                          label: label,
                          selected: selected == r,
                          onTap: () => c.rarityN.value = r,
                        );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: chip(MissionRarity.common, 'Common')),
                            const SizedBox(width: 8),
                            Expanded(child: chip(MissionRarity.rare, 'Rare')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Spacer(),
                            Expanded(
                              flex: 3,
                              child: chip(MissionRarity.legendary, 'Legendary'),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const _DividerRow(),

            // ===== CATEGORY (moved above Description) =====
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
                      builder: (_, v, __) => Center(
                        child: Text(
                          '×$v',
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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
          ],
        ),
      ],
    );
  }
}

/// Full-bleed Category strip with STRAIGHT corners (no rounding).
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.controller});
  final MissionOptionsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        borderRadius: BorderRadius.zero, // <-- no rounded corners anywhere
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: ValueListenableBuilder<String?>(
        valueListenable: controller.categoryIdN,
        builder: (_, selected, __) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 2),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final entry in _kMissionCategories.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _MissionCatChip(
                      label: entry.value.toUpperCase(),
                      selected: selected == entry.key,
                      onTap: () => controller.categoryIdN.value = entry.key,
                    ),
                  ),
              ],
            ),
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
    final controller = context
        .findAncestorStateOfType<_MissionOptionsPanelState>()!
        .widget
        .controller;

    // Build list for current filter
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
          // Category tabs (horizontal)
          SingleChildScrollView(
            controller: _catCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6),
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
                          .addPostFrameCallback((_) => _scrollToCategory(null));
                    },
                  ),
                ),
                const SizedBox(width: 6),
                ..._categories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: KeyedSubtree(
                        key: _keyFor(c),
                        child: _MissionCatChip(
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

          // Stat chips (wrap)
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
                              valueListenable: controller.statsN,
                              builder: (_, picks, __) {
                                final isSelected =
                                    picks.any((p) => p.id == s.id);
                                return _MissionStatChip(
                                  label: s.display,
                                  selected: isSelected,
                                  onTap: () => controller.toggleStat(s.id),
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

          // Selected stat editors (per-stat amounts)
          ValueListenableBuilder<List<StatPick>>(
            valueListenable: controller.statsN,
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
                            value: p.amount.clamp(1, 999),
                            min: 1,
                            max: 999,
                            onChanged: (v) => controller.setStatAmount(p.id, v),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => controller.removeStat(p.id),
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

/// ---- Chips used by both the Stats category row and Category picker ----
class _MissionCatChip extends StatelessWidget {
  const _MissionCatChip({
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

/// ---- Rarity chip that matches mission-card colors ----
class _RarityChip extends StatelessWidget {
  const _RarityChip({
    required this.rarity,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final MissionRarity rarity;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selBg = _rarityColor(rarity);
    final bg = selected ? selBg : const Color(0xFF232323);
    final fg = selected ? _textOn(selBg) : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0x22FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
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

/// ===============================
/// Local helpers / constants
/// ===============================

String _trimOneLine(String t) {
  final s = t.trim();
  return s.length <= 64 ? s : '${s.substring(0, 64)}…';
}

/// Temporary list for categories to avoid external dep here.
/// Replace with your real repository if available.
const Map<String, String> _kMissionCategories = <String, String>{
  'rap': 'Rap',
  'production': 'Production',
  'health': 'Health',
  'knowledge': 'Knowledge',
  'business': 'Business',
};
