import 'package:hive/hive.dart';
import 'package:kontinuum/data/level_utils.dart';

part 'stat.g.dart';

@HiveType(typeId: 6)
class Stat extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String label;

  @HiveField(2)
  int count;

  @HiveField(3)
  int xp;

  @HiveField(4)
  final int averageMinutesPerUnit;

  @HiveField(5)
  final int repsForMastery;

  /// Weight of this stat within its parent skill (0-1, normalized per skill).
  @HiveField(6, defaultValue: 0.0)
  double weight;

  /// Snapshot of the parent skill's weight used to derive this stat's cap.
  @HiveField(7, defaultValue: 0.0)
  double parentSkillWeight;

  /// Canonical category this stat belongs to (e.g. PRODUCTION).
  @HiveField(8, defaultValue: null)
  String? categoryId;

  /// Optional emoji displayed in stat chips.
  @HiveField(9, defaultValue: null)
  String? emoji;

  /// Optional description supplied by the user.
  @HiveField(10, defaultValue: null)
  String? description;

  Stat({
    required this.id,
    required this.label,
    this.count = 0,
    this.xp = 0,
    required this.averageMinutesPerUnit,
    required this.repsForMastery,
    this.weight = 0.0,
    this.parentSkillWeight = 0.0,
    this.categoryId,
    this.emoji,
    this.description,
  });

  /// Max XP needed to master this stat (weighted share of its skill cap).
  int get maxXp {
    // Legacy stats can have missing weights; default them to 1.0 so they scale
    // with the parent skill cap instead of falling back to per-minute curves.
    final double skillW = (parentSkillWeight > 0) ? parentSkillWeight : 1.0;
    final double statW = (weight > 0) ? weight : 1.0;

    final cap = LevelUtils.getStatCap(skillW, statW);
    if (cap > 0) return cap;
    // Fallback to legacy per-unit curve if weights are missing
    final legacy = averageMinutesPerUnit * repsForMastery;
    return legacy <= 0 ? 1 : legacy;
  }

  /// Derived level based on this stat's custom XP curve
  int get level {
    return LevelUtils.getLevelFromXp(xp, maxXp);
  }

  /// Progress toward next level
  double get levelProgress {
    final m = maxXp;
    if (m <= 0) return 0.0;
    final lvl = level;
    if (lvl >= LevelUtils.maxLevel) return 1.0;
    final levelXp = LevelUtils.getXpForLevel(lvl, m);
    final nextXp = LevelUtils.getXpForLevel(lvl + 1, m);
    final denom = nextXp - levelXp;
    if (denom <= 0) return 0.0;
    final progress = (xp - levelXp) / denom;
    return progress.clamp(0.0, 1.0);
  }
}
