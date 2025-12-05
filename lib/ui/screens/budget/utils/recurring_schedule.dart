// lib/ui/screens/budget/utils/recurring_schedule.dart

import '../models/budget_models.dart';

/// A single dated instance of a recurring expense.
class RecurringInstance {
  RecurringInstance({
    required this.expense,
    required this.dueDate,
  });

  final RecurringExpense expense;
  final DateTime dueDate;

  int get amountCents => expense.amountCents;
}

/// Build all upcoming instances for a set of recurring expenses within a
/// [windowStart]..[windowEnd] (inclusive) window, sorted by due date then name.
///
/// This is ideal for powering an "Upcoming Bills" list.
List<RecurringInstance> buildUpcomingInstances(
  List<RecurringExpense> expenses, {
  required DateTime windowStart,
  required DateTime windowEnd,
}) {
  // Normalize window order.
  var start = _dateOnly(windowStart);
  var end = _dateOnly(windowEnd);
  if (end.isBefore(start)) {
    final tmp = start;
    start = end;
    end = tmp;
  }

  final result = <RecurringInstance>[];

  for (final exp in expenses) {
    final dates = occurrencesForExpenseInWindow(
      exp,
      start,
      end,
    );
    for (final d in dates) {
      result.add(
        RecurringInstance(
          expense: exp,
          dueDate: d,
        ),
      );
    }
  }

  result.sort((a, b) {
    final cmp = a.dueDate.compareTo(b.dueDate);
    if (cmp != 0) return cmp;
    return a.expense.name.compareTo(b.expense.name);
  });

  return result;
}

/// Return all due dates for a single [expense] within [windowStart]..[windowEnd]
/// (inclusive). Dates are returned as midnight-local DateTimes.
List<DateTime> occurrencesForExpenseInWindow(
  RecurringExpense expense,
  DateTime windowStart,
  DateTime windowEnd, {
  int maxOccurrences = 64,
}) {
  var start = _dateOnly(windowStart);
  var end = _dateOnly(windowEnd);
  if (end.isBefore(start)) {
    final tmp = start;
    start = end;
    end = tmp;
  }

  switch (expense.cadence) {
    case Recurrence.weekly:
      return _weeklyOccurrencesInWindow(
        expense,
        start,
        end,
        maxOccurrences: maxOccurrences,
      );
    case Recurrence.monthly:
      return _monthlyOccurrencesInWindow(
        expense,
        start,
        end,
        maxOccurrences: maxOccurrences,
      );
    case Recurrence.yearly:
      return _yearlyOccurrencesInWindow(
        expense,
        start,
        end,
        maxOccurrences: maxOccurrences,
      );
  }
}

/// Get the next occurrence for [expense] on or after [reference].
///
/// Uses a bounded search window (default 365 days) so it can safely handle
/// bad/missing metadata.
DateTime? nextOccurrenceForExpense(
  RecurringExpense expense,
  DateTime reference, {
  int searchDays = 365,
}) {
  final start = _dateOnly(reference);
  final end = start.add(Duration(days: searchDays));
  final dates = occurrencesForExpenseInWindow(
    expense,
    start,
    end,
    maxOccurrences: 1,
  );
  if (dates.isEmpty) return null;
  return dates.first;
}

/// Compute a concrete [windowStart] and [windowEnd] for a given [BudgetTimeSpan].
///
/// [anchor] is typically the date selected in the budget header calendar.
///
///   - [BudgetTimeSpan.weekly]  → next 7 days starting at [anchor].
///   - [BudgetTimeSpan.monthly] → next 30 days starting at [anchor].
///   - [BudgetTimeSpan.yearly]  → next 365 days starting at [anchor].
///   - [BudgetTimeSpan.custom]  → [customStart]/[customEnd] (or [anchor] if null).
(DateTime, DateTime) windowForBudgetTimeSpan({
  required BudgetTimeSpan span,
  required DateTime anchor,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final base = _dateOnly(anchor);

  switch (span) {
    case BudgetTimeSpan.weekly:
      final start = base;
      final end = start.add(const Duration(days: 6));
      return (start, end);
    case BudgetTimeSpan.monthly:
      final start = base;
      final end = start.add(const Duration(days: 29));
      return (start, end);
    case BudgetTimeSpan.yearly:
      final start = base;
      final end = start.add(const Duration(days: 364));
      return (start, end);
    case BudgetTimeSpan.custom:
      var start = customStart != null ? _dateOnly(customStart) : base;
      var end = customEnd != null ? _dateOnly(customEnd) : base;
      if (end.isBefore(start)) {
        final tmp = start;
        start = end;
        end = tmp;
      }
      return (start, end);
  }
}

/// Convenience: build upcoming instances for the given [span] anchored at [anchor].
List<RecurringInstance> buildUpcomingInstancesForSpan(
  List<RecurringExpense> expenses, {
  required BudgetTimeSpan span,
  required DateTime anchor,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final (start, end) = windowForBudgetTimeSpan(
    span: span,
    anchor: anchor,
    customStart: customStart,
    customEnd: customEnd,
  );

  return buildUpcomingInstances(
    expenses,
    windowStart: start,
    windowEnd: end,
  );
}

/// Compute the total amount (in cents) that a single [expense] contributes
/// within the given [windowStart]..[windowEnd] (inclusive).
///
/// This expands the recurrence into concrete instances in the window and
/// multiplies by [expense.amountCents]. Use this when you want *actual*
/// contribution in a specific time span (week, year, custom) instead of a
/// normalized monthly value.
int expenseAmountInWindow(
  RecurringExpense expense,
  DateTime windowStart,
  DateTime windowEnd, {
  int maxOccurrences = 512,
}) {
  final dates = occurrencesForExpenseInWindow(
    expense,
    windowStart,
    windowEnd,
    maxOccurrences: maxOccurrences,
  );
  if (dates.isEmpty) return 0;
  return dates.length * expense.amountCents;
}

/// Compute total cents per category for a list of [expenses] within
/// [windowStart]..[windowEnd] (inclusive).
///
/// This is useful for the Categories dropdown when you want category
/// contributions for a weekly / yearly / custom time span.
///
/// The map key is the category name; expenses with a null category are
/// grouped under `'Uncategorized'`.
Map<String, int> categoryTotalsInWindow(
  List<RecurringExpense> expenses,
  DateTime windowStart,
  DateTime windowEnd, {
  int maxOccurrencesPerExpense = 512,
}) {
  final result = <String, int>{};

  for (final exp in expenses) {
    final cents = expenseAmountInWindow(
      exp,
      windowStart,
      windowEnd,
      maxOccurrences: maxOccurrencesPerExpense,
    );
    if (cents == 0) continue;

    final catName = exp.category?.name ?? 'Uncategorized';
    result[catName] = (result[catName] ?? 0) + cents;
  }

  return result;
}

// ────────────────── Internal helpers ──────────────────

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

List<DateTime> _weeklyOccurrencesInWindow(
  RecurringExpense expense,
  DateTime start,
  DateTime end, {
  required int maxOccurrences,
}) {
  final result = <DateTime>[];

  // Fallback if the weekday set is empty – default to the start-day-of-week.
  final weekdays = expense.weeklyWeekdays.isEmpty
      ? {start.weekday}
      : Set<int>.from(expense.weeklyWeekdays);

  var cursor = start;
  while (!cursor.isAfter(end) && result.length < maxOccurrences) {
    if (weekdays.contains(cursor.weekday)) {
      result.add(_dateOnly(cursor));
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  return result;
}

List<DateTime> _monthlyOccurrencesInWindow(
  RecurringExpense expense,
  DateTime start,
  DateTime end, {
  required int maxOccurrences,
}) {
  final result = <DateTime>[];

  // Use stored monthlyDay; if null, fall back to the windowStart's day.
  final targetDay =
      (expense.monthlyDay ?? start.day).clamp(1, 31); // 1–31 logical target

  // Walk month by month from the month containing [start] to the month
  // containing [end].
  var monthCursor = DateTime(start.year, start.month, 1);
  final lastMonth = DateTime(end.year, end.month, 1);

  while (!monthCursor.isAfter(lastMonth) && result.length < maxOccurrences) {
    final year = monthCursor.year;
    final month = monthCursor.month;
    final daysInMonth = _daysInMonth(year, month);
    final day = targetDay > daysInMonth ? daysInMonth : targetDay;

    final due = DateTime(year, month, day);

    if (!due.isBefore(start) && !due.isAfter(end)) {
      result.add(due);
    }

    // Advance to 1st of next month.
    monthCursor =
        (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  }

  return result;
}

List<DateTime> _yearlyOccurrencesInWindow(
  RecurringExpense expense,
  DateTime start,
  DateTime end, {
  required int maxOccurrences,
}) {
  final result = <DateTime>[];

  // Fallbacks: if month/day are missing, anchor to the start date.
  final month = (expense.yearlyMonth ?? start.month).clamp(1, 12);
  final rawDay = (expense.yearlyDay ?? start.day).clamp(1, 31);

  for (int year = start.year;
      year <= end.year && result.length < maxOccurrences;
      year++) {
    final daysInMonth = _daysInMonth(year, month);
    final day = rawDay > daysInMonth ? daysInMonth : rawDay;
    final due = DateTime(year, month, day);

    if (!due.isBefore(start) && !due.isAfter(end)) {
      result.add(due);
    }
  }

  return result;
}

int _daysInMonth(int year, int month) {
  // Move to the first day of the next month, then step back a day.
  final beginningNextMonth =
      (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  final lastDay = beginningNextMonth.subtract(const Duration(days: 1)).day;
  return lastDay;
}
