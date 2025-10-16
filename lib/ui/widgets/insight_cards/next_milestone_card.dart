import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/stat_repository.dart';

class NextMajorMilestoneCard extends StatelessWidget {
  final String categoryId;
  final String timeframe;

  const NextMajorMilestoneCard({
    super.key,
    required this.categoryId,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ObjectiveProvider>();
    final skills = provider.getSkillsForCategory(categoryId);

    _MilestoneProgressData? closest;

    for (final skill in skills) {
      for (final stat in skill.stats) {
        final milestone = provider.getMilestoneForStat(stat.id);
        final next = milestone?.getNext(stat.count);
        if (next == null) continue;

        final remaining = next - stat.count;
        if (closest == null || remaining < closest.remaining) {
          closest = _MilestoneProgressData(
            stat: stat,
            nextTarget: next,
            remaining: remaining,
          );
        }
      }
    }

    if (closest == null) {
      return const _EmptyCard("All current milestones completed!");
    }

    final meta = StatRepository.getById(closest.stat.id);
    final progress = closest.stat.count / closest.nextTarget;
    final progressPercent = progress.clamp(0.0, 1.0);
    final label = meta?.label ?? closest.stat.label;
    final emoji = meta?.emoji ?? '🎯';

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
              "📌 Next Major Milestone",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        "Goal: ${closest.nextTarget} ${label.toLowerCase()}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: Colors.grey.shade800,
              color: Colors.orangeAccent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Text(
              "${closest.remaining} to go • ${(progressPercent * 100).toStringAsFixed(0)}% complete",
              style: const TextStyle(
                fontSize: 13,
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneProgressData {
  final Stat stat;
  final int nextTarget;
  final int remaining;

  _MilestoneProgressData({
    required this.stat,
    required this.nextTarget,
    required this.remaining,
  });
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
