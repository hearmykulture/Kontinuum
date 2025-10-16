import 'package:flutter/material.dart';

class BudgetOnboarding extends StatelessWidget {
  const BudgetOnboarding({
    super.key,
    required this.step,
    required this.accent,
    required this.cardColor,
    required this.budgetCtrl,
    required this.monthlyBudget,
    required this.onMonthlyBudgetChanged,
    required this.categories,
    required this.categoryColors,
    required this.onAddOrEditCategory,
    required this.onDeleteCategory,
    required this.recurring,
    required this.onAddOrEditRecurring,
    required this.onDeleteRecurring,
    required this.fmtCurrency,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  final int step;
  final Color accent;
  final Color cardColor;

  final TextEditingController budgetCtrl;
  final int monthlyBudget;
  final void Function(int) onMonthlyBudgetChanged;

  final List<Map<String, dynamic>> categories;
  final List<Color> categoryColors;
  final Future<void> Function({Map<String, dynamic>? existing})
  onAddOrEditCategory;
  final void Function(Map<String, dynamic>) onDeleteCategory;

  final List<Map<String, dynamic>> recurring;
  final Future<void> Function({Map<String, dynamic>? existing})
  onAddOrEditRecurring;
  final void Function(Map<String, dynamic>) onDeleteRecurring;

  final String Function(num) fmtCurrency;

  final VoidCallback onClose;
  final VoidCallback onBack;
  final Future<void> Function() onNext;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _stepsHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (step) {
              0 => _stepBudget(context),
              1 => _stepCategories(context),
              _ => _stepRecurring(context),
            },
          ),
        ),
        _navBar(),
      ],
    );
  }

  // ---- steps ----

  Widget _stepBudget(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title("Monthly Budget"),
              const SizedBox(height: 8),
              const Text(
                "Set your total monthly spending limit.",
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "e.g. 2500",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.attach_money, color: accent),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v.replaceAll(',', '').trim());
                  onMonthlyBudgetChanged(
                    (parsed == null || parsed < 0) ? 0 : parsed,
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [2000, 2500, 3000].map((amt) {
                  return ChoiceChip(
                    label: Text("$amt"),
                    selected: monthlyBudget == amt,
                    onSelected: (_) {
                      budgetCtrl.text = "$amt";
                      onMonthlyBudgetChanged(amt);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepCategories(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title("Categories"),
              const SizedBox(height: 8),
              const Text(
                "Create a few categories you plan to spend in.",
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                _ghostCard("No categories yet. Add your first one below.")
              else
                ...categories.map((c) => _categoryTile(c)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onAddOrEditCategory(),
                  icon: Icon(Icons.add, color: accent),
                  label: Text("Add Category", style: TextStyle(color: accent)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepRecurring(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title("Recurring Expenses"),
              const SizedBox(height: 8),
              const Text(
                "Add bills or subscriptions that repeat monthly.",
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 12),
              if (recurring.isEmpty)
                _ghostCard("No recurring expenses yet.")
              else
                ...recurring.map((e) => _recurringTile(e)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onAddOrEditRecurring(),
                  icon: Icon(Icons.add_card, color: accent),
                  label: Text("Add Recurring", style: TextStyle(color: accent)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- tiles & helpers ----

  Widget _categoryTile(Map<String, dynamic> cat) {
    final color = Color(cat['color'] as int);
    final name = cat['name'] as String? ?? 'Category';
    final cap = (cat['cap'] as int?) ?? 0;

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
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Text(
            cap > 0 ? fmtCurrency(cap) : "No cap",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
            onPressed: () => onAddOrEditCategory(existing: cat),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => onDeleteCategory(cat),
          ),
        ],
      ),
    );
  }

  Widget _recurringTile(Map<String, dynamic> e) {
    final name = e['name'] as String? ?? 'Recurring';
    final amount = e['amount'] as int? ?? 0;
    final day = e['day'] as int? ?? 1;

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
          const Icon(Icons.repeat, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$name (day $day)",
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
            tooltip: 'Edit',
            icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
            onPressed: () => onAddOrEditRecurring(existing: e),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => onDeleteRecurring(e),
          ),
        ],
      ),
    );
  }

  // chrome

  Widget _stepsHeader() {
    final steps = ['Budget', 'Categories', 'Recurring'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active = i == step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: EdgeInsets.only(right: i < steps.length - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: active ? accent.withOpacity(.15) : cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? accent : Colors.white12,
                  width: active ? 1.2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  steps[i],
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _navBar() {
    final isFirst = step == 0;
    final isLast = step == 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isFirst ? onClose : onBack,
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
                child: Text(
                  isFirst ? "Close" : "Back",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isLast ? onFinish : onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isLast ? "Finish" : "Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // minis
  Widget _card({required Widget child}) => Card(
    color: cardColor,
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
