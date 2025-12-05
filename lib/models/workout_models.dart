import 'package:hive/hive.dart';

part 'workout_models.g.dart';

/// Default % used for adaptive drop/ramp sets when no preference exists.
const double kDefaultAdaptivePercent = 0.15;

/// ---------- ENUMS ----------

@HiveType(typeId: 200)
enum DietGoal {
  @HiveField(0)
  cut,
  @HiveField(1)
  maintain,
  @HiveField(2)
  bulk,
}

@HiveType(typeId: 201)
enum DietStrictness {
  @HiveField(0)
  soft,
  @HiveField(1)
  hard,
}

/// Intent drives filters + stat mapping
@HiveType(typeId: 202)
enum ExerciseIntent {
  @HiveField(0)
  strength,
  @HiveField(1)
  hypertrophy,
  @HiveField(2)
  endurance,
  @HiveField(3)
  mobility,
  @HiveField(4)
  conditioning,
}

@HiveType(typeId: 203)
enum ExerciseDifficulty {
  @HiveField(0)
  beginner,
  @HiveField(1)
  intermediate,
  @HiveField(2)
  advanced,
}

/// Workout block prescription types (not the editor block type)
@HiveType(typeId: 204)
enum BlockType {
  @HiveField(0)
  set,
  @HiveField(1)
  superset,
  @HiveField(2)
  circuit,
  @HiveField(3)
  emom,
  @HiveField(4)
  amrap,
}

@HiveType(typeId: 218)
enum RepetitionMode {
  @HiveField(0)
  weekly,
  @HiveField(1)
  interval,
}

@HiveType(typeId: 219)
enum RepetitionUnit {
  @HiveField(0)
  days,
  @HiveField(1)
  weeks,
  @HiveField(2)
  months,
  @HiveField(3)
  years,
}

/// ---------- CORE CONFIG MODELS ----------

@HiveType(typeId: 205)
class DietSettings {
  @HiveField(0)
  DietGoal goal;

  @HiveField(1)
  int kcalPerDay;

  @HiveField(2)
  int proteinTargetG;

  @HiveField(3)
  DietStrictness strictness;

  DietSettings({
    required this.goal,
    required this.kcalPerDay,
    required this.proteinTargetG,
    required this.strictness,
  });
}

@HiveType(typeId: 206)
class Exercise extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Primary + secondary muscles, e.g. ["chest","triceps"]
  @HiveField(2)
  List<String> muscles;

  /// e.g. ["barbell","bench"] or ["bodyweight"]
  @HiveField(3)
  List<String> equipment;

  @HiveField(4)
  ExerciseDifficulty difficulty;

  /// High-level training intent (drives stat category)
  @HiveField(5)
  ExerciseIntent intent;

  /// Raw instructions
  @HiveField(6)
  String instructions;

  /// Coaching cues / reminders ("brace core", "elbows tucked")
  @HiveField(7)
  List<String> cues;

  /// preview media (gif/url/asset path). optional.
  @HiveField(8)
  String? mediaUrl;

  /// license / attribution string
  @HiveField(9)
  String? attribution;

  /// Primary muscle groups emphasized by the movement.
  @HiveField(10)
  List<String> primaryMuscles;

  /// Secondary / supporting muscle groups that still receive stimulus.
  @HiveField(11)
  List<String> secondaryMuscles;

  Exercise({
    required this.id,
    required this.name,
    required this.muscles,
    required this.equipment,
    required this.difficulty,
    required this.intent,
    required this.instructions,
    required this.cues,
    List<String>? primaryMuscles,
    List<String>? secondaryMuscles,
    this.mediaUrl,
    this.attribution,
  })  : primaryMuscles = primaryMuscles ?? List<String>.from(muscles),
        secondaryMuscles = secondaryMuscles ?? const <String>[];
}

/// A single prescribed exercise inside a block (with targets & PO memory).
@HiveType(typeId: 207)
class WorkoutItem {
  /// Which exercise this references
  @HiveField(0)
  String exerciseId;

  /// e.g. 3 sets
  @HiveField(1)
  int targetSets;

  /// Typical hypertrophy/strength rep targets (e.g. 10, or 5)
  @HiveField(2)
  int? targetReps;

  /// For timed work (circuits, EMOM/AMRAP blocks, conditioning)
  @HiveField(3)
  int? targetTimeSec;

  /// Prescribed rest between sets (seconds)
  @HiveField(4)
  int? restSec;

  /// Suggested load for first set (kg/lb depending on prefs)
  @HiveField(5)
  double? targetLoad;

  /// Coach notes / general notes for this item
  @HiveField(6)
  String? notes;

  /// Up to ~2 pinned cues surfaced inline during Session
  @HiveField(7)
  List<String> cueChips;

  /// "Form check" reminders we want to surface next time if RPE blew up
  @HiveField(8)
  List<String> formChecks;

  /// Progressive Overload / safety tracking
  /// - how many consecutive misses on this lift
  @HiveField(9)
  int consecutiveMisses;

  /// last suggested load (kg) we told the user
  @HiveField(10)
  double? lastSuggestedLoadKg;

  /// last target reps we told the user
  @HiveField(11)
  int? lastTargetReps;

  /// last reported RPE
  @HiveField(12)
  double? lastLoggedRpe;

  /// Enable adaptive drop/ramp tooling for this exercise.
  @HiveField(13)
  bool adaptiveSetsEnabled;

  /// Default % (0.10 = 10%) used when suggesting adaptive changes.
  @HiveField(14)
  double? adaptivePercent;

  WorkoutItem({
    required this.exerciseId,
    required this.targetSets,
    this.targetReps,
    this.targetTimeSec,
    this.restSec,
    this.targetLoad,
    this.notes,
    List<String>? cueChips,
    List<String>? formChecks,
    int? consecutiveMisses,
    this.lastSuggestedLoadKg,
    this.lastTargetReps,
    this.lastLoggedRpe,
    bool? adaptiveSetsEnabled,
    this.adaptivePercent,
  })  : cueChips = cueChips ?? const [],
        formChecks = formChecks ?? const [],
        consecutiveMisses = consecutiveMisses ?? 0,
        adaptiveSetsEnabled = adaptiveSetsEnabled ?? false;
}

/// A block of 1+ WorkoutItem. This maps to cards in Session UI.
@HiveType(typeId: 208)
class WorkoutBlock {
  @HiveField(0)
  BlockType? type;

  /// Optional label like "Warm-up", "Main Lift", "Finisher"
  @HiveField(1)
  String? title;

  @HiveField(2)
  List<WorkoutItem> items;

  /// Optional notes specific to this block.
  @HiveField(3)
  String? note;

  WorkoutBlock({
    this.type,
    this.title,
    required this.items,
    this.note,
  });

  WorkoutBlock copyWith({
    BlockType? type,
    bool setTypeNull = false,
    String? title,
    List<WorkoutItem>? items,
    String? note,
    bool setNoteNull = false,
  }) {
    return WorkoutBlock(
      type: setTypeNull ? null : (type ?? this.type),
      title: title ?? this.title,
      items: items ?? this.items,
      note: setNoteNull ? null : (note ?? this.note),
    );
  }
}

/// A specific workout template (like "Push A", "Leg Day Heavy").
@HiveType(typeId: 209)
class Workout extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  List<WorkoutBlock> blocks;

  /// General notes for the whole workout (tempo, RPE caps, etc.)
  @HiveField(3)
  String? notes;

  /// Optional flag to mark this workout as a "rest day template"
  /// (e.g. used for active recovery / off-day cards).
  ///
  /// Backwards compatible: legacy records will deserialize with `false`
  /// when read via [WorkoutAdapterSafe].
  @HiveField(4)
  bool isRestTemplate;

  Workout({
    required this.id,
    required this.title,
    required this.blocks,
    this.notes,
    this.isRestTemplate = false,
  });
}

extension WorkoutBlockExtensions on WorkoutBlock {
  bool get isBreakBlock {
    if (type != null) return false;
    final noteText = (note ?? '').toLowerCase();
    return noteText.startsWith('duration:') && noteText.contains('type:');
  }

  bool get isWarmupBlock {
    if (note == 'type:warmup') return true;
    if ((note ?? '').isEmpty) {
      final normalizedTitle = title?.toLowerCase() ?? '';
      return normalizedTitle.contains('warmup') ||
          normalizedTitle.contains('warm-up');
    }
    return false;
  }

  bool get isCooldownBlock {
    if (note == 'type:cooldown') return true;
    if ((note ?? '').isEmpty) {
      final normalizedTitle = title?.toLowerCase() ?? '';
      return normalizedTitle.contains('cooldown') ||
          normalizedTitle.contains('cool-down');
    }
    return false;
  }

  bool get isPureNoteBlock {
    if (type != null) return false;
    if (items.isNotEmpty) return false;
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    if (isBreakBlock || isWarmupBlock || isCooldownBlock) return false;
    return true;
  }
}

extension WorkoutRestExtensions on Workout {
  /// Convenience: a workout is *logically* a rest template either if it is
  /// explicitly flagged or if it has no blocks.
  bool get isLogicallyRestTemplate => isRestTemplate || blocks.isEmpty;
}

/// A Routine = a program container.
@HiveType(typeId: 210)
class Routine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Progressive overload ON/OFF
  @HiveField(2)
  bool poEnabled;

  /// Required diet card
  @HiveField(3)
  DietSettings diet;

  /// Reference the workouts that belong to this routine
  @HiveField(4)
  List<String> workoutIds;

  /// e.g. created timestamp (msSinceEpoch)
  @HiveField(5)
  int createdAtMs;

  /// Optional explicit rest schedule configured at the routine level.
  @HiveField(6)
  RestSchedule? restSchedule;

  /// Whether the routine uses weekly picks or interval-style rest.
  @HiveField(7)
  RepetitionMode scheduleMode;

  Routine({
    required this.id,
    required this.name,
    required this.poEnabled,
    required this.diet,
    required this.workoutIds,
    required this.createdAtMs,
    this.restSchedule,
    RepetitionMode? scheduleMode,
  })  : scheduleMode =
            scheduleMode ?? restSchedule?.mode ?? RepetitionMode.weekly {
    if (this.restSchedule != null &&
        this.restSchedule!.mode != this.scheduleMode) {
      this.restSchedule = this.restSchedule!.copyWith(
        mode: this.scheduleMode,
      );
    }
  }
}

/// ---------- LOGGING MODELS (Session data) ----------

@HiveType(typeId: 211)
class SetLog {
  @HiveField(0)
  int? reps;

  @HiveField(1)
  double? load;

  @HiveField(2)
  double? rpe;

  @HiveField(3)
  String? notes;

  @HiveField(4)
  int tsMs;

  SetLog({
    this.reps,
    this.load,
    this.rpe,
    this.notes,
    required this.tsMs,
  });
}

@HiveType(typeId: 213)
class StatDelta {
  @HiveField(0)
  int strength;

  @HiveField(1)
  int hypertrophy;

  @HiveField(2)
  int endurance;

  @HiveField(3)
  int mobility;

  StatDelta({
    this.strength = 0,
    this.hypertrophy = 0,
    this.endurance = 0,
    this.mobility = 0,
  });

  StatDelta operator +(StatDelta other) {
    return StatDelta(
      strength: strength + other.strength,
      hypertrophy: hypertrophy + other.hypertrophy,
      endurance: endurance + other.endurance,
      mobility: mobility + other.mobility,
    );
  }
}

@HiveType(typeId: 212)
class ExerciseLog {
  @HiveField(0)
  String exerciseId;

  @HiveField(1)
  List<SetLog> sets;

  /// total volume for this exercise (sum weight*reps or equivalent)
  @HiveField(2)
  double volume;

  /// flags like "rep PR", "volume PR". simple string tags for now.
  @HiveField(3)
  List<String> prFlags;

  /// StatDelta awarded when this exercise was completed
  @HiveField(4)
  StatDelta statDelta;

  ExerciseLog({
    required this.exerciseId,
    required this.sets,
    required this.volume,
    required this.prFlags,
    required this.statDelta,
  });
}

@HiveType(typeId: 214)
class SessionTotals {
  @HiveField(0)
  double volume;

  @HiveField(1)
  int timeSec;

  @HiveField(2)
  int prCount;

  @HiveField(3)
  StatDelta statDeltas;

  SessionTotals({
    this.volume = 0.0,
    this.timeSec = 0,
    this.prCount = 0,
    required this.statDeltas,
  });
}

@HiveType(typeId: 215)
class WorkoutLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String routineId;

  @HiveField(2)
  String workoutId;

  @HiveField(3)
  String dateYmd;

  @HiveField(4)
  List<ExerciseLog> exerciseLogs;

  @HiveField(5)
  SessionTotals totals;

  /// 'dashboard' | 'mission'
  @HiveField(6)
  String source;

  @HiveField(7)
  String? missionId;

  WorkoutLog({
    required this.id,
    required this.routineId,
    required this.workoutId,
    required this.dateYmd,
    required this.exerciseLogs,
    required this.totals,
    required this.source,
    this.missionId,
  });
}

/// ---------- REST SCHEDULE ----------

/// Rest schedule mirrors [WorkoutSchedule] but is stored alongside it so the
/// system can explicitly model
///   - training days
///   - rest / recovery days
/// using the same repetition semantics.
///
/// Older data that doesn't have an explicit [RestSchedule] will still work:
/// we treat "rest" as the complement of workout days when necessary.
@HiveType(typeId: 221)
class RestSchedule extends HiveObject {
  @HiveField(0)
  RepetitionMode mode;

  /// Weekly mode: which days of the week are explicit rest (0=Mon, 6=Sun).
  @HiveField(1)
  List<bool> weeklyDays;

  /// Interval mode: repeat every N units (optional for rest if you want
  /// explicit patterns like "deload every 4th week").
  @HiveField(2)
  int intervalValue;

  @HiveField(3)
  RepetitionUnit intervalUnit;

  /// Start date for interval calculation (ISO 8601 string)
  @HiveField(4)
  String? intervalStartDateIso;

  RestSchedule({
    this.mode = RepetitionMode.weekly,
    List<bool>? weeklyDays,
    this.intervalValue = 1,
    this.intervalUnit = RepetitionUnit.days,
    this.intervalStartDateIso,
  }) : weeklyDays = weeklyDays ?? List<bool>.filled(7, false);

  RestSchedule copyWith({
    RepetitionMode? mode,
    List<bool>? weeklyDays,
    int? intervalValue,
    RepetitionUnit? intervalUnit,
    String? intervalStartDateIso,
  }) {
    return RestSchedule(
      mode: mode ?? this.mode,
      weeklyDays: weeklyDays ?? List<bool>.from(this.weeklyDays),
      intervalValue: intervalValue ?? this.intervalValue,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      intervalStartDateIso: intervalStartDateIso ?? this.intervalStartDateIso,
    );
  }

  /// True if this rest schedule says the given [date] is a rest day.
  bool isRestOn(DateTime date) {
    if (mode == RepetitionMode.weekly) {
      final dayIndex = date.weekday - 1; // Monday=1 → index 0
      if (dayIndex < 0 || dayIndex >= weeklyDays.length) return false;
      return weeklyDays[dayIndex];
    }

    // Interval semantics mirror WorkoutSchedule.isPrescribedFor.
    if (intervalStartDateIso == null || intervalValue <= 0) {
      return false;
    }

    try {
      final startDate = DateTime.parse(intervalStartDateIso!);
      final normalizedStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final diff = normalizedDate.difference(normalizedStart);

      switch (intervalUnit) {
        case RepetitionUnit.days:
          return diff.inDays >= 0 && diff.inDays % intervalValue == 0;
        case RepetitionUnit.weeks:
          if (diff.inDays < 0) return false;
          final weeks = (diff.inDays / 7).floor();
          return weeks % intervalValue == 0;
        case RepetitionUnit.months:
          final monthsDiff = (normalizedDate.year - normalizedStart.year) * 12 +
              (normalizedDate.month - normalizedStart.month);
          return monthsDiff >= 0 &&
              monthsDiff % intervalValue == 0 &&
              normalizedDate.day == normalizedStart.day;
        case RepetitionUnit.years:
          final yearsDiff = normalizedDate.year - normalizedStart.year;
          return yearsDiff >= 0 &&
              yearsDiff % intervalValue == 0 &&
              normalizedDate.month == normalizedStart.month &&
              normalizedDate.day == normalizedStart.day;
      }
    } catch (_) {
      return false;
    }
  }

  /// Helper to build a weekly rest schedule that is the complement of
  /// [workoutDays]. We always normalize to length 7 (Mon–Sun).
  factory RestSchedule.complementOfWeekly(List<bool> workoutDays) {
    final normalizedWorkout = List<bool>.generate(
      7,
      (i) => i < workoutDays.length ? workoutDays[i] : false,
    );
    final restDays = List<bool>.generate(
      7,
      (i) => !normalizedWorkout[i],
    );
    return RestSchedule(
      mode: RepetitionMode.weekly,
      weeklyDays: restDays,
      intervalValue: 1,
      intervalUnit: RepetitionUnit.days,
    );
  }
}

/// Stores the repetition schedule for a workout (when it should be performed)
@HiveType(typeId: 220)
class WorkoutSchedule extends HiveObject {
  @HiveField(0)
  String workoutId;

  @HiveField(1)
  RepetitionMode mode;

  /// Weekly mode: which days of the week (0=Monday, 6=Sunday)
  @HiveField(2)
  List<bool> weeklyDays;

  /// Interval mode: repeat every N units
  @HiveField(3)
  int intervalValue;

  @HiveField(4)
  RepetitionUnit intervalUnit;

  /// Start date for interval calculation (ISO 8601 string)
  @HiveField(5)
  String? intervalStartDateIso;

  /// Optional explicit rest schedule associated with this workout / routine.
  ///
  /// Legacy records will deserialize with `null`. In that case, rest days can
  /// be derived implicitly as the complement of workout days for simple cases.
  @HiveField(6)
  RestSchedule? restSchedule;

  /// Optional per-date rest overrides (YYYY-MM-DD → isRest).
  ///
  /// This lets a schedule explicitly mark certain calendar days as rest or
  /// non-rest, regardless of the underlying pattern.
  @HiveField(7)
  Map<String, bool>? restOverrides;

  WorkoutSchedule({
    required this.workoutId,
    this.mode = RepetitionMode.weekly,
    List<bool>? weeklyDays,
    this.intervalValue = 1,
    this.intervalUnit = RepetitionUnit.days,
    this.intervalStartDateIso,
    this.restSchedule,
    this.restOverrides,
  }) : weeklyDays = weeklyDays ?? List<bool>.filled(7, false);

  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Set or clear an explicit rest override for a given calendar day.
  ///
  /// - [ymd] must be "YYYY-MM-DD".
  /// - If [isRest] is true, that date is forced REST for this schedule.
  /// - If [isRest] is false, any override for that date is removed so the
  ///   normal pattern (restSchedule / isPrescribedFor) applies again.
  void setRestOverride(String ymd, {required bool isRest}) {
    final map = restOverrides ??= <String, bool>{};
    if (isRest) {
      map[ymd] = true;
    } else {
      map.remove(ymd);
      if (map.isEmpty) {
        restOverrides = null;
      }
    }
  }

  bool hasExplicitRestOverrideFor(DateTime date) {
    final overrides = restOverrides;
    if (overrides == null || overrides.isEmpty) return false;
    final key = _ymd(date);
    return overrides.containsKey(key);
  }

  /// Check if this workout is prescribed for the given date.
  bool isPrescribedFor(DateTime date) {
    if (mode == RepetitionMode.weekly) {
      // Monday = 1, Tuesday = 2, ..., Sunday = 7 in DateTime.weekday
      // We store: 0=Monday, 1=Tuesday, ..., 6=Sunday
      final dayIndex = date.weekday - 1;
      if (dayIndex < 0 || dayIndex >= weeklyDays.length) return false;
      return weeklyDays[dayIndex];
    } else {
      // Interval mode
      if (intervalStartDateIso == null || intervalValue <= 0) return false;
      try {
        final startDate = DateTime.parse(intervalStartDateIso!);
        final normalizedStart =
            DateTime(startDate.year, startDate.month, startDate.day);
        final normalizedDate = DateTime(date.year, date.month, date.day);

        final diff = normalizedDate.difference(normalizedStart);

        switch (intervalUnit) {
          case RepetitionUnit.days:
            return diff.inDays % intervalValue == 0 && diff.inDays >= 0;
          case RepetitionUnit.weeks:
            final days = diff.inDays;
            if (days < 0) return false;
            final weeks = (days / 7).floor();
            return weeks % intervalValue == 0;
          case RepetitionUnit.months:
            final monthsDiff =
                (normalizedDate.year - normalizedStart.year) * 12 +
                    (normalizedDate.month - normalizedStart.month);
            return monthsDiff % intervalValue == 0 &&
                normalizedDate.day == normalizedStart.day &&
                monthsDiff >= 0;
          case RepetitionUnit.years:
            final yearsDiff = normalizedDate.year - normalizedStart.year;
            return yearsDiff % intervalValue == 0 &&
                normalizedDate.month == normalizedStart.month &&
                normalizedDate.day == normalizedStart.day &&
                yearsDiff >= 0;
        }
      } catch (_) {
        return false;
      }
    }
  }

  /// True if, according to overrides + explicit [restSchedule] + implicit
  /// complement-of-workout logic, this date is a rest day.
  bool isRestDay(DateTime date) {
    // 1) Per-date override (takes absolute priority).
    final overrides = restOverrides;
    if (overrides != null && overrides.isNotEmpty) {
      final key = _ymd(date);
      if (overrides.containsKey(key)) {
        return overrides[key] == true;
      }
    }

    // 2) Explicit rest schedule if present.
    final RestSchedule? rs = restSchedule;
    if (rs != null) {
      return rs.isRestOn(date);
    }

    // 3) Legacy / implicit behavior: rest = complement of workout day.
    return !isPrescribedFor(date);
  }

  /// Compute (but do not persist) a weekly [RestSchedule] that is the complement
  /// of this schedule's weeklyDays. Handy for UIs that want a concrete object.
  RestSchedule inferredWeeklyRestSchedule() {
    return RestSchedule.complementOfWeekly(weeklyDays);
  }

  /// Ensure the internal weeklyDays list is exactly 7 entries (Mon–Sun).
  void normalizeWeeklyLength() {
    if (weeklyDays.length == 7) return;
    final normalized = List<bool>.generate(
      7,
      (i) => i < weeklyDays.length ? weeklyDays[i] : false,
    );
    weeklyDays = normalized;
  }
}

/// Call this once after Hive.initFlutter(), before using WorkoutSchedule.
/// (Optional if you already register these adapters via WorkoutBoxes.init).
void registerWorkoutHiveAdapters() {
  // Only register if not already registered elsewhere (to avoid typeId clashes).
  if (!Hive.isAdapterRegistered(218)) {
    Hive.registerAdapter(RepetitionModeAdapter());
  }
  if (!Hive.isAdapterRegistered(219)) {
    Hive.registerAdapter(RepetitionUnitAdapter());
  }
  if (!Hive.isAdapterRegistered(220)) {
    Hive.registerAdapter(WorkoutScheduleAdapter());
  }
  if (!Hive.isAdapterRegistered(221)) {
    Hive.registerAdapter(RestScheduleAdapter());
  }
}
