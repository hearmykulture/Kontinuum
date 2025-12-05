// lib/models/budget_models_hive.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kontinuum/core/time/app_clock.dart';

part 'budget_models_hive.g.dart';

/// Hive-serializable Budget model
@HiveType(typeId: 100)
class BudgetHive extends HiveObject {
  BudgetHive({
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

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int monthlyAmount;

  @HiveField(3)
  List<BudgetCategoryHive> categories;

  @HiveField(4)
  List<RecurringExpenseHive> recurrings;

  @HiveField(5)
  bool unallocatedAsSavings;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  BudgetHive copyWith({
    String? title,
    int? monthlyAmount,
    List<BudgetCategoryHive>? categories,
    List<RecurringExpenseHive>? recurrings,
    bool? unallocatedAsSavings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetHive(
      id: id,
      title: title ?? this.title,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      categories: categories ?? List<BudgetCategoryHive>.from(this.categories),
      recurrings:
          recurrings ?? List<RecurringExpenseHive>.from(this.recurrings),
      unallocatedAsSavings: unallocatedAsSavings ?? this.unallocatedAsSavings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? AppClock.now(),
    );
  }
}

@HiveType(typeId: 101)
class BudgetCategoryHive extends HiveObject {
  BudgetCategoryHive({
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
  });

  @HiveField(0)
  String name;

  @HiveField(1)
  int iconCodePoint;

  @HiveField(2)
  int colorValue;

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  BudgetCategoryHive copyWith({
    String? name,
    int? iconCodePoint,
    int? colorValue,
  }) {
    return BudgetCategoryHive(
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

@HiveType(typeId: 102)
class RecurringExpenseHive extends HiveObject {
  RecurringExpenseHive({
    required this.name,
    required this.amountCents,
    required this.cadence,
    required this.iconCodePoint,
    required this.colorValue,
    this.categoryName,
    this.weekdayMask,
    this.monthlyDay,
    this.yearlyMonth,
    this.yearlyDay,
  });

  @HiveField(0)
  String name;

  @HiveField(1)
  int amountCents;

  /// 0 = weekly, 1 = monthly, 2 = yearly
  @HiveField(2)
  int cadence;

  @HiveField(3)
  int iconCodePoint;

  @HiveField(4)
  int colorValue;

  /// Persist the linked category by name.
  @HiveField(5)
  String? categoryName;

  /// Bitmask for weekly cadence, using DateTime.weekday (1–7) mapped to bits 0–6.
  /// Null or 0 means "no specific days selected".
  @HiveField(6)
  int? weekdayMask;

  /// Day-of-month for monthly cadence (1–31).
  @HiveField(7)
  int? monthlyDay;

  /// Month (1–12) for yearly cadence.
  @HiveField(8)
  int? yearlyMonth;

  /// Day-of-month for yearly cadence (1–31).
  @HiveField(9)
  int? yearlyDay;

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  RecurringExpenseHive copyWith({
    String? name,
    int? amountCents,
    int? cadence,
    int? iconCodePoint,
    int? colorValue,
    String? categoryName,
    int? weekdayMask,
    int? monthlyDay,
    int? yearlyMonth,
    int? yearlyDay,
  }) {
    return RecurringExpenseHive(
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      cadence: cadence ?? this.cadence,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      categoryName: categoryName ?? this.categoryName,
      weekdayMask: weekdayMask ?? this.weekdayMask,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      yearlyMonth: yearlyMonth ?? this.yearlyMonth,
      yearlyDay: yearlyDay ?? this.yearlyDay,
    );
  }
}
