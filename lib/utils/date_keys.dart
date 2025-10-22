// lib/utils/date_keys.dart
library date_keys;

/// Canonical yyyy-MM-dd *local* date keys for storage & lookups.
/// Keep all time-of-day and timezone out of keys.
///
/// IMPORTANT:
/// - Writers should always use `DateKeys.ymd(d)`
/// - Readers may still keep HiveService._parseDayKey as a defensive fallback.
///
/// Rationale:
/// - Local midnights match what users see in the UI
/// - Avoids DST surprises by stripping time-of-day before keying
class DateKeys {
  /// yyyy-MM-dd in local time (e.g., 2025-03-09)
  static String ymd(DateTime d) {
    final local = d.isUtc ? d.toLocal() : d;
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Parse yyyy-MM-dd into a *local* DateTime at midnight.
  static DateTime fromYmd(String s) {
    final p = s.split('-');
    if (p.length != 3) {
      throw FormatException('Invalid yyyy-MM-dd: $s');
    }
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// Strip time-of-day in local time.
  static DateTime dateOnly(DateTime d) {
    final local = d.isUtc ? d.toLocal() : d;
    return DateTime(local.year, local.month, local.day);
  }

  /// True if same local calendar day.
  static bool sameDay(DateTime a, DateTime b) {
    final al = a.isUtc ? a.toLocal() : a;
    final bl = b.isUtc ? b.toLocal() : b;
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  /// Regex for quick sanity checks in debug logs.
  static final RegExp ymdRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Debug helper to assert keys are normalized.
  static void debugAssertYmdKey(String key) {
    assert(
      ymdRegex.hasMatch(key),
      'Non-normalized day key detected: "$key" (expected yyyy-MM-dd)',
    );
  }
}

/// Optional sugar so you can do: `date.toYmd` and `date.dateOnly()`.
extension DateKeysExt on DateTime {
  String get toYmd => DateKeys.ymd(this);
  DateTime get dateOnly => DateKeys.dateOnly(this);
}
