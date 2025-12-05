import 'package:flutter/material.dart';

/// ===== Models =====

class BudgetDraft {
  BudgetDraft({
    required this.title,
    required this.monthlyAmount, // dollars
    required this.categories,
    required this.recurrings,
    required this.unallocatedAsSavings,
  });

  final String title;
  final int monthlyAmount; // dollars
  final List<BudgetCategory> categories;
  final List<RecurringExpense> recurrings;
  final bool unallocatedAsSavings;

  BudgetDraft copyWith({
    String? title,
    int? monthlyAmount,
    List<BudgetCategory>? categories,
    List<RecurringExpense>? recurrings,
    bool? unallocatedAsSavings,
  }) {
    return BudgetDraft(
      title: title ?? this.title,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      categories: categories ?? this.categories,
      recurrings: recurrings ?? this.recurrings,
      unallocatedAsSavings: unallocatedAsSavings ?? this.unallocatedAsSavings,
    );
  }
}

class BudgetCategory {
  BudgetCategory({required this.name, required this.icon, required this.color});
  final String name;
  final IconData icon;
  final Color color;

  BudgetCategory copyWith({String? name, IconData? icon, Color? color}) {
    return BudgetCategory(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}

enum Recurrence { weekly, monthly, yearly }

enum BudgetTimeSpan { weekly, monthly, yearly, custom }

class RecurringExpense {
  RecurringExpense({
    required this.name,
    required this.amountCents,
    required this.cadence,
    required this.icon,
    required this.color,
    this.category,
    this.weeklyWeekdays = const {},
    this.monthlyDay = 1,
    this.yearlyMonth = 1,
    this.yearlyDay = 1,
  });

  final String name;
  final int amountCents; // store in cents
  final Recurrence cadence;
  final IconData icon;
  final Color color;
  final BudgetCategory? category;
  final Set<int> weeklyWeekdays; // Weekday numbers (1-7)
  final int monthlyDay; // Day of month (1-31)
  final int yearlyMonth; // Month (1-12)
  final int yearlyDay; // Day of month (1-31)

  RecurringExpense copyWith({
    String? name,
    int? amountCents,
    Recurrence? cadence,
    IconData? icon,
    Color? color,
    BudgetCategory? category,
    Set<int>? weeklyWeekdays,
    int? monthlyDay,
    int? yearlyMonth,
    int? yearlyDay,
  }) {
    return RecurringExpense(
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      cadence: cadence ?? this.cadence,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      category: category ?? this.category,
      weeklyWeekdays: weeklyWeekdays ?? this.weeklyWeekdays,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      yearlyMonth: yearlyMonth ?? this.yearlyMonth,
      yearlyDay: yearlyDay ?? this.yearlyDay,
    );
  }
}

String labelForRecurrence(Recurrence r) {
  switch (r) {
    case Recurrence.weekly:
      return 'Weekly';
    case Recurrence.monthly:
      return 'Monthly';
    case Recurrence.yearly:
      return 'Yearly';
  }
}

/// ===== Allocation view model (for the chart/legend) =====
class Allocation {
  Allocation({required this.totalCents, required this.items});
  final int totalCents;
  final List<AllocationItem> items;
}

class AllocationItem {
  AllocationItem({
    required this.name,
    required this.color,
    required this.cents,
  });
  final String name;
  final Color color;
  final int cents;
}

/// ===== Bank/CashFlow models (stubs) =====

/// Represents a bank transaction (stub implementation)
class BankTransaction {
  BankTransaction({
    required this.id,
    required this.accountId,
    this.merchant,
    this.name,
    this.category,
    this.categoryPath = const [],
    required this.isExpense,
    required this.amount,
    this.flow,
    required this.status,
    this.date,
    this.amountCents = 0,
    this.pendingTransactionId,
    this.currency,
    this.accountType,
    this.accountName,
  });

  final String id;
  final String accountId;
  final String? merchant;
  final String? name;
  final String? category;
  final List<String> categoryPath;
  final bool isExpense;
  final double amount;
  final String? flow;
  final String status;
  final DateTime? date;
  final int amountCents;
  final String? pendingTransactionId;
  final String? currency;
  final String? accountType;
  final String? accountName;
}

/// Represents a snapshot of cash flow data (stub implementation)
class CashFlowSnapshot {
  CashFlowSnapshot({
    this.transactions = const [],
    this.summary,
  });

  final List<BankTransaction> transactions;
  final CashFlowSummary? summary;
}

/// Summary of cash flow information (stub implementation)
class CashFlowSummary {
  CashFlowSummary({
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.from,
    this.to,
  });

  final double totalIncome;
  final double totalExpense;
  final DateTime? from;
  final DateTime? to;

  double get net => totalIncome - totalExpense;
  double get inflow => totalIncome;
  double get outflow => totalExpense;
}

/// Exception thrown when bank API is offline
class BankApiOfflineException implements Exception {
  BankApiOfflineException(this.message);
  final String message;

  @override
  String toString() => 'BankApiOfflineException: $message';
}
