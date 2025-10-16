import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/mission_seeder.dart';

class MissionProvider with ChangeNotifier {
  // ===== Config =====
  static const int _kVisibleSlots = 8;
  static const String _boxName = 'activeMissionsBox';
  static const String _metaBoxName = 'missionMetaBox';

  // Rarity weights (used for random within a bucket, not global mix)
  static const int _wtCommon = 65;
  static const int _wtRare = 28;
  static const int _wtLegendary = 7;

  // Suggested + board rarity policy
  static const int _maxLegendarySuggested = 1;   // among the 2 “Suggested”
  static const int _maxLegendaryOnBoard = 1;     // across all 8 visible

  // Quota plan for board fill (after suggested & accepted)
  static const int _quotaCommon = 6;
  static const int _quotaRare = 1;
  static const int _quotaLegendary = 1;

  // Legendary weekly throttle (days with ANY legendary on board)
  static const int _legendaryWindowDays = 4;
  static const int _legendaryDaysCap = 1;

  // Suggestion cooldown (don’t re-suggest the same mission too soon)
  static const int _suggestionCooldownDays = 2;

  // ===== State =====
  final Map<String, Mission> _byId = {};
  final List<String> _visibleIds = [];
  String? _lastRollYmd;

  // seeded per day for reproducible boards
  late Random _rng;

  ObjectiveProvider? _objectiveProvider;
  Box<Mission>? _box;
  Box<dynamic>? _metaBox;

  // meta (persisted)
  List<String> _legendaryDaysYmd = [];              // days we showed a legendary
  Map<String, String> _suggestedYmdById = {};       // missionId -> last suggested ymd
  List<String> _completedYesterdayIds = [];         // what was completed before reset (for priority re-add)

  // ===== Wiring =====
  void attachObjectiveProvider(ObjectiveProvider provider) {
    _objectiveProvider = provider;
  }

  Future<void> loadFromStorage() async {
    _box = Hive.box<Mission>(_boxName);
    if (!Hive.isBoxOpen(_metaBoxName)) {
      _metaBox = await Hive.openBox(_metaBoxName);
    } else {
      _metaBox = Hive.box(_metaBoxName);
    }

    if (_box!.isEmpty) {
      for (final m in MissionSeeder.seed()) {
        _byId[m.id] = m;
      }
      await _saveAll();
    } else {
      for (final m in _box!.values) {
        _byId[m.id] = m;
      }
    }

    // meta
    final savedVisible = (_metaBox?.get('visibleIds') as List?)?.cast<String>() ?? [];
    _lastRollYmd = _metaBox?.get('lastRollYmd') as String?;
    _legendaryDaysYmd = (_metaBox?.get('legendaryDaysYmd') as List?)?.cast<String>() ?? [];
    _suggestedYmdById = Map<String, String>.from(_metaBox?.get('suggestedYmdById') as Map? ?? {});
    _completedYesterdayIds = (_metaBox?.get('completedYesterdayIds') as List?)?.cast<String>() ?? [];

    if (savedVisible.isNotEmpty) {
      final seen = <String>{};
      for (final id in savedVisible) {
        if (_byId.containsKey(id) && !seen.contains(id)) {
          _visibleIds.add(id);
          seen.add(id);
        }
      }
    }

    // seed RNG for today (even before the first reset)
    _reseatRngFor(_todayYmdLocal());

    if (_visibleIds.isEmpty) {
      _rollDailySuggestionsIfNeeded(force: true);
      _topUpVisibleSlotsWithQuotas();
      await _saveMeta();
      _persistLater();
    }

    ensureTwoSuggestedPresent();
    notifyListeners();
  }

  // ===== Public API =====

  List<Mission> get allMissionsSorted {
    final list = _byId.values.toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  void addMission(Mission mission, {bool rebuildBoard = false}) {
    _byId[mission.id] = mission;
    if (rebuildBoard) {
      _topUpVisibleSlotsWithQuotas();
      ensureTwoSuggestedPresent();
      _saveMeta();
    }
    _persistLater();
    notifyListeners();
  }

  Future<void> seedIfEmpty() async {
    if (_byId.isEmpty) {
      for (final m in MissionSeeder.seed()) {
        _byId[m.id] = m;
      }
      await _saveAll();
    }
  }

  Future<void> syncWithSeeder() async {
    final seeds = MissionSeeder.seed();
    var added = false;
    for (final m in seeds) {
      if (!_byId.containsKey(m.id)) {
        _byId[m.id] = m;
        added = true;
      }
    }
    if (added) {
      await _saveAll();
    }
  }

  Future<void> ensureMissionSlotsFilled() async {
    final today = _todayYmdLocal();
    if (_lastRollYmd != today) {
      _dailyReset(today);
      _topUpVisibleSlotsWithQuotas();
      ensureTwoSuggestedPresent();
      _recordLegendaryDayIfNeeded(today);
      await _saveMeta();
      _persistLater();
      notifyListeners();
      return;
    }

    final before = _visibleIds.length;
    _topUpVisibleSlotsWithQuotas();
    ensureTwoSuggestedPresent();
    if (_visibleIds.length != before) {
      _recordLegendaryDayIfNeeded(today);
      await _saveMeta();
      _persistLater();
      notifyListeners();
    }
  }

  void forceRefreshMissions() {
    final acceptedKeep = _visibleIds.where((id) {
      final m = _byId[id];
      return m != null && m.isAccepted && !m.isCompleted;
    }).toList();

    _visibleIds
      ..clear()
      ..addAll(acceptedKeep);

    for (final m in _byId.values) {
      m.recommendedBySmartSuggestion = false;
    }

    _rollDailySuggestionsIfNeeded(force: true);
    _topUpVisibleSlotsWithQuotas();
    ensureTwoSuggestedPresent();
    _recordLegendaryDayIfNeeded(_todayYmdLocal());
    _persistLater();
    _saveMeta();
    notifyListeners();
  }

  List<Mission> getVisibleMissionSlots() =>
      _visibleIds.map((id) => _byId[id]).whereType<Mission>().toList();

  List<Mission> get acceptedMissions =>
      _byId.values.where((m) => m.isAccepted && !m.isCompleted).toList();

  List<Mission> get completedMissions =>
      _byId.values.where((m) => m.isCompleted).toList()
        ..sort((a, b) => b.rarity.index.compareTo(a.rarity.index));

  // ===== Mutations =====
  void acceptMission(Mission mission) {
    final m = _byId[mission.id];
    if (m == null) return;
    m.isAccepted = true;
    ensureTwoSuggestedPresent();
    _persistLater();
    notifyListeners();
  }

  void abandonMission(Mission mission) {
    final m = _byId[mission.id];
    if (m == null) return;
    m.isAccepted = false;
    ensureTwoSuggestedPresent();
    _persistLater();
    notifyListeners();
  }

  /// Marks complete **and awards XP** to the attached ObjectiveProvider.
  void completeMission(Mission mission) {
    final m = _byId[mission.id];
    if (m == null || m.isCompleted) return;

    m.isCompleted = true;
    m.isAccepted = false;

    final op = _objectiveProvider;
    if (op != null) {
      for (final catId in m.categoryIds) {
        op.addXpToCategory(catId, m.xpReward);
      }
    }

    _visibleIds.remove(mission.id);
    _topUpVisibleSlotsWithQuotas();
    ensureTwoSuggestedPresent();

    _persistLater();
    _saveMeta();
    notifyListeners();
  }

  void markIncomplete(Mission mission) {
    final m = _byId[mission.id];
    if (m == null) return;
    m.isCompleted = false;
    ensureTwoSuggestedPresent();
    _persistLater();
    notifyListeners();
  }

  void deleteMission(String id) {
    _byId.remove(id);
    _visibleIds.remove(id);
    ensureTwoSuggestedPresent();
    _persistLater();
    _saveMeta();
    notifyListeners();
  }

  Future<void> deleteAllCompleted() async {
    _byId.removeWhere((_, m) => m.isCompleted);
    _visibleIds.removeWhere((id) => !_byId.containsKey(id));
    ensureTwoSuggestedPresent();
    await _saveAll();
    await _saveMeta();
    notifyListeners();
  }

  /// Keep for internal/testing; UI should not expose it.
  bool putOnBoard(String id) {
    final m = _byId[id];
    if (m == null) return false;

    m.isCompleted = false;
    m.isAccepted = false;

    if (!_visibleIds.contains(id)) {
      if (_visibleIds.length >= _kVisibleSlots) {
        int removeIndex = _visibleIds.lastIndexWhere((vid) {
          final mm = _byId[vid];
          return mm == null || !mm.isAccepted;
        });
        if (removeIndex == -1) {
          removeIndex = _visibleIds.length - 1;
        }
        _visibleIds.removeAt(removeIndex);
      }
      _visibleIds.insert(0, id);
    }

    ensureTwoSuggestedPresent();
    _persistLater();
    _saveMeta();
    notifyListeners();
    return true;
  }

  // ===== Daily reset =====
  Future<void> dailyReset() async {
    final today = _todayYmdLocal();
    if (_lastRollYmd == today) return;
    _dailyReset(today);
    _topUpVisibleSlotsWithQuotas();
    ensureTwoSuggestedPresent();
    _recordLegendaryDayIfNeeded(today);
    await _saveMeta();
    _persistLater();
    notifyListeners();
  }

  /// 🧪 Debug: do the exact midnight-style reset **now** (same path).
  Future<void> debugResetBoardNow() async {
    final today = _todayYmdLocal();
    _dailyReset(today);                // identical internals
    _topUpVisibleSlotsWithQuotas();
    ensureTwoSuggestedPresent();
    _recordLegendaryDayIfNeeded(today);
    await _saveMeta();
    _persistLater();
    notifyListeners();
  }

  // ===== Internals =====
  String _todayYmdLocal() {
    final now = DateTime.now().toLocal();
    return '${now.year.toString().padLeft(4, '0')}-'
           '${now.month.toString().padLeft(2, '0')}-'
           '${now.day.toString().padLeft(2, '0')}';
  }

  void _reseatRngFor(String ymd) {
    // Include pool size to avoid degenerate repeats when the pool changes.
    _rng = Random(ymd.hashCode ^ (_byId.length << 7));
  }

  void _dailyReset(String todayYmd) {
    _lastRollYmd = todayYmd;
    _reseatRngFor(todayYmd);

    // Remember what was completed just before reset to prioritize within buckets
    _completedYesterdayIds = _byId.values
        .where((m) => m.isCompleted)
        .map((m) => m.id)
        .toList();

    // Unmark all completed
    for (final m in _byId.values) {
      m.isCompleted = false;
    }

    // Keep accepted missions visible
    final acceptedKeep = _visibleIds.where((id) {
      final m = _byId[id];
      return m != null && m.isAccepted;
    }).toList();

    _visibleIds
      ..clear()
      ..addAll(acceptedKeep);

    // Clear suggestions and re-roll
    for (final m in _byId.values) {
      m.recommendedBySmartSuggestion = false;
    }
    _rollDailySuggestionsIfNeeded(force: true);
  }

  // --- rarity helpers / tie-breakers (XP ignored) ---
  int _rarityRank(MissionRarity r) {
    switch (r) {
      case MissionRarity.legendary: return 3;
      case MissionRarity.rare:      return 2;
      case MissionRarity.common:    return 1;
    }
  }

  bool _isLegendary(Mission m) => m.rarity == MissionRarity.legendary;

  int _legendaryCountOnBoard() {
    int c = 0;
    for (final id in _visibleIds) {
      final m = _byId[id];
      if (m != null && !m.isCompleted && _isLegendary(m)) c++;
    }
    return c;
  }

  bool _withinLastNDays(String dayYmd, String todayYmd, int n) {
    DateTime parse(String ymd) {
      final p = ymd.split('-').map(int.parse).toList();
      return DateTime(p[0], p[1], p[2]);
    }
    final d = parse(dayYmd);
    final t = parse(todayYmd);
    return t.difference(d).inDays >= 0 && t.difference(d).inDays < n;
  }

  bool _weeklyLegendaryQuotaOpen(String today) {
    final recent = _legendaryDaysYmd.where((d) => _withinLastNDays(d, today, _legendaryWindowDays)).length;
    return recent < _legendaryDaysCap;
  }

  void _recordLegendaryDayIfNeeded(String today) {
    final hasLegendary = getVisibleMissionSlots().any(_isLegendary);
    if (hasLegendary && !_legendaryDaysYmd.contains(today)) {
      _legendaryDaysYmd.add(today);
      // prune old
      _legendaryDaysYmd = _legendaryDaysYmd
          .where((d) => _withinLastNDays(d, today, _legendaryWindowDays))
          .toList();
    }
  }

  // ===== Suggestions (2 max, <=1 legendary, cooldown, category spread) =====
  void _rollDailySuggestionsIfNeeded({bool force = false}) {
    final today = _todayYmdLocal();
    if (!force && _lastRollYmd == today) return;
    _lastRollYmd = today;

    for (final m in _byId.values) {
      m.recommendedBySmartSuggestion = false;
    }

    final pool = _byId.values
        .where((m) => !m.isCompleted && !m.isAccepted)
        .toList();
    if (pool.isEmpty) return;

    Map<String, int> recentByStat = {};
    try {
      recentByStat = _objectiveProvider?.getStatXpDelta('Last 7 Days') ?? {};
    } catch (_) {
      recentByStat = {};
    }

    int weakStatScore(Mission m) {
      int sum = 0;
      for (final sid in m.statIds) {
        sum += (recentByStat[sid] ?? 0);
      }
      return sum; // lower is weaker → higher priority
    }

    bool isCooledDown(Mission m) {
      final last = _suggestedYmdById[m.id];
      if (last == null) return true;
      return !_withinLastNDays(last, today, _suggestionCooldownDays + 1);
    }

    // Sort by: weaker stats, cooled-down first, freshness (lower timesRecommended),
    // lower rarity, category diversity hint, then alpha
    String primaryCat(Mission m) => m.categoryIds.isNotEmpty ? m.categoryIds.first : '~';
    final sorted = List<Mission>.from(pool)
      ..sort((a, b) {
        final s = weakStatScore(a).compareTo(weakStatScore(b));
        if (s != 0) return s;
        final cd = (isCooledDown(b) ? 1 : 0) - (isCooledDown(a) ? 1 : 0); // cooled first
        if (cd != 0) return cd;
        final fr = a.timesRecommended.compareTo(b.timesRecommended);
        if (fr != 0) return fr;
        final rr = _rarityRank(a.rarity).compareTo(_rarityRank(b.rarity)); // lower rarity first
        if (rr != 0) return rr;
        final cat = primaryCat(a).toLowerCase().compareTo(primaryCat(b).toLowerCase());
        if (cat != 0) return cat;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    final picks = <Mission>[];
    final seenCats = <String>{};
    int legPickCount = 0;
    final weeklyOpen = _weeklyLegendaryQuotaOpen(today);

    bool canTake(Mission m, {bool relaxLegendary = false}) {
      if (_isLegendary(m)) {
        if (legPickCount >= _maxLegendarySuggested) return false;
        if (!weeklyOpen && !relaxLegendary) return false;
      }
      // soft category spread: prefer new category if possible
      final cat = primaryCat(m);
      if (seenCats.contains(cat)) {
        // allow only if we can't find a non-conflicting option later
        // (we approximate by allowing in a 2nd pass if needed)
        return false;
      }
      return true;
    }

    // Pass 1: strict (no category dup, legendary gated by weeklyOpen)
    for (final m in sorted) {
      if (picks.length == 2) break;
      if (!canTake(m)) continue;
      picks.add(m);
      seenCats.add(primaryCat(m));
      if (_isLegendary(m)) legPickCount++;
    }

    // Pass 2: relax category spread (still obey suggested cap, and weekly gate)
    if (picks.length < 2) {
      for (final m in sorted) {
        if (picks.length == 2) break;
        if (picks.contains(m)) continue;
        if (_isLegendary(m)) {
          if (legPickCount >= _maxLegendarySuggested) continue;
          if (!weeklyOpen) continue; // still respect weekly gate in pass 2
        }
        picks.add(m);
        if (_isLegendary(m)) legPickCount++;
      }
    }

    // Pass 3: as a last resort, if weekly gate blocked filling 2 and only legendaries exist,
    // allow breaking weekly gate to reach 2 (keeps UX flowing when pool is tiny)
    if (picks.length < 2) {
      for (final m in sorted.where(_isLegendary)) {
        if (picks.length == 2) break;
        if (picks.contains(m)) continue;
        if (legPickCount >= _maxLegendarySuggested) continue;
        picks.add(m);
        legPickCount++;
      }
    }

    for (final m in picks) {
      m.recommendedBySmartSuggestion = true;
      m.timesRecommended += 1;
      _suggestedYmdById[m.id] = today;
    }
  }

  // ===== Quota-based top-up (6C/1R/1L), with legendary throttle & caps =====
  void _topUpVisibleSlotsWithQuotas() {
    final currentlyVisible = _visibleIds.toSet();

    // Place suggested first
    final suggested = _byId.values.where((m) {
      return m.recommendedBySmartSuggestion &&
          !m.isAccepted &&
          !m.isCompleted &&
          !currentlyVisible.contains(m.id);
    }).toList();

    for (final m in suggested) {
      if (_visibleIds.length >= _kVisibleSlots) break;
      _visibleIds.add(m.id);
    }

    // Count current visible by rarity
    int countRarity(MissionRarity r) {
      int c = 0;
      for (final id in _visibleIds) {
        final m = _byId[id];
        if (m != null && !m.isCompleted && m.rarity == r) c++;
      }
      return c;
    }

    int needCommon = (_quotaCommon - countRarity(MissionRarity.common)).clamp(0, _kVisibleSlots);
    int needRare   = (_quotaRare   - countRarity(MissionRarity.rare)).clamp(0, _kVisibleSlots);
    int needLeg    = (_quotaLegendary - countRarity(MissionRarity.legendary)).clamp(0, _kVisibleSlots);

    // Fill common first (we favor approachable work)
    _fillBucket(MissionRarity.common, needCommon);

    // Then rare
    _fillBucket(MissionRarity.rare, needRare);

    // Legendary last, only if caps/throttle permit
    final today = _todayYmdLocal();
    final weeklyOpen = _weeklyLegendaryQuotaOpen(today);
    final boardCapOpen = _legendaryCountOnBoard() < _maxLegendaryOnBoard;
    if (needLeg > 0 && weeklyOpen && boardCapOpen) {
      _fillBucket(MissionRarity.legendary, needLeg);
    }

    // If we’re still short (e.g., not enough rares/legs), backfill with lower rarity
    while (_visibleIds.length < _kVisibleSlots) {
      // Prefer common → rare → (legendary only if all else fails AND caps allow)
      if (_fillBucket(MissionRarity.common, 1) == 1) continue;
      if (_fillBucket(MissionRarity.rare, 1) == 1) continue;

      final boardCapOpen2 = _legendaryCountOnBoard() < _maxLegendaryOnBoard;
      final weeklyOpen2 = _weeklyLegendaryQuotaOpen(today);
      if (boardCapOpen2 && weeklyOpen2) {
        if (_fillBucket(MissionRarity.legendary, 1) == 1) continue;
      }
      break; // nothing left
    }
  }

  /// Returns how many actually added (<= need)
  int _fillBucket(MissionRarity rarity, int need) {
    if (need <= 0 || _visibleIds.length >= _kVisibleSlots) return 0;

    // build eligible list excluding already visible, accepted, completed
    final exclude = _visibleIds.toSet();
    final eligible = _byId.values.where((m) {
      if (m.rarity != rarity) return false;
      if (m.isCompleted || m.isAccepted) return false;
      if (exclude.contains(m.id)) return false;
      return true;
    }).toList();

    if (eligible.isEmpty) return 0;

    // prioritize yesterday’s completed within the bucket
    final priorityIds = _completedYesterdayIds.toSet();
    final priority = eligible.where((m) => priorityIds.contains(m.id)).toList();
    final others   = eligible.where((m) => !priorityIds.contains(m.id)).toList();

    int added = 0;

    // helper to pick one (weighted by per-mission rarity weight inside the bucket, but it’s constant per bucket;
    // we’ll just use a stable shuffle by rng to keep determinism)
    Mission _pickOne(List<Mission> list) {
      list.shuffle(_rng);
      return list.first;
    }

    while (need > 0 && _visibleIds.length < _kVisibleSlots) {
      Mission? pick;
      if (priority.isNotEmpty) {
        pick = _pickOne(priority);
        priority.remove(pick);
        others.remove(pick);
      } else if (others.isNotEmpty) {
        pick = _pickOne(others);
        others.remove(pick);
      } else {
        break;
      }

      // Legendary guard here as well (in case bucket == legendary)
      if (rarity == MissionRarity.legendary) {
        final today = _todayYmdLocal();
        if (_legendaryCountOnBoard() >= _maxLegendaryOnBoard) break;
        if (!_weeklyLegendaryQuotaOpen(today)) break;
      }

      _visibleIds.add(pick.id);
      added += 1;
      need -= 1;
    }

    return added;
  }

  /// Keep **exactly two** suggested missions present on the visible board.
  void ensureTwoSuggestedPresent() {
    final visible = getVisibleMissionSlots();

    final currentSuggested = visible
        .where((m) => m.recommendedBySmartSuggestion && !m.isCompleted)
        .toList();

    int changed = 0;

    // If more than 2, demote extras while preferring accepted and non-legendary.
    if (currentSuggested.length > 2) {
      final keepSorted = List<Mission>.from(currentSuggested)
        ..sort((a, b) {
          final aAcc = a.isAccepted ? 0 : 1; // keep accepted first
          final bAcc = b.isAccepted ? 0 : 1;
          if (aAcc != bAcc) return aAcc.compareTo(bAcc);

          final aLeg = _isLegendary(a) ? 1 : 0;
          final bLeg = _isLegendary(b) ? 1 : 0;
          if (aLeg != bLeg) return aLeg.compareTo(bLeg);

          // freshness, then lower rarity, then alpha
          final fr = a.timesRecommended.compareTo(b.timesRecommended);
          if (fr != 0) return fr;
          final rr = _rarityRank(a.rarity).compareTo(_rarityRank(b.rarity));
          if (rr != 0) return rr;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });

      final keep = keepSorted.take(2).map((m) => m.id).toSet();
      for (final m in currentSuggested) {
        if (!keep.contains(m.id)) {
          m.recommendedBySmartSuggestion = false;
          changed++;
        }
      }
    }

    // Recount after possible demotions.
    final after = getVisibleMissionSlots()
        .where((m) => m.recommendedBySmartSuggestion && !m.isCompleted)
        .toList();

    int suggestedCount = after.length;
    int legCount = after.where(_isLegendary).length;

    if (suggestedCount < 2) {
      final needed = 2 - suggestedCount;

      // Prefer non-accepted, NON-legendary, fresh; then relax if needed.
      final candidates = visible
          .where((m) => !m.isCompleted && !m.recommendedBySmartSuggestion)
          .toList()
        ..sort((a, b) {
          final aAcc = a.isAccepted ? 1 : 0; // prefer non-accepted
          final bAcc = b.isAccepted ? 1 : 0;
          if (aAcc != bAcc) return aAcc.compareTo(bAcc);

          final aLeg = _isLegendary(a) ? 1 : 0;
          final bLeg = _isLegendary(b) ? 1 : 0;
          if (aLeg != bLeg) return aLeg.compareTo(bLeg); // non-legendary first

          final fr = a.timesRecommended.compareTo(b.timesRecommended);
          if (fr != 0) return fr;
          final rr = _rarityRank(a.rarity).compareTo(_rarityRank(b.rarity));
          if (rr != 0) return rr;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });

      int added = 0;

      // Pass 1: respect legendary cap for suggested.
      for (final m in candidates) {
        if (_isLegendary(m) && legCount >= _maxLegendarySuggested) continue;
        m.recommendedBySmartSuggestion = true;
        m.timesRecommended += 1;
        legCount += _isLegendary(m) ? 1 : 0;
        added++;
        changed++;
        if (added == needed) break;
      }

      // Pass 2: relax if still short (e.g., only legendaries available).
      if (added < needed) {
        for (final m in candidates) {
          if (m.recommendedBySmartSuggestion) continue;
          m.recommendedBySmartSuggestion = true;
          m.timesRecommended += 1;
          added++;
          changed++;
          if (added == needed) break;
        }
      }
    }

    if (changed > 0) {
      _persistLater();
      notifyListeners();
    }
  }

  // ===== Persistence =====
  Future<void> _saveAll() async {
    if (_box == null) return;
    await _box!.clear();
    for (final m in _byId.values) {
      await _box!.put(m.id, m);
    }
  }

  Future<void> _saveMeta() async {
    if (_metaBox == null) return;
    await _metaBox!.put('visibleIds', List<String>.from(_visibleIds));
    if (_lastRollYmd != null) {
      await _metaBox!.put('lastRollYmd', _lastRollYmd);
    }
    await _metaBox!.put('legendaryDaysYmd', List<String>.from(_legendaryDaysYmd));
    await _metaBox!.put('suggestedYmdById', Map<String, String>.from(_suggestedYmdById));
    await _metaBox!.put('completedYesterdayIds', List<String>.from(_completedYesterdayIds));
  }

  void _persistLater() {
    Future.microtask(() async {
      await _saveAll();
      await _saveMeta();
    });
  }
}
