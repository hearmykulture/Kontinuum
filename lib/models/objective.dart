import 'package:hive/hive.dart';

part 'objective.g.dart';

@HiveType(typeId: 2)
enum ObjectiveType {
  @HiveField(0)
  standard,

  @HiveField(1)
  tally,

  @HiveField(2)
  writingPrompt,

  @HiveField(3)
  stopwatch,

  @HiveField(4)
  subtask,

  @HiveField(5)
  reflective,
}

@HiveType(typeId: 3)
class Objective extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final ObjectiveType type;

  @HiveField(3)
  final List<String> categoryIds;

  @HiveField(4)
  final List<String> statIds;

  /// Target count (or minutes for stopwatch)
  @HiveField(5)
  final int targetAmount;

  @HiveField(6)
  final int xpReward;

  /// Weekday schedule: 1=Mon ... 7=Sun
  @HiveField(7)
  final Map<int, bool> activeDays;

  @HiveField(8)
  final List<String> subtaskIds;

  @HiveField(9)
  final List<String> prerequisiteIds;

  @HiveField(10)
  final String? description;

  @HiveField(11)
  final String? writingBlockId;

  @HiveField(12)
  bool isLocked;

  @HiveField(13)
  String? lockedReason;

  /// Legacy single-number progress (still used for quick glance)
  @HiveField(14)
  int completedAmount;

  @HiveField(15)
  bool isCompleted;

  /// If an objective paid a custom XP (rare)
  @HiveField(16)
  int? actualXpEarned;

  @HiveField(17)
  DateTime? completedOn;

  /// Per-date progress for tally/stopwatch
  @HiveField(18)
  Map<String, int> completedAmounts;

  /// ────────────────────────────────────────────────────────────────────────────
  /// NEW: Interval schedule (optional)
  /// If set, the objective is active on dates where
  /// (date - repeatAnchorDate).inDays % repeatEveryNDays == 0
  /// You can use this alongside or instead of [activeDays].
  /// ────────────────────────────────────────────────────────────────────────────
  @HiveField(19)
  final int? repeatEveryNDays; // e.g. 2 = every other day

  @HiveField(20)
  final DateTime? repeatAnchorDate; // usually creation date or explicit start

  Objective({
    required this.id,
    required this.title,
    required this.type,
    required this.categoryIds,
    required this.statIds,
    required this.targetAmount,
    required this.xpReward,
    required this.activeDays,
    this.subtaskIds = const [],
    this.prerequisiteIds = const [],
    this.description,
    this.writingBlockId,
    this.isLocked = false,
    this.lockedReason,
    this.completedAmount = 0,
    this.isCompleted = false,
    this.actualXpEarned,
    this.completedOn,
    Map<String, int>? completedAmounts,
    this.repeatEveryNDays,
    this.repeatAnchorDate,
  }) : completedAmounts = completedAmounts ?? {};

  // Helpers
  bool isActiveOnWeekday(int weekday) => activeDays[weekday] == true;

  String _dateKey(DateTime date) => date.toIso8601String().substring(0, 10);

  int getCompletedAmount(DateTime date) =>
      completedAmounts[_dateKey(date)] ?? 0;

  void setCompletedAmount(DateTime date, int amount) {
    completedAmounts[_dateKey(date)] = amount;
  }

  void clearCompletedAmount(DateTime date) {
    completedAmounts.remove(_dateKey(date));
  }

  double completionRatioForDate(DateTime date) {
    final amount = getCompletedAmount(date);
    return targetAmount == 0 ? 0 : (amount / targetAmount).clamp(0.0, 1.0);
  }

  /// NEW: decides if this objective should appear on a given [date].
  /// Priority:
  /// 1) If interval is configured → use interval rule.
  /// 2) else → fall back to weekday toggle map.
  bool isActiveOnDate(DateTime date) {
    if (repeatEveryNDays != null && repeatAnchorDate != null) {
      final a = DateTime(
        repeatAnchorDate!.year,
        repeatAnchorDate!.month,
        repeatAnchorDate!.day,
      );
      final d = DateTime(date.year, date.month, date.day);
      final delta = d.difference(a).inDays;
      if (delta < 0) return false;
      return delta % repeatEveryNDays! == 0;
    }
    return isActiveOnWeekday(date.weekday);
  }

  Objective copyWith({
    String? title,
    String? description,
    String? writingBlockId,
    int? completedAmount,
    bool? isCompleted,
    bool? isLocked,
    String? lockedReason,
    int? actualXpEarned,
    DateTime? completedOn,
    Map<String, int>? completedAmounts,
    Map<int, bool>? activeDays,
    int? repeatEveryNDays,
    DateTime? repeatAnchorDate,
  }) {
    return Objective(
      id: id,
      title: title ?? this.title,
      type: type,
      categoryIds: categoryIds,
      statIds: statIds,
      targetAmount: targetAmount,
      xpReward: xpReward,
      activeDays: activeDays ?? this.activeDays,
      subtaskIds: subtaskIds,
      prerequisiteIds: prerequisiteIds,
      description: description ?? this.description,
      writingBlockId: writingBlockId ?? this.writingBlockId,
      isLocked: isLocked ?? this.isLocked,
      lockedReason: lockedReason ?? this.lockedReason,
      completedAmount: completedAmount ?? this.completedAmount,
      isCompleted: isCompleted ?? this.isCompleted,
      actualXpEarned: actualXpEarned ?? this.actualXpEarned,
      completedOn: completedOn ?? this.completedOn,
      completedAmounts: completedAmounts ?? Map.from(this.completedAmounts),
      repeatEveryNDays: repeatEveryNDays ?? this.repeatEveryNDays,
      repeatAnchorDate: repeatAnchorDate ?? this.repeatAnchorDate,
    );
  }
}
