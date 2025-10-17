import 'package:hive/hive.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/models/mission.dart';

class HiveService {
  // Box names (single source of truth)
  static const String skillBoxName = 'skillsBox';
  static const String statBoxName = 'statsBox';
  static const String categoryBoxName = 'categoriesBox';
  static const String staticObjectivesBoxName = 'staticObjectivesBox';
  static const String objectivesByDateBoxName =
      'objectivesByDateBox'; // untyped
  static const String statHistoryBoxName = 'statHistoryBox';
  static const String milestoneBoxName = 'milestoneBox';
  static const String activeMissionsBoxName = 'activeMissionsBox';

  // ---------- Helpers ----------

  /// Open a typed box if needed, otherwise return the already-opened box.
  Future<Box<T>> _openBoxIfNeeded<T>(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
    return Hive.openBox<T>(name);
  }

  /// Open an **untyped** box (used for objectivesByDate).
  Future<Box> _openUntypedBoxIfNeeded(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box(name);
    return Hive.openBox(name);
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
    return {for (final s in box.values) s.id: s};
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

  // ---------- Objectives by Date (UNtyped box) ----------
  // Keys: String (ISO day string for now)
  // Value: List<Objective>

  Future<void> saveObjectivesByDate(Map<DateTime, List<Objective>> data) async {
    final box = await _openUntypedBoxIfNeeded(objectivesByDateBoxName);
    await box.clear();

    // Store as: { '2025-10-16T00:00:00.000': <List<Objective>> }
    final map = <String, List<Objective>>{
      for (final e in data.entries) e.key.toIso8601String(): e.value,
    };

    await box.putAll(map);
  }

  Future<Map<DateTime, List<Objective>>> loadObjectivesByDate() async {
    final box = await _openUntypedBoxIfNeeded(objectivesByDateBoxName);

    final out = <DateTime, List<Objective>>{};
    // Cast keys to String and values to List<Objective>
    for (final key in box.keys.cast<String>()) {
      final raw = box.get(key);
      final list = (raw as List?)?.cast<Objective>() ?? const <Objective>[];
      out[DateTime.parse(key)] = list;
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
}
