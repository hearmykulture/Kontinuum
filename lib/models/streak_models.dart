import 'package:hive/hive.dart';

part 'streak_models.g.dart';

// NOTE: Hive typeIds must be 0..223. We use 120..125 here.
// Make sure these don't collide with your existing model typeIds.

@HiveType(typeId: 120)
class ObjectiveStreak extends HiveObject {
  @HiveField(0)
  String objectiveId;
  @HiveField(1)
  int current; // consecutive days
  @HiveField(2)
  int best; // personal best
  @HiveField(3)
  int lastYmd; // last date completed (YYYYMMDD)
  @HiveField(4)
  int lastBonusYmd; // guard: pay bonus only once per day

  ObjectiveStreak({
    required this.objectiveId,
    this.current = 0,
    this.best = 0,
    this.lastYmd = 0,
    this.lastBonusYmd = 0,
  });
}

@HiveType(typeId: 121)
class CategoryStreak extends HiveObject {
  @HiveField(0)
  String categoryId;
  @HiveField(1)
  int current;
  @HiveField(2)
  int best;
  @HiveField(3)
  int lastFullYmd; // last date all tasks were completed
  @HiveField(4)
  int lastClaimYmd; // last date a claim was paid
  @HiveField(5)
  bool claimPending; // “tap to collect” visible today
  @HiveField(6)
  int pendingXp; // amount to pay if claimed

  CategoryStreak({
    required this.categoryId,
    this.current = 0,
    this.best = 0,
    this.lastFullYmd = 0,
    this.lastClaimYmd = 0,
    this.claimPending = false,
    this.pendingXp = 0,
  });
}

@HiveType(typeId: 122)
class DayStreak extends HiveObject {
  @HiveField(0)
  int current;
  @HiveField(1)
  int best;
  @HiveField(2)
  int lastKeptYmd; // last date the day-streak was kept
  @HiveField(3)
  int lockedRequiredCountYmd; // date the lock belongs to
  @HiveField(4)
  int lockedRequiredCount; // tasks required that day

  DayStreak({
    this.current = 0,
    this.best = 0,
    this.lastKeptYmd = 0,
    this.lockedRequiredCountYmd = 0,
    this.lockedRequiredCount = 0,
  });
}

@HiveType(typeId: 123)
class BonusLedgerDay extends HiveObject {
  @HiveField(0)
  int ymd;
  @HiveField(1)
  int paidBonusXp; // already counted toward today’s pool
  @HiveField(2)
  int overflowXp; // converted to MC

  BonusLedgerDay({
    required this.ymd,
    this.paidBonusXp = 0,
    this.overflowXp = 0,
  });
}

@HiveType(typeId: 124)
class MomentumWallet extends HiveObject {
  @HiveField(0)
  int balanceMc;

  MomentumWallet({this.balanceMc = 0});
}

@HiveType(typeId: 125)
class SkipReceipt extends HiveObject {
  @HiveField(0)
  String objectiveId;
  @HiveField(1)
  int ymd;

  SkipReceipt({required this.objectiveId, required this.ymd});
}
