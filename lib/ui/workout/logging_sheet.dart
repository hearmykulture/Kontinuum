// lib/ui/workout/logging_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:kontinuum/services/workout_boxes.dart';
import 'package:kontinuum/ui/theme/app_colors.dart';
import 'package:kontinuum/core/time/app_clock.dart';

/// Bottom sheet for daily workout log / check-in.
///
/// Saved into `WorkoutBoxes.logsBox` as a Map with:
///   kind:        'daily_log'
///   dateIso:     ISO date (Y-M-D) of the selected day
///   createdAtIso:ISO timestamp when the entry was written
///   note:        free-form notes
///   moodScore:   1–5
///   energyScore: 1–5
///   weight:      optional double
///
/// One-off rest overrides are stored via [WorkoutBoxes.upsertRestOverrideFor]
/// into `WorkoutBoxes.restOverridesBoxName` as:
///   kind:        'one_off_rest'
///   dateIso:     ISO Y-M-D for the day being skipped
///   createdAtIso:ISO timestamp when the override was written
///   source:      'logging_sheet' / 'dashboard' / etc.
class LoggingSheet extends StatefulWidget {
  const LoggingSheet({
    super.key,
    required this.date,
  });

  final DateTime date;

  @override
  State<LoggingSheet> createState() => _LoggingSheetState();
}

class _LoggingSheetState extends State<LoggingSheet> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  int _mood = 3; // 1–5
  int _energy = 3; // 1–5

  dynamic _existingKey; // Hive key if we’re editing an existing log.
  bool _loading = true;
  bool _hasRestOverride = false; // one-off "skip today" flag for this date

  @override
  void initState() {
    super.initState();
    _loadExistingForDay();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Storage helpers
  // ───────────────────────────────────────────────────────────────────────────

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _extractDate(Map<dynamic, dynamic> log) {
    final v = log['dateIso'] ?? log['date'] ?? log['dateYmd'];
    if (v is DateTime) {
      return DateTime(v.year, v.month, v.day);
    }
    if (v is String) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return null;

      // yyyyMMdd
      if (trimmed.length == 8 &&
          !trimmed.contains('-') &&
          !trimmed.contains('/')) {
        final y = int.tryParse(trimmed.substring(0, 4));
        final m = int.tryParse(trimmed.substring(4, 6));
        final d = int.tryParse(trimmed.substring(6, 8));
        if (y != null && m != null && d != null) {
          return DateTime(y, m, d);
        }
      }

      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return null;
  }

  Future<void> _loadExistingForDay() async {
    // Use the concrete box type here so .keys is known Iterable.
    final box = WorkoutBoxes.logsBox;
    final target =
        DateTime(widget.date.year, widget.date.month, widget.date.day);

    dynamic foundKey;
    Map<dynamic, dynamic>? foundValue;

    try {
      for (final key in box.keys) {
        final dynamic value = box.get(key);
        if (value is! Map) continue;

        final kind = value['kind'] ?? value['type'];
        if (kind != 'daily_log' && kind != 'daily_progress') continue;

        final d = _extractDate(value);
        if (d != null && _sameDay(d, target)) {
          foundKey = key;
          foundValue = value;
        }
      }
    } catch (_) {
      // ignore, just treat as "no existing"
    }

    if (foundValue != null) {
      final map = foundValue;
      final note = map['note'];
      if (note is String) {
        _notesController.text = note;
      }

      final weight = map['weight'];
      if (weight is num) {
        _weightController.text = weight.toString();
      }

      final mood = map['moodScore'];
      if (mood is num && mood >= 1 && mood <= 5) {
        _mood = mood.toInt();
      }

      final energy = map['energyScore'];
      if (energy is num && energy >= 1 && energy <= 5) {
        _energy = energy.toInt();
      }
    }

    // Check if this day is already marked as a one-off rest override.
    final hasOverride = WorkoutBoxes.hasRestOverrideFor(target);

    if (!mounted) return;
    setState(() {
      _existingKey = foundKey;
      _hasRestOverride = hasOverride;
      _loading = false;
    });
  }

  Future<void> _save() async {
    // Treat box as dynamic here so we can write Map payloads regardless of
    // the generic type it was originally opened with.
    final dynamic box = WorkoutBoxes.logsBox;
    final day = DateTime(widget.date.year, widget.date.month, widget.date.day);

    final note = _notesController.text.trim();
    final weightText = _weightController.text.trim();
    final double? weight =
        weightText.isEmpty ? null : double.tryParse(weightText);

    final Map<String, dynamic> payload = <String, dynamic>{
      'kind': 'daily_log',
      'dateIso': day.toIso8601String(),
      'createdAtIso': AppClock.now().toIso8601String(),
      'note': note,
      'moodScore': _mood,
      'energyScore': _energy,
      if (weight != null) 'weight': weight,
    };

    try {
      if (_existingKey != null) {
        await box.put(_existingKey, payload);
      } else {
        await box.add(payload);
      }
    } catch (_) {
      // If anything goes wrong, just fall through; we still pop.
    }

    if (!mounted) return;
    Navigator.of(context).pop(true); // signal "logged"
  }

  Future<void> _skipToday() async {
    final shortLabel = DateFormat('EEE, MMM d').format(widget.date);

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF11151D),
            title: const Text(
              'Skip workout for today?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              "This will mark $shortLabel as a one-off rest day. "
              "Your recurring schedule won’t be changed.",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentBlue,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Skip today'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await WorkoutBoxes.upsertRestOverrideFor(
      widget.date,
      source: 'logging_sheet',
    );

    if (!mounted) return;

    // Treat a successful skip as a "completed" action for the caller.
    Navigator.of(context).pop(true);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double bottomInset = media.viewInsets.bottom;
    final String dateLabel = DateFormat('EEE, MMM d, yyyy').format(widget.date);

    const sheetBg = Color(0xFF0B1017);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 560),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: sheetBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: _loading
                  ? const SizedBox(
                      height: 160,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // handle
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Header row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Daily log',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateLabel,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.65),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    if (_hasRestOverride) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.snooze_rounded,
                                            size: 14,
                                            color: AppColors.accentBlue
                                                .withValues(alpha: 0.9),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Marked as one-off rest day',
                                            style: TextStyle(
                                              color: AppColors.accentBlue
                                                  .withValues(alpha: 0.9),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: _skipToday,
                                    child: const Text('Skip today'),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: _save,
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Save'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.accentBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Mood row
                          _RatingRow(
                            label: 'Mood',
                            value: _mood,
                            onChanged: (v) =>
                                setState(() => _mood = v.clamp(1, 5)),
                          ),
                          const SizedBox(height: 12),

                          // Energy row
                          _RatingRow(
                            label: 'Energy',
                            value: _energy,
                            onChanged: (v) =>
                                setState(() => _energy = v.clamp(1, 5)),
                          ),

                          const SizedBox(height: 16),

                          // Weight
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Bodyweight (optional)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.80),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'e.g. 182.4',
                              suffix: 'lb',
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Notes
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Notes',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.80),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: TextField(
                              controller: _notesController,
                              maxLines: 4,
                              minLines: 3,
                              keyboardType: TextInputType.multiline,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                              decoration: _fieldDecoration(
                                hint:
                                    'How did training feel today? PRs, soreness, sleep, anything notable…',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint, String? suffix}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 13,
      ),
      suffixText: suffix,
      suffixStyle: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
      ),
      filled: true,
      fillColor: const Color(0xFF11151D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.accentBlue.withValues(alpha: 0.8),
          width: 1.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small 1–5 rating pill row
// ─────────────────────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.accentBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final int v = index + 1;
            final bool selected = v == value;

            return GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                width: 32,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: selected
                      ? accent.withValues(alpha: 0.22)
                      : const Color(0xFF151923),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '$v',
                  style: TextStyle(
                    color: selected
                        ? accent
                        : Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
