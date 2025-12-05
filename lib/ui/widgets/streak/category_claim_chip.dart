import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/core/streaks/streak_engine.dart';
import 'package:kontinuum/core/time/day_id.dart';

class CategoryClaimChip extends StatelessWidget {
  const CategoryClaimChip({
    super.key,
    required this.categoryId, // use your category.id or name (matches streak key)
    required this.date, // usually the currently selected day
  });

  final String categoryId;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final se = context.read<StreakEngine>();
    final todayY = ymd(date);

    // Rebuild when this category's streak changes
    return ValueListenableBuilder(
      valueListenable: se.categoryListenable(keys: [categoryId]),
      builder: (_, __, ___) {
        final st = se.getCategoryStreak(categoryId);
        final show = st != null &&
            st.claimPending &&
            st.pendingXp > 0 &&
            st.lastFullYmd == todayY;

        if (!show) return const SizedBox.shrink();

        final pending = st!.pendingXp;

        return ActionChip(
          labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          avatar:
              const Icon(Icons.monetization_on, size: 16, color: Colors.black),
          backgroundColor: Colors.amber,
          label: Text('Claim +$pending XP',
              style: const TextStyle(color: Colors.black)),
          onPressed: () async {
            final paid = se.claimCategoryBonus(categoryId, date);
            final snack = SnackBar(
              content: Text(
                paid == pending
                    ? 'Claimed +$paid XP'
                    : 'Claimed +$paid XP (daily pool was capped)',
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(snack);
          },
        );
      },
    );
  }
}
