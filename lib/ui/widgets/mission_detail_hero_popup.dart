// lib/ui/widgets/mission_detail_hero_popup.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/data/level_utils.dart';
import 'package:kontinuum/ui/widgets/xp_gain_bottom_bar.dart'; // ✅ overlay

class MissionDetailHeroPopup extends StatelessWidget {
  final Mission mission;
  final VoidCallback? onClose;

  const MissionDetailHeroPopup({
    super.key,
    required this.mission,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final objectiveProvider = context.read<ObjectiveProvider>();
    final missionProvider = context.read<MissionProvider>();

    // ✅ Border reflects acceptance (green like the grid card)
    final Color borderColor = mission.isAccepted
        ? Colors.greenAccent.withOpacity(0.75)
        : Colors.deepPurpleAccent.withOpacity(0.5);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // backdrop
          GestureDetector(
            onTap: () {
              onClose?.call();
              Navigator.of(context).pop();
            },
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
          // sheet
          Center(
            child: Hero(
              tag: mission.id,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 340,
                    minHeight: 150,
                    maxHeight: 600,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161925).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.7), // ✅
                  ),
                  child: IntrinsicHeight(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                onClose?.call();
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                          if (mission.recommendedBySmartSuggestion)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurpleAccent.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "🧠 Suggested for You",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Text(
                            mission.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            mission.description ?? "No description.",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),

                          // ▶️ CATEGORY + RARITY BADGES
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ...mission.categoryIds.map((id) {
                                final cat = objectiveProvider.getCategoryById(
                                  id,
                                );
                                final level = LevelUtils.getCategoryLevelFromXp(
                                  cat.xp,
                                );
                                final prestige = LevelUtils.getPrestigeTitle(
                                  level,
                                );
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _prestigeTint(prestige.color),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${cat.name} ${prestige.title.split(' ').last}",
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _rarityColor(mission).withOpacity(0.2),
                                  border: Border.all(
                                    color: _rarityColor(mission),
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  mission.rarity.name.toUpperCase(),
                                  style: TextStyle(
                                    color: _rarityColor(mission),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Text(
                            "Stats Rewarded:",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: mission.statIds.map((id) {
                              final meta = StatRepository.getById(id);
                              return Chip(
                                backgroundColor: Colors.white12,
                                label: Text(
                                  meta?.display ?? "Unknown",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Reward: ${mission.xpReward} XP",
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ---- Actions ----
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!mission.isAccepted)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      missionProvider.acceptMission(mission);
                                      onClose?.call();
                                      Navigator.of(context).pop();
                                    },
                                    icon: const Icon(Icons.check),
                                    label: const Text("Accept Mission"),
                                  )
                                else if (!mission.isCompleted)
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          // === XP overlay (compute BEFORE mutation) ===
                                          final hasCat =
                                              mission.categoryIds.isNotEmpty;
                                          final String label = hasCat
                                              ? mission.categoryIds.first
                                                    .toUpperCase()
                                              : "Total";
                                          final Color color = hasCat
                                              ? _categoryColor(
                                                  mission.categoryIds.first,
                                                )
                                              : Colors.amber;

                                          final int fromXp = hasCat
                                              ? objectiveProvider.getCategoryXp(
                                                  mission.categoryIds.first,
                                                )
                                              : objectiveProvider.totalXp;
                                          final int toXp =
                                              fromXp + mission.xpReward;

                                          // Show the overlay now (root overlay), so it remains visible after pop.
                                          XpGainBottomBar.show(
                                            context,
                                            label: label,
                                            fromXp: fromXp,
                                            toXp: toXp,
                                            color: color,
                                          );

                                          // Pop first to keep hero happy, then mutate provider.
                                          onClose?.call();
                                          Navigator.of(context).pop();

                                          // Complete the mission (this will award XP via MissionProvider).
                                          Future.microtask(() {
                                            missionProvider.completeMission(
                                              mission,
                                            );
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        label: const Text("Complete Mission"),
                                      ),
                                      const SizedBox(height: 10),
                                      TextButton.icon(
                                        onPressed: () {
                                          missionProvider.abandonMission(
                                            mission,
                                          );
                                          onClose?.call();
                                          Navigator.of(context).pop();
                                        },
                                        icon: const Icon(Icons.cancel),
                                        label: const Text("Abandon Mission"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- helpers ----

  Color _rarityColor(Mission mission) {
    switch (mission.rarity) {
      case MissionRarity.common:
        return Colors.grey[300]!;
      case MissionRarity.rare:
        return Colors.cyanAccent;
      case MissionRarity.legendary:
        return Colors.deepPurpleAccent;
    }
  }

  Color _prestigeTint(String prestigeColor) {
    switch (prestigeColor.toLowerCase()) {
      case "white":
        return Colors.white;
      case "gold":
        return Colors.amber;
      case "aqua":
        return Colors.cyan;
      case "green":
        return Colors.greenAccent;
      case "blue":
        return Colors.lightBlueAccent;
      case "red":
        return Colors.redAccent;
      case "purple":
        return Colors.deepPurpleAccent;
      case "pink":
        return Colors.pinkAccent;
      case "gray":
        return Colors.grey;
      case "rainbow":
        return Colors.purpleAccent;
      default:
        return Colors.white10;
    }
  }

  Color _categoryColor(String name) {
    switch (name.toLowerCase()) {
      case 'rapping':
        return Colors.redAccent;
      case 'production':
        return Colors.blueAccent;
      case 'health':
        return Colors.greenAccent;
      case 'knowledge':
        return Colors.deepPurpleAccent;
      case 'networking':
        return Colors.teal;
      default:
        return Colors.amber;
    }
  }
}
