// lib/ui/screens/budget/widgets/budget_ring_chart.dart

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../models/budget_models.dart';
import '../painters/ring_painters.dart';
import 'common_widgets.dart';

/// Reusable donut + center pill + legend that visually matches
/// the CreateBudgetScreen header.
///
/// Usage:
///   BudgetRingChart(
///     amountLabel: '\$2,000.00',
///     onTapAmount: _openAmountPicker,
///     values: [200000, 1800000], // cents (or any units)
///     colors: [myPurple, BudgetTheme.unallocatedGray],
///     legendCategories: [
///       BudgetCategory(name: 'Foo', icon: Icons.circle, color: myPurple),
///       BudgetCategory(
///         name: 'Unallocated',
///         icon: Icons.circle,
///         color: BudgetTheme.unallocatedGray,
///       ),
///     ],
///     heroTag: 'budget_amount_hero', // optional
///   )
class BudgetRingChart extends StatefulWidget {
  const BudgetRingChart({
    super.key,
    required this.amountLabel,
    required this.values,
    required this.colors,
    this.legendCategories = const [],
    this.onTapAmount,
    this.heroTag,
    this.ringSize = 248.0,
    this.stroke = 14.0,
  });

  /// Text shown inside the pill ("Set amount" or "$2,000.00").
  final String amountLabel;

  /// Slice values (same order as [colors]).
  final List<double> values;

  /// Slice colors (same order as [values]).
  final List<Color> colors;

  /// Legend entries (normally 1:1 with [values]/[colors]).
  final List<BudgetCategory> legendCategories;

  /// Tap handler for the central pill (can be null).
  final VoidCallback? onTapAmount;

  /// Optional Hero tag for the pill to match CreateBudgetScreen.
  final String? heroTag;

  /// Outer diameter of the ring.
  final double ringSize;

  /// Stroke width of the ring.
  final double stroke;

  @override
  State<BudgetRingChart> createState() => _BudgetRingChartState();
}

class _BudgetRingChartState extends State<BudgetRingChart>
    with TickerProviderStateMixin {
  static const _layoutDuration = Duration(milliseconds: 360);
  static const _layoutCurve = Curves.easeOutCubic;

  // Animations (mirrors CreateBudgetScreen)
  late final AnimationController _ringScaleCtrl;
  late final CurvedAnimation _ringScale;
  late final AnimationController _sweepCtrl;
  late final CurvedAnimation _sweep;
  late final AnimationController _divideCtrl;
  late final CurvedAnimation _divide;

  // Pill measurement (to vertically center it in the ring)
  final GlobalKey _pillKey = GlobalKey();
  Size? _pillSize;

  @override
  void initState() {
    super.initState();

    _ringScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _ringScale = CurvedAnimation(
      parent: _ringScaleCtrl,
      curve: Curves.easeOutCubic,
    );

    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweep = CurvedAnimation(
      parent: _sweepCtrl,
      curve: Curves.easeOutCubic,
    );

    _divideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _divide = CurvedAnimation(
      parent: _divideCtrl,
      curve: Curves.easeOutCubic,
    );

    if (_hasSlices) {
      _ringScaleCtrl.value = 1.0;
      _sweepCtrl.value = 1.0;
      _divideCtrl.value = 1.0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePill());
  }

  bool get _hasSlices =>
      widget.values.isNotEmpty && widget.values.any((v) => v > 0);

  @override
  void didUpdateWidget(covariant BudgetRingChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final valuesChanged = widget.values.length != oldWidget.values.length ||
        !listEquals(widget.values, oldWidget.values) ||
        widget.colors.length != oldWidget.colors.length ||
        !listEquals(widget.colors, oldWidget.colors) ||
        widget.amountLabel != oldWidget.amountLabel;

    if (valuesChanged && _hasSlices) {
      // Same feel as CreateBudgetScreen: scale in + sweep + divide.
      _ringScaleCtrl.forward(from: 0);
      _sweepCtrl.forward(from: 0);
      _divideCtrl.forward(from: 0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePill());
  }

  void _measurePill() {
    final rb = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || !mounted) return;
    final newSize = rb.size;
    if (_pillSize == null || _pillSize != newSize) {
      setState(() => _pillSize = newSize);
    }
  }

  @override
  void dispose() {
    _ringScaleCtrl.dispose();
    _sweepCtrl.dispose();
    _divideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showChart = _hasSlices;
    final pillH = _pillSize?.height ?? 44.0;

    // Make sure these are typed as double, not num.
    final areaHeight = showChart ? widget.ringSize : (pillH + 12.0);
    final pillTop = showChart ? (widget.ringSize - pillH) / 2 : 12.0;

    // Avoid deprecated withOpacity; keep same visual feel.
    final trackColor = Colors.white.withAlpha((0.10 * 255).round());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chart area (donut + pill)
        Center(
          child: AnimatedContainer(
            duration: _layoutDuration,
            curve: _layoutCurve,
            height: areaHeight,
            width: widget.ringSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (showChart)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ScaleTransition(
                      scale: _ringScale,
                      child: SizedBox.square(
                        dimension: widget.ringSize,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_sweep, _divide]),
                          builder: (_, __) {
                            return CustomPaint(
                              painter: ProportionalRingPainter(
                                values: widget.values,
                                colors: widget.colors,
                                progress: _sweep.value,
                                splitT: _divide.value,
                                stroke: widget.stroke,
                                trackColor: trackColor,
                                gapRadians: 0.018,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // Center pill (Hero + PillButton.primary)
                AnimatedPositioned(
                  duration: _layoutDuration,
                  curve: _layoutCurve,
                  top: pillTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      key: _pillKey,
                      child: _buildPill(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Legend (same layout as CreateBudgetScreen)
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: (widget.legendCategories.isEmpty)
              ? const SizedBox(height: 6)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: CategoryLegend(categories: widget.legendCategories),
                ),
        ),
      ],
    );
  }

  Widget _buildPill() {
    final pill = PillButton.primary(
      icon: Icons.payments_rounded,
      label: widget.amountLabel,
      // Make sure PillButton gets a non-null callback.
      onTap: widget.onTapAmount ?? () {},
    );

    if (widget.heroTag == null) return pill;

    return Hero(
      tag: widget.heroTag!,
      child: pill,
    );
  }
}
