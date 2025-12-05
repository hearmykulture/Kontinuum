import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';

import 'package:kontinuum/data/hive_service.dart';
import 'package:kontinuum/models/budget_models_hive.dart';
import 'package:kontinuum/models/budget_transaction.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/diet_models.dart';
import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/models/merchant_override.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/project_model.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/models/streak_models.dart';
import 'package:kontinuum/models/workout_models.dart'
    show Routine, Workout, Exercise, WorkoutLog, WorkoutSchedule;
import 'package:kontinuum/services/budget_boxes.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/services/workout_boxes.dart';

/// Clears **all** app boxes using the canonical names from [HiveService].
/// - Uses typed opens for typed boxes to avoid "box open with different type".
/// - Logs each clear and reports counts (before → after).
class ResetService {
  const ResetService();

  static final List<String> _allBoxNames = <String>[
    // progress
    HiveService.skillBoxName,
    HiveService.statBoxName,
    HiveService.categoryBoxName,
    HiveService.staticObjectivesBoxName,
    HiveService.objectivesByDateBoxName,
    HiveService.statHistoryBoxName,
    HiveService.milestoneBoxName,
    HiveService.activeMissionsBoxName,
    HiveService.missionMetaBoxName,
    // streaks/meta
    'objectiveStreaks',
    'categoryStreaks',
    'dayStreak',
    'bonusLedger',
    'momentumWallet',
    'skipReceipts',
    'appMeta',
    // workouts
    WorkoutBoxes.routinesBoxName,
    WorkoutBoxes.legacyRoutinesBoxName,
    WorkoutBoxes.workoutsBoxName,
    WorkoutBoxes.exerciseBoxName,
    WorkoutBoxes.logsBoxName,
    WorkoutBoxes.legacyLogsBoxName,
    WorkoutBoxes.schedulesBoxName,
    WorkoutBoxes.restOverridesBoxName,
    SessionPersistenceService.boxName,
    // budgets/transactions
    HiveService.budgetsBoxName,
    BudgetBoxes.txBoxName,
    BudgetBoxes.overrideBoxName,
    BudgetBoxes.metaBoxName,
    // diet + fitness
    'dietEntries',
    'dietGoal',
    'dietFoods',
    'dietWeights',
    'fitnessProfile',
    // projects/notebooks (if persisted in future)
    'projects',
    'notebooks',
  ];

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

  Future<void> _clearUntypedBox<T>(String name) async {
    try {
      final Box<T> box = Hive.isBoxOpen(name)
          ? Hive.box<T>(name)
          : await Hive.openBox<T>(name);
      final before = box.length;
      await box.clear();
      await box.flush();
      debugPrint('🧹 Cleared $name ($before → 0)');
    } on HiveError {
      // If already open with a different generic type, fall back to raw access.
      final dynamic raw = Hive.box<dynamic>(name);
      if (raw is Box) {
        final before = raw.length;
        await raw.clear();
        await raw.flush();
        debugPrint('🧹 Cleared $name ($before → 0) [raw]');
        return;
      }
      rethrow;
    }
  }

  /// Clears skills, stats, categories, objectives, history, milestones,
  /// missions, and mission meta.
  Future<void> clearAllData({bool deleteFromDisk = false}) async {
    await clearProgressData();
    await clearStreakData();
    await clearWorkoutData();
    await clearSessionDrafts();
    await clearBudgetData();
    await clearDietData();
    await clearFitnessProfile();
    await clearProjectsAndNotebooks();
    if (deleteFromDisk) {
      await _deleteBoxesFromDisk();
    }
    debugPrint('✅ All Hive data cleared successfully.');
  }

  Future<void> clearProgressData() async {
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
      await _clearUntypedBox<dynamic>(HiveService.objectivesByDateBoxName);
      await _clearUntypedBox<dynamic>(HiveService.missionMetaBoxName);

    } catch (e) {
      debugPrint('❌ Error clearing progress data: $e');
      rethrow;
    }
  }

  Future<void> clearStreakData() async {
    try {
      await _clearTypedBox<ObjectiveStreak>('objectiveStreaks');
      await _clearTypedBox<CategoryStreak>('categoryStreaks');
      await _clearTypedBox<DayStreak>('dayStreak');
      await _clearTypedBox<BonusLedgerDay>('bonusLedger');
      await _clearTypedBox<MomentumWallet>('momentumWallet');
      await _clearTypedBox<SkipReceipt>('skipReceipts');
      await _clearUntypedBox<dynamic>('appMeta');
    } catch (e) {
      debugPrint('❌ Error clearing streak data: $e');
      rethrow;
    }
  }

  Future<void> clearWorkoutData() async {
    try {
      await _clearTypedBox<Routine>(WorkoutBoxes.routinesBoxName);
      await _clearTypedBox<Routine>(WorkoutBoxes.legacyRoutinesBoxName);
      await _clearTypedBox<Workout>(WorkoutBoxes.workoutsBoxName);
      await _clearTypedBox<Exercise>(WorkoutBoxes.exerciseBoxName);
      await _clearTypedBox<WorkoutLog>(WorkoutBoxes.logsBoxName);
      await _clearTypedBox<WorkoutLog>(WorkoutBoxes.legacyLogsBoxName);
      await _clearTypedBox<WorkoutSchedule>(WorkoutBoxes.schedulesBoxName);
      await _clearUntypedBox<Map<String, dynamic>>(
          WorkoutBoxes.restOverridesBoxName);
    } catch (e) {
      debugPrint('❌ Error clearing workout data: $e');
      rethrow;
    }
  }

  Future<void> clearSessionDrafts() async {
    try {
      await _clearUntypedBox<dynamic>(SessionPersistenceService.boxName);
    } catch (e) {
      debugPrint('❌ Error clearing session drafts: $e');
      rethrow;
    }
  }

  Future<void> clearBudgetData() async {
    try {
      await _clearTypedBox<BudgetHive>(HiveService.budgetsBoxName);
      await _clearTypedBox<BudgetTransaction>(BudgetBoxes.txBoxName);
      await _clearTypedBox<MerchantOverride>(BudgetBoxes.overrideBoxName);
      await _clearUntypedBox<dynamic>(BudgetBoxes.metaBoxName);
    } catch (e) {
      debugPrint('❌ Error clearing budget data: $e');
      rethrow;
    }
  }

  Future<void> clearDietData() async {
    try {
      await _clearTypedBox<DietEntry>('dietEntries');
      await _clearTypedBox<DietGoal>('dietGoal');
      await _clearUntypedBox<dynamic>('dietFoods');
      await _clearUntypedBox<dynamic>('dietWeights');
    } catch (e) {
      debugPrint('❌ Error clearing diet data: $e');
      rethrow;
    }
  }

  Future<void> clearFitnessProfile() async {
    try {
      await _clearTypedBox<FitnessNutritionProfile>('fitnessProfile');
    } catch (e) {
      debugPrint('❌ Error clearing fitness profile: $e');
      rethrow;
    }
  }

  Future<void> clearProjectsAndNotebooks() async {
    // Currently in-memory only, but clear persisted boxes if they ever exist.
    try {
      await _clearTypedBox<Project>('projects');
    } catch (_) {}
    try {
      await _clearTypedBox<Notebook>('notebooks');
    } catch (_) {}
  }

  Future<void> _deleteBoxesFromDisk() async {
    for (final name in _allBoxNames) {
      String? path;
      try {
        if (Hive.isBoxOpen(name)) {
          final box = Hive.box<dynamic>(name);
          path = box.path;
          await box.close();
        }
        await Hive.deleteBoxFromDisk(name);
        if (path != null) {
          final bak = File('$path.bak');
          if (await bak.exists()) {
            await bak.delete();
          }
        }
        debugPrint('🗑️ Deleted box files for $name');
      } catch (e) {
        debugPrint('⚠️ Skipped deleting $name: $e');
        continue;
      }
    }
  }
}
