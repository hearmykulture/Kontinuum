import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for RawKeyboard.clearKeysPressed
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/main.dart' show navigatorKey;
import 'package:kontinuum/config/feature_flags.dart';
import 'package:kontinuum/core/time/rollover_service.dart';

// Core screens
import 'package:kontinuum/ui/screens/progress_screen.dart';
import 'package:kontinuum/ui/screens/budget/create_budget_screen.dart';

// 🥗 diet screen
import 'package:kontinuum/ui/screens/diet/diet_home_screen.dart';

// 🏋 workout stack
import 'package:kontinuum/ui/workout/workout_dashboard_screen.dart';
import 'package:kontinuum/ui/workout/routine_detail_screen.dart';
import 'package:kontinuum/ui/workout/session_screen.dart';
import 'package:kontinuum/ui/workout/workout_summary_screen.dart';
import 'package:kontinuum/ui/workout/workout_editor_screen.dart';
import 'package:kontinuum/ui/workout/workout_history_screen.dart';
import 'package:kontinuum/ui/workout/library_picker_screen.dart';
// RoutineDetailScreen exports RoutineDetailArgs
// WorkoutSummaryScreen exports WorkoutSummaryArgs

class KontinuumApp extends StatefulWidget {
  const KontinuumApp({super.key});

  @override
  State<KontinuumApp> createState() => _KontinuumAppState();
}

class _KontinuumAppState extends State<KontinuumApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ Compatible reset for Flutter 3.32.x (no HardwareKeyboard.clearKeyboardState)
  void _resetKeyboardState() {
    try {
      RawKeyboard.instance.clearKeysPressed();
    } catch (_) {
      // no-op on platforms where RawKeyboard isn't tracking keys
    }
  }

  /// When app returns to foreground, run rollover again
  /// to handle "virtual midnight", and sanitize keyboard state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final roll = context.read<RolloverService>();
      roll.maybeRoll();
      _resetKeyboardState();
    }
  }

  // Also sanitize during hot-reload in debug
  @override
  void reassemble() {
    _resetKeyboardState();
    super.reassemble();
  }

  @override
  Widget build(BuildContext context) {
    // Base routes (always on)
    final Map<String, WidgetBuilder> routes = {
      // Budget composer route
      '/budget': (ctx) => CreateBudgetScreen(
            onClose: () => Navigator.of(ctx).maybePop(),
            onComplete: (draft) => Navigator.of(ctx).pop(draft),
          ),

      // 🥗 Diet route
      '/diet': (_) => const DietHomeScreen(),
    };

    // Conditionally add workout module routes
    if (FeatureFlags.workoutModuleEnabled) {
      routes.addAll({
        // 🚨 main workout entry — ProgressScreen should push this
        '/workout': (_) => const WorkoutDashboardScreen(),

        // Routine detail (expects: RoutineDetailArgs)
        '/routineDetail': (_) => const RoutineDetailScreen(),

        // Live session screen (pulls from provider.activeDraft)
        '/session': (_) => const SessionScreen(),

        // Workout summary (expects: WorkoutSummaryArgs)
        '/sessionSummary': (_) => const WorkoutSummaryScreen(),

        // Workout editor (expects: WorkoutEditorArgs)
        '/workoutEditor': (_) => const WorkoutEditorScreen(),

        // Workout history screen
        '/workoutHistory': (_) => const WorkoutHistoryScreen(),

        // Exercise library picker (for swap / add)
        '/workoutLibrary': (_) => const LibraryPickerScreen(),
      });
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Kontinuum',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // No more FlutterQuillLocalizations / writing-editor dependency
      supportedLocales: const [
        Locale('en'),
      ],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      home: const ProgressScreen(),
      routes: routes,
    );
  }
}

/// Global helper functions

Future<Object?> openBudgetComposer() {
  return navigatorKey.currentState?.pushNamed('/budget') ?? Future.value(null);
}
