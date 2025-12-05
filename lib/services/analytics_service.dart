// lib/services/analytics_service.dart

import 'package:flutter/foundation.dart';

/// Super lightweight shim for analytics.
/// In production you can wire this to Firebase, PostHog, Segment, whatever.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// Log an event with optional payload.
  /// For now we just debugPrint so nothing crashes.
  void log(String eventName, [Map<String, Object?> params = const {}]) {
    // DO NOT throw. Silent/no-op in release if you want.
    debugPrint('[analytics] $eventName :: $params');
  }
}
