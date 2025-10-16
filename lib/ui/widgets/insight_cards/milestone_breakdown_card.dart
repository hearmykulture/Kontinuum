import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:provider/provider.dart';

class MilestoneBreakdownCard extends StatelessWidget {
  final String categoryId;
  final String timeframe;

  const MilestoneBreakdownCard({
    super.key,
    required this.categoryId,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ObjectiveProvider>();
    final skills = provider.getSkillsForCategory(categoryId);
    final xpDeltas = provider.getStatXpDelta(timeframe);

    final List<_MilestoneBarData> barData = [];

    for (final skill in skills) {
      for (final stat in skill.stats) {
        final milestone = provider.getMilestoneForStat(stat.id);
        if (milestone == null) continue;

        final delta = xpDeltas[stat.id] ?? 0;
        final achieved = milestone.getAchieved(stat.count);

        final include = timeframe == 'All Time' || delta > 0;
        if (include) {
          barData.add(
            _MilestoneBarData(
              label:
                  '${StatRepository.getDisplay(stat.id)}'
                  '${delta > 0 ? ' (+$delta XP)' : ''}',
              value: achieved.length,
              isActive: delta > 0,
            ),
          );
        }
      }
    }

    final maxMilestones = barData.isEmpty
        ? 1
        : barData.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🧩 Milestone Breakdown",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (barData.isEmpty)
              const Text(
                'No activity in this timeframe.',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              )
            else
              SizedBox(
                height: barData.length * 32.0,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceBetween,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 140,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            if (index >= barData.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              barData[index].label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, _) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    barGroups: List.generate(barData.length, (i) {
                      final data = barData[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: data.value.toDouble(),
                            color: data.isActive
                                ? Colors.orangeAccent
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                            width: 14,
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxMilestones.toDouble(),
                              color: Colors.white12,
                            ),
                          ),
                        ],
                      );
                    }),
                    maxY: maxMilestones.toDouble() + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneBarData {
  final String label;
  final int value;
  final bool isActive;

  _MilestoneBarData({
    required this.label,
    required this.value,
    required this.isActive,
  });
}
