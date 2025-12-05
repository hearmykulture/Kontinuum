import 'package:kontinuum/core/time/app_clock.dart';
// lib/core/time/day_id.dart

/// Compact local day-id in the form YYYYMMDD.
int ymd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Today's local day-id.
int todayYmdLocal() => ymd(AppClock.now());

/// Yesterday's local day-id.
int yesterdayYmdLocal() =>
    ymd(AppClock.now().subtract(const Duration(days: 1)));

/// Simple equality check for day-ids.
bool isSameYmd(int a, int b) => a == b;

/// Reconstruct a local DateTime from a YYYYMMDD day-id.
DateTime dateFromYmd(int id) {
  final year = id ~/ 10000;
  final month = (id % 10000) ~/ 100;
  final day = id % 100;
  return DateTime(year, month, day);
}

/// Returns true if [a] and [b] are on the same local calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Parse a flexible date-ish string into a YYYYMMDD day-id.
///
/// Accepts:
///   - "yyyyMMdd"
///   - "yyyy-MM-dd"
///   - any ISO-like string parseable by [DateTime.tryParse].
int? ymdFromString(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  // "yyyyMMdd"
  if (s.length == 8 && !s.contains('-') && !s.contains('/')) {
    final y = int.tryParse(s.substring(0, 4));
    final m = int.tryParse(s.substring(4, 6));
    final d = int.tryParse(s.substring(6, 8));
    if (y != null && m != null && d != null) {
      return y * 10000 + m * 100 + d;
    }
  }

  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  return ymd(DateTime(parsed.year, parsed.month, parsed.day));
}
