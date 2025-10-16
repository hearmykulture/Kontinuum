import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/providers/objective_provider.dart';

class ObjectiveSeeder {
  static const Map<int, bool> everyDay = {
    1: true,
    2: true,
    3: true,
    4: true,
    5: true,
    6: true,
    7: true,
  };

  static void seedAll(ObjectiveProvider provider) {
    provider.addObjective(
      title: "Make 1 beat",
      type: ObjectiveType.standard,
      categoryIds: ['PRODUCTION'],
      statIds: ['beats_made'],
      xpReward: 60,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Write 8+ bars",
      type: ObjectiveType.writingPrompt,
      categoryIds: ['RAPPING'],
      statIds: ['verses_written'],
      xpReward: 10,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Chop 5 samples",
      type: ObjectiveType.tally,
      categoryIds: ['PRODUCTION'],
      statIds: ['samples_chopped'],
      xpReward: 20,
      targetAmount: 5,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Send out beats to 1–3 artists",
      type: ObjectiveType.tally,
      categoryIds: ['PRODUCTION'],
      statIds: ['beats_sent'],
      xpReward: 15,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Send out samples to 1–3 producers",
      type: ObjectiveType.tally,
      categoryIds: ['PRODUCTION'],
      statIds: ['samples_sent'],
      xpReward: 15,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Leave 5 meaningful comments",
      type: ObjectiveType.tally,
      categoryIds: ['NETWORKING'],
      statIds: ['comments_left'],
      xpReward: 10,
      targetAmount: 5,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Post on social media",
      type: ObjectiveType.standard,
      categoryIds: ['NETWORKING'],
      statIds: ['posts_made'],
      xpReward: 10,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Respond to 1+ DM",
      type: ObjectiveType.tally,
      categoryIds: ['NETWORKING'],
      statIds: ['dms_replied'],
      xpReward: 5,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Upload 1 beat",
      type: ObjectiveType.standard,
      categoryIds: ['NETWORKING'],
      statIds: ['beats_uploaded'],
      xpReward: 10,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Repost or promote someone else’s drop",
      type: ObjectiveType.standard,
      categoryIds: ['NETWORKING'],
      statIds: ['others_promoted'],
      xpReward: 10,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Add 1 idea to your content calendar",
      type: ObjectiveType.standard,
      categoryIds: ['NETWORKING'],
      statIds: ['content_ideas'],
      xpReward: 5,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Watch 1–3 tutorials",
      type: ObjectiveType.tally,
      categoryIds: ['KNOWLEDGE'],
      statIds: ['tutorials_watched'],
      xpReward: 15,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Read 10 pages from a music book",
      type: ObjectiveType.tally,
      categoryIds: ['KNOWLEDGE'],
      statIds: ['music_book_pages'],
      xpReward: 10,
      targetAmount: 10,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Read 10 pages of EBWM",
      type: ObjectiveType.tally,
      categoryIds: ['KNOWLEDGE'],
      statIds: ['ebwm_pages'],
      xpReward: 10,
      targetAmount: 10,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Memorize song for 30 mins",
      type: ObjectiveType.stopwatch,
      categoryIds: ['KNOWLEDGE'],
      statIds: ['songs_memorized'],
      xpReward: 30,
      targetAmount: 30,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Complete 1 workout",
      type: ObjectiveType.standard,
      categoryIds: ['HEALTH'],
      statIds: ['workouts_completed'],
      xpReward: 20,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Hit your water goal",
      type: ObjectiveType.standard,
      categoryIds: ['HEALTH'],
      statIds: ['water_goal_hit'],
      xpReward: 10,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Stick to diet goal",
      type: ObjectiveType.standard,
      categoryIds: ['HEALTH'],
      statIds: ['diet_successes'],
      xpReward: 10,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Log your mood & energy",
      type: ObjectiveType.standard,
      categoryIds: ['HEALTH'],
      statIds: ['mood_logged'],
      xpReward: 5,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Do 10+ minutes cardio",
      type: ObjectiveType.stopwatch,
      categoryIds: ['HEALTH'],
      statIds: ['cardio_sessions'],
      xpReward: 10,
      targetAmount: 10,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Meditate or reflect",
      type: ObjectiveType.standard,
      categoryIds: ['HEALTH'],
      statIds: ['meditations'],
      xpReward: 10,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Do 10+ minutes of stretching",
      type: ObjectiveType.stopwatch,
      categoryIds: ['HEALTH'],
      statIds: ['stretch_sessions'],
      xpReward: 10,
      targetAmount: 10,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Freestyle for 5 minutes",
      type: ObjectiveType.stopwatch,
      categoryIds: ['RAPPING'],
      statIds: ['freestyles_recorded'],
      xpReward: 10,
      targetAmount: 5,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Brainstorm 1 concept",
      type: ObjectiveType.standard,
      categoryIds: ['RAPPING'],
      statIds: ['concepts_brainstormed'],
      xpReward: 5,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );

    provider.addObjective(
      title: "Add words/rhymes or metaphors to your bank",
      type: ObjectiveType.standard,
      categoryIds: ['RAPPING'],
      statIds: ['rhymes_added'],
      xpReward: 5,
      targetAmount: 1,
      isStatic: true,
      activeDays: everyDay,
    );
  }
}
