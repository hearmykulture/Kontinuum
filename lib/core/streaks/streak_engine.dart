import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:kontinuum/core/time/day_id.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/streak_models.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/core/time/app_clock.dart';

/// SUPER MINIMAL streak engine:
/// - Day streak (top banner): real calendar days you “kept” (do 1 thing or log time).
/// - Objective streak (flame on card): consecutive calendar days THIS objective was done,
///   walking backward from the latest completion (future allowed), stop on first hole.
/// - Category streak: when an entire category is 100% for a day.
class StreakEngine {
  final Box<ObjectiveStreak> _objBox;
  final Box<CategoryStreak> _catBox;
  final Box<DayStreak> _dayBox;
  final Box<BonusLedgerDay> _ledgerBox;
  final Box<MomentumWallet> _walletBox;
  final Box<SkipReceipt> _skipBox;

  StreakEngine(
    this._objBox,
    this._catBox,
    this._dayBox,
    this._ledgerBox,
    this._walletBox,
    this._skipBox,
  );

  // ---------------------------------------------------------------------------
  // Small helpers
  // ---------------------------------------------------------------------------

  bool _isConsecutive(DateTime prev, DateTime next) {
    final p = DateTime(prev.year, prev.month, prev.day);
    final n = DateTime(next.year, next.month, next.day);
    final pNext = p.add(const Duration(days: 1));
    return pNext.year == n.year && pNext.month == n.month && pNext.day == n.day;
  }

  int _ymd(DateTime d) => ymd(d);

  DateTime _fromYmd(int y) {
    final year = y ~/ 10000;
    final month = (y % 10000) ~/ 100;
    final day = y % 100;
    return DateTime(year, month, day);
  }

  int _grantBonus(int y, int requestedXp) {
    final ledger = _ledgerBox.get(y) ?? BonusLedgerDay(ymd: y);
    ledger.paidBonusXp += requestedXp;

    final wallet = _walletBox.get('wallet') ?? MomentumWallet();
    const int overflow = 0;
    ledger.overflowXp += overflow;

    _ledgerBox.put(y, ledger);
    _walletBox.put('wallet', wallet);

    return requestedXp;
  }

  // ---------------------------------------------------------------------------
  // 📅 DAY STREAK (top banner)
  // ---------------------------------------------------------------------------

  /// Called at rollover for a finished calendar [day].
  void finalizeDayAndEvalDayStreak(DateTime day, ObjectiveProvider provider) {
    final sd = _dayBox.get('day') ?? DayStreak();
    final todayY = _ymd(day);

    final state = provider.getTodayState(day);

    // lock requirement so UI text makes sense
    if (sd.lockedRequiredCountYmd != todayY) {
      sd.lockedRequiredCountYmd = todayY;
      sd.lockedRequiredCount = 1; // "do 1 thing"
    }

    final didEnoughTasks = state.completedObjectives >= sd.lockedRequiredCount;
    final didEnoughMinutes = state.rawMinutes > 0;

    final kept = didEnoughTasks || didEnoughMinutes;

    if (kept) {
      sd.current += 1;
      if (sd.current > sd.best) sd.best = sd.current;
      sd.lastKeptYmd = todayY;
    } else {
      sd.current = 0;
    }

    _dayBox.put('day', sd);
  }

  /// Freeze today's requirement as soon as we see progress.
  void lockDayRequirementIfNeeded(DateTime date, ObjectiveProvider provider) {
    final sd = _dayBox.get('day') ?? DayStreak();
    final dY = _ymd(date);
    if (sd.lockedRequiredCountYmd == dY) {
      _dayBox.put('day', sd);
      return;
    }

    sd.lockedRequiredCountYmd = dY;
    sd.lockedRequiredCount = 1;
    _dayBox.put('day', sd);
  }

  DayStreak getDayStreak() => _dayBox.get('day') ?? DayStreak();

  ValueListenable<Box<DayStreak>> dayListenable() => _dayBox.listenable();

  // ---------------------------------------------------------------------------
  // 🔥 OBJECTIVE STREAKS (per-task flame badge)
  //
  // Rules:
  // - per-objective, stored in _objBox
  // - walk BACK from the latest completion date for that objective
  // - stop on first missing calendar day
  // - future completions are allowed, but they DO NOT advance the day banner
  // ---------------------------------------------------------------------------

  int recordCompletionAndMaybeBonus(
    Objective o,
    DateTime date,
    ObjectiveProvider provider,
  ) {
    final DateTime realToday = AppClock.now();
    final int realTodayY = _ymd(realToday);
    final int completionY = _ymd(date);
    final bool isFuture = completionY > realTodayY;

    // 1) lock *today's* requirement if user is time-traveling,
    //    otherwise lock the actual completion day
    if (isFuture) {
      // keep day streak grounded in real time
      lockDayRequirementIfNeeded(realToday, provider);
    } else {
      lockDayRequirementIfNeeded(date, provider);
    }

    // 2) snapshot BEFORE recompute (for same-day no-regression)
    final ObjectiveStreak? prev = _objBox.get(o.id);
    final int prevCurrent = prev?.current ?? 0;
    final int prevBest = prev?.best ?? 0;
    final int prevLastYmd = prev?.lastYmd ?? 0;

    // 3) recompute per-objective, timeline style
    _recomputeObjectiveStreakTimeline(o.id, provider);

    // 4) read back
    final ObjectiveStreak? now = _objBox.get(o.id);
    if (now == null) return 0;

    // 5) SAME-DAY safety: if we were on the same day and it dropped, keep it
    if (prev != null &&
        now.lastYmd == prevLastYmd &&
        now.current < prevCurrent) {
      now.current = prevCurrent;
      if (prevBest > now.best) {
        now.best = prevBest;
      }
      _objBox.put(o.id, now);
    }

    return 0;
  }

  /// Public recompute (undo/edit/backfill).
  void recomputeObjectiveStreak(
    String objectiveId,
    ObjectiveProvider provider,
  ) {
    _recomputeObjectiveStreakTimeline(objectiveId, provider);
  }

  /// Banner-style recompute for ONE objective.
  /// - respects future completions
  /// - does NOT bridge over holes
  /// - still tracks bestRun in history
  void _recomputeObjectiveStreakTimeline(
    String objectiveId,
    ObjectiveProvider provider,
  ) {
    final streak =
        _objBox.get(objectiveId) ?? ObjectiveStreak(objectiveId: objectiveId);

    final dates = provider.getCompletedDatesForObjective(objectiveId);

    if (dates.isEmpty) {
      streak.current = 0;
      streak.lastYmd = 0;
      _objBox.put(objectiveId, streak);
      return;
    }

    // dedup by day and sort
    final Map<int, DateTime> byDay = {};
    for (final d in dates) {
      byDay[_ymd(d)] = DateTime(d.year, d.month, d.day);
    }
    final List<DateTime> ordered = byDay.values.toList()
      ..sort((a, b) => a.compareTo(b));

    // ---- best run anywhere in history (keep old behavior) ----
    int bestRun = 1;
    int runLen = 1;
    for (int i = 1; i < ordered.length; i++) {
      if (_isConsecutive(ordered[i - 1], ordered[i])) {
        runLen += 1;
      } else {
        if (runLen > bestRun) bestRun = runLen;
        runLen = 1;
      }
    }
    if (runLen > bestRun) bestRun = runLen;

    // ---- current run = walk BACK from latest, stop on first missing day ----
    final Set<int> doneDays = byDay.keys.toSet();
    int latestY = _ymd(ordered.last);
    int tail = 0;
    int cursorY = latestY;

    while (doneDays.contains(cursorY)) {
      tail += 1;
      final DateTime prevDay =
          _fromYmd(cursorY).subtract(const Duration(days: 1));
      cursorY = _ymd(prevDay);
    }

    streak.current = tail; // what the card shows
    if (bestRun > streak.best) {
      streak.best = bestRun;
    }
    streak.lastYmd = latestY;

    _objBox.put(objectiveId, streak);
  }

  void handleUndoCompletion(
    String objectiveId,
    ObjectiveProvider provider,
  ) {
    _recomputeObjectiveStreakTimeline(objectiveId, provider);
  }

  ObjectiveStreak? getObjectiveStreak(String objectiveId) =>
      _objBox.get(objectiveId);

  ValueListenable<Box<ObjectiveStreak>> objectiveListenable(
          {List<dynamic>? keys}) =>
      _objBox.listenable(keys: keys);

  int objectiveCurrent(String objectiveId) =>
      _objBox.get(objectiveId)?.current ?? 0;

  // ---------------------------------------------------------------------------
  // 📦 CATEGORY STREAKS (claim chip)
  // ---------------------------------------------------------------------------

  void onCategoryAllDoneToday(String categoryId, DateTime date) {
    final streak =
        _catBox.get(categoryId) ?? CategoryStreak(categoryId: categoryId);

    final tY = _ymd(date);
    final prevY = _ymd(date.subtract(const Duration(days: 1)));

    if (streak.lastFullYmd == tY) {
      _catBox.put(categoryId, streak);
      return;
    }

    if (streak.lastFullYmd == prevY) {
      streak.current += 1;
    } else {
      streak.current = 1;
    }

    if (streak.current > streak.best) {
      streak.best = streak.current;
    }

    streak.pendingXp = 10 * streak.current;
    streak.claimPending = true;

    streak.lastFullYmd = tY;
    _catBox.put(categoryId, streak);
  }

  void cancelCategoryClaimForTodayIfAny(String categoryId, DateTime date) {
    final s = _catBox.get(categoryId);
    if (s == null) return;
    final tY = _ymd(date);
    if (s.claimPending && s.lastFullYmd == tY) {
      s.claimPending = false;
      s.pendingXp = 0;
      _catBox.put(categoryId, s);
    }
  }

  int claimCategoryBonus(String categoryId, DateTime date) {
    final s = _catBox.get(categoryId);
    if (s == null) return 0;
    if (!s.claimPending || s.pendingXp <= 0) return 0;

    final paid = _grantBonus(_ymd(date), s.pendingXp);

    s.claimPending = false;
    s.lastClaimYmd = _ymd(date);
    s.pendingXp = 0;
    _catBox.put(categoryId, s);

    return paid;
  }

  void autocollectCategoryBonusesForYmd(int dayYmd) {
    for (final key in _catBox.keys) {
      final s = _catBox.get(key);
      if (s == null) continue;
      if (s.claimPending && s.lastFullYmd == dayYmd && s.pendingXp > 0) {
        _grantBonus(dayYmd, s.pendingXp);
        s.lastClaimYmd = dayYmd;
        s.pendingXp = 0;
        s.claimPending = false;
        _catBox.put(key, s);
      }
    }
  }

  CategoryStreak? getCategoryStreak(String categoryId) =>
      _catBox.get(categoryId);

  bool categoryClaimPending(String categoryId, DateTime day) {
    final s = _catBox.get(categoryId);
    if (s == null) return false;
    return s.claimPending && s.lastFullYmd == _ymd(day) && s.pendingXp > 0;
  }

  int pendingCategoryXp(String categoryId) =>
      _catBox.get(categoryId)?.pendingXp ?? 0;

  ValueListenable<Box<CategoryStreak>> categoryListenable(
          {List<dynamic>? keys}) =>
      _catBox.listenable(keys: keys);

  // ---------------------------------------------------------------------------
  // ❌ BREAK MISSED OBJECTIVE STREAKS / SKIPS
  // ---------------------------------------------------------------------------

  void breakMissedObjectiveStreaks(
    DateTime day,
    List<Objective> todaysObjectives,
  ) {
    final int dY = _ymd(day);

    for (final o in todaysObjectives) {
      if (o.isCompleted) continue;

      final s = _objBox.get(o.id);
      if (s == null) continue;

      final bool usedSkip = _skipBox.values.any(
        (rec) => rec.objectiveId == o.id && rec.ymd == dY,
      );
      if (usedSkip) continue;

      if (dY > s.lastYmd) {
        s.current = 0;
        _objBox.put(o.id, s);
      }
    }
  }

  bool applySkipForObjective(
    String objectiveId,
    DateTime day, {
    required int costMc,
  }) {
    _skipBox.add(
      SkipReceipt(objectiveId: objectiveId, ymd: _ymd(day)),
    );
    return true;
  }

  bool hasSkipForObjectiveOnDate(String objectiveId, DateTime day) {
    final int y = _ymd(day);
    return _skipBox.values.any(
      (r) => r.objectiveId == objectiveId && r.ymd == y,
    );
  }

  // ---------------------------------------------------------------------------
  // 💰 WALLET / CAP STUBS
  // ---------------------------------------------------------------------------

  MomentumWallet getWallet() => _walletBox.get('wallet') ?? MomentumWallet();

  bool canSpendMc(int mc) {
    final w = getWallet();
    return w.balanceMc >= mc;
  }

  void addMc(int mc) {
    final w = getWallet();
    w.balanceMc += mc;
    _walletBox.put('wallet', w);
  }

  bool spendMc(int mc) {
    final w = getWallet();
    if (w.balanceMc < mc) return false;
    w.balanceMc -= mc;
    _walletBox.put('wallet', w);
    return true;
  }

  int todayCapRemaining() => 999;
  int capRemainingFor(DateTime day) => 999;

  // ---------------------------------------------------------------------------
  // 🧼 DEBUG RESET
  // ---------------------------------------------------------------------------

  void clearAllStreakData() {
    _objBox.clear();
    _catBox.clear();
    _dayBox.clear();
    _ledgerBox.clear();
    _skipBox.clear();
    _walletBox.clear();
  }
}
