import 'package:flutter/material.dart';

import 'package:kontinuum/services/analytics_service.dart';
import 'package:kontinuum/core/analytics/analytics_events.dart';

/// Big pill button that sits in ProgressScreen under the calendar scrubber
/// and above "Objectives".
///
/// - Logs analytics: progress_workout_button_tapped
/// - Navigates to /workout
///
/// Styling matches the dark / blue-black surface vibe.
class WorkoutEntryButton extends StatelessWidget {
  const WorkoutEntryButton({super.key});

  void _handleTap(BuildContext context) {
    // analytics
    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.progressWorkoutButtonTapped,
      {
        'source': 'progress_screen',
        'targetRoute': '/workout',
      },
    );

    // nav
    Navigator.of(context).pushNamed('/workout');
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0E1320); // blue-black surface
    final border = const Color(0xFF273043).withValues(alpha: .4);
    final textMain = const Color(0xFFF5F7FA);
    final textSub = const Color(0xFF9AA4B2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  color: Colors.black.withValues(alpha: .6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left icon bubble
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: .4),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.fitness_center,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workout',
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Start / continue a training session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSub,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: textMain.withValues(alpha: .8),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
