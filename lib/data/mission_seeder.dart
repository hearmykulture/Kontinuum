import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/providers/mission_provider.dart';

class MissionSeeder {
  /// Use if you want a list directly (e.g., for loadMissions)
  static List<Mission> seed() {
    return [
      Mission(
        id: 'm1',
        title: 'Produce 3 beats in a week',
        description: 'Challenge yourself to make 3 solid beats this week.',
        categoryIds: ['PRODUCTION'],
        statIds: ['beats_made'],
        xpReward: 180,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm2',
        title: 'Write 16 bars every day for 3 days',
        description: 'Keep your pen moving and write a verse daily.',
        categoryIds: ['RAPPING'],
        statIds: ['verses_written'],
        xpReward: 120,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm3',
        title: 'Study 3 tutorials',
        description: 'Absorb new techniques to level up your craft.',
        categoryIds: ['KNOWLEDGE'],
        statIds: ['tutorials_watched'],
        xpReward: 90,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm4',
        title: 'Upload 5 beats to your online store',
        description: 'Get your content out there and monetize it.',
        categoryIds: ['PRODUCTION', 'NETWORKING'],
        statIds: ['beats_uploaded'],
        xpReward: 150,
        rarity: MissionRarity.rare,
      ),
      Mission(
        id: 'm5',
        title: 'Freestyle 10 minutes every day for a week',
        description: 'Sharpen your off-the-dome ability.',
        categoryIds: ['RAPPING'],
        statIds: ['freestyles_recorded'],
        xpReward: 300,
        rarity: MissionRarity.rare,
      ),
      Mission(
        id: 'm6',
        title: 'Run a promo push: repost, post & comment',
        description:
            'Promote others & stay visible — repost, comment, and post.',
        categoryIds: ['NETWORKING'],
        statIds: ['others_promoted', 'posts_made', 'comments_left'],
        xpReward: 200,
        rarity: MissionRarity.rare,
      ),
      Mission(
        id: 'm7',
        title: 'Complete 5 workouts',
        description: 'Stay consistent with your health goals.',
        categoryIds: ['HEALTH'],
        statIds: ['workouts_completed'],
        xpReward: 100,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm8',
        title: 'Write 10 metaphors or punchlines',
        description: 'Work on your lyrical technique bank.',
        categoryIds: ['RAPPING'],
        statIds: ['rhymes_added'],
        xpReward: 70,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm9',
        title: 'Memorize 3 rap verses',
        description: 'Study flow, delivery, and bars from your favorites.',
        categoryIds: ['KNOWLEDGE'],
        statIds: ['songs_memorized'],
        xpReward: 120,
        rarity: MissionRarity.rare,
      ),
      Mission(
        id: 'm10',
        title: 'Brainstorm your next EP concept',
        description:
            'Plan out a cohesive project: titles, ideas, and core message.',
        categoryIds: ['RAPPING'],
        statIds: ['concepts_brainstormed'],
        xpReward: 150,
        rarity: MissionRarity.legendary,
      ),
      Mission(
        id: 'm11',
        title: 'Record a full demo track',
        description:
            'Lay down a rough version of a full track from start to finish.',
        categoryIds: ['RAPPING', 'PRODUCTION'],
        statIds: ['songs_recorded'],
        xpReward: 250,
        rarity: MissionRarity.rare,
      ),
      Mission(
        id: 'm12',
        title: 'Learn a new DAW shortcut or technique',
        description: 'Speed up your workflow by mastering a new trick.',
        categoryIds: ['KNOWLEDGE'],
        statIds: ['techniques_learned'],
        xpReward: 60,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm13',
        title: 'Connect with 2 new artists online',
        description: 'Expand your circle. Message, comment, or collab.',
        categoryIds: ['NETWORKING'],
        statIds: ['artists_connected'],
        xpReward: 130,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm14',
        title: 'Stretch for 10 minutes every morning for 5 days',
        description: 'Start each day with clarity and flexibility.',
        categoryIds: ['HEALTH'],
        statIds: ['stretch_sessions'],
        xpReward: 100,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm15',
        title: 'Design a new beat tag or sound ID',
        description: 'Craft your sonic signature — a memorable producer tag.',
        categoryIds: ['PRODUCTION'],
        statIds: ['tags_created'],
        xpReward: 150,
        rarity: MissionRarity.rare,
      ),
      Mission(
        id: 'm16',
        title: 'Write 3 verses using storytelling',
        description: 'Create vivid scenes and characters in your bars.',
        categoryIds: ['RAPPING'],
        statIds: ['story_verses_written'],
        xpReward: 140,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm17',
        title: 'Read a music business article or book chapter',
        description: 'Sharpen your industry knowledge and mindset.',
        categoryIds: ['KNOWLEDGE'],
        statIds: ['business_articles_read'],
        xpReward: 80,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm18',
        title: 'Cook a healthy meal from scratch',
        description: 'Fuel your body with something nourishing.',
        categoryIds: ['HEALTH'],
        statIds: ['meals_cooked'],
        xpReward: 90,
        rarity: MissionRarity.common,
      ),
      Mission(
        id: 'm19',
        title: 'Post a beat or verse online',
        description: 'Put yourself out there — share your work publicly.',
        categoryIds: ['PRODUCTION', 'NETWORKING'],
        statIds: ['posts_made'],
        xpReward: 120,
        rarity: MissionRarity.rare,
      ),
      Mission(
        id: 'm20',
        title: 'Write a hook using a double entendre',
        description: 'Flex layered meaning in your chorus writing.',
        categoryIds: ['RAPPING'],
        statIds: ['double_entendres_written'],
        xpReward: 160,
        rarity: MissionRarity.legendary,
      ),
    ];
  }

  /// Use this if you want to add them directly to a provider
  static void seedAll(MissionProvider provider) {
    for (final mission in seed()) {
      provider.addMission(mission);
    }
  }
}
