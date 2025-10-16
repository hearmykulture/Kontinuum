import 'dart:math';
import 'package:flutter/material.dart';

class BudgetOverview extends StatelessWidget {
  const BudgetOverview({
    super.key,
    required this.selectedDate,
    required this.monthlyBudget,
    required this.categories,
    required this.recurring,
    required this.dailyFor,
    required this.sumDailyFor,
    required this.sumDailyForMonth,
    required this.sumRecurring,
    required this.fmtCurrency,
    required this.onAddDaily,
    required this.onDeleteDaily,
    required this.onJumpToAddRecurring,
    required this.onJumpToEditCategories,
  });

  final DateTime selectedDate;
  final int monthlyBudget;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> recurring;

  final List<Map<String, dynamic>> Function(DateTime) dailyFor;
  final int Function(DateTime) sumDailyFor;
  final int Function(DateTime) sumDailyForMonth;
  final int Function() sumRecurring;
  final String Function(num) fmtCurrency;

  final VoidCallback onAddDaily;
  final void Function(DateTime date, String id) onDeleteDaily;
  final VoidCallback onJumpToAddRecurring;
  final VoidCallback onJumpToEditCategories;

  static const _accent = Colors.deepPurpleAccent;
  static const _cardColor = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    final recurringSum = sumRecurring();
    final monthlyLeft = max(0, monthlyBudget - recurringSum);
    final todaysTotal = sumDailyFor(selectedDate);
    final monthTotal = sumDailyForMonth(selectedDate);
    final dayLabel = MaterialLocalizations.of(
      context,
    ).formatFullDate(selectedDate);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title("Monthly Budget"),
              const SizedBox(height: 8),
              Text(
                fmtCurrency(monthlyBudget),
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: monthlyBudget == 0
                    ? 0
                    : (recurringSum / monthlyBudget).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.white10,
                color: _accent,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 6),
              Text(
                "${fmtCurrency(recurringSum)} recurring • ${fmtCurrency(monthlyLeft)} left",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Daily section
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                title: "Daily Expenses",
                subtitle: dayLabel,
                trailing: TextButton.icon(
                  onPressed: onAddDaily,
                  icon: const Icon(Icons.add, color: _accent),
                  label: const Text(
                    "Add Expense",
                    style: TextStyle(color: _accent),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _totalChip("Total today", fmtCurrency(todaysTotal)),
                  _totalChip("Month total", fmtCurrency(monthTotal)),
                ],
              ),
              const SizedBox(height: 12),
              _dailyList(selectedDate),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Categories
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title("Categories"),
              const SizedBox(height: 10),
              if (categories.isEmpty)
                const Text(
                  "No categories yet.",
                  style: TextStyle(color: Colors.white54),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((c) {
                    final color = Color(c['color'] as int);
                    final name = c['name'] as String? ?? 'Category';
                    final cap = (c['cap'] as int?) ?? 0;
                    return _categoryChip(name, color, cap);
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Recurring
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title("Recurring Expenses"),
              const SizedBox(height: 8),
              if (recurring.isEmpty)
                const Text(
                  "No recurring expenses added.",
                  style: TextStyle(color: Colors.white54),
                )
              else
                Column(
                  children: recurring.map((e) {
                    final name = e['name'] as String? ?? 'Recurring';
                    final amount = e['amount'] as int? ?? 0;
                    final day = e['day'] as int? ?? 1;
                    final catId = e['categoryId'] as String?;
                    final catName =
                        categories.firstWhere(
                              (c) => c['id'] == catId,
                              orElse: () => {'name': 'General'},
                            )['name']
                            as String;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "Every month on day $day • $catName",
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Text(
                        fmtCurrency(amount),
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onJumpToAddRecurring,
                icon: const Icon(Icons.add_card),
                label: const Text("Add Recurring"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onJumpToEditCategories,
                icon: const Icon(
                  Icons.category_outlined,
                  color: Colors.white70,
                ),
                label: const Text(
                  "Edit Categories",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- internals (pure UI helpers) ----
  Widget _dailyList(DateTime date) {
    final items = dailyFor(date);
    if (items.isEmpty) {
      return _ghostCard("No daily expenses yet. Tap “Add Expense”.");
    }

    return Column(
      children: items.map((e) {
        final name = (e['name'] as String?)?.trim().isNotEmpty == true
            ? e['name'] as String
            : 'Expense';
        final amount = e['amount'] as int? ?? 0;
        final catId = e['categoryId'] as String?;
        final cat = categories.firstWhere(
          (c) => c['id'] == catId,
          orElse: () => {
            'name': 'Unassigned',
            'color': Colors.white.toARGB32(),
          },
        );
        final color = Color(cat['color'] as int);
        final catName = cat['name'] as String;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  "$name • $catName",
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                fmtCurrency(amount),
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => onDeleteDaily(date, e['id'] as String),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _card({required Widget child}) => Card(
    color: _cardColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _ghostCard(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white54)),
  );

  Widget _sectionHeader({
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(title),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white60)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _totalChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Added: category chip helper that was missing
  Widget _categoryChip(String name, Color color, int cap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(color: Colors.white)),
          if (cap > 0) ...[
            const SizedBox(width: 6),
            Text(
              "• ${fmtCurrency(cap)}",
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: Colors.white,
      ),
    );
  }
}
