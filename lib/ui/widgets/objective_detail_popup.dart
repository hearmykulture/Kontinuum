import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/objective/objective_tokens.dart';

class ObjectiveDetailPopup extends StatelessWidget {
  final Objective objective;

  const ObjectiveDetailPopup({super.key, required this.objective});

  @override
  Widget build(BuildContext context) {
    final popupMaxHeight = MediaQuery.of(context).size.height * 0.85;
    final popupMaxWidth = MediaQuery.of(context).size.width * 0.9;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.6),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: Hero(
                tag: 'objective_${objective.id}',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: popupMaxHeight,
                      maxWidth: popupMaxWidth,
                    ),
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              objective.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Colors.amberAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "${objective.xpReward} XP",
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            if (objective.statIds.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Tracked Stats:',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    objective.statIds
                                        .map(StatRepository.getDisplay)
                                        .join(', '),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.lightBlueAccent,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),

                            const SizedBox(height: 16),

                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: objective.categoryIds.map((id) {
                                final color =
                                    ObjectiveTokens.categoryColors[id] ??
                                    Colors.white;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.4),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    id,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    child: const Text('Close'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final ok =
                                          await showDialog<bool>(
                                            context: context,
                                            builder: (dialogCtx) => AlertDialog(
                                              backgroundColor: const Color(
                                                0xFF1E1E1E,
                                              ),
                                              title: const Text(
                                                'Delete objective?',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              content: Text(
                                                '“${objective.title}” will be permanently removed.',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  child: const Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogCtx,
                                                        false,
                                                      ),
                                                ),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.redAccent,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogCtx,
                                                        true,
                                                      ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false;
                                      if (!ok) return;

                                      // Guard context use after await.
                                      if (!context.mounted) return;

                                      final provider = context
                                          .read<ObjectiveProvider>();
                                      await provider.deleteObjective(
                                        objective.id,
                                      );

                                      if (!context.mounted) return;

                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Objective “${objective.title}” deleted',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
