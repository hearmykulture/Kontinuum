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

  /// Total XP required to "master" this skill (sum of child stat ceilings).
  int get maxXp => stats.fold<int>(0, (sum, stat) => sum + stat.maxXp);

  /// Skill level (1–100) based on % of max XP.
  /// Guards:
  /// - maxXp <= 0  → level 1
  /// - negative xp → treated as 0
  /// - xp > maxXp  → clamped to 100
  int get level {
    final m = maxXp;
    if (m <= 0) return 1;
    final ratio = (xp.clamp(0, m) / m);
    return (ratio * 100).clamp(1.0, 100.0).toInt();
  }

  /// Progress within the **current level** (0.0–1.0).
  /// Uses level thresholds derived from maxXp with full guards.
  double get levelProgress {
    final m = maxXp;
    if (m <= 0) return 0.0;

    final lvl = level; // already clamped (1..100)
    if (lvl >= 100) return 1.0; // at cap

    final startOfLevelXp = (((lvl - 1) / 100.0) * m).toInt();
    final endOfLevelXp = ((lvl / 100.0) * m).toInt();
    final span = (endOfLevelXp - startOfLevelXp);
    if (span <= 0) return 0.0;

    final pos = (xp.clamp(0, m) - startOfLevelXp);
    return (pos / span).clamp(0.0, 1.0).toDouble();
  }

  Map<String, Stat> get statsById => {for (final stat in stats) stat.id: stat};
}
