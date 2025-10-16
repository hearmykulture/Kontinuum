import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Haptics
import 'package:intl/intl.dart';

import 'package:kontinuum/ui/widgets/calendar/calendar_theme.dart';
import 'package:kontinuum/ui/widgets/calendar/year_timeline.dart';
import 'package:kontinuum/ui/widgets/calendar/extended_sidebar_panel.dart';
import 'package:kontinuum/ui/widgets/calendar/lane_clipper.dart';
import 'package:kontinuum/ui/screens/day_detail_page.dart' as day;

// Pages
import 'package:kontinuum/ui/screens/task_editor_page.dart'
    as tedit; // adjust if needed
import 'package:kontinuum/ui/screens/reminder_time_picker_page_v2.dart'
    as rtp; // adjust if needed

/// Full-screen calendar page with left rail & expandable panel.
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
  static const _bg = Color(0xFF000000);
  static const _sidebar = Color(0xFF000000);
  static const _laneBg = Color(0xFF12161C);

  // Layout
  static const double _sidebarW = 82;
  static const double _rowMinH = 88;
  static const double _hPad = 12;

  // Animations
  static const Duration _animDur = Duration(milliseconds: 280);
  static const double _panelEps = 0.001; // treat ~0 as closed
  static const double _railPanelFrac = 0.94;
  static const double _dimMaxOpacity = 0.12;

  late final int _year;
  late DateTime _selected;
  String _activeOverlay = '';
  bool _showTimeline = false;

  late final AnimationController _railCtrl;
  late final Animation<double> _railEase;

  // When false and rail is closed, we don't even build the panel subtree.
  bool _panelMounted = false;

  final GlobalKey<YearTimelineState> _timelineKey =
      GlobalKey<YearTimelineState>();

  String _spaced(String s) => s.split('').join(' ');
  String _overlayLabelFor(DateTime d) {
    final mon = DateFormat.MMM().format(d).toUpperCase();
    final yr = DateFormat.y().format(d);
    return '${_spaced(mon)} ${_spaced(yr)}';
  }

  // Avoid deprecated withOpacity() warnings.
  Color _withOpacityCompat(Color c, double o) {
    final a = (o.clamp(0.0, 1.0) * 255).round();
    return Color((a << 24) | (c.value & 0x00FFFFFF));
  }

  double _phase(double t, double start, double end) {
    if (t <= start) return 0.0;
    if (t >= end) return 1.0;
    return (t - start) / (end - start);
  }

  // ---------------------------------------------------------------------------
  // Bottom Center Quick-Add (+) with horizontal drawer + drag-select
  // ---------------------------------------------------------------------------
  static const double _fabSize = 64;
  static const double _slotSize = 56;
  static const double _slotSpacing = 96; // distance from center to each side
  static const double _dragThreshold = 44;

  late final AnimationController _fabCtrl;
  late final Animation<double> _fabEase; // eased 0..1 (may overshoot slightly)

  bool _dragActive = false; // during hold+drag gesture
  int _hoverDir = 0; // -1 = left (reminder), 1 = right (event), 0 = none
  double _dragAccumX = 0.0;

  bool get _fabOpen => _fabCtrl.value > 0.01;

  // Consider the drawer interactive as soon as we're not fully closed.
  bool get _fabInteractive =>
      _dragActive || _fabCtrl.status != AnimationStatus.dismissed;

  Future<void> _openAfterFabClose(Widget page) async {
    if (_fabCtrl.status != AnimationStatus.dismissed) {
      try {
        await _fabCtrl.reverse();
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _toggleFab() {
    if (_fabOpen) {
      _fabCtrl.reverse();
    } else {
      _fabCtrl.forward();
    }
  }

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
      _selectReminder();
    } else if (dir == 1) {
      _selectEvent();
    } else {
      _fabCtrl.reverse(); // no selection → close
    }
  }

  // ===== OPEN PAGES =====
  Future<void> _selectReminder() async {
    HapticFeedback.mediumImpact();
    await _openAfterFabClose(
      rtp.EmptyReminderTimePage(day: _selected), // seed with selected day
    );
    if (!mounted) return;
    setState(() {}); // refresh timeline after saving reminders
  }

  Future<void> _selectEvent() async {
    HapticFeedback.mediumImpact();
    await _openAfterFabClose(const tedit.TaskEditorPage());
    if (!mounted) return;
    setState(() {}); // refresh if events influence timeline
  }

  Widget _buildFabMenu(EdgeInsets viewPad) {
    return AnimatedBuilder(
      animation: _fabEase,
      builder: (context, _) {
        final double t = _fabEase.value; // already eased 0..1 (may overshoot)
        final double leftDx = -_slotSpacing * t;
        final double rightDx = _slotSpacing * t;
        final double sideScale = 0.7 + 0.3 * _fabCtrl.value;
        final bool showSides = t > 0.001;

        final bool leftHover = (_hoverDir == -1);
        final bool rightHover = (_hoverDir == 1);

        BoxDecoration pill([bool hover = false]) => BoxDecoration(
          color: hover
              ? _withOpacityCompat(widget.accent, 0.20)
              : const Color(0x331C1F28),
          borderRadius: BorderRadius.circular(_slotSize / 2),
          border: Border.all(
            color: hover
                ? _withOpacityCompat(widget.accent, 0.80)
                : const Color(0x22FFFFFF),
            width: hover ? 2 : 1,
          ),
          boxShadow: [
            if (hover)
              const BoxShadow(
                blurRadius: 18,
                spreadRadius: 1,
                offset: Offset(0, 6),
                color: Color(0x55000000),
              ),
          ],
        );

        Widget sideButton({
          required IconData icon,
          required VoidCallback onTap,
          required bool hover,
          required double dx,
          required Alignment align,
        }) {
          return IgnorePointer(
            // Allow tapping as soon as the drawer is not fully closed, or while dragging.
            ignoring: !_fabInteractive,
            child: Opacity(
              opacity: showSides ? 1.0 : 0.0,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(
                  scale: sideScale * (hover ? 1.08 : 1.0),
                  alignment: align,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: onTap,
                    child: Container(
                      height: _slotSize,
                      width: _slotSize,
                      decoration: pill(hover),
                      alignment: Alignment.center,
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Center (+) with tap + drag
        final Widget centerBtn = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleFab, // TAP → open/close drawer
          onPanStart: _handlePanStart, // HOLD+DRAG → directional select
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
                color: _withOpacityCompat(widget.accent, _fabOpen ? 0.7 : 0.3),
                width: _fabOpen ? 2 : 1,
              ),
            ),
            child: AnimatedBuilder(
              animation: _fabEase,
              builder: (_, __) {
                final rot = (math.pi / 4) * _fabCtrl.value; // 0..45°
                return Transform.rotate(
                  angle: rot,
                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                );
              },
            ),
          ),
        );

        // LAYER ORDER:
        // 1) Transparent barrier (only while interactive) to swallow taps
        //    so the calendar underneath can't steal them.
        // 2) The actual bottom-center menu with icons and the (+) button.
        return Stack(
          children: [
            // 1) Transparent barrier above the calendar, below the icons
            if (_fabInteractive)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // tap outside menu -> close drawer
                    if (_fabOpen && !_dragActive) _fabCtrl.reverse();
                  },
                ),
              ),

            // 2) The menu itself
            Positioned(
              left: 0,
              right: 0,
              bottom: 20 + viewPad.bottom,
              child: IgnorePointer(
                ignoring: false,
                child: Center(
                  child: SizedBox(
                    width: _slotSpacing * 2 + _fabSize + 40, // tap slop area
                    height: _fabSize + 20,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Left (Reminder)
                        sideButton(
                          icon: Icons.alarm_add_rounded,
                          onTap: _selectReminder,
                          hover: leftHover,
                          dx: leftDx,
                          align: Alignment.centerRight,
                        ),
                        // Right (Event)
                        sideButton(
                          icon: Icons.event_available_rounded,
                          onTap: _selectEvent,
                          hover: rightHover,
                          dx: rightDx,
                          align: Alignment.centerLeft,
                        ),
                        // Center (+)
                        centerBtn,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    _activeOverlay = _overlayLabelFor(
      DateTime(_selected.year, _selected.month, 1),
    );

    _railCtrl = AnimationController(vsync: this, duration: _animDur);
    _railEase = CurvedAnimation(
      parent: _railCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _fabEase = CurvedAnimation(
      parent: _fabCtrl,
      curve: Curves.easeOutBack, // overshoot ok
      reverseCurve: Curves.easeInCubic,
    );

    _railCtrl.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        if (!_panelMounted) setState(() => _panelMounted = true);
      } else if (status == AnimationStatus.dismissed) {
        if (_panelMounted) setState(() => _panelMounted = false);
      }
    });

    // Reveal timeline after route transition completes; then scroll to selected.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = ModalRoute.of(context);
      final anim = route?.animation;

      Future<void> revealAndScroll() async {
        if (!mounted) return;
        setState(() => _showTimeline = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _timelineKey.currentState?.scrollToDate(_selected);
        });
      }

      if (anim == null || anim.status == AnimationStatus.completed) {
        revealAndScroll();
      } else {
        void listener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            anim.removeStatusListener(listener);
            revealAndScroll();
          }
        }

        anim.addStatusListener(listener);
      }
    });
  }

  @override
  void dispose() {
    _railCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  bool _inRange(DateTime d) {
    final a = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final b = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(a) && !x.isAfter(b);
  }

  void _selectFromPanel(DateTime d) {
    if (!_inRange(d)) return;
    setState(() => _selected = d);

    // Make sure the lane scrolls to the newly selected day.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timelineKey.currentState?.scrollToDate(d);
    });
  }

  Future<void> _openDayFromLane(DateTime d) async {
    if (!_inRange(d)) return;
    setState(() => _selected = d);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => day.DayDetailPage(day: d)));
    if (mounted) setState(() {}); // refresh pills after returning
  }

  void _onMonthOverlay(String currentLabel, String nextLabel, double t) {
    final active = (t < 0.5) ? currentLabel : nextLabel;
    if (active != _activeOverlay) setState(() => _activeOverlay = active);
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final topPad = media.padding.top;

    // Keep a sliver of the lane visible at all times.
    final double laneMinLogical = math.max(w * 0.10, 84.0);
    final double laneMin = _sidebarW + laneMinLogical;

    // Max panel width allowed (static per build, not per tick).
    final double remainingAfterRail = math.max(0.0, w - _sidebarW);
    final double availForPanel = math.max(0.0, w - laneMin);
    final double panelMax = math.min(
      remainingAfterRail * _railPanelFrac,
      availForPanel,
    );

    // ---- PREBUILD HEAVY CHILDREN (no per-tick rebuilds) ----

    final Widget laneChild = _showTimeline
        ? YearTimeline(
            key: _timelineKey,
            year: _year,
            selected: _selected,
            accent: widget.accent,
            sidebarW: _sidebarW,
            rowMinH: _rowMinH,
            hPad: _hPad,
            railColor: _sidebar,
            laneColor: _laneBg,
            railProgress: 0.0, // keep pure during rail anim
            onPick: _openDayFromLane,
            onMonthOverlay: _onMonthOverlay,
          )
        : const SizedBox.shrink();

    final bool buildPanel = _panelMounted;
    final Widget panelChild = buildPanel
        ? RepaintBoundary(
            child: ExtendedSidebarPanel(
              // Keep month view anchored to selected month
              monthAnchor: DateTime(_selected.year, _selected.month, 1),
              selected: _selected,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onPick: _selectFromPanel,
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: _railEase,
        // Keep the timeline as the child to avoid rebuilding it each tick.
        child: laneChild,
        builder: (_, child) {
          final p = _railEase.value; // 0..1

          final fadePhase = _phase(p, 0.0, 0.40);
          final fadeAmount = Curves.easeInCubic.transform(fadePhase);

          final clipPhase = Curves.easeOutCubic.transform(_phase(p, 0.0, 0.70));
          final leftInset = (_sidebarW * clipPhase).roundToDouble();

          final panelPhase = Curves.easeOutCubic.transform(
            _phase(p, 0.12, 1.0),
          );
          final panelWidth = panelMax * panelPhase;
          final expandedRailW = _sidebarW + panelWidth;

          final dimOpacity = _dimMaxOpacity * _phase(p, 0.22, 1.0);

          // Slide the extended panel over the rail as it opens.
          final double panelLeft = _sidebarW * (1.0 - panelPhase);
          final bool panelOpen = panelPhase > _panelEps;

          return Stack(
            children: [
              // Rail slab + EXTENDED PANEL (panelChild prebuilt outside)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: expandedRailW,
                child: Stack(
                  children: [
                    const Positioned.fill(child: ColoredBox(color: _sidebar)),
                    // Only anim wrappers rebuild; panelChild itself does not.
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

              // Timeline lane (pushed and clipped)
              MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: Hero(
                  tag: kCalendarHeroTag,
                  transitionOnUserGestures: true,
                  createRectTween: (a, b) =>
                      MaterialRectArcTween(begin: a, end: b),
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
                                child: ColoredBox(color: _laneBg),
                              ),
                              // Heavy lane list (AnimatedBuilder.child)
                              Positioned.fill(
                                child: child ?? const SizedBox.shrink(),
                              ),
                              // Lightweight fade overlay over the rail portion only.
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
                                      color: Colors.black,
                                    ),
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

              // *** TAP ZONE ON THE BASE RAIL (above lane) ***
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _sidebarW,
                child: IgnorePointer(
                  // Enable only when the panel is CLOSED; otherwise panel handles taps.
                  ignoring: panelOpen,
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
                  ignoring: dimOpacity == 0.0,
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

              // Rotated month/year label over the rail.
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: _showTimeline ? (1.0 - fadeAmount) : 0.0,
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
                              color: _withOpacityCompat(
                                widget.railOverlayColor,
                                0.95,
                              ),
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

              // Close
              Positioned(
                right: 8,
                top: topPad + 8,
                child: const Material(
                  color: Colors.transparent,
                  child: CloseButton(color: Colors.white),
                ),
              ),

              // Bottom-center Quick Add (+) menu (now with a transparent barrier)
              _buildFabMenu(MediaQuery.of(context).padding),
            ],
          );
        },
      ),
    );
  }
}
