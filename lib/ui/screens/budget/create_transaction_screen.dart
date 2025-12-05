// lib/ui/screens/budget/create_transaction_screen.dart
// Reuses the objective creator UI with budget-friendly labels + categories.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/providers/transactions_provider.dart';
import 'package:kontinuum/models/manual_transaction_draft.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';
import 'package:kontinuum/services/bank_link_service.dart';
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

  Future<bool> _handleSubmit(
    BuildContext context,
    ObjectiveFormSubmission submission,
  ) async {
    final flowRaw = submission.selectedCashflow;
    if (flowRaw == null || flowRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a cash flow type.')),
      );
      return false;
    }

    final normalizedFlow = flowRaw.toLowerCase();
    const allowedFlows = {'income', 'expense', 'transfer'};
    if (!allowedFlows.contains(normalizedFlow)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unsupported flow: $flowRaw')),
      );
      return false;
    }

    final amountValue = submission.amountValue ?? submission.xpValue;
    if (amountValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return false;
    }

    final amountCents = amountValue.abs() * 100;
    final accountName = (submission.selectedAccount?.trim().isNotEmpty ?? false)
        ? submission.selectedAccount!.trim()
        : 'Manual Account';

    final draft = ManualTransactionDraft(
      title: submission.title,
      amountCents: amountCents,
      flow: normalizedFlow,
      date: submission.startDate,
      category: submission.categoryId,
      description: submission.description,
      accountName: accountName,
      accountType: 'manual',
    );

    try {
      await context.read<TransactionsProvider>().addManualTransaction(draft);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction "${submission.title}" saved')),
      );
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save transaction: $e')),
      );
      return false;
    }
  }

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
        .map((c) => (id: c.name, name: c.name, colorInt: c.color?.value))
        .toList(growable: false);
    final String? accountLabel =
        _transactionAccountLabel(txn) ?? 'Manual Account';
    final List<String> accountOptions = _accountOptions(txn);
    final bool lockRepetition = txn != null;

    final String? effectiveTitle =
        initialTitle ?? _transactionTitle(txn);
    final int? initialAmountCents =
        txn?.amountCents.abs();
    final String? initialCashflow = _transactionFlowLabel(txn);
    final String? initialCategoryId = _matchCategoryId(
      txn,
      catTuples,
    );
    final DateTime? initialStartDate = txn?.date;
    final bool effectiveAutofocus = autofocusTitle && txn == null;

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
      initialAmountCents: initialAmountCents,
      initialCashflow: initialCashflow,
      initialAccount: accountLabel,
      initialCategoryId: initialCategoryId,
      initialStartDate: initialStartDate,
      initialRepetitionOff: lockRepetition,
      onSubmit: (submission) => _handleSubmit(context, submission),
    );
  }

  String? _transactionTitle(BankTransaction? txn) {
    if (txn == null) return null;
    if (txn.merchant?.isNotEmpty == true) return txn.merchant;
    if (txn.name?.isNotEmpty == true) return txn.name;
    return null;
  }

  String? _transactionFlowLabel(BankTransaction? txn) {
    if (txn == null) return null;
    final flow =
        (txn.flow ?? (txn.isExpense ? 'expense' : 'income')).toLowerCase();
    switch (flow) {
      case 'income':
        return 'Income';
      case 'expense':
        return 'Expense';
      case 'transfer':
        return 'Transfer';
      default:
        return null;
    }
  }

  String? _matchCategoryId(
    BankTransaction? txn,
    List<({String id, String name, int? colorInt})> categories,
  ) {
    if (txn?.category == null) return null;
    final txnCat = txn!.category!.toLowerCase();
    for (final cat in categories) {
      if (cat.name.toLowerCase() == txnCat) {
        return cat.id;
      }
    }
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
