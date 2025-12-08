// lib/ui/screens/budget/create_transaction_screen.dart
// Reuses the objective creator UI with budget-friendly labels + categories.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';
import '../create_objective_screen.dart';

class CreateTransactionScreen extends StatelessWidget {
  const CreateTransactionScreen({
    super.key,
    this.initialTitle,
    this.autofocusTitle = true,
    this.showDelete = false,
    this.onDelete,
    this.selectedBudgetId,
    this.initialTransaction,
  });

  final String? initialTitle;
  final bool autofocusTitle;
  final bool showDelete;
  final VoidCallback? onDelete;
  final String? selectedBudgetId;
  final BankTransaction? initialTransaction;

  @override
  Widget build(BuildContext context) {
    final txn = initialTransaction;
    final budgetProvider = context.watch<BudgetProvider>();
    final budgets = budgetProvider.budgets;
    Budget? budget;
    if (budgets.isNotEmpty) {
      budget = budgets.firstWhere(
        (b) => b.id == selectedBudgetId,
        orElse: () => budgets.first,
      );
    }

    final categories = budget?.categories ?? const <BudgetCategory>[];
    final catTuples = categories
        .map((c) => (id: c.name, name: c.name, colorInt: c.color.toARGB32()))
        .toList(growable: false);
    final List<String> accountOptions = _accountOptions(txn);
    final bool effectiveAutofocus = autofocusTitle && txn == null;

    final String? effectiveTitle =
        initialTitle ?? _transactionTitle(txn);

    return CreateObjectiveScreen(
      initialTitle: effectiveTitle,
      autofocusTitle: effectiveAutofocus,
      showDelete: showDelete,
      onDelete: onDelete,
      categoryLabel: 'Budget Category',
      typeLabel: 'Amount',
      repetitionLabel: 'Repetition',
      xpLabel: 'Cash Flow',
      statsLabel: 'Account',
      descriptionLabel: 'Description',
      showDescriptionTab: true,
      categoryOverride: catTuples.isEmpty ? null : catTuples,
      useAmountSlider: true,
      useAccountPills: true,
      accountOptions: accountOptions,
      useCashflowPills: true,
      cashflowOptions: const ['Income', 'Expense', 'Transfer'],
    );
  }

  String? _transactionTitle(BankTransaction? txn) {
    if (txn == null) return null;
    if (txn.merchant?.isNotEmpty == true) return txn.merchant;
    if (txn.name?.isNotEmpty == true) return txn.name;
    return null;
  }

  String? _transactionAccountLabel(BankTransaction? txn) {
    if (txn == null) return null;
    final name = txn.accountName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final type = txn.accountType;
    if (type != null && type.trim().isNotEmpty) {
      final lower = type.trim();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }
    return null;
  }

  List<String> _accountOptions(BankTransaction? txn) {
    final options = <String>[];
    final label = _transactionAccountLabel(txn);
    if (label != null && label.isNotEmpty && !options.contains(label)) {
      options.add(label);
    }
    if (!options.contains('Manual Account')) {
      options.add('Manual Account');
    }
    return options;
  }
}
