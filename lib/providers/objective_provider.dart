// lib/providers/objective_provider.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/data/level_utils.dart';
import 'package:kontinuum/data/objective_seeder.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/data/skill_seeder.dart';
import 'package:kontinuum/data/hive_service.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/data/milestone_seeder.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/providers/mission_provider.dart';

class ObjectiveProvider with ChangeNotifier {
  final Map<DateTime, List<Objective>> _objectivesByDate = {};
  final List<Objective> _staticObjectives = [];
  final Map<String, Category> _categories = {};
  final Map<String, Stat> _stats = {};
  final Map<String, Skill> _skills = {};
  final Map<String, List<Skill>> _skillsByCategory = {};
  final Uuid _uuid = const Uuid();
  final List<StatHistoryEntry> _statHistory = [];
  List<StatHistoryEntry> get statHistory => _statHistory;
  final Map<String, Milestone> _milestones = {};

  final HiveService _hiveService = HiveService();

  final ValueNotifier<int?> levelUpNotifier = ValueNotifier(null);
  final ValueNotifier<Category?> categoryLevelUpNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime> selectedDateNotifier = ValueNotifier(
    DateTime.now(),
  );

  static const List<String> coreCategoryIds = [
    'RAPPING',
    'PRODUCTION',
    'HEALTH',
    'KNOWLEDGE',
    'NETWORKING',
  ];

  int? _lastTotalLevelNotified;
  final Map<String, int> _lastCategoryLevelsNotified = {};
  Map<String, int> _previousStats = {};

  // ── Tally overage balance knobs (percentages) ─────────────────────────────
  static const double _tallyExtraStartPct = 0.50;
  static const double _tallyExtraStepPct = 0.10;
  static const double _tallyExtraFloorPct = 0.10;

  ObjectiveProvider() {
    for (final id in coreCategoryIds) {
      _categories[id] = Category(id: id, name: id);
    }
    _init();
  }

  // ---------- Small getters ----------
  List<Objective> get staticObjectives => List.unmodifiable(_staticObjectives);
  List<Objective> getObjectivesForExactDate(DateTime date) =>
      List.unmodifiable(_objectivesByDate[_normalize(date)] ?? []);
  Map<String, Category> get categories => _categories;
  Map<String, Stat> get stats => _stats;
  Map<String, Skill> get skills => _skills;
  Map<String, int> get previousStats => _previousStats;
  Map<String, Milestone> get milestones => _milestones;

  Future<void> persistSkills() async {
    await _hiveService.saveSkills(_skills.values.toList());
  }

  DateTime _normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  List<Objective> getObjectivesForDay(DateTime date) {
    final normalized = _normalize(date);
    final weekday = normalized.weekday;

    final dayObjectives = _objectivesByDate[normalized] ?? [];
    final overrides = {for (var o in dayObjectives) o.id: o};

    final result = _staticObjectives
        .where((o) => o.isActiveOnWeekday(weekday))
        .map((o) => overrides[o.id] ?? o.copyWith())
        .toList();

    final staticIds = _staticObjectives.map((o) => o.id).toSet();
    final extras = dayObjectives.where((o) => !staticIds.contains(o.id));
    result.addAll(extras);

    return result;
  }

  double getProgressForDay(DateTime date) {
    final objectives = getObjectivesForDay(date);
    if (objectives.isEmpty) return 0.0;
    final completed = objectives.where((o) => o.isCompleted).length;
    return completed / objectives.length;
  }

  void addObjective({
    required String title,
    required ObjectiveType type,
    required List<String> categoryIds,
    required List<String> statIds,
    int targetAmount = 1,
    int xpReward = 1,
    Map<int, bool>? activeDays,
    DateTime? startDate,
    List<String> prerequisiteIds = const [],
    List<String> subtaskIds = const [],
    String? description,
    String? writingBlockId,
    bool isStatic = false,
    int? repeatEveryNDays,
    DateTime? repeatAnchorDate,
  }) {
    final id = _uuid.v4();
    final objective = Objective(
      id: id,
      title: title,
      type: type,
      categoryIds: categoryIds,
      statIds: statIds,
      targetAmount: targetAmount,
      xpReward: xpReward,
      activeDays: activeDays ?? {for (int i = 1; i <= 7; i++) i: true},
      prerequisiteIds: prerequisiteIds,
      subtaskIds: subtaskIds,
      description: description,
      writingBlockId: writingBlockId,
      repeatEveryNDays: repeatEveryNDays,
      repeatAnchorDate: repeatAnchorDate,
    );

    if (isStatic) {
      _staticObjectives.add(objective);
    } else {
      final date = _normalize(startDate ?? DateTime.now());
      _objectivesByDate.putIfAbsent(date, () => []);
      _objectivesByDate[date]!.add(objective);
    }

    Future.microtask(() => persistObjectives());
    notifyListeners();
  }

  void toggleObjectiveCompletion(DateTime date, String objectiveId) {
    _previousStats = Map.fromEntries(
      _stats.entries.map((e) => MapEntry(e.key, e.value.count)),
    );

    final normalized = _normalize(date);
    final dateList = _objectivesByDate.putIfAbsent(normalized, () => []);

    Objective? obj = dateList.firstWhere(
      (o) => o.id == objectiveId,
      orElse: () {
        final staticMatch = _staticObjectives.firstWhere(
          (o) => o.id == objectiveId,
          orElse: () => throw Exception("Objective not found"),
        );
        final copy = staticMatch.copyWith();
        dateList.add(copy);
        return copy;
      },
    );

    final prevTotalXp = totalXp;
    final xp = obj.actualXpEarned ?? obj.xpReward;

    if (obj.isCompleted) {
      // Toggle to INCOMPLETE — keep progress
      obj.isCompleted = false;
      obj.completedOn = null;

      for (final catId in obj.categoryIds) {
        final cat = _categories.putIfAbsent(
          catId,
          () => Category(id: catId, name: catId),
        );
        cat.xp = (cat.xp - xp).clamp(0, 600000);
      }

      for (final statId in obj.statIds) {
        final stat = _stats.putIfAbsent(
          statId,
          () => Stat(
            id: statId,
            label: statId,
            averageMinutesPerUnit: 1,
            repsForMastery: 1,
          ),
        );
        // Undo target grant given on completion
        stat.count = math.max(0, stat.count - obj.targetAmount);
        stat.xp = math.max(0, stat.xp - xp);

        for (final skill in _skills.values) {
          if (skill.stats.any((s) => s.id == statId)) {
            _statHistory.add(
              StatHistoryEntry(
                statId: stat.id,
                date: DateTime.now(),
                amount: -obj.targetAmount,
                skillId: skill.id,
              ),
            );
          }
        }
      }
    } else {
      // Toggle to COMPLETE — ensure at least target
      obj.isCompleted = true;
      obj.completedAmount = math.max(obj.completedAmount, obj.targetAmount);
      obj.completedOn = DateTime.now();

      for (final catId in obj.categoryIds) {
        final cat = _categories.putIfAbsent(
          catId,
          () => Category(id: catId, name: catId),
        );

        final prevLevel = LevelUtils.getCategoryLevelFromXp(cat.xp);
        cat.xp = (cat.xp + xp).clamp(0, 600000);
        final newLevel = LevelUtils.getCategoryLevelFromXp(cat.xp);

        if (newLevel > prevLevel &&
            _lastCategoryLevelsNotified[cat.id] != newLevel) {
          _lastCategoryLevelsNotified[cat.id] = newLevel;
          Future.microtask(() {
            categoryLevelUpNotifier.value = null;
            categoryLevelUpNotifier.value = cat;
          });
        }
      }

      for (final statId in obj.statIds) {
        final stat = _stats.putIfAbsent(
          statId,
          () => Stat(
            id: statId,
            label: statId,
            averageMinutesPerUnit: 1,
            repsForMastery: 1,
          ),
        );
        stat.count += obj.targetAmount;
        stat.xp += xp;

        for (final skill in _skills.values) {
          if (skill.stats.any((s) => s.id == statId)) {
            addXpToSkill(skill.id, xp);

            _statHistory.add(
              StatHistoryEntry(
                statId: stat.id,
                date: DateTime.now(),
                amount: obj.targetAmount,
                skillId: skill.id,
              ),
            );
          }
        }

        final milestone = _milestones[statId];
        if (milestone != null) {
          final statCount = stat.count;
          final achieved = milestone.getAchieved(statCount);
          if (achieved.isNotEmpty) {
            debugPrint("🏆 Milestones hit for $statId: $achieved");
          }
        }
      }
    }

    final newTotalXp = totalXp;
    final prevTotalLevel = LevelUtils.getTotalLevelFromXp(
      prevTotalXp,
      _categories.length,
    );
    final newTotalLevel = LevelUtils.getTotalLevelFromXp(
      newTotalXp,
      _categories.length,
    );

    if (newTotalLevel > prevTotalLevel &&
        _lastTotalLevelNotified != newTotalLevel) {
      _lastTotalLevelNotified = newTotalLevel;
      Future.microtask(() {
        levelUpNotifier.value = null;
        levelUpNotifier.value = newTotalLevel;
      });
    }

    Future.microtask(() {
      _hiveService.saveStats(_stats);
      _hiveService.saveCategories(_categories);
      _hiveService.saveStatHistory(_statHistory);
      persistObjectives();
    });

    selectedDateNotifier.value = selectedDateNotifier.value;
    notifyListeners();
  }

  void evaluateLocks(DateTime date) {
    final normalized = _normalize(date);
    final objectives = _objectivesByDate[normalized];
    if (objectives == null) return;

    final completedIds = objectives
        .where((o) => o.isCompleted)
        .map((o) => o.id)
        .toSet();

    for (final obj in objectives) {
      final isBlocked = obj.prerequisiteIds.any(
        (id) => !completedIds.contains(id),
      );
      obj.isLocked = isBlocked;
      obj.lockedReason = isBlocked ? 'Incomplete prerequisite(s)' : null;
    }
    notifyListeners();
  }

  int getCategoryXp(String categoryId) => _categories[categoryId]?.xp ?? 0;
  int getStatCount(String statId) => _stats[statId]?.count ?? 0;

  int get totalXp => _categories.values.fold(0, (sum, cat) => sum + cat.xp);
  int get totalLevel =>
      LevelUtils.getTotalLevelFromXp(totalXp, _categories.length);
  int get totalXpForNextLevel =>
      LevelUtils.getTotalXpForLevel(totalLevel + 1, _categories.length);
  int get totalXpForCurrentLevel =>
      LevelUtils.getTotalXpForLevel(totalLevel, _categories.length);

  double get totalLevelProgress {
    final current = totalXpForCurrentLevel;
    final next = totalXpForNextLevel;
    if (next == current) return 0.0;
    return ((totalXp - current) / (next - current)).clamp(0.0, 1.0);
  }

  /// Creates the category if missing (ID is uppercased). Persists + notifies.
  void ensureCategoryExists(
    String categoryId, {
    String? displayName,
    int? colorInt,
  }) {
    if (!_categories.containsKey(categoryId)) {
      _categories[categoryId] = Category(
        id: categoryId,
        name: displayName ?? categoryId,
        colorInt: colorInt,
      );
      Future.microtask(() => _hiveService.saveCategories(_categories));
      notifyListeners();
    }
  }

  /// Convenience for UI: pass a label, optional color; we uppercase as ID.
  void createCategory(String nameOrId, {Color? color}) {
    final id = nameOrId.toUpperCase();
    if (_categories.containsKey(id)) {
      if (color != null && _categories[id]!.colorInt == null) {
        _categories[id] = Category(
          id: id,
          name: _categories[id]!.name,
          xp: _categories[id]!.xp,
          skills: _categories[id]!.skills,
          colorInt: color.value,
        );
        Future.microtask(() => _hiveService.saveCategories(_categories));
        notifyListeners();
      }
      return;
    }
    _categories[id] = Category(id: id, name: nameOrId, colorInt: color?.value);
    Future.microtask(() => _hiveService.saveCategories(_categories));
    notifyListeners();
  }

  void addXpToCategory(String categoryId, int xp) {
    ensureCategoryExists(categoryId);
    final cat = _categories[categoryId]!;

    final prevLevel = LevelUtils.getCategoryLevelFromXp(cat.xp);
    cat.xp = (cat.xp + xp).clamp(0, 600000);
    final newLevel = LevelUtils.getCategoryLevelFromXp(cat.xp);

    if (newLevel > prevLevel &&
        _lastCategoryLevelsNotified[cat.id] != newLevel) {
      _lastCategoryLevelsNotified[cat.id] = newLevel;
      Future.microtask(() {
        categoryLevelUpNotifier.value = null;
        categoryLevelUpNotifier.value = cat;
      });
    }

    final prevTotalLevel = totalLevel;
    final newTotalLevel = LevelUtils.getTotalLevelFromXp(
      totalXp,
      _categories.length,
    );

    if (newTotalLevel > prevTotalLevel &&
        _lastTotalLevelNotified != newTotalLevel) {
      _lastTotalLevelNotified = newTotalLevel;
      Future.microtask(() {
        levelUpNotifier.value = null;
        levelUpNotifier.value = newTotalLevel;
      });
    }

    Future.microtask(() => _hiveService.saveCategories(_categories));
    notifyListeners();
  }

  void addStaticObjectives() {
    ObjectiveSeeder.seedAll(this);
    SkillSeeder.seedAll(this);
  }

  Map<DateTime, double> getProgressForSurroundingWeek(DateTime centerDate) {
    final Map<DateTime, double> map = {};
    for (int i = -3; i <= 3; i++) {
      final date = centerDate.add(Duration(days: i));
      map[date] = getProgressForDay(date);
    }
    return map;
  }

  void resetAllXp({bool suppressNotify = false}) {
    for (final cat in _categories.values) {
      cat.xp = 0;
    }
    for (final skill in _skills.values) {
      skill.xp = 0;
    }
    for (final stat in _stats.values) {
      stat.count = 0;
    }

    _skills.clear();
    _skillsByCategory.clear();

    levelUpNotifier.value = null;
    categoryLevelUpNotifier.value = null;
    _lastTotalLevelNotified = null;
    _lastCategoryLevelsNotified.clear();
    _previousStats.clear();

    Future.microtask(() {
      persistSkills();
      _hiveService.saveStats(_stats);
      _hiveService.saveCategories(_categories);
      persistObjectives();
    });

    if (!suppressNotify) notifyListeners();
  }

  void registerSkill(String skillId, Skill skill) {
    _skills[skillId] = skill;

    final categoryId = skill.categoryId;
    _skillsByCategory.putIfAbsent(categoryId, () => []).add(skill);

    for (final stat in skill.stats) {
      registerStat(stat);
    }
    notifyListeners();
  }

  void addXpToSkill(String skillId, int xp) {
    final skill = _skills[skillId];
    if (skill != null) {
      skill.xp += xp;
      Future.microtask(() => persistSkills());
    }
    notifyListeners();
  }

  List<Skill> getSkillsForCategory(String categoryId) {
    return _skillsByCategory[categoryId] ?? const <Skill>[];
  }

  void registerStat(Stat stat) {
    _stats[stat.id] = stat;
    notifyListeners();
  }

  Future<void> _init() async {
    try {
      _categories.addEntries(
        coreCategoryIds.map((id) => MapEntry(id, Category(id: id, name: id))),
      );

      final loadedStats = await _hiveService.loadStats();
      final loadedCategories = await _hiveService.loadCategories();
      final loadedSkills = await _hiveService.loadSkills();
      final loadedStaticObjectives = await _hiveService.loadStaticObjectives();
      final loadedObjectivesByDate = await _hiveService.loadObjectivesByDate();
      final loadedHistory = await _hiveService.loadStatHistory();
      final loadedMilestones = await _hiveService.loadMilestones();

      _stats.addAll(loadedStats);
      _categories.addAll(loadedCategories);
      _staticObjectives.addAll(loadedStaticObjectives);
      _objectivesByDate.addAll(loadedObjectivesByDate);
      _statHistory.addAll(loadedHistory);
      _milestones.addAll(loadedMilestones);

      for (final skill in loadedSkills) {
        registerSkill(skill.id, skill);
      }

      debugPrint("📦 Loaded ${_milestones.length} milestones from Hive");
    } catch (e, stack) {
      debugPrint("🛑 Error loading from Hive: $e\n$stack");
    }

    if (_skills.isEmpty) {
      SkillSeeder.seedAll(this);
    }

    if (_milestones.isEmpty) {
      debugPrint("🌱 Seeding default milestones");
      MilestoneSeeder.seedAll(this);
    }

    if (_staticObjectives.isEmpty) {
      addStaticObjectives();
    }
  }

  Future<void> persistObjectives() async {
    await _hiveService.saveStaticObjectives(_staticObjectives);
    await _hiveService.saveObjectivesByDate(_objectivesByDate);
  }

  void resetObjectiveCompletion() {
    for (final objectives in _objectivesByDate.values) {
      for (final obj in objectives) {
        obj.isCompleted = false;
        obj.completedAmount = 0;
        obj.completedOn = null;
        obj.isLocked = false;
        obj.lockedReason = null;
      }
    }
    for (final obj in _staticObjectives) {
      obj.isCompleted = false;
      obj.completedAmount = 0;
      obj.completedOn = null;
      obj.isLocked = false;
      obj.lockedReason = null;
    }
    Future.microtask(() => persistObjectives());
    notifyListeners();
  }

  void registerMilestone(Milestone milestone) {
    _milestones[milestone.statId] = milestone;
    notifyListeners();
  }

  void addMilestones() {
    MilestoneSeeder.seedAll(this);
    notifyListeners();
  }

  Milestone? getMilestoneForStat(String statId) => _milestones[statId];

  int getXpForId(String id) {
    if (_stats.containsKey(id)) {
      return _stats[id]!.count;
    } else if (_skills.containsKey(id)) {
      return _skills[id]!.xp;
    } else if (_categories.containsKey(id)) {
      return _categories[id]!.xp;
    }
    return 0;
  }

  void resetEverything({MissionProvider? missionProvider}) {
    for (final cat in _categories.values) {
      cat.xp = 0;
    }
    for (final skill in _skills.values) {
      skill.xp = 0;
    }
    for (final stat in _stats.values) {
      stat.count = 0;
    }

    _skills.clear();
    _skillsByCategory.clear();
    _staticObjectives.clear();
    _objectivesByDate.clear();
    _milestones.clear();
    _statHistory.clear();

    levelUpNotifier.value = null;
    categoryLevelUpNotifier.value = null;
    _lastTotalLevelNotified = null;
    _lastCategoryLevelsNotified.clear();
    _previousStats.clear();

    missionProvider?.forceRefreshMissions();

    Future.microtask(() {
      persistSkills();
      _hiveService.saveStats(_stats);
      _hiveService.saveCategories(_categories);
      _hiveService.saveObjectivesByDate(_objectivesByDate);
      _hiveService.saveStaticObjectives(_staticObjectives);
      _hiveService.saveStatHistory(_statHistory);
      _hiveService.saveMilestones(_milestones);
    });

    notifyListeners();
  }

  List<StatHistoryEntry> getStatHistory(String statId) {
    return _statHistory.where((entry) => entry.statId == statId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Category getCategoryById(String id) {
    if (!_categories.containsKey(id)) {
      throw Exception("Category with ID $id not found");
    }
    return _categories[id]!;
  }

  List<Stat> getStatsForCategory(String categoryId) {
    final List<Stat> statsInCategory = [];

    final skills = _skillsByCategory[categoryId] ?? const <Skill>[];
    for (final skill in skills) {
      statsInCategory.addAll(skill.stats);
    }

    for (final stat in _stats.values) {
      final meta = StatRepository.getById(stat.id);
      if (meta != null &&
          meta.categoryId == categoryId &&
          !statsInCategory.contains(stat)) {
        statsInCategory.add(stat);
      }
    }
    return statsInCategory;
  }

  Map<String, int> getStatXpForTimeframe(String timeframe) {
    final now = DateTime.now();
    final cutoff = switch (timeframe) {
      'Last 7 Days' => now.subtract(const Duration(days: 7)),
      'Last 30 Days' => now.subtract(const Duration(days: 30)),
      'This Week' => DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      _ => null,
    };

    final result = <String, int>{};
    for (final entry in _statHistory) {
      if (cutoff == null || entry.date.isAfter(cutoff)) {
        result[entry.statId] = (result[entry.statId] ?? 0) + entry.amount;
      }
    }
    return result;
  }

  Map<String, int> getStatXpDelta(String timeframe) {
    final start = _getTimeframeCutoff(timeframe);
    if (start == null) return {};
    final deltaMap = <String, int>{};
    for (final entry in _statHistory) {
      if (entry.date.isAfter(start)) {
        deltaMap[entry.statId] = (deltaMap[entry.statId] ?? 0) + entry.amount;
      }
    }
    return deltaMap;
  }

  Map<String, int> getSkillXpDelta(String timeframe) {
    final start = _getTimeframeCutoff(timeframe);
    if (start == null) return {};
    final deltaMap = <String, int>{};
    for (final entry in _statHistory) {
      if (entry.skillId != null && entry.date.isAfter(start)) {
        deltaMap[entry.skillId!] =
            (deltaMap[entry.skillId!] ?? 0) + entry.amount;
      }
    }
    return deltaMap;
  }

  DateTime? _getTimeframeCutoff(String timeframe) {
    final now = DateTime.now();
    return switch (timeframe) {
      'Last 7 Days' => now.subtract(const Duration(days: 7)),
      'Last 30 Days' => now.subtract(const Duration(days: 30)),
      'This Week' => DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      'All Time' => null,
      _ => null,
    };
  }

  // ──────────────────────────── TALLY XP HELPERS ────────────────────────────

  double _pctForExtra(int i) {
    final p = _tallyExtraStartPct - _tallyExtraStepPct * (i - 1);
    return p < _tallyExtraFloorPct ? _tallyExtraFloorPct : p;
  }

  int _computeTallyXpDelta({
    required int oldAmount,
    required int newAmount,
    required int target,
    required int baseXpPerTally,
  }) {
    oldAmount = math.max(0, oldAmount);
    newAmount = math.max(0, newAmount);
    target = math.max(0, target);

    if (newAmount == oldAmount || baseXpPerTally <= 0) return 0;

    int deltaXp = 0;

    if (newAmount > oldAmount) {
      final int incWithin =
          (math.min(newAmount, target) - math.min(oldAmount, target)).toInt();
      deltaXp += incWithin * baseXpPerTally;

      final int oldExtra = math.max(0, oldAmount - target);
      final int newExtra = math.max(0, newAmount - target);
      for (int i = oldExtra + 1; i <= newExtra; i++) {
        deltaXp += (baseXpPerTally * _pctForExtra(i)).round();
      }
    } else {
      final int decWithin =
          (math.min(oldAmount, target) - math.min(newAmount, target)).toInt();
      deltaXp -= decWithin * baseXpPerTally;

      final int oldExtra = math.max(0, oldAmount - target);
      final int newExtra = math.max(0, newAmount - target);
      for (int i = newExtra + 1; i <= oldExtra; i++) {
        deltaXp -= (baseXpPerTally * _pctForExtra(i)).round();
      }
    }
    return deltaXp;
  }

  void _applyTallyDelta({
    required Objective obj,
    required int xpDelta,
    required int unitDelta,
  }) {
    if (xpDelta == 0 && unitDelta == 0) return;

    // Categories
    for (final catId in obj.categoryIds) {
      addXpToCategory(catId, xpDelta);
    }

    // Stats + Skills + History
    for (final statId in obj.statIds) {
      final stat = _stats.putIfAbsent(
        statId,
        () => Stat(
          id: statId,
          label: statId,
          averageMinutesPerUnit: 1,
          repsForMastery: 1,
        ),
      );

      stat.count = math.max(0, stat.count + unitDelta);
      stat.xp = math.max(0, stat.xp + xpDelta);

      for (final skill in _skills.values) {
        if (skill.stats.any((s) => s.id == statId)) {
          addXpToSkill(skill.id, xpDelta);
          _statHistory.add(
            StatHistoryEntry(
              statId: stat.id,
              date: DateTime.now(),
              amount: unitDelta,
              skillId: skill.id,
            ),
          );
        }
      }

      final milestone = _milestones[statId];
      if (milestone != null) {
        final statCount = stat.count;
        final achieved = milestone.getAchieved(statCount);
        if (achieved.isNotEmpty) {
          debugPrint("🏆 Milestones hit for $statId: $achieved");
        }
      }
    }

    Future.microtask(() {
      _hiveService.saveStats(_stats);
      _hiveService.saveStatHistory(_statHistory);
      persistSkills();
    });
  }

  // ──────────────────────── CORE UPDATE (TALLY-AWARE) ───────────────────────

  void updateObjectiveAmountForDate(
    DateTime date,
    String objectiveId,
    int newAmount,
  ) {
    final normalized = _normalize(date);
    final dateList = _objectivesByDate.putIfAbsent(normalized, () => []);

    var idx = dateList.indexWhere((o) => o.id == objectiveId);
    if (idx == -1) {
      final base = _staticObjectives.firstWhere(
        (o) => o.id == objectiveId,
        orElse: () => throw Exception("Objective not found"),
      );
      dateList.add(base.copyWith());
      idx = dateList.length - 1;
    }

    final obj = dateList[idx];

    // ── Special handling for TALLY with diminishing XP ──────────────────────
    if (obj.type == ObjectiveType.tally) {
      final int oldAmount = obj.getCompletedAmount(normalized);
      final int finalAmount = math.max(0, newAmount);
      final int unitDelta = finalAmount - oldAmount;

      if (unitDelta == 0) {
        final bool nowCompleted = finalAmount >= obj.targetAmount;
        obj.isCompleted = nowCompleted;
        obj.completedOn = nowCompleted
            ? (obj.completedOn ?? DateTime.now())
            : null;

        evaluateLocks(normalized);
        notifyListeners();
        persistObjectives();
        return;
      }

      obj.setCompletedAmount(normalized, finalAmount);

      final int target = math.max(1, obj.targetAmount);
      final int baseXpPerTally = (obj.xpReward / target).round();

      final int xpDelta = _computeTallyXpDelta(
        oldAmount: oldAmount,
        newAmount: finalAmount,
        target: obj.targetAmount,
        baseXpPerTally: baseXpPerTally,
      );

      final bool nowCompleted = finalAmount >= obj.targetAmount;
      obj.isCompleted = nowCompleted;
      obj.completedOn = nowCompleted
          ? (obj.completedOn ?? DateTime.now())
          : null;

      _applyTallyDelta(obj: obj, xpDelta: xpDelta, unitDelta: unitDelta);

      evaluateLocks(normalized);
      notifyListeners();
      persistObjectives();
      return;
    }

    // ── ORIGINAL behavior for non-tally types ───────────────────────────────
    final wasCompleted = obj.isCompleted;

    final int finalAmount = math.max(0, newAmount);
    obj.setCompletedAmount(normalized, finalAmount);

    final reachedTarget = finalAmount >= obj.targetAmount;

    if (reachedTarget && !wasCompleted) {
      toggleObjectiveCompletion(normalized, objectiveId);
      return;
    } else if (!reachedTarget && wasCompleted) {
      toggleObjectiveCompletion(normalized, objectiveId);
      return;
    }

    if (!reachedTarget) {
      obj.isCompleted = false;
      obj.completedOn = null;
    }

    evaluateLocks(normalized);
    notifyListeners();
    persistObjectives();
  }

  // =================== DELETE APIs ===================

  Future<void> deleteCategory(String categoryId) async {
    if (!_categories.containsKey(categoryId)) return;

    for (final o in _staticObjectives) {
      o.categoryIds.removeWhere((id) => id == categoryId);
    }
    for (final list in _objectivesByDate.values) {
      for (final o in list) {
        o.categoryIds.removeWhere((id) => id == categoryId);
      }
    }

    _categories.remove(categoryId);

    await _hiveService.saveCategories(_categories);
    await persistObjectives();
    notifyListeners();
  }

  Future<bool> deleteObjectiveOnDate(DateTime date, String objectiveId) async {
    final normalized = _normalize(date);
    final list = _objectivesByDate[normalized];
    if (list == null) return false;

    final before = list.length;
    list.removeWhere((o) => o.id == objectiveId);
    final changed = before != list.length;

    if (list.isEmpty) {
      _objectivesByDate.remove(normalized);
    }

    if (changed) {
      await persistObjectives();
      notifyListeners();
    }
    return changed;
  }

  Future<int> deleteObjectiveEverywhere(String objectiveId) async {
    int removed = 0;

    final beforeStatic = _staticObjectives.length;
    _staticObjectives.removeWhere((o) => o.id == objectiveId);
    removed += (beforeStatic - _staticObjectives.length);

    for (final entry in _objectivesByDate.entries.toList()) {
      final list = entry.value;
      final before = list.length;
      list.removeWhere((o) => o.id == objectiveId);
      removed += (before - list.length);
      if (list.isEmpty) _objectivesByDate.remove(entry.key);
    }

    if (removed > 0) {
      await persistObjectives();
      notifyListeners();
    }
    return removed;
  }

  Future<void> deleteObjective(String objectiveId) async {
    await deleteObjectiveEverywhere(objectiveId);
  }

  Future<bool> deleteStat(String statId) async {
    final existed = _stats.remove(statId) != null;

    for (final skill in _skills.values) {
      skill.stats.removeWhere((s) => s.id == statId);
    }
    for (final o in _staticObjectives) {
      o.statIds.removeWhere((id) => id == statId);
    }
    for (final list in _objectivesByDate.values) {
      for (final o in list) {
        o.statIds.removeWhere((id) => id == statId);
      }
    }

    _statHistory.removeWhere((e) => e.statId == statId);
    _milestones.remove(statId);

    if (existed) {
      await _hiveService.saveStats(_stats);
      await persistSkills();
      await persistObjectives();
      await _hiveService.saveStatHistory(_statHistory);
      await _hiveService.saveMilestones(_milestones);
      notifyListeners();
    }
    return existed;
  }

  Future<void> moveObjectiveToCategory({
    required String objectiveId,
    required String newCategoryId,
    DateTime? date,
  }) async {
    ensureCategoryExists(newCategoryId);
    bool changed = false;

    if (date != null) {
      final normalized = _normalize(date);
      final list = _objectivesByDate[normalized];
      if (list != null) {
        final i = list.indexWhere((o) => o.id == objectiveId);
        if (i != -1) {
          final o = list[i];
          if (o.categoryIds.isEmpty) {
            o.categoryIds.add(newCategoryId);
          } else {
            o.categoryIds[0] = newCategoryId;
          }
          changed = true;
        }
      }
    }

    final si = _staticObjectives.indexWhere((o) => o.id == objectiveId);
    if (si != -1) {
      final o = _staticObjectives[si];
      if (o.categoryIds.isEmpty) {
        o.categoryIds.add(newCategoryId);
      } else {
        o.categoryIds[0] = newCategoryId;
      }
      changed = true;
    }

    if (changed) {
      await persistObjectives();
      notifyListeners();
    }
  }

  /// Reorder objectives within [categoryId] for a specific [date].
  Future<void> reorderObjectivesInCategoryForDate(
    DateTime date,
    String categoryId,
    List<String> orderedIds,
  ) async {
    final weekday = _normalize(date).weekday;

    void reorderSubset(
      List<Objective> list,
      bool Function(Objective) inSubset,
    ) {
      final subset = list.where(inSubset).toList();
      if (subset.isEmpty) return;

      final mapById = {for (final o in subset) o.id: o};
      final reordered = <Objective>[];

      for (final id in orderedIds) {
        final o = mapById[id];
        if (o != null) reordered.add(o);
      }
      for (final o in subset) {
        if (!reordered.contains(o)) reordered.add(o);
      }

      int ptr = 0;
      for (int i = 0; i < list.length; i++) {
        if (inSubset(list[i])) {
          list[i] = reordered[ptr++];
        }
      }
    }

    // Static subset for this weekday & category (remove unnecessary parentheses)
    reorderSubset(
      _staticObjectives,
      (o) =>
          o.categoryIds.isNotEmpty &&
          o.categoryIds.first == categoryId &&
          o.isActiveOnWeekday(weekday),
    );

    // Dated list subset (remove unnecessary parentheses)
    final normalized = _normalize(date);
    final dayList = _objectivesByDate[normalized];
    if (dayList != null) {
      reorderSubset(
        dayList,
        (o) => o.categoryIds.isNotEmpty && o.categoryIds.first == categoryId,
      );
    }

    await persistObjectives();
    notifyListeners();
  }

  List<String> getCategoryIdsInUse(DateTime date) {
    final set = <String>{};
    for (final o in getObjectivesForDay(date)) {
      set.add(o.categoryIds.isNotEmpty ? o.categoryIds.first : 'Uncategorized');
    }
    return set.toList();
  }

  Future<void> reorderCategories(List<String> orderedIds) async {
    final snapshot = Map<String, Category>.from(_categories);

    final known = snapshot.keys.toSet();
    final filtered = orderedIds.where(known.contains).toList();
    final remainder = snapshot.keys.where((id) => !filtered.contains(id));

    final newOrder = <String>[...filtered, ...remainder];

    _categories
      ..clear()
      ..addEntries(newOrder.map((id) => MapEntry(id, snapshot[id]!)));

    await _hiveService.saveCategories(_categories);
    notifyListeners();
  }
}
