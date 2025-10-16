import 'package:flutter/material.dart';
import 'package:kontinuum/data/level_utils.dart';

class StatXpBar extends StatelessWidget {
  final int xp;
  final int maxXp;

  const StatXpBar({super.key, required this.xp, required this.maxXp});

  @override
  Widget build(BuildContext context) {
    final level = LevelUtils.getLevelFromXp(xp, maxXp);
    final currentLevelXp = LevelUtils.getXpForLevel(level, maxXp);
    final nextLevelXp = LevelUtils.getXpForLevel(level + 1, maxXp);
    final levelRange = nextLevelXp - currentLevelXp;
    final levelProgress = levelRange == 0
        ? 0.0
        : (xp - currentLevelXp) / levelRange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: levelProgress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade800,
          color: Colors.deepPurpleAccent,
          minHeight: 6,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$xp / $nextLevelXp XP",
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            Text(
              "$xp / $maxXp XP total",
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
      ],
    );
  }
}
