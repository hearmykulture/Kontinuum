import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/objective/objective_tokens.dart';
import 'package:kontinuum/ui/widgets/objective/stat_progress.dart';
import 'package:kontinuum/ui/widgets/objective/tally_stepper.dart';

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
    return _TallyPopupContent(
      objective: objective,
      selectedDate: selectedDate,
      onToggleComplete: onToggleComplete,
      onUpdateAmount: onUpdateAmount,
    );
  }

  @override
  bool isComplete(Objective objective) {
    return false;
  }
}

class _TallyPopupContent extends StatefulWidget {
  final Objective objective;
  final DateTime selectedDate;
  final VoidCallback onToggleComplete;
  final ValueChanged<int>? onUpdateAmount;

  const _TallyPopupContent({
    required this.objective,
    required this.selectedDate,
    required this.onToggleComplete,
    required this.onUpdateAmount,
  });

  @override
  State<_TallyPopupContent> createState() => _TallyPopupContentState();
}

class _TallyPopupContentState extends State<_TallyPopupContent> {
  int? _lastAmount;

  Objective _resolveObjective(ObjectiveProvider provider) {
    final todays = provider.getObjectivesForDay(widget.selectedDate);
    final idx = todays.indexWhere((o) => o.id == widget.objective.id);
    return idx == -1 ? widget.objective : todays[idx];
  }

  Color _accentColor(Objective o) {
    if (o.categoryIds.isEmpty) return const Color(0xFF8E7CFF);
    final name = o.categoryIds.first.toUpperCase();
    return ObjectiveTokens.categoryColors[name] ?? const Color(0xFF8E7CFF);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ObjectiveProvider, Objective>(
      selector: (_, p) => _resolveObjective(p),
      builder: (context, live, _) {
        final amount = live.getCompletedAmount(widget.selectedDate);
        final cappedTarget = live.targetAmount <= 0 ? 1 : live.targetAmount;
        final cappedAmount = amount.clamp(0, cappedTarget);
        final prevAmount = (_lastAmount ?? cappedAmount).clamp(0, cappedTarget);
        _lastAmount = cappedAmount;

        final accent = _accentColor(live);
        final completionRatio = live.completionRatioForDate(widget.selectedDate);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              live.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Progress • ${cappedAmount.toInt()} / $cappedTarget tallies',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
                color: const Color(0x18111216),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LevelProgressBar(
                    previousXp: prevAmount.toInt(),
                    currentXp: cappedAmount.toInt(),
                    maxXp: cappedTarget,
                    color: accent,
                    backgroundColor: const Color(0xFF141622),
                    thickness: 8,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(completionRatio * 100).clamp(0, 100).toStringAsFixed(0)}% complete',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        cappedAmount >= cappedTarget
                            ? 'Target met'
                            : '${(cappedTarget - cappedAmount).toInt()} remaining',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TallyStepper(
              amount: amount,
              min: 0,
              max: 1 << 31,
              target: cappedTarget,
              rowHeight: 48,
              numberFontSize: 18,
              radius: 20,
              backgroundColor: const Color(0x1FFFFFFF),
              expandToWidth: true,
              onChanged: (next) {
                if (widget.onUpdateAmount != null) {
                  widget.onUpdateAmount!(next);
                }
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: widget.onToggleComplete,
                    child: const Text('Mark complete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      if (widget.onUpdateAmount != null) {
                        widget.onUpdateAmount!(cappedTarget);
                      }
                    },
                    child: Text(cappedAmount >= cappedTarget ? 'Done' : 'Fill to target'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
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
