import 'package:hive/hive.dart';

part 'milestone.g.dart';

@HiveType(typeId: 7) // 🧠 Choose a unique typeId for Milestone
class Milestone extends HiveObject {
  @HiveField(0)
  final String statId;

  @HiveField(1)
  final List<int> thresholds;

  @HiveField(2)
  final int? cap;

  Milestone({
    required this.statId,
    this.thresholds = const [1, 5, 10, 50, 100, 500, 1000, 5000, 10000],
    this.cap,
  });

  /// Returns the next milestone not yet reached
  int? getNext(int currentCount) {
    for (final threshold in thresholds) {
      if (threshold > currentCount && (cap == null || threshold <= cap!)) {
        return threshold;
      }
    }
    return null;
  }

  /// Returns whether a given milestone has been achieved
  bool isAchieved(int count, int milestone) {
    return count >= milestone;
  }

  /// Returns all achieved milestones
  List<int> getAchieved(int count) {
    return thresholds
        .where((t) => t <= count && (cap == null || t <= cap!))
        .toList();
  }
}
