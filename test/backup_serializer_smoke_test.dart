import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:kontinuum/data/hive_service.dart';
import 'package:kontinuum/data/reset_service.dart';
import 'package:kontinuum/models/budget_models_hive.dart';
import 'package:kontinuum/models/budget_transaction.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/diet_models.dart';
import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/models/merchant_override.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/session_state.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/models/streak_models.dart';
import 'package:kontinuum/services/backup/backup_manifest.dart';
import 'package:kontinuum/services/backup/backup_serializer.dart';
import 'package:kontinuum/services/budget_boxes.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/services/workout_boxes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('backup_test');
    Hive.init(tmp.path);
    _registerAdapters();
    await WorkoutBoxes.init();
    await SessionPersistenceService.init();
    await BudgetBoxes.init();
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  test('serializer exports and restores core progress data', () async {
    final reset = const ResetService();
    final serializer = BackupSerializer(resetService: reset);

    final skillBox = await Hive.openBox<Skill>(HiveService.skillBoxName);
    final statBox = await Hive.openBox<Stat>(HiveService.statBoxName);
    final catBox = await Hive.openBox<Category>(HiveService.categoryBoxName);
    final objBox = await Hive.openBox<Objective>(HiveService.staticObjectivesBoxName);
    final statHistoryBox =
        await Hive.openBox<StatHistoryEntry>(HiveService.statHistoryBoxName);
    final milestoneBox =
        await Hive.openBox<Milestone>(HiveService.milestoneBoxName);
    final missionBox =
        await Hive.openBox<Mission>(HiveService.activeMissionsBoxName);
    final objectivesByDateBox =
        await Hive.openBox<dynamic>(HiveService.objectivesByDateBoxName);

    final stat = Stat(
      id: 'stat-1',
      label: 'Push-ups',
      averageMinutesPerUnit: 1,
      repsForMastery: 100,
      xp: 10,
    );
    final skill = Skill(
      id: 'skill-1',
      label: 'Strength',
      categoryId: 'cat-1',
      xp: 20,
      stats: [stat],
    );
    final category = Category(
      id: 'cat-1',
      name: 'Health',
      xp: 50,
      skills: [skill],
    );
    final objective = Objective(
      id: 'obj-1',
      title: 'Do push-ups',
      type: ObjectiveType.standard,
      categoryIds: const ['cat-1'],
      statIds: const ['stat-1'],
      targetAmount: 1,
      xpReward: 10,
      activeDays: const {1: true, 2: true, 3: true, 4: true, 5: true},
    );
    final history = StatHistoryEntry(
      statId: 'stat-1',
      date: DateTime.utc(2024, 1, 1),
      amount: 5,
    );
    final milestone = Milestone(
      statId: 'stat-1',
      thresholds: const [1, 5, 10],
    );
    final mission = Mission(
      id: 'mission-1',
      title: 'Start mission',
      description: 'Test mission',
      categoryIds: const ['cat-1'],
      statIds: const ['stat-1'],
      xpReward: 15,
    );

    await statBox.put(stat.id, stat);
    await skillBox.put(skill.id, skill);
    await catBox.put(category.id, category);
    await objBox.put(objective.id, objective);
    await statHistoryBox.put(0, history);
    await milestoneBox.put(milestone.statId, milestone);
    await missionBox.put(mission.id, mission);
    await objectivesByDateBox.put(
      '2024-01-01',
      <Objective>[objective],
    );

    final sections = await serializer.exportAll();
    final manifest = BackupManifest.empty(schemaVersion: 1)
        .copyWith(sections: sections);

    // wipe and restore
    await reset.clearAllData();
    await serializer.importAll(manifest, resetFirst: false);

    expect(skillBox.get(skill.id)?.label, equals('Strength'));
    expect(statBox.get(stat.id)?.xp, equals(10));
    expect(catBox.get(category.id)?.name, equals('Health'));
    expect(objBox.get(objective.id)?.title, equals('Do push-ups'));
    expect(statHistoryBox.length, equals(1));
    expect(missionBox.length, equals(1));
    expect(objectivesByDateBox.length, equals(1));
  });
}

void _registerAdapters() {
  // progress / missions
  Hive.registerAdapter(StatAdapter());
  Hive.registerAdapter(SkillAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(ObjectiveTypeAdapter());
  Hive.registerAdapter(ObjectiveAdapter());
  Hive.registerAdapter(StatHistoryEntryAdapter());
  Hive.registerAdapter(MilestoneAdapter());
  Hive.registerAdapter(MissionRarityAdapter());
  Hive.registerAdapter(MissionAdapter());

  // streaks
  Hive.registerAdapter(ObjectiveStreakAdapter());
  Hive.registerAdapter(CategoryStreakAdapter());
  Hive.registerAdapter(DayStreakAdapter());
  Hive.registerAdapter(BonusLedgerDayAdapter());
  Hive.registerAdapter(MomentumWalletAdapter());
  Hive.registerAdapter(SkipReceiptAdapter());

  // budgets
  Hive.registerAdapter(BudgetHiveAdapter());
  Hive.registerAdapter(BudgetTransactionAdapter());
  Hive.registerAdapter(MerchantOverrideAdapter());

  // diet (use test-safe typeIds within 0–223)
  Hive.registerAdapter(MealSlotAdapterTest());
  Hive.registerAdapter(DietEntryAdapterTest());
  Hive.registerAdapter(DietGoalAdapterTest());
  Hive.registerAdapter(DietFoodAdapterTest());

  // fitness profile
  Hive.registerAdapter(TrainingGoalAdapter());
  Hive.registerAdapter(TrainingEnvironmentAdapter());
  Hive.registerAdapter(DietGoalKindAdapter());
  Hive.registerAdapter(TrackingStyleAdapter());
  Hive.registerAdapter(ExperienceLevelAdapter());
  Hive.registerAdapter(FitnessNutritionProfileAdapter());

  // workouts (WorkoutBoxes.init registers exercise/workout adapters)
  Hive.registerAdapter(WorkoutSessionStateAdapter());
  Hive.registerAdapter(SavedSetDataAdapter());
}

// Lightweight adapters with typeIds inside Hive's allowed range for tests.
class MealSlotAdapterTest extends MealSlotAdapter {
  @override
  int get typeId => 180;
}

class DietEntryAdapterTest extends DietEntryAdapter {
  @override
  int get typeId => 181;
}

class DietGoalAdapterTest extends DietGoalAdapter {
  @override
  int get typeId => 182;
}

class DietFoodAdapterTest extends DietFoodAdapter {
  @override
  int get typeId => 183;
}
