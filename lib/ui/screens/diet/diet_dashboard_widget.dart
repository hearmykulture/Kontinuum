// lib/ui/diet/diet_dashboard_widget.dart
// Fully self-contained header: YearProgressBar + DietCarousel.
// No provider dependency; pass dietCards (optional). Overlay scrollbar + divider included.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:kontinuum/ui/widgets/year_progress_date.dart';
import 'package:kontinuum/ui/theme/app_colors.dart';

typedef ProgressForDay = double Function(DateTime day);

class DietCardData {
  final String id;
  final String title; // e.g., "Breakfast Templates"
  final String? subtitle; // e.g., "12 items"
  final IconData icon; // e.g., Icons.restaurant
  final VoidCallback? onTap;

  const DietCardData({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon = Icons.restaurant,
    this.onTap,
  });
}

class DietDashboardWidget extends StatelessWidget {
  const DietDashboardWidget({
    super.key,
    required this.selectedDate,
    required this.getProgressForDay,
    required this.onDateSelected,

    // Appearance
    this.accentColor = AppColors.accentBlue,

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

    /// Cards to show in the carousel (optional).
    this.dietCards = const [],

    /// Callback if user taps the trailing “Create” tile.
    this.onCreateTap,
  });

  // Progress bar inputs
  final DateTime selectedDate;
  final ProgressForDay getProgressForDay;
  final ValueChanged<DateTime> onDateSelected;
  final Color accentColor;

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

  // Diet-specific
  final List<DietCardData> dietCards;
  final VoidCallback? onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        YearProgressBar(
          selectedDate: selectedDate,
          getProgressForDay: getProgressForDay,
          onDateSelected: onDateSelected,
          accentColor: accentColor,
        ),
        Transform.translate(
          offset: Offset(0, carouselUnderlap),
          child: DietCarousel(
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
            items: dietCards,
            onCreateTap: onCreateTap,
          ),
        ),
      ],
    );
  }
}

/// Horizontal grid of diet cards with a trailing Create tile.
/// Draws an OVERLAY scrollbar inside the same height and a divider beneath.
/// Scrollbar appears only when content is actually wider than the viewport.
class DietCarousel extends StatefulWidget {
  const DietCarousel({
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

    // data
    this.items = const [],
    this.onCreateTap,
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

  final List<DietCardData> items;
  final VoidCallback? onCreateTap;

  @override
  State<DietCarousel> createState() => _DietCarouselState();
}

class _DietCarouselState extends State<DietCarousel> {
  static const double _hPad = 16;
  static const double _spacing = 12;

  final ScrollController _scrollCtrl = ScrollController();
  String? _selectedId;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
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

        final totalTiles = items.length + 1; // + Create tile

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
            if (index < items.length) {
              final item = items[index];
              return _DietCard(
                size: computedItemSize,
                data: item,
                cardColor: widget.cardColor,
                isSelected: _selectedId == item.id,
                onTap: () {
                  setState(() {
                    _selectedId = _selectedId == item.id ? null : item.id;
                  });
                  item.onTap?.call();
                },
              );
            }
            return _CreateDietTile(
              size: computedItemSize,
              cardColor: widget.cardColor,
              onTap: widget.onCreateTap,
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
                        thumbColor: Colors.white.withValues(alpha: .7),
                        trackColor: Colors.white.withValues(alpha: .12),
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

class _CreateDietTile extends StatelessWidget {
  const _CreateDietTile({
    required this.size,
    required this.cardColor,
    this.onTap,
  });

  final double size;
  final Color cardColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const _CreateCenteredBody(),
      ),
    );
  }
}

class _DietCard extends StatelessWidget {
  const _DietCard({
    required this.size,
    required this.data,
    required this.cardColor,
    this.isSelected = false,
    this.onTap,
  });

  final double size;
  final DietCardData data;
  final Color cardColor;
  final bool isSelected;
  final VoidCallback? onTap;

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
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Main card content
            InkWell(
              borderRadius: BorderRadius.circular(_borderRadius),
              onTap: onTap ?? data.onTap,
              child: Container(
                // Draw selection border OVER content to avoid any layout change.
                foregroundDecoration: isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(_borderRadius),
                        border: Border.all(color: _selectedColor, width: 2),
                      )
                    : null,
                child: _CardPadding(
                  childBuilder: (context) => _CardBody(
                    title: data.title,
                    subtitle: data.subtitle,
                    icon: data.icon,
                  ),
                ),
              ),
            ),
            // Optional corner affordance if selected (here: edit icon)
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTap ?? data.onTap,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed icon area (no shifting)
        const Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 6, left: 2),
              child: Icon(Icons.folder, color: Colors.white70, size: 22),
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
