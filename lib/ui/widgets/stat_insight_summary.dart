import 'package:flutter/material.dart';

class StatInsightSummary extends StatelessWidget {
  final String statLabel;
  final int currentXp;
  final int level;
  final int nextMilestone;

  const StatInsightSummary({
    super.key,
    required this.statLabel,
    required this.currentXp,
    required this.level,
    required this.nextMilestone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              statLabel,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildItem('XP', currentXp.toString()),
                _buildItem('Level', level.toString()),
                _buildItem('Next', nextMilestone.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
