import 'package:flutter/material.dart';

class DietInsightsScreen extends StatelessWidget {
  const DietInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: real charts
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InsightCard(
          title: 'Adherence',
          value: '4 days',
          desc: 'You stayed within ±200 kcal for the last 4 days.',
        ),
        const SizedBox(height: 12),
        _InsightCard(
          title: 'Avg kcal (7d)',
          value: '2,280',
          desc: 'Slightly under your weekly target.',
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.value,
    required this.desc,
  });

  final String title;
  final String value;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
