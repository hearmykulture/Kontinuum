import 'package:hive/hive.dart';

part 'mission.g.dart';

@HiveType(typeId: 12) // 🧠 Use a unique typeId
enum MissionRarity {
  @HiveField(0)
  common,
  @HiveField(1)
  rare,
  @HiveField(2)
  legendary,
}

@HiveType(typeId: 13)
class Mission extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final List<String> categoryIds;

  @HiveField(4)
  final List<String> statIds;

  @HiveField(5)
  final int xpReward;

  @HiveField(6)
  final MissionRarity rarity;

  @HiveField(7)
  bool isCompleted;

  @HiveField(8)
  bool recommendedBySmartSuggestion;

  @HiveField(9)
  int timesRecommended;

  @HiveField(10)
  bool isAccepted;

  Mission({
    required this.id,
    required this.title,
    this.description,
    required this.categoryIds,
    required this.statIds,
    required this.xpReward,
    this.rarity = MissionRarity.common,
    this.isCompleted = false,
    this.recommendedBySmartSuggestion = false,
    this.timesRecommended = 0,
    this.isAccepted = false,
  });

  Mission copyWith({
    String? title,
    String? description,
    List<String>? categoryIds,
    List<String>? statIds,
    int? xpReward,
    MissionRarity? rarity,
    bool? isCompleted,
    bool? recommendedBySmartSuggestion,
    int? timesRecommended,
    bool? isAccepted,
  }) {
    return Mission(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryIds: categoryIds ?? this.categoryIds,
      statIds: statIds ?? this.statIds,
      xpReward: xpReward ?? this.xpReward,
      rarity: rarity ?? this.rarity,
      isCompleted: isCompleted ?? this.isCompleted,
      recommendedBySmartSuggestion:
          recommendedBySmartSuggestion ?? this.recommendedBySmartSuggestion,
      timesRecommended: timesRecommended ?? this.timesRecommended,
      isAccepted: isAccepted ?? this.isAccepted,
    );
  }
}
