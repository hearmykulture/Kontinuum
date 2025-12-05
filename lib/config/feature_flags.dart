// lib/config/feature_flags.dart
import 'package:flutter/foundation.dart';

/// Feature flags / kill switches for in-development modules.
///
/// You can gate UI entry points (buttons, routes) behind these,
/// and even remote-config them in the future if you want.
class FeatureFlags {
  /// Workout module (Dashboard → Routine → Session → Summary).
  ///
  /// P0: keep this true while building so you can see the UI.
  /// In production you can choose to hide this if it's not ready.
  static const bool workoutModuleEnabled = true;

  /// Future: calorie / diet tracking module.
  static const bool calorieModuleEnabled = false;

  /// Debug helpers (like PO playground screens)
  static const bool debugPoPlayground = kDebugMode;
}
