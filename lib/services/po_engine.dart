// lib/services/po_engine.dart
import 'dart:math' as math;
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/plate_math.dart';

/// Status color mapping in UI:
/// - progress = green
/// - hold = amber
/// - deload = red
enum PoStatus { progress, hold, deload }

/// Lightweight struct we show on the Summary screen under "Next Targets".
///
/// nextLoadKg: what weight to aim for next time (if loaded exercise)
/// nextRepsTarget: what rep target to aim for (for bodyweight / progression by reps)
/// status: progress|hold|deload
class PoPreview {
  final double? nextLoadKg;
  final int? nextRepsTarget;
  final PoStatus status;

  const PoPreview({
    this.nextLoadKg,
    this.nextRepsTarget,
    required this.status,
  });
}

enum AdaptiveAdjustmentKind { drop, ramp }

enum AdaptiveAdjustmentAxis { load, reps, sets }

/// Represents a contextual drop or ramp suggestion we can surface inline
/// inside the session log dialog.
class AdaptiveAdjustmentOption {
  final String id;
  final AdaptiveAdjustmentKind kind;
  final AdaptiveAdjustmentAxis axis;
  final double percent; // stored as positive decimal (0.15 = 15%)
  final double? fromLoad;
  final double? targetLoad;
  final int? fromReps;
  final int? targetReps;
  final int? fromSets;
  final int? targetSets;
  final String rationale;

  const AdaptiveAdjustmentOption({
    required this.id,
    required this.kind,
    required this.axis,
    required this.percent,
    required this.rationale,
    this.fromLoad,
    this.targetLoad,
    this.fromReps,
    this.targetReps,
    this.fromSets,
    this.targetSets,
  });
}

/// Small helper describing how a given calendar day relates to a workout's
/// schedule (training vs. rest). This is used by dashboards and PO summaries
/// when synthesizing routines.
///
/// `isRestDay` consults [WorkoutSchedule.isRestDay] (which in turn respects
/// weekly patterns, interval mode, and one-off overrides).
class WorkoutDayScheduleStatus {
  final DateTime date;
  final bool isWorkoutDay;
  final bool isRestDay;

  const WorkoutDayScheduleStatus({
    required this.date,
    required this.isWorkoutDay,
    required this.isRestDay,
  });
}

/// Compute schedule status for a [date] given a [WorkoutSchedule].
WorkoutDayScheduleStatus getDayScheduleStatus(
  WorkoutSchedule schedule,
  DateTime date,
) {
  final bool workout = schedule.isPrescribedFor(date);
  final bool rest = schedule.isRestDay(date);
  return WorkoutDayScheduleStatus(
    date: date,
    isWorkoutDay: workout && !rest,
    isRestDay: rest && !workout ? true : rest,
  );
}

/// Progressive Overload brain (pure functions).
///
/// We feed it:
/// - the routine's PO toggle
/// - the WorkoutItem (which stores lastSuggestedLoadKg, consecutiveMisses, etc.)
/// - the sets actually logged for that exercise this session
///
/// and it tells us what to show for "Next time".
class ProgressiveOverloadEngine {
  /// Core decision.
  ///
  /// [poEnabled] - if false, we just "hold".
  /// [item] - prescription & PO memory
  /// [performedSets] - sets logged this session for this exercise
  ///
  /// Returns PoPreview for summary UI.
  static PoPreview computeNextTarget({
    required bool poEnabled,
    required WorkoutItem item,
    required List<SetLog> performedSets,
    double barWeightKg = 20.0,
    double minIncrementKg = 1.25,
    double dbIncrementKg = 2.5,
  }) {
    // If PO is off entirely for the routine, we bail early.
    if (!poEnabled) {
      final holdLoad = _baselineLoad(item, performedSets);
      return PoPreview(
        nextLoadKg: holdLoad,
        nextRepsTarget: item.targetReps,
        status: PoStatus.hold,
      );
    }

    // If no sets were logged, can't calculate.
    if (performedSets.isEmpty) {
      final holdLoad = _baselineLoad(item, performedSets);
      return PoPreview(
        nextLoadKg: holdLoad,
        nextRepsTarget: item.targetReps,
        status: PoStatus.hold,
      );
    }

    final SetLog lastSet = performedSets.last;
    final int? targetReps = item.targetReps ?? item.lastTargetReps;
    final int? actualReps = lastSet.reps;
    final double? lastRpe = lastSet.rpe ?? item.lastLoggedRpe;
    final double? lastLoad =
        lastSet.load ?? item.lastSuggestedLoadKg ?? item.targetLoad;

    final bool hitTarget =
        (targetReps != null && actualReps != null && actualReps >= targetReps);

    final bool highRpe = (lastRpe != null && lastRpe >= 9.0);
    final bool lowRpeGood = hitTarget && (lastRpe != null && lastRpe <= 8.0);

    // --- RULES ---

    // 1. Deload check: Miss target reps OR consecutiveMisses >=2
    if (!hitTarget || item.consecutiveMisses >= 2) {
      final reduced = _applyPercent(lastLoad, -0.05);
      final rounded = _roundForEquipment(
        reduced,
        item,
        barWeightKg,
        minIncrementKg,
        dbIncrementKg,
      );
      return PoPreview(
        nextLoadKg: rounded,
        nextRepsTarget: targetReps,
        status: PoStatus.deload,
      );
    }

    // 2. Hold: You hit the target but RPE 9–10 → same load
    if (hitTarget && highRpe) {
      final rounded = _roundForEquipment(
        lastLoad,
        item,
        barWeightKg,
        minIncrementKg,
        dbIncrementKg,
      );
      return PoPreview(
        nextLoadKg: rounded,
        nextRepsTarget: targetReps,
        status: PoStatus.hold,
      );
    }

    // 3. Progress: Hit target with RPE ≤ 8 → +2.5%
    if (lowRpeGood) {
      // If it's bodyweight (no load), we "double progress" via reps before weight.
      if (lastLoad == null || lastLoad <= 0) {
        // Bodyweight path:
        // - bump reps target by +1 or +2 until a cap, then suggest loading
        final int newRepsTarget = targetReps ?? actualReps ?? 0) + 1;
        return PoPreview(
          nextLoadKg: null,
          nextRepsTarget: newRepsTarget,
          status: PoStatus.progress,
        );
      }

      final increased = _applyPercent(lastLoad, 0.025);
      final rounded = _roundForEquipment(
        increased,
        item,
        barWeightKg,
        minIncrementKg,
        dbIncrementKg,
      );
      return PoPreview(
        nextLoadKg: rounded,
        nextRepsTarget: targetReps,
        status: PoStatus.progress,
      );
    }

    // Fallback → Hold.
    final holdLoad = _roundForEquipment(
      lastLoad,
      item,
      barWeightKg,
      minIncrementKg,
      dbIncrementKg,
    );
    return PoPreview(
      nextLoadKg: holdLoad,
      nextRepsTarget: targetReps,
      status: PoStatus.hold,
    );
  }

  /// Volume guardrail:
  /// If average RPE ≥9 across ≥3 exercises → suggest trimming an accessory set.
  static bool volumeGuardrailTriggered(
      Map<String, List<SetLog>> allSetsByExercise) {
    int highCount = 0;
    allSetsByExercise.forEach((_, sets) {
      if (sets.isEmpty) return;
      final avgRpe = _avgRpe(sets);
      if (avgRpe != null && avgRpe >= 9.0) {
        highCount += 1;
      }
    });
    return highCount >= 3;
  }

  // ---- helpers ----

  static double? _baselineLoad(WorkoutItem item, List<SetLog> sets) {
    if (sets.isNotEmpty && sets.last.load != null) {
      return sets.last.load;
    }
    if (item.lastSuggestedLoadKg != null) return item.lastSuggestedLoadKg;
    if (item.targetLoad != null) return item.targetLoad;
    return null;
  }

  static int? _baselineReps(WorkoutItem item, List<SetLog> sets) {
    if (sets.isNotEmpty && sets.last.reps != null) {
      return sets.last.reps;
    }
    if (item.lastTargetReps != null) return item.lastTargetReps;
    if (item.targetReps != null) return item.targetReps;
    return null;
  }

  static double? _applyPercent(double? base, double pct) {
    if (base == null) return null;
    return base * (1.0 + pct);
  }

  static double? _roundForEquipment(
    double? raw,
    WorkoutItem item,
    double barWeightKg,
    double minIncrementKg,
    double dbIncrementKg,
  ) {
    if (raw == null) return null;

    // Heuristic: if it's likely barbell → roundBarbell, else roundToIncrement.
    // We'll guess "barbell" based on the cueChips/notes later.
    // For P0 we just call roundToIncrement with dbIncrementKg unless weight is heavy.
    if (raw >= (barWeightKg + 5)) {
      return PlateMath.roundBarbell(
        raw,
        barWeightKg: barWeightKg,
        minIncrementKg: minIncrementKg,
      );
    } else {
      return PlateMath.roundToIncrement(
        raw,
        incrementKg: dbIncrementKg,
      );
    }
  }

  static double? _avgRpe(List<SetLog> sets) {
    final vals =
        sets.map((s) => s.rpe).where((v) => v != null).cast<double>().toList();
    if (vals.isEmpty) return null;
    final sum = vals.fold<double>(0, (acc, v) => acc + v);
    return sum / vals.length;
  }

  /// Generate contextual adaptive options (drop + ramp) that the Session UI
  /// can render as quick actions next to the log-set dialog.
  static List<AdaptiveAdjustmentOption> buildAdaptiveOptions({
    required WorkoutItem item,
    required List<SetLog> performedSets,
    double percentHint = kDefaultAdaptivePercent,
    double barWeightKg = 20.0,
    double minIncrementKg = 1.25,
    double dbIncrementKg = 2.5,
  }) {
    if (!item.adaptiveSetsEnabled) return const [];

    final double resolvedPercent =
        _clampPercent(percentHint <= 0 ? kDefaultAdaptivePercent : percentHint);
    final List<AdaptiveAdjustmentOption> options = [];

    final double? baseLoad = _baselineLoad(item, performedSets);
    final int? baseReps = _baselineReps(item, performedSets);
    final int baseSets = math.max(1, item.targetSets);

    final SetLog? lastSet =
        performedSets.isNotEmpty ? performedSets.last : null;
    final int? actualReps = lastSet?.reps;
    final int? targetReps = item.targetReps ?? item.lastTargetReps;
    final bool hitTarget =
        targetReps == null || actualReps == null || actualReps >= targetReps;
    final double? lastRpe = lastSet?.rpe ?? item.lastLoggedRpe;
    final bool highRpe = lastRpe != null && lastRpe >= 9.0;
    final bool lowRpe = lastRpe != null && lastRpe <= 8.0;

    for (final axis in AdaptiveAdjustmentAxis.values) {
      final adaptiveDrop = _buildAdaptiveOption(
        kind: AdaptiveAdjustmentKind.drop,
        percent: resolvedPercent,
        item: item,
        baseLoad: baseLoad,
        baseReps: baseReps,
        baseSets: baseSets,
        hitTarget: hitTarget,
        highRpe: highRpe,
        lowRpe: lowRpe,
        barWeightKg: barWeightKg,
        minIncrementKg: minIncrementKg,
        dbIncrementKg: dbIncrementKg,
        forceAxis: axis,
      );
      if (adaptiveDrop != null) {
        options.add(adaptiveDrop);
      }

      final adaptiveRamp = _buildAdaptiveOption(
        kind: AdaptiveAdjustmentKind.ramp,
        percent: resolvedPercent,
        item: item,
        baseLoad: baseLoad,
        baseReps: baseReps,
        baseSets: baseSets,
        hitTarget: hitTarget,
        highRpe: highRpe,
        lowRpe: lowRpe,
        barWeightKg: barWeightKg,
        minIncrementKg: minIncrementKg,
        dbIncrementKg: dbIncrementKg,
        forceAxis: axis,
      );
      if (adaptiveRamp != null) {
        options.add(adaptiveRamp);
      }
    }

    return options;
  }

  static AdaptiveAdjustmentOption? _buildAdaptiveOption({
    required AdaptiveAdjustmentKind kind,
    required double percent,
    required WorkoutItem item,
    required double? baseLoad,
    required int? baseReps,
    required int baseSets,
    required bool hitTarget,
    required bool highRpe,
    required bool lowRpe,
    required double barWeightKg,
    required double minIncrementKg,
    required double dbIncrementKg,
    AdaptiveAdjustmentAxis? forceAxis,
  }) {
    AdaptiveAdjustmentAxis? axis = forceAxis;
    if (axis != null && !_axisAvailable(axis, baseLoad, baseReps)) {
      return null;
    }

    axis ??= _selectAxis(
      kind: kind,
      baseLoad: baseLoad,
      baseReps: baseReps,
      baseSets: baseSets,
      hitTarget: hitTarget,
    );

    switch (axis) {
      case AdaptiveAdjustmentAxis.load:
        if (baseLoad == null || baseLoad <= 0) return null;
        final double sign = kind == AdaptiveAdjustmentKind.drop ? -1 : 1;
        final double raw = baseLoad * (1 + (percent * sign));
        final double? target = _roundForEquipment(
          raw,
          item,
          barWeightKg,
          minIncrementKg,
          dbIncrementKg,
        );
        if (target == null || (target - baseLoad).abs() < 0.01) {
          final double manual =
              baseLoad + sign * math.max(1.25, baseLoad * 0.01);
          final double? fallback = _roundForEquipment(
            manual,
            item,
            barWeightKg,
            minIncrementKg,
            dbIncrementKg,
          );
          if (fallback == null) return null;
          return AdaptiveAdjustmentOption(
            id: '${kind.name}-load',
            kind: kind,
            axis: axis,
            percent: percent,
            fromLoad: baseLoad,
            targetLoad: fallback,
            rationale: _adaptiveRationale(kind, hitTarget, highRpe, lowRpe),
          );
        }
        return AdaptiveAdjustmentOption(
          id: '${kind.name}-load',
          kind: kind,
          axis: axis,
          percent: percent,
          fromLoad: baseLoad,
          targetLoad: target,
          rationale: _adaptiveRationale(kind, hitTarget, highRpe, lowRpe),
        );
      case AdaptiveAdjustmentAxis.reps:
        final int start = math.max(1, baseReps ?? 1);
        final double signed = start *
            (kind == AdaptiveAdjustmentKind.drop
                ? (1 - percent)
                : (1 + percent));
        int targetReps = signed.round();
        if (targetReps == start) {
          targetReps = (start + (kind == AdaptiveAdjustmentKind.drop ? -1 : 1))
              .clamp(1, 300);
        } else {
          targetReps = targetReps.clamp(1, 300);
        }
        if (targetReps == start) return null;
        return AdaptiveAdjustmentOption(
          id: '${kind.name}-reps',
          kind: kind,
          axis: axis,
          percent: percent,
          fromReps: start,
          targetReps: targetReps,
          rationale: _adaptiveRationale(kind, hitTarget, highRpe, lowRpe),
        );
      case AdaptiveAdjustmentAxis.sets:
        final int delta = math.max(1, (baseSets * percent).round()).clamp(1, 6);
        final int next = kind == AdaptiveAdjustmentKind.drop
            ? math.max(1, baseSets - delta)
            : math.min(20, baseSets + delta);
        if (next == baseSets) return null;
        return AdaptiveAdjustmentOption(
          id: '${kind.name}-sets',
          kind: kind,
          axis: axis,
          percent: percent,
          fromSets: baseSets,
          targetSets: next,
          rationale: _adaptiveRationale(kind, hitTarget, highRpe, lowRpe),
        );
    }
  }

  static AdaptiveAdjustmentAxis _selectAxis({
    required AdaptiveAdjustmentKind kind,
    required double? baseLoad,
    required int? baseReps,
    required int baseSets,
    required bool hitTarget,
  }) {
    if (baseLoad != null && baseLoad > 0) {
      if (kind == AdaptiveAdjustmentKind.drop) {
        return AdaptiveAdjustmentAxis.load;
      }
      if (kind == AdaptiveAdjustmentKind.ramp && hitTarget) {
        return AdaptiveAdjustmentAxis.load;
      }
    }
    if (baseReps != null && baseReps > 0) {
      return AdaptiveAdjustmentAxis.reps;
    }
    return AdaptiveAdjustmentAxis.sets;
  }

  static bool _axisAvailable(
    AdaptiveAdjustmentAxis axis,
    double? baseLoad,
    int? baseReps,
  ) {
    switch (axis) {
      case AdaptiveAdjustmentAxis.load:
        return baseLoad != null && baseLoad > 0;
      case AdaptiveAdjustmentAxis.reps:
        return baseReps != null && baseReps > 0;
      case AdaptiveAdjustmentAxis.sets:
        return true;
    }
  }

  static double _clampPercent(double raw) {
    final double normalized = raw.abs();
    if (normalized < 0.02) return 0.02;
    if (normalized > 0.40) return 0.40;
    return normalized;
  }

  static String _adaptiveRationale(
    AdaptiveAdjustmentKind kind,
    bool hitTarget,
    bool highRpe,
    bool lowRpe,
  ) {
    if (kind == AdaptiveAdjustmentKind.drop) {
      if (!hitTarget) {
        return 'Missed the target — peel back to finish cleanly.';
      }
      if (highRpe) {
        return 'RPE spiked — lighten the load for better form.';
      }
      return 'Intentional drop set to accumulate fatigue safely.';
    } else {
      if (hitTarget && lowRpe) {
        return 'Room left in the tank — push the next set.';
      }
      if (hitTarget) {
        return 'On target — add a small progression.';
      }
      return 'Use a ramp to rebuild momentum.';
    }
  }
}
