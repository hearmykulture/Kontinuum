import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/models/streak_models.dart';
import 'package:kontinuum/models/workout_models.dart'
    show Routine, Workout, Exercise, WorkoutLog, WorkoutSchedule;
import 'package:kontinuum/services/backup/backup_codec.dart';
import 'package:kontinuum/services/backup/backup_manifest.dart';
import 'package:kontinuum/services/backup/data_backup_service.dart';
import 'package:kontinuum/services/budget_boxes.dart';
import 'package:kontinuum/services/session_persistence_service.dart';
import 'package:kontinuum/services/workout_boxes.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class BackupSerializer {
  BackupSerializer({ResetService? resetService})
      : _resetService = resetService ?? const ResetService();

  final ResetService _resetService;
  final Map<String, int> _importedCounts = <String, int>{};

  // ───────────────────────────────────────────────────────────────────────────
  // Export
  // ───────────────────────────────────────────────────────────────────────────

  Future<Map<String, BackupSection>> exportAll({
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  }) async {
    final sections = <String, BackupSection>{};

    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.progress] = await _exportProgress(onProgress);
    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.missions] = await _exportMissions(onProgress);
    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.streaks] = await _exportStreaks(onProgress);
    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.workouts] = await _exportWorkouts(onProgress);
    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.sessions] = await _exportSessions(onProgress);
    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.budgets] = await _exportBudgets(onProgress);
    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.transactions] =
        await _exportTransactions(onProgress);
    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.diet] = await _exportDiet(onProgress);
    cancellationToken?.throwIfCancelled();
    sections[BackupModuleKeys.fitnessProfile] =
        await _exportFitnessProfile(onProgress);
    sections[BackupModuleKeys.projects] =
        BackupSection.empty(BackupModuleKeys.projects);
    sections[BackupModuleKeys.notebooks] =
        BackupSection.empty(BackupModuleKeys.notebooks);
    sections[BackupModuleKeys.meta] = await _exportMeta();

    return sections;
  }

  Future<BackupSection> _exportProgress(
      void Function(String stage)? onProgress) async {
    onProgress?.call('progress');
    final boxes = <BackupBoxDump>[];
    final counts = <String, int>{};

    final skills = await _dumpTypedBox<Skill>(HiveService.skillBoxName);
    boxes.add(skills);
    counts[HiveService.skillBoxName] = skills.entries.length;

    final stats = await _dumpTypedBox<Stat>(HiveService.statBoxName);
    boxes.add(stats);
    counts[HiveService.statBoxName] = stats.entries.length;

    final categories =
        await _dumpTypedBox<Category>(HiveService.categoryBoxName);
    boxes.add(categories);
    counts[HiveService.categoryBoxName] = categories.entries.length;

    final staticObjectives =
        await _dumpTypedBox<Objective>(HiveService.staticObjectivesBoxName);
    boxes.add(staticObjectives);
    counts[HiveService.staticObjectivesBoxName] =
        staticObjectives.entries.length;

    final objectivesByDate =
        await _dumpUntypedBox<dynamic>(HiveService.objectivesByDateBoxName);
    boxes.add(objectivesByDate);
    counts[HiveService.objectivesByDateBoxName] =
        objectivesByDate.entries.length;

    final statHistory =
        await _dumpTypedBox<StatHistoryEntry>(HiveService.statHistoryBoxName);
    boxes.add(statHistory);
    counts[HiveService.statHistoryBoxName] = statHistory.entries.length;

    final milestones =
        await _dumpTypedBox<Milestone>(HiveService.milestoneBoxName);
    boxes.add(milestones);
    counts[HiveService.milestoneBoxName] = milestones.entries.length;

    return BackupSection(
      key: BackupModuleKeys.progress,
      moduleVersion: 1,
      counts: counts,
      payload: {
        'boxes': boxes.map((b) => b.toJson()).toList(),
      },
    );
  }

  Future<BackupSection> _exportMissions(
      void Function(String stage)? onProgress) async {
    onProgress?.call('missions');
    final boxes = <BackupBoxDump>[];
    final counts = <String, int>{};

    final missions =
        await _dumpTypedBox<Mission>(HiveService.activeMissionsBoxName);
    boxes.add(missions);
    counts[HiveService.activeMissionsBoxName] = missions.entries.length;

    final meta = await _dumpUntypedBox<dynamic>(HiveService.missionMetaBoxName);
    boxes.add(meta);
    counts[HiveService.missionMetaBoxName] = meta.entries.length;

    return BackupSection(
      key: BackupModuleKeys.missions,
      moduleVersion: 1,
      counts: counts,
      payload: {'boxes': boxes.map((b) => b.toJson()).toList()},
    );
  }

  Future<BackupSection> _exportStreaks(
      void Function(String stage)? onProgress) async {
    onProgress?.call('streaks');
    final boxes = <BackupBoxDump>[];
    final counts = <String, int>{};

    final objectiveStreaks =
        await _dumpTypedBox<ObjectiveStreak>('objectiveStreaks');
    boxes.add(objectiveStreaks);
    counts['objectiveStreaks'] = objectiveStreaks.entries.length;

    final categoryStreaks =
        await _dumpTypedBox<CategoryStreak>('categoryStreaks');
    boxes.add(categoryStreaks);
    counts['categoryStreaks'] = categoryStreaks.entries.length;

    final dayStreak = await _dumpTypedBox<DayStreak>('dayStreak');
    boxes.add(dayStreak);
    counts['dayStreak'] = dayStreak.entries.length;

    final bonusLedger = await _dumpTypedBox<BonusLedgerDay>('bonusLedger');
    boxes.add(bonusLedger);
    counts['bonusLedger'] = bonusLedger.entries.length;

    final wallet = await _dumpTypedBox<MomentumWallet>('momentumWallet');
    boxes.add(wallet);
    counts['momentumWallet'] = wallet.entries.length;

    final skip = await _dumpTypedBox<SkipReceipt>('skipReceipts');
    boxes.add(skip);
    counts['skipReceipts'] = skip.entries.length;

    final appMeta = await _dumpUntypedBox<dynamic>('appMeta');
    boxes.add(appMeta);
    counts['appMeta'] = appMeta.entries.length;

    return BackupSection(
      key: BackupModuleKeys.streaks,
      moduleVersion: 1,
      counts: counts,
      payload: {'boxes': boxes.map((b) => b.toJson()).toList()},
    );
  }

  Future<BackupSection> _exportWorkouts(
      void Function(String stage)? onProgress) async {
    onProgress?.call('workouts');
    final boxes = <BackupBoxDump>[];
    final counts = <String, int>{};

    final routines =
        await _dumpTypedBox<Routine>(WorkoutBoxes.routinesBoxName);
    boxes.add(routines);
    counts[WorkoutBoxes.routinesBoxName] = routines.entries.length;

    final routinesLegacy =
        await _dumpTypedBox<Routine>(WorkoutBoxes.legacyRoutinesBoxName);
    boxes.add(routinesLegacy);
    counts[WorkoutBoxes.legacyRoutinesBoxName] = routinesLegacy.entries.length;

    final workouts = await _dumpTypedBox<Workout>(WorkoutBoxes.workoutsBoxName);
    boxes.add(workouts);
    counts[WorkoutBoxes.workoutsBoxName] = workouts.entries.length;

    final exercises =
        await _dumpTypedBox<Exercise>(WorkoutBoxes.exerciseBoxName);
    boxes.add(exercises);
    counts[WorkoutBoxes.exerciseBoxName] = exercises.entries.length;

    final logs = await _dumpTypedBox<WorkoutLog>(WorkoutBoxes.logsBoxName);
    boxes.add(logs);
    counts[WorkoutBoxes.logsBoxName] = logs.entries.length;

    final legacyLogs =
        await _dumpTypedBox<WorkoutLog>(WorkoutBoxes.legacyLogsBoxName);
    boxes.add(legacyLogs);
    counts[WorkoutBoxes.legacyLogsBoxName] = legacyLogs.entries.length;

    final schedules =
        await _dumpTypedBox<WorkoutSchedule>(WorkoutBoxes.schedulesBoxName);
    boxes.add(schedules);
    counts[WorkoutBoxes.schedulesBoxName] = schedules.entries.length;

    final overrides = await _dumpUntypedBox<Map<String, dynamic>>(
        WorkoutBoxes.restOverridesBoxName);
    boxes.add(overrides);
    counts[WorkoutBoxes.restOverridesBoxName] = overrides.entries.length;

    return BackupSection(
      key: BackupModuleKeys.workouts,
      moduleVersion: 1,
      counts: counts,
      payload: {'boxes': boxes.map((b) => b.toJson()).toList()},
    );
  }

  Future<BackupSection> _exportSessions(
      void Function(String stage)? onProgress) async {
    onProgress?.call('sessions');
    final dump =
        await _dumpUntypedBox<dynamic>(SessionPersistenceService.boxName);
    return BackupSection(
      key: BackupModuleKeys.sessions,
      moduleVersion: 1,
      counts: {SessionPersistenceService.boxName: dump.entries.length},
      payload: {'boxes': [dump.toJson()]},
    );
  }

  Future<BackupSection> _exportBudgets(
      void Function(String stage)? onProgress) async {
    onProgress?.call('budgets');
    final budgets = await _dumpTypedBox<BudgetHive>(HiveService.budgetsBoxName);
    return BackupSection(
      key: BackupModuleKeys.budgets,
      moduleVersion: 1,
      counts: {HiveService.budgetsBoxName: budgets.entries.length},
      payload: {'boxes': [budgets.toJson()]},
    );
  }

  Future<BackupSection> _exportTransactions(
      void Function(String stage)? onProgress) async {
    onProgress?.call('transactions');
    final boxes = <BackupBoxDump>[];
    final counts = <String, int>{};

    final tx = await _dumpTypedBox<BudgetTransaction>(BudgetBoxes.txBoxName);
    boxes.add(tx);
    counts[BudgetBoxes.txBoxName] = tx.entries.length;

    final overrides =
        await _dumpTypedBox<MerchantOverride>(BudgetBoxes.overrideBoxName);
    boxes.add(overrides);
    counts[BudgetBoxes.overrideBoxName] = overrides.entries.length;

    final meta = await _dumpUntypedBox<dynamic>(BudgetBoxes.metaBoxName);
    boxes.add(meta);
    counts[BudgetBoxes.metaBoxName] = meta.entries.length;

    return BackupSection(
      key: BackupModuleKeys.transactions,
      moduleVersion: 1,
      counts: counts,
      payload: {'boxes': boxes.map((b) => b.toJson()).toList()},
    );
  }

  Future<BackupSection> _exportDiet(
      void Function(String stage)? onProgress) async {
    onProgress?.call('diet');
    final boxes = <BackupBoxDump>[];
    final counts = <String, int>{};

    final entries = await _dumpTypedBox<DietEntry>('dietEntries');
    boxes.add(entries);
    counts['dietEntries'] = entries.entries.length;

    final goal = await _dumpTypedBox<DietGoal>('dietGoal');
    boxes.add(goal);
    counts['dietGoal'] = goal.entries.length;

    final foods = await _dumpUntypedBox<dynamic>('dietFoods');
    boxes.add(foods);
    counts['dietFoods'] = foods.entries.length;

    final weights = await _dumpUntypedBox<dynamic>('dietWeights');
    boxes.add(weights);
    counts['dietWeights'] = weights.entries.length;

    return BackupSection(
      key: BackupModuleKeys.diet,
      moduleVersion: 1,
      counts: counts,
      payload: {'boxes': boxes.map((b) => b.toJson()).toList()},
    );
  }

  Future<BackupSection> _exportFitnessProfile(
      void Function(String stage)? onProgress) async {
    onProgress?.call('fitnessProfile');
    final profileBox =
        await _dumpTypedBox<FitnessNutritionProfile>('fitnessProfile');
    return BackupSection(
      key: BackupModuleKeys.fitnessProfile,
      moduleVersion: 1,
      counts: {'fitnessProfile': profileBox.entries.length},
      payload: {'boxes': [profileBox.toJson()]},
    );
  }

  Future<BackupSection> _exportMeta() async {
    final meta = <String, dynamic>{
      'platform': defaultTargetPlatform.toString(),
      'generatedAt': AppClock.now().toIso8601String(),
    };
    return BackupSection(
      key: BackupModuleKeys.meta,
      moduleVersion: 1,
      counts: const {},
      payload: meta,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Import
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> importAll(
    BackupManifest manifest, {
    bool resetFirst = true,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
    bool verifyCounts = true,
    bool createBackups = true,
  }) async {
    _importedCounts.clear();
    cancellationToken?.throwIfCancelled();
    if (resetFirst) {
      onProgress?.call('reset');
      await _resetService.clearAllData();
    }

    if (createBackups) {
      onProgress?.call('backup existing');
      await _backupExistingBoxes();
    }

    await _importProgress(
      _boxesFrom(manifest.sections[BackupModuleKeys.progress]),
      onProgress,
      cancellationToken,
    );
    await _importMissions(
      _boxesFrom(manifest.sections[BackupModuleKeys.missions]),
      onProgress,
      cancellationToken,
    );
    await _importStreaks(
      _boxesFrom(manifest.sections[BackupModuleKeys.streaks]),
      onProgress,
      cancellationToken,
    );
    await _importWorkouts(
      _boxesFrom(manifest.sections[BackupModuleKeys.workouts]),
      onProgress,
      cancellationToken,
    );
    await _importSessions(
      _boxesFrom(manifest.sections[BackupModuleKeys.sessions]),
      onProgress,
      cancellationToken,
    );
    await _importBudgets(
      _boxesFrom(manifest.sections[BackupModuleKeys.budgets]),
      onProgress,
      cancellationToken,
    );
    await _importTransactions(
      _boxesFrom(manifest.sections[BackupModuleKeys.transactions]),
      onProgress,
      cancellationToken,
    );
    await _importDiet(
      _boxesFrom(manifest.sections[BackupModuleKeys.diet]),
      onProgress,
      cancellationToken,
    );
    await _importFitnessProfile(
      _boxesFrom(manifest.sections[BackupModuleKeys.fitnessProfile]),
      onProgress,
      cancellationToken,
    );

    if (verifyCounts) {
      _verifyCounts(manifest);
    }
  }

  Future<void> _backupExistingBoxes() async {
    final boxNames = <String>[
      HiveService.skillBoxName,
      HiveService.statBoxName,
      HiveService.categoryBoxName,
      HiveService.staticObjectivesBoxName,
      HiveService.objectivesByDateBoxName,
      HiveService.statHistoryBoxName,
      HiveService.milestoneBoxName,
      HiveService.activeMissionsBoxName,
      HiveService.missionMetaBoxName,
      'objectiveStreaks',
      'categoryStreaks',
      'dayStreak',
      'bonusLedger',
      'momentumWallet',
      'skipReceipts',
      'appMeta',
      WorkoutBoxes.routinesBoxName,
      WorkoutBoxes.legacyRoutinesBoxName,
      WorkoutBoxes.workoutsBoxName,
      WorkoutBoxes.exerciseBoxName,
      WorkoutBoxes.logsBoxName,
      WorkoutBoxes.legacyLogsBoxName,
      WorkoutBoxes.schedulesBoxName,
      WorkoutBoxes.restOverridesBoxName,
      SessionPersistenceService.boxName,
      HiveService.budgetsBoxName,
      BudgetBoxes.txBoxName,
      BudgetBoxes.overrideBoxName,
      BudgetBoxes.metaBoxName,
      'dietEntries',
      'dietGoal',
      'dietFoods',
      'dietWeights',
      'fitnessProfile',
    ];

    for (final name in boxNames) {
      final bool exists = await Hive.boxExists(name) || Hive.isBoxOpen(name);
      if (!exists) continue;
      try {
        final BoxBase<dynamic> box = Hive.isBoxOpen(name)
            ? _getOpenBoxForBackup(name)
            : await Hive.openBox(name);
        final path = box.path;
        if (path == null) continue;
        final src = File(path);
        if (await src.exists()) {
          final bak = File('$path.bak');
          await bak.writeAsBytes(await src.readAsBytes(), flush: true);
        }
      } catch (_) {
        continue;
      }
    }
  }

  BoxBase<dynamic> _getOpenBoxForBackup(String name) {
    switch (name) {
      case 'objectiveStreaks':
        return Hive.box<ObjectiveStreak>(name);
      case 'categoryStreaks':
        return Hive.box<CategoryStreak>(name);
      case 'dayStreak':
        return Hive.box<DayStreak>(name);
      case 'bonusLedger':
        return Hive.box<BonusLedgerDay>(name);
      case 'momentumWallet':
        return Hive.box<MomentumWallet>(name);
      case 'skipReceipts':
        return Hive.box<SkipReceipt>(name);
      case HiveService.skillBoxName:
        return Hive.box<Skill>(name);
      case HiveService.statBoxName:
        return Hive.box<Stat>(name);
      case HiveService.categoryBoxName:
        return Hive.box<Category>(name);
      case HiveService.staticObjectivesBoxName:
        return Hive.box<Objective>(name);
      case HiveService.statHistoryBoxName:
        return Hive.box<StatHistoryEntry>(name);
      case HiveService.milestoneBoxName:
        return Hive.box<Milestone>(name);
      case HiveService.activeMissionsBoxName:
        return Hive.box<Mission>(name);
      case HiveService.budgetsBoxName:
        return Hive.box<BudgetHive>(name);
      case BudgetBoxes.txBoxName:
        return Hive.box<BudgetTransaction>(name);
      case BudgetBoxes.overrideBoxName:
        return Hive.box<MerchantOverride>(name);
      case WorkoutBoxes.routinesBoxName:
      case WorkoutBoxes.legacyRoutinesBoxName:
        return Hive.box<Routine>(name);
      case WorkoutBoxes.workoutsBoxName:
        return Hive.box<Workout>(name);
      case WorkoutBoxes.exerciseBoxName:
        return Hive.box<Exercise>(name);
      case WorkoutBoxes.logsBoxName:
      case WorkoutBoxes.legacyLogsBoxName:
        return Hive.box<WorkoutLog>(name);
      case WorkoutBoxes.schedulesBoxName:
        return Hive.box<WorkoutSchedule>(name);
      case WorkoutBoxes.restOverridesBoxName:
        return Hive.box<Map<String, dynamic>>(name);
      case 'dietEntries':
        return Hive.box<DietEntry>(name);
      case 'dietGoal':
        return Hive.box<DietGoal>(name);
      case 'fitnessProfile':
        return Hive.box<FitnessNutritionProfile>(name);
      default:
        return Hive.box(name);
    }
  }

  Future<void> _importProgress(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    cancellationToken?.throwIfCancelled();
    onProgress?.call('progress');
    await _restoreTypedBox<Skill>(
      HiveService.skillBoxName,
      _findBox(boxes, HiveService.skillBoxName),
    );
    await _restoreTypedBox<Stat>(
      HiveService.statBoxName,
      _findBox(boxes, HiveService.statBoxName),
    );
    await _restoreTypedBox<Category>(
      HiveService.categoryBoxName,
      _findBox(boxes, HiveService.categoryBoxName),
    );
    await _restoreTypedBox<Objective>(
      HiveService.staticObjectivesBoxName,
      _findBox(boxes, HiveService.staticObjectivesBoxName),
    );
    await _restoreTypedBox<StatHistoryEntry>(
      HiveService.statHistoryBoxName,
      _findBox(boxes, HiveService.statHistoryBoxName),
    );
    await _restoreTypedBox<Milestone>(
      HiveService.milestoneBoxName,
      _findBox(boxes, HiveService.milestoneBoxName),
    );
    await _restoreUntypedBox<dynamic>(
      HiveService.objectivesByDateBoxName,
      _findBox(boxes, HiveService.objectivesByDateBoxName),
    );
  }

  Future<void> _importMissions(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    onProgress?.call('missions');
    cancellationToken?.throwIfCancelled();
    await _restoreTypedBox<Mission>(
      HiveService.activeMissionsBoxName,
      _findBox(boxes, HiveService.activeMissionsBoxName),
    );
    await _restoreUntypedBox<dynamic>(
      HiveService.missionMetaBoxName,
      _findBox(boxes, HiveService.missionMetaBoxName),
    );
  }

  Future<void> _importStreaks(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    onProgress?.call('streaks');
    cancellationToken?.throwIfCancelled();
    await _restoreTypedBox<ObjectiveStreak>(
      'objectiveStreaks',
      _findBox(boxes, 'objectiveStreaks'),
    );
    await _restoreTypedBox<CategoryStreak>(
      'categoryStreaks',
      _findBox(boxes, 'categoryStreaks'),
    );
    await _restoreTypedBox<DayStreak>(
      'dayStreak',
      _findBox(boxes, 'dayStreak'),
    );
    await _restoreTypedBox<BonusLedgerDay>(
      'bonusLedger',
      _findBox(boxes, 'bonusLedger'),
    );
    await _restoreTypedBox<MomentumWallet>(
      'momentumWallet',
      _findBox(boxes, 'momentumWallet'),
    );
    await _restoreTypedBox<SkipReceipt>(
      'skipReceipts',
      _findBox(boxes, 'skipReceipts'),
    );
    await _restoreUntypedBox<dynamic>(
      'appMeta',
      _findBox(boxes, 'appMeta'),
    );
  }

  Future<void> _importWorkouts(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    onProgress?.call('workouts');
    cancellationToken?.throwIfCancelled();
    await _restoreTypedBox<Routine>(
      WorkoutBoxes.routinesBoxName,
      _findBox(boxes, WorkoutBoxes.routinesBoxName),
    );
    await _restoreTypedBox<Routine>(
      WorkoutBoxes.legacyRoutinesBoxName,
      _findBox(boxes, WorkoutBoxes.legacyRoutinesBoxName),
    );
    await _restoreTypedBox<Workout>(
      WorkoutBoxes.workoutsBoxName,
      _findBox(boxes, WorkoutBoxes.workoutsBoxName),
    );
    await _restoreTypedBox<Exercise>(
      WorkoutBoxes.exerciseBoxName,
      _findBox(boxes, WorkoutBoxes.exerciseBoxName),
    );
    await _restoreTypedBox<WorkoutLog>(
      WorkoutBoxes.logsBoxName,
      _findBox(boxes, WorkoutBoxes.logsBoxName),
    );
    await _restoreTypedBox<WorkoutLog>(
      WorkoutBoxes.legacyLogsBoxName,
      _findBox(boxes, WorkoutBoxes.legacyLogsBoxName),
    );
    await _restoreTypedBox<WorkoutSchedule>(
      WorkoutBoxes.schedulesBoxName,
      _findBox(boxes, WorkoutBoxes.schedulesBoxName),
    );
    await _restoreUntypedBox<Map<String, dynamic>>(
      WorkoutBoxes.restOverridesBoxName,
      _findBox(boxes, WorkoutBoxes.restOverridesBoxName),
    );
  }

  Future<void> _importSessions(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    onProgress?.call('sessions');
    cancellationToken?.throwIfCancelled();
    await _restoreUntypedBox<dynamic>(
      SessionPersistenceService.boxName,
      _findBox(boxes, SessionPersistenceService.boxName),
    );
  }

  Future<void> _importBudgets(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    onProgress?.call('budgets');
    cancellationToken?.throwIfCancelled();
    await _restoreTypedBox<BudgetHive>(
      HiveService.budgetsBoxName,
      _findBox(boxes, HiveService.budgetsBoxName),
    );
  }

  Future<void> _importTransactions(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    onProgress?.call('transactions');
    cancellationToken?.throwIfCancelled();
    await _restoreTypedBox<BudgetTransaction>(
      BudgetBoxes.txBoxName,
      _findBox(boxes, BudgetBoxes.txBoxName),
    );
    await _restoreTypedBox<MerchantOverride>(
      BudgetBoxes.overrideBoxName,
      _findBox(boxes, BudgetBoxes.overrideBoxName),
    );
    await _restoreUntypedBox<dynamic>(
      BudgetBoxes.metaBoxName,
      _findBox(boxes, BudgetBoxes.metaBoxName),
    );
  }

  Future<void> _importDiet(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    onProgress?.call('diet');
    cancellationToken?.throwIfCancelled();
    await _restoreTypedBox<DietEntry>(
      'dietEntries',
      _findBox(boxes, 'dietEntries'),
    );
    await _restoreTypedBox<DietGoal>(
      'dietGoal',
      _findBox(boxes, 'dietGoal'),
    );
    await _restoreUntypedBox<dynamic>(
      'dietFoods',
      _findBox(boxes, 'dietFoods'),
    );
    await _restoreUntypedBox<dynamic>(
      'dietWeights',
      _findBox(boxes, 'dietWeights'),
    );
  }

  Future<void> _importFitnessProfile(
    List<BackupBoxDump> boxes,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  ) async {
    onProgress?.call('fitnessProfile');
    cancellationToken?.throwIfCancelled();
    await _restoreTypedBox<FitnessNutritionProfile>(
      'fitnessProfile',
      _findBox(boxes, 'fitnessProfile'),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // helpers
  // ───────────────────────────────────────────────────────────────────────────

  Future<BackupBoxDump> _dumpTypedBox<T>(String name) async {
    if (!Hive.isBoxOpen(name) && !(await Hive.boxExists(name))) {
      return BackupBoxDump(name: name, entries: const []);
    }
    final box = await _openTypedBox<T>(name);
    return _dumpBox(name, box);
  }

  Future<BackupBoxDump> _dumpUntypedBox<T>(String name) async {
    if (!Hive.isBoxOpen(name) && !(await Hive.boxExists(name))) {
      return BackupBoxDump(name: name, entries: const []);
    }
    final box = await _openUntypedBox<T>(name);
    return _dumpBox(name, box);
  }

  BackupBoxDump _dumpBox(String name, Box<dynamic> box) {
    final entries = <BackupEntry>[];
    for (final key in box.keys) {
      final value = box.get(key);
      entries.add(BackupValueCodec.encode(key, value));
    }
    return BackupBoxDump(name: name, entries: entries);
  }

  Future<Box<T>> _openTypedBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }

  Future<Box<T>> _openUntypedBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }

  List<BackupBoxDump> _boxesFrom(BackupSection? section) {
    if (section == null) return const [];
    final list = section.payload['boxes'];
    if (list is! List) return const [];
    return list
        .map((e) =>
            BackupBoxDump.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  BackupBoxDump? _findBox(List<BackupBoxDump> boxes, String name) {
    for (final b in boxes) {
      if (b.name == name) return b;
    }
    return null;
  }

  Future<void> _restoreTypedBox<T>(
    String name,
    BackupBoxDump? dump,
  ) async {
    if (dump == null) return;
    final box = await _openTypedBox<T>(name);
    await box.clear();
    final map = <dynamic, T>{};
    for (final entry in dump.entries) {
      final value = BackupValueCodec.decode(entry);
      if (value is T) {
        map[entry.key] = value;
      }
    }
    await box.putAll(map);
    await box.flush();
    _importedCounts[name] = map.length;
  }

  Future<void> _restoreUntypedBox<T>(
    String name,
    BackupBoxDump? dump,
  ) async {
    if (dump == null) return;
    final box = await _openUntypedBox<T>(name);
    await box.clear();
    final map = <dynamic, T>{};
    for (final entry in dump.entries) {
      final value = BackupValueCodec.decode(entry);
      if (value is T) {
        map[entry.key] = value;
      } else {
        map[entry.key] = value as T;
      }
    }
    await box.putAll(map);
    await box.flush();
    _importedCounts[name] = map.length;
  }

  void _verifyCounts(BackupManifest manifest) {
    final mismatches = <String>[];
    for (final section in manifest.sections.values) {
      section.counts.forEach((box, expected) {
        final actual = _importedCounts[box];
        if (actual != null && actual != expected) {
          mismatches.add('$box expected $expected, wrote $actual');
        }
      });
    }
    if (mismatches.isNotEmpty) {
      throw StateError('Count verification failed: ${mismatches.join('; ')}');
    }
  }
}
