import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/models/stat_history_entry.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/stat_repository.dart';

class MostActiveStatCard extends StatelessWidget {
  final String categoryId;
  final String timeframe;

  const MostActiveStatCard({
    super.key,
    required this.categoryId,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ObjectiveProvider>();
    final skills = provider.getSkillsForCategory(categoryId);

    final statGains = <Stat, double>{};

    for (final skill in skills) {
      for (final stat in skill.stats) {
        final history = provider.getStatHistory(stat.id);
        final filtered = _filterHistoryByTimeframe(history, timeframe);
        final gain = filtered.fold<double>(0, (sum, e) => sum + e.amount);
        if (gain > 0) statGains[stat] = gain;
      }
    }

    if (statGains.isEmpty) {
      return _EmptyCard(
        timeframe == 'All Time'
            ? "No XP data available."
            : "No XP gained during $timeframe.",
      );
    }

    final topEntry = statGains.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    final topStat = topEntry.key;
    final topXp = topEntry.value;

    final meta = StatRepository.getById(topStat.id);
    final progress = (topStat.xp / topStat.maxXp).clamp(0.0, 1.0);

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📊 Most Active Stat",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(meta?.emoji ?? "🎯", style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta?.label ?? topStat.label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      "+${topXp.toStringAsFixed(0)} XP $timeframe",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade800,
              color: Colors.greenAccent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Text(
              "${topStat.xp.toStringAsFixed(0)} / ${topStat.maxXp.toStringAsFixed(0)} XP",
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  List<StatHistoryEntry> _filterHistoryByTimeframe(
    List<StatHistoryEntry> history,
    String timeframe,
  ) {
    final now = DateTime.now();

    switch (timeframe) {
      case 'Last 7 Days':
        return history
            .where((e) => e.date.isAfter(now.subtract(const Duration(days: 7))))
            .toList();
      case 'Last 30 Days':
        return history
            .where(
              (e) => e.date.isAfter(now.subtract(const Duration(days: 30))),
            )
            .toList();
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return history.where((e) => e.date.isAfter(startOfWeek)).toList();
      default:
        return history;
    }
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
