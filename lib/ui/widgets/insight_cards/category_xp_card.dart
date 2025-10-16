import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/level_utils.dart';

class CategoryXpCard extends StatelessWidget {
  final Category category;
  final String timeframe;

  const CategoryXpCard({
    super.key,
    required this.category,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ObjectiveProvider>();
    final statDeltaMap = provider.getStatXpForTimeframe(timeframe);
    final categoryXpDelta = _calculateCategoryXpDelta(
      provider,
      category.id,
      statDeltaMap,
    );

    final currentXp = category.xp;
    final level = LevelUtils.getCategoryLevelFromXp(currentXp);
    final nextLevel = (level + 1).clamp(1, LevelUtils.maxLevel);
    final xpForCurrent = LevelUtils.getXpForCategoryLevel(level);
    final xpForNext = LevelUtils.getXpForCategoryLevel(nextLevel);
    final progress = ((currentXp - xpForCurrent) / (xpForNext - xpForCurrent))
        .clamp(0.0, 1.0);

    final prestige = LevelUtils.getPrestigeTitle(level);
    final color = _mapPrestigeColor(prestige.color);

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🏆 ${category.name} – Level $level",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade800,
              color: color,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$currentXp XP",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  "→ $xpForNext XP",
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  prestige.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.9),
                  ),
                ),
                if (timeframe != 'All Time' && categoryXpDelta > 0)
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 14,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+$categoryXpDelta XP',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _calculateCategoryXpDelta(
    ObjectiveProvider provider,
    String categoryId,
    Map<String, int> deltaMap,
  ) {
    return provider
        .getStatsForCategory(categoryId)
        .fold<int>(0, (sum, stat) => sum + (deltaMap[stat.id] ?? 0));
  }

  Color _mapPrestigeColor(String name) {
    switch (name.toLowerCase()) {
      case 'gold':
        return Colors.amber;
      case 'aqua':
        return Colors.cyanAccent;
      case 'green':
        return Colors.greenAccent;
      case 'blue':
        return Colors.blueAccent;
      case 'red':
        return Colors.redAccent;
      case 'purple':
        return Colors.purpleAccent;
      case 'gray':
        return Colors.grey;
      case 'white':
        return Colors.white;
      case 'pink':
        return Colors.pinkAccent;
      case 'rainbow':
        return Colors.deepPurpleAccent;
      default:
        return Colors.orangeAccent;
    }
  }
}
