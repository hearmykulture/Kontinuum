import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/stat_insight_summary.dart';
import 'package:kontinuum/ui/widgets/stat_xp_history_chart.dart';

class StatInsightsTab extends StatelessWidget {
  final String statId;

  const StatInsightsTab({super.key, required this.statId});

  String _formatLabel(String id) {
    return id
        .split(RegExp(r'[_\s]+'))
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ObjectiveProvider>(context);
    final label = _formatLabel(statId);

    final milestone = provider.getMilestoneForStat(statId);
    final currentCount = provider.stats.containsKey(statId)
        ? provider.getStatCount(statId)
        : provider.skills.containsKey(statId)
        ? provider.skills[statId]!.xp
        : provider.categories.containsKey(statId)
        ? provider.categories[statId]!.xp
        : 0;

    final level = milestone != null
        ? ((currentCount / milestone.thresholds.last) * 100)
              .clamp(0, 100)
              .toInt()
        : 0;

    final nextMilestone =
        milestone?.thresholds.firstWhere(
          (t) => t > currentCount,
          orElse: () => milestone.thresholds.last,
        ) ??
        0;

    final history = provider.getStatHistory(statId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatInsightSummary(
            statLabel: label,
            currentXp: currentCount,
            level: level,
            nextMilestone: nextMilestone,
          ),
          const SizedBox(height: 24),
          StatXpHistoryChart(history: history),
        ],
      ),
    );
  }
}
