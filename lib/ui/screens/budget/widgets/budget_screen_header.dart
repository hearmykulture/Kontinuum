import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/ui/screens/budget/budget_overview_screen.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';
import 'package:kontinuum/ui/widgets/year_progress_date.dart';
import 'package:kontinuum/ui/theme/app_colors.dart';

typedef ProgressForDay = double Function(DateTime day);

class BudgetScreenWidget extends StatelessWidget {
  const BudgetScreenWidget({
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

    /// Tight vertical padding around cards (doesn't affect divider).
    this.carouselTopBottomPad = 8,

    /// Pixels ABOVE the divider where the overlay scrollbar sits.
    /// Smaller = lower (closer to the divider). Zero sits right on top.
    this.carouselScrollbarBottomInset = 4,

    /// Divider color under the carousel.
    this.dividerColor = const Color(0x1FFFFFFF),

    /// Visibility toggles for reuse
    this.enableScrollbar = true,
    this.showDivider = true,

    /// Create budget callback
    this.onCreateTap,

    /// Report selected budget id up to parent (nullable -> deselect).
    this.onBudgetSelected,
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

  // Callbacks
  final VoidCallback? onCreateTap;

  /// Selection notify (id or null when deselected)
  final ValueChanged<String?>? onBudgetSelected;

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
          child: BudgetCarousel(
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
            onCreateTap: onCreateTap,
            onBudgetSelected: onBudgetSelected,
          ),
        ),
      ],
    );
  }
}

/// Horizontal grid of budget cards with a trailing Create tile.
/// Draws an OVERLAY scrollbar inside the same height and a divider beneath.
/// Scrollbar appears only when content is actually wider than the viewport.
class BudgetCarousel extends StatefulWidget {
  const BudgetCarousel({
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

    // callbacks
    this.onCreateTap,

    // selection upcall
    this.onBudgetSelected,
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

  final VoidCallback? onCreateTap;

  /// Notifies parent of the selected budget id (or null to deselect).
  final ValueChanged<String?>? onBudgetSelected;

  @override
  State<BudgetCarousel> createState() => _BudgetCarouselState();
}

class _BudgetCarouselState extends State<BudgetCarousel> {
  static const double _hPad = 16;
  static const double _spacing = 12;

  final ScrollController _scrollCtrl = ScrollController();
  String? _selectedBudgetId;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>().budgets;
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

        final totalTiles = budgets.length + 1;

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
            if (index < budgets.length) {
              final Budget b = budgets[index];
              final bool isSelected = _selectedBudgetId == b.id;
              return _BudgetCard(
                size: computedItemSize,
                budget: b,
                cardColor: widget.cardColor,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedBudgetId = isSelected ? null : b.id;
                  });
                  widget.onBudgetSelected?.call(_selectedBudgetId);
                },
              );
            }
            return _CreateBudgetTile(
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
              Divider(
                height: 1,
                thickness: 1,
                color: widget.dividerColor,
              ),
          ],
        );
      },
    );
  }
}

class _CreateBudgetTile extends StatelessWidget {
  const _CreateBudgetTile({
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

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.size,
    required this.budget,
    required this.cardColor,
    this.isSelected = false,
    this.onTap,
  });

  final double size;
  final Budget budget;
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
              onTap: onTap ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            BudgetOverviewScreen(budgetId: budget.id),
                      ),
                    );
                  },
              child: Container(
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
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              BudgetOverviewScreen(budgetId: budget.id),
                        ),
                      );
                    },
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

  // Helper so _BudgetCard can reuse fixed layout without passing values twice.
  static Widget buildFromParent(BuildContext context) {
    final parent = context.findAncestorWidgetOfExactType<_BudgetCard>()!;
    final b = parent.budget;
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final amountText =
        '${formatter.format(b.monthlyAmount)} / ${labelForBudgetTimeSpan(b.cadence)}';
    return _CardBody(
      title: b.title,
      subtitle: amountText,
      icon: Icons.account_balance_wallet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            maxLines: 1,
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
