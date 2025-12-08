// lib/ui/workout/workout_dashboard_screen.dart
// Header: YearProgressBar + RoutineCarousel (owned by WorkoutDashboardWidget)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart'; // listenable() comes from hive_flutter

import 'package:kontinuum/core/analytics/analytics_events.dart';
import 'package:kontinuum/services/analytics_service.dart';

import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/models/session_state.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/services/workout_progress_service.dart';
import 'package:kontinuum/services/workout_boxes.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/services/exercise_library_service.dart';

import 'package:kontinuum/ui/workout/fitness_screening_flow.dart';
import 'package:kontinuum/ui/workout/fitness_profile_screen.dart';
import 'package:kontinuum/ui/theme/app_colors.dart';
import 'package:kontinuum/ui/workout/logging_sheet.dart';

// Create/Edit Workout screen (+ args)
import 'package:kontinuum/ui/workout/workout_editor_screen.dart'
    show WorkoutEditorArgs, WorkoutEditorScreen;

// Header widget (progress + routine carousel)
import 'package:kontinuum/ui/workout/workout_dashboard_widget.dart';

// Cross-nav to Diet + Progress
import 'package:kontinuum/ui/screens/diet/diet_dashboard_screen.dart';
import 'package:kontinuum/ui/screens/progress_screen.dart';

// Session + Timeline
import 'package:kontinuum/ui/workout/session_screen.dart' show SessionScreen;
import 'package:kontinuum/ui/workout/session_screen_args.dart';
import 'package:kontinuum/ui/workout/workout_timeline_screen.dart'
    show WorkoutTimelineScreen;

// Attach parts (private helpers, pills, footer, etc.)
part 'workout_dashboard_header_footer.dart';
part 'workout_dashboard_pills.dart';

class _WorkoutPalette {
  static const bg = Color(0xFF090A0E);
  static const accent = AppColors.accentBlue;
}

// Global toggle for dashboard debug logs.
const bool _kWorkoutDashboardDebugLogs = false;

void _wdLog(String message) {
  if (!_kWorkoutDashboardDebugLogs) return;
  debugPrint(message);
}

class WorkoutDashboardScreen extends StatefulWidget {
  const WorkoutDashboardScreen({super.key, this.onClose, this.dateSignal});

  final VoidCallback? onClose;
  final ValueNotifier<DateTime?>? dateSignal;

  @override
  State<WorkoutDashboardScreen> createState() => _WorkoutDashboardScreenState();
}

class _WorkoutDashboardScreenState extends State<WorkoutDashboardScreen> {
  DateTime _selectedDate = DateTime.now();
  ValueNotifier<DateTime?>? _dateSignal;

  // Initial date coming from navigation (e.g. Finished → /workout)
  bool _routeInitialDateApplied = false;
  bool _routeHadInitialDate = false;
  bool _syncedProgressSelectedDate = false;
  bool _hasExplicitInitialDate = false;

  // profile gate
  bool _profileCheckScheduled = false;
  bool _showingProfileSurvey = false;

  // initial calendar selection from logs
  bool _initialDateFromLogsApplied = false;

  // routine selection state (from carousel)
  String? _currentRoutineId; // last applied routine id
  String? _selectedRoutineId;

  // header-only dropdown state (for the WORKOUTS pill)
  bool _workoutsExpanded = true;

  // TODAY section dropdown state
  bool _todayExpanded = true;

  // Float the corner buttons upward
  static const double _cornerLift = -14.0;

  // Per-workout day selections (Mon..Sun)
  final Map<String, List<bool>> _dayPicks = <String, List<bool>>{};

  List<bool> _getPicks(String workoutId) {
    return _dayPicks.putIfAbsent(
      workoutId,
      () => List<bool>.filled(7, false),
    );
  }

  void _toggleDay(String workoutId, int dayIndex) {
    setState(() {
      final picks = _getPicks(workoutId);
      picks[dayIndex] = !picks[dayIndex];
    });
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance
        .log(WorkoutAnalyticsEvents.workoutDashboardOpened);
    _attachDateSignal();
  }

  @override
  void didUpdateWidget(covariant WorkoutDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateSignal != widget.dateSignal) {
      _detachDateSignal();
      _attachDateSignal();
    }
  }

  @override
  void dispose() {
    _detachDateSignal();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 1) Apply initial date from navigation arguments (if any) exactly once.
    //
    //    We expect things like:
    //    Navigator.pushNamed('/workout', arguments: DateTime(...));
    //
    //    If a route date is provided, we use that as the initial calendar date
    //    and DO NOT override it later with "latest completed log" logic.
    if (!_routeInitialDateApplied) {
      _routeInitialDateApplied = true;

      final Object? args = ModalRoute.of(context)?.settings.arguments;
      DateTime? routeDate;

      if (args is DateTime) {
        routeDate = DateTime(args.year, args.month, args.day);
      } else if (args is String) {
        final parsed = DateTime.tryParse(args);
        if (parsed != null) {
          routeDate = DateTime(parsed.year, parsed.month, parsed.day);
        }
      }

      if (routeDate != null) {
        _routeHadInitialDate = true;
        _hasExplicitInitialDate = true;
        if (!_sameDay(_selectedDate, routeDate)) {
          _wdLog(
            '[Dashboard] Applying initialDate from route args → '
            '${routeDate.toIso8601String()}',
          );
          setState(() {
            _selectedDate = routeDate!;
          });
        } else {
          _wdLog(
            '[Dashboard] Route initialDate matches current selectedDate → '
            '${routeDate.toIso8601String()}',
          );
        }
      } else {
        _wdLog('[Dashboard] No route initialDate provided.');
      }
    }

    _syncSelectedDateFromProgressIfNeeded();

    // 2) Profile gating
    if (!_profileCheckScheduled) {
      _profileCheckScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureProfile();
      });
    }

    // 3) After the very first frame on a fresh dashboard, try to snap
    //    the calendar to the most recent *completed* workout day,
    //    BUT ONLY if no explicit route date was provided.
    if (!_initialDateFromLogsApplied) {
      _initialDateFromLogsApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_routeHadInitialDate) {
          _wdLog(
            '[Dashboard] Skipping logs-based initial date because '
            'route provided an explicit initialDate.',
          );
          return;
        }
        if (_hasExplicitInitialDate) {
          _wdLog(
            '[Dashboard] Skipping logs-based initial date because '
            'an explicit initial date was already applied.',
          );
          return;
        }
        _applyLatestCompletedDayFromLogsIfAny();
      });
    }
  }

  Future<void> _ensureProfile() async {
    if (!mounted || _showingProfileSurvey) return;
    final fitness = context.read<FitnessProfileProvider>();
    if (fitness.hasProfile) return;

    final result = await _openScreening(force: true);
    if (!mounted) return;

    final updated = context.read<FitnessProfileProvider>();
    if (updated.hasProfile) return;

    if (result != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureProfile();
      });
    }
  }

  Future<bool?> _openScreening({bool force = false}) async {
    if (!mounted || _showingProfileSurvey) return null;
    _showingProfileSurvey = true;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => FitnessScreeningFlow(forceCompletion: force),
        settings:
            force ? const RouteSettings(name: 'fitness_screening_force') : null,
      ),
    );
    _showingProfileSurvey = false;
    return result;
  }

  void _maybeCloseOnSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v > 300) {
      // Prefer parent-provided close to trigger shared transitions.
      if (widget.onClose != null) {
        widget.onClose!.call();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DAY-SCOPED PROGRESS helpers
  // ───────────────────────────────────────────────────────────────────────────

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  ObjectiveProvider? _maybeObjectiveProvider() {
    try {
      return context.read<ObjectiveProvider>();
    } catch (_) {
      return null;
    }
  }

  void _syncSelectedDateFromProgressIfNeeded() {
    if (_syncedProgressSelectedDate || _routeHadInitialDate) return;

    final progressAncestor =
        context.findAncestorWidgetOfExactType<ProgressScreen>();
    if (progressAncestor == null) return;

    final objective = _maybeObjectiveProvider();
    if (objective == null) return;

    final DateTime progressSelected = objective.selectedDateNotifier.value;
    final DateTime normalized = DateTime(
      progressSelected.year,
      progressSelected.month,
      progressSelected.day,
    );

    _syncedProgressSelectedDate = true;
    _hasExplicitInitialDate = true;

    if (_sameDay(_selectedDate, normalized)) {
      _wdLog(
        '[Dashboard] ProgressScreen already on same selectedDate '
        '(${normalized.toIso8601String()})',
      );
      return;
    }

    _wdLog(
      '[Dashboard] Syncing selectedDate from ProgressScreen → '
      '${normalized.toIso8601String()}',
    );
    setState(() {
      _selectedDate = normalized;
    });
  }

  void _attachDateSignal() {
    _dateSignal = widget.dateSignal;
    _dateSignal?.addListener(_handleDateSignal);
    _handleDateSignal();
  }

  void _detachDateSignal() {
    _dateSignal?.removeListener(_handleDateSignal);
    _dateSignal = null;
  }

  void _handleDateSignal() {
    final sig = _dateSignal;
    if (sig == null) return;
    final DateTime? day = sig.value;
    if (day == null) return;
    final normalized = DateTime(day.year, day.month, day.day);
    setState(() {
      _selectedDate = normalized;
      _hasExplicitInitialDate = true;
      _routeHadInitialDate = true;
    });
    sig.value = null;
  }

  String _formatYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  /// Map/Object-safe: read a workoutId out of any log/session shape.
  /// IMPORTANT: we treat Maps first so we never call `.workoutId` on `_Map`.
  String? _readWorkoutId(dynamic x) {
    if (x == null) return null;

    // 1) Map-based payloads (Hive Map, JSON, etc.)
    if (x is Map) {
      for (final k in const [
        'workoutId',
        'currentWorkoutId',
        'wid',
        'workout_id',
        'id',
      ]) {
        final v = x[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    // 2) Typed objects (legacy Hive classes, etc.)
    try {
      final v = (x as dynamic).workoutId;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = (x as dynamic).currentWorkoutId;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = (x as dynamic).wid;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}

    return null;
  }

  /// Map/Object-safe: extract a timestamp representing the log date.
  /// We support:
  ///   - Map logs (new `_saveLog` shape + any legacy map)
  ///   - Typed `WorkoutLog` (legacy Hive objects)
  DateTime? _extractLogDate(dynamic log) {
    if (log == null) return null;

    // Helper to parse "yyyyMMdd" or ISO date strings
    DateTime? parseFlexible(String s) {
      final trimmed = s.trim();
      if (trimmed.isEmpty) return null;

      // "yyyyMMdd" (compact format used by finishSession)
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

      // "yyyy-MM-dd" or full ISO; DateTime will handle both
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }

      return null;
    }

    // 1) Map payloads (current log shape and any older maps)
    if (log is Map) {
      DateTime? tryStr(String k) {
        final v = log[k];
        if (v is String) return parseFlexible(v);
        if (v is DateTime) return v;
        return null;
      }

      DateTime? tryMs(String k) {
        final v = log[k];
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
        return null;
      }

      // Prefer explicit "scheduled" or "date" fields if present.
      for (final k in [
        'scheduledDateIso',
        'scheduledDate',
        'scheduledFor',
        'dateYmd',
        'date',
        'startedAt',
        'completedAt',
        'dateIso',
        'startedAtIso',
        'completedAtIso',
      ]) {
        final d = tryStr(k);
        if (d != null) return d;
      }

      for (final k in ['startedAtMs', 'completedAtMs', 'dateMs']) {
        final d = tryMs(k);
        if (d != null) return d;
      }

      return null;
    }

    // 2) Typed WorkoutLog objects (legacy entries)
    if (log is WorkoutLog) {
      final d = parseFlexible(log.dateYmd);
      if (d != null) return d;
      return null;
    }

    // 3) Anything else → we don't introspect to avoid NoSuchMethodError.
    return null;
  }

  /// Returns true if any log exists for [workoutId] on [date].
  /// Kept for possible future use, but no longer the primary driver
  /// for completion (we trust our own log/session blending for that).
  // ignore: unused_element
  bool _hasWorkoutActivityOnDate(String workoutId, DateTime date) {
    final ymd = DateTime(date.year, date.month, date.day);
    try {
      for (final log in WorkoutBoxes.logsBox.values) {
        final dynamic dyn = log; // <-- dynamic so Map/object-safe
        final logWid = _readWorkoutId(dyn);
        if (logWid != workoutId) continue;
        final d = _extractLogDate(dyn);
        if (d != null && _sameDay(d, ymd)) return true;
      }
    } catch (_) {}
    return false;
  }

  /// Robustly read a "completed" flag from either Map logs
  /// or typed WorkoutLog objects.
  bool _isCompletedLog(dynamic log) {
    if (log == null) return false;

    bool readValue(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase();
        return s == 'true' || s == 'yes' || s == 'y' || s == '1';
      }
      return false;
    }

    // Map-based logs (includes new `_saveLog` shape)
    if (log is Map) {
      // 1) Explicit boolean flags
      for (final k in ['isCompleted', 'completed', 'finished', 'done']) {
        final v = log[k];
        if (v != null && readValue(v)) return true;
      }

      // 2) New `WorkoutProvider._saveLog()` shape:
      //    if we have an exerciseCount or volume, this is a *finished* workout.
      final exCount = log['exerciseCount'];
      if (exCount is int && exCount > 0) return true;

      final vol = log['volume'] ?? log['totalVolume'];
      if (vol is num && vol > 0) return true;

      // 3) Fallback: treat logs with explicit total/done set counts.
      final totalRaw = log['totalSets'] ?? log['setCount'] ?? log['targetSets'];
      final doneRaw = log['completedSets'] ?? log['doneSets'];

      int? total;
      int? done;

      if (totalRaw is int && totalRaw > 0) {
        total = totalRaw;
      } else if (totalRaw is num && totalRaw > 0) {
        total = totalRaw.toInt();
      }

      if (doneRaw is int && doneRaw >= 0) {
        done = doneRaw;
      } else if (doneRaw is num && doneRaw >= 0) {
        done = doneRaw.toInt();
      }

      if (total != null && total > 0 && done != null && done >= total) {
        return true;
      }

      return false;
    }

    // Typed WorkoutLog objects
    if (log is WorkoutLog) {
      // Consider a WorkoutLog "completed" if it has any exercise logs with sets.
      if (log.exerciseLogs.isNotEmpty) {
        for (final exerciseLog in log.exerciseLogs) {
          if (exerciseLog.sets.isNotEmpty) {
            return true;
          }
        }
      }
      return false;
    }

    // Legacy/dynamic logs - try various completion flags via reflection.
    try {
      final v = (log as dynamic).isCompleted;
      if (readValue(v)) return true;
    } catch (_) {}

    try {
      final v = (log as dynamic).completed;
      if (readValue(v)) return true;
    } catch (_) {}

    try {
      final v = (log as dynamic).finished;
      if (readValue(v)) return true;
    } catch (_) {}

    try {
      final v = (log as dynamic).done;
      if (readValue(v)) return true;
    } catch (_) {}

    return false;
  }

  /// Returns a completion fraction [0, 1] for [workoutId] on [date] based on
  /// persisted logs in [WorkoutBoxes.logsBox].
  ///
  /// We take the *best* completion we can infer across all matching logs
  /// (in case there are multiple legacy shapes).
  ///
  /// IMPORTANT:
  /// This implementation **never** calls `.totalSets` / `.completedSets`
  /// on `WorkoutLog` directly, so we avoid NoSuchMethodError on older
  /// typed objects. All typed access is either via Map fields or guarded
  /// by `_isCompletedLog`.
  double _completionFromLogs(String workoutId, DateTime date) {
    final ymd = DateTime(date.year, date.month, date.day);
    double best = 0.0;

    _wdLog(
      '[Dashboard] _completionFromLogs checking → '
      'workoutId=$workoutId, '
      'targetDate=${ymd.toIso8601String()}, '
      'totalLogsInBox=${WorkoutBoxes.logsBox.values.length}',
    );

    try {
      for (final raw in WorkoutBoxes.logsBox.values) {
        final dynamic dyn = raw;

        // Match workout
        final logWorkoutId = _readWorkoutId(dyn);
        _wdLog(
          '[Dashboard]   checking log: '
          'logWorkoutId=$logWorkoutId, '
          'targetWorkoutId=$workoutId, '
          'match=${logWorkoutId == workoutId}',
        );
        if (logWorkoutId != workoutId) continue;

        // Match date
        final d = _extractLogDate(dyn);
        final dateMatch = d != null && _sameDay(d, ymd);
        _wdLog(
          '[Dashboard]   date check: '
          'logDate=${d?.toIso8601String()}, '
          'targetDate=${ymd.toIso8601String()}, '
          'match=$dateMatch',
        );
        if (d == null || !_sameDay(d, ymd)) continue;

        double c = 0.0;

        // If this log is clearly "completed" (boolean flags, exerciseCount>0,
        // volume>0, or sets fully done) → treat as 100%.
        final isCompleted = _isCompletedLog(dyn);
        _wdLog(
          '[Dashboard]   isCompleted=$isCompleted, '
          'exerciseLogsCount=${(dyn is WorkoutLog) ? dyn.exerciseLogs.length : "unknown"}',
        );
        if (isCompleted) {
          c = 1.0;
        } else if (dyn is Map) {
          int? total;
          int? done;

          final totalRaw =
              dyn['totalSets'] ?? dyn['setCount'] ?? dyn['targetSets'];
          final doneRaw = dyn['completedSets'] ?? dyn['doneSets'];

          if (totalRaw is int && totalRaw > 0) {
            total = totalRaw;
          } else if (totalRaw is num && totalRaw > 0) {
            total = totalRaw.toInt();
          }

          if (doneRaw is int && doneRaw >= 0) {
            done = doneRaw;
          } else if (doneRaw is num && doneRaw >= 0) {
            done = doneRaw.toInt();
          }

          // New Map log shape: exerciseCount / volume → treat as complete.
          if (c == 0.0) {
            final exCount = dyn['exerciseCount'];
            final vol = dyn['volume'] ?? dyn['totalVolume'];
            if ((exCount is int && exCount > 0) || (vol is num && vol > 0)) {
              c = 1.0;
            }
          }

          // If we have partial set counts, derive a ratio.
          if (c == 0.0 &&
              total != null &&
              total > 0 &&
              done != null &&
              done >= 0) {
            c = (done / total).clamp(0.0, 1.0);
          }
        } else if (dyn is WorkoutLog) {
          // Legacy typed WorkoutLog without explicit totals:
          // treat "any sets logged" as at least some progress (0.5),
          // but let _isCompletedLog continue to be the main driver.
          int totalSets = 0;
          for (final exLog in dyn.exerciseLogs) {
            totalSets += exLog.sets.length;
          }
          if (totalSets > 0) {
            c = 0.5; // "in progress" but not obviously finished.
          }
        }

        if (c > best) {
          best = c;
          _wdLog('[Dashboard]   new best completion: $best');
          if (best >= 1.0) break;
        }
      }
    } catch (e) {
      // any weirdness → just keep current best
      _wdLog('[Dashboard] _completionFromLogs error: $e');
    }

    _wdLog('[Dashboard] _completionFromLogs result → best=$best');
    return best.clamp(0.0, 1.0);
  }

  /// Returns true if there is a *completed* log for this workout
  /// on the given calendar date.
  bool _hasCompletedWorkoutOnDate(String workoutId, DateTime date) {
    return _completionFromLogs(workoutId, date) >= 0.999;
  }

  /// True if ANY completed log exists on this calendar date.
  bool _hasAnyCompletedLogOnDate(DateTime date) {
    final DateTime ymd = DateTime(date.year, date.month, date.day);
    try {
      for (final raw in WorkoutBoxes.logsBox.values) {
        final dynamic dyn = raw;
        if (!_isCompletedLog(dyn)) continue;
        final DateTime? d = _extractLogDate(dyn);
        if (d != null && _sameDay(d, ymd)) {
          return true;
        }
      }
    } catch (e) {
      _wdLog('[Dashboard] _hasAnyCompletedLogOnDate error: $e');
    }
    return false;
  }

  /// Helper: after a session returns, find the last *completed* log for
  /// this workout and return its calendar date (year / month / day).
  DateTime? _lastCompletedDateForWorkoutFromLogs(String workoutId) {
    DateTime? lastDate;
    try {
      for (final log in WorkoutBoxes.logsBox.values) {
        final dynamic dyn = log;
        final String? wid = _readWorkoutId(dyn);
        if (wid != workoutId) continue;
        if (!_isCompletedLog(dyn)) continue;

        final DateTime? d = _extractLogDate(dyn);
        if (d == null) continue;

        // Because Hive boxes preserve insertion order for add(),
        // the final matching entry we see will be the most recently
        // written log for this workout.
        lastDate = DateTime(d.year, d.month, d.day);
      }
    } catch (e) {
      _wdLog(
        '[Dashboard] _lastCompletedDateForWorkoutFromLogs error: $e',
      );
    }
    return lastDate;
  }

  /// Helper: scan *all* logs and return the most recent completed day,
  /// regardless of which workout it belongs to.
  DateTime? _lastCompletedDateFromAllLogs() {
    DateTime? latest;
    try {
      for (final log in WorkoutBoxes.logsBox.values) {
        final dynamic dyn = log;
        if (!_isCompletedLog(dyn)) continue;

        final DateTime? d = _extractLogDate(dyn);
        if (d == null) continue;

        final DateTime day = DateTime(d.year, d.month, d.day);
        if (latest == null || day.isAfter(latest)) {
          latest = day;
        }
      }
    } catch (e) {
      _wdLog('[Dashboard] _lastCompletedDateFromAllLogs error: $e');
    }
    _wdLog(
      '[Dashboard] _lastCompletedDateFromAllLogs → ${latest?.toIso8601String() ?? "null"}',
    );
    return latest;
  }

  /// Count how many *completed* logs exist for a workout across all time.
  int _countTimesCompleted(String workoutId) {
    int count = 0;
    try {
      for (final log in WorkoutBoxes.logsBox.values) {
        final dynamic dyn = log; // <-- dynamic here too
        if (_readWorkoutId(dyn) != workoutId) continue;
        if (_isCompletedLog(dyn)) count++;
      }
    } catch (_) {}
    return count;
  }

  /// Read in-flight (uncommitted) session progress for a given date via
  /// SessionPersistenceService (typed, Map-safe).
  ///
  /// Note: we *do not* require `state.isValid` here; as long as the session
  /// belongs to this workout + date, we’ll surface its completion fraction.
  double _inFlightCompletion(String workoutId, Workout workout, DateTime date) {
    try {
      // Prefer the session bound to this exact workout+date.
      final String ymd = _formatYmd(date);
      WorkoutSessionState? state = SessionPersistenceService.getSessionFor(
        workoutId: workoutId,
        scheduledDateYmd: ymd,
      );

      // Fallback to the generic "current" session if nothing keyed was found.
      state ??= SessionPersistenceService.getCurrentSession();
      if (state == null) return 0.0;
      if (state.workoutId != workoutId) return 0.0;

      // Require the session's day to match the requested date.
      final String? dateToCompare = state.scheduledDateIso ?? state.savedAtIso;
      if (dateToCompare == null || dateToCompare.isEmpty) return 0.0;
      final sessionDate = DateTime.tryParse(dateToCompare);
      if (sessionDate == null || !_sameDay(sessionDate, date)) return 0.0;

      // Use totalCompletedSets so we capture progress across all exercises,
      // not just the currently-selected one.
      final int doneSets = state.totalCompletedSets;
      if (doneSets <= 0) return 0.0;

      final int totalSets = _estimateTotalSetsForWorkout(workout);
      if (totalSets <= 0) return 0.0;

      return (doneSets / totalSets).clamp(0.0, 1.0);
    } catch (_) {
      // If anything goes odd, just treat as "no in-flight progress"
      return 0.0;
    }
  }

  /// Very defensive helper: estimate how many sets a workout *probably* has.
  /// Uses dynamic access and try/catch so we never crash on weird shapes.
  int _estimateTotalSetsForWorkout(Workout workout) {
    int totalSets = 0;
    final dynamic dynWorkout = workout;

    // 1) Try to read blocks list from the workout (typed or dynamic).
    List<dynamic> blocks = const [];
    try {
      final b = dynWorkout.blocks;
      if (b is List) {
        blocks = List<dynamic>.from(b);
      }
    } catch (_) {}

    // If we have blocks, inspect each block for "sets".
    if (blocks.isNotEmpty) {
      for (final blk in blocks) {
        int blockSets = 0;

        // Handle typed WorkoutBlock first
        if (blk is WorkoutBlock) {
          // Sum up targetSets from all items in the block
          for (final item in blk.items) {
            blockSets += item.targetSets;
          }
        } else {
          // Fall back to dynamic handling for other types
          final dynamic b = blk;

          // a) Explicit integer counts on the block itself.
          if (b is Map) {
            try {
              final direct = b['setCount'] ?? b['setsCount'] ?? b['targetSets'];
              if (direct is int && direct > 0) {
                blockSets = direct;
              }
            } catch (_) {}

            // b) If the block has a 'sets' list, use its length.
            if (blockSets == 0) {
              try {
                final sList = b['sets'];
                if (sList is List) {
                  blockSets = sList.length;
                }
              } catch (_) {}
            }
          }

          // c) Otherwise, inspect an inner list of "exercises/items/movements"
          //    and count sets on each item.
          if (blockSets == 0) {
            List<dynamic> items = const [];

            // Map-style access for dynamic blocks.
            if (b is Map) {
              final e = b['exercises'] ??
                  b['items'] ??
                  b['exerciseItems'] ??
                  b['movements'];
              if (e is List) items = List<dynamic>.from(e);
            }

            if (items.isNotEmpty) {
              for (final itm in items) {
                int exSets = 0;

                // Handle typed WorkoutItem
                if (itm is WorkoutItem) {
                  exSets = itm.targetSets;
                } else if (itm is Map) {
                  final s = itm['sets'] ?? itm['targetSets'];
                  if (s is int && s > 0) {
                    exSets = s;
                  } else if (s is List && s.isNotEmpty) {
                    exSets = s.length;
                  }
                }

                // If we still have no idea, count that item as a single set.
                blockSets += exSets == 0 ? 1 : exSets;
              }
            }
          }
        }

        // d) As an absolute last resort, assume the block represents at least one set.
        if (blockSets == 0) {
          blockSets = 1;
        }

        totalSets += blockSets;
      }

      return totalSets;
    }

    // 2) No blocks list — fallback: explicit workout.totalSets if present.
    try {
      final ts = dynWorkout.totalSets;
      if (ts is int && ts > 0) return ts;
    } catch (_) {}

    // 3) Legacy shape: workout.exercises top-level.
    try {
      final exList = dynWorkout.exercises;
      if (exList is List) {
        for (final e in exList) {
          final dynamic ex = e;
          int exSets = 0;

          // sets: can be int or List
          try {
            final s = (ex as dynamic).sets;
            if (s is int && s > 0) exSets = s;
            if (s is List && s.isNotEmpty) exSets = s.length;
          } catch (_) {}

          if (ex is Map && exSets == 0) {
            final s = ex['sets'] ?? ex['targetSets'];
            if (s is int && s > 0) exSets = s;
            if (s is List && s.isNotEmpty) exSets = s.length;
          }

          if (exSets == 0) {
            try {
              final t = (ex as dynamic).targetSets;
              if (t is int && t > 0) exSets = t;
            } catch (_) {}
          }

          if (exSets == 0) exSets = 1;
          totalSets += exSets;
        }
        if (totalSets > 0) return totalSets;
      }
    } catch (_) {}

    // If we truly can't infer anything, say "0" so we just hide in-flight progress.
    return 0;
  }

  /// Primary completion helper: first look at persisted logs for that
  /// workout+date, then blend in any in-flight session progress, and clamp.
  double _completionForWorkoutOnDate(
      String workoutId, Workout workout, DateTime date) {
    // Use the centralized progress service so the denominator (target sets)
    // matches what the calendar ring uses.
    final snapshot = WorkoutProgressService.instance.snapshotForDay(
      workout: workout,
      scheduledDate: date,
    );
    return snapshot.percent.clamp(0.0, 1.0);
  }

  /// Routine-level progress for the calendar/YearProgress header.
  /// Returns a value in [0, 1] representing how "complete" the day is
  /// for the currently resolved routine.
  ///
  /// Rest days are treated as fully complete (light-blue ring). Days with
  /// no prescribed workouts return 0 so that new routines without schedules
  /// don't look fully complete.
  double _routineProgressForDay(DateTime date) {
    try {
      final wp = context.read<WorkoutProvider>();
      final fp = context.read<FitnessProfileProvider>();

      final Routine? routine = _resolveSelectedRoutine(wp, fp.profile);
      if (routine == null) return 0.0;

      final DateTime day = DateTime(date.year, date.month, date.day);
      final bool hasAnyWorkoutsInRoutine = routine.workoutIds.isNotEmpty;

      // If this calendar day is flagged as a REST day for the routine
      // (including one-off overrides), treat it as fully complete.
      final bool isRestDay =
          hasAnyWorkoutsInRoutine && wp.isRestDay(routine.id, day);
      if (isRestDay) {
        return 1.0;
      }

      // Ask the progress service which workouts are *prescribed*
      // for this routine on the given date.
      final prescribedIds = WorkoutProgressService.getPrescribedWorkouts(
        routineId: routine.id,
        date: day,
      );

      // Nothing scheduled (and not a rest day handled above) → no progress.
      // This avoids auto-completing every day when a routine has workouts but
      // no per-workout schedule has been set yet.
      if (prescribedIds.isEmpty) {
        return 0.0;
      }

      // Otherwise, compute completion weighted by target sets across all
      // prescribed workouts. This ensures partial sessions contribute
      // proportionally (e.g., leaving early counts as partial progress).
      int totalTargetSets = 0;
      int totalCompletedSets = 0;
      double fallbackPercentSum = 0.0; // for workouts without set metadata
      int fallbackCount = 0;

      for (final wid in prescribedIds) {
        final w = wp.getWorkoutById(wid);
        if (w == null) continue;

        final snapshot = WorkoutProgressService.instance.snapshotForDay(
          workout: w,
          scheduledDate: day,
        );

        if (snapshot.totalSets > 0) {
          totalTargetSets += snapshot.totalSets;
          totalCompletedSets += snapshot.completedSets.clamp(
            0,
            snapshot.totalSets,
          );
        } else {
          fallbackPercentSum += snapshot.percent.clamp(0.0, 1.0);
          fallbackCount++;
        }
      }

      double percent;
      if (totalTargetSets > 0) {
        percent = totalCompletedSets / totalTargetSets;

        // Blend in any workouts without set counts as equal-weight entries
        // using their percent to avoid dropping them entirely.
        if (fallbackCount > 0) {
          final double fallbackAvg = fallbackPercentSum / fallbackCount;
          percent = ((percent * totalTargetSets) +
                  (fallbackAvg * fallbackCount)) /
              (totalTargetSets + fallbackCount);
        }
      } else if (fallbackCount > 0) {
        percent = fallbackPercentSum / fallbackCount;
      } else {
        percent = 0.0;
      }

      return percent.clamp(0.0, 1.0);
    } catch (_) {
      // Any weirdness: just report "no progress" rather than crash.
      return 0.0;
    }
  }

  /// On a fresh dashboard (e.g. after finishing a workout and navigating
  /// back via a new route), center the calendar on the most recent
  /// completed workout day — but ONLY when no explicit initial date
  /// was passed via navigation.
  void _applyLatestCompletedDayFromLogsIfAny() {
    final DateTime? latest = _lastCompletedDateFromAllLogs();
    if (latest == null) {
      _wdLog('[Dashboard] No completed logs found for initial date.');
      return;
    }

    // If we're already on that day, nothing to do.
    if (_sameDay(_selectedDate, latest)) {
      _wdLog(
        '[Dashboard] Selected date already matches latest completed day → ${latest.toIso8601String()}',
      );
      return;
    }

    _wdLog(
      '[Dashboard] Applying latest completed day from logs → ${latest.toIso8601String()}',
    );
    setState(() {
      _selectedDate = latest;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Small helpers for WORKOUTS stat chips
  // ───────────────────────────────────────────────────────────────────────────

  String? _deriveFocusLabel(Workout workout) {
    // Derive focus label from the most common exercise intent in the workout
    try {
      final intentCounts = <ExerciseIntent, int>{};

      for (final block in workout.blocks) {
        for (final item in block.items) {
          final exercise =
              ExerciseLibraryService.instance.getById(item.exerciseId);
          if (exercise != null) {
            intentCounts[exercise.intent] =
                (intentCounts[exercise.intent] ?? 0) + 1;
          }
        }
      }

      if (intentCounts.isEmpty) return null;

      // Find the most common intent
      var maxCount = 0;
      ExerciseIntent? primaryIntent;

      intentCounts.forEach((intent, count) {
        if (count > maxCount) {
          maxCount = count;
          primaryIntent = intent;
        }
      });

      if (primaryIntent == null) return null;

      // Convert intent to human-readable label
      final s = primaryIntent.toString();
      final idx = s.indexOf('.');
      final clean = idx == -1 ? s : s.substring(idx + 1);
      if (clean.isNotEmpty) {
        return clean[0].toUpperCase() + clean.substring(1);
      }
    } catch (_) {
      // If anything goes wrong, return null
    }

    return null;
  }

  int? _deriveTargetMinutes(Workout workout) {
    // Calculate estimated duration based on workout structure
    int totalSeconds = 0;

    for (final block in workout.blocks) {
      for (final item in block.items) {
        // If item has targetTimeSec, use that
        if (item.targetTimeSec != null && item.targetTimeSec! > 0) {
          totalSeconds += item.targetTimeSec! * item.targetSets;
        } else {
          // Otherwise estimate: assume ~3 seconds per rep + rest time
          final reps = item.targetReps ?? 10;
          final timePerSet = (reps * 3);
          final restPerSet = item.restSec ?? 60;
          totalSeconds += (timePerSet + restPerSet) * item.targetSets;
        }
      }

      // Add some buffer time between blocks (~30 seconds)
      if (block.items.isNotEmpty) {
        totalSeconds += 30;
      }
    }

    if (totalSeconds > 0) {
      return (totalSeconds / 60).ceil();
    }

    return null;
  }

  int? _deriveBlockCount(Workout workout) {
    return workout.blocks.length;
  }

  List<bool>? _weeklyRestDaysForRoutine(Routine routine) {
    if (routine.scheduleMode != RepetitionMode.weekly) return null;
    final rest = routine.restSchedule;
    if (rest == null) return null;
    if (rest.mode != RepetitionMode.weekly) return null;
    final days = List<bool>.filled(7, false);
    for (int i = 0; i < 7; i++) {
      days[i] = i < rest.weeklyDays.length ? rest.weeklyDays[i] : false;
    }
    return days;
  }

  String? _intervalSummaryForRest(RestSchedule? rest) {
    if (rest == null) return null;
    if (rest.mode != RepetitionMode.interval) return null;
    final int value = rest.intervalValue <= 0 ? 1 : rest.intervalValue;
    String unitLabel;
    switch (rest.intervalUnit) {
      case RepetitionUnit.days:
        unitLabel = 'day';
        break;
      case RepetitionUnit.weeks:
        unitLabel = 'week';
        break;
      case RepetitionUnit.months:
        unitLabel = 'month';
        break;
      case RepetitionUnit.years:
        unitLabel = 'year';
        break;
    }
    final suffix = value == 1 ? '' : 's';
    return 'Rest every $value $unitLabel$suffix';
  }

  int? _deriveExerciseCount(Workout workout) {
    int total = 0;

    for (final block in workout.blocks) {
      total += block.items.length;
    }

    return total > 0 ? total : null;
  }

  void _openProfileOrScreening() {
    final fitness = context.read<FitnessProfileProvider>();
    if (fitness.hasProfile) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const FitnessProfileScreen(),
        ),
      );
    } else {
      _openScreening();
    }
  }

  void _goToDiet() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DietDashboardScreen(),
        settings: const RouteSettings(name: 'diet_dashboard_from_workout'),
      ),
    );
  }

  void _goToProgress() {
    // Prefer parent-provided close so we reuse the host transition (e.g. Progress → Workout).
    if (widget.onClose != null) {
      widget.onClose!.call();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ProgressScreen(),
        settings: const RouteSettings(name: 'progress_from_workout_close'),
      ),
    );
  }

  void _openLoggingSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LoggingSheet(date: _selectedDate),
    );
  }

  // carousel selection callback
  void _onRoutineSelected(String routineId) {
    if (_selectedRoutineId == routineId) return;
    setState(() => _selectedRoutineId = routineId);
  }

  // resolve selected routine (carousel > profile > first)
  Routine? _resolveSelectedRoutine(
      WorkoutProvider wp, FitnessNutritionProfile? profile) {
    if (_selectedRoutineId != null) {
      final idx = wp.routines.indexWhere((e) => e.id == _selectedRoutineId);
      if (idx != -1) return wp.routines[idx];
    }
    final profileId = profile?.currentRoutineId;
    if (profileId != null) {
      final idx = wp.routines.indexWhere((e) => e.id == profileId);
      if (idx != -1) return wp.routines[idx];
    }
    return wp.routines.isNotEmpty ? wp.routines.first : null;
  }

  // create workout in selected routine (footer "New" button)
  Future<void> _openCreateWorkoutInSelected() async {
    final wp = context.read<WorkoutProvider>();
    final fp = context.read<FitnessProfileProvider>();

    final Routine? routine = _resolveSelectedRoutine(wp, fp.profile);
    if (routine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a routine first')),
      );
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const WorkoutEditorScreen(),
        settings: RouteSettings(
          name: 'create_workout',
          arguments: WorkoutEditorArgs(attachToRoutineId: routine.id),
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _workoutsExpanded = false;
    });
  }

  // create workout for a specific routine (inline "New workout" pill)
  Future<void> _openCreateWorkoutInRoutine(Routine routine) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const WorkoutEditorScreen(),
        settings: RouteSettings(
          name: 'create_workout_from_list',
          arguments: WorkoutEditorArgs(attachToRoutineId: routine.id),
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _workoutsExpanded = false);
  }

  // open existing workout from inline pill (Edit)
  Future<void> _openEditWorkout(String workoutId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const WorkoutEditorScreen(),
        settings: RouteSettings(
          name: 'edit_workout_from_list',
          arguments: WorkoutEditorArgs(workoutId: workoutId),
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _workoutsExpanded = false);
  }

  // Start -> Session screen
  void _showSessionStartError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _startWorkout(String workoutId, {String? routineId}) async {
    final wp = context.read<WorkoutProvider>();

    // Snapshot the date that was selected when the user tapped "Start".
    // If we can't infer a log date later, we fall back to this.
    final DateTime startedOnDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    if (routineId == null || routineId.isEmpty) {
      _wdLog('[WorkoutDashboard] ⚠️ Cannot start session without routineId');
      _showSessionStartError('Select a routine before starting a workout.');
      return;
    }

    // ── REST-DAY GATE ────────────────────────────────────────────────────────
    final bool isRestDay = wp.isRestDay(routineId, startedOnDate);

    if (isRestDay) {
      _wdLog(
        '[WorkoutDashboard] _startWorkout blocked on rest day → '
        'workoutId=$workoutId, routineId=$routineId, '
        'date=${startedOnDate.toIso8601String()}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Today is marked as a rest day for this routine.'),
          duration: Duration(seconds: 3),
        ),
      );

      AnalyticsService.instance.log(
        'workout_session_blocked_rest_day',
        {
          'routineId': routineId,
          'workoutId': workoutId,
          'dateYmd': _formatYmd(startedOnDate),
        },
      );
      return;
    }

    final bool hasActiveSession = wp.activeDraft?.workoutId == workoutId;
    if (!hasActiveSession) {
      final result = wp.startSession(
        routineId: routineId,
        workoutId: workoutId,
        source: 'dashboard',
        calendarDayOverride: startedOnDate,
      );
      if (!result.started) {
        _showSessionStartError(result.message ?? 'Unable to start session.');
        return;
      }
      _wdLog(
        '[WorkoutDashboard] Started session → '
        'workoutId=$workoutId, routineId=$routineId, '
        'scheduledDate=${startedOnDate.toIso8601String()}',
      );
    } else {
      _wdLog(
        '[WorkoutDashboard] Resuming active session → '
        'workoutId=$workoutId, routineId=$routineId',
      );
    }

    final sessionArgs = SessionScreenArgs(
      workoutId: workoutId,
      attachToRoutineId: routineId,
      scheduledDate: startedOnDate,
    );

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SessionScreen(args: sessionArgs),
        settings: const RouteSettings(
          name: 'session_from_dashboard',
        ),
      ),
    );

    if (!mounted) return;

    // Tiny delay to ensure any logs/session writes have flushed.
    await Future<void>.delayed(const Duration(milliseconds: 1));

    // After returning from the session (and any summary/finish screens),
    // prefer the *log date* for this workout if we can detect a completed log.
    final DateTime? lastCompletedForWorkout =
        _lastCompletedDateForWorkoutFromLogs(workoutId);

    // If we can't find a completed log for this workout, fall back to either
    // "latest completed log for any workout" or the date the user tapped Start.
    final DateTime? latestAny = _lastCompletedDateFromAllLogs();
    final DateTime effective =
        lastCompletedForWorkout ?? latestAny ?? startedOnDate;

    if (!mounted) return;

    _wdLog(
      '[WorkoutDashboard] After session, snapping calendar to '
      '${effective.toIso8601String()} '
      '(lastCompletedForWorkout=${lastCompletedForWorkout?.toIso8601String() ?? "null"}, '
      'startedOnDate=${startedOnDate.toIso8601String()}, '
      'latestAny=${latestAny?.toIso8601String() ?? "null"})',
    );

    setState(() {
      _selectedDate = effective;
    });
    // The WorkoutYearProgressBar listens for selectedDate changes and
    // will auto-scroll to center this date.
  }

  // Info -> Timeline
  void _openTimelineFor(Workout w) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutTimelineScreen(workout: w),
      ),
    );
  }

  // Non-destructive swipe confirm for now (no provider method wired yet)
  Future<bool> _confirmRemoveFromRoutine(BuildContext ctx, String title) async {
    final bool? ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Remove workout?'),
        content: Text('"$title" will be removed from this routine.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('OK')),
        ],
      ),
    );
    return ok == true ? false : false;
  }

  // Build Today section content with prescribed workouts + log progress pill
  //
  // NEW:
  //  - If the routine has workouts but none are prescribed for the selected
  //    date, we treat the day as a scheduled REST day:
  //      • Treat the day as "complete" at the routine level
  //      • Hide workout cards entirely
  //      • Show a supportive rest-day card instead
  Widget _buildTodayContent(Routine? routine) {
    final bool logDone = _hasAnyCompletedLogOnDate(_selectedDate);
    final children = <Widget>[];

    if (routine == null) {
      children.add(
        _buildEmptyState('Create a routine to see today\'s workouts'),
      );
    } else {
      _wdLog(
        '[Dashboard] _buildTodayContent → '
        '_selectedDate=${_selectedDate.toIso8601String()}, '
        'routineId=${routine.id}',
      );

      final wp = context.read<WorkoutProvider>();
      final DateTime day = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      final bool isRestDay = wp.isRestDay(routine.id, day);

      if (isRestDay) {
        // Scheduled or override rest: no workout cards, just supportive messaging.
        children.add(_buildRestDayCard(routine));
      } else {
        // Training day: show only the prescribed workouts for this date.
        final prescribedWorkoutIds =
            WorkoutProgressService.getPrescribedWorkouts(
          routineId: routine.id,
          date: day,
        );
        final Iterable<String> idsToShow = prescribedWorkoutIds;

        if (idsToShow.isEmpty) {
          children.add(
            _buildEmptyState('No workouts scheduled for this date'),
          );
        } else {
          for (final workoutId in idsToShow) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Builder(
                  builder: (context) {
                    final workout = wp.getWorkoutById(workoutId);
                    if (workout == null) {
                      return const SizedBox.shrink();
                    }

                    final completion = _completionForWorkoutOnDate(
                      workoutId,
                      workout,
                      day,
                    );
                    final completionPercent = (completion * 100).round();

                    _wdLog(
                      '[Dashboard] Workout completion → '
                      'workoutId=$workoutId, '
                      'date=${day.toIso8601String()}, '
                      'completion=$completion, '
                      'percent=$completionPercent%',
                    );

                    final t = workout.title.trim();
                    final title = t.isEmpty ? 'Untitled workout' : t;

                    return _TodayWorkoutPill(
                      label: title,
                      completionPercent: completionPercent,
                      onStart: () =>
                          _startWorkout(workoutId, routineId: routine.id),
                      onInfo: () => _openTimelineFor(workout),
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    }

    // Always show the log-progress pill under whatever content we had.
    // Even on rest days, we want people to be able to log mood/notes.
    children.add(
      Padding(
        padding: EdgeInsets.only(top: children.isEmpty ? 0 : 6),
        child: _TodayLogProgressPill(
          isDone: logDone,
          onTap: _openLoggingSheet,
        ),
      ),
    );

    return Column(
      children: children,
    );
  }

  /// Rest-day card that replaces workout cards when the current date is
  /// a scheduled rest day for the active routine.
  Widget _buildRestDayCard(Routine routine) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.accentBlue.withValues(alpha: 0.18),
            const Color(0xFF050910),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.accentBlue.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bedtime,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scheduled rest day',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your plan has you off the floor today so you can recover and come back stronger.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildRestSuggestionChip('Light walk or stretch'),
                    _buildRestSuggestionChip('Log mood or energy'),
                    _buildRestSuggestionChip('Preview upcoming workouts'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestSuggestionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2A).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild this screen whenever session box or logs change.
    //
    // IMPORTANT:
    // The 'workout_session_state' box is opened as Box<dynamic> by
    // SessionPersistenceService.init(), so we must ALSO read it as
    // Box<dynamic> here to avoid Hive type mismatches.
    final Box<dynamic> sessionBox = Hive.box<dynamic>('workout_session_state');
    final sessionListenable = sessionBox.listenable(); // hive_flutter

    final logsListenable = WorkoutBoxes.logsBox.listenable();

    return ValueListenableBuilder(
      valueListenable: sessionListenable,
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: logsListenable,
          builder: (context, __, ___) {
            final wp = context.watch<WorkoutProvider>();
            final fp = context.watch<FitnessProfileProvider>();

            final Routine? routine = _resolveSelectedRoutine(wp, fp.profile);

            if (routine?.id != _currentRoutineId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _currentRoutineId = routine?.id);
              });
            }

            final int workoutCount = routine?.workoutIds.length ?? 0;
            final List<Workout> routineWorkouts = <Workout>[];
            if (routine != null) {
              for (final id in routine.workoutIds) {
                final w = wp.getWorkoutById(id);
                if (w != null) routineWorkouts.add(w);
              }
            }
            final List<bool>? restDisabledDays =
                routine == null ? null : _weeklyRestDaysForRoutine(routine);
            final String? intervalSummary = routine == null
                ? null
                : _intervalSummaryForRest(routine.restSchedule);
            final bool showIntervalCallout = routine != null &&
                routine.scheduleMode == RepetitionMode.interval &&
                intervalSummary != null;

            return GestureDetector(
              onHorizontalDragEnd: _maybeCloseOnSwipe,
              child: Scaffold(
                backgroundColor: _WorkoutPalette.bg,
                body: SafeArea(
                  bottom: false,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Main scroll content
                      ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 120),
                        children: [
                          // Header: calendar + routine carousel
                          WorkoutDashboardWidget(
                            selectedDate: _selectedDate,
                            getProgressForDay: _routineProgressForDay,
                            onDateSelected: (date) =>
                                setState(() => _selectedDate = date),
                            accentColor: _WorkoutPalette.accent,
                            isRestDayFor: routine == null
                                ? null
                                : (day) => wp.isRestDay(routine.id, day),
                            isOneOffRestFor: wp.hasOneOffRestOverride,
                            selectedRoutineId:
                                _selectedRoutineId ?? routine?.id,
                            onRoutineSelected: _onRoutineSelected,
                            carouselTwoRows: false,
                            carouselColumns: 4,
                            carouselCardColor: const Color(0xFF0A0E11),
                            carouselPadding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 10),
                            carouselUnderlap: -24,
                            carouselTopBottomPad: 10,
                            carouselScrollbarBottomInset: 0,
                            enableScrollbar: true,
                            showDivider: true,
                          ),

                        // ===== Centered "TODAY" header pill =====
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: _CenteredHeaderPill(
                            title: 'TODAY',
                            expanded: _todayExpanded,
                            onToggle: () => setState(
                                () => _todayExpanded = !_todayExpanded),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                            child: _buildTodayContent(routine),
                          ),
                          crossFadeState: _todayExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 180),
                          sizeCurve: Curves.easeOutCubic,
                        ),

                        // ===== Centered "WORKOUTS (N)" header pill =====
                        if (routine != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _CenteredHeaderPill(
                              title: 'WORKOUTS ($workoutCount)',
                              expanded: _workoutsExpanded,
                              onToggle: () => setState(
                                  () => _workoutsExpanded = !_workoutsExpanded),
                            ),
                          ),
                          if (showIntervalCallout)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                              child: Text(
                                intervalSummary!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                              child: Column(
                                children: [
                                  if (routineWorkouts.isEmpty)
                                    _WorkoutListPill(
                                      label: 'New workout',
                                      isPrimary: true,
                                      onTap: () =>
                                          _openCreateWorkoutInRoutine(routine),
                                      scheduleMode: routine.scheduleMode,
                                      routineRestSchedule: routine.restSchedule,
                                      intervalSummaryLabel: showIntervalCallout
                                          ? intervalSummary
                                          : null,
                                    )
                                  else ...[
                                    for (final w in routineWorkouts)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Dismissible(
                                          key: ValueKey('workout-pill-${w.id}'),
                                          direction:
                                              DismissDirection.endToStart,
                                          confirmDismiss: (_) async =>
                                              _confirmRemoveFromRoutine(
                                            context,
                                            w.title.trim().isEmpty
                                                ? 'Untitled workout'
                                                : w.title.trim(),
                                          ),
                                          background: _SwipeBackground(),
                                          child: _WorkoutListPill(
                                            workoutId: w.id,
                                            label: w.title.trim().isEmpty
                                                ? 'Untitled workout'
                                                : w.title.trim(),
                                            onTap: () => _openEditWorkout(w.id),
                                            // Actions
                                            onStart: () => _startWorkout(w.id,
                                                routineId: routine.id),
                                            onInfo: () => _openTimelineFor(w),
                                            onEdit: () =>
                                                _openEditWorkout(w.id),

                                            // Collapsed context — wired to stat helpers
                                            focusLabel: _deriveFocusLabel(w),
                                            targetMinutes:
                                                _deriveTargetMinutes(w),
                                            blockCount: _deriveBlockCount(w),
                                            exerciseCount:
                                                _deriveExerciseCount(w),
                                            timesCompleted:
                                                _countTimesCompleted(w.id),
                                            onViewTimeline: () =>
                                                _openTimelineFor(w),

                                            // Day toggles (local state)
                                            daySelections: _getPicks(w.id),
                                            disabledDays: restDisabledDays,
                                            onToggleDay: (i) =>
                                                _toggleDay(w.id, i),
                                            scheduleMode: routine.scheduleMode,
                                            routineRestSchedule:
                                                routine.restSchedule,
                                            intervalSummaryLabel:
                                                showIntervalCallout
                                                    ? intervalSummary
                                                    : null,
                                          ),
                                        ),
                                      ),
                                    _WorkoutListPill(
                                      label: 'New workout',
                                      isPrimary: true,
                                      onTap: () =>
                                          _openCreateWorkoutInRoutine(routine),
                                      scheduleMode: routine.scheduleMode,
                                      routineRestSchedule: routine.restSchedule,
                                      intervalSummaryLabel: showIntervalCallout
                                          ? intervalSummary
                                          : null,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            crossFadeState: _workoutsExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 180),
                            sizeCurve: Curves.easeOutCubic,
                          ),
                        ],
                      ],
                    ),

                    // Top-left cross-nav to Diet — raised higher
                    Positioned(
                      top: _cornerLift,
                      left: 8,
                      child: IconButton(
                        tooltip: 'Diet',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x33000000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                        ),
                        icon: const Icon(Icons.local_dining, size: 20),
                        onPressed: _goToDiet,
                      ),
                    ),

                    // Top-right Close (“X”) — routes to Progress
                    Positioned(
                      top: _cornerLift,
                      right: 8,
                      child: IconButton(
                        tooltip: 'Close',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x33000000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                        ),
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _goToProgress,
                      ),
                    ),
                  ],
                ),
              ),

              // Footer with Back / Profile / New
              bottomNavigationBar: _FooterControls(
                onBack: () => Navigator.of(context).maybePop(),
                onProfile: _openProfileOrScreening,
                onAdd: _openCreateWorkoutInSelected,
              ),
            ),
          );
        },
      );
    },
  );
  }
}
