import 'package:flutter/material.dart';
import 'package:kontinuum/ui/screens/progress_screen.dart';
import 'package:kontinuum/ui/widgets/level_up_watcher.dart';
import 'package:kontinuum/main.dart'; // navigatorKey

// Writing editor
import 'package:kontinuum/ui/writing_editor/writing_editor_screen.dart';

// ✅ NEW: Budget module
import 'package:kontinuum/ui/screens/budget/budget_screen.dart';

class KontinuumApp extends StatelessWidget {
  const KontinuumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ global navigation
      title: 'Kontinuum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      builder: (context, child) => LevelUpWatcher(child: child!),

      // Keep your normal home
      home: const ProgressScreen(),

      // ➕ Routes
      routes: {
        '/writing': (_) => const WritingEditorScreen(),
        '/budget': (_) => const BudgetScreen(), // ✅ new route
      },
    );
  }
}

/// Optional helper: call this from anywhere to open the editor without a BuildContext.
void openWritingEditor() {
  navigatorKey.currentState?.pushNamed('/writing');
}
