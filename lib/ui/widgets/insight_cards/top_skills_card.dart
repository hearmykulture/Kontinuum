import 'package:flutter/material.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/ui/widgets/skill_xp_bar.dart';
import 'package:kontinuum/data/level_utils.dart';

class TopSkillsCard extends StatelessWidget {
  final List<Skill> skills;
  final Map<String, int>? previousXpBySkill;
  final String timeframe;

  const TopSkillsCard({
    super.key,
    required this.skills,
    required this.previousXpBySkill,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) {
      return const _EmptyCard("No skills tracked yet for this category.");
    }

    final List<_SkillWithDelta> skillDeltas = skills.map((skill) {
      final previousXp = previousXpBySkill?[skill.id] ?? 0;
      final delta = skill.xp - previousXp;
      return _SkillWithDelta(skill: skill, delta: delta);
    }).toList()..sort((a, b) => b.delta.compareTo(a.delta)); // Sort descending

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
              "🧠 Skills Ranked by Proficiency (${_formatTimeframeLabel(timeframe)})",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...skillDeltas.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return _SkillRow(
                skill: data.skill,
                delta: data.delta,
                isTop: index == 0,
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatTimeframeLabel(String tf) {
    switch (tf) {
      case 'This Week':
      case 'Last 7 Days':
      case 'Last 30 Days':
      case 'All Time':
        return tf;
      default:
        return "Timeframe";
    }
  }
}

class _SkillWithDelta {
  final Skill skill;
  final int delta;

  _SkillWithDelta({required this.skill, required this.delta});
}

class _SkillRow extends StatelessWidget {
  final Skill skill;
  final int delta;
  final bool isTop;

  const _SkillRow({
    required this.skill,
    required this.delta,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final level = LevelUtils.getLevelFromXp(skill.xp, skill.maxXp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  isTop ? "👑 ${skill.label}" : skill.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  if (delta > 0) ...[
                    const Icon(
                      Icons.arrow_upward,
                      color: Colors.greenAccent,
                      size: 14,
                    ),
                    Text(
                      "+$delta",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    "Lvl $level",
                    style: const TextStyle(fontSize: 13, color: Colors.white38),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SkillXpBar(xp: skill.xp, maxXp: skill.maxXp),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}
