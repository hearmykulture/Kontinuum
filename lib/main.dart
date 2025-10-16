// lib/main.dart
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

// Writing editor registry + blocks
import 'package:kontinuum/ui/writing_editor/blocks/block_registry.dart';
import 'package:kontinuum/ui/writing_editor/models/text_block.dart'
    show BlockType;

// Entendre
import 'package:kontinuum/ui/writing_editor/blocks/handlers/entendre_behavior.dart';
import 'package:kontinuum/ui/writing_editor/blocks/handlers/entendre_handler.dart';
import 'package:kontinuum/ui/writing_editor/blocks/editors/entendre_editor.dart';

// Simile
import 'package:kontinuum/ui/writing_editor/blocks/editors/simile_editor.dart';

// 👇 Global watcher that shows level-up popups anywhere in the app
import 'package:kontinuum/ui/widgets/level_up_watcher.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Hive adapters
  Hive.registerAdapter(StatAdapter());
  Hive.registerAdapter(SkillAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(ObjectiveTypeAdapter());
  Hive.registerAdapter(ObjectiveAdapter());
  Hive.registerAdapter(StatHistoryEntryAdapter());
  Hive.registerAdapter(MilestoneAdapter());
  Hive.registerAdapter(MissionAdapter());
  Hive.registerAdapter(MissionRarityAdapter());

  // Hive boxes
  await Hive.openBox<Skill>('skillsBox');
  await Hive.openBox<Stat>('statsBox');
  await Hive.openBox<Category>('categoriesBox');
  await Hive.openBox<Objective>('staticObjectivesBox');
  await Hive.openBox('objectivesByDateBox');
  await Hive.openBox<StatHistoryEntry>('statHistoryBox');
  await Hive.openBox<Milestone>('milestoneBox');
  await Hive.openBox<Mission>('activeMissionsBox');

  // Register writing blocks (render + behavior + editor UI)
  final reg = BlockRegistry.instance;
  reg
    ..registerHandler(EntendreHandler())
    ..registerBehavior(BlockType.entendre, EntendreBehavior())
    ..registerEditor(BlockType.entendre, EntendreEditor())
    ..registerEditor(BlockType.simile, SimileEditor());

  debugPrint('🧩 BlockRegistry wired: Entendre + Simile');

  // Providers (create once here so we can wire them together)
  final objectiveProvider = ObjectiveProvider();
  final missionProvider = MissionProvider()
    ..attachObjectiveProvider(objectiveProvider);
  await missionProvider.loadFromStorage();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ObjectiveProvider>.value(
          value: objectiveProvider,
        ),
        ChangeNotifierProvider<MissionProvider>.value(value: missionProvider),
      ],
      // ⬇️ Mount a single LevelUpWatcher globally so popups fire on every screen
      child: const LevelUpWatcher(
        child: KontinuumApp(), // Your app builds the MaterialApp inside
      ),
    ),
  );
}
