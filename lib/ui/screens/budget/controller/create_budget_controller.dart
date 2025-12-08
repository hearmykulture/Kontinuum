import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/budget_models.dart';
import '../theme/budget_theme.dart';

/// Controller holds state + business logic. UI listens via ChangeNotifier.
class CreateBudgetController extends ChangeNotifier {
  CreateBudgetController({BudgetDraft? initial}) {
    if (initial != null) {
      _title = initial.title;
      _monthlyAmount = initial.monthlyAmount;
      _unallocatedAsSavings = initial.unallocatedAsSavings;
      _cadence = initial.cadence;

      // Deep copy categories; remap recurring.category references.
      final Map<BudgetCategory, BudgetCategory> map = {};
      for (final c in initial.categories) {
        final copy = c.copyWith();
        map[c] = copy;
        _categories.add(copy);
      }
      for (final r in initial.recurrings) {
        _recurrings.add(
          r.copyWith(category: r.category == null ? null : map[r.category]!),
        );
      }
    }
  }

  /// ===== State =====
  String _title = '';
  int? _monthlyAmount; // dollars
  final List<BudgetCategory> _categories = <BudgetCategory>[];
  final List<RecurringExpense> _recurrings = <RecurringExpense>[];
  bool _unallocatedAsSavings = false;
  BudgetTimeSpan _cadence = BudgetTimeSpan.monthly;

  /// ===== Getters =====
  String get title => _title;
  int? get monthlyAmount => _monthlyAmount;
  List<BudgetCategory> get categories => List.unmodifiable(_categories);
  List<RecurringExpense> get recurrings => List.unmodifiable(_recurrings);
  bool get unallocatedAsSavings => _unallocatedAsSavings;
  BudgetTimeSpan get cadence => _cadence;

  bool get hasAllocation => _recurrings.isNotEmpty;

  /// ===== Mutators =====
  void setTitle(String v) {
    _title = v;
    notifyListeners();
  }

  void setMonthlyAmount(int? dollars) {
    _monthlyAmount = (dollars ?? 0) < 0 ? 0 : dollars;
    notifyListeners();
  }

  void setCadence(BudgetTimeSpan cadence) {
    if (_cadence == cadence) return;
    final prev = _cadence;
    _cadence = cadence;
    if (_monthlyAmount != null) {
      final cents = _monthlyAmount! * 100;
      final converted = _convertAmountBetweenSpans(
        cents,
        from: prev,
        to: cadence,
      );
      _monthlyAmount = (converted / 100).round();
    }
    notifyListeners();
  }

  void toggleUnallocatedAsSavings([bool? v]) {
    _unallocatedAsSavings = v ?? !_unallocatedAsSavings;
    notifyListeners();
  }

  void addCategory(BudgetCategory c) {
    _categories.add(c);
    notifyListeners();
  }

  void updateCategoryAt(int index, BudgetCategory c) {
    if (index < 0 || index >= _categories.length) return;
    _categories[index] = c;
    notifyListeners();
  }

  BudgetCategory removeCategoryAt(int index) {
    final removed = _categories.removeAt(index);
    // Detach from any recurrings pointing to it.
    for (int i = 0; i < _recurrings.length; i++) {
      if (_recurrings[i].category == removed) {
        _recurrings[i] = _recurrings[i].copyWith(category: null);
      }
    }
    notifyListeners();
    return removed;
  }

  void addRecurring(RecurringExpense r) {
    _recurrings.add(r);
    notifyListeners();
  }

  void updateRecurringAt(int index, RecurringExpense r) {
    if (index < 0 || index >= _recurrings.length) return;
    _recurrings[index] = r;
    notifyListeners();
  }

  RecurringExpense removeRecurringAt(int index) {
    final removed = _recurrings.removeAt(index);
    notifyListeners();
    return removed;
  }

  /// ===== Budget math =====
  int _recurringCentsForCurrentSpan(RecurringExpense r) {
    final fromDays = _daysForRecurrence(r.cadence);
    final toDays = _daysForSpan(_cadence);
    if (fromDays == toDays) return r.amountCents;
    if (fromDays <= 0 || toDays <= 0) return r.amountCents;
    final perDay = r.amountCents / fromDays;
    return (perDay * toDays).round();
  }

  int get monthCents => (_monthlyAmount ?? 0) * 100;

  Map<BudgetCategory, int> _categoryTotals({required bool includeZero}) {
    final Map<BudgetCategory, int> totals = {
      if (includeZero)
        for (final c in _categories) c: 0
    };
    for (final r in _recurrings) {
      if (r.category == null) continue;
      totals.update(
        r.category!,
        (prev) => prev + _recurringCentsForCurrentSpan(r),
        ifAbsent: () => _recurringCentsForCurrentSpan(r),
      );
    }
    return totals;
  }

  int allocatedSumCents() {
    int s = 0;
    for (final r in _recurrings) {
      if (r.category != null) s += _recurringCentsForCurrentSpan(r);
    }
    return s;
  }

  int remainderCents() {
    final allocated = allocatedSumCents();
    return math.max(0, monthCents - allocated);
  }

  int overageCents() {
    if (_monthlyAmount == null) return 0;
    final over = allocatedSumCents() - monthCents;
    return over > 0 ? over : 0;
  }

  bool get isOverBudget =>
      _monthlyAmount != null && allocatedSumCents() > monthCents;

  Allocation buildAllocation({required bool includeZeroCategories}) {
    final totals = _categoryTotals(includeZero: includeZeroCategories);
    final items = <AllocationItem>[
      for (final e in totals.entries)
        AllocationItem(name: e.key.name, color: e.key.color, cents: e.value),
    ];

    final rem = remainderCents();
    if (rem > 0) {
      items.add(
        AllocationItem(
          name: _unallocatedAsSavings ? 'Savings' : 'Unallocated',
          color: BudgetTheme.unallocatedGray,
          cents: rem,
        ),
      );
    }
    return Allocation(totalCents: monthCents, items: items);
  }

  /// To hand back to caller on "Complete"
  BudgetDraft? toDraft() {
    if (_monthlyAmount == null || _title.trim().isEmpty) return null;
    return BudgetDraft(
      title: _title.trim(),
      monthlyAmount: _monthlyAmount!,
      categories: List<BudgetCategory>.from(_categories),
      recurrings: List<RecurringExpense>.from(_recurrings),
      unallocatedAsSavings: _unallocatedAsSavings,
      cadence: _cadence,
    );
  }

  int _convertAmountBetweenSpans(
    int amountCents, {
    required BudgetTimeSpan from,
    required BudgetTimeSpan to,
  }) {
    final fromDays = _daysForSpan(from);
    final toDays = _daysForSpan(to);
    if (fromDays == toDays) return amountCents;
    if (fromDays <= 0 || toDays <= 0) return amountCents;
    final perDay = amountCents / fromDays;
    return (perDay * toDays).round();
  }

  int _daysForSpan(BudgetTimeSpan span) {
    switch (span) {
      case BudgetTimeSpan.weekly:
        return 7;
      case BudgetTimeSpan.monthly:
        return 30;
      case BudgetTimeSpan.yearly:
        return 365;
      case BudgetTimeSpan.custom:
        return 30;
    }
  }

  int _daysForRecurrence(Recurrence cadence) {
    switch (cadence) {
      case Recurrence.weekly:
        return 7;
      case Recurrence.monthly:
        return 30;
      case Recurrence.yearly:
        return 365;
    }
  }
}
