// lib/ui/screens/progress_screen.dart
import 'dart:async';
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
import 'package:kontinuum/ui/widgets/add_item_fab.dart';
import 'package:kontinuum/ui/widgets/calendar/calendar_fullscreen_page.dart';
import 'package:kontinuum/providers/mission_provider.dart';

// NEW: Budget + Health + Level utils
import 'package:kontinuum/ui/screens/budget/budget_screen_v2.dart';
import 'package:kontinuum/ui/screens/health/health_screen.dart';
import 'package:kontinuum/data/level_utils.dart';

/// ===== Color palette: BLACK + BLUE-BLACK =====
class AppPalette {
  static const bg = Color(0xFF0A0A0B); // near-black (page background)
  static const surface = Color(0xFF0E1320); // blue-black (pills/surfaces)
  static const outline = Color(0xFF273043); // cool gray-blue stroke
  static const onSurface = Color(0xFFF5F7FA); // crisp light text
  static const subtext = Color(0xFF9AA4B2); // subdued cool text

  // Requested purple for the Add button (#2B124C)
  static const addPurple = Color(0xFF481a53);
}

// App backdrop
const Color kProgressBg = AppPalette.bg;
// Category header pill
const Color kCategoryPillColor = AppPalette.surface;

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with TickerProviderStateMixin {
  final Map<String, bool> _expandedCategories = {};

  // ---- Horizontal "scroll over" between Progress ↔ Mission Board ----
  late final PageController _pageCtrl;
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

  // ---- GPU prepaint warm-up ----
  bool _prepaintProgress = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);

    _statsSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
      value: 0.0,
    );

    // Warm up MissionProvider so the board is ready before sliding in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final missionProvider = context.read<MissionProvider>();
      final objectiveProvider = context.read<ObjectiveProvider>();
      missionProvider.attachObjectiveProvider(objectiveProvider);
      () async {
        try {
          await missionProvider.seedIfEmpty();
          await missionProvider.syncWithSeeder();
          missionProvider.ensureMissionSlotsFilled();
        } catch (_) {
          // ignore warm-up failures
        }
      }();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _statsSlideCtrl.dispose();
    super.dispose();
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
      PageRouteBuilder<void>(
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
            backgroundColor: kProgressBg,
            title: const Text(
              'Delete objective?',
              style: TextStyle(color: AppPalette.onSurface),
            ),
            content: Text(
              '“$title” will be permanently removed.',
              style: const TextStyle(color: AppPalette.subtext),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppPalette.subtext),
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
            backgroundColor: kProgressBg,
            title: const Text(
              'Delete category?',
              style: TextStyle(color: AppPalette.onSurface),
            ),
            content: Text(
              'All objectives in “$categoryId” will be uncategorized.\n\nThis cannot be undone.',
              style: const TextStyle(color: AppPalette.subtext),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppPalette.subtext),
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

  // ====== Dismissible objective row ======
  Widget _buildDismissibleObjectiveRow({
    required BuildContext context,
    required ObjectiveProvider provider,
    required Objective obj,
    required DateTime selectedDate,
  }) {
    final handler = getHandlerForType(obj.type);

    return _RightEdgeDismissible(
      dismissibleKey: ValueKey('obj_${obj.id}'),
      enabled: true,
      confirmDelete: () => _confirmDeleteObjective(context, obj.title),
      onDismissed: () async {
        await provider.deleteObjective(obj.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Objective deleted')),
        );
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
        onTap: () {
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

          showModalBottomSheet<void>(
            context: context,
            backgroundColor: kProgressBg,
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
        child: ObjectiveListItem(objective: obj, selectedDate: selectedDate),
      ),
    );
  }

  // Footer with Add only (organize removed)
  Widget _footerButtons() {
    final base = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Theme(
        data: base.copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.addPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              shadowColor: Colors.black.withValues(alpha: .35),
              elevation: 2,
            ),
          ),
        ),
        child: const Center(child: AddItemFab()),
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
    final dy = _statsDragStartGlobalY! - d.globalPosition.dy; // up = +
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

  // ===== XP Debugger Bottom Sheet =====
  Future<void> _openXpDebuggerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      useSafeArea: false,
      barrierColor: Colors.black.withValues(alpha: .35),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return const _CategoryXpDebugSheet();
      },
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
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_statsSlideCtrl.value > 0.01) {
          _closeStats();
          return;
        }
        if (_pageIndex == 1) {
          await _goToProgress();
          return;
        }
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: kProgressBg,
        body: SafeArea(
          child: Stack(
            children: [
              _buildProgressLayer(
                provider: provider,
                topEdgeHeight: topEdgeHeight,
              ),
              if (_prepaintProgress)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TickerMode(
                      enabled: false,
                      child: Opacity(
                        opacity: 0.001,
                        child: const RepaintBoundary(
                          child: _KeepAlive(
                            child: _ProgressPageContent(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _statsSlideCtrl,
                  builder: (context, _) {
                    final offset = Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).transform(_statsSlideCtrl.value);
                    return Transform.translate(
                      offset: Offset(0, offset.dy * screenH),
                      child: IgnorePointer(
                        ignoring: _statsSlideCtrl.value == 0.0,
                        child: const StatsDashboard(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: _listBottomInsetForXpBar - 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // NEW: XP Debugger FAB → opens bottom sheet
              FloatingActionButton(
                heroTag: 'fab_to_xp_debug',
                backgroundColor: const Color(0xFF7E57C2), // purple
                foregroundColor: Colors.white,
                tooltip: 'Open XP Debugger',
                child: const Icon(Icons.science_outlined),
                onPressed: _openXpDebuggerSheet,
              ),
              const SizedBox(height: 12),
              // NEW: Health FAB
              FloatingActionButton(
                heroTag: 'fab_to_health',
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                tooltip: 'Open Health',
                child: const Icon(Icons.favorite),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HealthScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Existing: Budget FAB
              FloatingActionButton(
                heroTag: 'fab_to_budget',
                backgroundColor: const Color(0xFF26A69A), // teal accent is fine
                foregroundColor: Colors.white,
                tooltip: 'Open Budget',
                child: const Icon(Icons.attach_money),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BudgetScreenV2(),
                    ),
                  );
                },
              ),
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
            onPageChanged: (i) {
              setState(() => _pageIndex = i);
              if (i == 1) {
                _prepaintProgress = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 16), () {
                    if (mounted) setState(() => _prepaintProgress = false);
                  });
                });
              }
            },
            children: [
              TickerMode(
                enabled: _pageIndex == 0,
                child: const RepaintBoundary(
                  child: _KeepAlive(child: _ProgressPageContent()),
                ),
              ),
              TickerMode(
                enabled: _pageIndex == 1,
                child: RepaintBoundary(
                  child: MissionBoardScreen(isActive: _pageIndex == 1),
                ),
              ),
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
                behavior: HitTestBehavior.translucent,
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
                icon: const Icon(Icons.flag_outlined,
                    color: AppPalette.onSurface),
                tooltip: 'Mission Board',
                onPressed: _goToBoard,
              ),
            ),
        ],
      ),
    );
  }

  // ----- Progress content (original body moved into an impl method) -----
  Widget _buildProgressContentImpl(ObjectiveProvider provider) {
    return Stack(
      children: [
        ValueListenableBuilder<DateTime>(
          valueListenable: provider.selectedDateNotifier,
          builder: (context, selectedDate, _) {
            final objectives = provider.getObjectivesForDay(selectedDate);

            // Group by first category (or "Uncategorized")
            final Map<String, List<Objective>> groupedByCategory = {};
            for (final obj in objectives) {
              final category = obj.categoryIds.isNotEmpty
                  ? obj.categoryIds.first
                  : 'Uncategorized';
              groupedByCategory.putIfAbsent(category, () => []).add(obj);
            }

            // Order categories alphabetically, with "Uncategorized" at the end.
            final orderedCats = groupedByCategory.keys.toList()
              ..sort((a, b) {
                if (a == 'Uncategorized' && b == 'Uncategorized') return 0;
                if (a == 'Uncategorized') return 1;
                if (b == 'Uncategorized') return -1;
                return a.toLowerCase().compareTo(b.toLowerCase());
              });

            final header = Column(
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
                      color: AppPalette.onSurface,
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
                        style: TextStyle(color: AppPalette.subtext),
                      ),
                    ),
                  ),
                  _footerButtons(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _statsDragStart,
                    onVerticalDragUpdate: _statsDragUpdate,
                    onVerticalDragEnd: _statsDragEnd,
                    onTap: _openStatsFully,
                    child: XpLevelBar(
                      controller: _xpBarCtrl,
                      onStatsPressed: _openStatsFully,
                    ),
                  ),
                ],
              );
            }

            final list = _buildNormalCategoryList(
              orderedCats,
              groupedByCategory,
              provider,
              selectedDate,
            );

            return Column(
              children: [
                header,
                Expanded(child: list),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _statsDragStart,
                  onVerticalDragUpdate: _statsDragUpdate,
                  onVerticalDragEnd: _statsDragEnd,
                  onTap: _openStatsFully,
                  child: XpLevelBar(
                    controller: _xpBarCtrl,
                    onStatsPressed: _openStatsFully,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ===== Normal category list (lazy builder) =====
  Widget _buildNormalCategoryList(
    List<String> orderedCats,
    Map<String, List<Objective>> groupedByCategory,
    ObjectiveProvider provider,
    DateTime selectedDate,
  ) {
    final itemCount = orderedCats.length + 3; // spacer + footer + spacer

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: _listBottomInsetForXpBar),
      cacheExtent: 800,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < orderedCats.length) {
          final category = orderedCats[index];
          final items = groupedByCategory[category]!;
          final initiallyExpanded = _expandedCategories[category] ?? true;

          return _CategorySection(
            key: ValueKey('cat_$category'),
            category: category,
            items: items,
            initiallyExpanded: initiallyExpanded,
            onExpandedChanged: (expanded) {
              setState(() => _expandedCategories[category] = expanded);
            },
            canDismiss: category != 'Uncategorized',
            confirmDelete: () => _confirmDeleteCategory(context, category),
            onDeleted: () async {
              await provider.deleteCategory(category);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Category “$category” deleted')),
              );
            },
            rowBuilder: (obj) => _buildDismissibleObjectiveRow(
              context: context,
              provider: provider,
              obj: obj,
              selectedDate: selectedDate,
            ),
          );
        }
        if (index == orderedCats.length) return const SizedBox(height: 8);
        if (index == orderedCats.length + 1) return _footerButtons();
        return const SizedBox(height: 4);
      },
    );
  }
}

// ===================== KeepAlive wrapper =====================
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// A lightweight wrapper to keep the content page as a separate subtree.
class _ProgressPageContent extends StatelessWidget {
  const _ProgressPageContent();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ObjectiveProvider>(context, listen: false);
    final state = context.findAncestorStateOfType<_ProgressScreenState>();
    if (state == null) return const SizedBox.shrink();
    return state._buildProgressContentImpl(provider);
  }
}

// ===== Helpers / dismissible =====

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

// ============ Category section with instant, reliable expand/collapse ============
class _CategorySection extends StatefulWidget {
  const _CategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.initiallyExpanded,
    required this.onExpandedChanged,
    required this.canDismiss,
    required this.confirmDelete,
    required this.onDeleted,
    required this.rowBuilder,
  });

  final String category;
  final List<Objective> items;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpandedChanged;

  final bool canDismiss;
  final Future<bool> Function() confirmDelete;
  final Future<void> Function() onDeleted;

  // Build a single objective row (uses parent’s helper)
  final Widget Function(Objective obj) rowBuilder;

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _ctrl;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _expanded ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _CategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If external state changed (e.g., persisted expansion), sync animation.
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        widget.initiallyExpanded != _expanded) {
      _expanded = widget.initiallyExpanded;
      _ctrl.animateTo(
        _expanded ? 1.0 : 0.0,
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 220),
      );
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged(_expanded);
    _ctrl.animateTo(
      _expanded ? 1.0 : 0.0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: kCategoryPillColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppPalette.outline.withValues(alpha: .28),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "${widget.category} (${widget.items.length})",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppPalette.onSurface,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      splashRadius: 22,
                      tooltip: _expanded ? 'Collapse' : 'Expand',
                      onPressed: _toggle,
                      icon: RotationTransition(
                        turns: Tween<double>(begin: 0.0, end: 0.5)
                            .animate(CurvedAnimation(
                          parent: _ctrl,
                          curve: Curves.easeOutCubic,
                        )),
                        child: const Icon(Icons.expand_more,
                            color: AppPalette.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Body stays in the tree ALWAYS. We animate height via heightFactor
    // and disable pointers when collapsed. Background changed to BLACK/transparent.
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: AnimatedBuilder(
        animation: _ctrl,
        child: Column(
          children: [
            const SizedBox(height: 6),
            for (final obj in widget.items) widget.rowBuilder(obj),
            const SizedBox(height: 6),
          ],
        ),
        builder: (context, child) {
          final t = CurvedAnimation(
            parent: _ctrl,
            curve: Curves.easeOutCubic,
          ).value;
          return Container(
            decoration: BoxDecoration(
              // 👇 was kCategoryPillColor; now invisible on page background
              color: Colors.transparent, // or kProgressBg for solid black
              borderRadius: BorderRadius.circular(14),
              // remove outline while expanded/collapsed to keep it invisible
              border: Border.all(color: Colors.transparent, width: 0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: t, // drives the actual height
                  child: IgnorePointer(
                    ignoring: t < 0.01,
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    return _RightEdgeDismissible(
      dismissibleKey: ValueKey('cat_${widget.category}'),
      enabled: widget.canDismiss,
      confirmDelete: widget.confirmDelete,
      onDismissed: widget.onDeleted,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          body, // always present; height animates between 0↔1
          if (widget.category == 'Uncategorized') const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ===================== XP Debugger Bottom Sheet (compact) =====================

class _CategoryXpDebugSheet extends StatelessWidget {
  const _CategoryXpDebugSheet();

  static const coreCategories = [
    'RAPPING',
    'PRODUCTION',
    'HEALTH',
    'KNOWLEDGE',
    'NETWORKING',
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final provider = Provider.of<ObjectiveProvider>(context);
    final missionProvider =
        Provider.of<MissionProvider>(context, listen: false);

    // Ensure base cats exist
    for (final id in coreCategories) {
      provider.ensureCategoryExists(id);
    }

    final categories = provider.categories;
    final totalXp = provider.totalXp;
    final totalLevel = provider.totalLevel;
    final totalProgress = provider.totalLevelProgress;
    final totalXpForNext = provider.totalXpForNextLevel;

    // ~3/4 of the bottom half ≈ 0.375 of screen height
    final sheetHeight = (media.size.height * 0.38).clamp(260.0, 480.0);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Container(
              height: sheetHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF121826), // deep blue-black
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(
                    color: AppPalette.outline.withValues(alpha: .22)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    offset: Offset(0, -6),
                    color: Color(0x66000000),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // drag handle
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // header row (compact)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.science_outlined,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'XP Debugger',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // content (scrollable, compact)
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      children: [
                        // Total card (compact)
                        Card(
                          color: Colors.blueGrey[900],
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "🧠 Total Progress",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text("Total XP: $totalXp",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                                Text("Total Level: $totalLevel",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 4,
                                  child: LinearProgressIndicator(
                                    value: totalProgress.clamp(0.0, 1.0),
                                    backgroundColor: Colors.grey[700],
                                    color: Colors.cyan,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$totalXp / $totalXpForNext XP for next level",
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Category cards (compact)
                        ...categories.values.map((cat) {
                          const maxXp = 600000;
                          final currentLevel =
                              LevelUtils.getLevelFromXp(cat.xp, maxXp);
                          final nextLevel =
                              (currentLevel + 1).clamp(1, LevelUtils.maxLevel);
                          final xpForCurrent =
                              LevelUtils.getXpForLevel(currentLevel, maxXp);
                          final xpForNext =
                              LevelUtils.getXpForLevel(nextLevel, maxXp);
                          final progress = ((cat.xp - xpForCurrent) /
                                  (xpForNext - xpForCurrent))
                              .clamp(0.0, 1.0);
                          final prestige = cat.prestigeTitle;
                          final colorHex = cat.prestigeColor;
                          final color = _parseColor(colorHex);

                          return Card(
                            color: Colors.grey[850],
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${cat.name} — Lv.$currentLevel ($prestige)",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 4,
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      color: color ?? Colors.amber,
                                      backgroundColor: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${cat.xp} / $xpForNext XP",
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              provider.resetEverything(
                                  missionProvider: missionProvider);
                            },
                            child: const Text(
                              "🧹 Full Reset (XP, Objectives, Stats, Milestones)",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String hex) {
    try {
      final hexCode = hex.replaceAll("#", "");
      if (hexCode.length == 6) {
        return Color(int.parse("FF$hexCode", radix: 16));
      } else if (hexCode.length == 8) {
        return Color(int.parse(hexCode, radix: 16));
      }
    } catch (_) {}
    return null;
  }
}
