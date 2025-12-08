import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kontinuum/models/stat_history_entry.dart';

class StatXpHistoryChart extends StatelessWidget {
  final List<StatHistoryEntry> history;

  const StatXpHistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No XP history available.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    double _xpValue(StatHistoryEntry e) =>
        e.xpDelta != 0 ? e.xpDelta.toDouble() : e.amount.toDouble();

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), _xpValue(history[i])));
    }

    final maxY = history
            .map((e) => _xpValue(e))
            .fold<double>(0, (a, b) => a > b ? a : b) *
        1.2;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 1.6,
        child: LineChart(
          LineChartData(
            backgroundColor: const Color(0xFF1E1E1E),
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                left: BorderSide(color: Colors.white24),
                bottom: BorderSide(color: Colors.white24),
              ),
            ),
            minX: 0,
            maxX: history.length.toDouble() - 1,
            minY: 0,
            maxY: maxY > 0
                ? maxY
                : 10, // Prevent chart from crashing on all-zero data
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.deepPurpleAccent,
                barWidth: 3,
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                ),
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
