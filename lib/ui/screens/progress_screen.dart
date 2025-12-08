import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/providers/alignment_schedule_provider.dart';
import 'package:kontinuum/providers/notification_center_provider.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/workout_progress_service.dart';
import 'package:kontinuum/utils/date_keys.dart';
import 'package:kontinuum/ui/widgets/year_progress_date.dart';
import 'package:kontinuum/ui/widgets/objective_list_item.dart';
import 'package:kontinuum/ui/widgets/xp_level_bar.dart';
import 'package:kontinuum/ui/screens/stats_dashboard.dart';
import 'package:kontinuum/ui/objective_type_handlers/objective_type_factory.dart';
import 'package:kontinuum/ui/widgets/add_item_fab.dart';
import 'package:kontinuum/ui/widgets/calendar/calendar_fullscreen_page.dart';
// Budget + Level utils
import 'package:kontinuum/ui/screens/budget/budget_focus.dart';
import 'package:kontinuum/ui/screens/budget/budget_screen_v2.dart';
import 'package:kontinuum/ui/screens/budget/budget_screen_theme.dart';
import 'package:kontinuum/data/level_utils.dart';

// STREAK (only the chip in category sections)
import 'package:kontinuum/ui/widgets/streak/category_claim_chip.dart';

// Workout (FAB + right-edge gesture)
import 'package:kontinuum/ui/workout/workout_dashboard_screen.dart';

// 🔥 NEW: organization screen moved out
import 'package:kontinuum/ui/screens/objective_organization_screen.dart';
import 'package:kontinuum/ui/screens/alignment_flow_page.dart';
import 'package:kontinuum/ui/screens/mission_board_screen.dart';
import 'package:kontinuum/ui/workout/session_screen.dart';
import 'package:kontinuum/ui/workout/session_screen_args.dart';
import 'package:kontinuum/ui/screens/day_detail_page.dart';
import 'package:kontinuum/ui/screens/create_objective_screen2.dart';

import 'package:kontinuum/ui/screens/data_management_sheet.dart';
import 'package:kontinuum/services/backup/data_backup_service.dart';
import 'package:kontinuum/services/backup/local_file_backup_transport.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kontinuum/core/time/app_clock.dart';
import 'package:kontinuum/core/streaks/streak_engine.dart';
import 'package:kontinuum/models/app_notification.dart';

/// ===== Color palette: BLACK + BLUE-BLACK =====
class AppPalette {
  static const bg = Color(0xFF0A0A0B);
  static const surface = Color(0xFF0E1320);
  static const outline = Color(0xFF273043);
  static const onSurface = Color(0xFFF5F7FA);
  static const subtext = Color(0xFF9AA4B2);
  static const addPurple = Color(0xFF481a53);
}

const Color kProgressBg = AppPalette.bg;
const Color kCategoryPillColor = AppPalette.surface;
const String kUncategorizedCategoryName = 'Uncategorized';
const String kAbstinenceCategoryName = 'ABSTINENCE';
const Color kWorkoutPageBg = Color(0xFF090A0E);

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with TickerProviderStateMixin {
  final Map<String, bool> _expandedCategories = {};

  static const int _budgetPageIndex = 0;
  static const int _progressPageIndex = 1;
  static const int _workoutPageIndex = 2;
  static const Duration _pageTransitionDuration = Duration(milliseconds: 120);
  static const String _notificationPopupHeroTag = 'notification_popup_hero';

  int _pageIndex = _progressPageIndex;
  bool _pageTransitioning = false;
  bool _progressHorizontalDragActive = false;
  double _progressHorizontalDragDelta = 0.0;

  static const double _listBottomInsetForXpBar = 120;

  bool _calendarPushed = false;
  double? _dragStartY;

  final XpLevelBarController _xpBarCtrl = XpLevelBarController();
  final ValueNotifier<int?> _budgetRingPageJump = ValueNotifier<int?>(null);
  final ValueNotifier<BudgetFocusTarget?> _budgetFocusSignal =
      ValueNotifier<BudgetFocusTarget?>(null);
  final ValueNotifier<BudgetBillFocus?> _budgetBillFocusSignal =
      ValueNotifier<BudgetBillFocus?>(null);
  final ValueNotifier<DateTime?> _workoutDateSignal =
      ValueNotifier<DateTime?>(null);

  late final AnimationController _statsSlideCtrl;
  double? _statsDragStartGlobalY;
  bool _fabMenuExpanded = false;
  bool _backupBusy = false;
  AlignmentScheduleProvider? _alignmentProvider;
  bool _notificationCenterOpen = false;
  bool _xpBarTapStartedOnPlus = false;

  @override
  void initState() {
    super.initState();
    _statsSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
      value: 0.0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final missionProvider = context.read<MissionProvider>();
      final objectiveProvider = context.read<ObjectiveProvider>();
      missionProvider.attachObjectiveProvider(objectiveProvider);
      () async {
        try {
          await missionProvider.seedIfEmpty();
          await missionProvider.syncWithSeeder();
          missionProvider.ensureMissionSlotsFilled();
        } catch (_) {}
      }();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<AlignmentScheduleProvider>(context);
    if (_alignmentProvider == provider) return;
    _alignmentProvider?.removeListener(_handleAlignmentScheduleUpdate);
    _alignmentProvider = provider;
    _alignmentProvider?.addListener(_handleAlignmentScheduleUpdate);
    _handleAlignmentScheduleUpdate();
  }

  @override
  void dispose() {
    _alignmentProvider?.removeListener(_handleAlignmentScheduleUpdate);
    _statsSlideCtrl.dispose();
    _budgetRingPageJump.dispose();
    _budgetFocusSignal.dispose();
    _budgetBillFocusSignal.dispose();
    _workoutDateSignal.dispose();
    super.dispose();
  }

  Future<void> _goToBudgetPage() async {
    _setFabMenuExpanded(false);
    await _switchToPage(_budgetPageIndex);
  }

  Future<void> _goToProgress() async {
    await _switchToPage(_progressPageIndex);
  }

  Future<void> _goToWorkoutPage() async {
    _setFabMenuExpanded(false);
    await _switchToPage(_workoutPageIndex);
  }

  Future<void> _openMissionBoard() async {
    await _openMissionBoardWithFocus();
  }

  Future<void> _openMissionBoardWithFocus({
    String? missionId,
    bool autoOpenDetail = false,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: _pageTransitionDuration,
        reverseTransitionDuration: _pageTransitionDuration,
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => MissionBoardScreen(
          skipIntroAnimation: true,
          focusMissionId: missionId,
          autoOpenMissionDetail: autoOpenDetail,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  Future<void> _openWorkoutDay(DateTime day) async {
    final normalized = DateKeys.dateOnly(day);
    final objectiveProvider = context.read<ObjectiveProvider>();
    objectiveProvider.selectedDateNotifier.value = normalized;
    if (_notificationCenterOpen) {
      await Navigator.of(context).maybePop();
    }
    await _goToWorkoutPage();
    // Nudge the dashboard after the page transition kicks in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _workoutDateSignal.value = normalized;
    });
  }

  void _setFabMenuExpanded(bool expanded) {
    if (_fabMenuExpanded == expanded) return;
    setState(() => _fabMenuExpanded = expanded);
  }

  void _toggleFabMenu() => _setFabMenuExpanded(!_fabMenuExpanded);

  Future<void> _switchToPage(int target) async {
    if (!mounted) return;
    if (_pageIndex == target || _pageTransitioning) return;
    setState(() {
      _pageIndex = target;
      _pageTransitioning = true;
      if (target != _progressPageIndex) {
        _fabMenuExpanded = false;
      }
    });
    await Future<void>.delayed(_pageTransitionDuration);
    if (mounted) {
      setState(() {
        _pageTransitioning = false;
      });
    }
  }

  int _compareCategoryNames(String a, String b) {
    if (a == kAbstinenceCategoryName && b == kAbstinenceCategoryName) {
      return 0;
    }
    if (a == kAbstinenceCategoryName) return -1;
    if (b == kAbstinenceCategoryName) return 1;

    if (a == kUncategorizedCategoryName &&
        b == kUncategorizedCategoryName) {
      return 0;
    }
    if (a == kUncategorizedCategoryName) return 1;
    if (b == kUncategorizedCategoryName) return -1;

    return a.toLowerCase().compareTo(b.toLowerCase());
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
        opaque: false,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, anim, __) {
          // Use a stateful wrapper for one-time delayed build
          return _DeferredCalendarBuilder(
            initialDate: selected,
            firstDate: first,
            lastDate: last,
          );
        },
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, -0.04),
            end: Offset.zero,
          ).animate(curved);
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );

    _calendarPushed = false;
  }

  Future<void> _openDataManagementSheet() async {
    _setFabMenuExpanded(false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DataManagementSheet(
            backupService: DataBackupService(),
          ),
        );
      },
    );
  }

  Future<void> _saveBackupInline() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    final transport = LocalFileBackupTransport();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DataBackupService().exportAndSave(
        transport: transport,
        suggestedFileName: LocalFileBackupTransport.defaultFileName,
      );
      String location = transport.lastSavedPath ?? '';
      if (location.isEmpty && (Platform.isAndroid || Platform.isIOS)) {
        final dir = await getApplicationDocumentsDirectory();
        location = '${dir.path}/${LocalFileBackupTransport.defaultFileName}';
      }
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(location.isEmpty ? 'Backup saved' : 'Backup saved to $location'),
        ),
      );
    } on BackupUserCancelled {
      // silent cancel
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _loadBackupInline() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final objectiveProvider = context.read<ObjectiveProvider>();
      final missionProvider = context.read<MissionProvider>();
      final workoutProvider = context.read<WorkoutProvider>();
      final dietProvider = context.read<DietProvider>();
      final fitnessProvider = context.read<FitnessProfileProvider>();
      final budgetProvider = context.read<BudgetProvider>();

      await DataBackupService().importFromTransport(
        LocalFileBackupTransport(),
        objectiveProvider: objectiveProvider,
        missionProvider: missionProvider,
        workoutProvider: workoutProvider,
        dietProvider: dietProvider,
        fitnessProfileProvider: fitnessProvider,
        budgetProvider: budgetProvider,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup loaded')),
      );
    } on BackupUserCancelled {
      // silent cancel
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Load failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<bool> _confirmDeleteObjective(
    BuildContext context,
    String title,
  ) async {
    final res = await showDialog<bool>(
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
    );
    return res ?? false;
  }

  Future<bool> _confirmDeleteCategory(
    BuildContext context,
    String categoryId,
  ) async {
    final res = await showDialog<bool>(
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
    );
    return res ?? false;
  }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Center(child: AddItemFab()),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: _backupBusy ? null : _saveBackupInline,
                  child: const Text('Save'),
                ),
                FilledButton(
                  onPressed: _backupBusy ? null : _loadBackupInline,
                  child: const Text('Load'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onProgressHorizontalDragStart(DragStartDetails _) {
    if (_pageIndex != _progressPageIndex || _pageTransitioning) return;
    _progressHorizontalDragActive = true;
    _progressHorizontalDragDelta = 0.0;
  }

  void _onProgressHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_progressHorizontalDragActive) return;
    _progressHorizontalDragDelta += details.primaryDelta ?? 0.0;
  }

  void _onProgressHorizontalDragEnd(DragEndDetails details) {
    if (!_progressHorizontalDragActive) return;
    final double delta = _progressHorizontalDragDelta;
    _progressHorizontalDragActive = false;
    _progressHorizontalDragDelta = 0.0;

    final double velocityX = details.velocity.pixelsPerSecond.dx;
    const double velocityThreshold = 600;
    const double distanceThreshold = 60;

    bool swipeLeft = velocityX < -velocityThreshold || delta < -distanceThreshold;
    bool swipeRight = velocityX > velocityThreshold || delta > distanceThreshold;

    if (swipeLeft) {
      _goToWorkoutPage();
    } else if (swipeRight) {
      _goToBudgetPage();
    }
  }

  void _onProgressHorizontalDragCancel() {
    _progressHorizontalDragActive = false;
    _progressHorizontalDragDelta = 0.0;
  }

  void _statsDragStart(DragStartDetails d) {
    _statsDragStartGlobalY = d.globalPosition.dy;
  }

  void _statsDragUpdate(DragUpdateDetails d) {
    if (_statsDragStartGlobalY == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final height = box.size.height;
    final dy = _statsDragStartGlobalY! - d.globalPosition.dy;
    final delta = (dy / height).clamp(0.0, 1.0);
    _statsSlideCtrl.value = delta;
  }

  void _statsDragEnd(DragEndDetails d) {
    _statsDragStartGlobalY = null;
    final vy = -d.velocity.pixelsPerSecond.dy;
    final shouldOpen = _statsSlideCtrl.value > 0.2 || vy > 600;
    _statsSlideCtrl.fling(velocity: shouldOpen ? 2.0 : -2.0);
  }

  void _handleXpBarTapDown(TapDownDetails details) {
    _xpBarTapStartedOnPlus =
        _xpBarCtrl.isPointInsidePlusBadge(details.globalPosition);
  }

  void _handleXpBarTapUp(TapUpDetails details) {
    final bool tappedPlus = _xpBarTapStartedOnPlus ||
        _xpBarCtrl.isPointInsidePlusBadge(details.globalPosition);
    _xpBarTapStartedOnPlus = false;
    if (tappedPlus) {
      _openCreateObjectiveFromXpBar();
    } else {
      _openStatsFully();
    }
  }

  void _handleXpBarTapCancel() {
    _xpBarTapStartedOnPlus = false;
  }

  void _openStatsFully() {
    _statsSlideCtrl.animateTo(
      1.0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 320),
    );
  }

  Future<void> _openCreateObjectiveFromXpBar() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateObjectiveScreen2(),
        fullscreenDialog: true,
      ),
    );
  }

  void _closeStats() {
    _statsSlideCtrl.animateTo(
      0.0,
      curve: Curves.easeInCubic,
      duration: const Duration(milliseconds: 280),
    );
  }

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

  void _openOrganizerScreen() {
    final provider = context.read<ObjectiveProvider>();
    final day = provider.selectedDateNotifier.value;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ObjectiveOrganizationScreen(day: day),
      ),
    );
  }

  void _handleAlignmentScheduleUpdate() {
    final provider = _alignmentProvider;
    if (provider == null || _notificationCenterOpen) return;
    final prompt = provider.peekPendingPrompt();
    if (prompt == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _notificationCenterOpen) return;
      final consumed = provider.consumePendingPrompt();
      if (consumed == null) return;
      _openNotificationCenter();
    });
  }

  void _openNotificationCenter() {
    if (_notificationCenterOpen) return;
    _notificationCenterOpen = true;
    final alignmentProvider = context.read<AlignmentScheduleProvider>();
    Navigator.of(context)
        .push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, _) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: _NotificationCenterPopup(
              heroTag: _notificationPopupHeroTag,
              onResetAlignment: () =>
                  context.read<AlignmentScheduleProvider>().resetTodayProgress(),
              onNotificationTap: _handleNotificationTap,
              onOpenBudgetBalance: _openBudgetBalanceFromNotification,
              onOpenMissionBoard: _openMissionBoardFromNotificationWithFocus,
              onOpenWorkoutDay: _openWorkoutDay,
            ),
          );
        },
      ),
    )
        .whenComplete(() {
      _notificationCenterOpen = false;
      alignmentProvider.reevaluate();
    });
  }

  Future<void> _handleNotificationTap(
    NotificationItem item, {
    bool autoCompleteTask = false,
  }) async {
    if (!_shouldOpenDaySchedule(item.kind)) return;
    final DateTime targetDay = _resolveNotificationDay(item);
    final bool isTask = item.kind == NotificationKind.taskDueToday;
    final String? focusTaskId =
        isTask ? _taskIdFromPayload(item.payload) : null;
    final String? autoCompleteTaskId =
        autoCompleteTask ? focusTaskId : null;

    if (_notificationCenterOpen) {
      await Navigator.of(context).maybePop();
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DayDetailPage(
          day: targetDay,
          startInSchedule: true,
          focusTaskId: focusTaskId,
          autoCompleteTaskId: autoCompleteTaskId,
        ),
        settings: const RouteSettings(
          name: 'day_detail_from_notification',
        ),
      ),
    );
  }

  Future<void> _openBudgetBalanceFromNotification({
    BudgetFocusTarget? focusTarget,
    BudgetBillFocus? billFocus,
    int? ringPage,
  }) async {
    if (_notificationCenterOpen) {
      await Navigator.of(context).maybePop();
    }
    await _goToBudgetPage();
    _budgetRingPageJump.value = ringPage ?? 0;
    if (focusTarget != null) {
      _budgetFocusSignal.value = focusTarget;
    }
    if (billFocus != null) {
      _budgetBillFocusSignal.value = billFocus;
    }
  }

  Future<void> _openMissionBoardFromNotificationWithFocus({
    String? missionId,
    bool? autoOpenDetail,
  }) async {
    if (_notificationCenterOpen) {
      await Navigator.of(context).maybePop();
    }
    await _openMissionBoardWithFocus(
      missionId: missionId,
      autoOpenDetail: autoOpenDetail ?? false,
    );
  }

  bool _shouldOpenDaySchedule(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.taskDueToday:
      case NotificationKind.eventStartingSoon:
      case NotificationKind.reminderDue:
      case NotificationKind.overlappingEvents:
        return true;
      default:
        return false;
    }
  }

  DateTime _resolveNotificationDay(NotificationItem item) {
    final fromPayload = _parseNotificationDay(item.payload);
    return fromPayload ?? DateKeys.dateOnly(item.createdAt);
  }

  DateTime? _parseNotificationDay(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    for (final key in const [
      'dateYmd',
      'dayYmd',
      'day',
      'dueDate',
      'dueOn',
      'dueYmd',
      'eventDate',
      'eventYmd',
      'startYmd',
      'startDate',
      'startDateYmd',
    ]) {
      final value = payload[key];
      final parsed = _coercePayloadDay(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _coercePayloadDay(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return DateKeys.dateOnly(value);
    }
    if (value is String && value.isNotEmpty) {
      if (DateKeys.ymdRegex.hasMatch(value)) {
        return DateKeys.fromYmd(value);
      }
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateKeys.dateOnly(parsed);
      }
    }
    if (value is int && value > 0) {
      final bool looksMillis = value > 100000000000;
      final millis = looksMillis ? value : value * 1000;
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      return DateKeys.dateOnly(dt);
    }
    return null;
  }

  String? _taskIdFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    for (final key in const ['taskId', 'task_id', 'taskID', 'id']) {
      final raw = payload[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ObjectiveProvider>(context);
    final media = MediaQuery.of(context);
    final screenH = media.size.height;

    final double topInset = media.padding.top;
    final double topEdgeHeight = (topInset + 10).clamp(24.0, 48.0);

    // 🔹 NEW: make the root scaffold match the page (progress vs budget)
    final bool onBudgetPage = _pageIndex == _budgetPageIndex;
    final bool onWorkoutPage = _pageIndex == _workoutPageIndex;
    final Color scaffoldBg = onBudgetPage
        ? BudgetScreenTheme.budgetGreen
        : onWorkoutPage
            ? kWorkoutPageBg
            : kProgressBg;
    const Color budgetBgColor = BudgetScreenTheme.budgetGreen;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_statsSlideCtrl.value > 0.01) {
          _closeStats();
          return;
        }
        if (_pageIndex != _progressPageIndex) {
          await _goToProgress();
          return;
        }
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: AnimatedContainer(
        duration: _pageTransitionDuration,
        curve: Curves.easeOutCubic,
        color: scaffoldBg,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                _buildProgressLayer(
                  provider: provider,
                  topEdgeHeight: topEdgeHeight,
                  budgetBackgroundColor: budgetBgColor,
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
          floatingActionButton: _pageIndex == _progressPageIndex
              ? AnimatedBuilder(
                  animation: _statsSlideCtrl,
                  builder: (context, child) {
                    if (_statsSlideCtrl.value > 0.01) {
                      return const SizedBox.shrink();
                    }
                    return child!;
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: _listBottomInsetForXpBar - 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ..._buildFabMenuButtons(),
                              const SizedBox(height: 12),
                            ],
                          ),
                          crossFadeState: _fabMenuExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                          sizeCurve: Curves.easeOutCubic,
                        ),
                        FloatingActionButton(
                          heroTag: 'fab_toggle_menu',
                          backgroundColor: _fabMenuExpanded
                              ? AppPalette.surface
                              : const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          tooltip: _fabMenuExpanded
                              ? 'Hide quick actions'
                              : 'Show quick actions',
                          onPressed: _toggleFabMenu,
                          child: Icon(
                            _fabMenuExpanded ? Icons.close : Icons.menu,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  List<Widget> _buildFabMenuButtons() {
    return [
      FloatingActionButton(
        heroTag: 'fab_to_xp_debug',
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        tooltip: 'Open XP Debugger',
        onPressed: () {
          _setFabMenuExpanded(false);
          _openXpDebuggerSheet();
        },
        child: const Icon(Icons.science_outlined),
      ),
      const SizedBox(height: 12),
      FloatingActionButton(
        heroTag: 'fab_backup_restore',
        backgroundColor: const Color(0xFF26A69A),
        foregroundColor: Colors.white,
        tooltip: 'Backup & restore',
        onPressed: _openDataManagementSheet,
        child: const Icon(Icons.save_alt),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildProgressLayer({
    required ObjectiveProvider provider,
    required double topEdgeHeight,
    required Color budgetBackgroundColor,
  }) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: _pageTransitionDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_pageIndex),
              child: SizedBox.expand(
                child: _buildPageForIndex(
                  provider: provider,
                  budgetBackgroundColor: budgetBackgroundColor,
                ),
              ),
            ),
          ),
          // Top edge drag to open calendar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: topEdgeHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              excludeFromSemantics: true,
              onVerticalDragStart: (d) {
                _dragStartY = d.globalPosition.dy;
              },
              onVerticalDragUpdate: (d) {
                final start = _dragStartY ?? d.globalPosition.dy;
                final dy = d.globalPosition.dy - start;
                if (dy > 36) _openCalendarOnce();
              },
              onVerticalDragEnd: (_) {
                _dragStartY = null;
              },
            ),
          ),
          if (_pageIndex == _progressPageIndex)
            Positioned(
              top: -10,
              left: 4,
              child: IconButton(
                icon: const Icon(
                  Icons.push_pin,
                  color: AppPalette.onSurface,
                  size: 19,
                ),
                tooltip: 'Mission Board',
                onPressed: _openMissionBoard,
              ),
            ),
          if (_pageIndex == _progressPageIndex)
            Positioned(
              top: -10,
              right: 4,
              child: _NotificationCenterIconButton(
                onPressed: _openNotificationCenter,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageForIndex({
    required ObjectiveProvider provider,
    required Color budgetBackgroundColor,
  }) {
    if (_pageIndex == _budgetPageIndex) {
      return TickerMode(
        enabled: true,
        child: Container(
          color: budgetBackgroundColor,
          child: RepaintBoundary(
            child: BudgetScreenV2(
              ringPageJumpSignal: _budgetRingPageJump,
              focusSignal: _budgetFocusSignal,
              billFocusSignal: _budgetBillFocusSignal,
            ),
          ),
        ),
      );
    }

    if (_pageIndex == _workoutPageIndex) {
      return TickerMode(
        enabled: true,
        child: Container(
          color: kWorkoutPageBg,
          child: WorkoutDashboardScreen(
            onClose: () {
              if (mounted) _goToProgress();
            },
            dateSignal: _workoutDateSignal,
          ),
        ),
      );
    }

    return TickerMode(
      enabled: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onProgressHorizontalDragStart,
        onHorizontalDragUpdate: _onProgressHorizontalDragUpdate,
        onHorizontalDragEnd: _onProgressHorizontalDragEnd,
        onHorizontalDragCancel: _onProgressHorizontalDragCancel,
        child: const RepaintBoundary(
          child: _KeepAlive(child: _ProgressPageContent()),
        ),
      ),
    );
  }

  Widget _buildProgressContentImpl(ObjectiveProvider provider) {
    return Stack(
      children: [
        ValueListenableBuilder<DateTime>(
          valueListenable: provider.selectedDateNotifier,
          builder: (context, selectedDate, _) {
            final objectives = provider.getObjectivesForDay(selectedDate);

            final Map<String, List<Objective>> groupedByCategory = {};
            final List<Objective> abstinenceObjectives = [];

            for (final obj in objectives) {
              if (obj.isAbstinence) {
                abstinenceObjectives.add(obj);
                continue;
              }

              final category = obj.categoryIds.isNotEmpty
                  ? obj.categoryIds.first
                  : kUncategorizedCategoryName;
              groupedByCategory.putIfAbsent(category, () => []).add(obj);
            }

            if (abstinenceObjectives.isNotEmpty) {
              groupedByCategory[kAbstinenceCategoryName] = abstinenceObjectives;
            }

            final orderedCats = groupedByCategory.keys.toList()
              ..sort(_compareCategoryNames);

            final headerChildren = <Widget>[
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
              _CompactDayStreakStrip(
                viewingDay: selectedDate,
                onOrganizePressed: _openOrganizerScreen,
              ),
              const SizedBox(height: 4),
            ];

            final header = Column(children: headerChildren);

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
                  onTapDown: _handleXpBarTapDown,
                  onTapUp: _handleXpBarTapUp,
                  onTapCancel: _handleXpBarTapCancel,
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
                onTapDown: _handleXpBarTapDown,
                onTapUp: _handleXpBarTapUp,
                onTapCancel: _handleXpBarTapCancel,
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

  Widget _buildNormalCategoryList(
    List<String> orderedCats,
    Map<String, List<Objective>> groupedByCategory,
    ObjectiveProvider provider,
    DateTime selectedDate,
  ) {
    final itemCount = orderedCats.length + 3;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: _listBottomInsetForXpBar),
      cacheExtent: 800,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < orderedCats.length) {
          final category = orderedCats[index];
          final items = groupedByCategory[category]!;
          final initiallyExpanded = _expandedCategories[category] ?? true;
          final isAbstinenceCategory = category == kAbstinenceCategoryName;

          return _CategorySection(
            key: ValueKey('cat_$category'),
            category: category,
            items: items,
            initiallyExpanded: initiallyExpanded,
            selectedDate: selectedDate,
            onExpandedChanged: (expanded) {
              setState(() => _expandedCategories[category] = expanded);
            },
            canDismiss:
                !isAbstinenceCategory && category != kUncategorizedCategoryName,
            confirmDelete: isAbstinenceCategory
                ? () async => false
                : () => _confirmDeleteCategory(context, category),
            onDeleted: isAbstinenceCategory
                ? () async {}
                : () async {
                    await provider.deleteCategory(category);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Category "$category" deleted'),
                      ),
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

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({
    required this.routineId,
    this.missedDate,
  });

  final String routineId;
  final DateTime? missedDate;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late DateTime _anchor;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = AppClock.now();
    _anchor = widget.missedDate ?? DateTime(now.year, now.month, now.day);
    _selected = _anchor;
  }

  List<DateTime> _buildRange() {
    return List<DateTime>.generate(
      7,
      (i) => _anchor.add(Duration(days: i - 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _buildRange();
    final wp = context.read<WorkoutProvider>();
    final routine = wp.getRoutineById(widget.routineId);
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Reschedule workouts',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a day to shift this routine’s schedule (rest days shift too).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .7),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: range.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = range[index];
                  final bool selected = DateKeys.dateOnly(day) ==
                      DateKeys.dateOnly(_selected);
                  final completion =
                      _computeDayCompletion(wp, routine, day);
                  final bool isRest = routine == null
                      ? false
                      : wp.isRestDay(widget.routineId, day);
                  return GestureDetector(
                    onTap: () => setState(() => _selected = day),
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: .12)
                            : Colors.white.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Colors.blueAccent.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: .12),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat.E().format(day),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          _DayCircle(
                            progress: isRest ? 1.0 : completion,
                            isRest: isRest,
                          ),
                          Text(
                            DateFormat.d().format(day),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: routine == null
                        ? null
                        : () async {
                            final delta =
                                _selected.difference(_anchor).inDays;
                            final workoutProvider = context.read<WorkoutProvider>();
                            final navigator = Navigator.of(context);
                            if (delta != 0) {
                              await WorkoutProgressService.shiftRoutineSchedule(
                                routine: routine,
                                deltaDays: delta,
                              );
                              if (mounted) {
                                await workoutProvider
                                    .emitScheduleNotifications(
                                      routineId: routine.id,
                                      now: _selected,
                                    );
                              }
                            }
                            if (mounted) navigator.maybePop();
                          },
                    child: const Text('Shift schedule'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _computeDayCompletion(
    WorkoutProvider wp,
    Routine? routine,
    DateTime day,
  ) {
    if (routine == null) return 0.0;
    final prescribed = WorkoutProgressService.getPrescribedWorkouts(
      routineId: routine.id,
      date: day,
    );
    if (prescribed.isEmpty) return 0.0;
    double total = 0;
    int count = 0;
    for (final wid in prescribed) {
      final w = wp.getWorkoutById(wid);
      if (w == null) continue;
      total += WorkoutProgressService.instance.completionForDay(
        workout: w,
        scheduledDate: day,
      );
      count++;
    }
    if (count == 0) return 0.0;
    return (total / count).clamp(0.0, 1.0);
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({required this.progress, required this.isRest});

  final double progress;
  final bool isRest;

  @override
  Widget build(BuildContext context) {
    final Color ring = isRest ? Colors.tealAccent : Colors.blueAccent;
    final double clamped = progress.clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: clamped == 0 ? 0.01 : clamped,
            strokeWidth: 3,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(ring),
          ),
        ),
        Icon(
          isRest ? Icons.self_improvement : Icons.fitness_center,
          size: 14,
          color: Colors.white,
        ),
      ],
    );
  }
}

class _RescheduleHeroPopup extends StatelessWidget {
  const _RescheduleHeroPopup({
    required this.heroTag,
    required this.routineId,
    this.missedDate,
  });

  final String heroTag;
  final String routineId;
  final DateTime? missedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              color: Colors.black.withValues(alpha: .45),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: ModalRoute.of(context)!.animation!,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxWidth =
                        (constraints.maxWidth - 32).clamp(0.0, 440.0);
                    return Center(
                      child: Container(
                        width: maxWidth,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppPalette.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .12),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _RescheduleSheet(
                            routineId: routineId,
                            missedDate: missedDate,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _CompactDayStreakStrip extends StatelessWidget {
  const _CompactDayStreakStrip({
    required this.viewingDay,
    required this.onOrganizePressed,
  });

  final DateTime viewingDay;
  final VoidCallback onOrganizePressed;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ObjectiveProvider>();
    final streakEngine = context.read<StreakEngine>();

    final DateTime day = _strip(viewingDay);

    final viewingState = provider.getTodayState(day);
    final int done = viewingState.completedObjectives;
    final int total = viewingState.activeObjectives;

    return ValueListenableBuilder(
      valueListenable: streakEngine.dayListenable(),
      builder: (_, __, ___) {
        final streak = streakEngine.getDayStreak().current;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Day streak · $streak day${streak == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.onSurface,
                      ),
                    ),
                    Text(
                      'Progress ${_fmt(day)}: $done / $total',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppPalette.onSurface.withValues(alpha: .45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                icon: const Icon(
                  Icons.apps_rounded,
                  size: 20,
                  color: Colors.white38,
                ),
                tooltip: 'Organize objectives',
                onPressed: onOrganizePressed,
              ),
            ],
          ),
        );
      },
    );
  }

  static DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _fmt(DateTime d) {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(d.year, d.month, d.day);
    if (t == today) return 'today';
    return '${d.month}/${d.day}';
  }

}

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

class _ProgressPageContent extends StatelessWidget {
  const _ProgressPageContent();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ObjectiveProvider>(context, listen: true);
    final state = context.findAncestorStateOfType<_ProgressScreenState>();
    if (state == null) return const SizedBox.shrink();
    return state._buildProgressContentImpl(provider);
  }
}

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
    required this.selectedDate,
  });

  final String category;
  final List<Objective> items;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpandedChanged;

  final bool canDismiss;
  final Future<bool> Function() confirmDelete;
  final Future<void> Function() onDeleted;

  final Widget Function(Objective obj) rowBuilder;

  final DateTime selectedDate;

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
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        widget.initiallyExpanded != _expanded) {
      _expanded = widget.initiallyExpanded;
      _ctrl.animateTo(_expanded ? 1.0 : 0.0);
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged(_expanded);
    _ctrl.animateTo(_expanded ? 1.0 : 0.0);
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
    final anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

    final bool isAbstinence = widget.category == kAbstinenceCategoryName;
    final Color pillColor = isAbstinence
        ? const Color(0xFF1A0C11)
        : kCategoryPillColor;
    final Color borderColor = isAbstinence
        ? const Color(0x66FF4D6A)
        : AppPalette.outline.withValues(alpha: .28);
    final double baseRadius = isAbstinence ? 9.0 : 14.0;
    final double baseVerticalPad = isAbstinence ? 3.0 : 7.0;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          final t = anim.value;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(baseRadius - (1.0 * t)),
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(baseRadius - (1.0 * t)),
              child: Ink(
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(baseRadius - (1.0 * t)),
                  border: Border.all(
                    color: borderColor,
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isAbstinence ? 10 : 12,
                    vertical: baseVerticalPad + (isAbstinence ? 0.8 : 1.5) * t,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          "${widget.category} (${widget.items.length})",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppPalette.onSurface,
                            letterSpacing: 0.15,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      CategoryClaimChip(
                        categoryId: widget.category,
                        date: widget.selectedDate,
                      ),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          splashRadius: 18,
                          onPressed: _toggle,
                          icon: RotationTransition(
                            turns: Tween<double>(begin: 0.0, end: 0.5)
                                .animate(anim),
                            child: const Icon(
                              Icons.expand_more,
                              color: AppPalette.onSurface,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: SizeTransition(
        sizeFactor: anim,
        axisAlignment: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              const SizedBox(height: 4),
              for (final obj in widget.items) widget.rowBuilder(obj),
              const SizedBox(height: 4),
            ],
          ),
        ),
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
          body,
          if (widget.category == kUncategorizedCategoryName)
            const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _NotificationCenterIconButton extends StatelessWidget {
  const _NotificationCenterIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notification center',
      preferBelow: false,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(
          Icons.circle_outlined,
          color: AppPalette.onSurface,
          size: 18,
        ),
        tooltip: 'Notification center',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: 42,
          height: 42,
        ),
        splashRadius: 21,
      ),
    );
  }
}

typedef NotificationTapCallback = Future<void> Function(
  NotificationItem item, {
  bool autoCompleteTask,
});

typedef BudgetOpenCallback = Future<void> Function({
  BudgetFocusTarget? focusTarget,
  BudgetBillFocus? billFocus,
  int? ringPage,
});

typedef MissionOpenCallback = Future<void> Function({
  String? missionId,
  bool? autoOpenDetail,
});

typedef WorkoutDayOpenCallback = Future<void> Function(DateTime day);

class _NotificationCenterPopup extends StatefulWidget {
  const _NotificationCenterPopup({
    required this.heroTag,
    required this.onResetAlignment,
    this.onNotificationTap,
    this.onOpenBudgetBalance,
    this.onOpenMissionBoard,
    this.onOpenWorkoutDay,
  });

  final String heroTag;
  final Future<void> Function() onResetAlignment;
  final NotificationTapCallback? onNotificationTap;
  final BudgetOpenCallback? onOpenBudgetBalance;
  final MissionOpenCallback? onOpenMissionBoard;
  final WorkoutDayOpenCallback? onOpenWorkoutDay;

  @override
  State<_NotificationCenterPopup> createState() =>
      _NotificationCenterPopupState();
}

class _NotificationCenterPopupState extends State<_NotificationCenterPopup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateWorkoutNotifications());
  }

  Future<void> _evaluateWorkoutNotifications() async {
    final profile = context.read<FitnessProfileProvider>().profile;
    final routineId = profile?.currentRoutineId;
    if (routineId == null) return;
    final wp = context.read<WorkoutProvider>();
    await wp.emitScheduleNotifications(
      routineId: routineId,
      now: AppClock.now(),
    );
  }

  Future<void> _handleAlignmentTap() async {
    final provider = context.read<AlignmentScheduleProvider>();
    final success = await provider.completeNextCheckIn();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Logged alignment check-in' : 'All check-ins are done',
        ),
      ),
    );
  }

  Future<void> _openScheduleSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const _AlignmentScheduleSheet();
      },
    );
  }

  void _openAlignmentFlow() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, _) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: AlignmentFlowPage(heroTag: widget.heroTag),
          );
        },
      ),
    );
  }

  Color _moduleColor(NotificationModule module) {
    switch (module) {
      case NotificationModule.workouts:
        return const Color(0xFF5EEAD4);
      case NotificationModule.missions:
        return const Color(0xFFFFB74D);
      case NotificationModule.budget:
        return const Color(0xFF7DD3FC);
      case NotificationModule.calendar:
        return const Color(0xFFA78BFA);
      case NotificationModule.tasks:
        return const Color(0xFF90CAF9);
    }
  }

  String _notificationHeroTag(NotificationItem item) => 'notif_${item.id}';

  bool _routesToDaySchedule(NotificationItem item) {
    switch (item.kind) {
      case NotificationKind.taskDueToday:
      case NotificationKind.eventStartingSoon:
      case NotificationKind.reminderDue:
      case NotificationKind.overlappingEvents:
        return true;
      default:
        return false;
    }
  }

  bool _routesToBudget(NotificationItem item) {
    if (item.module != NotificationModule.budget) return false;
    switch (item.kind) {
      case NotificationKind.lowBalanceForBill:
      case NotificationKind.categoryOverBudget:
      case NotificationKind.billUpcoming:
      case NotificationKind.billOverdue:
        return true;
      default:
        return false;
    }
  }

  bool _routesToWorkout(NotificationItem item) {
    if (item.module != NotificationModule.workouts) return false;
    switch (item.kind) {
      case NotificationKind.missedWorkout:
      case NotificationKind.sessionInProgress:
      case NotificationKind.restDayReminder:
        return true;
      default:
        return false;
    }
  }

  bool _routesToMissions(NotificationItem item) {
    if (item.module != NotificationModule.missions) return false;
    switch (item.kind) {
      case NotificationKind.missionOverdue:
      case NotificationKind.missionRefresh:
        return true;
      default:
        return false;
    }
  }

  BudgetFocusTarget? _budgetFocusTargetFor(NotificationItem item) {
    switch (item.kind) {
      case NotificationKind.billUpcoming:
      case NotificationKind.billOverdue:
        return BudgetFocusTarget.upcomingBills;
      default:
        return null;
    }
  }

  bool _wantsBillDetail(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.billUpcoming:
      case NotificationKind.billOverdue:
        return true;
      default:
        return false;
    }
  }

  int? _ringPageFor(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.lowBalanceForBill:
        return 0; // Bank balances page
      case NotificationKind.categoryOverBudget:
        return 1; // Budget ring
      default:
        return null;
    }
  }

  BudgetBillFocus? _billFocusFromNotification(NotificationItem item) {
    if (item.module != NotificationModule.budget) return null;
    final payload = item.payload ?? const <String, dynamic>{};
    final key = _firstString(payload, const ['billKey', 'bill_key', 'key']);
    final budgetId =
        _firstString(payload, const ['budgetId', 'budget_id', 'budgetID']);
    final billId =
        _firstString(payload, const ['billId', 'bill_id', 'billID', 'id']);
    final bundledId = _firstId(payload['ids']);
    final name = _firstString(
          payload,
          const ['billName', 'name', 'title'],
        ) ??
        _billNameFromDetail(item.detail);
    final amountCents =
        _parseAmountCents(payload['amountCents'], assumeCents: true) ??
            _parseAmountCents(payload['amount']) ??
            _parseAmountCents(payload['total']) ??
            _parseAmountFromDetail(item.detail);
    final dueDate = _parseBillDueDate(payload);

    final combinedKey = key ?? billId ?? bundledId;
    final focus = BudgetBillFocus(
      billKey: combinedKey,
      budgetId: budgetId,
      name: name,
      amountCents: amountCents,
      dueDate: dueDate,
    );
    return focus.hasData ? focus : null;
  }

  String? _firstString(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _firstId(dynamic raw) {
    if (raw is List) {
      for (final value in raw) {
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  DateTime? _parseBillDueDate(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    for (final key in const [
      'dueDate',
      'dueOn',
      'due',
      'dueYmd',
      'due_ymd',
      'dueTs',
      'due_ts',
      'due_date',
      'dueDateIso',
      'dueDateMs',
      'dueDateMillis',
      'date',
      'dateYmd',
      'billDue',
    ]) {
      final parsed = _coerceBillDate(payload[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _coerceBillDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return DateKeys.dateOnly(raw);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (DateKeys.ymdRegex.hasMatch(trimmed)) {
        return DateKeys.fromYmd(trimmed);
      }
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return DateKeys.dateOnly(parsed);
      final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        final millis = int.tryParse(digits);
        if (millis != null) {
          final isMillis = digits.length > 10;
          final dt = DateTime.fromMillisecondsSinceEpoch(
            isMillis ? millis : millis * 1000,
          );
          return DateKeys.dateOnly(dt);
        }
      }
    }
    if (raw is int) {
      final isMillis = raw > 100000000000;
      final dt =
          DateTime.fromMillisecondsSinceEpoch(isMillis ? raw : raw * 1000);
      return DateKeys.dateOnly(dt);
    }
    if (raw is double) {
      final millis = raw.round();
      final isMillis = millis > 100000000000;
      final dt = DateTime.fromMillisecondsSinceEpoch(
        isMillis ? millis : millis * 1000,
      );
      return DateKeys.dateOnly(dt);
    }
    return null;
  }

  int? _parseAmountCents(
    dynamic raw, {
    bool assumeCents = false,
  }) {
    if (raw == null) return null;
    if (raw is int) {
      return assumeCents ? raw : (raw * 100);
    }
    if (raw is double) {
      return assumeCents ? raw.round() : (raw * 100).round();
    }
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.-]'), '');
      if (cleaned.isEmpty) return null;
      final value = double.tryParse(cleaned);
      if (value == null) return null;
      if (assumeCents) return value.round();
      return (value * 100).round();
    }
    return null;
  }

  int? _parseAmountFromDetail(String detail) {
    final match =
        RegExp(r'([-+]?[0-9]*\.?[0-9]+)').firstMatch(detail.replaceAll(',', ''));
    if (match == null) return null;
    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;
    return (value * 100).round();
  }

  String? _billNameFromDetail(String detail) {
    final parts = detail.split(RegExp(r'[·•|-]'));
    if (parts.isEmpty) return null;
    final candidate = parts.first.trim();
    return candidate.isEmpty ? null : candidate;
  }

  String? _missionIdFromNotification(NotificationItem item) {
    final payload = item.payload ?? const <String, dynamic>{};
    final missionId = _firstString(
      payload,
      const ['missionId', 'mission_id', 'missionID', 'id'],
    );
    return missionId ?? _firstId(payload['ids']);
  }

  VoidCallback? _buildPillTapHandler(NotificationItem item) {
    if (_disableCardTap(item)) return null;
    if (_routesToDaySchedule(item) && widget.onNotificationTap != null) {
      return () => widget.onNotificationTap!(item);
    }
    if (_routesToBudget(item) && widget.onOpenBudgetBalance != null) {
      final focus = _budgetFocusTargetFor(item);
      final billFocus =
          _wantsBillDetail(item.kind) ? _billFocusFromNotification(item) : null;
      final ringPage = _ringPageFor(item.kind);
      return () => widget.onOpenBudgetBalance!(
            focusTarget: focus,
            billFocus: billFocus,
            ringPage: ringPage,
          );
    }
    if (_routesToWorkout(item)) {
      if (item.kind == NotificationKind.sessionInProgress) {
        return () => _openWorkoutFromNotification(item.payload);
      }
      if (item.kind == NotificationKind.missedWorkout &&
          widget.onOpenWorkoutDay != null) {
        final targetDay = _scheduledDayFromPayload(item.payload) ??
            DateKeys.dateOnly(item.createdAt);
        return () => widget.onOpenWorkoutDay!(targetDay);
      }
      if (item.kind == NotificationKind.restDayReminder &&
          widget.onOpenWorkoutDay != null) {
        final today = DateKeys.dateOnly(AppClock.now());
        return () => widget.onOpenWorkoutDay!(today);
      }
    }
    if (_routesToMissions(item) && widget.onOpenMissionBoard != null) {
      final missionId = _missionIdFromNotification(item);
      final autoDetail = item.kind == NotificationKind.missionOverdue;
      return () => widget.onOpenMissionBoard!(
            missionId: missionId,
            autoOpenDetail: autoDetail,
          );
    }
    return null;
  }

  bool _disableCardTap(NotificationItem item) {
    switch (item.kind) {
      case NotificationKind.taskDueToday:
      case NotificationKind.reminderDue:
      case NotificationKind.eventStartingSoon:
      case NotificationKind.lowBalanceForBill:
      case NotificationKind.categoryOverBudget:
      case NotificationKind.billOverdue:
      case NotificationKind.billUpcoming:
      case NotificationKind.missionRefresh:
      case NotificationKind.missedWorkout:
      case NotificationKind.restDayReminder:
      case NotificationKind.missionOverdue:
      case NotificationKind.overlappingEvents:
        return true;
      default:
        return false;
    }
  }

  Future<Duration?> _pickSnoozeDuration(NotificationItem item) async {
    return showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Duration option(int minutes) => Duration(minutes: minutes);
        final options = [15, 30, 60];
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snooze "${item.title}"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              ...options.map(
                (m) => ListTile(
                  title: Text('$m minutes',
                      style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.of(ctx).pop(option(m)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _seedDemoNotifications() async {
    final center = context.read<NotificationCenterProvider>();
    final now = AppClock.now();
    await center.addAll([
      // Workouts
      NotificationItem(
        id: 'demo_session_in_progress',
        module: NotificationModule.workouts,
        kind: NotificationKind.sessionInProgress,
        title: 'Session in progress',
        detail: 'Push A · logged warm-up',
        meta: '12m elapsed',
        severity: NotificationSeverity.nonCritical,
        groupKey: 'session_demo',
        actions: const [
          NotificationAction(
            label: 'Resume',
            type: NotificationActionType.resume,
            payload: {
              'routineId': 'demo_routine',
              'workoutId': 'demo_workout',
            },
          ),
          NotificationAction(
            label: 'Dismiss',
            type: NotificationActionType.dismiss,
          ),
        ],
        payload: const {
          'routineId': 'demo_routine',
          'workoutId': 'demo_workout',
        },
      ),
      NotificationItem(
        id: 'demo_missed_workout',
        module: NotificationModule.workouts,
        kind: NotificationKind.missedWorkout,
        title: 'Missed workout',
        detail: 'Leg day · reschedule?',
        meta: 'Yesterday',
        severity: NotificationSeverity.nonCritical,
        actions: const [
          NotificationAction(
            label: 'Reschedule',
            type: NotificationActionType.reschedule,
          ),
          NotificationAction(
            label: 'Dismiss',
            type: NotificationActionType.dismiss,
          ),
        ],
      ),
      NotificationItem(
        id: 'demo_rest_day',
        module: NotificationModule.workouts,
        kind: NotificationKind.restDayReminder,
        title: 'Rest day',
        detail: 'Log recovery or mobility',
        meta: 'Today',
        severity: NotificationSeverity.nonCritical,
        actions: const [
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
          NotificationAction(
            label: 'Dismiss',
            type: NotificationActionType.dismiss,
          ),
        ],
      ),

      // Missions
      NotificationItem(
        id: 'demo_mission_overdue',
        module: NotificationModule.missions,
        kind: NotificationKind.missionOverdue,
        title: 'Mission overdue',
        detail: 'Ship draft chapter today',
        meta: 'Due today',
        severity: NotificationSeverity.critical,
        groupKey: 'mission_overdue',
        actions: const [
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
          NotificationAction(
            label: 'Dismiss',
            type: NotificationActionType.dismiss,
          ),
        ],
      ),
      NotificationItem(
        id: 'demo_mission_refresh',
        module: NotificationModule.missions,
        kind: NotificationKind.missionRefresh,
        title: 'Mission slot available',
        detail: 'New mission ready to pick',
        meta: 'Just now',
        severity: NotificationSeverity.nonCritical,
        actions: const [
          NotificationAction(
            label: 'Open',
            type: NotificationActionType.open,
          ),
          NotificationAction(
            label: 'Dismiss',
            type: NotificationActionType.dismiss,
          ),
        ],
      ),

      // Budget
      NotificationItem(
        id: 'demo_bill_upcoming',
        module: NotificationModule.budget,
        kind: NotificationKind.billUpcoming,
        title: 'Bill upcoming',
        detail: 'Phone · \$45',
        meta: 'Due in 2d',
        severity: NotificationSeverity.nonCritical,
        actions: const [
          NotificationAction(
            label: 'Pay',
            type: NotificationActionType.pay,
          ),
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
        ],
      ),
      NotificationItem(
        id: 'demo_bill_overdue_1',
        module: NotificationModule.budget,
        kind: NotificationKind.billOverdue,
        title: 'Bill overdue',
        detail: 'Internet · \$60',
        meta: '3 days late',
        severity: NotificationSeverity.critical,
        groupKey: 'bill_overdue',
        actions: const [
          NotificationAction(
            label: 'Pay now',
            type: NotificationActionType.pay,
          ),
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
        ],
      ),
      NotificationItem(
        id: 'demo_bill_overdue_2',
        module: NotificationModule.budget,
        kind: NotificationKind.billOverdue,
        title: 'Bill overdue',
        detail: 'Utilities · \$120',
        meta: 'Today',
        severity: NotificationSeverity.critical,
        groupKey: 'bill_overdue',
        actions: const [
          NotificationAction(
            label: 'Pay now',
            type: NotificationActionType.pay,
          ),
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
        ],
      ),
      NotificationItem(
        id: 'demo_over_budget',
        module: NotificationModule.budget,
        kind: NotificationKind.categoryOverBudget,
        title: 'Over budget',
        detail: 'Dining is 18% over plan',
        meta: 'This month',
        severity: NotificationSeverity.nonCritical,
        actions: const [
          NotificationAction(
            label: 'View',
            type: NotificationActionType.open,
          ),
          NotificationAction(
            label: 'Dismiss',
            type: NotificationActionType.dismiss,
          ),
        ],
      ),
      NotificationItem(
        id: 'demo_low_balance',
        module: NotificationModule.budget,
        kind: NotificationKind.lowBalanceForBill,
        title: 'Low balance',
        detail: 'Balance may not cover Rent \$1500',
        meta: 'Due in 5d',
        severity: NotificationSeverity.critical,
        actions: const [
          NotificationAction(
            label: 'View',
            type: NotificationActionType.open,
          ),
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
        ],
      ),

      // Calendar/Tasks
      NotificationItem(
        id: 'demo_event_soon',
        module: NotificationModule.calendar,
        kind: NotificationKind.eventStartingSoon,
        title: 'Event starting soon',
        detail: 'Weekly sync · Zoom',
        meta: 'Starts in 15m',
        severity: NotificationSeverity.nonCritical,
        expiresAt: now.add(const Duration(hours: 2)),
        actions: const [
          NotificationAction(
            label: 'View',
            type: NotificationActionType.open,
          ),
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
        ],
        payload: {
          'eventId': 'demo_event_soon',
          'dateYmd': DateKeys.ymd(now),
        },
      ),
      NotificationItem(
        id: 'demo_reminder_due',
        module: NotificationModule.calendar,
        kind: NotificationKind.reminderDue,
        title: 'Reminder due',
        detail: 'Call back Alex',
        meta: 'Due now',
        severity: NotificationSeverity.nonCritical,
        actions: const [
          NotificationAction(
            label: 'View',
            type: NotificationActionType.open,
          ),
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
        ],
        payload: {
          'reminderId': 'demo_reminder_due',
          'dateYmd': DateKeys.ymd(now),
        },
      ),
      NotificationItem(
        id: 'demo_overlap',
        module: NotificationModule.calendar,
        kind: NotificationKind.overlappingEvents,
        title: 'Overlapping events',
        detail: 'Standup vs. Client call',
        meta: '10:00 AM',
        severity: NotificationSeverity.nonCritical,
        actions: const [
          NotificationAction(
            label: 'Reschedule',
            type: NotificationActionType.open,
          ),
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
        ],
        payload: {
          'dateYmd': DateKeys.ymd(now),
        },
      ),
      NotificationItem(
        id: 'demo_task_due',
        module: NotificationModule.tasks,
        kind: NotificationKind.taskDueToday,
        title: 'Task due today',
        detail: 'Send weekly report',
        meta: 'Today 5 PM',
        severity: NotificationSeverity.nonCritical,
        actions: const [
          NotificationAction(
            label: 'Complete',
            type: NotificationActionType.complete,
          ),
          NotificationAction(
            label: 'Snooze',
            type: NotificationActionType.snooze,
          ),
        ],
        payload: {
          'taskId': 'demo_task_due',
          'dateYmd': DateKeys.ymd(now),
        },
      ),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seeded demo notifications'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  DateTime? _parseYmdString(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 8) {
      final y = int.tryParse(cleaned.substring(0, 4));
      final m = int.tryParse(cleaned.substring(4, 6));
      final d = int.tryParse(cleaned.substring(6, 8));
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    final DateTime? parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return null;
  }

  DateTime? _scheduledDayFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final DateTime? fromYmd = _parseYmdString(
      (payload['dateYmd'] ??
              payload['scheduledDateYmd'] ??
              payload['scheduledDate']) as String?,
    );
    if (fromYmd != null) return fromYmd;
    return _parseYmdString(payload['scheduledDateIso'] as String?);
  }

  Future<void> _openWorkoutFromNotification(
    Map<String, dynamic>? payload,
  ) async {
    final routineId = payload?['routineId'] as String?;
    final workoutId = payload?['workoutId'] as String?;
    if (routineId == null || workoutId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing workout info')),
      );
      return;
    }
    final wp = context.read<WorkoutProvider>();
    final today = AppClock.now();
    final DateTime normalized = DateTime(today.year, today.month, today.day);
    final DateTime scheduledDay =
        _scheduledDayFromPayload(payload) ?? normalized;
    final alreadyActive = wp.activeDraft?.workoutId == workoutId;
    if (!alreadyActive) {
      final result = wp.startSession(
        routineId: routineId,
        workoutId: workoutId,
        source: 'notification_center',
        calendarDayOverride: scheduledDay,
      );
      if (!result.started) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? 'Unable to start that workout right now.',
            ),
          ),
        );
        return;
      }
    }
    final args = SessionScreenArgs(
      routineId: routineId,
      workoutId: workoutId,
      source: 'notification_center',
      attachToRoutineId: routineId,
      scheduledDate: scheduledDay,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScreen(args: args),
        settings:
            const RouteSettings(name: 'session_from_notification_center'),
      ),
    );
  }

  Future<void> _openReschedulePopup(
    NotificationItem item,
    Map<String, dynamic>? payload,
  ) async {
    final workoutProvider = context.read<WorkoutProvider>();
    String? routineIdMaybe = payload?['routineId'] as String?;
    routineIdMaybe ??= workoutProvider.activeDraft?.routineId;
    routineIdMaybe ??=
        context.read<FitnessProfileProvider>().profile?.currentRoutineId;
    if (routineIdMaybe == null && workoutProvider.routines.isNotEmpty) {
      routineIdMaybe = workoutProvider.routines.first.id;
    }
    if (routineIdMaybe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing routine for reschedule')),
      );
      return;
    }
    final String routineId = routineIdMaybe;
    DateTime? missedDate;
    final ymd = payload?['dateYmd'] as String?;
    if (ymd != null) {
      missedDate = DateTime.tryParse(ymd);
    }
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: .45),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => _RescheduleHeroPopup(
          heroTag: _notificationHeroTag(item),
          routineId: routineId,
          missedDate: missedDate,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
    NotificationAction action,
    NotificationItem item,
  ) async {
    final center = context.read<NotificationCenterProvider>();
    switch (action.type) {
      case NotificationActionType.snooze:
        final duration = await _pickSnoozeDuration(item);
        if (duration != null) {
          await center.snooze(item.id, duration);
        }
        break;
      case NotificationActionType.dismiss:
        await center.dismiss(item.id);
        break;
      case NotificationActionType.resume:
      case NotificationActionType.open:
        if (item.module == NotificationModule.workouts) {
          await _openWorkoutFromNotification(action.payload ?? item.payload);
        } else if (item.module == NotificationModule.budget &&
            widget.onOpenBudgetBalance != null) {
          final focus = _budgetFocusTargetFor(item);
          final billFocus = _wantsBillDetail(item.kind)
              ? _billFocusFromNotification(item)
              : null;
          final ringPage = _ringPageFor(item.kind);
          await widget.onOpenBudgetBalance!(
            focusTarget: focus,
            billFocus: billFocus,
            ringPage: ringPage,
          );
          if (item.kind == NotificationKind.lowBalanceForBill ||
              item.kind == NotificationKind.categoryOverBudget) {
            await center.dismiss(item.id);
          }
        } else if (item.module == NotificationModule.missions &&
            widget.onOpenMissionBoard != null &&
            (item.kind == NotificationKind.missionRefresh ||
                item.kind == NotificationKind.missionOverdue)) {
          final missionId = _missionIdFromNotification(item);
          final autoDetail = item.kind == NotificationKind.missionOverdue;
          await widget.onOpenMissionBoard!(
            missionId: missionId,
            autoOpenDetail: autoDetail,
          );
          await center.dismiss(item.id);
        } else if (_routesToDaySchedule(item)) {
          if (widget.onNotificationTap != null) {
            await widget.onNotificationTap!(item);
          }
          await center.dismiss(item.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Action: ${action.label}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      case NotificationActionType.end:
        await context.read<WorkoutProvider>().finishSession();
        await center.dismiss(item.id);
        break;
      case NotificationActionType.pay:
        if (item.module == NotificationModule.budget &&
            widget.onOpenBudgetBalance != null &&
            (item.kind == NotificationKind.billUpcoming ||
                item.kind == NotificationKind.billOverdue)) {
          final focus = _budgetFocusTargetFor(item);
          final billFocus = _billFocusFromNotification(item);
          await widget.onOpenBudgetBalance!(
            focusTarget: focus,
            billFocus: billFocus,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Action: ${action.label}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      case NotificationActionType.complete:
        if (item.kind == NotificationKind.taskDueToday &&
            widget.onNotificationTap != null) {
          await widget.onNotificationTap!(
            item,
            autoCompleteTask: true,
          );
          await center.dismiss(item.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Action: ${action.label}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      case NotificationActionType.reschedule:
        await _openReschedulePopup(item, action.payload ?? item.payload);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action: ${action.label}'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.animation;
    final curved = animation == null
        ? null
        : CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

    final media = MediaQuery.of(context);
    final size = media.size;

    final alignmentProvider = context.watch<AlignmentScheduleProvider>();
    final notificationCenter = context.watch<NotificationCenterProvider>();
    final grouped = notificationCenter.groupedActiveNotifications();
    final queuedCount = notificationCenter.queuedNotifications.length;
    final hasNonCritical = notificationCenter.activeNotifications
        .any((n) => n.severity == NotificationSeverity.nonCritical);

    const double horizontalMargin = 16;
    const double verticalMargin = 16;
    final double topOffset = media.padding.top + 24;
    final double maxPopupWidth = (size.width * 0.92).clamp(300.0, 720.0);

    final completedCount = alignmentProvider.completedTodayCount;
    final totalCheckIns = alignmentProvider.totalCheckIns;
    final nextCheckIn = alignmentProvider.nextCheckInTime;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                color: Colors.black.withValues(alpha: .45),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: topOffset,
                right: horizontalMargin,
                left: horizontalMargin,
                bottom: verticalMargin,
              ),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxPopupWidth,
                  ),
                  child: FadeTransition(
                    opacity: curved ?? const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF202A3A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .14),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 18,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: size.height * 0.78,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (kDebugMode) ...[
                              SizedBox(
                                width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final notificationProvider = context.read<NotificationCenterProvider>();
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      await widget.onResetAlignment();
                                      await notificationProvider.clearAll();
                                      if (mounted) {
                                        scaffoldMessenger
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Reset for today (debug)'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: .25),
                                    ),
                                  ),
                                  child: const Text('Reset today (debug)'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _seedDemoNotifications(),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: .25),
                                    ),
                                  ),
                                  child: const Text(
                                    'Seed demo notifications (debug)',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 48),
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                        'Notification Center',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppPalette.onSurface,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints.tightFor(
                                      width: 36,
                                      height: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.close,
                                      color: AppPalette.subtext,
                                      size: 20,
                                    ),
                                    tooltip: 'Close',
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                  ),
                                ],
                              ),
                              const Divider(
                                height: 16,
                                color: Color(0xFF2E394F),
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      DateFormat.yMMMMEEEEd()
                                          .format(AppClock.now()),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: .72),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          ActionChip(
                                            label: const Text(
                                              'Clear non-critical',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            avatar: Icon(
                                              Icons.cleaning_services_outlined,
                                              size: 16,
                                              color: hasNonCritical
                                                  ? Colors.white
                                                  : Colors.white38,
                                            ),
                                            disabledColor: Colors.white
                                                .withValues(alpha: .08),
                                            onPressed: hasNonCritical
                                                ? () => notificationCenter
                                                    .clearNonCritical()
                                                : null,
                                          ),
                                          FilterChip(
                                            selected: notificationCenter
                                                .quietHoursEnabled,
                                            label: Text(
                                              notificationCenter
                                                      .quietHoursEnabled
                                                  ? 'Quiet hours: on'
                                                  : 'Quiet hours: off',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            onSelected: (value) =>
                                                notificationCenter
                                                    .toggleQuietHours(value),
                                          ),
                                          if (queuedCount > 0)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: .08),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: .14),
                                                ),
                                              ),
                                              child: Text(
                                                '$queuedCount queued',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: grouped.isEmpty
                                    ? const _NotificationEmptyState()
                                    : ListView.builder(
                                        physics:
                                            const BouncingScrollPhysics(),
                                        padding: EdgeInsets.zero,
                                        itemCount: notificationCenter
                                            .activeNotifications.length,
                                        itemBuilder: (context, index) {
                                          final item = notificationCenter
                                              .activeNotifications[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Dismissible(
                                              key: ValueKey(item.id),
                                              direction:
                                                  DismissDirection.horizontal,
                                              background: _DismissBackground(
                                                alignment:
                                                    Alignment.centerLeft,
                                                color: Colors.orange
                                                    .withValues(alpha: .25),
                                                icon: Icons.snooze_rounded,
                                                label: 'Snooze',
                                              ),
                                              secondaryBackground:
                                                  _DismissBackground(
                                                alignment:
                                                    Alignment.centerRight,
                                                color: Colors.red
                                                    .withValues(alpha: .25),
                                                icon: Icons.close_rounded,
                                                label: 'Dismiss',
                                              ),
                                              confirmDismiss:
                                                  (direction) async {
                                                if (direction ==
                                                    DismissDirection
                                                        .startToEnd) {
                                                  final duration =
                                                      await _pickSnoozeDuration(
                                                          item);
                                                  if (duration == null) {
                                                    return false;
                                                  }
                                                  await notificationCenter
                                                      .snooze(
                                                          item.id, duration);
                                                  return true;
                                                }
                                                await notificationCenter
                                                    .dismiss(item.id);
                                                return true;
                                              },
                                              child: Hero(
                                                tag: _notificationHeroTag(item),
                                                flightShuttleBuilder: (
                                                  context,
                                                  animation,
                                                  direction,
                                                  fromCtx,
                                                  toCtx,
                                                ) {
                                                  final Widget target =
                                                      direction ==
                                                              HeroFlightDirection
                                                                  .push
                                                          ? toCtx.widget
                                                          : fromCtx.widget;
                                                  return FadeTransition(
                                                    opacity: animation.drive(
                                                      CurveTween(
                                                        curve: Curves
                                                            .easeInOutCubic,
                                                      ),
                                                    ),
                                                    child: target,
                                                  );
                                                },
                                                child: _NotificationPill(
                                                  item: item,
                                                  accent: _moduleColor(
                                                    item.module,
                                                  ),
                                                  onActionTap: (action) =>
                                                      _handleAction(
                                                    action,
                                                    item,
                                                  ),
                                                  onTap:
                                                      _buildPillTapHandler(item),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              const SizedBox(height: 14),
                              const Divider(
                                height: 14,
                                color: Color(0xFF1F2430),
                              ),
                              const SizedBox(height: 8),
                              _AlignmentStrip(
                                completed: completedCount,
                                total: totalCheckIns,
                                nextCheckIn: nextCheckIn,
                                onAdvance: () => _handleAlignmentTap(),
                                onOpenFlow: _openAlignmentFlow,
                                onOpenSettings: _openScheduleSheet,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPill extends StatelessWidget {
  const _NotificationPill({
    required this.item,
    required this.accent,
    required this.onActionTap,
    this.onTap,
  });

  final NotificationItem item;
  final Color accent;
  final ValueChanged<NotificationAction> onActionTap;
  final VoidCallback? onTap;

  Color _severityColor() {
    switch (item.severity) {
      case NotificationSeverity.critical:
        return Colors.redAccent.withValues(alpha: 0.9);
      case NotificationSeverity.nonCritical:
        return Colors.white.withValues(alpha: 0.28);
    }
  }

  @override
  Widget build(BuildContext context) {
    final railColor = _severityColor();
    final metaLabel = item.meta ??
        DateFormat.jm().format(item.createdAt); // fallback to timestamp
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: railColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: railColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bolt,
                                          size: 12,
                                          color: accent,
                                        ),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          item.module.name.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.8,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (item.isBundled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        '${item.bundleCount}x',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.6,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppPalette.onSurface
                                      .withValues(alpha: .75),
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: AppPalette.onSurface
                                        .withValues(alpha: .54),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      metaLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppPalette.onSurface
                                            .withValues(alpha: .72),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (item.actions.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            direction: Axis.vertical,
                            alignment: WrapAlignment.center,
                            children: item.actions
                                .map(
                                  (action) => OutlinedButton(
                                    onPressed: () => onActionTap(action),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(80, 32),
                                      maximumSize: const Size(100, 34),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.24),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                    ),
                                    child: Text(
                                      action.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
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

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'No notifications yet',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AlignmentStrip extends StatelessWidget {
  const _AlignmentStrip({
    required this.completed,
    required this.total,
    required this.nextCheckIn,
    required this.onAdvance,
    required this.onOpenFlow,
    required this.onOpenSettings,
  });

  final int completed;
  final int total;
  final DateTime? nextCheckIn;
  final VoidCallback onAdvance;
  final VoidCallback onOpenFlow;
  final VoidCallback onOpenSettings;

  String _ctaLabel(int completed, int total) {
    if (completed <= 0) return 'Start';
    if (completed >= total) return 'Completed';
    if (completed >= total - 1) return 'Complete';
    return 'Log';
  }

  @override
  Widget build(BuildContext context) {
    final int clamped = completed.clamp(0, total);
    final int safeTotal = total <= 0 ? 1 : total;
    final double progress = clamped / safeTotal;
    final String cta = _ctaLabel(clamped, safeTotal);
    final String nextLabel = nextCheckIn != null
        ? 'Next check-in ${MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(nextCheckIn!),
            alwaysUse24HourFormat: false,
          )}'
        : 'All caught up';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily alignment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.onSurface.withValues(alpha: .6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: Colors.white70,
                ),
                tooltip: 'Alignment schedule',
                onPressed: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E88E5).withValues(alpha: .18),
                ),
                child: const Icon(
                  Icons.checklist_rtl,
                  color: Color(0xFF90CAF9),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: .08),
                        color: const Color(0xFF64B5F6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$clamped/$safeTotal complete',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.onSurface.withValues(alpha: .72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 90),
                child: FilledButton(
                  onPressed: onOpenFlow,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    cta,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlignmentScheduleSheet extends StatelessWidget {
  const _AlignmentScheduleSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlignmentScheduleProvider>();
    final times = provider.scheduledTimes;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Alignment schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final time = times[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Check-in ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final newTime = await showTimePicker(
                        context: context,
                        initialTime: time,
                      );
                      if (newTime != null) {
                        await provider.updateTimeAt(index, newTime);
                      }
                    },
                    child: Text(
                      _formatTime(context, time),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => Divider(
                color: Colors.white.withValues(alpha: .1),
              ),
              itemCount: times.length,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => provider.resetSchedule(),
                    child: const Text('Reset to defaults'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }
}

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

    for (final id in coreCategories) {
      provider.ensureCategoryExists(id);
    }

    final categories = provider.categories;
    final totalXp = provider.totalXp;
    final totalLevel = provider.totalLevel;
    final totalProgress = provider.totalLevelProgress;
    final totalXpForNext = provider.totalXpForNextLevel;

    final today = provider.selectedDateNotifier.value;

    final sheetHeight = (media.size.height * 0.38).clamp(260.0, 520.0);

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
                color: const Color(0xFF121826),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(
                  color: AppPalette.outline.withValues(alpha: .22),
                ),
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
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
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
                              horizontal: 8,
                              vertical: 6,
                            ),
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
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      children: [
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
                                Text(
                                  "Total XP: $totalXp",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  "Total Level: $totalLevel",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
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
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          color: const Color(0xFF182033),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "🗓 Today Debug",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        provider.debugCompleteAllOnDate(today);
                                      },
                                      child: const Text(
                                        "✅ Complete all for today",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orangeAccent,
                                      ),
                                      onPressed: () {
                                        provider.debugUncompleteAllOnDate(
                                          today,
                                        );
                                      },
                                      child: const Text(
                                        "↩︎ Uncomplete all",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Date: ${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ...categories.values.map((cat) {
                          const maxXp = LevelUtils.categoryMaxXp;
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
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
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
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              provider.resetEverything(
                                missionProvider: missionProvider,
                              );
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

/// Deferred calendar builder that shows placeholder first, then builds calendar
class _DeferredCalendarBuilder extends StatefulWidget {
  const _DeferredCalendarBuilder({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DeferredCalendarBuilder> createState() =>
      _DeferredCalendarBuilderState();
}

class _DeferredCalendarBuilderState extends State<_DeferredCalendarBuilder> {
  bool _buildCalendar = false;

  @override
  void initState() {
    super.initState();
    // Build calendar after first frame (16ms) - instant placeholder first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _buildCalendar = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_buildCalendar) {
      return FullscreenCalendarPage(
        initialDate: widget.initialDate,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
      );
    }

    // Lightweight placeholder - instant first frame
    return const Material(
      color: Color(0xFF12161C),
      child: SizedBox.expand(),
    );
  }
}
