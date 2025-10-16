import 'package:hive/hive.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/models/mission.dart';

class HiveService {
  static const String skillBoxName = 'skillsBox';
  static const String statBoxName = 'statsBox';
  static const String categoryBoxName = 'categoriesBox';
  static const String staticObjectivesBoxName = 'staticObjectivesBox';
  static const String objectivesByDateBoxName = 'objectivesByDateBox';
  static const String statHistoryBoxName = 'statHistoryBox';
  static const String milestoneBoxName = 'milestoneBox';

  // ✅ Skills
  Future<void> saveSkills(List<Skill> skills) async {
    final box = Hive.box<Skill>(skillBoxName);
    await box.clear();
    for (final skill in skills) {
      await box.put(skill.id, skill);
    }
  }

  Future<List<Skill>> loadSkills() async {
    final box = Hive.box<Skill>(skillBoxName);
    return box.values.toList();
  }

  // ✅ Stats
  Future<void> saveStats(Map<String, Stat> stats) async {
    final box = Hive.box<Stat>(statBoxName);
    await box.clear();
    for (final stat in stats.values) {
      await box.put(stat.id, stat);
    }
  }

  Future<Map<String, Stat>> loadStats() async {
    final box = Hive.box<Stat>(statBoxName);
    return {for (var stat in box.values) stat.id: stat};
  }

  // ✅ Categories
  Future<void> saveCategories(Map<String, Category> categories) async {
    final box = Hive.box<Category>(categoryBoxName);
    await box.clear();
    for (final cat in categories.values) {
      await box.put(cat.id, cat);
    }
  }

  Future<Map<String, Category>> loadCategories() async {
    final box = Hive.box<Category>(categoryBoxName);
    return {for (var cat in box.values) cat.id: cat};
  }

  // ✅ Static Objectives
  Future<void> saveStaticObjectives(List<Objective> objectives) async {
    final box = Hive.box<Objective>(staticObjectivesBoxName);
    await box.clear();
    for (final obj in objectives) {
      await box.put(obj.id, obj);
    }
  }

  Future<List<Objective>> loadStaticObjectives() async {
    final box = Hive.box<Objective>(staticObjectivesBoxName);
    return box.values.toList();
  }

  // ✅ Daily Objectives by Date
  Future<void> saveObjectivesByDate(Map<DateTime, List<Objective>> data) async {
    final box = Hive.box(objectivesByDateBoxName);
    await box.clear();
    for (final entry in data.entries) {
      final key = entry.key.toIso8601String();
      await box.put(key, entry.value);
    }
  }

  Future<Map<DateTime, List<Objective>>> loadObjectivesByDate() async {
    final box = Hive.box(objectivesByDateBoxName);
    return {
      for (var key in box.keys)
        DateTime.parse(key): List<Objective>.from(box.get(key) ?? []),
    };
  }

  // ✅ Stat History
  Future<void> saveStatHistory(List<StatHistoryEntry> entries) async {
    final box = Hive.box<StatHistoryEntry>(statHistoryBoxName);
    await box.clear();
    for (int i = 0; i < entries.length; i++) {
      await box.put(i, entries[i]);
    }
  }

  Future<List<StatHistoryEntry>> loadStatHistory() async {
    final box = Hive.box<StatHistoryEntry>(statHistoryBoxName);
    return box.values.toList();
  }

  // ✅ Milestones
  Future<void> saveMilestones(Map<String, Milestone> milestones) async {
    final box = Hive.box<Milestone>(milestoneBoxName);
    await box.clear();
    for (final entry in milestones.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  Future<Map<String, Milestone>> loadMilestones() async {
    final box = Hive.box<Milestone>(milestoneBoxName);
    final Map<String, Milestone> result = {};
    for (final key in box.keys) {
      final milestone = box.get(key);
      if (milestone != null) {
        result[key.toString()] = milestone;
      }
    }
    return result;
  }

  static const String activeMissionsBoxName = 'activeMissionsBox';

  Future<void> saveActiveMissions(List<Mission> missions) async {
    final box = Hive.box<Mission>(activeMissionsBoxName);
    await box.clear();
    for (int i = 0; i < missions.length; i++) {
      await box.put(missions[i].id, missions[i]);
    }
  }

  Future<List<Mission>> loadActiveMissions() async {
    final box = Hive.box<Mission>(activeMissionsBoxName);
    return box.values.toList();
  }
}
