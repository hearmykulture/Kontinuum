import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/core/streaks/streak_engine.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/core/streaks/streak_config.dart';
import 'package:kontinuum/core/time/app_clock.dart';

/// Simple in-app shop: currently sells "Skip Objective (protect streak today)".
/// Usage:
///   ShopBottomSheet.show(context);
class ShopBottomSheet {
  // If you prefer, move this into StreakConfig.
  static const int _skipCostMc = 15;

  static Future<void> show(BuildContext context, {DateTime? date}) async {
    final objProv = context.read<ObjectiveProvider>();
    final StreakEngine? engine = objProv.streakEngine;

    if (engine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Shop unavailable (engine not attached).')),
      );
      return;
    }

    final DateTime day = date ?? objProv.selectedDateNotifier.value;
    final List<Objective> todays = objProv.getObjectivesForDay(day);

    // Put incomplete first for convenience.
    todays.sort((a, b) {
      final ai = a.isCompleted ? 1 : 0;
      final bi = b.isCompleted ? 1 : 0;
      final cmp = ai.compareTo(bi);
      if (cmp != 0) return cmp;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    Objective? selected;
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final balance = engine.getWallet().balanceMc;
            final canAfford = balance >= _skipCostMc;

            String subline = 'Overflow bonuses convert automatically '
                'at ${StreakConfig.xpPerMc} XP → 1 MC.';
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Text('Shop', style: theme.textTheme.titleLarge),
                      const Spacer(),
                      Chip(
                        label: Text('MC: $balance'),
                        avatar: const Icon(Icons.bolt_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Product card
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_moon_outlined),
                              const SizedBox(width: 8),
                              Text(
                                'Skip Objective (protect streak today)',
                                style: theme.textTheme.titleMedium,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.bolt_outlined, size: 16),
                                    const SizedBox(width: 4),
                                    Text('$_skipCostMc'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose one objective from ${_friendlyDate(day)}. '
                            'If you miss it, the streak will not break for that objective.',
                            style: theme.textTheme.bodyMedium!
                                .copyWith(color: theme.hintColor),
                          ),
                          const SizedBox(height: 16),

                          // Objective selector
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: todays.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No objectives scheduled for that day.',
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: todays.length,
                                    separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color:
                                            theme.colorScheme.outlineVariant),
                                    itemBuilder: (_, i) {
                                      final o = todays[i];
                                      final alreadySkipped =
                                          _safeHasSkip(engine, o, day);
                                      final disabledReason = !canAfford
                                          ? 'Not enough MC'
                                          : alreadySkipped
                                              ? 'Already protected'
                                              : null;

                                      return ListTile(
                                        enabled: disabledReason == null,
                                        leading: Radio<Objective>(
                                          value: o,
                                          groupValue: selected,
                                          onChanged: (val) {
                                            if (disabledReason != null) return;
                                            setState(() => selected = val);
                                          },
                                        ),
                                        title: Text(o.title),
                                        subtitle: Row(
                                          children: [
                                            if (o.isCompleted)
                                              const Padding(
                                                padding:
                                                    EdgeInsets.only(right: 8),
                                                child: Icon(Icons.check_circle,
                                                    size: 16),
                                              ),
                                            Text(
                                              disabledReason ??
                                                  (o.isCompleted
                                                      ? 'Completed'
                                                      : 'Incomplete'),
                                            ),
                                          ],
                                        ),
                                        trailing: alreadySkipped
                                            ? const Icon(Icons.verified,
                                                color: Colors.green)
                                            : null,
                                        onTap: () {
                                          if (disabledReason != null) return;
                                          setState(() => selected = o);
                                        },
                                      );
                                    },
                                  ),
                          ),

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.shopping_bag_outlined),
                                  label: const Text('Apply Skip'),
                                  onPressed: (selected != null && canAfford)
                                      ? () {
                                          final o = selected!;
                                          // Double-check: prevent duplicates.
                                          if (_safeHasSkip(engine, o, day)) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Skip already applied to "${o.title}" today.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          final ok =
                                              engine.applySkipForObjective(
                                            o.id,
                                            day,
                                            costMc: _skipCostMc,
                                          );

                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(ok
                                                  ? 'Skip applied: "${o.title}" is protected today (−$_skipCostMc MC).'
                                                  : 'Not enough MC to apply skip.'),
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subline,
                      style: theme.textTheme.bodySmall!
                          .copyWith(color: theme.hintColor),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _friendlyDate(DateTime d) {
    final now = AppClock.now();
    final nd = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    final delta = dd.difference(nd).inDays;
    if (delta == 0) return 'today';
    if (delta == -1) return 'yesterday';
    if (delta == 1) return 'tomorrow';
    return '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
  }

  // Guard: if helper isn't present yet, we fall back to "no skip on file".
  static bool _safeHasSkip(StreakEngine engine, Objective o, DateTime day) {
    try {
      return engine.hasSkipForObjectiveOnDate(o.id, day);
    } catch (_) {
      return false;
    }
  }
}
