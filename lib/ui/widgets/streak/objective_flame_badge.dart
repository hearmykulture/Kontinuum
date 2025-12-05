import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/core/streaks/streak_engine.dart';

class ObjectiveFlameBadge extends StatelessWidget {
  const ObjectiveFlameBadge({
    super.key,
    required this.objectiveId,
  });

  final String objectiveId;

  @override
  Widget build(BuildContext context) {
    final se = context.read<StreakEngine>();

    // Rebuild only when this objective's streak changes
    return ValueListenableBuilder(
      valueListenable: se.objectiveListenable(keys: [objectiveId]),
      builder: (_, __, ___) {
        final os = se.getObjectiveStreak(objectiveId);
        final n = os?.current ?? 0;
        if (n <= 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0x33FF9800),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x66FF9800), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department,
                  size: 12, color: Colors.orangeAccent),
              const SizedBox(width: 4),
              Text(
                '$n',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
