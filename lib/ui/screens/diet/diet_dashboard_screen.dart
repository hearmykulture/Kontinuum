// lib/ui/screens/diet/diet_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/models/diet_models.dart';
import 'package:kontinuum/ui/screens/diet/diet_dashboard_widget.dart';
import 'package:kontinuum/ui/screens/diet/diet_log_sheet.dart';
import 'package:kontinuum/ui/screens/diet/fdc_food_search_sheet.dart';
import 'package:kontinuum/ui/screens/diet/create_diet_screen.dart';
import 'package:kontinuum/ui/workout/workout_dashboard_screen.dart';
import 'package:kontinuum/ui/screens/progress_screen.dart'; // ✅ Go to Progress
import 'package:kontinuum/core/time/app_clock.dart';

class DietDashboardScreen extends StatefulWidget {
  const DietDashboardScreen({
    super.key,
    this.onClose,
  });

  /// (Legacy) Optional close hook. Pressing the X now always routes to Progress.
  final VoidCallback? onClose;

  @override
  State<DietDashboardScreen> createState() => _DietDashboardScreenState();
}

class _DietDashboardScreenState extends State<DietDashboardScreen> {
  DateTime _selectedDate = AppClock.now();

  // Float the corner buttons upward into the safe area/notch area
  static const double _cornerLift = -16.0;

  void _openLogSheet(MealSlot slot) {
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

  void _goToWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WorkoutDashboardScreen(),
        settings: const RouteSettings(name: 'workout_dashboard_from_diet'),
      ),
    );
  }

  void _goToProgress() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ProgressScreen(),
        settings: const RouteSettings(name: 'progress_from_diet_close'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none, // allow the corner icons to float higher
          children: [
            Consumer<DietProvider>(
              builder: (context, diet, _) {
                final date = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                );

                // Use ListView like WorkoutDashboardScreen so top position matches exactly
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    DietDashboardWidget(
                      selectedDate: date,
                      getProgressForDay: (day) {
                        final target = diet.goal.caloriesTarget;
                        if (target <= 0) return 0.0;
                        final cals = diet.caloriesForDay(day);
                        return cals / target.clamp(0.0, 1.0);
                      },
                      onDateSelected: (d) => setState(() => _selectedDate = d),

                      // Optional tiles inside the widget
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
                              mealSlot: MealSlot.lunch,
                            );
                          },
                        ),
                        DietCardData(
                          id: 'quick_log',
                          title: 'Quick Log',
                          subtitle: 'Add to Lunch',
                          icon: Icons.add,
                          onTap: () => _openLogSheet(MealSlot.lunch),
                        ),
                      ],

                      // Navigate to CreateDietScreen on "Create"
                      onCreateTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CreateDietScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),

            // Top-left cross-nav to Workout (dumbbell) — raised higher
            Positioned(
              top: _cornerLift,
              left: 8,
              child: IconButton(
                tooltip: 'Workouts',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x33000000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.fitness_center),
                onPressed: _goToWorkout,
              ),
            ),

            // Close (“X”) — routes to Progress
            Positioned(
              top: _cornerLift,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x33000000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.close),
                onPressed: _goToProgress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
