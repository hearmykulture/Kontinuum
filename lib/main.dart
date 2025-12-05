import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        debugPaintBaselinesEnabled,
        debugPaintLayerBordersEnabled,
        debugPaintPointersEnabled,
        debugPaintSizeEnabled;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_keyboard_visibility_platform_interface/flutter_keyboard_visibility_platform_interface.dart'
    as keyboard_visibility show FlutterKeyboardVisibilityPlatform;
import 'package:quill_native_bridge/quill_native_bridge.dart'
    show
        QuillNativeBridgeFeature,
        GalleryImageSaveOptions,
        ImageSaveOptions,
        ImageSaveResult,
        QuillNativeBridgeStub;
import 'package:quill_native_bridge_platform_interface/quill_native_bridge_platform_interface.dart'
    as quill_native show QuillNativeBridgePlatform;

// App shell / navigation host
import 'package:kontinuum/app.dart';

// Providers
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/providers/project_provider.dart';
import 'package:kontinuum/providers/alignment_schedule_provider.dart';
import 'package:kontinuum/providers/transactions_provider.dart';
import 'package:kontinuum/providers/notification_center_provider.dart';
import 'package:kontinuum/services/notification_dispatcher.dart';

// Core models & Hive adapters
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/models/budget_models_hive.dart';

// Diet models (generated)
import 'package:kontinuum/models/diet_models.dart';

// Workout models: register Hive adapters for repetition/schedule models
import 'package:kontinuum/models/workout_models.dart' as workout_models
    show registerWorkoutHiveAdapters;

// ✅ backward-compatible adapter for old WorkoutItem rows
import 'package:kontinuum/models/workout_item_adapter_safe.dart';

// Session state (Hive-annotated workout session model)
import 'package:kontinuum/models/session_state.dart';

// Streaks / rollover
import 'package:kontinuum/models/streak_models.dart';
import 'package:kontinuum/core/streaks/streak_engine.dart';
import 'package:kontinuum/core/time/rollover_service.dart';

// Workout local storage + exercise library seed
import 'package:kontinuum/services/workout_boxes.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/services/session_persistence_service.dart';

// Budget boxes
import 'package:kontinuum/services/budget_boxes.dart';

// Level-up watcher overlay
import 'package:kontinuum/ui/widgets/level_up_watcher.dart';

// Hive helpers
import 'package:kontinuum/data/hive_service.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class _QuillNativeBridgeNoop extends quill_native.QuillNativeBridgePlatform {
  @override
  Future<bool> isSupported(QuillNativeBridgeFeature feature) async => false;

  @override
  Future<bool> isIOSSimulator() async => false;

  @override
  Future<String?> getClipboardHtml() async => null;

  @override
  Future<void> copyHtmlToClipboard(String html) async {}

  @override
  Future<void> copyImageToClipboard(Uint8List imageBytes) async {}

  @override
  Future<Uint8List?> getClipboardImage() async => null;

  @override
  Future<Uint8List?> getClipboardGif() async => null;

  @override
  Future<List<String>> getClipboardFiles() async => const [];

  @override
  Future<void> openGalleryApp() async {}

  @override
  Future<void> saveImageToGallery(
    Uint8List imageBytes, {
    required GalleryImageSaveOptions options,
  }) async {}

  @override
  Future<ImageSaveResult> saveImage(
    Uint8List imageBytes, {
    required ImageSaveOptions options,
  }) async =>
      const ImageSaveResult(filePath: null, blobUrl: null);

  @override
  bool isAppleSafari() => false;
}

class _KeyboardVisibilityStub
    extends keyboard_visibility.FlutterKeyboardVisibilityPlatform {
  _KeyboardVisibilityStub() {
    // Ensure listeners receive an initial hidden state.
    _controller.add(false);
  }

  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onChange => _controller.stream;
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ----------------------------------------------------------
// DIET: fixed adapters with safe IDs (180–182)
// ----------------------------------------------------------
class MealSlotAdapterFixed extends MealSlotAdapter {
  @override
  int get typeId => 180;
}

class DietEntryAdapterFixed extends DietEntryAdapter {
  @override
  int get typeId => 181;
}

class DietGoalAdapterFixed extends DietGoalAdapter {
  @override
  int get typeId => 182;
}

// ---------- generic safe register ----------
void _registerAdapterSafe<T>(TypeAdapter<T> adapter) {
  final id = adapter.typeId;
  if (id < 0 || id > 223) {
    debugPrint(
        '⚠️ Skipping adapter ${adapter.runtimeType} because typeId=$id is out of range (0–223).');
    return;
  }
  if (!Hive.isAdapterRegistered(id)) {
    Hive.registerAdapter<T>(adapter);
  }
}

// ---------- generic resilient open ----------
Future<Box<T>> _openBoxResilient<T>(String name) async {
  try {
    return await Hive.openBox<T>(name);
  } catch (e, st) {
    debugPrint('❗ Failed to open box "$name": $e');
    debugPrint('$st');
    await Hive.deleteBoxFromDisk(name);
    debugPrint('🧹 Deleted box "$name" and reopening clean…');
    return await Hive.openBox<T>(name);
  }
}

// ----------------------------------------------------------
// WORKOUT init — fully resilient + hot-restart safe
// ----------------------------------------------------------
Future<void> _initWorkoutStorageResilient() async {
  try {
    const scrubCandidates = <String>[
      'workouts',
      'workoutSessions',
      'workoutPlans',
      'workoutTemplates',
      'workoutMeta',
    ];

    const reservedWorkoutBoxes = <String>{
      'workoutroutines',
      'workoutRoutines',
      'workoutlogs',
      'workoutLogs',
    };

    final anyOpen = scrubCandidates.any(Hive.isBoxOpen) ||
        reservedWorkoutBoxes.any(Hive.isBoxOpen);

    if (!anyOpen) {
      try {
        await WorkoutBoxes.init();
      } catch (e, st) {
        debugPrint('❗ WorkoutBoxes.init() failed (1st attempt): $e');
        debugPrint('$st');

        for (final name in scrubCandidates) {
          if (await Hive.boxExists(name)) {
            debugPrint('🧹 Deleting corrupted workout box "$name"…');
            await Hive.deleteBoxFromDisk(name);
          }
        }

        try {
          await WorkoutBoxes.init();
        } catch (e2, st2) {
          debugPrint('❗ WorkoutBoxes.init() failed (2nd attempt): $e2');
          debugPrint('$st2');
          debugPrint(
              '⚠️ Workout storage will be disabled for this run, app will still boot.');
          return;
        }
      }
    } else {
      debugPrint(
          '⚠️ Workout boxes already open (hot restart / iOS keep-alive) → skipping WorkoutBoxes.init()');
    }

    // seed our local small library
    try {
      await ExerciseLibraryService.instance.ensureSeedLoaded();
    } catch (e, st) {
      debugPrint('⚠️ Failed to seed exercise library: $e');
      debugPrint('$st');
    }
  } catch (e, st) {
    debugPrint('🚫 Hard workout init failure (swallowed): $e');
    debugPrint('$st');
  }
}

Future<void> _logToFile(String message) async {
  try {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/kontinuum_startup.log');
    await file.writeAsString('${AppClock.now()}: $message\n',
        mode: FileMode.append);
  } catch (e) {
    // Silently fail if can't write
  }
}

Future<void> main() async {
  // Pre-zone logging is safe (doesn't touch Flutter bindings).
  await _logToFile('🚀 [MAIN] App starting...');

  // Everything that touches Flutter bindings must be in the SAME zone.
  runZonedGuarded(() async {
    try {
      debugPaintBaselinesEnabled = false;
      debugPaintSizeEnabled = false;
      debugPaintPointersEnabled = false;
      debugPaintLayerBordersEnabled = false;
      WidgetsFlutterBinding.ensureInitialized();
      await _logToFile('✅ [MAIN] WidgetsFlutterBinding initialized');
    } catch (e) {
      await _logToFile('❌ [MAIN] WidgetsFlutterBinding FAILED: $e');
      rethrow;
    }

    // Global error handler for Flutter framework errors (same zone!)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // Keep Flutter's verbose diagnostics
      debugPrintStack(label: 'STACK', stackTrace: details.stack);
    };

    // Quill native bridge isn't available outside mobile builds.
    QuillNativeBridgeStub.registerWith();
    // Override stub with a fully-implemented no-op to avoid UnimplementedError.
    quill_native.QuillNativeBridgePlatform.instance = _QuillNativeBridgeNoop();

    // Desktop builds don't ship platform implementations for keyboard visibility.
    keyboard_visibility.FlutterKeyboardVisibilityPlatform.instance =
        _KeyboardVisibilityStub();

    // 👇 Swallow orphan KeyUp events from desktop hero/focus swaps
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event is KeyUpEvent) {
        final pressed = HardwareKeyboard.instance.physicalKeysPressed;
        if (!pressed.contains(event.physicalKey)) {
          debugPrint(
              '🛡️ Swallowed orphan KeyUp for ${event.logicalKey.debugName}');
          return true;
        }
      }
      return false;
    });

    await _logToFile('📱 [MAIN] About to init Hive...');

    try {
      await Hive.initFlutter();
      await _logToFile('✅ [MAIN] Hive initialized successfully');
    } catch (e) {
      await _logToFile('❌ [MAIN] Hive.initFlutter FAILED: $e');
      rethrow;
    }

    // 🔹 Register RepetitionMode, RepetitionUnit, WorkoutSchedule (218–220)
    await _logToFile('📝 [MAIN] Registering workout adapters...');
    workout_models.registerWorkoutHiveAdapters();
    await _logToFile('✅ [MAIN] Workout adapters registered');

    // 1) register safe workout item adapter first (legacy rows)
    if (!Hive.isAdapterRegistered(207)) {
      Hive.registerAdapter(WorkoutItemAdapterSafe());
      debugPrint('✅ Registered WorkoutItemAdapterSafe (typeId=207)');
    }

    // 1b) register safe workout adapter to handle legacy null bools
    if (!Hive.isAdapterRegistered(209)) {
      Hive.registerAdapter(WorkoutAdapterSafe());
      debugPrint('✅ Registered WorkoutAdapterSafe (typeId=209)');
    }

    // 2) register ALL adapters we use in providers
    _registerAdapterSafe<Stat>(StatAdapter());
    _registerAdapterSafe<Skill>(SkillAdapter());
    _registerAdapterSafe<Category>(CategoryAdapter());
    _registerAdapterSafe<ObjectiveType>(ObjectiveTypeAdapter());
    _registerAdapterSafe<Objective>(ObjectiveAdapter());
    _registerAdapterSafe<StatHistoryEntry>(StatHistoryEntryAdapter());
    _registerAdapterSafe<Milestone>(MilestoneAdapter());
    _registerAdapterSafe<Mission>(MissionAdapter());
    _registerAdapterSafe<MissionRarity>(MissionRarityAdapter());

    // streak adapters
    _registerAdapterSafe<ObjectiveStreak>(ObjectiveStreakAdapter());
    _registerAdapterSafe<CategoryStreak>(CategoryStreakAdapter());
    _registerAdapterSafe<DayStreak>(DayStreakAdapter());
    _registerAdapterSafe<BonusLedgerDay>(BonusLedgerDayAdapter());
    _registerAdapterSafe<MomentumWallet>(MomentumWalletAdapter());
    _registerAdapterSafe<SkipReceipt>(SkipReceiptAdapter());
    _registerAdapterSafe<BudgetHive>(BudgetHiveAdapter());
    _registerAdapterSafe<BudgetCategoryHive>(BudgetCategoryHiveAdapter());
    _registerAdapterSafe<RecurringExpenseHive>(RecurringExpenseHiveAdapter());

    // diet adapters
    _registerAdapterSafe<MealSlot>(MealSlotAdapterFixed());
    _registerAdapterSafe<DietEntry>(DietEntryAdapterFixed());
    _registerAdapterSafe<DietGoal>(DietGoalAdapterFixed());

    // fitness screening adapters
    _registerAdapterSafe<TrainingGoal>(TrainingGoalAdapter());
    _registerAdapterSafe<TrainingEnvironment>(TrainingEnvironmentAdapter());
    _registerAdapterSafe<DietGoalKind>(DietGoalKindAdapter());
    _registerAdapterSafe<TrackingStyle>(TrackingStyleAdapter());
    _registerAdapterSafe<ExperienceLevel>(ExperienceLevelAdapter());
    _registerAdapterSafe<FitnessNutritionProfile>(
        FitnessNutritionProfileAdapter());

    // Session state adapters (typeId 223/222)
    if (!Hive.isAdapterRegistered(223)) {
      try {
        _registerAdapterSafe<WorkoutSessionState>(WorkoutSessionStateAdapter());
      } catch (_) {
        // If the generated adapter isn't present yet, it's fine.
      }
    }
    if (!Hive.isAdapterRegistered(222)) {
      try {
        _registerAdapterSafe<SavedSetData>(SavedSetDataAdapter());
      } catch (_) {
        // Same note as above.
      }
    }

    // 3) open core boxes up front (resilient)
    await _openBoxResilient<Skill>(HiveService.skillBoxName);
    await _openBoxResilient<Stat>(HiveService.statBoxName);
    await _openBoxResilient<Category>(HiveService.categoryBoxName);
    await _openBoxResilient<Objective>(HiveService.staticObjectivesBoxName);
    await _openBoxResilient<dynamic>(HiveService.objectivesByDateBoxName);
    await _openBoxResilient<StatHistoryEntry>(HiveService.statHistoryBoxName);
    await _openBoxResilient<Milestone>(HiveService.milestoneBoxName);
    await _openBoxResilient<Mission>(HiveService.activeMissionsBoxName);
    await _openBoxResilient<dynamic>(HiveService.missionMetaBoxName);

    // app meta
    final metaBox = await _openBoxResilient<dynamic>('appMeta');

    // streak-related boxes
    final objStreakBox =
        await _openBoxResilient<ObjectiveStreak>('objectiveStreaks');
    final catStreakBox =
        await _openBoxResilient<CategoryStreak>('categoryStreaks');
    final dayStreakBox = await _openBoxResilient<DayStreak>('dayStreak');
    final ledgerBox = await _openBoxResilient<BonusLedgerDay>('bonusLedger');
    final walletBox = await _openBoxResilient<MomentumWallet>('momentumWallet');
    final skipBox = await _openBoxResilient<SkipReceipt>('skipReceipts');

    // workout boxes + local seed
    await _initWorkoutStorageResilient();

    // session persistence (workout state save/restore)
    await SessionPersistenceService.init();

    // budget boxes (for transactions)
    await BudgetBoxes.init();

    // budget main box
    await _openBoxResilient<BudgetHive>(HiveService.budgetsBoxName);

    // diet boxes
    final dietEntryBox = await _openBoxResilient<DietEntry>('dietEntries');
    final dietGoalBox = await _openBoxResilient<DietGoal>('dietGoal');
    final dietFoodsBox = await _openBoxResilient<dynamic>('dietFoods');
    final dietWeightsBox = await _openBoxResilient<dynamic>('dietWeights');
    final fitnessProfileBox =
        await _openBoxResilient<FitnessNutritionProfile>('fitnessProfile');
    final alignmentScheduleBox =
        await _openBoxResilient<dynamic>('alignment_schedule_box');
    final notificationCenterBox =
        await _openBoxResilient<dynamic>('notification_center_box');
    final notificationCenterProvider =
        NotificationCenterProvider(notificationCenterBox);

    // (writing editor fully removed: no BlockRegistry wiring here anymore)

    // 4) providers
    final objectiveProvider = ObjectiveProvider();

    final missionProvider = MissionProvider()
      ..attachObjectiveProvider(objectiveProvider);
    await missionProvider.loadFromStorage();

    final streakEngine = StreakEngine(
      objStreakBox,
      catStreakBox,
      dayStreakBox,
      ledgerBox,
      walletBox,
      skipBox,
    );
    objectiveProvider.attachStreakEngine(streakEngine);

    final rolloverService =
        RolloverService(metaBox, streakEngine, objectiveProvider);
    rolloverService.maybeRoll();

    final workoutProvider = WorkoutProvider(objectiveProvider, missionProvider);

    final dietProvider = DietProvider(
      entryBox: dietEntryBox,
      goalBox: dietGoalBox,
      foodsBox: dietFoodsBox,
      weightsBox: dietWeightsBox,
    );
    final fitnessProfileProvider = FitnessProfileProvider(fitnessProfileBox);

    final hiveService = HiveService();
    final budgetProvider = BudgetProvider(hiveService);
    await budgetProvider.loadBudgets();

    final projectProvider = ProjectProvider();
    final alignmentProvider = AlignmentScheduleProvider(alignmentScheduleBox);
    NotificationDispatcher.attach(notificationCenterProvider);

    final existingProfile = fitnessProfileProvider.profile;
    if (existingProfile != null) {
      await dietProvider.updateBaseCalories(existingProfile.tdeeEstimate);
      await dietProvider.updateGoalMode(switch (existingProfile.dietGoal) {
        DietGoalKind.cut => 'cut',
        DietGoalKind.bulk => 'bulk',
        DietGoalKind.maintain => 'maintain',
      });
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: objectiveProvider),
          ChangeNotifierProvider.value(value: missionProvider),
          ChangeNotifierProvider.value(value: workoutProvider),
          ChangeNotifierProvider.value(value: dietProvider),
          ChangeNotifierProvider.value(value: fitnessProfileProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: projectProvider),
          ChangeNotifierProvider.value(value: alignmentProvider),
          ChangeNotifierProvider.value(
            value: notificationCenterProvider,
          ),
          ChangeNotifierProvider(create: (_) => TransactionsProvider()),
          Provider<StreakEngine>.value(value: streakEngine),
          Provider<RolloverService>.value(value: rolloverService),
        ],
        child: const LevelUpWatcher(
          child: KontinuumApp(),
        ),
      ),
    );
  }, (error, stackTrace) {
    // Unhandled async errors in this zone
    debugPrint('🚨 UNHANDLED ERROR: $error');
    debugPrint('STACK: $stackTrace');
  });
}
