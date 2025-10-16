import 'package:flutter/material.dart';
import 'package:kontinuum/models/objective.dart';

/// Base class for handling different types of objective logic and UI.
///
/// Each concrete handler will implement how the objective:
/// - Renders its input widget (checkbox, tally counter, etc.)
/// - Determines if it is complete
abstract class ObjectiveTypeHandler {
  /// Builds the appropriate UI input widget for this objective type.
  ///
  /// [objective]: the current objective to render.
  /// [selectedDate]: the currently selected date in the ProgressScreen.
  /// [onToggleComplete]: called when the user toggles completion (used in standard).
  /// [onUpdateAmount]: used for tally or stopwatch types to update progress amount.
  Widget buildInputWidget({
    required Objective objective,
    required DateTime selectedDate,
    required VoidCallback onToggleComplete,
    required Function(int)? onUpdateAmount,
  });

  /// Returns whether the objective is currently marked as complete.
  bool isComplete(Objective objective);
}
