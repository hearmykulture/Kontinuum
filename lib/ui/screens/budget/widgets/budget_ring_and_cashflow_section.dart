// lib/ui/screens/budget/widgets/budget_ring_and_cashflow_section.dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/services/bank_link_service.dart';
import 'package:kontinuum/models/budget_transaction.dart';
import 'package:kontinuum/services/budget_boxes.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';
import 'package:kontinuum/ui/screens/budget/utils/recurring_schedule.dart';
import 'package:kontinuum/ui/screens/budget/widgets/budget_ring_chart.dart';

import '../budget_screen_theme.dart';
import 'package:kontinuum/core/time/app_clock.dart';
import 'package:kontinuum/ui/screens/budget/create_transaction_screen.dart';
import 'package:kontinuum/ui/screens/budget/theme/budget_theme.dart';

/* ───────────────────────── Helpers ───────────────────────── */

/// Normalize recurring expenses to monthly cents, taking into account
/// multiple weekly weekdays if configured.
int normalizedMonthlyCents(RecurringExpense r) {
  switch (r.cadence) {
    case Recurrence.weekly:
      final countPerWeek =
          r.weeklyWeekdays.isNotEmpty ? r.weeklyWeekdays.length : 1;
      return r.amountCents * countPerWeek * 52 / 12.round();
    case Recurrence.monthly:
      return r.amountCents;
    case Recurrence.yearly:
      return r.amountCents / 12.round();
  }
}

/// Shared helper: one horizontal row of chips that scrolls horizontally.
Widget _horizontalChipRow(List<Widget> chips) {
  if (chips.isEmpty) return const SizedBox.shrink();
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: chips
          .map(
            (w) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: w,
            ),
          )
          .toList(),
    ),
  );
}

Widget _transactionBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/* ───────────────────────── Ring section (slider + sections) ───────────────────────── */

class BudgetRingSection extends StatefulWidget {
  const BudgetRingSection({
    super.key,
    required this.selectedBudgetId,
    required this.bankLinkService,
    required this.showStats,
    required this.onToggleStats,
    this.onTapAmount,
  });

  final String? selectedBudgetId;
  final BankLinkService bankLinkService;

  /// Whether the stats view is active (toggled by the graph icon).
  final bool showStats;

  /// Called when the graph icon is tapped.
  final VoidCallback onToggleStats;

  /// Called when user taps the ring amount label (to open edit/create).
  final VoidCallback? onTapAmount;

  @override
  State<BudgetRingSection> createState() => _BudgetRingSectionState();
}

class _BudgetRingSectionState extends State<BudgetRingSection> {
  static const int _pageCount = 3;

  // Slightly tighter height so the pager dots sit just under the legend.
  static const double _pagerHeight = 280.0;

  late final PageController _pageController;
  int _currentPage = 0; // start on Bank balances

  // Controls whether the CASH FLOW section is open or collapsed.
  bool _cashFlowExpanded = true;

  // Controls whether the UPCOMING BILLS dropdown is open or collapsed.
  bool _upcomingBillsExpanded = false;

  // Timespan state for the upcoming bills dropdown.
  BudgetTimeSpan _upcomingBillsSpan = BudgetTimeSpan.monthly;
  DateTime? _customSpanFrom;
  DateTime? _customSpanTo;

  // Controls whether the CATEGORIES dropdown is open or collapsed.
  bool _categoriesExpanded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedBudgetId = widget.selectedBudgetId;

    // If nothing is selected, hide the whole section for now.
    if (selectedBudgetId == null) return const SizedBox.shrink();

    final provider = context.watch<BudgetProvider>();
    final Budget? budget = provider.byId(selectedBudgetId);
    if (budget == null) return const SizedBox.shrink();

    // Upcoming bills are driven from recurrence metadata.
    final now = AppClock.now();
    final upcomingBills = buildUpcomingInstancesForSpan(
      budget.recurrings,
      span: _upcomingBillsSpan,
      anchor: now,
      customStart: _customSpanFrom,
      customEnd: _customSpanTo,
    );

    final int totalCents = budget.monthlyAmount * 100;

    // Sum per-category recurring spend (normalized to monthly).
    final Map<String, int> categoryTotals = <String, int>{};
    for (final cat in budget.categories) {
      categoryTotals[cat.name] = 0;
    }

    int usedCents = 0;
    int uncategorizedCents = 0;
    for (final rec in budget.recurrings) {
      final int monthlyRecCents = normalizedMonthlyCents(rec);
      usedCents += monthlyRecCents;
      final cat = rec.category;
      if (cat == null) {
        uncategorizedCents += monthlyRecCents;
      } else {
        categoryTotals[cat.name] = categoryTotals[cat.name] ?? 0) + monthlyRecCents;
      }
    }

    final int remainderCents = (totalCents - usedCents).clamp(0, totalCents);

    final List<double> values = <double>[];
    final List<Color> colors = <Color>[];
    final List<BudgetCategory> legend = <BudgetCategory>[];

    // Only add categories with spend > 0 to avoid degenerate slices.
    for (final cat in budget.categories) {
      final cents = categoryTotals[cat.name] ?? 0);
      if (cents > 0) {
        values.add(cents.toDouble());
        colors.add(cat.color);
        legend.add(
          BudgetCategory(name: cat.name, icon: cat.icon, color: cat.color),
        );
      }
    }

    // Show uncategorized recurring spend explicitly so totals stay aligned.
    if (uncategorizedCents > 0) {
      const uncategorizedColor = BudgetTheme.unallocatedGray;
      values.add(uncategorizedCents.toDouble());
      colors.add(uncategorizedColor);
      legend.add(
        BudgetCategory(
          name: 'Uncategorized',
          icon: Icons.category_outlined,
          color: uncategorizedColor,
        ),
      );
    }

    // Always add the remainder slice if any.
    if (remainderCents > 0) {
      final Color unallocatedColor = Colors.white.withValues(alpha: (0.40));
      values.add(remainderCents.toDouble());
      colors.add(unallocatedColor);
      legend.add(
        BudgetCategory(
          name: budget.unallocatedAsSavings ? 'Savings' : 'Unallocated',
          icon: Icons.circle,
          color: unallocatedColor,
        ),
      );
    }

    // If there are still no slices (empty budget & no remainder), hide.
    if (values.isEmpty) return const SizedBox.shrink();

    final currencyFmt = NumberFormat.currency(symbol: '\$');
    final String amountLabel = currencyFmt.format(budget.monthlyAmount);

    // Subtitle text based on current page
    String subtitle;
    switch (_currentPage) {
      case 0:
        subtitle = 'BALANCE OVERVIEW';
        break;
      case 1:
        subtitle = 'BUDGET OVERVIEW';
        break;
      default:
        subtitle = '';
    }

    final bool showStats = widget.showStats;

    return Transform.translate(
      offset: const Offset(0, -12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title pill + subtitle (centered, above sliders)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChartTitlePill(text: budget.title),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: subtitle.isNotEmpty
                      ? Text(
                          subtitle,
                          key: ValueKey(subtitle),
                          style: TextStyle(
                            color: Colors.green.shade300.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        )
                      : const SizedBox(key: ValueKey(''), height: 0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!showStats)
            SizedBox(
              height: _pagerHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pageCount,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Bank balances page
                    return _BankBalancesChartPage(
                      bankLinkService: widget.bankLinkService,
                    );
                  }

                  // For now pages 1 and 2 share the same budget ring data.
                  final bool isHeroPage = index == 1;
                  return BudgetRingChart(
                    amountLabel: amountLabel,
                    values: values,
                    colors: colors,
                    legendCategories: legend,
                    heroTag: isHeroPage ? 'budget_amount_hero' : null,
                    onTapAmount: widget.onTapAmount,
                  );
                },
              ),
            )
          else
            Container(
              height: _pagerHeight,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: BudgetScreenTheme.buttonGreen,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Stats view coming soon',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 4),
          if (!showStats)
            _RingPagerIndicator(
              pageCount: _pageCount,
              currentIndex: _currentPage,
            ),

          // ── Section pills under the chart ────────────────────────────────
          const SizedBox(height: 16),

          // Cash Flow
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _BudgetSectionPill(
              label: 'Cash Flow',
              expanded: _cashFlowExpanded,
              onTap: () {
                setState(() {
                  _cashFlowExpanded = !_cashFlowExpanded;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _CashFlowSection(
                bankLinkService: widget.bankLinkService,
                selectedBudgetId: widget.selectedBudgetId,
              ),
              crossFadeState: _cashFlowExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
          ),
          const SizedBox(height: 12),

          // Upcoming Bills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _BudgetSectionPill(
              label: 'Upcoming Bills',
              expanded: _upcomingBillsExpanded,
              onTap: () {
                setState(() {
                  _upcomingBillsExpanded = !_upcomingBillsExpanded;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                decoration: BoxDecoration(
                  color: BudgetScreenTheme.buttonGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUpcomingSpanHeader(),
                    const SizedBox(height: 8),
                    _UpcomingBillsList(bills: upcomingBills),
                  ],
                ),
              ),
              crossFadeState: _upcomingBillsExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
          ),
          const SizedBox(height: 12),

          // Categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _BudgetSectionPill(
              label: 'Categories',
              expanded: _categoriesExpanded,
              onTap: () {
                setState(() {
                  _categoriesExpanded = !_categoriesExpanded;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _CategoriesSection(
                budget: budget,
                bankLinkService: widget.bankLinkService,
              ),
              crossFadeState: _categoriesExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildUpcomingSpanHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _horizontalChipRow(
          BudgetTimeSpan.values.map((span) {
            final bool selected = span == _upcomingBillsSpan;
            return ChoiceChip(
              label: Text(
                labelForBudgetTimeSpan(span),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? BudgetScreenTheme.plusMint : Colors.white,
                ),
              ),
              selected: selected,
              onSelected: (_) {
                if (span == BudgetTimeSpan.custom) {
                  _pickCustomSpanRange();
                  return;
                }
                setState(() {
                  _upcomingBillsSpan = span;
                });
              },
              selectedColor: const Color(0xFF234036),
              backgroundColor: const Color(0xFF173328),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          _upcomingSpanLabel(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _upcomingSpanLabel() {
    final anchor = AppClock.now();
    final (from, to) = windowForBudgetTimeSpan(
      span: _upcomingBillsSpan,
      anchor: anchor,
      customStart: _customSpanFrom,
      customEnd: _customSpanTo,
    );
    final df = DateFormat('MMM d, yyyy');
    switch (_upcomingBillsSpan) {
      case BudgetTimeSpan.monthly:
        return 'Next 30 days';
      case BudgetTimeSpan.weekly:
        return 'Next 7 days';
      case BudgetTimeSpan.yearly:
        return 'Next 12 months';
      case BudgetTimeSpan.custom:
        return '${df.format(from)} – ${df.format(to)}';
    }
  }

  Future<void> _pickCustomSpanRange() async {
    final now = AppClock.now();
    final initialFrom = _customSpanFrom ?? now;
    final initialTo = _customSpanTo ?? now;
    final initialRange = DateTimeRange(start: initialFrom, end: initialTo);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      helpText: 'Select custom upcoming bills range',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: BudgetScreenTheme.plusMint,
              surface: Color(0xFF0F1C18),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF041412),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _upcomingBillsSpan = BudgetTimeSpan.custom;
      _customSpanFrom = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _customSpanTo = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
    });
  }
}

({IconData icon, Color color}) _flowIconStyle(String flow) {
  switch (flow) {
    case 'income':
      return (icon: Icons.arrow_downward_rounded, color: const Color(0xFF4CD964));
    case 'expense':
      return (icon: Icons.arrow_upward_rounded, color: const Color(0xFFFF6B6B));
    case 'transfer':
      return (icon: Icons.swap_horiz_rounded, color: const Color(0xFF5AC8FA));
    default:
      return (icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF9BA5B3));
  }
}

Widget _transactionPill(BankTransaction t, {VoidCallback? onTap}) {
  final title =
      t.merchant?.isNotEmpty == true ? t.merchant! : (t.name ?? 'Transaction');
  final category = t.category ??
      (t.categoryPath.isNotEmpty ? t.categoryPath.first : 'Uncategorized');
  final isExpense = t.isExpense;
  final amountAbs = t.amount.abs();
  final amountFmt =
      NumberFormat.currency(symbol: '\$').format(amountAbs);
  final flowLabel =
      (t.flow ?? (isExpense ? 'expense' : 'income')).toLowerCase();
  final isTransfer = flowLabel == 'transfer';
  final amountText =
      isTransfer ? amountFmt : (isExpense ? '-$amountFmt' : '+$amountFmt');
  final amountColor = isTransfer
      ? Colors.white70
      : (isExpense ? Colors.red.shade300 : Colors.green.shade300);
  final pending = t.status == 'pending';
  final isManual = t.status.toLowerCase() == 'manual';
  final themeColor = BudgetScreenTheme.buttonGreen;
  final borderColor = Colors.white.withValues(alpha: 0.08);
  final flowIconStyle = _flowIconStyle(flowLabel);
  final iconData = flowIconStyle.icon;
  final iconColor = flowIconStyle.color;

  final pill = Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: themeColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor, width: 1),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            iconData,
            color: iconColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(width: 6),
                    _transactionBadge('Pending', Colors.yellow.shade800),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isManual)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _transactionBadge(
                  'Manual',
                  const Color(0xFF3A5366),
                ),
              ),
            Text(
              amountText,
              style: TextStyle(
                color: amountColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  if (onTap == null) return pill;

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: pill,
  );
}

class _BankBalancesChartPage extends StatefulWidget {
  const _BankBalancesChartPage({required this.bankLinkService});

  final BankLinkService bankLinkService;

  @override
  State<_BankBalancesChartPage> createState() => _BankBalancesChartPageState();
}

class _BankBalancesChartPageState extends State<_BankBalancesChartPage> {
  // Match the actual record type returned by BankLinkService.fetchBalances():
  // ({ double checking, String? currency, bool hasAccounts, double savings })
  late Future<
      ({
        double checking,
        String? currency,
        bool hasAccounts,
        double savings,
      })> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.bankLinkService.fetchBalances().catchError(
      (error) {
        // Return default empty state if bank connection fails
        return (
          checking: 0.0,
          currency: null,
          hasAccounts: false,
          savings: 0.0,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          double checking,
          String? currency,
          bool hasAccounts,
          double savings,
        })>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (snap.hasError || !snap.hasData || !snap.data!.hasAccounts) {
          // Greyed-out "connect your bank" view
          return BudgetRingChart(
            amountLabel: 'Connect a bank account',
            values: const [1.0],
            colors: [Colors.white.withValues(alpha: 0.18)],
            legendCategories: [
              BudgetCategory(
                name: 'Link bank to see balances',
                icon: Icons.link,
                color: Colors.white,
              ),
            ],
          );
        }

        final data = snap.data!;
        final double checking = data.checking;
        final double savings = data.savings;
        final double total = checking + savings;

        final amountLabel = '\$${NumberFormat('#,##0.00').format(total)}';

        final List<double> values = [];
        final List<Color> colors = [];
        final List<BudgetCategory> legend = [];

        if (checking > 0) {
          values.add(checking);
          colors.add(Colors.white);
          legend.add(
            BudgetCategory(
              name: 'Checking',
              icon: Icons.account_balance_wallet,
              color: Colors.white,
            ),
          );
        }
        if (savings > 0) {
          values.add(savings);
          colors.add(Colors.white70);
          legend.add(
            BudgetCategory(
              name: 'Savings',
              icon: Icons.savings,
              color: Colors.white70,
            ),
          );
        }

        if (values.isEmpty) {
          values.add(1.0);
          colors.add(Colors.white.withValues(alpha: 0.18));
          legend.add(
            BudgetCategory(
              name: 'No balance',
              icon: Icons.account_balance_wallet,
              color: Colors.white,
            ),
          );
        }

        return BudgetRingChart(
          amountLabel: amountLabel,
          values: values,
          colors: colors,
          legendCategories: legend,
        );
      },
    );
  }
}

/* ───────────────────────── Small ring UI bits ───────────────────────── */

class _StatsToggleButton extends StatelessWidget {
  const _StatsToggleButton({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = Colors.white.withValues(
      alpha: active ? 0.9 : 0.45,
    ); // thin circle outline
    final Color bg =
        active ? Colors.white.withValues(alpha: 0.08) : Colors.transparent;
    final Color iconColor = Colors.white.withValues(alpha: 0.9);

    return Semantics(
      label: 'Toggle stats view',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Icon(
            Icons.show_chart_rounded,
            size: 18,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _ChartTitlePill extends StatelessWidget {
  const _ChartTitlePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: BudgetScreenTheme.buttonGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RingPagerIndicator extends StatelessWidget {
  const _RingPagerIndicator({
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final bool isActive = index == currentIndex;

        final double width = isActive ? 26 : 8;
        final double height = 8;
        final Color color =
            isActive ? Colors.white : Colors.white.withValues(alpha: 0.35);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

/// Generic budget section pill used for "Cash Flow", "Upcoming Bills", etc.
class _BudgetSectionPill extends StatelessWidget {
  const _BudgetSectionPill({
    required this.label,
    this.expanded = false,
    this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Colors.transparent,
              width: 1.5,
            ),
          ),
          color: const Color(0xFF6B9071),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Data-driven Upcoming Bills list powered by recurrence helper.
class _UpcomingBillsList extends StatelessWidget {
  const _UpcomingBillsList({required this.bills});

  final List<RecurringInstance> bills;

  @override
  Widget build(BuildContext context) {
    // Match the Cash Flow transaction container background.
    final themeColor = BudgetScreenTheme.buttonGreen;
    final borderColor = Colors.white.withValues(alpha: 0.08);
    final dateFmt = DateFormat('EEE, MMM d');
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);

    String relative(DateTime due) {
      final dueDay = DateTime(due.year, due.month, due.day);
      final diff = dueDay.difference(today).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff > 1 && diff <= 7) return 'In $diff days';
      if (diff == -1) return 'Yesterday';
      if (diff < -1 && diff >= -7) return '${-diff} days ago';
      return dateFmt.format(due);
    }

    if (bills.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: const Text(
              'No upcoming bills configured.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    final sorted = [...bills]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final amountFmt = NumberFormat.currency(symbol: '\$');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < sorted.length; i++) ...[
          Builder(builder: (_) {
            final bill = sorted[i];
            final r = bill.expense;
            final dateLabel = dateFmt.format(bill.dueDate);
            final rel = relative(bill.dueDate);
            final amountText = amountFmt.format(r.amountCents / 100.0);
            final iconColor = r.color;
            final iconData = r.icon;

            return Padding(
              padding: EdgeInsets.only(bottom: i == sorted.length - 1 ? 0 : 8),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        iconData,
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dateLabel • $rel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amountText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

/* ───────────────────────── Cash Flow ───────────────────────── */

enum _CashFlowRange { day, week, month, year, custom }

enum _AccountTypeFilter { all, checking, savings, credit }

enum _FlowFilter { all, income, expense, transfer }

class _CashFlowSection extends StatefulWidget {
  const _CashFlowSection({
    required this.bankLinkService,
    required this.selectedBudgetId,
  });

  final BankLinkService bankLinkService;
  final String? selectedBudgetId;

  @override
  State<_CashFlowSection> createState() => _CashFlowSectionState();
}

class _CashFlowSectionState extends State<_CashFlowSection> {
  _CashFlowRange _range = _CashFlowRange.month;
  _AccountTypeFilter _accountFilter = _AccountTypeFilter.all;
  _FlowFilter _flowFilter = _FlowFilter.all;

  String _categoryFilter = 'all';
  List<String> _categoryOptions = <String>[];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Future<CashFlowSnapshot> _future;

  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    final now = AppClock.now();
    _customFrom = DateTime(now.year, now.month, 1);
    _customTo = DateTime(now.year, now.month, now.day);

    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _boundsForRange(_CashFlowRange range) {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case _CashFlowRange.day:
        return today, today;
      case _CashFlowRange.week:
        final from = today.subtract(const Duration(days: 6));
        return from, today;
      case _CashFlowRange.month:
        final from = DateTime(today.year, today.month, 1);
        return from, today;
      case _CashFlowRange.year:
        final from = today.subtract(const Duration(days: 365));
        return from, today;
      case _CashFlowRange.custom:
        final from = _customFrom ?? DateTime(today.year, today.month, 1);
        final to = _customTo ?? today;
        return from, to;
    }
  }

  String? _accountTypeParam() {
    switch (_accountFilter) {
      case _AccountTypeFilter.all:
        return null;
      case _AccountTypeFilter.checking:
        return 'checking';
      case _AccountTypeFilter.savings:
        return 'savings';
      case _AccountTypeFilter.credit:
        return 'credit';
    }
  }

  String? _flowParam() {
    switch (_flowFilter) {
      case _FlowFilter.all:
        return null;
      case _FlowFilter.income:
        return 'income';
      case _FlowFilter.expense:
        return 'expense';
      case _FlowFilter.transfer:
        return 'transfer';
    }
  }

  Future<CashFlowSnapshot> _load() {
    final (from, to) = _boundsForRange(_range);
    return widget.bankLinkService.fetchCashFlowSnapshot(
      from: from,
      to: to,
      accountType: _accountTypeParam(),
      flow: _flowParam(),
      category: _categoryFilter == 'all' ? null : _categoryFilter,
      query: _searchQuery.isNotEmpty ? _searchQuery : null,
      limit: 500,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _setRange(_CashFlowRange range) {
    if (_range == range) {
      if (range == _CashFlowRange.custom) {
        _pickCustomRange();
      }
      return;
    }
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  Future<void> _pickCustomRange() async {
    final now = AppClock.now();
    final (currentFrom, currentTo) = _boundsForRange(_CashFlowRange.custom);
    final initialRange = DateTimeRange(start: currentFrom, end: currentTo);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      helpText: 'Select custom cash flow range',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: BudgetScreenTheme.plusMint,
              surface: Color(0xFF0F1C18),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF041412),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _range = _CashFlowRange.custom;
      _customFrom = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _customTo = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
      _future = _load();
      // Budget vs actual remains month-based; no change here.
    });
  }

  void _retry() {
    _reload();
  }

  void _openTransactionComposer(BankTransaction txn) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateTransactionScreen(
          selectedBudgetId: widget.selectedBudgetId,
          initialTransaction: txn,
          autofocusTitle: false,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  String _labelForRange(_CashFlowRange range) {
    switch (range) {
      case _CashFlowRange.day:
        return 'Day';
      case _CashFlowRange.week:
        return 'Week';
      case _CashFlowRange.month:
        return 'Month';
      case _CashFlowRange.year:
        return 'Year';
      case _CashFlowRange.custom:
        return 'Custom';
    }
  }

  void _updateCategoryOptionsFromTransactions(List<BankTransaction> txns) {
    final cats = <String>{};
    for (final t in txns) {
      final cat = t.category ??
          (t.categoryPath.isNotEmpty ? t.categoryPath.first : 'Uncategorized');
      if (cat.isNotEmpty) cats.add(cat);
    }
    final list = cats.toList()..sort();
    if (!listEquals(list, _categoryOptions)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _categoryOptions = list;
          if (_categoryFilter != 'all' &&
              !_categoryOptions.contains(_categoryFilter)) {
            _categoryFilter = 'all';
          }
        });
      });
    }
  }

  Widget _buildSummaryRow(
    CashFlowSummary summary,
    List<BankTransaction> txns,
    DateTime from,
    DateTime to,
  ) {
    final compactFmt = NumberFormat.compactCurrency(symbol: '\$');
    final fullFmt = NumberFormat.currency(symbol: '\$');

    Widget pill(String label, double value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            compactFmt.format(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
    }

    final netColor =
        summary.net >= 0 ? Colors.green.shade300 : Colors.red.shade300;

    final totalOutflow = summary.outflow.abs();
    final totalDays = math.max(1, to.difference(from).inDays + 1);
    final avgDailySpend = totalOutflow / totalDays;

    final today = AppClock.now();
    final todayKey = DateFormat('yyyy-MM-dd')
        .format(DateTime(today.year, today.month, today.day));
    final dateKeyFmt = DateFormat('yyyy-MM-dd');

    double todaySpend = 0;
    for (final t in txns) {
      final d = t.date;
      if (d == null || !t.isExpense) continue;
      final key = dateKeyFmt.format(DateTime(d.year, d.month, d.day));
      if (key == todayKey) {
        todaySpend += t.amount.abs();
      }
    }

    double? projection;
    if (_range == _CashFlowRange.month) {
      final periodStart = DateTime(from.year, from.month, from.day);
      final periodEnd = DateTime(to.year, to.month, to.day);
      var clampedToday = DateTime(today.year, today.month, today.day);
      if (clampedToday.isBefore(periodStart)) clampedToday = periodStart;
      if (clampedToday.isAfter(periodEnd)) clampedToday = periodEnd;
      var daysElapsed = clampedToday.difference(periodStart).inDays + 1;
      daysElapsed = math.max(1, daysElapsed);
      final projectedPerDay = summary.net / daysElapsed;
      projection = projectedPerDay * totalDays;
    }

    final todayLabel =
        'Today ${fullFmt.format(todaySpend)} (avg ${fullFmt.format(avgDailySpend)}/day)';
    final String? projectionLabel = projection == null
        ? null
        : 'On track: ${fullFmt.format(projection)} this month';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              pill('Inflow', summary.inflow, Colors.green.shade300),
              pill('Outflow', summary.outflow, Colors.red.shade300),
              pill('Net', summary.net, netColor),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todayLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (projectionLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  projectionLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    Widget buildAccountBlock() {
      String labelFor(_AccountTypeFilter f) {
        switch (f) {
          case _AccountTypeFilter.all:
            return 'All';
          case _AccountTypeFilter.checking:
            return 'Checking';
          case _AccountTypeFilter.savings:
            return 'Savings';
          case _AccountTypeFilter.credit:
            return 'Credit';
        }
      }

      final chips = _AccountTypeFilter.values.map((f) {
        final selected = f == _accountFilter;
        return ChoiceChip(
          label: Text(
            labelFor(f),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? BudgetScreenTheme.plusMint : Colors.white,
            ),
          ),
          selected: selected,
          onSelected: (_) {
            if (selected) return;
            setState(() {
              _accountFilter = f;
            });
            _reload();
          },
          selectedColor: const Color(0xFF234036),
          backgroundColor: const Color(0xFF173328),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide.none,
        );
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accounts',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _horizontalChipRow(chips),
        ],
      );
    }

    Widget buildFlowBlock() {
      String labelFor(_FlowFilter f) {
        switch (f) {
          case _FlowFilter.all:
            return 'All';
          case _FlowFilter.income:
            return 'Income';
          case _FlowFilter.expense:
            return 'Expenses';
          case _FlowFilter.transfer:
            return 'Transfers';
        }
      }

      final chips = _FlowFilter.values.map((f) {
        final selected = f == _flowFilter;
        return ChoiceChip(
          label: Text(
            labelFor(f),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? BudgetScreenTheme.plusMint : Colors.white,
            ),
          ),
          selected: selected,
          onSelected: (_) {
            if (selected) return;
            setState(() {
              _flowFilter = f;
            });
            _reload();
          },
          selectedColor: const Color(0xFF234036),
          backgroundColor: const Color(0xFF173328),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide.none,
        );
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Flow',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _horizontalChipRow(chips),
        ],
      );
    }

    Widget buildCategoryBlock() {
      final chips = <Widget>[
        FilterChip(
          label: const Text(
            'All',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: _categoryFilter == 'all',
          onSelected: (_) {
            if (_categoryFilter == 'all') return;
            setState(() {
              _categoryFilter = 'all';
            });
            _reload();
          },
          selectedColor: const Color(0xFF234036),
          backgroundColor: const Color(0xFF173328),
          labelStyle: TextStyle(
            color: _categoryFilter == 'all'
                ? BudgetScreenTheme.plusMint
                : Colors.white,
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide.none,
        ),
        ..._categoryOptions.map((cat) {
          final selected = _categoryFilter == cat;
          return FilterChip(
            label: Text(
              cat,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: selected,
            onSelected: (_) {
              if (selected) return;
              setState(() {
                _categoryFilter = cat;
              });
              _reload();
            },
            selectedColor: const Color(0xFF234036),
            backgroundColor: const Color(0xFF173328),
            labelStyle: TextStyle(
              color: selected ? BudgetScreenTheme.plusMint : Colors.white,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            side: BorderSide.none,
          );
        }),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categories',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _horizontalChipRow(chips),
        ],
      );
    }

    Widget buildSearchField() {
      return TextField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
        ),
        cursorColor: BudgetScreenTheme.plusMint,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search merchants or names',
          hintStyle: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 16,
            color: Colors.white70,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white54,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _reload();
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF173328),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onSubmitted: (value) {
          setState(() {
            _searchQuery = value.trim();
          });
          _reload();
        },
      );
    }

    Widget buildRangeBlock() {
      final chips = _CashFlowRange.values.map((r) {
        final bool selected = r == _range;
        return ChoiceChip(
          label: Text(
            _labelForRange(r),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? BudgetScreenTheme.plusMint : Colors.white,
            ),
          ),
          selected: selected,
          onSelected: (_) {
            if (r == _CashFlowRange.custom) {
              _pickCustomRange();
            } else {
              _setRange(r);
            }
          },
          selectedColor: const Color(0xFF234036),
          backgroundColor: const Color(0xFF173328),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide.none,
        );
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Period',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _horizontalChipRow(chips),
        ],
      );
    }

    // NOTE: Search bar moved *below* the Period block
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, // ensure left alignment
      children: [
        buildAccountBlock(),
        const SizedBox(height: 6),
        buildFlowBlock(),
        const SizedBox(height: 6),
        buildCategoryBlock(),
        const SizedBox(height: 6),
        buildRangeBlock(),
        const SizedBox(height: 10),
        buildSearchField(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BudgetScreenTheme.buttonGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilters(),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: BudgetBoxes.tx.listenable(),
            builder: (_, __, ___) {
              return FutureBuilder<CashFlowSnapshot>(
                future: _future,
                builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (snap.hasError) {
                final err = snap.error;
                final String errText = err?.toString() ?? '';
                final bool offline = err is BankApiOfflineException ||
                    errText.contains('UNREACHABLE') ||
                    errText.contains('TIMEOUT');

                final msg = offline
                    ? 'Can’t reach Kontinuum server. Is it running?'
                    : 'Unable to load cash flow.';
                return _CashFlowErrorBanner(
                  message: msg,
                  onRetry: _retry,
                );
              }

              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No data available for this period.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }

              final data = snap.data!;
              final serverTxns = data.transactions;
              final (from, to) = _boundsForRange(_range);

              final manualTxns = _manualTransactionsForRange(
                from: from,
                to: to,
                accountType: _accountTypeParam(),
                flow: _flowParam(),
                category: _categoryFilter == 'all' ? null : _categoryFilter,
                query: _searchQuery.isNotEmpty ? _searchQuery : null,
              );

              final txns = <BankTransaction>[
                ...serverTxns,
                ...manualTxns,
              ]..sort((a, b) {
                  final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bd.compareTo(ad);
                });

              final summary =
                  _summaryWithManual(data.summary, manualTxns, from, to);

              _updateCategoryOptionsFromTransactions(txns);

              if (txns.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (summary != null)
                      _buildSummaryRow(summary, txns, from, to),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No transactions in this period.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final children = <Widget>[];

              if (summary != null) {
                children.add(_buildSummaryRow(summary, txns, from, to));
              }

              // Group by date string YYYY-MM-DD
              final byDay = <String, List<BankTransaction>>{};
              final dateKeyFmt = DateFormat('yyyy-MM-dd');
              for (final t in txns) {
                final d = t.date;
                final key = d != null ? dateKeyFmt.format(d) : 'Unknown';
                byDay.putIfAbsent(key, () => []).add(t);
              }

              final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

              final todayNow = AppClock.now();
              final todayKey = dateKeyFmt.format(todayNow);
              final yesterdayKey =
                  dateKeyFmt.format(todayNow.subtract(const Duration(days: 1)));
              final dayLabelFmt = DateFormat('EEE, MMM d');

              for (final key in keys) {
                final list = byDay[key]!;
                DateTime? parsed;
                try {
                  parsed = DateTime.parse(key);
                } catch (_) {}

                final label = key == todayKey
                    ? 'Today'
                    : key == yesterdayKey
                        ? 'Yesterday'
                        : (parsed != null ? dayLabelFmt.format(parsed) : key);

                children.add(
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );

                children.add(
                  Column(
                    children: [
                      for (final entry in list.asMap().entries)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom:
                                  entry.key == list.length - 1 ? 0 : 8),
                          child: _transactionPill(
                            entry.value,
                            onTap: () => _openTransactionComposer(entry.value),
                          ),
                        ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Categories dropdown ───────────────────────── */

enum _CategoryRange { automatic, week, year, custom }

class _CategoriesSection extends StatefulWidget {
  const _CategoriesSection({
    required this.budget,
    required this.bankLinkService,
  });

  final Budget budget;
  final BankLinkService bankLinkService;

  @override
  State<_CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<_CategoriesSection> {
  _CategoryRange _range = _CategoryRange.automatic;

  DateTime? _customFrom;
  DateTime? _customTo;

  late Future<CashFlowSnapshot> _future;

  String? _selectedCategoryName;
  final ScrollController _categoryListController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = AppClock.now();
    _customFrom = DateTime(now.year, now.month, 1);
    _customTo = DateTime(now.year, now.month, now.day);

    if (widget.budget.categories.isNotEmpty) {
      _selectedCategoryName = widget.budget.categories.first.name;
    }

    _future = _load();
  }

  @override
  void dispose() {
    _categoryListController.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _boundsForRange(_CategoryRange range) {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case _CategoryRange.automatic:
        final from = DateTime(today.year, today.month, 1);
        return from, today;
      case _CategoryRange.week:
        final from = today.subtract(const Duration(days: 6));
        return from, today;
      case _CategoryRange.year:
        final from = today.subtract(const Duration(days: 365));
        return from, today;
      case _CategoryRange.custom:
        final from = _customFrom ?? DateTime(today.year, today.month, 1);
        final to = _customTo ?? today;
        return from, to;
    }
  }

  Future<CashFlowSnapshot> _load() {
    final (from, to) = _boundsForRange(_range);
    // For categories, we care about expenses only.
    return widget.bankLinkService.fetchCashFlowSnapshot(
      from: from,
      to: to,
      accountType: null,
      flow: 'expense',
      category: null,
      query: null,
      limit: 500,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _setRange(_CategoryRange range) {
    if (_range == range) {
      if (range == _CategoryRange.custom) {
        _pickCustomRange();
      }
      return;
    }
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  Future<void> _pickCustomRange() async {
    final now = AppClock.now();
    final (currentFrom, currentTo) = _boundsForRange(_CategoryRange.custom);
    final initialRange = DateTimeRange(start: currentFrom, end: currentTo);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      helpText: 'Select custom period for categories',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: BudgetScreenTheme.plusMint,
              surface: Color(0xFF0F1C18),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF041412),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _range = _CategoryRange.custom;
      _customFrom = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _customTo = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
      _future = _load();
    });
  }

  String _labelForRange(_CategoryRange range) {
    switch (range) {
      case _CategoryRange.automatic:
        return 'Auto (Monthly)';
      case _CategoryRange.week:
        return 'Week';
      case _CategoryRange.year:
        return 'Year';
      case _CategoryRange.custom:
        return 'Custom';
    }
  }

  String _rangeDescriptionLabel() {
    final (from, to) = _boundsForRange(_range);
    final df = DateFormat('MMM d, yyyy');
    switch (_range) {
      case _CategoryRange.automatic:
        return 'This month';
      case _CategoryRange.week:
        return 'Last 7 days';
      case _CategoryRange.year:
        return 'Last 12 months';
      case _CategoryRange.custom:
        return '${df.format(from)} – ${df.format(to)}';
    }
  }

  Map<String, int> _computeMonthlyCategoryTotals() {
    final map = <String, int>{};
    for (final c in widget.budget.categories) {
      map[c.name] = 0;
    }
    for (final rec in widget.budget.recurrings) {
      final cat = rec.category;
      if (cat == null) continue;
      final cents = normalizedMonthlyCents(rec);
      map[cat.name] = map[cat.name] ?? 0) + cents;
    }
    return map;
  }

  List<BankTransaction> _filterForCategory(
    List<BankTransaction> all,
    String? categoryName,
  ) {
    if (categoryName == null) return all;
    final wanted = categoryName.toLowerCase();
    return all.where((t) {
      final cat = t.category ??
          (t.categoryPath.isNotEmpty ? t.categoryPath.first : null);
      if (cat == null) return false;
      return cat.toLowerCase() == wanted;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final budget = widget.budget;
    final monthlyTotals = _computeMonthlyCategoryTotals();
    final int budgetMonthlyCents = budget.monthlyAmount * 100;

    final hasBudget = budgetMonthlyCents > 0;
    final rangeLabel = _rangeDescriptionLabel();

    // Make sure selected category name always exists if there are categories.
    String? effectiveSelected = _selectedCategoryName;
    if (budget.categories.isNotEmpty) {
      if (effectiveSelected == null ||
          !budget.categories.any((c) => c.name == effectiveSelected)) {
        effectiveSelected = budget.categories.first.name;
      }
    } else {
      effectiveSelected = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: BudgetScreenTheme.buttonGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.pie_chart_outline_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              const Text(
                'Category breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                rangeLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'See how each category contributes to your budget and the transactions inside it.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),

          // Time span chips
          _buildRangeChips(),

          const SizedBox(height: 10),

          if (budget.categories.isEmpty)
            const Text(
              'Add categories to your budget to see a breakdown here.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            )
          else if (!hasBudget)
            const Text(
              'Set a monthly amount on this budget to see category percentages.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            )
          else ...[
            _buildCategoryList(
              budget: budget,
              monthlyTotals: monthlyTotals,
              budgetMonthlyCents: budgetMonthlyCents,
              selectedName: effectiveSelected,
            ),
            const SizedBox(height: 12),
            _buildTransactionsSection(effectiveSelected, rangeLabel),
          ],
        ],
      ),
    );
  }

  Widget _buildRangeChips() {
    final chips = _CategoryRange.values.map((r) {
      final bool selected = r == _range;
      return ChoiceChip(
        label: Text(
          _labelForRange(r),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? BudgetScreenTheme.plusMint : Colors.white,
          ),
        ),
        selected: selected,
        onSelected: (_) {
          if (r == _CategoryRange.custom) {
            _pickCustomRange();
          } else {
            _setRange(r);
          }
        },
        selectedColor: const Color(0xFF234036),
        backgroundColor: const Color(0xFF173328),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        side: BorderSide.none,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Period',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        _horizontalChipRow(chips),
      ],
    );
  }

  Widget _buildCategoryList({
    required Budget budget,
    required Map<String, int> monthlyTotals,
    required int budgetMonthlyCents,
    required String? selectedName,
  }) {
    final tiles = <Widget>[];
    final total = budgetMonthlyCents <= 0 ? 0 : budgetMonthlyCents;

    for (final cat in budget.categories) {
      final cents = monthlyTotals[cat.name] ?? 0;
      final double fraction = total > 0 ? cents / total : 0.0;
      final double percent = fraction * 100.0;
      final bool selected = cat.name == selectedName;

      final amountLabel =
          NumberFormat.currency(symbol: '\$').format(cents / 100.0);

      tiles.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategoryName = cat.name;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color:
                  selected ? const Color(0xFF234036) : const Color(0xFF173328),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? BudgetScreenTheme.plusMint.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.08),
                width: selected ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: [
                _MiniCategoryRing(
                  fraction: fraction,
                  color: cat.color,
                  label: '${percent.round()}%',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${percent.toStringAsFixed(0)}% of monthly budget',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amountLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (tiles.isEmpty) {
      return const Text(
        'No categories found.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 220,
      ),
      child: Scrollbar(
        controller: _categoryListController,
        thumbVisibility: tiles.length > 3,
        child: ListView(
          controller: _categoryListController,
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          children: tiles,
        ),
      ),
    );
  }

  Widget _buildTransactionsSection(
    String? selectedCategoryName,
    String rangeLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedCategoryName == null
              ? 'Transactions in $rangeLabel'
              : 'Transactions in $rangeLabel • $selectedCategoryName',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder(
          valueListenable: BudgetBoxes.tx.listenable(),
          builder: (_, __, ___) {
            return FutureBuilder<CashFlowSnapshot>(
              future: _future,
              builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (snap.hasError) {
              final err = snap.error;
              final String errText = err?.toString() ?? '';
              final bool offline = err is BankApiOfflineException ||
                  errText.contains('UNREACHABLE') ||
                  errText.contains('TIMEOUT');

              final msg = offline
                  ? 'Can’t reach Kontinuum server. Is it running?'
                  : 'Unable to load transactions for this period.';
              return _CashFlowErrorBanner(
                message: msg,
                onRetry: _reload,
              );
            }

            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No transaction data available.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              );
            }

            final snapshot = snap.data!;
            final allTxns = snapshot.transactions;
            final filtered = _filterForCategory(allTxns, selectedCategoryName);
            final (from, to) = _boundsForRange(_range);
            final manualTxns = _manualTransactionsForRange(
              from: from,
              to: to,
              accountType: null,
              flow: 'expense',
              category: selectedCategoryName,
              query: null,
            );
            final txns = <BankTransaction>[
              ...filtered,
              ...manualTxns,
            ]..sort((a, b) {
                final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bd.compareTo(ad);
              });

            if (txns.isEmpty) {
              final catLabel = selectedCategoryName ?? 'this period';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No transactions for $catLabel in $rangeLabel.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              );
            }

            // Group by date like in Cash Flow.
            final byDay = <String, List<BankTransaction>>{};
            final dateKeyFmt = DateFormat('yyyy-MM-dd');
            for (final t in txns) {
              final d = t.date;
              final key = d != null ? dateKeyFmt.format(d) : 'Unknown';
              byDay.putIfAbsent(key, () => []).add(t);
            }

            final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

            final todayNow = AppClock.now();
            final todayKey = dateKeyFmt.format(todayNow);
            final yesterdayKey =
                dateKeyFmt.format(todayNow.subtract(const Duration(days: 1)));
            final dayLabelFmt = DateFormat('EEE, MMM d');

            final children = <Widget>[];

            for (final key in keys) {
              final list = byDay[key]!;
              DateTime? parsed;
              try {
                parsed = DateTime.parse(key);
              } catch (_) {}

              final label = key == todayKey
                  ? 'Today'
                  : key == yesterdayKey
                      ? 'Yesterday'
                      : (parsed != null ? dayLabelFmt.format(parsed) : key);

              children.add(
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );

              children.add(
                Column(
                  children: [
                    for (int i = 0; i < list.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: i == list.length - 1 ? 0 : 8),
                        child: _transactionPill(list[i]),
                      ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            );
              },
            );
          },
        ),
      ],
    );
  }
}

List<BankTransaction> _manualTransactionsForRange({
  required DateTime from,
  required DateTime to,
  String? accountType,
  String? flow,
  String? category,
  String? query,
}) {
  if (!Hive.isBoxOpen(BudgetBoxes.txBoxName)) return const [];
  final box = BudgetBoxes.tx;
  final List<BankTransaction> manual = [];
  final dateStart = DateTime(from.year, from.month, from.day);
  final dateEnd = DateTime(to.year, to.month, to.day);
  final accountFilter = accountType?.toLowerCase();
  final flowFilter = flow?.toLowerCase();
  final categoryFilter = category?.toLowerCase();
  final queryFilter = query?.toLowerCase();

  for (final txn in box.values) {
    if (!txn.manual) continue;
    final date = txn.date;
    if (date == null) continue;
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(dateStart) || day.isAfter(dateEnd)) continue;

    if (accountFilter != null && accountFilter.isNotEmpty) {
      final type = txn.accountType ?? 'manual').toLowerCase();
      if (type != accountFilter) continue;
    }

    final txnFlow =
        (txn.flow ?? (txn.isExpense ? 'expense' : 'income')).toLowerCase();
    if (flowFilter != null && flowFilter.isNotEmpty) {
      if (txnFlow != flowFilter) continue;
    }

    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      final txnCat = txn.category ?? '').toLowerCase();
      if (txnCat != categoryFilter) continue;
    }

    if (queryFilter != null && queryFilter.isNotEmpty) {
      final haystack = <String>[];
      if (txn.merchant != null) haystack.add(txn.merchant!.toLowerCase());
      if (txn.memo != null) haystack.add(txn.memo!.toLowerCase());
      if (txn.accountName != null) {
        haystack.add(txn.accountName!.toLowerCase());
      }
      if (!haystack.any((s) => s.contains(queryFilter))) continue;
    }

    manual.add(_manualToBankTransaction(txn));
  }

  manual.sort((a, b) {
    final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bd.compareTo(ad);
  });
  return manual;
}

BankTransaction _manualToBankTransaction(BudgetTransaction txn) {
  final cents = txn.amountCents.abs();
  final signedCents = txn.isExpense ? -cents : cents;
  final amount = signedCents / 100.0;
  final label = txn.merchant?.isNotEmpty == true
      ? txn.merchant!
      : (txn.memo?.isNotEmpty == true
          ? txn.memo!
          : (txn.accountName ?? 'Manual transaction'));

  return (
    id: txn.id,
    accountId: txn.accountId,
    accountName: txn.accountName,
    date: txn.date,
    amount: amount.toDouble(),
    amountCents: signedCents,
    isExpense: txn.isExpense,
    status: txn.status,
    name: label,
    merchant: txn.merchant,
    categoryPath: const [],
    pendingTransactionId: txn.pendingTransactionId,
    currency: txn.currency,
    accountType: txn.accountType ?? 'manual',
    flow: (txn.flow ?? (txn.isExpense ? 'expense' : 'income')).toLowerCase(),
    category: txn.category,
  );
}

CashFlowSummary? _summaryWithManual(
  CashFlowSummary? base,
  List<BankTransaction> manual,
  DateTime from,
  DateTime to,
) {
  if (manual.isEmpty) return base;
  final delta = _manualSummaryDelta(manual);
  if (delta.inflow == 0 && delta.outflow == 0 && delta.net == 0) {
    return base;
  }
  if (base == null) {
    return (
      from: from,
      to: to,
      inflow: delta.inflow,
      outflow: delta.outflow,
      net: delta.net,
    );
  }
  return (
    from: base.from ?? from,
    to: base.to ?? to,
    inflow: base.inflow + delta.inflow,
    outflow: base.outflow + delta.outflow,
    net: base.net + delta.net,
  );
}

({double inflow, double outflow, double net}) _manualSummaryDelta(
    List<BankTransaction> manual) {
  double inflow = 0;
  double outflow = 0;
  for (final t in manual) {
    final amt = t.amount.abs();
    final flow = t.flow ?? (t.isExpense ? 'expense' : 'income')).toLowerCase();
    if (flow == 'income') {
      inflow += amt;
    } else if (flow == 'expense') {
      // Treat outflows as positive magnitudes to match the API summary,
      // which returns outflow as a positive number.
      outflow += amt;
    }
  }
  return inflow: inflow, outflow: outflow, net: inflow - outflow;
}

class _MiniCategoryRing extends StatelessWidget {
  const _MiniCategoryRing({
    required this.fraction,
    required this.color,
    required this.label,
  });

  final double fraction;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: clamped == 0.0 ? 0.0 : clamped,
            strokeWidth: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Error banner ───────────────────────── */

class _CashFlowErrorBanner extends StatelessWidget {
  const _CashFlowErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF402222).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: BudgetScreenTheme.plusMint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
