import 'package:flutter/foundation.dart';
import 'package:kontinuum/models/objective.dart';

/// What got dragged and where we want it to go.
class ObjectiveMoveIntent {
  final Objective objective;
  final String fromCategory; // e.g. "RAPPING" or "Uncategorized"
  final String? toCategory; // null or "Uncategorized" ⇒ goes to unassigned
  final int? toIndex; // position inside target category (null = append)
  final DateTime day;

  ObjectiveMoveIntent({
    required this.objective,
    required this.fromCategory,
    required this.day,
    this.toCategory,
    this.toIndex,
  });
}

/// When you drag a whole category to a new slot.
class CategoryMoveIntent {
  final String categoryId;
  final int newIndex;

  CategoryMoveIntent({
    required this.categoryId,
    required this.newIndex,
  });
}

/// Global “edit / jiggle / drag” brain for Progress screen.
class ObjectiveArrangeController extends ChangeNotifier {
  bool _editMode = false;
  bool get editMode => _editMode;

  // the thing currently being dragged (for highlighting targets)
  String? draggingObjectiveId;
  String? draggingCategoryId;

  // these are set by the screen so the controller stays UI-layer
  Future<void> Function(ObjectiveMoveIntent intent)? onMoveObjective;
  Future<void> Function(CategoryMoveIntent intent)? onMoveCategory;

  void toggleEdit() {
    _editMode = !_editMode;
    notifyListeners();
  }

  void exitEdit() {
    if (!_editMode) return;
    _editMode = false;
    draggingObjectiveId = null;
    draggingCategoryId = null;
    notifyListeners();
  }

  // ——— objective drag ———
  void startObjectiveDrag(String objectiveId) {
    draggingObjectiveId = objectiveId;
    notifyListeners();
  }

  Future<void> dropObjective(ObjectiveMoveIntent intent) async {
    draggingObjectiveId = null;
    if (onMoveObjective != null) {
      await onMoveObjective!(intent);
    }
    notifyListeners();
  }

  // ——— category drag ———
  void startCategoryDrag(String categoryId) {
    draggingCategoryId = categoryId;
    notifyListeners();
  }

  Future<void> dropCategory(CategoryMoveIntent intent) async {
    draggingCategoryId = null;
    if (onMoveCategory != null) {
      await onMoveCategory!(intent);
    }
    notifyListeners();
  }
}
