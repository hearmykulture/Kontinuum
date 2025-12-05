import 'package:hive/hive.dart';
import 'package:kontinuum/models/budget_models_hive.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/utils/date_keys.dart';

class HiveService {
  // ---------- Box names ----------
  static const String skillBoxName = 'skillsBox';
  static const String statBoxName = 'statsBox';
  static const String categoryBoxName = 'categoriesBox';
  static const String staticObjectivesBoxName = 'staticObjectivesBox';

  /// Keys = local 'yyyy-MM-dd' (via DateKeys.ymd)
  /// Values = List<Objective>
  static const String objectivesByDateBoxName = 'objectivesByDateBox';

  static const String statHistoryBoxName = 'statHistoryBox';
  static const String milestoneBoxName = 'milestoneBox';
  static const String activeMissionsBoxName = 'activeMissionsBox';
  static const String missionMetaBoxName = 'missionMetaBox';
  static const String budgetsBoxName = 'budgetsBox';

  // ---------- Legacy key parser (defensive) ----------
  // Accepts either "YYYY-MM-DD" or a full ISO, normalizes to local date.
  static DateTime _parseDayKey(String key) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(key);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    // Fallback: parse and clamp
    final dt = DateTime.parse(key);
    return DateKeys.dateOnly(dt);
  }

  // ---------- open helpers ----------
  Future<Box<T>> _openBoxIfNeeded<T>(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
    return Hive.openBox<T>(name);
  }

  Future<Box<dynamic>> _openUntypedBoxIfNeeded(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(name);
  }

  // ---------- Skills ----------
  Future<void> saveSkills(List<Skill> skills) async {
    final box = await _openBoxIfNeeded<Skill>(skillBoxName);
    await box.clear();
    await box.putAll({for (final s in skills) s.id: s});
  }

  Future<List<Skill>> loadSkills() async {
    final box = await _openBoxIfNeeded<Skill>(skillBoxName);
    return box.values.toList(growable: false);
  }

  // ---------- Stats ----------
  Future<void> saveStats(Map<String, Stat> stats) async {
    final box = await _openBoxIfNeeded<Stat>(statBoxName);
    await box.clear();
    await box.putAll(stats);
  }

  Future<Map<String, Stat>> loadStats() async {
    final box = await _openBoxIfNeeded<Stat>(statBoxName);
    final result = <String, Stat>{};
    for (final s in box.values) {
      result[s.id] = s;
    }
    return result;
  }

  // ---------- Categories ----------
  Future<void> saveCategories(Map<String, Category> categories) async {
    final box = await _openBoxIfNeeded<Category>(categoryBoxName);
    await box.clear();
    await box.putAll(categories);
  }

  Future<Map<String, Category>> loadCategories() async {
    final box = await _openBoxIfNeeded<Category>(categoryBoxName);
    return {for (final c in box.values) c.id: c};
  }

  // ---------- Static Objectives ----------
  Future<void> saveStaticObjectives(List<Objective> objectives) async {
    final box = await _openBoxIfNeeded<Objective>(staticObjectivesBoxName);
    await box.clear();
    await box.putAll({for (final o in objectives) o.id: o});
  }

  Future<List<Objective>> loadStaticObjectives() async {
    final box = await _openBoxIfNeeded<Objective>(staticObjectivesBoxName);
    return box.values.toList(growable: false);
  }

  // ---------- Objectives by Date (UNtyped) ----------
  /// Save map<localDate,List<Objective>> with normalized keys.
  Future<void> saveObjectivesByDate(
    Map<DateTime, List<Objective>> data,
  ) async {
    final box = await _openUntypedBoxIfNeeded(objectivesByDateBoxName);
    await box.clear();

    final map = <String, List<Objective>>{
      for (final e in data.entries)
        DateKeys.ymd(DateKeys.dateOnly(e.key)): e.value,
    };

    await box.putAll(map);
  }

  /// Load and normalize legacy ISO keys to 'yyyy-MM-dd'.
  Future<Map<DateTime, List<Objective>>> loadObjectivesByDate() async {
    final box = await _openUntypedBoxIfNeeded(objectivesByDateBoxName);
    final out = <DateTime, List<Objective>>{};
    var changed = false;

    for (final rawKey in box.keys) {
      if (rawKey is! String) continue;
      final day = _parseDayKey(rawKey);
      final list =
          (box.get(rawKey) as List?)?.cast<Objective>() ?? const <Objective>[];
      out[day] = list;

      final desiredKey = DateKeys.ymd(day);
      if (rawKey != desiredKey) {
        await box.put(desiredKey, list);
        await box.delete(rawKey);
        changed = true;
      }
    }

    if (changed) {
      await box.flush();
    }

    return out;
  }

  // ---------- Stat History ----------
  Future<void> saveStatHistory(List<StatHistoryEntry> entries) async {
    final box = await _openBoxIfNeeded<StatHistoryEntry>(statHistoryBoxName);
    await box.clear();
    await box.putAll({for (var i = 0; i < entries.length; i++) i: entries[i]});
  }

  Future<List<StatHistoryEntry>> loadStatHistory() async {
    final box = await _openBoxIfNeeded<StatHistoryEntry>(statHistoryBoxName);
    return box.values.toList(growable: false);
  }

  // ---------- Milestones ----------
  Future<void> saveMilestones(Map<String, Milestone> milestones) async {
    final box = await _openBoxIfNeeded<Milestone>(milestoneBoxName);
    await box.clear();
    await box.putAll(milestones);
  }

  Future<Map<String, Milestone>> loadMilestones() async {
    final box = await _openBoxIfNeeded<Milestone>(milestoneBoxName);
    final result = <String, Milestone>{};
    for (final key in box.keys.cast<String>()) {
      final m = box.get(key);
      if (m != null) result[key] = m;
    }
    return result;
  }

  // ---------- Active Missions ----------
  Future<void> saveActiveMissions(List<Mission> missions) async {
    final box = await _openBoxIfNeeded<Mission>(activeMissionsBoxName);
    await box.clear();
    await box.putAll({for (final m in missions) m.id: m});
  }

  Future<List<Mission>> loadActiveMissions() async {
    final box = await _openBoxIfNeeded<Mission>(activeMissionsBoxName);
    return box.values.toList(growable: false);
  }

  // ---------- Budgets ----------
  Future<void> saveBudgets(List<BudgetHive> budgets) async {
    final box = await _openBoxIfNeeded<BudgetHive>(budgetsBoxName);
    await box.clear();
    await box.putAll({for (final b in budgets) b.id: b});
  }

  Future<List<BudgetHive>> loadBudgets() async {
    final box = await _openBoxIfNeeded<BudgetHive>(budgetsBoxName);
    return box.values.toList(growable: false);
  }
}
