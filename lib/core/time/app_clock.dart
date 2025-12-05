import 'package:flutter/foundation.dart';

/// Centralized clock helper so we can time-travel in debug/test builds.
class AppClock {
  AppClock._();

  static Duration? _debugOffset;

  /// Returns the current app time (real time + optional debug offset).
  static DateTime now() {
    final base = DateTime.now();
    return _debugOffset == null ? base : base.add(_debugOffset!);
  }

  /// Force the clock to pretend it's [target] while still ticking forward.
  static void debugSetFixed(DateTime target) {
    assert(() {
      _debugOffset = target.difference(DateTime.now());
      return true;
    }());
  }

  /// Manually set a custom offset (debug only).
  static void debugSetOffset(Duration offset) {
    assert(() {
      _debugOffset = offset;
      return true;
    }());
  }

  /// Clear any overrides and use the real system clock again.
  static void reset() {
    assert(() {
      _debugOffset = null;
      return true;
    }());
  }

  static bool get isSimulated =>
      _debugOffset != null && kDebugMode; // only meaningful in debug.
}
