import 'package:hive/hive.dart';

part 'stat_history_entry.g.dart';

@HiveType(typeId: 9)
class StatHistoryEntry extends HiveObject {
  @HiveField(0)
  final String statId;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final int amount;

  @HiveField(3)
  final String? skillId; // 🟣 New field

  StatHistoryEntry({
    required this.statId,
    required this.date,
    required this.amount,
    this.skillId,
  });
}
