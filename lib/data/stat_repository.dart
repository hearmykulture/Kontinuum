class StatMetadata {
  final String id;
  final String label;
  final String? emoji;
  final String? description;
  final String categoryId;

  const StatMetadata({
    required this.id,
    required this.label,
    required this.categoryId,
    this.emoji,
    this.description,
  });

  String get display => "${emoji ?? ''} $label".trim();
}

class StatRepository {
  static final Map<String, StatMetadata> _stats = {
    'beats_made': const StatMetadata(
      id: 'beats_made',
      label: 'Beats Made',
      emoji: '🎧',
      description: 'Completed full beats',
      categoryId: 'PRODUCTION',
    ),
    'samples_chopped': const StatMetadata(
      id: 'samples_chopped',
      label: 'Samples Chopped',
      emoji: '🔪',
      categoryId: 'PRODUCTION',
    ),
    'beats_sent': const StatMetadata(
      id: 'beats_sent',
      label: 'Beats Sent',
      emoji: '📩',
      categoryId: 'PRODUCTION',
    ),
    'samples_sent': const StatMetadata(
      id: 'samples_sent',
      label: 'Samples Sent',
      emoji: '🧃',
      categoryId: 'PRODUCTION',
    ),
    'comments_left': const StatMetadata(
      id: 'comments_left',
      label: 'Comments Left',
      emoji: '💬',
      categoryId: 'NETWORKING',
    ),
    'posts_made': const StatMetadata(
      id: 'posts_made',
      label: 'Social Posts',
      emoji: '📱',
      categoryId: 'NETWORKING',
    ),
    'dms_replied': const StatMetadata(
      id: 'dms_replied',
      label: 'DMs Replied',
      emoji: '📨',
      categoryId: 'NETWORKING',
    ),
    'beats_uploaded': const StatMetadata(
      id: 'beats_uploaded',
      label: 'Beats Uploaded',
      emoji: '☁️',
      categoryId: 'PRODUCTION',
    ),
    'others_promoted': const StatMetadata(
      id: 'others_promoted',
      label: 'Reposts/Promos',
      emoji: '🔁',
      categoryId: 'NETWORKING',
    ),
    'content_ideas': const StatMetadata(
      id: 'content_ideas',
      label: 'Ideas Added',
      emoji: '🧠',
      categoryId: 'CONTENT',
    ),
    'tutorials_watched': const StatMetadata(
      id: 'tutorials_watched',
      label: 'Tutorials Watched',
      emoji: '🎥',
      categoryId: 'KNOWLEDGE',
    ),
    'music_book_pages': const StatMetadata(
      id: 'music_book_pages',
      label: 'Pages (Music Book)',
      emoji: '📚',
      categoryId: 'KNOWLEDGE',
    ),
    'ebwm_pages': const StatMetadata(
      id: 'ebwm_pages',
      label: 'Pages (EBWM)',
      emoji: '🧾',
      categoryId: 'KNOWLEDGE',
    ),
    'songs_memorized': const StatMetadata(
      id: 'songs_memorized',
      label: 'Songs Memorized',
      emoji: '🧠',
      categoryId: 'KNOWLEDGE',
    ),
    'workouts_completed': const StatMetadata(
      id: 'workouts_completed',
      label: 'Workouts',
      emoji: '🏋🏽',
      categoryId: 'HEALTH',
    ),
    'water_goal_hit': const StatMetadata(
      id: 'water_goal_hit',
      label: 'Water Goal',
      emoji: '💧',
      categoryId: 'HEALTH',
    ),
    'diet_successes': const StatMetadata(
      id: 'diet_successes',
      label: 'Diet Successes',
      emoji: '🥗',
      categoryId: 'HEALTH',
    ),
    'mood_logged': const StatMetadata(
      id: 'mood_logged',
      label: 'Mood Logged',
      emoji: '📓',
      categoryId: 'HEALTH',
    ),
    'cardio_sessions': const StatMetadata(
      id: 'cardio_sessions',
      label: 'Cardio Sessions',
      emoji: '🏃🏽',
      categoryId: 'HEALTH',
    ),
    'meditations': const StatMetadata(
      id: 'meditations',
      label: 'Meditated',
      emoji: '🧘🏽',
      categoryId: 'HEALTH',
    ),
    'stretch_sessions': const StatMetadata(
      id: 'stretch_sessions',
      label: 'Stretching',
      emoji: '🧎🏽',
      categoryId: 'HEALTH',
    ),
    'verses_written': const StatMetadata(
      id: 'verses_written',
      label: 'Bars Written',
      emoji: '✍🏽',
      categoryId: 'RAPPING',
    ),
    'freestyles_recorded': const StatMetadata(
      id: 'freestyles_recorded',
      label: 'Freestyles',
      emoji: '🎙️',
      categoryId: 'RAPPING',
    ),
    'concepts_brainstormed': const StatMetadata(
      id: 'concepts_brainstormed',
      label: 'Concepts Brainstormed',
      emoji: '💡',
      categoryId: 'RAPPING',
    ),
    'rhymes_added': const StatMetadata(
      id: 'rhymes_added',
      label: 'Rhymes/Metaphors Added',
      emoji: '📔',
      categoryId: 'RAPPING',
    ),
  };

  static StatMetadata? getById(String id) => _stats[id];

  static String getDisplay(String id) {
    return _stats[id]?.display ?? id;
  }

  static String? getCategoryForStat(String id) {
    return _stats[id]?.categoryId;
  }

  static List<StatMetadata> getAll() => _stats.values.toList();

  static List<StatMetadata> getByCategory(String categoryId) {
    return _stats.values
        .where((stat) => stat.categoryId == categoryId)
        .toList();
  }
}
