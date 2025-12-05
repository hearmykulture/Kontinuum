import 'dart:math' as math;

/// Basic rounding helpers for load targets.
///
/// NOTE: This is intentionally super minimal right now.
/// We'll flesh out barbell math + per-user prefs (bar weight, db increment)
/// in P1.
class PlateMath {
  /// Round a barbell target to nearest increment.
  ///
  /// Example: roundBarbell(72.3, barWeightKg:20, minIncrementKg:1.25)
  /// -> 72.5
  static double roundBarbell(
    double rawLoadKg, {
    double barWeightKg = 20.0,
    double minIncrementKg = 1.25,
  }) {
    if (rawLoadKg <= 0) return 0;
    final rounded = _roundToIncrement(rawLoadKg, minIncrementKg);
    // never return less than the bar itself if it's a barbell lift
    return math.max(rounded, barWeightKg);
  }

  /// Round dumbbells / machines to the nearest increment.
  /// For most commercial gyms in kg, 2.5 is common.
  static double roundToIncrement(
    double rawLoadKg, {
    double incrementKg = 2.5,
  }) {
    if (rawLoadKg <= 0) return 0;
    return _roundToIncrement(rawLoadKg, incrementKg);
  }

  static double _roundToIncrement(double value, double inc) {
    final steps = (value / inc).round();
    return steps * inc;
  }
}
