// lib/ui/workout/workout_dashboard_widget.dart
// Fully self-contained header: WorkoutYearProgressBar + RoutineCarousel.
// RoutineCarousel owns the OVERLAY scrollbar and the divider, with toggles.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // ValueNotifier / ValueListenable
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/ui/theme/app_colors.dart';
import 'package:kontinuum/ui/widgets/calendar/calendar_theme.dart';
import 'package:kontinuum/ui/widgets/calendar/calendar_fullscreen_page.dart';

// routines & routing
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/ui/workout/workout_routine_editor_page.dart';

typedef ProgressForDay = double Function(DateTime day);

class WorkoutDashboardWidget extends StatelessWidget {
  const WorkoutDashboardWidget({
    super.key,
    required this.selectedDate,
    required this.getProgressForDay,
    required this.onDateSelected,

    // selection plumbing
    required this.selectedRoutineId,
    required this.onRoutineSelected,

    // Appearance
    this.accentColor = AppColors.accentBlue,

    // Optional rest-day awareness
    this.isRestDayFor,

    /// Optional one-off rest override predicate.
    /// If provided, days flagged here are also treated as rest in the ring
    /// and mini calendar, without changing the recurring schedule.
    this.isOneOffRestFor,

    // Carousel options
    this.carouselTwoRows = false,
    this.carouselColumns = 4,
    this.carouselFixedItemSize,
    this.carouselCardColor = const Color(0xFF0A0E11),
    this.carouselPadding = const EdgeInsets.fromLTRB(16, 0, 16, 8),

    /// Slight negative offset to tuck the carousel up under the progress bar.
    this.carouselUnderlap = -18,

    /// Tight vertical padding around cards (doesn’t affect divider).
    this.carouselTopBottomPad = 8,

    /// Pixels ABOVE the divider where the overlay scrollbar sits.
    /// Smaller = lower (closer to the divider). Zero sits right on top.
    this.carouselScrollbarBottomInset = 4,

    /// Divider color under the carousel.
    this.dividerColor = const Color(0x1FFFFFFF),

    /// Visibility toggles for reuse
    this.enableScrollbar = true,
    this.showDivider = true,
  });

  // Progress bar inputs
  final DateTime selectedDate;
  final ProgressForDay getProgressForDay;
  final ValueChanged<DateTime> onDateSelected;
  final Color accentColor;

  /// Optional *scheduled* rest-day predicate. If provided:
  ///  - Rest days are treated as 100% complete in the ring.
  ///  - Rest-day rings get a light-blue color.
  ///  - A small supportive pill appears under the date for the selected day.
  final bool Function(DateTime day)? isRestDayFor;

  /// Optional one-off "Skip workout" rest override predicate.
  /// Dashboards treat these as rest days too, but copy can distinguish them
  /// from scheduled rest (see the selected-day pill).
  final bool Function(DateTime day)? isOneOffRestFor;

  // selection plumbing
  final String? selectedRoutineId;
  final ValueChanged<String> onRoutineSelected;

  // Carousel inputs
  final bool carouselTwoRows;
  final int carouselColumns;
  final double? carouselFixedItemSize;
  final Color carouselCardColor;
  final EdgeInsetsGeometry carouselPadding;
  final double carouselUnderlap;

  // Spacing / overlay scrollbar placement
  final double carouselTopBottomPad;
  final double carouselScrollbarBottomInset;

  // Divider
  final Color dividerColor;

  // Visibility
  final bool enableScrollbar;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WorkoutYearProgressBar(
          selectedDate: selectedDate,
          getProgressForDay: getProgressForDay,
          onDateSelected: onDateSelected,
          accentColor: accentColor,
          isRestDayFor: isRestDayFor,
          isOneOffRestFor: isOneOffRestFor,
        ),
        Transform.translate(
          offset: Offset(0, carouselUnderlap),
          child: RoutineCarousel(
            twoRows: carouselTwoRows,
            cardColor: carouselCardColor,
            padding: carouselPadding,
            columns: carouselColumns,
            fixedItemSize: carouselFixedItemSize,
            topBottomPad: carouselTopBottomPad,
            scrollbarBottomInset: carouselScrollbarBottomInset,
            dividerColor: dividerColor,
            enableScrollbar: enableScrollbar,
            showDivider: showDivider,

            // selection plumbing
            selectedRoutineId: selectedRoutineId,
            onSelected: onRoutineSelected,
          ),
        ),
      ],
    );
  }
}

/// Horizontal grid of routine cards with a trailing Create tile.
/// Draws an OVERLAY scrollbar inside the same height and a divider beneath.
/// Scrollbar appears only when content is actually wider than the viewport.
class RoutineCarousel extends StatefulWidget {
  const RoutineCarousel({
    super.key,
    required this.twoRows,
    this.cardColor = const Color(0xFF0A0E11),
    this.padding,
    this.columns = 4,
    this.fixedItemSize,

    // spacing & overlay scrollbar
    this.topBottomPad = 8,
    this.scrollbarBottomInset = 4,
    this.dividerColor = const Color(0x1FFFFFFF),

    // visibility knobs
    this.enableScrollbar = true,
    this.showDivider = true,

    // selection plumbing
    required this.selectedRoutineId,
    required this.onSelected,
  });

  final bool twoRows;
  final Color cardColor;
  final EdgeInsetsGeometry? padding;
  final int columns;
  final double? fixedItemSize;

  /// Vertical padding around the tiles (not the scrollbar).
  final double topBottomPad;

  /// Pixels ABOVE the divider to place the overlay scrollbar.
  final double scrollbarBottomInset;

  final Color dividerColor;

  final bool enableScrollbar;
  final bool showDivider;

  // selection plumbing
  final String? selectedRoutineId;
  final ValueChanged<String> onSelected;

  @override
  State<RoutineCarousel> createState() => _RoutineCarouselState();
}

class _RoutineCarouselState extends State<RoutineCarousel> {
  static const double _hPad = 16;
  static const double _spacing = 12;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routines = context.watch<WorkoutProvider>().routines;
    final rows = widget.twoRows ? 2 : 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;

        // Merge external padding if provided.
        final EdgeInsetsGeometry baseGeom =
            widget.padding ?? const EdgeInsets.symmetric(horizontal: _hPad);
        final EdgeInsets b = baseGeom.resolve(Directionality.of(context));

        // Tight vertical padding around the grid only.
        final EdgeInsets resolvedPad = EdgeInsets.fromLTRB(
          b.left,
          (b.top == 0 ? widget.topBottomPad : b.top),
          b.right,
          (b.bottom == 0 ? widget.topBottomPad : b.bottom),
        );

        // Compute tile size & columns visible at once.
        final int cols = widget.fixedItemSize == null
            ? widget.columns.clamp(1, 12)
            : ((maxW - (resolvedPad.left + resolvedPad.right) + _spacing) /
                    ((widget.fixedItemSize!) + _spacing))
                .floor()
                .clamp(1, 12);

        final double computedItemSize = widget.fixedItemSize ??
            ((maxW -
                    (resolvedPad.left + resolvedPad.right) -
                    (_spacing * (cols - 1))) /
                cols);

        // Height for square tiles + spacing between rows
        final double contentHeight =
            (computedItemSize * rows) + (_spacing * (rows - 1));

        final totalTiles = routines.length + 1;

        // ---- Determine if horizontal scrolling is actually needed ----------
        final int totalColumns = (totalTiles / rows).ceil();
        final double contentWidth = (totalColumns * computedItemSize) +
            (_spacing * (totalColumns - 1)) +
            resolvedPad.left +
            resolvedPad.right;
        final double viewportWidth = maxW;
        final bool isScrollable = contentWidth > viewportWidth + 0.5;
        // --------------------------------------------------------------------

        final grid = GridView.builder(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          padding: resolvedPad,
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: rows,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: computedItemSize,
          ),
          itemCount: totalTiles,
          itemBuilder: (context, index) {
            if (index < routines.length) {
              final Routine r = routines[index];
              return _RoutineCard(
                size: computedItemSize,
                routine: r,
                cardColor: widget.cardColor,
                isSelected: widget.selectedRoutineId == r.id,
                onTap: () => widget.onSelected(r.id), // select card
                onEdit: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      transitionDuration: const Duration(milliseconds: 420),
                      reverseTransitionDuration:
                          const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) =>
                          WorkoutRoutineEditorPage(routineId: r.id),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(
                        opacity: CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
              );
            }
            return _CreateRoutineTile(
              size: computedItemSize,
              cardColor: widget.cardColor,
            );
          },
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed height for cards only; overlay bar doesn't request space.
            SizedBox(
              height: contentHeight + (widget.topBottomPad * 2),
              child: Stack(
                children: [
                  Positioned.fill(child: grid),
                  if (widget.enableScrollbar && isScrollable)
                    Positioned(
                      left: resolvedPad.left,
                      right: resolvedPad.right,
                      bottom: widget.scrollbarBottomInset + 4,
                      child: _OverlayHScrollbar(
                        controller: _scrollCtrl,
                        thickness: 4,
                        radius: 8,
                        minThumbWidth: 28,
                        thumbColor: Colors.white.withValues(alpha: 0.7),
                        trackColor: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.showDivider)
              Transform.translate(
                offset: const Offset(0, 0),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: widget.dividerColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CreateRoutineTile extends StatelessWidget {
  const _CreateRoutineTile({required this.size, required this.cardColor});
  final double size;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder<void>(
              transitionDuration: const Duration(milliseconds: 420),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) => const WorkoutRoutineEditorPage(),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ),
                child: child,
              ),
            ),
          );
        },
        child: const _CreateCenteredBody(),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.size,
    required this.routine,
    required this.cardColor,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
  });

  final double size;
  final Routine routine;
  final Color cardColor;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  static const _borderRadius = 16.0;
  static const _selectedColor = Color(0xFF448AFF);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        clipBehavior: Clip.antiAlias, // keep ink & border clean
        child: Stack(
          children: [
            // Main card content (tap selects)
            InkWell(
              borderRadius: BorderRadius.circular(_borderRadius),
              onTap: onTap,
              child: Container(
                // Draw selection border OVER content to avoid any layout change.
                foregroundDecoration: isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(_borderRadius),
                        border: Border.all(color: _selectedColor, width: 2),
                      )
                    : null,
                child: const _CardPadding(
                  childBuilder: _CardBody.buildFromParent,
                ),
              ),
            ),

            // Pencil icon overlay in top-right corner (only for selected card)
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    // Use the dedicated edit callback (opens the correct routine)
                    onTap: onEdit ?? onTap,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white70,
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

/// Keeps the same padding/layout regardless of selection state.
class _CardPadding extends StatelessWidget {
  const _CardPadding({required this.childBuilder});
  final Widget Function(BuildContext) childBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: childBuilder(context),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    this.title,
    this.subtitle,
    this.icon,
  });

  final String? title;
  final String? subtitle;
  final IconData? icon;

  // Helper so _RoutineCard can reuse fixed layout without passing values twice.
  static Widget buildFromParent(BuildContext context) {
    final parent = context.findAncestorWidgetOfExactType<_RoutineCard>()!;
    final r = parent.routine;
    return _CardBody(
      title: r.name,
      subtitle:
          '${r.workoutIds.length} workout${r.workoutIds.length == 1 ? '' : 's'}',
      icon: Icons.fitness_center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed icon area (no shifting)
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child:
                  Icon(icon ?? Icons.folder, color: Colors.white70, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (title != null)
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          )
        else
          const Text(
            'Create',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1, // lock to one line to prevent wrap on selection
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          )
        else
          const SizedBox(height: 6),
      ],
    );
  }
}

class _CreateCenteredBody extends StatelessWidget {
  const _CreateCenteredBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: Colors.white70, size: 22),
          SizedBox(height: 8),
          Text('Create', style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Lightweight, paint-only horizontal overlay scrollbar.
class _OverlayHScrollbar extends StatelessWidget {
  const _OverlayHScrollbar({
    required this.controller,
    this.thickness = 4,
    this.radius = 8,
    this.minThumbWidth = 24,
    this.thumbColor = Colors.white,
    this.trackColor = const Color(0x33FFFFFF),
  });

  final ScrollController controller;
  final double thickness;
  final double radius;
  final double minThumbWidth;
  final Color thumbColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final has = controller.hasClients;
            final pos = has ? controller.position : null;
            final viewport = has ? pos!.viewportDimension : 1.0;
            final max = has ? pos!.maxScrollExtent : 0.0;
            final min = has ? pos!.minScrollExtent : 0.0;
            final total = viewport + (max - min);
            final trackW = c.maxWidth;

            double thumbW = total > 0
                ? math.max((viewport / total) * trackW, minThumbWidth)
                : trackW;
            thumbW = thumbW.clamp(minThumbWidth, trackW);

            final progress =
                (max <= 0) ? 0.0 : (pos!.pixels / max).clamp(0.0, 1.0);
            final thumbLeft = (trackW - thumbW) * progress;

            return SizedBox(
              width: trackW,
              height: thickness,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Track
                    Container(color: trackColor),
                    // Thumb
                    Positioned(
                      left: thumbLeft,
                      width: thumbW,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: thumbColor,
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Workout-specific copy of the YearProgressBar logic.
// This is isolated so changes here don't affect the Progress screen widget.
// ───────────────────────────────────────────────────────────────────────────

class WorkoutYearProgressBar extends StatefulWidget {
  const WorkoutYearProgressBar({
    super.key,
    required this.selectedDate,
    required this.getProgressForDay,
    required this.onDateSelected,
    this.firstDateCap,
    this.lastDateCap,
    this.accentColor = AppColors.accentBlue,
    this.isRestDayFor,
    this.isOneOffRestFor,
  });

  final DateTime selectedDate; // local date
  final double Function(DateTime) getProgressForDay;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? firstDateCap;
  final DateTime? lastDateCap;
  final Color accentColor;

  /// Optional *scheduled* rest-day predicate.
  final bool Function(DateTime day)? isRestDayFor;

  /// Optional one-off rest override predicate (e.g., "Skip workout today").
  final bool Function(DateTime day)? isOneOffRestFor;

  @override
  State<WorkoutYearProgressBar> createState() => _WorkoutYearProgressBarState();
}

class _WorkoutYearProgressBarState extends State<WorkoutYearProgressBar> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  static const double itemWidth = 60;
  bool _userInitiatedSelection = false;

  // Gradient end (light green)
  static const Color _kProgressGreen = Color(0xFF8EB69B);

  // Rest-day ring gradient (light blue)
  static const Color _kRestDayBlueStart = Color(0xFFB3E5FC);
  static const Color _kRestDayBlueEnd = Color(0xFF4FC3F7);

  // Sizes
  static const double _kProgressSize = 48;
  static const double _kProgressStroke = 5;
  static const double _kRingWidth = 1.6;
  static const double _kRingGap = 2.0;

  // Noticeable fade + subtle scale on selection ring
  static const Duration _ringFade = Duration(milliseconds: 420);
  static const double _kRingScaleMin = 0.90;

  final GlobalKey _dateTapKey = GlobalKey();

  final Map<int, double> _prevProgressByDayIndex = {};
  int? _cachedYear;
  Timer? _throttle;

  int _dayIndexUtc(DateTime d) {
    final a = DateTime.utc(d.year, 1, 1);
    final b = DateTime.utc(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

  int _daysInYearUtc(int year) {
    final a = DateTime.utc(year, 1, 1);
    final b = DateTime.utc(year + 1, 1, 1);
    return b.difference(a).inDays;
  }

  Rect _globalRectFor(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return const Rect.fromLTWH(0, 0, 0, 0);
    final box = ctx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter(widget.selectedDate, jump: true);
    });
    _scrollController.addListener(() {
      if (_throttle != null) return;
      _throttle = Timer(const Duration(milliseconds: 16), () {
        _throttle = null;
        if (mounted) setState(() => _scrollOffset = _scrollController.offset);
      });
    });
  }

  @override
  void didUpdateWidget(covariant WorkoutYearProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear progress cache when the progress function or year might have changed
    if (widget.getProgressForDay != oldWidget.getProgressForDay ||
        widget.selectedDate.year != oldWidget.selectedDate.year) {
      _prevProgressByDayIndex.clear();
      _cachedYear = null;
    }

    // When parent changes selectedDate (e.g., from logs or the dashboard),
    // keep the circles centered on that date.
    if (!_isSameDay(widget.selectedDate, oldWidget.selectedDate)) {
      final bool animateSelection = _userInitiatedSelection;
      _userInitiatedSelection = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToCenter(
            widget.selectedDate,
            jump: !animateSelection,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _throttle?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCenter(DateTime date, {bool jump = false}) {
    final index = _dayIndexUtc(date);
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (index * itemWidth) - (screenWidth / 2 - itemWidth / 2);

    void go() {
      final maxExtent = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final clamped = offset.clamp(0.0, maxExtent);
      if (jump) {
        _scrollController.jumpTo(clamped);
      } else {
        _scrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    if (_scrollController.hasClients) {
      go();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
    }
  }

  double _calculateScale(double itemCenter, double screenCenter) {
    final distance = (itemCenter - screenCenter).abs();
    const maxDistance = 200.0;
    final t = (distance / maxDistance).clamp(0.0, 1.0);
    return 1.0 - (0.3 * t);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openMiniCalendar() async {
    final now = DateTime.now();
    final first = widget.firstDateCap ?? DateTime(now.year - 5, 1, 1);
    final last = widget.lastDateCap ?? DateTime(now.year + 5, 12, 31);

    final anchor = _globalRectFor(_dateTapKey);

    await _WorkoutMiniCalendarSheet.showAnchored(
      context,
      anchorRect: anchor,
      initialDate: widget.selectedDate,
      firstDate: first,
      lastDate: last,
      isRestDayFor: widget.isRestDayFor,
      isOneOffRestFor: widget.isOneOffRestFor,
      onSelected: (picked) {
        final normalized = DateTime(picked.year, picked.month, picked.day);
        _userInitiatedSelection = true;
        widget.onDateSelected(normalized);
        _scrollToCenter(normalized);
      },
    );
  }

  String _weekday3(int w) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(w - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;
    final startOfYearLocal = DateTime(selectedDate.year, 1, 1);
    final daysInYear = _daysInYearUtc(selectedDate.year);
    final screenWidth = MediaQuery.of(context).size.width;
    final nowLocal = DateTime.now();

    final double ringSize = _kProgressSize + 2 * _kRingWidth + 2 * _kRingGap;

    if (_cachedYear != selectedDate.year) {
      _prevProgressByDayIndex.clear();
      _cachedYear = selectedDate.year;
    }

    final bool selectedScheduledRest =
        widget.isRestDayFor?.call(widget.selectedDate) ?? false;
    final bool selectedOneOffRest =
        widget.isOneOffRestFor?.call(widget.selectedDate) ?? false;
    final bool selectedIsRest = selectedScheduledRest || selectedOneOffRest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date label
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
          child: Center(
            child: InkWell(
              key: _dateTapKey,
              onTap: _openMiniCalendar,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  DateFormat.yMMMMEEEEd().format(selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),

        SizedBox(
          height: 100,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemExtent: itemWidth,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            addSemanticIndexes: false,
            itemCount: daysInYear,
            itemBuilder: (context, index) {
              final day = startOfYearLocal.add(Duration(days: index));
              final isToday = _isSameDay(day, nowLocal);
              final isSelected = _isSameDay(day, selectedDate);

              final bool scheduledRest =
                  widget.isRestDayFor?.call(day) ?? false;
              final bool oneOffRest =
                  widget.isOneOffRestFor?.call(day) ?? false;
              final bool isRestDay = scheduledRest || oneOffRest;

              // Base progress from parent, but force rest days (scheduled or override) to 100%.
              double currentProgress =
                  widget.getProgressForDay(day).clamp(0.0, 1.0);
              if (isRestDay && currentProgress < 1.0) {
                currentProgress = 1.0;
              }

              final prev = _prevProgressByDayIndex[index] ?? currentProgress;
              _prevProgressByDayIndex[index] = currentProgress;

              final itemStart = index * itemWidth;
              final itemCenter = itemStart + itemWidth / 2;
              final screenCenter = _scrollOffset + screenWidth / 2;
              final scale = _calculateScale(itemCenter, screenCenter);

              Color dayTextColor = Colors.white;
              if (isToday) dayTextColor = Colors.purpleAccent;
              if (isSelected) dayTextColor = widget.accentColor;

              // Rest day ring uses a light blue color instead of the usual gradient.
              final Color ringStart =
                  isRestDay ? _kRestDayBlueStart : Colors.white;
              final Color ringEnd =
                  isRestDay ? _kRestDayBlueEnd : _kProgressGreen;

              return GestureDetector(
                onTap: () {
                  _userInitiatedSelection = true;
                  widget.onDateSelected(day);
                  _scrollToCenter(day);
                },
                child: SizedBox(
                  width: itemWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _weekday3(day.weekday),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: RepaintBoundary(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Gradient / solid progress ring
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: prev,
                                  end: currentProgress,
                                ),
                                duration: const Duration(milliseconds: 550),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return CustomPaint(
                                    size: const Size.square(_kProgressSize),
                                    painter: _GradientProgressPainter(
                                      progress: value.clamp(0.0, 1.0),
                                      strokeWidth: _kProgressStroke,
                                      trackColor: Colors.grey.shade800,
                                      startColor: ringStart,
                                      endColor: ringEnd,
                                      startAngle: -math.pi / 2, // top
                                    ),
                                  );
                                },
                              ),

                              // OUTER selection ring — fade + scale
                              IgnorePointer(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 0.0,
                                    end: isSelected ? 1.0 : 0.0,
                                  ),
                                  duration: _ringFade,
                                  curve: Curves.easeInOutCubic,
                                  builder: (context, t, child) {
                                    final double s = _kRingScaleMin +
                                        (1.0 - _kRingScaleMin) * t;
                                    return Opacity(
                                      opacity: t,
                                      child: Transform.scale(
                                        scale: s,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: ringSize,
                                    height: ringSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.accentColor,
                                        width: _kRingWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Day number
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: dayTextColor,
                                ),
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
          ),
        ),
      ],
    );
  }
}

/// Paints a circular track and a gradient progress arc (white → light green
/// by default, or solid light-blue when used for rest days).
class _GradientProgressPainter extends CustomPainter {
  _GradientProgressPainter({
    required this.progress, // 0..1
    required this.strokeWidth,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
    required this.startAngle,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color startColor;
  final Color endColor;
  final double startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    // Progress
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final sweep = 2 * math.pi * clamped;

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweep,
      colors: [startColor, endColor],
      stops: const [0.0, 1.0],
    );

    final paint = Paint()
      ..shader =
          gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, startAngle, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientProgressPainter old) {
    return old.progress != progress ||
        old.strokeWidth != strokeWidth ||
        old.trackColor != trackColor ||
        old.startColor != startColor ||
        old.endColor != endColor ||
        old.startAngle != startAngle;
  }
}

// ---------------------------------------------------------------------------
// Workout-specific copy of MiniCalendarSheet + anchored popover.
// This is visually 1:1 with the global mini calendar, but scoped here so
// workout tweaks won't affect the Progress screen.
// ---------------------------------------------------------------------------

class _WorkoutMiniCalendarSheet extends StatefulWidget {
  const _WorkoutMiniCalendarSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
    this.isRestDayFor,
    this.isOneOffRestFor,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelected;

  /// Optional rest-day predicate to lightly highlight scheduled rest days
  /// inside the anchored mini calendar grid.
  final bool Function(DateTime day)? isRestDayFor;

  /// Optional one-off rest override predicate; also highlighted as rest.
  final bool Function(DateTime day)? isOneOffRestFor;

  /// Show as an anchored popover (transparent route so Hero can fly).
  static Future<DateTime?> showAnchored(
    BuildContext context, {
    required Rect anchorRect,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onSelected,
    bool Function(DateTime day)? isRestDayFor,
    bool Function(DateTime day)? isOneOffRestFor,
  }) {
    return Navigator.of(context).push<DateTime?>(
      PageRouteBuilder<DateTime?>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (routeCtx, __, ___) {
          return _WorkoutAnchoredCalendarOverlay(
            anchorRect: anchorRect,
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            isRestDayFor: isRestDayFor,
            isOneOffRestFor: isOneOffRestFor,
            onSelected: (d) {
              // Only propagate the date; the sheet itself handles popping.
              onSelected(d);
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
  State<_WorkoutMiniCalendarSheet> createState() =>
      _WorkoutMiniCalendarSheetState();
}

class _WorkoutMiniCalendarSheetState extends State<_WorkoutMiniCalendarSheet> {
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
    // (daysThisMonth is unused in this grid-filler but kept for clarity)

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
          final Widget shuttleChild = direction == HeroFlightDirection.push
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
                                  'month'), // minor text layout stability
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
                    _WorkoutWeekdayLabel('S'),
                    _WorkoutWeekdayLabel('M'),
                    _WorkoutWeekdayLabel('T'),
                    _WorkoutWeekdayLabel('W'),
                    _WorkoutWeekdayLabel('T'),
                    _WorkoutWeekdayLabel('F'),
                    _WorkoutWeekdayLabel('S'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // GRID — compute real cell size so the 6th row fits perfectly.
              LayoutBuilder(
                builder: (_, box) {
                  // width of one cell (7 columns with 6 gaps)
                  final double cell =
                      ((box.maxWidth - _gridSpacing * 6) / 7).clamp(28.0, 64.0);
                  final double gridH = cell * 6 + _gridSpacing * 5;
                  final double pill = math.min(_pillSize, cell - 4);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: gridH,
                        child: RepaintBoundary(
                          child: _WorkoutValueListenableBuilder2<DateTime,
                              DateTime>(
                            first: _displayedMonthN,
                            second: _selectedN,
                            builder: (_, displayedMonth, selected, __) {
                              // Local copies for fast access in itemBuilder.
                              final month = displayedMonth.month;
                              final selectedDay = selected;
                              return GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
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

                                  final bool scheduledRest =
                                      widget.isRestDayFor?.call(day) ?? false;
                                  final bool oneOffRest =
                                      widget.isOneOffRestFor?.call(day) ??
                                          false;
                                  final bool isRestDay =
                                      scheduledRest || oneOffRest;

                                  final Color fg = inDisplayedMonth
                                      ? _text
                                      : _muted.withValues(alpha: 0.35);

                                  BoxDecoration deco;
                                  if (isToday) {
                                    deco = BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _panel,
                                      border: const Border.fromBorderSide(
                                        BorderSide(
                                            color: Colors.white, width: 2.5),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    );
                                  } else if (isSelected) {
                                    deco = const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _accent,
                                    );
                                  } else if (isRestDay && inDisplayedMonth) {
                                    // Light rest-day badge for days in this month.
                                    deco = BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0x3324B6FF),
                                      border: Border.all(
                                        color: const Color(0x6624B6FF),
                                        width: 1.4,
                                      ),
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
                                      borderRadius:
                                          BorderRadius.circular(pill / 2),
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
                                                    normalized; // local update
                                              }
                                              widget.onSelected(normalized);
                                              Navigator.of(context)
                                                  .maybePop(normalized);
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
                          height: 10), // cushion above rounded bottom
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

class _WorkoutWeekdayLabel extends StatelessWidget {
  const _WorkoutWeekdayLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: _WorkoutMiniCalendarSheetState._pillSize,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: _WorkoutMiniCalendarSheetState._muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
}

/// Overlay host that positions & animates the popover.
class _WorkoutAnchoredCalendarOverlay extends StatefulWidget {
  const _WorkoutAnchoredCalendarOverlay({
    required this.anchorRect,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
    required this.onDismissed,
    this.isRestDayFor,
    this.isOneOffRestFor,
  });

  final Rect anchorRect;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onDismissed;

  final bool Function(DateTime day)? isRestDayFor;
  final bool Function(DateTime day)? isOneOffRestFor;

  @override
  State<_WorkoutAnchoredCalendarOverlay> createState() =>
      _WorkoutAnchoredCalendarOverlayState();
}

class _WorkoutAnchoredCalendarOverlayState
    extends State<_WorkoutAnchoredCalendarOverlay>
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
    _slide =
        Tween<Offset>(begin: const Offset(0, -0.03), end: Offset.zero).animate(
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
                    child: _WorkoutCalendarPopover(
                      radius: radiusFor(t),
                      maxHeight: maxH,
                      caretX: caretX.toDouble(),
                      caretDown: preferBelow,
                      onClose: _close,
                      child: _WorkoutMiniCalendarSheet(
                        initialDate: widget.initialDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onSelected: (d) => widget.onSelected(d),
                        isRestDayFor: widget.isRestDayFor,
                        isOneOffRestFor: widget.isOneOffRestFor,
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
class _WorkoutCalendarPopover extends StatelessWidget {
  const _WorkoutCalendarPopover({
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
      painter: _WorkoutSpeechBubblePainter(
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
class _WorkoutSpeechBubblePainter extends CustomPainter {
  _WorkoutSpeechBubblePainter({
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
  bool shouldRepaint(covariant _WorkoutSpeechBubblePainter old) =>
      old.caretX != caretX ||
      old.caretDown != caretDown ||
      old.color != color ||
      old.radius != radius;
}

/* ---------- Tiny helper to listen to two notifiers ---------- */
class _WorkoutValueListenableBuilder2<A, B> extends StatelessWidget {
  const _WorkoutValueListenableBuilder2({
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
