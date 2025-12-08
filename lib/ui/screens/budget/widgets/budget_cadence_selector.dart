import 'package:flutter/material.dart';

import '../models/budget_models.dart';
import '../theme/budget_theme.dart';

class BudgetCadenceSelector extends StatelessWidget {
  const BudgetCadenceSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.spans = const [
      BudgetTimeSpan.weekly,
      BudgetTimeSpan.monthly,
      BudgetTimeSpan.yearly,
    ],
  });

  final BudgetTimeSpan selected;
  final ValueChanged<BudgetTimeSpan> onChanged;
  final List<BudgetTimeSpan> spans;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final span in spans)
          _CadenceChip(
            label: labelForBudgetTimeSpan(span),
            selected: selected == span,
            onTap: () => onChanged(span),
          ),
      ],
    );
  }
}

class _CadenceChip extends StatelessWidget {
  const _CadenceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? BudgetTheme.mint
        : Colors.white.withValues(
            alpha: 0.08,
          );
    final borderColor =
        selected ? BudgetTheme.mint : Colors.white.withValues(alpha: 0.16);
    final fg = selected ? Colors.black : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BudgetTheme.mint.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
