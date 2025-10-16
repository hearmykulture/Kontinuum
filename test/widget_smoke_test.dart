// test/widget_smoke_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kontinuum/app.dart'; // if your root widget lives elsewhere, update this import

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(
      KontinuumApp(),
    ); // remove `const` if constructor isn't const
    await tester.pumpAndSettle();
    // We expect the root to be a MaterialApp (or contain one).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
