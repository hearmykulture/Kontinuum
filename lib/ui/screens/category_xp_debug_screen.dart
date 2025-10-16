import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/data/level_utils.dart';

class CategoryXpDebugScreen extends StatelessWidget {
  const CategoryXpDebugScreen({super.key});

  static const coreCategories = [
    'RAPPING',
    'PRODUCTION',
    'HEALTH',
    'KNOWLEDGE',
    'NETWORKING',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ObjectiveProvider>(context);
    final missionProvider = Provider.of<MissionProvider>(
      context,
      listen: false,
    );

    for (final id in coreCategories) {
      provider.ensureCategoryExists(id);
    }

    final categories = provider.categories;
    final totalXp = provider.totalXp;
    final totalLevel = provider.totalLevel;
    final totalProgress = provider.totalLevelProgress;
    final totalXpForNext = provider.totalXpForNextLevel;

    return Scaffold(
      appBar: AppBar(title: const Text('🧪 XP Debugger')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: Colors.blueGrey[900],
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🧠 Total Progress",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Total XP: $totalXp",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    "Total Level: $totalLevel",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: totalProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[700],
                    color: Colors.cyan,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$totalXp / $totalXpForNext XP for next level",
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          ...categories.values.map((cat) {
            const maxXp = 600000;
            final currentLevel = LevelUtils.getLevelFromXp(cat.xp, maxXp);
            final nextLevel = (currentLevel + 1).clamp(1, LevelUtils.maxLevel);
            final xpForCurrent = LevelUtils.getXpForLevel(currentLevel, maxXp);
            final xpForNext = LevelUtils.getXpForLevel(nextLevel, maxXp);
            final progress =
                ((cat.xp - xpForCurrent) / (xpForNext - xpForCurrent)).clamp(
                  0.0,
                  1.0,
                );
            final prestige = cat.prestigeTitle;
            final colorHex = cat.prestigeColor;
            final color = _parseColor(colorHex);

            return Card(
              color: Colors.grey[850],
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${cat.name} - Lv. $currentLevel ($prestige)",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress,
                      color: color ?? Colors.amber,
                      backgroundColor: Colors.grey[700],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${cat.xp} / $xpForNext XP",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [100, 1000, 10000].map((amount) {
                        return ElevatedButton(
                          onPressed: () {
                            provider.addXpToCategory(cat.id, amount);
                          },
                          child: Text("+$amount XP"),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                provider.resetEverything(missionProvider: missionProvider);
              },
              child: const Text(
                "🧹 Full Reset (XP, Objectives, Stats, Milestones)",
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Color? _parseColor(String hex) {
    try {
      final hexCode = hex.replaceAll("#", "");
      if (hexCode.length == 6) {
        return Color(int.parse("FF$hexCode", radix: 16));
      } else if (hexCode.length == 8) {
        return Color(int.parse(hexCode, radix: 16));
      }
    } catch (_) {}
    return null;
  }
}
