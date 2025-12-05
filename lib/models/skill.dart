import 'package:hive/hive.dart';
import 'package:kontinuum/data/level_utils.dart';
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

  /// Weight of this skill within its category (0-1, normalized per category).
  @HiveField(5, defaultValue: 0.0)
  double weight;

  Skill({
    required this.id,
    required this.label,
    required this.categoryId,
    this.xp = 0,
    this.stats = const [],
    this.weight = 0.0,
  });

  /// Total XP required to "master" this skill (weighted share of category cap).
  int get maxXp {
    final cap = LevelUtils.getSkillCap(weight);
    return cap <= 0 ? 1 : cap;
  }

  /// Skill level (1–LevelUtils.maxLevel) based on % of max XP.
  /// Guards:
  /// - maxXp <= 0  → level 1
  /// - negative xp → treated as 0
  /// - xp > maxXp  → clamped to LevelUtils.maxLevel (overcap allowed)
  int get level {
    return LevelUtils.getLevelFromXp(xp, maxXp);
  }

  /// Progress within the **current level** (0.0–1.0).
  /// Uses level thresholds derived from maxXp with full guards.
  double get levelProgress {
    final m = maxXp;
    if (m <= 0) return 0.0;

    final lvl = level; // already clamped (1..LevelUtils.maxLevel)
    if (lvl >= LevelUtils.maxLevel) return 1.0; // at cap

    final startOfLevelXp = LevelUtils.getXpForLevel(lvl, m);
    final endOfLevelXp = LevelUtils.getXpForLevel(lvl + 1, m);
    final span = endOfLevelXp - startOfLevelXp;
    if (span <= 0) return 0.0;

    final progress = (xp.clamp(0, m) - startOfLevelXp) / span;
    return progress.clamp(0.0, 1.0).toDouble();
  }

  Map<String, Stat> get statsById => {for (final stat in stats) stat.id: stat};
}
