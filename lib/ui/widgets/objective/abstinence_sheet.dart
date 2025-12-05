// lib/ui/widgets/objective/abstinence_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/providers/objective_provider.dart';

class AbstinenceSheet extends StatelessWidget {
  final Objective objective;
  final DateTime selectedDate;

  const AbstinenceSheet({
    super.key,
    required this.objective,
    required this.selectedDate,
  });

  String _fmt(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Selector<ObjectiveProvider, _AbSnapshot>(
      selector: (_, p) {
        final days = p.getAbstinenceDays(objective.id, selectedDate);
        return _AbSnapshot(
          daysClean: days,
          start: objective.abstinenceStartDate,
          lastRelapse: objective.abstinenceLastRelapseDate,
        );
      },
      builder: (context, snap, __) {
        final provider = context.read<ObjectiveProvider>();
        final isAbs = objective.isAbstinence; // ✅ unified

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1014),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.shield_moon,
                        color: Colors.lightBlueAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        objective.title,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${snap.daysClean} day${snap.daysClean == 1 ? '' : 's'} clean',
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Started:',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      snap.start != null ? _fmt(snap.start!) : '—',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 14),
                    const Text('Last relapse:',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      snap.lastRelapse != null ? _fmt(snap.lastRelapse!) : '—',
                      style: TextStyle(
                        color: snap.lastRelapse != null
                            ? Colors.redAccent
                            : Colors.white30,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (isAbs) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      await provider.startAbstinence(
                        objective.id,
                        selectedDate,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Streak restarted today')),
                        );
                      }
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restart from today'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await provider.logAbstinenceRelapse(
                        objective.id,
                        selectedDate,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Relapse logged')),
                        );
                      }
                    },
                    icon: const Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent),
                    label: const Text(
                      'Log relapse',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'This objective isn’t marked as an abstinence tracker in the model yet.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AbSnapshot {
  final int daysClean;
  final DateTime? start;
  final DateTime? lastRelapse;
  const _AbSnapshot({
    required this.daysClean,
    required this.start,
    required this.lastRelapse,
  });
}
