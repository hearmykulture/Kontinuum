import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:kontinuum/ui/widgets/calendar/calendar_theme.dart';
import 'package:kontinuum/ui/widgets/calendar/year_timeline.dart';
import 'package:kontinuum/ui/widgets/calendar/extended_sidebar_panel.dart';
import 'package:kontinuum/ui/widgets/calendar/lane_clipper.dart';
import 'package:kontinuum/ui/screens/day_detail_page.dart' as day;

// Pages
import 'package:kontinuum/ui/screens/task_editor_page.dart' as tedit;
import 'package:kontinuum/ui/screens/reminder_time_picker_page_v2.dart' as rtp;
// Editor models (TaskEditorResult, TaskOptionsValue, ChecklistEntry, StatPick...)
import 'package:kontinuum/ui/screens/task_editor/models.dart' as tmodels;

/// Custom FAB location that lifts CenterFloat by [lift] pixels (no hit-test issues).
class _CenterFloatLifted extends FloatingActionButtonLocation {
  const _CenterFloatLifted(this.lift);
  final double lift;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final base =
        FloatingActionButtonLocation.centerFloat.getOffset(scaffoldGeometry);
    return Offset(base.dx, base.dy - lift);
  }
}

class FullscreenCalendarPage extends StatefulWidget {
  const FullscreenCalendarPage({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.accent = const Color(0xFF8A9199),
    this.railOverlayColor = kKontinuumBlue,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Color accent;
  final Color railOverlayColor;

  @override
  State<FullscreenCalendarPage> createState() => _FullscreenCalendarPageState();
}

class _FullscreenCalendarPageState extends State<FullscreenCalendarPage>
    with TickerProviderStateMixin {
  // Colors
  static const _sidebar = Color(0xFF000000);
  static const _laneBg = Color(0xFF12161C);

  // Layout
  static const double _sidebarW = 82;
  static const double _rowMinH = 88;
  static const double _hPad = 12;

  // Rail/panel anim
  static const Duration _animDur = Duration(milliseconds: 280);
  static const double _panelEps = 0.001;
  static const double _railPanelFrac = 0.94;
  static const double _dimMaxOpacity = 0.12;

  // Content reveal timing (blank blue -> fade/slide-up)
  static const Duration _contentFadeDelay = Duration(milliseconds: 600);
  static const Duration _contentFadeDur = Duration(milliseconds: 1400);
  static const double _enterLiftPx = 40.0;

  // FAB placement tweak (raise a little so the up-arrow fits below)
  static const double _fabLift = 44.0;

  // Jump-to-today button
  static const double _jumpSize = 44.0;

  late int _year;
  late DateTime _selected;
  String _activeOverlay = '';
  bool _yearTransitioning = false;

  // Upward + fade-in controller
  late final AnimationController _revealCtrl;
  late final Animation<double> _revealOpacity;
  late final Animation<double> _revealTranslate; // px down -> 0
  late final Animation<double> _revealScale; // subtle depth

  // Rail slide panel
  late final AnimationController _railCtrl;
  late final Animation<double> _railEase;
  bool _panelMounted = false;

  // Quick-Add drawer
  static const double _fabSize = 64;
  static const double _slotSize = 56;
  static const double _slotHit = 92;
  static const double _slotSpacing = 84;
  static const double _dragThreshold = 44;
  static const double _showAtT = 0.22;

  late final AnimationController _fabCtrl;
  late final Animation<double> _fabEase;
  bool _dragActive = false;
  int _hoverDir = 0; // -1 = left, 1 = right
  double _dragAccumX = 0.0;
  bool _pressLeft = false;
  bool _pressRight = false;

  bool get _fabOpen => _fabCtrl.value > 0.01;
  bool get _fabInteractive =>
      _dragActive || _fabCtrl.status != AnimationStatus.dismissed;

  // "Jump to Today" visibility
  bool _showJump = false;
  bool _jumpPointsUp = true;

  final GlobalKey<YearTimelineState> _timelineKey =
      GlobalKey<YearTimelineState>();

  String _spaced(String s) => s.split('').join(' ');
  String _overlayLabelFor(DateTime d) {
    final mon = DateFormat.MMM().format(d).toUpperCase();
    final yr = DateFormat.y().format(d);
    return '${_spaced(mon)} ${_spaced(yr)}';
  }

  // Newer Flutter: prefer withValues() over withOpacity / bit twiddling
  Color _withAlpha(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));

  double _phase(double t, double start, double end) {
    if (t <= start) return 0.0;
    if (t >= end) return 1.0;
    return (t - start) / (end - start);
  }

  double get _panelPhaseValue {
    final double eased = _phase(_railEase.value, 0.12, 1.0);
    return Curves.easeOutCubic.transform(eased);
  }

  bool get _isPanelOpen => _panelPhaseValue > _panelEps;

  // ---- Quick Add handlers ----
  void _toggleFab() => _fabOpen ? _fabCtrl.reverse() : _fabCtrl.forward();

  void _handlePanStart(DragStartDetails _) {
    _dragActive = true;
    _dragAccumX = 0.0;
    _hoverDir = 0;
    _fabCtrl.forward();
    setState(() {});
  }

  void _handlePanUpdate(DragUpdateDetails d) {
    _dragAccumX += d.delta.dx;
    final int dir = (_dragAccumX >= _dragThreshold)
        ? 1
        : (_dragAccumX <= -_dragThreshold)
            ? -1
            : 0;
    if (dir != _hoverDir) {
      _hoverDir = dir;
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  void _handlePanEnd([DragEndDetails? _]) {
    final int dir = _hoverDir;
    _dragActive = false;
    _hoverDir = 0;
    if (dir == -1) {
      _onTapReminder();
    } else if (dir == 1) {
      _onTapEvent();
    } else {
      _fabCtrl.reverse();
    }
  }

  Future<void> _closeFabAndPush(Widget page) async {
    _dragActive = false;
    _hoverDir = 0;
    _pressLeft = _pressRight = false;
    _fabCtrl.stop();
    _fabCtrl.value = 0.0;
    if (mounted) setState(() {});

    final dynamic res =
        await Navigator.of(context, rootNavigator: true).push<dynamic>(
      MaterialPageRoute<dynamic>(builder: (_) => page),
    );

    if (!mounted) return;

    if (res is tmodels.TaskEditorResult) {
      _saveTaskEditorResult(res);
    } else {
      setState(() {}); // editor cancelled or non-task page
    }
  }

  // ---- NEW: helper to push a custom Route (for leftward slide) ----
  Future<void> _closeFabAndPushRoute<T>(Route<T> route) async {
    _dragActive = false;
    _hoverDir = 0;
    _pressLeft = _pressRight = false;
    _fabCtrl.stop();
    _fabCtrl.value = 0.0;
    if (mounted) setState(() {});

    final res = await Navigator.of(context, rootNavigator: true).push<T>(route);

    if (!mounted) return;

    if (res is tmodels.TaskEditorResult) {
      _saveTaskEditorResult(res);
    } else {
      setState(() {});
    }
  }

  // ---- NEW: Route that slides the next page in from the LEFT ----
  Route<T> _slideFromLeftRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  void _onTapReminder() {
    HapticFeedback.mediumImpact();
    _closeFabAndPushRoute(
      _slideFromLeftRoute(rtp.EmptyReminderTimePage(day: _selected)),
    );
  }

  void _onTapEvent() {
    HapticFeedback.mediumImpact();
    // Seed the editor with the currently-selected calendar day
    _closeFabAndPush(
      tedit.TaskEditorPage(
        initialOptions: tmodels.TaskOptionsValue(date: _selected),
        autofocusTitle: true,
      ),
    );
  }

  /// Persist a TaskEditorResult by constructing a [day.Task] that matches your store.
  void _saveTaskEditorResult(tmodels.TaskEditorResult res) {
    // Choose a concrete day (store requires DateTime, not nullable).
    final DateTime placeOn = day.DayPlanStore.dateOnly(res.date ?? _selected);
    final DateTime? reminderAnchor = res.date;
    final DateTime? deadline = res.deadline;

    final task = day.Task(
      id: day.DayPlanStore.genId(),
      title: res.title,
      repeatOnCompletion: res.repeatOnCompletion,
      checklist: res.checklist
          .map((tmodels.ChecklistEntry c) =>
          day.TaskChecklistEntry(text: c.text, done: c.done))
          .toList(),
      due: (res.hasDeadline && deadline != null)
          ? day.DayPlanStore.dateOnly(deadline)
          : null,
      remindAt: (res.hasReminder && reminderAnchor != null)
          ? DateTime(
              reminderAnchor.year,
              reminderAnchor.month,
              reminderAnchor.day,
              9,
              0,
            )
          : null,
      stats: res.stats, // multi-stat payload supported by your Task
    );

    day.DayPlanStore.I.addTask(placeOn, task);

    // Keep UI focused on the day we wrote to
    _selectFromPanel(placeOn);
    _timelineKey.currentState?.scrollToDate(placeOn);
  }

  Widget _buildCenterFab() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleFab,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Container(
        height: _fabSize,
        width: _fabSize,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2F3A),
          borderRadius: BorderRadius.circular(_fabSize / 2),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              spreadRadius: 2,
              offset: Offset(0, 8),
              color: Color(0x66000000),
            ),
          ],
          border: Border.all(
            color: _withAlpha(widget.accent, _fabOpen ? 0.7 : 0.3),
            width: _fabOpen ? 2 : 1,
          ),
        ),
        child: AnimatedBuilder(
          animation: _fabEase,
          builder: (_, __) {
            final rot = (math.pi / 4) * _fabCtrl.value;
            return Transform.rotate(
              angle: rot,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidePillsOverlay(EdgeInsets viewPad, {required bool panelOpen}) {
    if (panelOpen) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !(_fabOpen || _dragActive),
      child: AnimatedBuilder(
        animation: _fabEase,
        builder: (context, _) {
          final double t = _fabEase.value;
          if (!(_fabOpen || _dragActive) && t == 0.0) {
            return const SizedBox.shrink();
          }

          final double leftDx = -_slotSpacing * t;
          final double rightDx = _slotSpacing * t;
          final double sideScale = 0.80 + 0.20 * _fabCtrl.value;
          final bool showSides = t >= _showAtT;

          final double menuH = _fabSize + 20;
          // Keep overlay row aligned with lifted FAB.
          final double menuBottom = 20 + viewPad.bottom + _fabLift;

          BoxDecoration pill(bool active) => BoxDecoration(
                color: active
                    ? _withAlpha(widget.accent, 0.20)
                    : const Color(0x331C1F28),
                borderRadius: BorderRadius.circular(_slotSize / 2),
                border: Border.all(
                  color: active
                      ? _withAlpha(widget.accent, 0.85)
                      : const Color(0x66FFFFFF),
                  width: active ? 2 : 1,
                ),
                boxShadow: [
                  if (active)
                    const BoxShadow(
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: Offset(0, 6),
                      color: Color(0x55000000),
                    ),
                ],
              );

          Widget slotButton({
            required bool isLeft,
            required IconData icon,
            required VoidCallback onPressed,
            required bool hover,
            required double dx,
            required Alignment align,
          }) {
            final bool pressed = isLeft ? _pressLeft : _pressRight;
            final bool active = hover || pressed;
            return Transform.translate(
              offset: Offset(dx, 0),
              transformHitTests: true,
              child: Transform.scale(
                scale: sideScale * (active ? 1.10 : 1.0),
                alignment: align,
                transformHitTests: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() {
                    if (isLeft) {
                      _pressLeft = true;
                    } else {
                      _pressRight = true;
                    }
                  }),
                  onTapCancel: () => setState(() {
                    if (isLeft) {
                      _pressLeft = false;
                    } else {
                      _pressRight = false;
                    }
                  }),
                  onTapUp: (_) {
                    setState(() {
                      if (isLeft) {
                        _pressLeft = false;
                      } else {
                        _pressRight = false;
                      }
                    });
                    onPressed();
                  },
                  child: SizedBox(
                    width: _slotHit,
                    height: _slotHit,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 110),
                        curve: Curves.easeOut,
                        height: _slotSize,
                        width: _slotSize,
                        decoration: pill(active),
                        alignment: Alignment.center,
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              // Tap anywhere to close quick add
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_fabOpen && !_dragActive) _fabCtrl.reverse();
                  },
                ),
              ),
              if (showSides)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: menuBottom,
                  child: Center(
                    child: SizedBox(
                      width: _slotSpacing * 2 + _fabSize + 40,
                      height: menuH,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          slotButton(
                            isLeft: true,
                            icon: Icons.alarm_add_rounded,
                            onPressed: _onTapReminder,
                            hover: _hoverDir == -1,
                            dx: leftDx,
                            align: Alignment.centerRight,
                          ),
                          slotButton(
                            isLeft: false,
                            icon: Icons.event_available_rounded,
                            onPressed: _onTapEvent,
                            hover: _hoverDir == 1,
                            dx: rightDx,
                            align: Alignment.centerLeft,
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
    );
  }

  // ---------------------- CALENDAR RAIL / TIMELINE ----------------------
  @override
  void initState() {
    super.initState();

    _selected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _year = _selected.year;
    _activeOverlay =
        _overlayLabelFor(DateTime(_selected.year, _selected.month, 1));

    // Rail/panel anim
    _railCtrl = AnimationController(vsync: this, duration: _animDur);
    _railEase = CurvedAnimation(
      parent: _railCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _railCtrl.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        if (!_panelMounted) setState(() => _panelMounted = true);
      } else if (status == AnimationStatus.dismissed) {
        if (_panelMounted) setState(() => _panelMounted = false);
      }
    });

    // Quick add
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _fabEase = CurvedAnimation(
      parent: _fabCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    // Reveal controller (fade + slide up + slight scale)
    _revealCtrl = AnimationController(vsync: this, duration: _contentFadeDur);
    _revealOpacity = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeInOutCubic,
    );
    _revealTranslate = Tween<double>(begin: _enterLiftPx, end: 0.0).animate(
      CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic),
    );
    _revealScale = Tween<double>(begin: 0.985, end: 1.0).animate(
      CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic),
    );

    // Show blank blue immediately, then reveal with an "up" motion.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(_contentFadeDelay);
      if (!mounted) return;
      _revealCtrl.forward();
      // Scroll the timeline after first frame of reveal so layout is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _timelineKey.currentState?.scrollToDate(_selected);
      });
    });
  }

  @override
  void dispose() {
    _railCtrl.dispose();
    _fabCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  bool _inRange(DateTime d) {
    final a = DateTime(
        widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final b = DateTime(
        widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(a) && !x.isAfter(b);
  }

  void _selectFromPanel(DateTime d) {
    if (!_inRange(d)) return;
    setState(() => _selected = d);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timelineKey.currentState?.scrollToDate(d);
    });
  }

  Future<void> _openDayFromLane(DateTime d) async {
    if (!_inRange(d)) return;
    setState(() => _selected = d);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => day.DayDetailPage(day: d)),
    );
    if (mounted) setState(() {});
  }

  void _onMonthOverlay(String currentLabel, String nextLabel, double t) {
    final active = (t < 0.5) ? currentLabel : nextLabel;
    if (active != _activeOverlay) setState(() => _activeOverlay = active);
  }

  void _handleTimelineEdge(TimelineEdge edge) {
    if (_yearTransitioning) return;
    switch (edge) {
      case TimelineEdge.start:
        _shiftYear(-1, jumpToStart: false);
        break;
      case TimelineEdge.end:
        _shiftYear(1, jumpToStart: true);
        break;
    }
  }

  void _shiftYear(int delta, {required bool jumpToStart}) {
    final int targetYear = _year + delta;
    final DateTime desired =
        jumpToStart ? DateTime(targetYear, 1, 1) : DateTime(targetYear, 12, 31);
    if (!_inRange(desired)) return;

    setState(() {
      _yearTransitioning = true;
      _year = targetYear;
      _selected = desired;
      _activeOverlay =
          _overlayLabelFor(DateTime(_selected.year, _selected.month, 1));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _timelineKey.currentState?.scrollToDate(desired);
      if (mounted) {
        setState(() => _yearTransitioning = false);
      } else {
        _yearTransitioning = false;
      }
    });
  }

  void _toggleRail() {
    if (_railCtrl.status == AnimationStatus.dismissed ||
        _railCtrl.status == AnimationStatus.reverse) {
      _railCtrl.forward();
    } else {
      _railCtrl.reverse();
    }
  }

  void _closeRail() => _railCtrl.reverse();

  // Rough visibility test for today's row using scroll metrics
  void _onAnyScroll(ScrollMetrics m) {
    final now = DateTime.now();
    if (now.year != _year) {
      final bool pointUp = _year > now.year;
      if (!_showJump || _jumpPointsUp != pointUp) {
        setState(() {
          _showJump = true;
          _jumpPointsUp = pointUp;
        });
      }
      return;
    }

    // approximate row height (min row + divider)
    const double rowH = _rowMinH + 1.0;
    final startOfYear = DateTime(_year, 1, 1);
    final idx = DateTime(_year, now.month, now.day)
        .difference(startOfYear)
        .inDays
        .clamp(0, 365);
    final todayTop = idx * rowH;
    final todayBottom = todayTop + rowH;

    final visibleTop = m.pixels;
    final visibleBottom = visibleTop + m.viewportDimension;

    // Small margin so it appears a bit before/after it leaves.
    const double margin = 24.0;
    final bool above = todayBottom < visibleTop + margin;
    final bool below = todayTop > visibleBottom - margin;
    final bool offscreen = above || below;
    final bool pointUp = above; // need to scroll upward to reach today

    if (offscreen != _showJump || (offscreen && pointUp != _jumpPointsUp)) {
      setState(() {
        _showJump = offscreen;
        if (offscreen) _jumpPointsUp = pointUp;
      });
    }
  }

  Widget _buildCloseButton(EdgeInsets pad) {
    return Positioned(
      right: 10,
      top: pad.top + 6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x4D1C1F28),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;

    final double laneMinLogical = math.max(w * 0.10, 84.0);
    final double laneMin = _sidebarW + laneMinLogical;

    final double remainingAfterRail = math.max(0.0, w - _sidebarW);
    final double availForPanel = math.max(0.0, w - laneMin);
    final double panelMax =
        math.min(remainingAfterRail * _railPanelFrac, availForPanel);

    // Always build; we animate opacity/translate instead of conditionally building.
    final Widget laneChild = NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical) {
          _onAnyScroll(n.metrics);
        }
        return false;
      },
      child: YearTimeline(
        key: _timelineKey,
        year: _year,
        selected: _selected,
        accent: widget.accent,
        sidebarW: _sidebarW,
        rowMinH: _rowMinH,
        hPad: _hPad,
        railColor: _sidebar,
        laneColor: _laneBg,
        railProgress: 0.0,
        onPick: _openDayFromLane,
        onMonthOverlay: _onMonthOverlay,
        onEdgeReached: _handleTimelineEdge,
      ),
    );

    final bool buildPanel = _panelMounted;
    final Widget panelChild = buildPanel
        ? RepaintBoundary(
            child: ExtendedSidebarPanel(
              monthAnchor: DateTime(_selected.year, _selected.month, 1),
              selected: _selected,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onPick: _selectFromPanel,
            ),
          )
        : const SizedBox.shrink();

    final merged = Listenable.merge([_railEase, _fabEase, _revealCtrl]);

    return Scaffold(
      backgroundColor: _laneBg,

      // FAB (now lifted via custom FAB location so taps work reliably)
      floatingActionButton: AnimatedBuilder(
        animation: Listenable.merge([_revealCtrl, _railEase]),
        builder: (_, __) {
          final bool panelOpen = _isPanelOpen;
          final double opacity = panelOpen ? 0.0 : _revealOpacity.value;
          final bool ignoring =
              panelOpen || _revealCtrl.isDismissed || _fabInteractive;
          return Opacity(
            opacity: opacity,
            child: IgnorePointer(
              ignoring: ignoring,
              child: _buildCenterFab(),
            ),
          );
        },
      ),
      floatingActionButtonLocation: _CenterFloatLifted(_fabLift),

      body: AnimatedBuilder(
        animation: merged,
        child: laneChild,
        builder: (_, child) {
          // Rail math
          final p = _railEase.value;
          final fadePhase = _phase(p, 0.0, 0.40);
          final fadeAmount = Curves.easeInCubic.transform(fadePhase);
          final clipPhase = Curves.easeOutCubic.transform(_phase(p, 0.0, 0.70));
          final leftInset = (_sidebarW * clipPhase).roundToDouble();
          final panelPhase =
              Curves.easeOutCubic.transform(_phase(p, 0.12, 1.0));
          final panelWidth = panelMax * panelPhase;
          final expandedRailW = _sidebarW + panelWidth;
          final dimOpacity = _dimMaxOpacity * _phase(p, 0.22, 1.0);
          final double panelLeft = _sidebarW * (1.0 - panelPhase);
          final bool panelOpen = panelPhase > _panelEps;

          final pad = MediaQuery.of(context).padding;

          // Upward + fade wrapper
          final enteringTransform = Transform.translate(
            offset: Offset(0, _revealTranslate.value),
            child: Transform.scale(
              scale: _revealScale.value,
              alignment: Alignment.center,
              child: Opacity(
                opacity: _revealOpacity.value,
                child: Stack(
                  children: [
                    // Rail slab + EXTENDED PANEL
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: expandedRailW,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                              child: ColoredBox(color: _sidebar)),
                          if (buildPanel)
                            Positioned.fill(
                              left: panelLeft,
                              child: TickerMode(
                                enabled: panelOpen,
                                child: IgnorePointer(
                                  ignoring: !panelOpen,
                                  child: Opacity(
                                    opacity: panelPhase,
                                    child: panelChild,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Timeline lane
                    AbsorbPointer(
                      absorbing: _fabInteractive,
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: true,
                        child: Padding(
                          padding: EdgeInsets.only(left: panelWidth),
                          child: ClipRect(
                            clipper: LaneClipper(leftInset),
                            child: RepaintBoundary(
                              child: Material(
                                color: Colors.transparent,
                                child: Stack(
                                  children: [
                                    const Positioned.fill(
                                        child: ColoredBox(color: _laneBg)),
                                    Positioned.fill(
                                        child:
                                            child ?? const SizedBox.shrink()),
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: _sidebarW,
                                      child: IgnorePointer(
                                        ignoring: true,
                                        child: Opacity(
                                          opacity: fadeAmount,
                                          child: const ColoredBox(
                                              color: Colors.black),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Base rail tap zone
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _sidebarW,
                      child: IgnorePointer(
                        ignoring: panelOpen || _fabInteractive,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleRail,
                        ),
                      ),
                    ),

                    // Backdrop dim (right side)
                    Positioned.fill(
                      left: expandedRailW,
                      child: IgnorePointer(
                        ignoring: dimOpacity == 0.0 || _fabInteractive,
                        child: Opacity(
                          opacity: dimOpacity,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _closeRail,
                            child: const ColoredBox(color: Colors.black),
                          ),
                        ),
                      ),
                    ),

                    // Rotated month/year label
                    Positioned(
                      left: 6,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        ignoring: true,
                        child: Opacity(
                          opacity: (1.0 - fadeAmount) * _revealOpacity.value,
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                switchInCurve: Curves.easeOutQuad,
                                switchOutCurve: Curves.easeInQuad,
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(opacity: anim, child: child),
                                child: Text(
                                  _activeOverlay,
                                  key: ValueKey(_activeOverlay),
                                  style: TextStyle(
                                    color: _withAlpha(
                                        widget.railOverlayColor, 0.95),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ---- Jump-to-today button (centered, BELOW the raised +) ----
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: pad.bottom + 8,
                      child: IgnorePointer(
                        ignoring: !_showJump || _fabInteractive,
                        child: AnimatedSlide(
                          offset:
                              _showJump ? Offset.zero : const Offset(0, 0.15),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _showJump ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  final now = DateTime.now();
                                  _timelineKey.currentState?.scrollToDate(
                                    DateTime(now.year, now.month, now.day),
                                  );
                                },
                                child: Container(
                                  height: _jumpSize,
                                  width: _jumpSize,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.28),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x80000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _jumpPointsUp
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Side pills overlay (raised with +)
                    _buildSidePillsOverlay(pad, panelOpen: panelOpen),

                    // Close button
                    _buildCloseButton(pad),
                  ],
                ),
              ),
            ),
          );

          // Render blank blue under the entering transform (in case opacity < 1)
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: _laneBg),
              enteringTransform,
            ],
          );
        },
      ),
    );
  }
}
