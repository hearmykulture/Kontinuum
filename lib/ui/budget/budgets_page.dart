// lib/ui/budget/budgets_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:kontinuum/providers/budget_provider.dart';

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({
    super.key,
    required this.budgets,
    required this.atCap,
    required this.onGetStarted,
    required this.onCreateNew,
    required this.onEmptyCreate,
    required this.onBudgetTap,
    required this.addSquareKey,
    required this.addTileKey,
    required this.tileKeys,
    this.plusOpacity,
    this.onBudgetLongPress,
    this.cardColor = const Color(0xFF0B2B26),
    this.cardBorderRadius = 22.0,
    this.accentColor = const Color(0xFFDAF1DE),
    this.subtitleColor = const Color(0xFF9BB0A1),
    this.maxNoticeColor = const Color(0xFF9BB0A1),
    this.currentBudgetId,
  });

  final List<Budget> budgets;
  final bool atCap;
  final Animation<double>? plusOpacity;

  final VoidCallback onGetStarted;
  final VoidCallback onCreateNew;
  final VoidCallback onEmptyCreate;
  final ValueChanged<Budget> onBudgetTap;
  final ValueChanged<Budget>? onBudgetLongPress;

  final GlobalKey addSquareKey;
  final GlobalKey addTileKey;
  final Map<String, GlobalKey> tileKeys;

  final Color cardColor;
  final double cardBorderRadius;
  final Color accentColor;
  final Color subtitleColor;
  final Color maxNoticeColor;

  /// The id of the budget that's marked as "current" (badge appears).
  final String? currentBudgetId;

  static final NumberFormat _currency =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final bool hasBudgets = budgets.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: hasBudgets
          ? _BudgetGrid(
              key: const ValueKey('budget_grid'),
              budgets: budgets,
              atCap: atCap,
              onBudgetTap: onBudgetTap,
              onBudgetLongPress: onBudgetLongPress,
              onCreateNew: onCreateNew,
              addTileKey: addTileKey,
              tileKeys: tileKeys,
              cardColor: cardColor,
              borderRadius: cardBorderRadius,
              accentColor: accentColor,
              subtitleColor: subtitleColor,
              maxNoticeColor: maxNoticeColor,
              currentBudgetId: currentBudgetId,
            )
          : _EmptyState(
              key: const ValueKey('budget_empty'),
              onGetStarted: onGetStarted,
              onCreateNew: onEmptyCreate,
              addSquareKey: addSquareKey,
              plusOpacity: plusOpacity,
              cardColor: cardColor,
              accentColor: accentColor,
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.onGetStarted,
    required this.onCreateNew,
    required this.addSquareKey,
    required this.cardColor,
    required this.accentColor,
    this.plusOpacity,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onCreateNew;
  final GlobalKey addSquareKey;
  final Color cardColor;
  final Color accentColor;
  final Animation<double>? plusOpacity;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? plus = plusOpacity;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GetStartedButton(onPressed: onGetStarted, accentColor: accentColor),
        const SizedBox(height: 18),
        _AddSquare(
          measureKey: addSquareKey,
          size: 150,
          onTap: onCreateNew,
          cornerRadius: 24,
          cardColor: cardColor,
          accentColor: accentColor,
          plusOpacity: plus,
        ),
      ],
    );
  }
}

class _BudgetGrid extends StatelessWidget {
  const _BudgetGrid({
    super.key,
    required this.budgets,
    required this.atCap,
    required this.onBudgetTap,
    required this.onBudgetLongPress,
    required this.onCreateNew,
    required this.addTileKey,
    required this.tileKeys,
    required this.cardColor,
    required this.borderRadius,
    required this.accentColor,
    required this.subtitleColor,
    required this.maxNoticeColor,
    required this.currentBudgetId,
  });

  final List<Budget> budgets;
  final bool atCap;
  final ValueChanged<Budget> onBudgetTap;
  final ValueChanged<Budget>? onBudgetLongPress;
  final VoidCallback onCreateNew;
  final GlobalKey addTileKey;
  final Map<String, GlobalKey> tileKeys;
  final Color cardColor;
  final double borderRadius;
  final Color accentColor;
  final Color subtitleColor;
  final Color maxNoticeColor;
  final String? currentBudgetId;

  @override
  Widget build(BuildContext context) {
    final int baseCount = budgets.length;
    final bool showAddTile = !atCap;
    final int itemCount = baseCount + (showAddTile ? 1 : 0);
    final int crossAxisCount = itemCount <= 4 ? itemCount : 4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          primary: false,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount.clamp(1, 4),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            if (index < baseCount) {
              final budget = budgets[index];
              final key = tileKeys[budget.id] ?? GlobalKey();
              tileKeys.putIfAbsent(budget.id, () => key);

              final bool isCurrent =
                  (currentBudgetId != null && currentBudgetId == budget.id);

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                child: _BudgetTile(
                  key: ValueKey('budget_tile_${budget.id}'),
                  measureKey: key,
                  budget: budget,
                  isCurrent: isCurrent,
                  onTap: () => onBudgetTap(budget),
                  onLongPress: onBudgetLongPress != null
                      ? () => onBudgetLongPress!(budget)
                      : null,
                  cardColor: cardColor,
                  borderRadius: borderRadius,
                  accentColor: accentColor,
                  subtitleColor: subtitleColor,
                ),
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              child: _AddBudgetTile(
                key: const ValueKey('budget_add_tile'),
                measureKey: addTileKey,
                onTap: onCreateNew,
                borderRadius: borderRadius,
                accentColor: accentColor,
                cardColor: cardColor,
              ),
            );
          },
        ),
        if (atCap)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Max ${BudgetProvider.kBudgetsCap} budgets reached',
              style: TextStyle(
                color: maxNoticeColor,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ),
      ],
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    super.key,
    required this.measureKey,
    required this.budget,
    required this.onTap,
    this.onLongPress,
    required this.cardColor,
    required this.borderRadius,
    required this.accentColor,
    required this.subtitleColor,
    required this.isCurrent,
  });

  final GlobalKey measureKey;
  final Budget budget;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color cardColor;
  final double borderRadius;
  final Color accentColor;
  final Color subtitleColor;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    // Compact layout to prevent overflow in small tiles.
    const double kPad = 12;
    const double kTitleSize = 16;
    const double kSubSize = 12;

    final String period = 'Monthly';
    final String value = BudgetsPage._currency.format(budget.monthlyAmount);

    Widget roundedSquareIcon(IconData icon) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6), // ← rounded *square*
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: accentColor),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: accentColor.withValues(alpha: 0.25),
          highlightColor: Colors.white10,
          child: Ink(
            key: measureKey,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Stack(
              children: [
                // Content
                Padding(
                  padding: const EdgeInsets.all(kPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      roundedSquareIcon(Icons.folder_rounded),
                      const SizedBox(height: 6),
                      // Title
                      Text(
                        budget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: kTitleSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // "Monthly"
                      Text(
                        period,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: kSubSize,
                          letterSpacing: 0.2,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Value under "Monthly"
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentColor.withValues(alpha: 0.90),
                          fontSize: kSubSize,
                          letterSpacing: 0.2,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Current badge
                if (isCurrent)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: _CheckBadge(size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
    );
  }
}

class _AddBudgetTile extends StatelessWidget {
  const _AddBudgetTile({
    super.key,
    required this.measureKey,
    required this.onTap,
    required this.borderRadius,
    required this.accentColor,
    required this.cardColor,
  });

  final GlobalKey measureKey;
  final VoidCallback onTap;
  final double borderRadius;
  final Color accentColor;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    Widget roundedSquarePlus() {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.add_rounded, size: 16, color: accentColor),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: accentColor.withValues(alpha: 0.2),
          highlightColor: accentColor.withValues(alpha: 0.05),
          child: Ink(
            key: measureKey,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.7),
                width: 2,
              ),
              backgroundBlendMode: BlendMode.srcOver,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  roundedSquarePlus(),
                  const SizedBox(height: 8),
                  Text(
                    'Create new budget',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({
    required this.onPressed,
    required this.accentColor,
  });

  final VoidCallback onPressed;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Get started',
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0B2B26),
          foregroundColor: accentColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: _FlashText(
          'Get Started',
          color: accentColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddSquare extends StatelessWidget {
  const _AddSquare({
    required this.measureKey,
    required this.size,
    required this.onTap,
    required this.cornerRadius,
    required this.cardColor,
    required this.accentColor,
    this.plusOpacity,
  });

  final GlobalKey measureKey;
  final double size;
  final VoidCallback onTap;
  final double cornerRadius;
  final Color cardColor;
  final Color accentColor;
  final Animation<double>? plusOpacity;

  @override
  Widget build(BuildContext context) {
    final Widget icon = Icon(Icons.add_rounded, color: accentColor, size: 48);
    final Widget fadingIcon = plusOpacity != null
        ? FadeTransition(opacity: plusOpacity!, child: icon)
        : icon;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        key: measureKey,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        width: size,
        height: size,
        child: Center(child: fadingIcon),
      ),
    );
  }
}

class _FlashText extends StatefulWidget {
  const _FlashText(
    this.text, {
    required this.color,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.period = const Duration(seconds: 5),
    this.flashDuration = const Duration(milliseconds: 1300),
    this.tailPortion = 0.20,
    this.peakScale = 1.14,
    this.whiteMix = 0.50,
    this.maxGlow = 12.0,
    this.glowOpacity = 0.50,
    this.margin = 0.14,
    this.sigma = 0.16,
  });

  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final Duration period;
  final Duration flashDuration;
  final double tailPortion;
  final double peakScale;
  final double whiteMix;
  final double maxGlow;
  final double glowOpacity;
  final double margin;
  final double sigma;

  @override
  State<_FlashText> createState() => _FlashTextState();
}

class _FlashTextState extends State<_FlashText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late double _flashPortion;
  late double _tail;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)..repeat();
    _flashPortion =
        widget.flashDuration.inMilliseconds / widget.period.inMilliseconds;
    _tail = widget.tailPortion.clamp(0.05, 0.5);
    if (_flashPortion + _tail > 0.92) {
      _tail = (0.92 - _flashPortion).clamp(0.05, 0.5);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chars = widget.text.split('');
    final letterIdx = <int>[];
    for (int i = 0; i < chars.length; i++) {
      if (chars[i] != ' ') letterIdx.add(i);
    }
    final m = letterIdx.length;
    final xs = List<double>.generate(m, (i) => (m == 1) ? 0.5 : i / (m - 1));

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;

        double? centerX;
        if (t <= _flashPortion) {
          final local = (t / _flashPortion).clamp(0.0, 1.0);
          final eased = Curves.easeInOutCubic.transform(local);
          centerX = -widget.margin + (1 + 2 * widget.margin) * eased;
        }

        double globalTail = 0.0;
        if (t > _flashPortion && t <= (_flashPortion + _tail)) {
          final k = (t - _flashPortion) / _tail;
          globalTail = 0.35 * (1.0 - Curves.easeOutCubic.transform(k));
        }

        int nonSpace = 0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: TextBaseline.alphabetic == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: List.generate(chars.length, (i) {
            final ch = chars[i];
            if (ch == ' ') return const SizedBox(width: 6);

            double intensity = 0.0;
            if (centerX != null) {
              final x = xs[nonSpace];
              final dx = x - centerX;
              final sig2 = 2 * widget.sigma * widget.sigma;
              final gauss = math.exp(-(dx * dx) / sig2).clamp(0.0, 1.0);
              final sweepProg = (t / _flashPortion).clamp(0.0, 1.0);
              final edgeSoft = 0.5 * Curves.easeOut.transform(sweepProg) +
                  0.5 * Curves.easeIn.transform(1 - sweepProg);
              intensity = gauss * (0.85 + 0.15 * edgeSoft);
            }
            final total = math.max(intensity, globalTail);

            final scale = 1 + (widget.peakScale - 1) * total;
            final color =
                Color.lerp(widget.color, Colors.white, widget.whiteMix * total)!;
            final glow = widget.maxGlow * total;
            final glowOpacity = (widget.glowOpacity * total).clamp(0.0, 1.0);

            nonSpace++;

            return Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Text(
                ch,
                style: TextStyle(
                  color: color,
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight,
                  shadows: glow > 0.01
                      ? [
                          Shadow(
                            color: widget.color.withValues(alpha: glowOpacity),
                            blurRadius: glow,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFDAF1DE).withValues(alpha: 0.9),
            width: 2,
          ),
        ),
        child: const Center(
          child: Icon(Icons.check_rounded, size: 12, color: Color(0xFFDAF1DE)),
        ),
      ),
    );
  }
}
