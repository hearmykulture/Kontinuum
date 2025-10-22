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

class RecurringExpense {
  RecurringExpense({
    required this.name,
    required this.amountCents,
    required this.cadence,
    required this.icon,
    required this.color,
    this.category,
  });

  final String name;
  final int amountCents; // store in cents
  final Recurrence cadence;
  final IconData icon;
  final Color color;
  final BudgetCategory? category;

  RecurringExpense copyWith({
    String? name,
    int? amountCents,
    Recurrence? cadence,
    IconData? icon,
    Color? color,
    BudgetCategory? category,
  }) {
    return RecurringExpense(
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      cadence: cadence ?? this.cadence,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      category: category ?? this.category,
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
