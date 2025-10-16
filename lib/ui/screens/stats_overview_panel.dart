import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/data/level_utils.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/screens/milestone_tree_screen.dart';
import 'package:kontinuum/ui/widgets/stat_xp_bar.dart';
import 'package:kontinuum/ui/widgets/skill_xp_bar.dart';
import 'package:kontinuum/ui/widgets/milestone_popup_wrapper.dart';
import 'package:kontinuum/ui/widgets/insight_cards/smart_suggestion_card.dart';
import 'package:kontinuum/ui/widgets/insight_cards/smart_suggestion_utils.dart';

class StatOverviewPanel extends StatefulWidget {
  const StatOverviewPanel({super.key});

  @override
  State<StatOverviewPanel> createState() => _StatOverviewPanelState();
}

class _StatOverviewPanelState extends State<StatOverviewPanel> {
  final Map<String, bool> _expanded = {};

  void _openMilestoneTree(BuildContext context, String statId, GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final pillRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => Navigator.of(context).pop(),
          child: MilestonePopupWrapper(
            pillRect: pillRect, // ✅ Pass the required param
            child: GestureDetector(
              onTap: () {}, // prevent popup from closing on internal taps
              child: MilestoneTreeScreen(statId: statId),
            ),
          ),
        ),
      ),
    );
  }

  Color _getPrestigeColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'gray':
        return Colors.grey;
      case 'white':
        return Colors.white;
      case 'gold':
        return Colors.amber;
      case 'aqua':
        return Colors.cyanAccent;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blueAccent;
      case 'red':
        return Colors.redAccent;
      case 'purple':
        return Colors.deepPurpleAccent;
      case 'pink':
        return Colors.pinkAccent;
      case 'rainbow':
        return Colors.tealAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLevelBadge({
    Key? key,
    required int level,
    required int xp,
    required String prestigeColor,
    required VoidCallback onTap,
  }) {
    final color = _getPrestigeColor(prestigeColor);
    return GestureDetector(
      key: key, // ✅ attach the GlobalKey to the pill widget
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(50),
          borderRadius: BorderRadius.circular(20),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "LVL $level",
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text: " │ ",
                style: TextStyle(color: Colors.white54),
              ),
              TextSpan(
                text: "$xp XP",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildXpBarForCategory(String categoryName, int xp, int level) {
    final currentXp = LevelUtils.getXpForCategoryLevel(level);
    final nextXp = LevelUtils.getXpForCategoryLevel(level + 1);
    final range = nextXp - currentXp;
    final progress = range == 0 ? 0.0 : (xp - currentXp) / range;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade800,
          color: _getColorForCategory(categoryName),
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 4),
        Text(
          "$xp / $nextXp XP",
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Color _getColorForCategory(String name) {
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ObjectiveProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // 🧱 All Category Cards
            ...provider.categories.values.map((category) {
              final skills = provider.getSkillsForCategory(category.id);
              final categoryLevel = LevelUtils.getCategoryLevelFromXp(
                category.xp,
              );
              final categoryPrestige = LevelUtils.getPrestigeTitle(
                categoryLevel,
              );
              final hasSkills = skills.isNotEmpty;
              final prestigeColor = _getPrestigeColor(categoryPrestige.color);
              final isExpanded = _expanded[category.id] ?? true;

              final categoryPillKey = GlobalKey();

              return Column(
                children: [
                  Card(
                    color: const Color(0xFF1C1C1E),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // 🔹 Category Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: prestigeColor,
                                    ),
                                  ),
                                  if (hasSkills)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        categoryPrestige.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              _buildLevelBadge(
                                key: categoryPillKey,
                                level: categoryLevel,
                                xp: category.xp,
                                prestigeColor: categoryPrestige.color,
                                onTap: () => _openMilestoneTree(
                                  context,
                                  category.id,
                                  categoryPillKey,
                                ),
                              ),
                            ],
                          ),

                          _buildXpBarForCategory(
                            category.name,
                            category.xp,
                            categoryLevel,
                          ),

                          // 🔹 Skill + Stat Breakdown
                          if (hasSkills)
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF101526),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: const Text(
                                      'SKILLS & STATS',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _expanded[category.id] = !isExpanded;
                                        });
                                      },
                                    ),
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      child: Column(
                                        children: skills.map((skill) {
                                          final skillMaxXp = skill.maxXp;
                                          final skillLevel =
                                              LevelUtils.getLevelFromXp(
                                                skill.xp,
                                                skillMaxXp,
                                              );
                                          final skillPrestige =
                                              LevelUtils.getPrestigeTitle(
                                                skillLevel,
                                              );

                                          final skillPillKey = GlobalKey();

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      skill.label,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    _buildLevelBadge(
                                                      key: skillPillKey,
                                                      level: skillLevel,
                                                      xp: skill.xp,
                                                      prestigeColor:
                                                          skillPrestige.color,
                                                      onTap: () =>
                                                          _openMilestoneTree(
                                                            context,
                                                            skill.id,
                                                            skillPillKey,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                SkillXpBar(
                                                  xp: skill.xp,
                                                  maxXp: skillMaxXp,
                                                ),
                                                const SizedBox(height: 6),
                                                ...skill.stats.map((stat) {
                                                  final statCount = provider
                                                      .getStatCount(stat.id);
                                                  final statMaxXp =
                                                      stat.repsForMastery *
                                                      stat.averageMinutesPerUnit;
                                                  final statLevel =
                                                      LevelUtils.getLevelFromXp(
                                                        statCount,
                                                        statMaxXp,
                                                      );
                                                  final statPrestige =
                                                      LevelUtils.getPrestigeTitle(
                                                        statLevel,
                                                      );

                                                  final statPillKey =
                                                      GlobalKey();

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 12,
                                                          top: 4,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              "$statCount ${stat.label}",
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                  ),
                                                            ),
                                                            _buildLevelBadge(
                                                              key: statPillKey,
                                                              level: statLevel,
                                                              xp: statCount,
                                                              prestigeColor:
                                                                  statPrestige
                                                                      .color,
                                                              onTap: () =>
                                                                  _openMilestoneTree(
                                                                    context,
                                                                    stat.id,
                                                                    statPillKey,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        StatXpBar(
                                                          xp: statCount,
                                                          maxXp: statMaxXp,
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 🔮 Smart Suggestions Card
                  const SizedBox(height: 8),
                  SmartSuggestionCard(
                    suggestions: SmartSuggestionUtils.getSuggestions(
                      provider,
                      category,
                    ),
                  ),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
