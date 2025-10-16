import 'package:kontinuum/models/milestone.dart';
import 'package:kontinuum/providers/objective_provider.dart';

class MilestoneSeeder {
  static void seedAll(ObjectiveProvider provider) {
    final defaultThresholds = [1, 5, 10, 50, 100, 500, 1000, 5000, 10000];

    // Stats
    for (final statId in provider.stats.keys) {
      provider.registerMilestone(
        Milestone(statId: statId, thresholds: defaultThresholds),
      );
    }

    // Skills
    for (final skill in provider.skills.values) {
      provider.registerMilestone(
        Milestone(statId: skill.id, thresholds: defaultThresholds),
      );
    }

    // Categories
    for (final category in provider.categories.values) {
      provider.registerMilestone(
        Milestone(statId: category.id, thresholds: defaultThresholds),
      );
    }
  }
}
