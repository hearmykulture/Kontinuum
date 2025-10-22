import 'package:flutter/material.dart';
import 'package:kontinuum/ui/screens/progress_screen.dart';
import 'package:kontinuum/main.dart'; // navigatorKey

// Writing editor
import 'package:kontinuum/ui/writing_editor/writing_editor_screen.dart';

// Budget composer screen (kept for the /budget route)
import 'package:kontinuum/ui/screens/budget/create_budget_screen.dart';

class KontinuumApp extends StatelessWidget {
  const KontinuumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Kontinuum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      home: const ProgressScreen(),
      routes: {
        '/writing': (_) => const WritingEditorScreen(),
        '/budget': (ctx) => CreateBudgetScreen(
              onClose: () => Navigator.of(ctx).maybePop(),
              onComplete: (draft) {
                // TODO: persist draft to storage if desired.
                Navigator.of(ctx).pop(draft);
              },
            ),
      },
    );
  }
}

void openWritingEditor() {
  navigatorKey.currentState?.pushNamed('/writing');
}

/// Return the result without tying to a specific type to avoid the analyzer error.
Future<Object?> openBudgetComposer() {
  return navigatorKey.currentState?.pushNamed('/budget') ?? Future.value(null);
}
