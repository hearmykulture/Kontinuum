import 'package:hive/hive.dart';
import 'package:kontinuum/utils/date_keys.dart';

part 'objective.g.dart';

@HiveType(typeId: 2)
enum ObjectiveType {
  @HiveField(0)
  standard,
  @HiveField(1)
  tally,
  @HiveField(3)
  stopwatch,
  @HiveField(4)
  subtask,
  @HiveField(6)
  abstinence, // legacy / kept for Hive compatibility
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

  /// Legacy single-number progress
  @HiveField(14)
  int completedAmount;

  @HiveField(15)
  bool isCompleted;

  /// If an objective paid a custom XP (rare)
  @HiveField(16)
  int? actualXpEarned;

  @HiveField(17)
  DateTime? completedOn;

  /// Per-date progress for tally/stopwatch.
  /// Keys = local 'yyyy-MM-dd'
  @HiveField(18)
  Map<String, int> completedAmounts;

  /// Interval schedule (optional).
  /// (date - repeatAnchorDate).inDays % repeatEveryNDays == 0
  @HiveField(19)
  final int? repeatEveryNDays;

  @HiveField(20)
  final DateTime? repeatAnchorDate;

  // ===== abstinence-specific =====
  @HiveField(21)
  DateTime? abstinenceStartDate;

  @HiveField(22)
  DateTime? abstinenceLastRelapseDate;

  @HiveField(23)
  int abstinenceCurrentStreakDays;

  @HiveField(24)
  int abstinenceLongestStreakDays;

  /// Map<yyyy-MM-dd, true> for relapse days
  @HiveField(25)
  Map<String, bool> abstinenceRelapsesByDate;

  /// if true → provider can auto-mark “stayed clean”
  @HiveField(26)
  bool abstinenceAutoCompleteDaily;

  /// real switch we use now (not the enum)
  @HiveField(27)
  bool abstinenceEnabled;

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
    // abstinence
    this.abstinenceStartDate,
    this.abstinenceLastRelapseDate,
    int? abstinenceCurrentStreakDays,
    int? abstinenceLongestStreakDays,
    Map<String, bool>? abstinenceRelapsesByDate,
    bool? abstinenceAutoCompleteDaily,
    bool? abstinenceEnabled,
  })  : completedAmounts = completedAmounts ?? <String, int>{},
        abstinenceCurrentStreakDays = abstinenceCurrentStreakDays ?? 0,
        abstinenceLongestStreakDays = abstinenceLongestStreakDays ?? 0,
        abstinenceRelapsesByDate = abstinenceRelapsesByDate ?? <String, bool>{},
        abstinenceAutoCompleteDaily = abstinenceAutoCompleteDaily ?? true,
        abstinenceEnabled = abstinenceEnabled ?? false;

  // ===== helpers =====
  bool isActiveOnWeekday(int weekday) => activeDays[weekday] == true;

  String _dateKey(DateTime date) =>
      DateKeys.ymd(DateKeys.dateOnly(date)); // single source

  int getCompletedAmount(DateTime date) =>
      completedAmounts[_dateKey(date)] ?? 0;

  void setCompletedAmount(DateTime date, int amount) {
    completedAmounts[_dateKey(date)] = amount;
  }

  void clearCompletedAmount(DateTime date) {
    completedAmounts.remove(_dateKey(date));
  }

  /// Normalized completion ratio for a specific calendar day.
  ///
  /// - standard / subtask → 0 or 1 based on [isCompleted]
  /// - tally / stopwatch → amount / targetAmount (clamped 0–1) per day
  /// - abstinence → current streak / longest streak (clamped 0–1)
  double completionRatioForDate(DateTime date) {
    if (isAbstinence) {
      final days = abstinenceDaysOn(date);
      if (days <= 0) return 0.0;
      final denom =
          abstinenceLongestStreakDays > 0 ? abstinenceLongestStreakDays : days;
      if (denom <= 0) return 0.0;
      return days / denom.clamp(0.0, 1.0);
    }

    if (type == ObjectiveType.tally || type == ObjectiveType.stopwatch) {
      final amount = getCompletedAmount(date);
      final denom = targetAmount <= 0 ? 1 : targetAmount;
      return amount / denom.clamp(0.0, 1.0);
    }

    // Standard one-shot style objectives are binary per day.
    return isCompleted ? 1.0 : 0.0;
  }

  bool isActiveOnDate(DateTime date) {
    final DateTime d = DateKeys.dateOnly(date);
    final DateTime? anchor =
        repeatAnchorDate != null ? DateKeys.dateOnly(repeatAnchorDate!) : null;

    if (anchor != null && d.isBefore(anchor)) return false;

    if (repeatEveryNDays != null && anchor != null) {
      final delta = d.difference(anchor).inDays;
      if (delta < 0) return false;
      return delta % repeatEveryNDays! == 0;
    }
    return isActiveOnWeekday(d.weekday);
  }

  // ===== abstinence helpers =====
  String _absKey(DateTime date) => DateKeys.ymd(DateKeys.dateOnly(date));

  bool isRelapseOn(DateTime date) =>
      abstinenceRelapsesByDate[_absKey(date)] == true;

  void markRelapseOn(DateTime date) {
    if (!abstinenceEnabled) return;
    final k = _absKey(date);
    abstinenceRelapsesByDate[k] = true;
    final day = DateKeys.dateOnly(date);
    abstinenceLastRelapseDate = day;
    abstinenceCurrentStreakDays = 0;
    // restart run from this day
    abstinenceStartDate = day;
  }

  bool get isAbstinence =>
      type == ObjectiveType.abstinence || abstinenceEnabled == true;

  /// Latest relapse on or before [day], using the per-day relapse map.
  DateTime? _latestAbstinenceRelapseOnOrBefore(DateTime day) {
    if (abstinenceRelapsesByDate.isEmpty) {
      return abstinenceLastRelapseDate;
    }

    final dayKey = DateKeys.ymd(DateKeys.dateOnly(day));
    DateTime? latest;

    abstinenceRelapsesByDate.forEach((k, v) {
      if (!v) return;
      if (k.compareTo(dayKey) > 0) return;

      // Parse yyyy-MM-dd
      final parts = k.split('-');
      if (parts.length != 3) return;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final dayNum = int.tryParse(parts[2]);
      if (year == null || month == null || dayNum == null) return;

      final dt = DateTime(year, month, dayNum);
      if (latest == null || dt.isAfter(latest!)) {
        latest = dt;
      }
    });

    return latest ?? abstinenceLastRelapseDate;
  }

  /// Days clean on [day] according to this objective's abstinence fields.
  int abstinenceDaysOn(DateTime day) {
    if (!isAbstinence) return 0;

    final d = DateKeys.dateOnly(day);
    final base = _latestAbstinenceRelapseOnOrBefore(d) ?? abstinenceStartDate;
    if (base == null) return 0;

    final diff = d.difference(base).inDays + 1;
    if (diff < 0) return 0;
    return diff;
  }

  // ===== copy =====
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
    // abstinence
    DateTime? abstinenceStartDate,
    DateTime? abstinenceLastRelapseDate,
    int? abstinenceCurrentStreakDays,
    int? abstinenceLongestStreakDays,
    Map<String, bool>? abstinenceRelapsesByDate,
    bool? abstinenceAutoCompleteDaily,
    bool? abstinenceEnabled,
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
      completedAmounts: completedAmounts ?? Map.of(this.completedAmounts),
      repeatEveryNDays: repeatEveryNDays ?? this.repeatEveryNDays,
      repeatAnchorDate: repeatAnchorDate ?? this.repeatAnchorDate,
      // abstinence
      abstinenceStartDate: abstinenceStartDate ?? this.abstinenceStartDate,
      abstinenceLastRelapseDate:
          abstinenceLastRelapseDate ?? this.abstinenceLastRelapseDate,
      abstinenceCurrentStreakDays:
          abstinenceCurrentStreakDays ?? this.abstinenceCurrentStreakDays,
      abstinenceLongestStreakDays:
          abstinenceLongestStreakDays ?? this.abstinenceLongestStreakDays,
      abstinenceRelapsesByDate: abstinenceRelapsesByDate ??
          Map<String, bool>.from(this.abstinenceRelapsesByDate),
      abstinenceAutoCompleteDaily:
          abstinenceAutoCompleteDaily ?? this.abstinenceAutoCompleteDaily,
      abstinenceEnabled: abstinenceEnabled ?? this.abstinenceEnabled,
    );
  }
}
