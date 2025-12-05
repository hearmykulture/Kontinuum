import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';

import 'add_exercise_popup.dart';

class AddExercisePopupRoute extends PageRoute<List<Exercise>> {
  AddExercisePopupRoute({
    this.heroTag,
    this.headerLabel = 'Add exercise',
    this.initialExerciseId,
    this.detailsMode = false,
  });

  final String? heroTag;
  final String headerLabel;
  final String? initialExerciseId;
  final bool detailsMode;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.45);

  @override
  String? get barrierLabel => 'Dismiss ${headerLabel.toLowerCase()} popup';

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AddExercisePopup(
      heroTag: heroTag,
      headerLabel: headerLabel,
      initialExerciseId: initialExerciseId,
      detailsMode: detailsMode,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final scaleCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: fadeCurve,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(scaleCurve),
        child: child,
      ),
    );
  }
}

class ExerciseDetailsPopupRoute extends AddExercisePopupRoute {
  ExerciseDetailsPopupRoute({
    String? heroTag,
    required String exerciseId,
  }) : super(
          heroTag: heroTag,
          headerLabel: 'Exercise Details',
          initialExerciseId: exerciseId,
          detailsMode: true,
        );
}
