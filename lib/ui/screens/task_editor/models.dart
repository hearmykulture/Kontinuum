// task_editor/models.dart
import 'package:flutter/foundation.dart'; // ChangeNotifier, ValueNotifier, listEquals
import 'package:hive/hive.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/stat_history_entry.dart';

/// A single selected stat with its amount.
class StatPick {
  final String id;
  final int amount;

  const StatPick({required this.id, this.amount = 1});

  // ── Back-compat shims (old code sometimes reads .statId / .value) ─────────
  @Deprecated('Use .id')
  String get statId => id;

  @Deprecated('Use .amount')
  int get value => amount;

  /// copyWith supports both new and legacy parameter names.
  StatPick copyWith({
    String? id,
    String? statId, // legacy alias
    int? amount,
    int? value, // legacy alias
  }) {
    final newId = id ?? statId ?? this.id;
    final newAmount = amount ?? value ?? this.amount;
    return StatPick(id: newId, amount: newAmount);
  }

  /// Json helpers that tolerate both new and legacy payload shapes.
  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
      };

  factory StatPick.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['statId'];
    if (rawId == null) {
      throw ArgumentError('StatPick.fromJson: missing id/statId');
    }
    final dynamic rawAmt = json['amount'] ?? json['value'] ?? 1;
    final int amt =
        (rawAmt is num) ? rawAmt.toInt() : int.tryParse('$rawAmt') ?? 1;
    return StatPick(id: rawId as String, amount: amt);
  }

  @override
  bool operator ==(Object other) =>
      other is StatPick && other.id == id && other.amount == amount;

  @override
  int get hashCode => Object.hash(id, amount);

  @override
  String toString() => 'StatPick(id: $id, amount: $amount)';
}

/// Returned to the caller when saving a task.
class TaskEditorResult {
  final String title;
  final bool repeatOnCompletion;
  final bool hasReminder;
  final bool hasDeadline;
  final List<ChecklistEntry> checklist;
  final DateTime? date; // null => No Date / Someday
  final DateTime? deadline; // null => no deadline selected
  final bool someday; // explicit Someday flag (distinct from No Date)

  /// Multiple stats may be selected.
  final List<StatPick> stats;

  /// Legacy single-stat fields (kept for back-compat; ignored if [stats] not empty).
  final String? statId;
  final int statAmount;

  const TaskEditorResult({
    required this.title,
    required this.repeatOnCompletion,
    required this.hasReminder,
    required this.hasDeadline,
    required this.checklist,
    required this.date,
    this.deadline,
    required this.someday,
    this.stats = const [],
    this.statId,
    this.statAmount = 1,
  });
}

/// A single checklist entry (subtask).
class ChecklistEntry {
  final String text;
  final bool done;
  const ChecklistEntry({required this.text, required this.done});
}

/// Immutable value for task options.
class TaskOptionsValue {
  final DateTime? date; // null => No Date (or Someday if [someday] true)
  final bool someday; // explicitly Someday
  final bool repeatsDaily; // repeat on completion (daily)
  final bool hasReminder;
  final bool hasDeadline;
  final DateTime? deadline;

  /// Multiple stat selections.
  final List<StatPick> stats;

  /// Legacy single-stat (kept for compatibility with older call sites).
  final String? statId;
  final int statAmount;

  const TaskOptionsValue({
    this.date,
    this.someday = false,
    this.repeatsDaily = false,
    this.hasReminder = false,
    this.hasDeadline = false,
    this.deadline,
    this.stats = const [],
    this.statId,
    this.statAmount = 1,
  });

  TaskOptionsValue copyWith({
    DateTime? date,
    bool? someday,
    bool? repeatsDaily,
    bool? hasReminder,
    bool? hasDeadline,
    DateTime? deadline,
    List<StatPick>? stats,
    String? statId,
    int? statAmount,
  }) {
    return TaskOptionsValue(
      date: date ?? this.date,
      someday: someday ?? this.someday,
      repeatsDaily: repeatsDaily ?? this.repeatsDaily,
      hasReminder: hasReminder ?? this.hasReminder,
      hasDeadline: hasDeadline ?? this.hasDeadline,
      deadline: deadline ?? this.deadline,
      stats: stats ?? this.stats,
      statId: statId ?? this.statId,
      statAmount: statAmount ?? this.statAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskOptionsValue &&
      other.date == date &&
      other.someday == someday &&
      other.repeatsDaily == repeatsDaily &&
      other.hasReminder == hasReminder &&
      other.hasDeadline == hasDeadline &&
      other.deadline == deadline &&
      listEquals(other.stats, stats) &&
      other.statId == statId &&
      other.statAmount == statAmount;

  @override
  int get hashCode => Object.hash(
        date,
        someday,
        repeatsDaily,
        hasReminder,
        hasDeadline,
        deadline,
        Object.hashAll(stats),
        statId,
        statAmount,
      );
}

/// Controller so parent can read/write options.
class TaskOptionsController extends ChangeNotifier {
  TaskOptionsController([TaskOptionsValue? initial])
      : dateN = ValueNotifier<DateTime?>(initial?.date),
        somedayN = ValueNotifier<bool>(initial?.someday ?? false),
        repeatsDailyN = ValueNotifier<bool>(initial?.repeatsDaily ?? false),
        hasReminderN = ValueNotifier<bool>(initial?.hasReminder ?? false),
        deadlineN = ValueNotifier<DateTime?>(initial?.deadline),
        hasDeadlineN = ValueNotifier<bool>(initial?.hasDeadline ?? false),
        statsN = ValueNotifier<List<StatPick>>(
            List<StatPick>.from(initial?.stats ?? const [])),
        // Legacy mirrors
        statIdN = ValueNotifier<String?>(initial?.statId),
        statAmountN = ValueNotifier<int>(initial?.statAmount ?? 1) {
    void relay() {
      if (_squelch) return;
      notifyListeners();
    }

    for (final ln in _allNotifiers) {
      ln.addListener(relay);
    }
  }

  // Field-level notifiers
  final ValueNotifier<DateTime?> dateN;
  final ValueNotifier<bool> somedayN;
  final ValueNotifier<bool> repeatsDailyN;
  final ValueNotifier<bool> hasReminderN;
  final ValueNotifier<DateTime?> deadlineN;
  final ValueNotifier<bool> hasDeadlineN;

  /// NEW multi-stat list
  final ValueNotifier<List<StatPick>> statsN;

  /// Legacy single-stat notifiers (kept so older UI can still compile if referenced).
  final ValueNotifier<String?> statIdN;
  final ValueNotifier<int> statAmountN;

  Iterable<Listenable> get _allNotifiers => <Listenable>[
        dateN,
        somedayN,
        repeatsDailyN,
        hasReminderN,
        deadlineN,
        hasDeadlineN,
        statsN,
        statIdN,
        statAmountN,
      ];

  bool _squelch = false;

  TaskOptionsValue get value => TaskOptionsValue(
        date: dateN.value,
        someday: somedayN.value,
        repeatsDaily: repeatsDailyN.value,
        hasReminder: hasReminderN.value,
        hasDeadline: hasDeadlineN.value,
        deadline: deadlineN.value,
        stats: List<StatPick>.from(statsN.value),
        // legacy mirror from first selected if present
        statId: statsN.value.isNotEmpty ? statsN.value.first.id : statIdN.value,
        statAmount: statsN.value.isNotEmpty
            ? statsN.value.first.amount
            : statAmountN.value,
      );

  set value(TaskOptionsValue v) {
    _squelch = true;
    _setIfChanged(dateN, v.date);
    _setIfChanged(somedayN, v.someday);
    _setIfChanged(repeatsDailyN, v.repeatsDaily);
    _setIfChanged(hasReminderN, v.hasReminder);
    _setIfChanged(hasDeadlineN, v.hasDeadline);
    _setIfChanged(deadlineN, v.deadline);
    _setIfChangedList(statsN, v.stats);
    // keep legacy mirrors in sync
    _setIfChanged(statIdN, v.statId);
    _setIfChanged(statAmountN, v.statAmount);
    _squelch = false;
    notifyListeners(); // single batched tick
  }

  void update(TaskOptionsValue Function(TaskOptionsValue) fn) {
    value = fn(value);
  }

  // ----- Multi-stat helpers -----
  void toggleStat(String id) {
    final list = List<StatPick>.from(statsN.value);
    final idx = list.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add(StatPick(id: id, amount: 1));
    }
    statsN.value = list;
  }

  void setStatAmount(String id, int amount) {
    amount = amount.clamp(1, 999999);
    final list = List<StatPick>.from(statsN.value);
    final idx = list.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(amount: amount);
      statsN.value = list;
    }
  }

  void removeStat(String id) {
    final list = List<StatPick>.from(statsN.value)
      ..removeWhere((s) => s.id == id);
    statsN.value = list;
  }

  static void _setIfChanged<T>(ValueNotifier<T> n, T newV) {
    if (n.value != newV) n.value = newV;
  }

  static void _setIfChangedList<T>(ValueNotifier<List<T>> n, List<T> newV) {
    if (!listEquals(n.value, newV)) n.value = List<T>.from(newV);
  }

  @override
  void dispose() {
    dateN.dispose();
    somedayN.dispose();
    repeatsDailyN.dispose();
    hasReminderN.dispose();
    deadlineN.dispose();
    hasDeadlineN.dispose();
    statsN.dispose();
    statIdN.dispose();
    statAmountN.dispose();
    super.dispose();
  }
}

/* ──────────────────────────────────────────────────────────────
   OPTIONAL: call this from your task-complete path
   ────────────────────────────────────────────────────────────── */

class TaskStatRewarder {
  /// Safe no-op if [statId] is null. Adjust box names if yours differ.
  static Future<void> rewardIfAny(String? statId, int amount) async {
    if (statId == null) return;
    await rewardAll([StatPick(id: statId, amount: amount)]);
  }

  /// Reward multiple stats at once.
  static Future<void> rewardAll(List<StatPick> picks) async {
    if (picks.isEmpty) return;
    final statsBox = await Hive.openBox<Stat>('statsBox');
    final historyBox = await Hive.openBox<StatHistoryEntry>('statHistoryBox');

    for (final pick in picks) {
      final stat = statsBox.get(pick.id);
      if (stat != null) {
        stat.count += pick.amount;
        stat.xp += stat.averageMinutesPerUnit * pick.amount;
        await stat.save();
      }
      final int xpGain = stat != null
          ? stat.averageMinutesPerUnit * pick.amount
          : 0;
      await historyBox.add(StatHistoryEntry(
        statId: pick.id,
        date: DateTime.now(),
        amount: pick.amount, // unit delta
        xpDelta: xpGain,
        skillId: null,
        objectiveId: null,
      ));
    }
  }
}
