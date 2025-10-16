import 'dart:ui';
import 'package:hive/hive.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/data/level_utils.dart';

part 'category.g.dart';

@HiveType(typeId: 4)
class Category extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  int xp;

  @HiveField(3)
  final List<Skill> skills;

  /// ARGB color for this category (nullable for legacy records)
  @HiveField(4)
  int? colorInt;

  Category({
    required this.id,
    required this.name,
    this.xp = 0,
    this.skills = const [],
    this.colorInt,
  });

  /// Category levels use a fixed 600,000 XP curve (10,000-hour mastery)
  int get level => LevelUtils.getCategoryLevelFromXp(xp);

  String get prestigeTitle => LevelUtils.getPrestigeTitle(level).title;
  String get prestigeColor => LevelUtils.getPrestigeTitle(level).color;

  Color? get color => colorInt == null ? null : Color(colorInt!);

  Map<String, Skill> get skillsById => {
    for (final skill in skills) skill.id: skill,
  };
}
