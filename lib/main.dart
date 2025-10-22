import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:kontinuum/app.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/models/mission.dart';

// writing editor...
import 'package:kontinuum/ui/writing_editor/blocks/block_registry.dart';
import 'package:kontinuum/ui/writing_editor/models/text_block.dart'
    show BlockType;
import 'package:kontinuum/ui/writing_editor/blocks/handlers/entendre_behavior.dart';
import 'package:kontinuum/ui/writing_editor/blocks/handlers/entendre_handler.dart';
import 'package:kontinuum/ui/writing_editor/blocks/editors/entendre_editor.dart';
import 'package:kontinuum/ui/writing_editor/blocks/editors/simile_editor.dart';

import 'package:kontinuum/ui/widgets/level_up_watcher.dart';
import 'package:kontinuum/data/hive_service.dart';

// ✅ banking boxes
import 'package:kontinuum/services/budget_boxes.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // ✅ Register your app's existing adapters first (if not already generated on access)
  Hive.registerAdapter(StatAdapter());
  Hive.registerAdapter(SkillAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(ObjectiveTypeAdapter());
  Hive.registerAdapter(ObjectiveAdapter());
  Hive.registerAdapter(StatHistoryEntryAdapter());
  Hive.registerAdapter(MilestoneAdapter());
  Hive.registerAdapter(MissionAdapter());
  Hive.registerAdapter(MissionRarityAdapter());

  // ✅ Open your existing boxes
  await Hive.openBox<Skill>(HiveService.skillBoxName);
  await Hive.openBox<Stat>(HiveService.statBoxName);
  await Hive.openBox<Category>(HiveService.categoryBoxName);
  await Hive.openBox<Objective>(HiveService.staticObjectivesBoxName);
  await Hive.openBox<dynamic>(HiveService.objectivesByDateBoxName);
  await Hive.openBox<StatHistoryEntry>(HiveService.statHistoryBoxName);
  await Hive.openBox<Milestone>(HiveService.milestoneBoxName);
  await Hive.openBox<Mission>(HiveService.activeMissionsBoxName);
  await Hive.openBox<dynamic>(HiveService.missionMetaBoxName);

  // ✅ Register adapters and open banking boxes (only once)
  await BudgetBoxes.init();

  // Writing-editor registry
  final reg = BlockRegistry.instance
    ..registerHandler(EntendreHandler())
    ..registerBehavior(BlockType.entendre, EntendreBehavior())
    ..registerEditor(BlockType.entendre, EntendreEditor())
    ..registerEditor(BlockType.simile, SimileEditor());
  debugPrint('🧩 BlockRegistry wired: Entendre + Simile');

  final objectiveProvider = ObjectiveProvider();
  final missionProvider = MissionProvider()
    ..attachObjectiveProvider(objectiveProvider);
  await missionProvider.loadFromStorage();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ObjectiveProvider>.value(
            value: objectiveProvider),
        ChangeNotifierProvider<MissionProvider>.value(value: missionProvider),
      ],
      child: const LevelUpWatcher(child: KontinuumApp()),
    ),
  );
}
