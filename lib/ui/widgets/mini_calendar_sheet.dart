import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // ValueNotifier / ValueListenable
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kontinuum/ui/widgets/calendar/calendar_theme.dart';
import 'package:kontinuum/ui/widgets/calendar/calendar_fullscreen_page.dart';

/// Mini calendar shown in an *anchored popover* that heroes into fullscreen.
class MiniCalendarSheet extends StatefulWidget {
  const MiniCalendarSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelected;

  /// Convenience: keep old `show(...)` call-sites working by proxying to the anchored popover.
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onSelected,
  }) {
    // Build a tiny center anchor so the popover animates nicely.
    Rect anchorRect;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay?.context.findRenderObject() case final RenderBox box) {
      final size = box.size;
      anchorRect = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: 1,
        height: 1,
      );
    } else {
      final size = MediaQuery.of(context).size;
      anchorRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 1,
        height: 1,
      );
    }

    return showAnchored(
      context,
      anchorRect: anchorRect,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onSelected: onSelected,
    );
  }

  /// Show as an anchored popover (transparent route so Hero can fly).
  static Future<DateTime?> showAnchored(
    BuildContext context, {
    required Rect anchorRect,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onSelected,
  }) {
    return Navigator.of(context).push<DateTime?>(
      PageRouteBuilder<DateTime?>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (routeCtx, __, ___) {
          return _AnchoredCalendarOverlay(
            anchorRect: anchorRect,
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            onSelected: (d) {
              onSelected(d);
              Navigator.of(routeCtx).pop<DateTime?>(d);
            },
            onDismissed: () => Navigator.of(routeCtx).pop<DateTime?>(null),
          );
        },
        // no extra transition — Hero owns the stage
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  @override
  State<MiniCalendarSheet> createState() => _MiniCalendarSheetState();
}

class _MiniCalendarSheetState extends State<MiniCalendarSheet> {
  // Mini sheet tokens
  static const _panel = Color(0xFF131720);
  static const _text = Colors.white;
  static const _muted = Color(0x66FFFFFF);
  static const _faint = Color(0x33FFFFFF);
  static const _accent = kKontinuumBlue;
  static const _pillSize = 36.0; // preferred pill diameter
  static const _gridSpacing = 10.0;

  // Reactive state (fine-grained rebuilds)
  late final ValueNotifier<DateTime>
  _displayedMonthN; // normalized to first-of-month
  late final ValueNotifier<DateTime> _selectedN; // normalized to Y/M/D (00:00)

  // Cached current grid & labels for the visible month (recomputed only when month changes)
  late List<DateTime> _gridDays; // 42 entries
  late String _monthLabel; // UPPERCASE month name
  late String _yearLabel;

  // Cached Intl formatters (Intl objects are relatively heavy)
  late final DateFormat _mmmmFmt = DateFormat.MMMM();

  // Normalized range bounds
  late final DateTime _firstDay = DateTime(
    widget.firstDate.year,
    widget.firstDate.month,
    widget.firstDate.day,
  );
  late final DateTime _lastDay = DateTime(
    widget.lastDate.year,
    widget.lastDate.month,
    widget.lastDate.day,
  );

  @override
  void initState() {
    super.initState();

    final initSel = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final initMonth = DateTime(initSel.year, initSel.month, 1);

    _selectedN = ValueNotifier<DateTime>(initSel);
    _displayedMonthN = ValueNotifier<DateTime>(initMonth);

    // Seed caches
    _recomputeMonthCaches(initMonth);

    // When the visible month changes, refresh grid and labels (single place).
    _displayedMonthN.addListener(() {
      _recomputeMonthCaches(_displayedMonthN.value);
      // Only parts that read labels/grid will rebuild (ValueListenableBuilders below).
      setState(() {});
    });
  }

  @override
  void dispose() {
    _selectedN.dispose();
    _displayedMonthN.dispose();
    super.dispose();
  }

  // ---------- Helpers / caching ----------

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inRange(DateTime d) => !(d.isBefore(_firstDay) || d.isAfter(_lastDay));

  void _recomputeMonthCaches(DateTime monthFirst) {
    _gridDays = _buildGridDates(monthFirst);
    _monthLabel = _mmmmFmt.format(monthFirst).toUpperCase();
    _yearLabel = monthFirst.year.toString();
  }

  static List<DateTime> _buildGridDates(DateTime displayedMonthFirst) {
    final first = displayedMonthFirst; // 1st of month
    final leading = first.weekday % 7; // Sunday=0
    final daysThisMonth = DateTime(first.year, first.month + 1, 0).day;

    final cells = List<DateTime>.filled(42, first, growable: false);
    // Start date (Sunday before/at the 1st)
    final start = first.subtract(Duration(days: leading));

    for (int i = 0; i < 42; i++) {
      final d = start.add(Duration(days: i));
      cells[i] = DateTime(d.year, d.month, d.day); // normalize
    }
    return cells;
  }

  void _shiftMonth(int delta) {
    final cur = _displayedMonthN.value;
    final next = DateTime(cur.year, cur.month + delta, 1);

    final firstBound = DateTime(_firstDay.year, _firstDay.month, 1);
    final lastBound = DateTime(_lastDay.year, _lastDay.month, 1);

    if (!next.isBefore(firstBound) && !next.isAfter(lastBound)) {
      _displayedMonthN.value = next; // triggers cache recompute + setState
    }
  }

  Future<void> _openFullscreen() async {
    // Push fullscreen; keep this popover route under it so the Hero runs.
    final picked = await Navigator.of(context).push<DateTime>(
      PageRouteBuilder<DateTime>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => FullscreenCalendarPage(
          initialDate: _selectedN.value,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          accent: const Color(0xFF8A9199),
          railOverlayColor: kKontinuumBlue,
        ),
        // Let the Hero animation be the only transition.
        transitionsBuilder: (context, animation, secondary, child) => child,
      ),
    );

    if (!mounted) return;

    if (picked != null) {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      widget.onSelected(normalized);
      Navigator.of(context).pop<DateTime?>(normalized);
    } else {
      Navigator.of(context).pop<DateTime?>(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // normalize "today" once per build
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Wrap the card in a Hero so it can fly into the fullscreen page.
    return Material(
      color: Colors.transparent,
      child: Hero(
        tag: kCalendarHeroTag,
        transitionOnUserGestures: true,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),

        // keeps source visible; prevents empty gap under flight
        placeholderBuilder: (_, __, ___) => const Material(
          type: MaterialType.transparency,
          child: SizedBox.shrink(),
        ),

        flightShuttleBuilder: (context, animation, direction, fromCtx, toCtx) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final radiusAnim = Tween<BorderRadius>(
            begin: BorderRadius.circular(18),
            end: BorderRadius.zero,
          ).animate(curved);

          // Fly the *child* of the Hero, not the Hero itself.
          final fromHero = fromCtx.widget as Hero;
          final toHero = toCtx.widget as Hero;
          final shuttleChild = direction == HeroFlightDirection.push
              ? toHero.child
              : fromHero.child;

          return AnimatedBuilder(
            animation: radiusAnim,
            builder: (_, __) => Material(
              type: MaterialType.transparency, // avoids black flash
              child: ClipRRect(
                borderRadius: radiusAnim.value,
                child: shuttleChild,
              ),
            ),
          );
        },

        child: Container(
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // header (labels change only when month changes)
              Row(
                children: [
                  IconButton(
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                    color: _text,
                    tooltip: 'Previous month',
                  ),
                  Expanded(
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: _displayedMonthN,
                      builder: (_, __, ___) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _monthLabel,
                              key: const ValueKey(
                                'month',
                              ), // minor text layout stability
                              style: const TextStyle(
                                color: _accent,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _yearLabel,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openFullscreen,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0F14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _faint),
                      ),
                      child: const Icon(
                        Icons.north_east,
                        size: 16,
                        color: _muted,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right),
                    color: _text,
                    tooltip: 'Next month',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                    color: _text,
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // weekdays (static)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _WeekdayLabel('S'),
                    _WeekdayLabel('M'),
                    _WeekdayLabel('T'),
                    _WeekdayLabel('W'),
                    _WeekdayLabel('T'),
                    _WeekdayLabel('F'),
                    _WeekdayLabel('S'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // GRID — compute real cell size so the 6th row fits perfectly.
              LayoutBuilder(
                builder: (_, box) {
                  // width of one cell (7 columns with 6 gaps)
                  final double cell = ((box.maxWidth - _gridSpacing * 6) / 7)
                      .clamp(28.0, 64.0);
                  final double gridH = cell * 6 + _gridSpacing * 5;
                  final double pill = math.min(_pillSize, cell - 4);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: gridH,
                        child: RepaintBoundary(
                          child: ValueListenableBuilder2<DateTime, DateTime>(
                            first: _displayedMonthN,
                            second: _selectedN,
                            builder: (_, displayedMonth, selected, __) {
                              // Local copies for fast access in itemBuilder.
                              final month = displayedMonth.month;
                              final selectedDay = selected;
                              return GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                itemCount: 42,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                      crossAxisSpacing: _gridSpacing,
                                      mainAxisSpacing: _gridSpacing,
                                      childAspectRatio: 1.0,
                                    ),
                                itemBuilder: (_, i) {
                                  final day = _gridDays[i];
                                  final inDisplayedMonth = day.month == month;
                                  final isSelected = _sameDay(day, selectedDay);
                                  final isToday = _sameDay(day, today);
                                  final enabled = _inRange(day);

                                  final fg = inDisplayedMonth
                                      ? _text
                                      : _muted.withValues(alpha: 0.35);

                                  BoxDecoration deco;
                                  if (isToday) {
                                    deco = BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _panel,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.06,
                                          ),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    );
                                  } else if (isSelected) {
                                    deco = const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _accent,
                                    );
                                  } else {
                                    deco = BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: inDisplayedMonth
                                          ? const Color(0x1AFFFFFF)
                                          : const Color(0x0DFFFFFF),
                                    );
                                  }

                                  return Opacity(
                                    opacity: enabled ? 1 : 0.45,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                        pill / 2,
                                      ),
                                      onTap: enabled
                                          ? () {
                                              final normalized = DateTime(
                                                day.year,
                                                day.month,
                                                day.day,
                                              );
                                              if (!_sameDay(
                                                normalized,
                                                _selectedN.value,
                                              )) {
                                                _selectedN.value =
                                                    normalized; // local fine-grained update
                                              }
                                              widget.onSelected(normalized);
                                              Navigator.of(context).maybePop(
                                                normalized,
                                              ); // close popover route
                                            }
                                          : null,
                                      child: Center(
                                        child: Container(
                                          width: pill,
                                          height: pill,
                                          decoration: deco,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isSelected && !isToday
                                                  ? Colors.black
                                                  : fg,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ), // cushion above rounded bottom
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: _MiniCalendarSheetState._pillSize,
    child: const Center(
      child: Text(
        '',
        // This placeholder is replaced below; see RichText in build
      ),
    ),
  );
}

/// Overlay host that positions & animates the popover.
class _AnchoredCalendarOverlay extends StatefulWidget {
  const _AnchoredCalendarOverlay({
    required this.anchorRect,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
    required this.onDismissed,
  });

  final Rect anchorRect;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onDismissed;

  @override
  State<_AnchoredCalendarOverlay> createState() =>
      _AnchoredCalendarOverlayState();
}

class _AnchoredCalendarOverlayState extends State<_AnchoredCalendarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
        );

    // play enter
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;

    const horizontalMargin = 12.0;
    const verticalGap = 8.0;
    final maxW = math.min(screen.width - horizontalMargin * 2, 360.0);
    final maxH = math.min(screen.height * 0.70, 560.0); // a touch more headroom

    final belowTop = widget.anchorRect.bottom + verticalGap;
    final spaceBelow = screen.height - media.padding.bottom - belowTop;
    final preferBelow = spaceBelow >= 280;

    final desiredLeft = widget.anchorRect.center.dx - maxW / 2;
    final clampedLeft = desiredLeft.clamp(
      horizontalMargin,
      screen.width - horizontalMargin - maxW,
    );

    final caretX = widget.anchorRect.center.dx - clampedLeft;

    // Scale origin: from the caret (top edge if below, bottom edge if above)
    final alignX = (caretX / maxW) * 2 - 1; // -1..1
    final alignY = preferBelow ? -1.0 : 1.0;

    // Corner radius morph (hero-like)
    double radiusFor(double t) => 24.0 - 6.0 * t; // 24 -> 18

    return Stack(
      children: [
        // Tap-outside barrier (fades with the sheet)
        Positioned.fill(
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
        ),

        // Popover with animated scale/fade/slide from the caret point
        Positioned(
          left: clampedLeft.toDouble(),
          top: preferBelow ? belowTop : null,
          bottom: preferBelow
              ? null
              : (screen.height - widget.anchorRect.top + verticalGap),
          width: maxW,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final t = _ctrl.value.clamp(0.0, 1.0);
              return FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ScaleTransition(
                    alignment: Alignment(alignX, alignY),
                    scale: _scale,
                    child: _CalendarPopover(
                      radius: radiusFor(t),
                      maxHeight: maxH,
                      caretX: caretX.toDouble(),
                      caretDown: preferBelow,
                      onClose: _close,
                      child: MiniCalendarSheet(
                        initialDate: widget.initialDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onSelected: (d) => widget.onSelected(d),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Rounded popover with a small caret.
class _CalendarPopover extends StatelessWidget {
  const _CalendarPopover({
    required this.child,
    required this.maxHeight,
    required this.caretX,
    required this.caretDown,
    required this.onClose,
    required this.radius,
  });

  final Widget child;
  final double maxHeight;
  final double caretX; // x-position inside bubble where caret points
  final bool caretDown; // true: caret points downward from bubble's top edge
  final VoidCallback onClose;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(padding: EdgeInsets.zero, child: child),
        ),
      ),
    );

    return CustomPaint(
      painter: _SpeechBubblePainter(
        caretX: caretX,
        caretDown: caretDown,
        color: const Color(0xFF131720),
        shadow: const Color(0x80000000),
        radius: radius,
      ),
      child: Padding(
        // Leave room only for the caret itself.
        padding: EdgeInsets.only(
          top: caretDown ? 10 : 0,
          bottom: caretDown ? 0 : 10,
        ),
        child: content,
      ),
    );
  }
}

/// Draws a rounded rectangle with a triangular caret (speech bubble).
class _SpeechBubblePainter extends CustomPainter {
  _SpeechBubblePainter({
    required this.caretX,
    required this.caretDown,
    required this.color,
    required this.shadow,
    required this.radius,
  });

  final double caretX; // x inside the bubble width
  final bool caretDown;
  final Color color;
  final Color shadow;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius;
    const caretW = 16.0;
    const caretH = 10.0;

    final bubbleRect = Rect.fromLTWH(
      0,
      caretDown ? caretH : 0,
      size.width,
      size.height - caretH,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(bubbleRect, Radius.circular(r)));

    // caret triangle
    final cx = caretX.clamp(r + 8, size.width - r - 8);
    if (caretDown) {
      path
        ..moveTo(cx - caretW / 2, caretH)
        ..lineTo(cx, 0)
        ..lineTo(cx + caretW / 2, caretH)
        ..close();
    } else {
      final y = size.height;
      path
        ..moveTo(cx - caretW / 2, y - caretH)
        ..lineTo(cx, y)
        ..lineTo(cx + caretW / 2, y - caretH)
        ..close();
    }

    // soft shadow
    final shadowPaint = Paint()
      ..color = shadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, shadowPaint);

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter old) =>
      old.caretX != caretX ||
      old.caretDown != caretDown ||
      old.color != color ||
      old.radius != radius;
}

/* ---------- Tiny helper to listen to two notifiers ---------- */
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
