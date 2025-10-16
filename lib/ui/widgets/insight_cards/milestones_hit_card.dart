import 'package:flutter/material.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:provider/provider.dart';

class MilestonesHitCard extends StatelessWidget {
  final String categoryId;
  final String timeframe;

  const MilestonesHitCard({
    super.key,
    required this.categoryId,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ObjectiveProvider>();
    final skills = provider.getSkillsForCategory(categoryId);
    final xpDeltas = provider.getStatXpDelta(timeframe);

    int totalMilestonesHit = 0;
    int statCount = 0;
    int skillCount = 0;

    for (final skill in skills) {
      bool skillHasMilestone = false;

      for (final stat in skill.stats) {
        final delta = xpDeltas[stat.id] ?? 0;
        final milestone = provider.getMilestoneForStat(stat.id);
        final shouldInclude = timeframe == 'All Time' || delta > 0;

        if (milestone != null && shouldInclude) {
          final achieved = milestone.getAchieved(stat.count);
          if (achieved.isNotEmpty) {
            totalMilestonesHit += achieved.length;
            statCount++;
            skillHasMilestone = true;
          }
        }
      }

      if (skillHasMilestone) {
        skillCount++;
      }
    }

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🎯 Milestones Hit",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (totalMilestonesHit > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$totalMilestonesHit milestone${totalMilestonesHit == 1 ? '' : 's'} completed",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 6,
                          color: Colors.greenAccent,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$skillCount skill${skillCount == 1 ? '' : 's'} • $statCount stat${statCount == 1 ? '' : 's'}",
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              )
            else
              const Text(
                "No milestones hit during this timeframe.",
                style: TextStyle(fontSize: 13, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}
