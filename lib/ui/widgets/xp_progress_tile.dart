import 'package:flutter/material.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/data/level_utils.dart';

class XpProgressTile extends StatelessWidget {
  final Category category;

  const XpProgressTile({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final currentXp = category.xp;
    final currentLevel = LevelUtils.getLevelFromXp(currentXp, 600000);
    final nextLevel = (currentLevel + 1).clamp(1, LevelUtils.maxLevel);
    final xpForCurrent = LevelUtils.getXpForLevel(currentLevel, 600000);
    final xpForNext = LevelUtils.getXpForLevel(nextLevel, 600000);
    final range = xpForNext - xpForCurrent;
    final progress = range == 0 ? 0.0 : (currentXp - xpForCurrent) / range;

    return ListTile(
      title: Text("${category.name} - Lv. $currentLevel"),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.prestigeTitle,
            style: TextStyle(color: Colors.grey[400]),
          ),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            color: Colors.amber,
            backgroundColor: Colors.grey[800],
          ),
          Text("$currentXp / $xpForNext XP"),
        ],
      ),
    );
  }
}
