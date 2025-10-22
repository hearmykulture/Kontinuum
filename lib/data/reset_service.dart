import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';

import 'package:kontinuum/data/hive_service.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/stat_history_entry.dart';

/// Clears **all** app boxes using the canonical names from [HiveService].
/// - Uses typed opens for typed boxes to avoid "box open with different type".
/// - Logs each clear and reports counts (before → after).
class ResetService {
  const ResetService();

  Future<void> _clearTypedBox<T>(String name) async {
    Box<T> box;
    if (Hive.isBoxOpen(name)) {
      box = Hive.box<T>(name);
    } else {
      box = await Hive.openBox<T>(name);
    }
    final before = box.length;
    await box.clear();
    await box.flush();
    debugPrint('🧹 Cleared $name ($before → 0)');
  }

  Future<void> _clearUntypedBox(String name) async {
    Box<dynamic> box;
    if (Hive.isBoxOpen(name)) {
      box = Hive.box<dynamic>(name);
    } else {
      box = await Hive.openBox<dynamic>(name);
    }
    final before = box.length;
    await box.clear();
    await box.flush();
    debugPrint('🧹 Cleared $name ($before → 0)');
  }

  /// Clears every box the app owns (skills, stats, categories, objectives,
  /// history, milestones, missions, and mission meta).
  Future<void> clearAllData() async {
    try {
      // Typed boxes
      await _clearTypedBox<Skill>(HiveService.skillBoxName);
      await _clearTypedBox<Stat>(HiveService.statBoxName);
      await _clearTypedBox<Category>(HiveService.categoryBoxName);
      await _clearTypedBox<Objective>(HiveService.staticObjectivesBoxName);
      await _clearTypedBox<StatHistoryEntry>(HiveService.statHistoryBoxName);
      await _clearTypedBox<Milestone>(HiveService.milestoneBoxName);
      await _clearTypedBox<Mission>(HiveService.activeMissionsBoxName);

      // Untyped / mixed structures
      await _clearUntypedBox(HiveService.objectivesByDateBoxName);
      await _clearUntypedBox(HiveService.missionMetaBoxName);

      debugPrint('✅ All Hive data cleared successfully.');
    } catch (e) {
      debugPrint('❌ Error clearing Hive data: $e');
      rethrow;
    }
  }
}
