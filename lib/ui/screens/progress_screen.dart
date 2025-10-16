// lib/ui/screens/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/year_progress_date.dart';
import 'package:kontinuum/ui/widgets/objective_list_item.dart';
import 'package:kontinuum/ui/widgets/xp_level_bar.dart';
import 'package:kontinuum/ui/screens/stats_dashboard.dart';
import 'package:kontinuum/ui/screens/mission_board_screen.dart';
import 'package:kontinuum/ui/objective_type_handlers/objective_type_factory.dart';
import 'package:kontinuum/ui/screens/project_screen.dart'; // ⬅️ fixed import
import 'package:kontinuum/ui/widgets/add_item_fab.dart';

// ⬇️ calendar screen for swipe-down (appears from top)
import 'package:kontinuum/ui/widgets/calendar/calendar_fullscreen_page.dart';

// Optional screens for the FAB drawer:
import 'package:kontinuum/ui/screens/budget/budget_screen.dart';
// If your writing editor has a different widget/route, update this import/usage.
import 'package:kontinuum/ui/writing_editor/block_text_editor.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with TickerProviderStateMixin {
  final Map<String, bool> _expandedCategories = {};

  // ---- Organize mode ----
  bool _organizeMode = false;
  List<String> _categoryOrder = [];

  // ---- Right-side mini drawer state ----
  late final AnimationController _fabCtrl;
  bool _fabOpen = false;

  // ---- Horizontal "scroll over" between Progress ↔ Mission Board ----
  late final PageController _pageCtrl;
  // With reversed PageView, index 0 = rightmost, index 1 = leftmost
  int _pageIndex = 0; // start on Progress (right)

  // Leave space so list content never hides behind the XP bar.
  static const double _listBottomInsetForXpBar = 120;

  // ---- Top-edge swipe-down to Calendar ----
  bool _calendarPushed = false;
  double? _dragStartY;

  // ---- Bottom XP bar controller (for jump + animate on completion) ----
  final XpLevelBarController _xpBarCtrl = XpLevelBarController();

  // ---- Vertical slide to Stats (opaque, on TOP) ----
  late final AnimationController _statsSlideCtrl; // 0 = hidden, 1 = shown
  double? _statsDragStartGlobalY;

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pageCtrl = PageController(initialPage: 0);

    _statsSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    _pageCtrl.dispose();
    _statsSlideCtrl.dispose();
    super.dispose();
  }

  void _toggleFab({bool? open}) {
    setState(() {
      _fabOpen = open ?? !_fabOpen;
      if (_fabOpen) {
        _fabCtrl.forward();
      } else {
        _fabCtrl.reverse();
      }
    });
  }

  Future<void> _goToBoard() async {
    await _pageCtrl.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToProgress() async {
    await _pageCtrl.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openCalendarOnce() async {
    if (_calendarPushed) return;
    _calendarPushed = true;

    final provider = Provider.of<ObjectiveProvider>(context, listen: false);
    final selected = provider.selectedDateNotifier.value;
    final first = DateTime(selected.year - 5, 1, 1);
    final last = DateTime(selected.year + 5, 12, 31);

    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, __, ___) => FullscreenCalendarPage(
          initialDate: selected,
          firstDate: first,
          lastDate: last,
        ),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(curved);
          final fade = Tween<double>(begin: 0, end: 1).animate(curved);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );

    _calendarPushed = false;
  }

  // ====== Delete confirms ======
  Future<bool> _confirmDeleteObjective(
    BuildContext context,
    String title,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Delete objective?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              '“$title” will be permanently removed.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmDeleteCategory(
    BuildContext context,
    String categoryId,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Delete category?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'All objectives in “$categoryId” will be uncategorized.\n\nThis cannot be undone.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ====== Dismissible objective row (normal mode) ======
  Widget _buildDismissibleObjectiveRow({
    required BuildContext context,
    required ObjectiveProvider provider,
    required Objective obj,
    required DateTime selectedDate,
  }) {
    final handler = getHandlerForType(obj.type);

    return _RightEdgeDismissible(
      dismissibleKey: ValueKey('obj_${obj.id}'),
      enabled: !_organizeMode,
      confirmDelete: () => _confirmDeleteObjective(context, obj.title),
      onDismissed: () async {
        await provider.deleteObjective(obj.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Objective “${obj.title}” deleted')),
          );
        }
      },
      buildSecondaryBackground: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: .4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete', style: TextStyle(color: Colors.redAccent)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.redAccent),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: _organizeMode
            ? null
            : () {
                final handlerWidget = handler.buildInputWidget(
                  objective: obj,
                  selectedDate: selectedDate,
                  onToggleComplete: () {
                    final p = provider;
                    p.toggleObjectiveCompletion(selectedDate, obj.id);
                    p.evaluateLocks(selectedDate);
                    Navigator.of(context).pop();
                  },
                  onUpdateAmount: (newAmount) {
                    final p = provider;
                    p.updateObjectiveAmountForDate(
                      selectedDate,
                      obj.id,
                      newAmount,
                    );
                    p.evaluateLocks(selectedDate);
                    Navigator.of(context).pop();
                  },
                );

                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.grey[900],
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: handlerWidget,
                  ),
                );
              },
        child: _organizeMode
            ? _OrganizeObjectiveTile(objective: obj, onStartDrag: (_) {})
            : ObjectiveListItem(objective: obj, selectedDate: selectedDate),
      ),
    );
  }

  // Keep category order in sync
  void _syncCategoryOrder(Iterable<String> current) {
    if (_categoryOrder.isEmpty) {
      _categoryOrder = current.toList();
      return;
    }
    final now = current.toList();
    final next = <String>[];
    for (final id in _categoryOrder) {
      if (now.contains(id)) next.add(id);
    }
    for (final id in now) {
      if (!next.contains(id)) next.add(id);
    }
    _categoryOrder = next;
  }

  // Footer with Add + Organize
  Widget _footerButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AddItemFab(),
            const SizedBox(height: 12),
            _OrganizeToggleButton(
              isOn: _organizeMode,
              onToggle: () => setState(() => _organizeMode = !_organizeMode),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Stats slide gestures (drag UP on XP bar) =====
  void _statsDragStart(DragStartDetails d) {
    _statsDragStartGlobalY = d.globalPosition.dy;
  }

  void _statsDragUpdate(DragUpdateDetails d) {
    if (_statsDragStartGlobalY == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final height = box.size.height;
    // Upward drag increases progress: 0 → 1
    final dy = (_statsDragStartGlobalY! - d.globalPosition.dy); // up = +
    final delta = (dy / height).clamp(0.0, 1.0);
    _statsSlideCtrl.value = delta;
  }

  void _statsDragEnd(DragEndDetails d) {
    _statsDragStartGlobalY = null;
    final vy = -d.velocity.pixelsPerSecond.dy; // up = positive
    final shouldOpen = _statsSlideCtrl.value > 0.2 || vy > 600;
    _statsSlideCtrl.fling(velocity: shouldOpen ? 2.0 : -2.0);
  }

  void _openStatsFully() {
    _statsSlideCtrl.animateTo(
      1.0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 320),
    );
  }

  void _closeStats() {
    _statsSlideCtrl.animateTo(
      0.0,
      curve: Curves.easeInCubic,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ObjectiveProvider>(context);
    final media = MediaQuery.of(context);
    final screenH = media.size.height;

    // Height for the top-edge gesture catcher
    final double topInset = media.padding.top;
    final double topEdgeHeight = (topInset + 10).clamp(24.0, 48.0);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Close stats first if open (even partially)
        if (_statsSlideCtrl.value > 0.01) {
          _closeStats();
          return;
        }
        if (_pageIndex == 1) {
          await _goToProgress();
          return;
        }
        // Close FAB drawer if open
        if (_fabOpen) {
          _toggleFab(open: false);
          return;
        }
        // Allow system back if nothing to intercept
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // ===== BASE: Progress layer (static; does NOT blend with stats)
              _buildProgressLayer(
                provider: provider,
                topEdgeHeight: topEdgeHeight,
              ),

              // ===== TOP: Stats slides up from bottom (full-screen & opaque)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _statsSlideCtrl,
                  builder: (context, _) {
                    final offset = Tween<Offset>(
                      begin: const Offset(0, 1), // off-screen bottom
                      end: Offset.zero,
                    ).transform(_statsSlideCtrl.value);
                    return Transform.translate(
                      offset: Offset(0, offset.dy * screenH),
                      child: IgnorePointer(
                        ignoring: _statsSlideCtrl.value == 0.0,
                        child:
                            const StatsDashboard(), // has its own Scaffold bg
                      ),
                    );
                  },
                ),
              ),

              // ===== Floating Action Button + Drawer =====
              _buildFabDrawer(context, provider),
            ],
          ),
        ),
      ),
    );
  }

  // Full progress layer (moves horizontally to board, not vertically)
  Widget _buildProgressLayer({
    required ObjectiveProvider provider,
    required double topEdgeHeight,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          PageView(
            controller: _pageCtrl,
            scrollDirection: Axis.horizontal,
            reverse: true, // board is LEFT, progress is RIGHT
            allowImplicitScrolling: true,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            onPageChanged: (i) => setState(() => _pageIndex = i),
            children: [
              _buildProgressContent(provider),
              const MissionBoardScreen(),
            ],
          ),

          // ⬇️ TOP-edge SWIPE-DOWN strip → Calendar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: topEdgeHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              excludeFromSemantics: true,
              onVerticalDragStart: (d) => _dragStartY = d.globalPosition.dy,
              onVerticalDragUpdate: (d) {
                final start = _dragStartY ?? d.globalPosition.dy;
                final dy = d.globalPosition.dy - start; // down = +
                if (dy > 36) _openCalendarOnce();
              },
              onVerticalDragEnd: (_) => _dragStartY = null,
            ),
          ),

          // 🔒 LEFT-EDGE SWIPE STRIP — swipe-only; taps pass through
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 40,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent, // let taps hit below
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -8) _goToBoard();
                },
              ),
            ),
          ),

          // 🧭 Mission Board — jump via icon (ONLY on Progress page)
          if (_pageIndex == 0)
            Positioned(
              top: -10,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.flag_outlined, color: Colors.white),
                tooltip: 'Mission Board',
                onPressed: _goToBoard,
              ),
            ),
        ],
      ),
    );
  }

  // ----- Progress content (original body) -----
  Widget _buildProgressContent(ObjectiveProvider provider) {
    return Stack(
      children: [
        ValueListenableBuilder<DateTime>(
          valueListenable: provider.selectedDateNotifier,
          builder: (context, selectedDate, _) {
            final objectives = provider.getObjectivesForDay(selectedDate);

            final Map<String, List<Objective>> groupedByCategory = {};
            for (final obj in objectives) {
              final category = obj.categoryIds.isNotEmpty
                  ? obj.categoryIds.first
                  : 'Uncategorized';
              groupedByCategory.putIfAbsent(category, () => []).add(obj);
            }

            final catIds = groupedByCategory.keys;
            _syncCategoryOrder(catIds);

            final orderedCats = _categoryOrder
                .where((id) => groupedByCategory.containsKey(id))
                .toList();

            Widget header = Column(
              children: [
                Consumer<ObjectiveProvider>(
                  builder: (context, provider, _) {
                    return YearProgressBar(
                      selectedDate: selectedDate,
                      getProgressForDay: provider.getProgressForDay,
                      onDateSelected: (date) {
                        provider.selectedDateNotifier.value = date;
                      },
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4.0, bottom: 2.0),
                  child: Text(
                    "Objectives",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_organizeMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .12),
                        ),
                      ),
                      child: const Text(
                        "Organize mode: drag ≡ to reorder categories.\n"
                        "Long-press objectives to reorder within a category.\n"
                        "Drag ⠿ onto another category header to move it.",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            );

            if (groupedByCategory.isEmpty) {
              return Column(
                children: [
                  header,
                  const Expanded(
                    child: Center(
                      child: Text(
                        "No objectives for this day",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  _footerButtons(),
                  // ⬇️ XP bar is the drag handle to open stats
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _statsDragStart,
                    onVerticalDragUpdate: _statsDragUpdate,
                    onVerticalDragEnd: _statsDragEnd,
                    onTap: _openStatsFully,
                    child: XpLevelBar(
                      controller: _xpBarCtrl,
                      onStatsPressed: _openStatsFully, // shows & taps icon
                    ),
                  ),
                ],
              );
            }

            final list = _organizeMode
                ? _buildReorderableCategoryList(
                    orderedCats,
                    groupedByCategory,
                    provider,
                    selectedDate,
                  )
                : _buildNormalCategoryList(
                    orderedCats,
                    groupedByCategory,
                    provider,
                    selectedDate,
                  );

            return Column(
              children: [
                header,
                Expanded(child: list),
                // ⬇️ XP bar is the drag handle to open stats
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _statsDragStart,
                  onVerticalDragUpdate: _statsDragUpdate,
                  onVerticalDragEnd: _statsDragEnd,
                  onTap: _openStatsFully,
                  child: XpLevelBar(
                    controller: _xpBarCtrl,
                    onStatsPressed: _openStatsFully, // shows & taps icon
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ===== Normal category list (no organize) =====
  Widget _buildNormalCategoryList(
    List<String> orderedCats,
    Map<String, List<Objective>> groupedByCategory,
    ObjectiveProvider provider,
    DateTime selectedDate,
  ) {
    final children = <Widget>[
      for (final category in orderedCats)
        _buildCategoryTile(
          category,
          groupedByCategory[category]!,
          provider,
          selectedDate,
        ),
    ];
    children.addAll(const [SizedBox(height: 8)]);
    children.add(_footerButtons());
    children.add(const SizedBox(height: 4));

    return ListView(
      padding: const EdgeInsets.only(bottom: _listBottomInsetForXpBar),
      children: children,
    );
  }

  Widget _buildCategoryTile(
    String category,
    List<Objective> items,
    ObjectiveProvider provider,
    DateTime selectedDate,
  ) {
    final isExpanded = _expandedCategories[category] ?? true;
    final isUncategorized = category == 'Uncategorized';

    return DragTarget<_ObjectiveDrag>(
      onWillAcceptWithDetails: (_) => _organizeMode,
      onAcceptWithDetails: (details) async {
        if (!_organizeMode) return;
        final data = details.data;
        if (data.fromCategoryId == category) return;
        await provider.moveObjectiveToCategory(
          objectiveId: data.objectiveId,
          newCategoryId: category,
          date: selectedDate,
        );
        if (mounted) setState(() {});
      },
      builder: (context, _, __) {
        return _RightEdgeDismissible(
          dismissibleKey: ValueKey('cat_$category'),
          enabled: !(_organizeMode || isUncategorized),
          confirmDelete: () => _confirmDeleteCategory(context, category),
          onDismissed: () async {
            await provider.deleteCategory(category);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Category “$category” deleted')),
              );
            }
          },
          buildSecondaryBackground: () => Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: .4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Delete', style: TextStyle(color: Colors.redAccent)),
                SizedBox(width: 8),
                Icon(Icons.delete_forever, color: Colors.redAccent),
              ],
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      "$category (${items.length})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              collapsedIconColor: Colors.white,
              iconColor: Colors.white,
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() => _expandedCategories[category] = expanded);
              },
              children: items
                  .map(
                    (obj) => _buildDismissibleObjectiveRow(
                      context: context,
                      provider: provider,
                      obj: obj,
                      selectedDate: selectedDate,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  // ===== Organize: Reorderable categories =====
  Widget _buildReorderableCategoryList(
    List<String> orderedCats,
    Map<String, List<Objective>> groupedByCategory,
    ObjectiveProvider provider,
    DateTime selectedDate,
  ) {
    return ReorderableListView(
      padding: const EdgeInsets.only(bottom: _listBottomInsetForXpBar),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final moved = _categoryOrder.removeAt(oldIndex);
          _categoryOrder.insert(newIndex, moved);
        });
      },
      buildDefaultDragHandles: false,
      children: [
        for (int i = 0; i < orderedCats.length; i++)
          ReorderableDragStartListener(
            key: ValueKey('cat_reorder_${orderedCats[i]}'),
            index: i,
            child: DragTarget<_ObjectiveDrag>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) async {
                final data = details.data;
                if (data.fromCategoryId == orderedCats[i]) return;
                await provider.moveObjectiveToCategory(
                  objectiveId: data.objectiveId,
                  newCategoryId: orderedCats[i],
                  date: selectedDate,
                );
                if (mounted) setState(() {});
              },
              builder: (context, _, __) {
                final category = orderedCats[i];
                final items = groupedByCategory[category]!;
                final isExpanded = _expandedCategories[category] ?? true;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      title: Row(
                        children: [
                          const Icon(Icons.drag_handle, color: Colors.white54),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "$category (${items.length})",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (expanded) {
                        setState(
                          () => _expandedCategories[category] = expanded,
                        );
                      },
                      children: [
                        ReorderableListView.builder(
                          key: ValueKey('obj_list_$category'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final obj = items[index];
                            return ReorderableDragStartListener(
                              index: index,
                              key: ValueKey('obj_${obj.id}_organize'),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: .06,
                                      ),
                                    ),
                                  ),
                                ),
                                child: _OrganizeObjectiveTile(
                                  objective: obj,
                                  onStartDrag: (_) {},
                                ),
                              ),
                            );
                          },
                          onReorder: (oldIndex, newIndex) async {
                            final ids = items.map((o) => o.id).toList();
                            if (newIndex > oldIndex) newIndex -= 1;
                            final moved = ids.removeAt(oldIndex);
                            ids.insert(newIndex, moved);
                            await provider.reorderObjectivesInCategoryForDate(
                              provider.selectedDateNotifier.value,
                              category,
                              ids,
                            );
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        Container(
          key: const ValueKey('_footer_buttons'),
          margin: const EdgeInsets.only(top: 8),
          child: _footerButtons(),
        ),
      ],
    );
  }

  void _showXpDebugDialog(BuildContext context, ObjectiveProvider provider) {
    const coreCategories = [
      'RAPPING',
      'PRODUCTION',
      'HEALTH',
      'KNOWLEDGE',
      'NETWORKING',
    ];

    for (final id in coreCategories) {
      provider.ensureCategoryExists(id);
    }

    int selectedXp = 100;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "🧪 XP Debugger",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [10, 100, 1000].map((xp) {
                      final isSelected = xp == selectedXp;
                      return ChoiceChip(
                        label: Text("+$xp XP"),
                        selected: isSelected,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                        selectedColor: Colors.orangeAccent,
                        backgroundColor: Colors.grey[800],
                        onSelected: (_) => setState(() => selectedXp = xp),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: coreCategories.map((id) {
                      return ElevatedButton(
                        onPressed: () =>
                            provider.addXpToCategory(id, selectedXp),
                        child: Text("+$selectedXp XP to $id"),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      provider.resetAllXp();
                      provider.resetObjectiveCompletion();
                    },
                    child: const Text("Reset"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===== FAB Drawer overlay =====
  Widget _buildFabDrawer(BuildContext context, ObjectiveProvider provider) {
    // Keep the main FAB out of the XP bar's way.
    const double bottomClearance = _listBottomInsetForXpBar - 24; // ~96
    final media = MediaQuery.of(context);
    final double bottom = bottomClearance + media.padding.bottom;

    return Stack(
      children: [
        // Tap-out scrim
        if (_fabOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _toggleFab(open: false),
              child: Container(color: Colors.black.withValues(alpha: .35)),
            ),
          ),

        // Drawer items (animate upward)
        Positioned(
          right: 16,
          bottom: bottom + 56, // place items above the main FAB
          child: IgnorePointer(
            ignoring: !_fabOpen && _fabCtrl.status == AnimationStatus.dismissed,
            child: SizedBox(
              width: 56,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _AnimatedFabItem(
                    controller: _fabCtrl,
                    index: 1,
                    color: const Color(0xFF26A69A), // teal
                    icon: Icons.attach_money,
                    tooltip: 'Budget Manager',
                    hero: 'fab_budget',
                    onPressed: () {
                      _toggleFab(open: false);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BudgetScreen()),
                      );
                    },
                  ),
                  _AnimatedFabItem(
                    controller: _fabCtrl,
                    index: 2,
                    color: const Color(0xFF42A5F5), // blue
                    icon: Icons.dashboard_customize_outlined,
                    tooltip: 'Project Manager',
                    hero: 'fab_projects',
                    onPressed: () {
                      _toggleFab(open: false);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProjectScreen(), // ⬅️ fixed
                        ),
                      );
                    },
                  ),
                  _AnimatedFabItem(
                    controller: _fabCtrl,
                    index: 3,
                    color: const Color(0xFF7E57C2), // purple
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Writing Editor',
                    hero: 'fab_writing',
                    onPressed: () {
                      _toggleFab(open: false);
                      // Update the destination if your editor widget differs.
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BlockTextEditor(),
                        ),
                      );
                    },
                  ),
                  _AnimatedFabItem(
                    controller: _fabCtrl,
                    index: 4,
                    color: const Color(0xFFFF7043), // orange
                    icon: Icons.bug_report_outlined,
                    tooltip: 'XP Debugger',
                    hero: 'fab_xp_debug',
                    onPressed: () {
                      _toggleFab(open: false);
                      _showXpDebugDialog(context, provider);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Main FAB
        Positioned(
          right: 16,
          bottom: bottom,
          child: FloatingActionButton(
            heroTag: 'fab_main_more',
            onPressed: () => _toggleFab(),
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _fabOpen ? 0.125 : 0.0, // 45°
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small “pill” button used for Organize toggle in the footer
class _OrganizeToggleButton extends StatelessWidget {
  const _OrganizeToggleButton({required this.isOn, required this.onToggle});

  final bool isOn;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'fab_organize',
      onPressed: onToggle,
      backgroundColor: const Color(0xFF6C63FF),
      foregroundColor: Colors.white,
      icon: Icon(isOn ? Icons.check : Icons.tune),
      label: Text(isOn ? 'Done' : 'Organize'),
    );
  }
}

class _OrganizeObjectiveTile extends StatelessWidget {
  const _OrganizeObjectiveTile({required this.objective, this.onStartDrag});

  final Objective objective;
  final void Function(_ObjectiveDrag)? onStartDrag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          LongPressDraggable<_ObjectiveDrag>(
            data: _ObjectiveDrag(
              objectiveId: objective.id,
              fromCategoryId: objective.categoryIds.isNotEmpty
                  ? objective.categoryIds.first
                  : 'Uncategorized',
            ),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .18),
                  ),
                ),
                child: Text(
                  objective.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            childWhenDragging: const Opacity(
              opacity: 0.4,
              child: Icon(Icons.drag_indicator, color: Colors.white54),
            ),
            child: const Icon(Icons.drag_indicator, color: Colors.white54),
            onDragStarted: () {
              onStartDrag?.call(
                _ObjectiveDrag(
                  objectiveId: objective.id,
                  fromCategoryId: objective.categoryIds.isNotEmpty
                      ? objective.categoryIds.first
                      : 'Uncategorized',
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              objective.title,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveDrag {
  final String objectiveId;
  final String fromCategoryId;
  _ObjectiveDrag({required this.objectiveId, required this.fromCategoryId});
}

class _AnimatedFabItem extends StatelessWidget {
  const _AnimatedFabItem({
    required this.controller,
    required this.index,
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.hero,
    required this.onPressed,
  });

  final AnimationController controller;
  final int index;
  final Color color;
  final IconData icon;
  final String tooltip;
  final String hero;
  final VoidCallback onPressed;

  static const double _btnSize = 56;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final double start = 0.05 + (4 - index) * 0.08;
    final double end = (start + 0.55).clamp(0.0, 1.0);

    final curvedMove = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeInCubic),
    );

    final curvedFade = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeInCubic),
    );

    final dy = Tween<double>(
      begin: 0,
      end: -(_btnSize + _gap) * index,
    ).animate(curvedMove);

    final scale = Tween<double>(begin: 0.85, end: 1.0).animate(curvedMove);
    final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curvedFade);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, dy.value),
          child: Opacity(
            opacity: opacity.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale.value,
              alignment: Alignment.center,
              child: IgnorePointer(
                ignoring: controller.status == AnimationStatus.dismissed,
                child: FloatingActionButton(
                  heroTag: hero,
                  tooltip: tooltip,
                  onPressed: onPressed,
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dismiss only if drag starts on the RIGHT edge then swipes LEFT
class _RightEdgeDismissible extends StatefulWidget {
  const _RightEdgeDismissible({
    required this.dismissibleKey,
    required this.enabled,
    required this.confirmDelete,
    required this.onDismissed,
    required this.child,
    required this.buildSecondaryBackground,
  });

  final Key dismissibleKey;
  final bool enabled;
  final Future<bool> Function() confirmDelete;
  final Future<void> Function() onDismissed;
  final Widget child;
  final Widget Function() buildSecondaryBackground;

  @override
  State<_RightEdgeDismissible> createState() => _RightEdgeDismissibleState();
}

class _RightEdgeDismissibleState extends State<_RightEdgeDismissible> {
  static const double _edgeGrip = 56;
  bool _startedOnRightEdge = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(event.position);
        final width = box.size.width;
        _startedOnRightEdge = local.dx >= (width - _edgeGrip);
      },
      child: Dismissible(
        key: widget.dismissibleKey,
        direction: widget.enabled
            ? DismissDirection.endToStart
            : DismissDirection.none,
        confirmDismiss: (dir) async {
          if (!widget.enabled) return false;
          if (dir != DismissDirection.endToStart) return false;
          if (!_startedOnRightEdge) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Swipe from the right edge to delete'),
                duration: Duration(milliseconds: 900),
              ),
            );
            return false;
          }
          return widget.confirmDelete();
        },
        onDismissed: (_) async => widget.onDismissed(),
        background: const SizedBox.shrink(),
        secondaryBackground: widget.buildSecondaryBackground(),
        child: widget.child,
      ),
    );
  }
}
