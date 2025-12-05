// lib/ui/screens/diet/diet_day_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/diet_models.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/ui/screens/diet/diet_log_sheet.dart';

// New: dashboard header at the very top
import 'package:kontinuum/ui/screens/diet/diet_dashboard_widget.dart';
import 'package:kontinuum/ui/screens/diet/fdc_food_search_sheet.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class DietDayView extends StatefulWidget {
  const DietDayView({super.key});

  @override
  State<DietDayView> createState() => _DietDayViewState();
}

class _DietDayViewState extends State<DietDayView> {
  DateTime _selectedDate = AppClock.now();

  @override
  Widget build(BuildContext context) {
    return Consumer<DietProvider>(
      builder: (context, diet, _) {
        final date = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        final dateLabel =
            '${_weekday(date.weekday)}, ${date.month}/${date.day}';

        final targetKcal = diet.goal.caloriesTarget;
        final currentKcal = diet.caloriesForDay(date);

        final breakfasts = diet.entriesForSlotEnum(date, MealSlot.breakfast);
        final lunches = diet.entriesForSlotEnum(date, MealSlot.lunch);
        final dinners = diet.entriesForSlotEnum(date, MealSlot.dinner);
        final snacks = diet.entriesForSlotEnum(date, MealSlot.snack);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Top header: YearProgressBar + diet carousel (identical look to workout) ---
              DietDashboardWidget(
                selectedDate: date,
                getProgressForDay: (day) {
                  final target = diet.goal.caloriesTarget;
                  if (target <= 0) return 0.0;
                  final cals = diet.caloriesForDay(day);
                  final v = cals / target;
                  return v.clamp(0.0, 1.0);
                },
                onDateSelected: (d) => setState(() => _selectedDate = d),

                // Optional tiles; hook up whatever flows you like
                dietCards: [
                  DietCardData(
                    id: 'usda',
                    title: 'Search USDA',
                    subtitle: 'FoodData Central',
                    icon: Icons.search,
                    onTap: () {
                      showFdcFoodSearchSheet(
                        context,
                        date: date,
                        mealSlot: MealSlot.lunch, // adjust as desired
                      );
                    },
                  ),
                  const DietCardData(
                    id: 'favorites',
                    title: 'Favorites',
                    subtitle: 'Quick picks',
                    icon: Icons.star,
                  ),
                  const DietCardData(
                    id: 'templates',
                    title: 'Templates',
                    subtitle: 'Breakfast/Lunch/Dinner',
                    icon: Icons.view_module,
                  ),
                ],
                onCreateTap: () => _openLogSheet(context, MealSlot.lunch),
              ),
              const SizedBox(height: 12),
              // ------------------------------------------------------------------------------

              Text(
                dateLabel,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Today', style: TextStyle(fontSize: 28)),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: () {},
                    child: Text(
                      diet.goal.mode.isNotEmpty
                          ? (diet.goal.mode[0].toUpperCase() +
                              diet.goal.mode.substring(1))
                          : 'Goal',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CalorieBar(
                current: currentKcal,
                target: targetKcal,
              ),
              const SizedBox(height: 16),
              _MealCard(
                title: 'Breakfast',
                entries: breakfasts,
                onAdd: () => _openLogSheet(context, MealSlot.breakfast),
              ),
              _MealCard(
                title: 'Lunch',
                entries: lunches,
                onAdd: () => _openLogSheet(context, MealSlot.lunch),
              ),
              _MealCard(
                title: 'Dinner',
                entries: dinners,
                onAdd: () => _openLogSheet(context, MealSlot.dinner),
              ),
              _MealCard(
                title: 'Snacks',
                entries: snacks,
                onAdd: () => _openLogSheet(context, MealSlot.snack),
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  static void _openLogSheet(BuildContext context, MealSlot slot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DietLogSheet(defaultSlot: slot),
    );
  }

  String _weekday(int w) {
    switch (w) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
      default:
        return 'Sun';
    }
  }
}

class _CalorieBar extends StatelessWidget {
  const _CalorieBar({required this.current, required this.target});

  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final pct = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$current / $target kcal'),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.title,
    required this.entries,
    required this.onAdd,
  });

  final String title;
  final List<DietEntry> entries;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add',
                ),
              ],
            ),
            if (entries.isEmpty)
              Text(
                'Nothing logged yet',
                style: TextStyle(color: Colors.grey.shade500),
              )
            else
              ...entries.map(
                (m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${m.calories} kcal'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
