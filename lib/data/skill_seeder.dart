import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/providers/objective_provider.dart';

class SkillSeeder {
  static void seedAll(ObjectiveProvider provider) {
    // RAPPING SKILLS
    _addSkill(
      provider,
      Skill(
        id: 'lyrical_ability',
        label: 'Lyrical Ability',
        categoryId: 'RAPPING',
        weight: 0.5,
        stats: [
          Stat(
            id: 'verses_written',
            label: 'Verses Written',
            averageMinutesPerUnit: 15,
            repsForMastery: 500,
            weight: 1 / 3,
          ),
          Stat(
            id: 'freestyles_recorded',
            label: 'Freestyles Recorded',
            averageMinutesPerUnit: 5,
            repsForMastery: 500,
            weight: 1 / 3,
          ),
          Stat(
            id: 'rhymes_added',
            label: 'Rhymes Added',
            averageMinutesPerUnit: 3,
            repsForMastery: 500,
            weight: 1 / 3,
          ),
        ],
      ),
    );

    _addSkill(
      provider,
      Skill(
        id: 'concept_development',
        label: 'Concept Development',
        categoryId: 'RAPPING',
        weight: 0.5,
        stats: [
          Stat(
            id: 'concepts_brainstormed',
            label: 'Concepts Brainstormed',
            averageMinutesPerUnit: 10,
            repsForMastery: 300,
            weight: 1.0,
          ),
        ],
      ),
    );

    // PRODUCTION SKILLS
    _addSkill(
      provider,
      Skill(
        id: 'beat_making',
        label: 'Beat Making',
        categoryId: 'PRODUCTION',
        weight: 0.5,
        stats: [
          Stat(
            id: 'beats_made',
            label: 'Beats Made',
            averageMinutesPerUnit: 60,
            repsForMastery: 500,
            weight: 0.6,
          ),
          Stat(
            id: 'samples_chopped',
            label: 'Samples Chopped',
            averageMinutesPerUnit: 30,
            repsForMastery: 500,
            weight: 0.4,
          ),
        ],
      ),
    );

    _addSkill(
      provider,
      Skill(
        id: 'distribution',
        label: 'Distribution',
        categoryId: 'PRODUCTION',
        weight: 0.5,
        stats: [
          Stat(
            id: 'beats_sent',
            label: 'Beats Sent',
            averageMinutesPerUnit: 20,
            repsForMastery: 500,
            weight: 0.5,
          ),
          Stat(
            id: 'samples_sent',
            label: 'Samples Sent',
            averageMinutesPerUnit: 15,
            repsForMastery: 500,
            weight: 0.5,
          ),
        ],
      ),
    );

    // HEALTH SKILLS
    _addSkill(
      provider,
      Skill(
        id: 'fitness',
        label: 'Fitness',
        categoryId: 'HEALTH',
        weight: 0.5,
        stats: [
          Stat(
            id: 'workouts_completed',
            label: 'Workouts Completed',
            averageMinutesPerUnit: 45,
            repsForMastery: 300,
            weight: 0.4,
          ),
          Stat(
            id: 'cardio_sessions',
            label: 'Cardio Sessions',
            averageMinutesPerUnit: 20,
            repsForMastery: 300,
            weight: 0.3,
          ),
          Stat(
            id: 'stretch_sessions',
            label: 'Stretch Sessions',
            averageMinutesPerUnit: 10,
            repsForMastery: 300,
            weight: 0.3,
          ),
        ],
      ),
    );

    _addSkill(
      provider,
      Skill(
        id: 'wellbeing',
        label: 'Wellbeing',
        categoryId: 'HEALTH',
        weight: 0.5,
        stats: [
          Stat(
            id: 'mood_logged',
            label: 'Mood Logged',
            averageMinutesPerUnit: 5,
            repsForMastery: 300,
            weight: 0.25,
          ),
          Stat(
            id: 'meditations',
            label: 'Meditations',
            averageMinutesPerUnit: 15,
            repsForMastery: 300,
            weight: 0.25,
          ),
          Stat(
            id: 'water_goal_hit',
            label: 'Water Goal Hit',
            averageMinutesPerUnit: 5,
            repsForMastery: 300,
            weight: 0.25,
          ),
          Stat(
            id: 'diet_successes',
            label: 'Diet Successes',
            averageMinutesPerUnit: 10,
            repsForMastery: 300,
            weight: 0.25,
          ),
        ],
      ),
    );

    // KNOWLEDGE SKILLS
    _addSkill(
      provider,
      Skill(
        id: 'music_education',
        label: 'Music Education',
        categoryId: 'KNOWLEDGE',
        weight: 1.0,
        stats: [
          Stat(
            id: 'tutorials_watched',
            label: 'Tutorials Watched',
            averageMinutesPerUnit: 20,
            repsForMastery: 300,
            weight: 0.25,
          ),
          Stat(
            id: 'music_book_pages',
            label: 'Music Book Pages Read',
            averageMinutesPerUnit: 2,
            repsForMastery: 1000,
            weight: 0.25,
          ),
          Stat(
            id: 'ebwm_pages',
            label: 'EBWM Pages Read',
            averageMinutesPerUnit: 2,
            repsForMastery: 1000,
            weight: 0.25,
          ),
          Stat(
            id: 'songs_memorized',
            label: 'Songs Memorized',
            averageMinutesPerUnit: 30,
            repsForMastery: 200,
            weight: 0.25,
          ),
        ],
      ),
    );

    // NETWORKING SKILLS
    _addSkill(
      provider,
      Skill(
        id: 'outreach',
        label: 'Outreach',
        categoryId: 'NETWORKING',
        weight: 0.5,
        stats: [
          Stat(
            id: 'dms_replied',
            label: 'DMs Replied',
            averageMinutesPerUnit: 2,
            repsForMastery: 500,
            weight: 0.5,
          ),
          Stat(
            id: 'comments_left',
            label: 'Comments Left',
            averageMinutesPerUnit: 3,
            repsForMastery: 500,
            weight: 0.5,
          ),
        ],
      ),
    );

    _addSkill(
      provider,
      Skill(
        id: 'online_presence',
        label: 'Online Presence',
        categoryId: 'NETWORKING',
        weight: 0.5,
        stats: [
          Stat(
            id: 'posts_made',
            label: 'Posts Made',
            averageMinutesPerUnit: 10,
            repsForMastery: 300,
            weight: 0.25,
          ),
          Stat(
            id: 'beats_uploaded',
            label: 'Beats Uploaded',
            averageMinutesPerUnit: 5,
            repsForMastery: 300,
            weight: 0.25,
          ),
          Stat(
            id: 'others_promoted',
            label: 'Others Promoted',
            averageMinutesPerUnit: 3,
            repsForMastery: 300,
            weight: 0.25,
          ),
          Stat(
            id: 'content_ideas',
            label: 'Content Ideas Added',
            averageMinutesPerUnit: 10,
            repsForMastery: 300,
            weight: 0.25,
          ),
        ],
      ),
    );
  }

  static void _addSkill(ObjectiveProvider provider, Skill skill) {
    for (var stat in skill.stats) {
      provider.registerStat(stat);
    }
    provider.registerSkill(skill.id, skill);
  }
}
