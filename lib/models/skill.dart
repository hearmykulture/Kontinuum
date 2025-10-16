import 'package:hive/hive.dart';
import 'stat.dart';

part 'skill.g.dart';

@HiveType(typeId: 5)
class Skill extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String label;

  @HiveField(2)
  final String categoryId;

  @HiveField(3)
  int xp;

  @HiveField(4)
  final List<Stat> stats;

  Skill({
    required this.id,
    required this.label,
    required this.categoryId,
    this.xp = 0,
    this.stats = const [],
  });

  /// Total XP required to "master" this skill
  int get maxXp => stats.fold(0, (sum, stat) => sum + stat.maxXp);

  /// Skill level (1–100), based on % of max XP
  int get level => (xp / maxXp * 100).clamp(1, 100).toInt();

  /// Progress toward next level
  double get levelProgress {
    final levelXp = (level / 100 * maxXp).toInt();
    final nextXp = ((level + 1) / 100 * maxXp).toInt();
    return ((xp - levelXp) / (nextXp - levelXp)).clamp(0.0, 1.0);
  }

  Map<String, Stat> get statsById => {for (final stat in stats) stat.id: stat};
}
