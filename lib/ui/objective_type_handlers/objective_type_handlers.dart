import 'package:flutter/material.dart';
import 'package:kontinuum/models/objective.dart';
import 'objective_type_handler.dart';

// ✅ STANDARD
class StandardObjectiveHandler extends ObjectiveTypeHandler {
  @override
  Widget buildInputWidget({
    required Objective objective,
    required DateTime selectedDate,
    required VoidCallback onToggleComplete,
    required Function(int)? onUpdateAmount,
  }) {
    return _HoverableCheckboxRow(
      title: objective.title,
      isCompleted: objective.isCompleted,
      onToggle: onToggleComplete,
    );
  }

  @override
  bool isComplete(Objective objective) => objective.isCompleted;
}

class _HoverableCheckboxRow extends StatefulWidget {
  final String title;
  final bool isCompleted;
  final VoidCallback onToggle;

  const _HoverableCheckboxRow({
    required this.title,
    required this.isCompleted,
    required this.onToggle,
  });

  @override
  State<_HoverableCheckboxRow> createState() => _HoverableCheckboxRowState();
}

class _HoverableCheckboxRowState extends State<_HoverableCheckboxRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              decoration: widget.isCompleted
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: MouseRegion(
            opaque: false,
            hitTestBehavior: HitTestBehavior.deferToChild,
            onEnter: (_) {
              print('Hovered IN');
              setState(() => _isHovered = true);
            },
            onExit: (_) {
              print('Hovered OUT');
              setState(() => _isHovered = false);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onToggle,
              child: AnimatedScale(
                scale: _isHovered ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isCompleted
                          ? Colors.greenAccent
                          : Colors.grey,
                      width: 2,
                    ),
                    color: widget.isCompleted
                        ? Colors.greenAccent
                        : Colors.transparent,
                  ),
                  child: widget.isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.black)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ TALLY
class TallyObjectiveHandler extends ObjectiveTypeHandler {
  @override
  Widget buildInputWidget({
    required Objective objective,
    required DateTime selectedDate,
    required VoidCallback onToggleComplete,
    required Function(int)? onUpdateAmount,
  }) {
    final currentAmount = objective.getCompletedAmount(selectedDate);
    return ListTile(
      title: Text(objective.title),
      subtitle: LinearProgressIndicator(
        value: objective.completionRatioForDate(selectedDate),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              if (onUpdateAmount != null && currentAmount > 0) {
                onUpdateAmount(currentAmount - 1);
              }
            },
          ),
          Text("$currentAmount / ${objective.targetAmount}"),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              if (onUpdateAmount != null) {
                onUpdateAmount(currentAmount + 1);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  bool isComplete(Objective objective) {
    return false;
  }
}

// ✅ STOPWATCH
class StopwatchObjectiveHandler extends ObjectiveTypeHandler {
  @override
  Widget buildInputWidget({
    required Objective objective,
    required DateTime selectedDate,
    required VoidCallback onToggleComplete,
    required Function(int)? onUpdateAmount,
  }) {
    return ListTile(
      title: Text(objective.title),
      subtitle: const Text("Tap to start stopwatch"),
      onTap: () {
        // TODO: Open stopwatch screen, then call onUpdateAmount(duration)
      },
    );
  }

  @override
  bool isComplete(Objective objective) =>
      objective.completedAmount >= objective.targetAmount;
}

// ✅ WRITING PROMPT
class WritingPromptObjectiveHandler extends ObjectiveTypeHandler {
  @override
  Widget buildInputWidget({
    required Objective objective,
    required DateTime selectedDate,
    required VoidCallback onToggleComplete,
    required Function(int)? onUpdateAmount,
  }) {
    return ListTile(
      title: Text(objective.title),
      subtitle: const Text("Complete in the Writing Editor"),
      trailing: const Icon(Icons.edit),
      onTap: () {
        // TODO: Navigate to writing editor using writingBlockId
      },
    );
  }

  @override
  bool isComplete(Objective objective) => objective.isCompleted;
}

// ✅ SUBTASK
class SubtaskObjectiveHandler extends ObjectiveTypeHandler {
  @override
  Widget buildInputWidget({
    required Objective objective,
    required DateTime selectedDate,
    required VoidCallback onToggleComplete,
    required Function(int)? onUpdateAmount,
  }) {
    return ListTile(
      title: Text(objective.title),
      subtitle: const Text("Tap to view subtasks"),
      trailing: const Icon(Icons.checklist),
      onTap: () {
        // TODO: Show nested subtask list or screen
      },
    );
  }

  @override
  bool isComplete(Objective objective) => objective.isCompleted;
}

// ✅ REFLECTIVE
class ReflectiveObjectiveHandler extends ObjectiveTypeHandler {
  @override
  Widget buildInputWidget({
    required Objective objective,
    required DateTime selectedDate,
    required VoidCallback onToggleComplete,
    required Function(int)? onUpdateAmount,
  }) {
    return ListTile(
      title: Text(objective.title),
      subtitle: const Text("Tap to reflect"),
      trailing: const Icon(Icons.self_improvement),
      onTap: () {
        // TODO: Open reflection modal / mood entry screen
      },
    );
  }

  @override
  bool isComplete(Objective objective) => objective.isCompleted;
}
