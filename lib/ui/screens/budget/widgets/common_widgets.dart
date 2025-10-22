import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/budget_models.dart';
import '../theme/budget_theme.dart';

/// ===== TitleField =====
class TitleField extends StatelessWidget {
  const TitleField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.width,
    required this.fontSize,
    required this.maxLines,
    this.autofocus = false,
    this.inputFormatters = const [],
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double width;
  final double fontSize;
  final int maxLines;
  final bool autofocus;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        scrollPhysics: const NeverScrollableScrollPhysics(),
        cursorColor: BudgetTheme.text,
        cursorWidth: 3,
        cursorHeight: fontSize * 1.1,
        style: TextStyle(
          color: BudgetTheme.text,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: 0.2,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: 'Create budget',
          hintStyle: TextStyle(
            color: BudgetTheme.textMuted,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: 0.2,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        inputFormatters: inputFormatters,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}

/// ===== Category legend =====
class CategoryLegend extends StatelessWidget {
  const CategoryLegend({super.key, required this.categories});
  final List<BudgetCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in categories)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: c.color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.15),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('—',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                c.name,
                style: const TextStyle(
                  color: BudgetTheme.text,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// ===== Pill button =====
class PillButton extends StatelessWidget {
  const PillButton.primary({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  })  : bg = BudgetTheme.mint,
        fg = Colors.black,
        border = Colors.transparent;

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 140),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.06)),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
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

/// ===== Color Rail (shared by sheets) =====
class ColorRail extends StatelessWidget {
  const ColorRail({
    super.key,
    required this.colors,
    required this.selected,
    required this.onPick,
  });
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF051F20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: colors.map((c) {
          final sel = c.value == selected.value;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPick(c);
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? Colors.white : Colors.white.withOpacity(0.25),
                  width: sel ? 2 : 1,
                ),
              ),
              child: sel
                  ? const Center(
                      child: Icon(Icons.check, size: 18, color: Colors.black),
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ===== Close FAB =====
class CloseFab extends StatelessWidget {
  const CloseFab({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Close',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.08)),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: BudgetTheme.mint.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(Icons.close, size: 20, color: BudgetTheme.mint),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== No-glow scroll behavior =====
class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

/// ===== Expandable option group (categories/recurring) =====
class OptionGroup extends StatelessWidget {
  const OptionGroup({
    super.key,
    // categories
    required this.categoriesExpanded,
    required this.onTapCategories,
    required this.onAddCategory,
    required this.categories,
    required this.onEditCategory,
    required this.onDeleteCategory,
    // recurring
    required this.recurringExpanded,
    required this.onTapRecurring,
    required this.onAddRecurring,
    required this.recurring,
    required this.onEditRecurring,
    required this.onDeleteRecurring,
  });

  // categories
  final bool categoriesExpanded;
  final VoidCallback onTapCategories;
  final VoidCallback onAddCategory;
  final List<BudgetCategory> categories;
  final ValueChanged<int> onEditCategory;
  final ValueChanged<int> onDeleteCategory;

  // recurring
  final bool recurringExpanded;
  final VoidCallback onTapRecurring;
  final VoidCallback onAddRecurring;
  final List<RecurringExpense> recurring;
  final ValueChanged<int> onEditRecurring;
  final ValueChanged<int> onDeleteRecurring;

  static const double _rowVPad = 12;
  static const double _boxSize = 34;
  static const double _boxRadius = 12;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    final divider = Container(
      height: 1,
      color: BudgetTheme.dividerOnCard(context),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );

    // Max height for inner lists so they scroll instead of overflowing
    final double maxListH =
        math.min(MediaQuery.of(context).size.height * 0.28, 240);
    final money = NumberFormat.currency(symbol: '\$');

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: radius,
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(label: 'Categories', onTap: onTapCategories),
            divider,
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: categoriesExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Add a category',
                                  style: TextStyle(
                                    color: BudgetTheme.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              _iconBoxButton(
                                icon: Icons.add_rounded,
                                tooltip: 'New category',
                                onTap: onAddCategory,
                              ),
                            ],
                          ),
                          if (categories.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: maxListH),
                              child: ScrollConfiguration(
                                behavior: NoGlowScrollBehavior(),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final c = categories[i];
                                    return Dismissible(
                                      key: ValueKey(
                                          'cat_${i}_${c.name}_${c.color.value}'),
                                      direction: DismissDirection.endToStart,
                                      confirmDismiss: (_) async {
                                        HapticFeedback.lightImpact();
                                        return true;
                                      },
                                      onDismissed: (_) => onDeleteCategory(i),
                                      background:
                                          _swipeBg(cutoutPx: _boxSize + 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: c.color,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(c.icon,
                                                    size: 18,
                                                    color: BudgetTheme.mint),
                                                const SizedBox(width: 8),
                                                Text(
                                                  c.name,
                                                  style: const TextStyle(
                                                    color: BudgetTheme.text,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _iconBoxButton(
                                            icon: Icons.edit_rounded,
                                            tooltip: 'Edit',
                                            onTap: () => onEditCategory(i),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            divider,
            _row(label: 'Recurring expenses', onTap: onTapRecurring),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: recurringExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Add a bill',
                                  style: TextStyle(
                                    color: BudgetTheme.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              _iconBoxButton(
                                icon: Icons.add_rounded,
                                tooltip: 'New recurring expense',
                                onTap: onAddRecurring,
                              ),
                            ],
                          ),
                          if (recurring.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: maxListH),
                              child: ScrollConfiguration(
                                behavior: NoGlowScrollBehavior(),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: recurring.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final r = recurring[i];
                                    final cat = r.category;
                                    final catPart =
                                        (cat == null) ? '' : ' • ${cat.name}';
                                    return Dismissible(
                                      key: ValueKey(
                                          'rec_${i}_${r.name}_${r.color.value}'),
                                      direction: DismissDirection.endToStart,
                                      confirmDismiss: (_) async {
                                        HapticFeedback.lightImpact();
                                        return true;
                                      },
                                      onDismissed: (_) => onDeleteRecurring(i),
                                      background:
                                          _swipeBg(cutoutPx: _boxSize + 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: r.color,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(r.icon,
                                                        size: 18,
                                                        color:
                                                            BudgetTheme.mint),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      r.name,
                                                      style: const TextStyle(
                                                        color: BudgetTheme.text,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${money.format(r.amountCents / 100)} • ${labelForRecurrence(r.cadence)}$catPart',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _iconBoxButton(
                                            icon: Icons.edit_rounded,
                                            tooltip: 'Edit',
                                            onTap: () => onEditRecurring(i),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.06)),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: _rowVPad),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '',
                  style: TextStyle(fontSize: 0), // spacer for semantics
                ),
              ),
              Expanded(
                flex: 999,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: BudgetTheme.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              SizedBox(
                width: _boxSize,
                height: _boxSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(_boxRadius),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.14),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.chevron_right_rounded,
                        size: 20, color: BudgetTheme.mint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _iconBoxButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_boxRadius),
          overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.06)),
          child: Ink(
            width: _boxSize,
            height: _boxSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(_boxRadius),
              border:
                  Border.all(color: Colors.white.withOpacity(0.14), width: 1),
            ),
            child: Center(
              child: Icon(icon, size: 20, color: BudgetTheme.mint),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _swipeBg({required double cutoutPx}) {
    return Container(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(right: cutoutPx),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFB00020).withOpacity(0.9),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(_boxRadius),
            bottomRight: Radius.circular(_boxRadius),
          ),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
    );
  }
}
