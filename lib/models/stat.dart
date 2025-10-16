import 'package:hive/hive.dart';

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

  Stat({
    required this.id,
    required this.label,
    this.count = 0,
    this.xp = 0,
    required this.averageMinutesPerUnit,
    required this.repsForMastery,
  });

  /// Max XP needed to master this stat
  int get maxXp => averageMinutesPerUnit * repsForMastery;

  /// Derived level based on this stat's custom XP curve
  int get level => (xp / maxXp * 100).clamp(1, 100).toInt();

  /// Progress toward next level
  double get levelProgress {
    final levelXp = (level / 100 * maxXp).toInt();
    final nextXp = ((level + 1) / 100 * maxXp).toInt();
    return ((xp - levelXp) / (nextXp - levelXp)).clamp(0.0, 1.0);
  }
}
