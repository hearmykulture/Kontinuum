// lib/providers/budget_provider.dart

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:kontinuum/data/hive_service.dart';
import 'package:kontinuum/models/budget_models_hive.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class Budget {
  Budget({
    required this.id,
    required this.title,
    required this.monthlyAmount,
    required this.categories,
    required this.recurrings,
    required this.unallocatedAsSavings,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? AppClock.now(),
        updatedAt = updatedAt ?? AppClock.now();

  final String id;
  final String title;

  /// Monthly budget amount, stored in whole dollars.
  final int monthlyAmount;
  final List<BudgetCategory> categories;
  final List<RecurringExpense> recurrings;
  final bool unallocatedAsSavings;
  final DateTime createdAt;
  final DateTime updatedAt;

  Budget copyWith({
    String? title,
    int? monthlyAmount,
    List<BudgetCategory>? categories,
    List<RecurringExpense>? recurrings,
    bool? unallocatedAsSavings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id,
      title: title ?? this.title,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      categories: categories ?? List<BudgetCategory>.from(this.categories),
      recurrings: recurrings ?? List<RecurringExpense>.from(this.recurrings),
      unallocatedAsSavings: unallocatedAsSavings ?? this.unallocatedAsSavings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? AppClock.now(),
    );
  }

  BudgetDraft toDraft() {
    return BudgetDraft(
      title: title,
      monthlyAmount: monthlyAmount,
      categories: categories.map((c) => c.copyWith()).toList(growable: false),
      recurrings: recurrings.map((r) => r.copyWith()).toList(growable: false),
      unallocatedAsSavings: unallocatedAsSavings,
    );
  }

  static Budget fromDraft({
    required String id,
    required BudgetDraft draft,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id,
      title: draft.title,
      monthlyAmount: draft.monthlyAmount,
      categories:
          draft.categories.map((c) => c.copyWith()).toList(growable: false),
      recurrings:
          draft.recurrings.map((r) => r.copyWith()).toList(growable: false),
      unallocatedAsSavings: draft.unallocatedAsSavings,
      createdAt: createdAt,
    );
  }

  static Budget mergeWithDraft(Budget original, BudgetDraft draft) {
    return Budget.fromDraft(
      id: original.id,
      draft: draft,
      createdAt: original.createdAt,
    ).copyWith(
      updatedAt: AppClock.now(),
    );
  }

  /// Monthly amount expressed in cents.
  int get monthlyAmountCents => monthlyAmount * 100;

  /// Convert this budget's monthly amount into a total (in cents) for the given [span].
  ///
  /// For `weekly` and `yearly`, this uses a simple normalization:
  ///   - weekly ≈ monthly / 4
  ///   - yearly = monthly * 12
  ///
  /// For `custom`, if [spanStart] and [spanEnd] are provided, the amount is
  /// scaled linearly based on the number of days in the window
  /// (30 days ≈ 1 month). Otherwise it falls back to the monthly amount.
  int amountCentsForSpan(
    BudgetTimeSpan span, {
    DateTime? spanStart,
    DateTime? spanEnd,
  }) {
    return normalizeMonthlyAmountForSpan(
      monthlyAmountCents,
      span,
      spanStart: spanStart,
      spanEnd: spanEnd,
    );
  }

  /// Static method to normalize a monthly amount for a given time span.
  static int normalizeMonthlyAmountForSpan(
    int monthlyAmountCents,
    BudgetTimeSpan span, {
    DateTime? spanStart,
    DateTime? spanEnd,
  }) {
    switch (span) {
      case BudgetTimeSpan.weekly:
        return (monthlyAmountCents / 4).round();
      case BudgetTimeSpan.monthly:
        return monthlyAmountCents;
      case BudgetTimeSpan.yearly:
        return monthlyAmountCents * 12;
      case BudgetTimeSpan.custom:
        if (spanStart == null || spanEnd == null) {
          return monthlyAmountCents;
        }
        final days = spanEnd.difference(spanStart).inDays + 1;
        return ((monthlyAmountCents / 30) * days).round();
    }
  }

  // Convert to Hive model
  BudgetHive toHive() {
    return BudgetHive(
      id: id,
      title: title,
      monthlyAmount: monthlyAmount,
      categories: categories.map((c) => _categoryToHive(c)).toList(),
      recurrings: recurrings.map((r) => _recurringToHive(r)).toList(),
      unallocatedAsSavings: unallocatedAsSavings,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Convert from Hive model — rehydrate recurring.category by name
  static Budget fromHive(BudgetHive hive) {
    // Categories first
    final categories =
        hive.categories.map((c) => _categoryFromHive(c)).toList();

    BudgetCategory? resolveCat(String? name) {
      if (name == null) return null;
      try {
        return categories.firstWhere((c) => c.name == name);
      } catch (_) {
        return null;
      }
    }

    // Recurrings with resolved category
    final recurrings = hive.recurrings
        .map(
          (r) => _recurringFromHive(
            r,
            category: resolveCat(r.categoryName),
          ),
        )
        .toList();

    return Budget(
      id: hive.id,
      title: hive.title,
      monthlyAmount: hive.monthlyAmount,
      categories: categories,
      recurrings: recurrings,
      unallocatedAsSavings: hive.unallocatedAsSavings,
      createdAt: hive.createdAt,
      updatedAt: hive.updatedAt,
    );
  }

  static BudgetCategoryHive _categoryToHive(BudgetCategory cat) {
    return BudgetCategoryHive(
      name: cat.name,
      iconCodePoint: cat.icon.codePoint,
      colorValue: cat.color.toARGB32(),
    );
  }

  static BudgetCategory _categoryFromHive(BudgetCategoryHive hive) {
    return BudgetCategory(
      name: hive.name,
      icon: hive.icon,
      color: hive.color,
    );
  }

  /// Encode recurrence + cadence-specific metadata into the Hive model.
  static RecurringExpenseHive _recurringToHive(RecurringExpense rec) {
    int cadenceIndex;
    switch (rec.cadence) {
      case Recurrence.weekly:
        cadenceIndex = 0;
        break;
      case Recurrence.monthly:
        cadenceIndex = 1;
        break;
      case Recurrence.yearly:
        cadenceIndex = 2;
        break;
    }

    return RecurringExpenseHive(
      name: rec.name,
      amountCents: rec.amountCents,
      cadence: cadenceIndex,
      iconCodePoint: rec.icon.codePoint,
      colorValue: rec.color.toARGB32(),
      categoryName: rec.category?.name, // persist category by name
      // cadence metadata:
      weekdayMask: _encodeWeekdays(rec.weeklyWeekdays),
      monthlyDay: rec.monthlyDay,
      yearlyMonth: rec.yearlyMonth,
      yearlyDay: rec.yearlyDay,
    );
  }

  /// Rehydrate recurrence + cadence metadata from Hive.
  static RecurringExpense _recurringFromHive(
    RecurringExpenseHive hive, {
    BudgetCategory? category,
  }) {
    Recurrence cadence;
    switch (hive.cadence) {
      case 0:
        cadence = Recurrence.weekly;
        break;
      case 1:
        cadence = Recurrence.monthly;
        break;
      case 2:
        cadence = Recurrence.yearly;
        break;
      default:
        cadence = Recurrence.monthly;
    }

    final weeklyDays = _decodeWeekdays(hive.weekdayMask);

    return RecurringExpense(
      name: hive.name,
      amountCents: hive.amountCents,
      cadence: cadence,
      icon: hive.icon,
      color: hive.color,
      category: category, // reattached on load
      weeklyWeekdays: weeklyDays,
      monthlyDay: hive.monthlyDay ?? 1,
      yearlyMonth: hive.yearlyMonth ?? 1,
      yearlyDay: hive.yearlyDay ?? 1,
    );
  }

  /// Bitmask helpers for weekly cadence (DateTime.weekday 1–7).
  static int? _encodeWeekdays(Set<int> days) {
    if (days.isEmpty) return null;
    int mask = 0;
    for (final d in days) {
      if (d < DateTime.monday || d > DateTime.sunday) continue;
      final bit = d - DateTime.monday; // 0–6
      mask |= 1 << bit;
    }
    return mask;
  }

  static Set<int> _decodeWeekdays(int? mask) {
    if (mask == null || mask == 0) return <int>{};
    final result = <int>{};
    for (int bit = 0; bit < 7; bit++) {
      if ((mask & (1 << bit)) != 0) {
        result.add(DateTime.monday + bit);
      }
    }
    return result;
  }
}

class BudgetProvider with ChangeNotifier {
  static const int kBudgetsCap = 8;

  final HiveService _hiveService;
  final List<Budget> _budgets = <Budget>[];
  int _sequence = 0;
  bool _isLoaded = false;

  BudgetProvider(this._hiveService);

  bool get isLoaded => _isLoaded;

  UnmodifiableListView<Budget> get budgets =>
      UnmodifiableListView<Budget>(_budgets);

  bool get atCap => _budgets.length >= kBudgetsCap;

  Budget? byId(String id) {
    for (final budget in _budgets) {
      if (budget.id == id) return budget;
    }
    return null;
  }

  /// Load budgets from Hive on app startup
  Future<void> loadBudgets() async {
    if (_isLoaded) return;
    try {
      final hiveModels = await _hiveService.loadBudgets();
      _budgets.clear();
      _budgets.addAll(hiveModels.map((h) => Budget.fromHive(h)));
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading budgets: $e');
      _isLoaded = true;
    }
  }

  Future<void> reloadFromStorage() async {
    _isLoaded = false;
    _budgets.clear();
    await loadBudgets();
  }

  Future<Budget> createBudget(BudgetDraft draft) async {
    if (atCap) {
      throw StateError('Budget cap $kBudgetsCap reached');
    }
    final budget = Budget.fromDraft(
      id: _nextId(),
      draft: draft,
    );
    _budgets.add(budget);
    await _persist();
    notifyListeners();
    return budget;
  }

  Future<Budget?> updateBudget(String id, BudgetDraft draft) async {
    final index = _budgets.indexWhere((b) => b.id == id);
    if (index == -1) return null;
    final updated = Budget.mergeWithDraft(_budgets[index], draft);
    _budgets[index] = updated;
    await _persist();
    notifyListeners();
    return updated;
  }

  Future<Budget?> removeBudget(String id) async {
    final index = _budgets.indexWhere((b) => b.id == id);
    if (index == -1) return null;
    final removed = _budgets.removeAt(index);
    await _persist();
    notifyListeners();
    return removed;
  }

  Future<Budget?> duplicateBudget(String id) async {
    if (atCap) return null;
    final original = byId(id);
    if (original == null) return null;
    final clone = Budget(
      id: _nextId(),
      title: '${original.title} Copy',
      monthlyAmount: original.monthlyAmount,
      categories:
          original.categories.map((c) => c.copyWith()).toList(growable: false),
      recurrings:
          original.recurrings.map((r) => r.copyWith()).toList(growable: false),
      unallocatedAsSavings: original.unallocatedAsSavings,
      createdAt: AppClock.now(),
    );
    _budgets.add(clone);
    await _persist();
    notifyListeners();
    return clone;
  }

  Future<void> clearAll() async {
    _budgets.clear();
    await _persist();
    notifyListeners();
  }

  /// Persist all budgets to Hive
  Future<void> _persist() async {
    try {
      final hiveModels = _budgets.map((b) => b.toHive()).toList();
      await _hiveService.saveBudgets(hiveModels);
    } catch (e) {
      debugPrint('Error persisting budgets: $e');
    }
  }

  String _nextId() {
    final ts = AppClock.now().microsecondsSinceEpoch;
    _sequence = (_sequence + 1) % 9999;
    return 'budget_${ts}_$_sequence';
  }
}
