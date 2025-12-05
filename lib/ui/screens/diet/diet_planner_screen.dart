import 'package:flutter/material.dart';

class DietPlannerScreen extends StatelessWidget {
  const DietPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final days = _fakeWeek();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final d = days[index];
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text('${d.label} · ${d.targetKcal} kcal'),
            subtitle: Text(d.tag),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: open editor sheet
            },
          ),
        );
      },
    );
  }

  List<_PlannerDay> _fakeWeek() {
    return const [
      _PlannerDay('Mon', 2350, 'Rest'),
      _PlannerDay('Tue', 2650, 'Training'),
      _PlannerDay('Wed', 2350, 'Rest'),
      _PlannerDay('Thu', 2350, 'Rest'),
      _PlannerDay('Fri', 2650, 'Training'),
      _PlannerDay('Sat', 2500, 'Flex'),
      _PlannerDay('Sun', 2200, 'Low'),
    ];
  }
}

class _PlannerDay {
  final String label;
  final int targetKcal;
  final String tag;
  const _PlannerDay(this.label, this.targetKcal, this.tag);
}
