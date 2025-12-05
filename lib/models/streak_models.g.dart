// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ObjectiveStreakAdapter extends TypeAdapter<ObjectiveStreak> {
  @override
  final int typeId = 120;

  @override
  ObjectiveStreak read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ObjectiveStreak(
      objectiveId: fields[0] as String,
      current: fields[1] as int,
      best: fields[2] as int,
      lastYmd: fields[3] as int,
      lastBonusYmd: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ObjectiveStreak obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.objectiveId)
      ..writeByte(1)
      ..write(obj.current)
      ..writeByte(2)
      ..write(obj.best)
      ..writeByte(3)
      ..write(obj.lastYmd)
      ..writeByte(4)
      ..write(obj.lastBonusYmd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectiveStreakAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategoryStreakAdapter extends TypeAdapter<CategoryStreak> {
  @override
  final int typeId = 121;

  @override
  CategoryStreak read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryStreak(
      categoryId: fields[0] as String,
      current: fields[1] as int,
      best: fields[2] as int,
      lastFullYmd: fields[3] as int,
      lastClaimYmd: fields[4] as int,
      claimPending: fields[5] as bool,
      pendingXp: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryStreak obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.categoryId)
      ..writeByte(1)
      ..write(obj.current)
      ..writeByte(2)
      ..write(obj.best)
      ..writeByte(3)
      ..write(obj.lastFullYmd)
      ..writeByte(4)
      ..write(obj.lastClaimYmd)
      ..writeByte(5)
      ..write(obj.claimPending)
      ..writeByte(6)
      ..write(obj.pendingXp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryStreakAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DayStreakAdapter extends TypeAdapter<DayStreak> {
  @override
  final int typeId = 122;

  @override
  DayStreak read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DayStreak(
      current: fields[0] as int,
      best: fields[1] as int,
      lastKeptYmd: fields[2] as int,
      lockedRequiredCountYmd: fields[3] as int,
      lockedRequiredCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DayStreak obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.current)
      ..writeByte(1)
      ..write(obj.best)
      ..writeByte(2)
      ..write(obj.lastKeptYmd)
      ..writeByte(3)
      ..write(obj.lockedRequiredCountYmd)
      ..writeByte(4)
      ..write(obj.lockedRequiredCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayStreakAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BonusLedgerDayAdapter extends TypeAdapter<BonusLedgerDay> {
  @override
  final int typeId = 123;

  @override
  BonusLedgerDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BonusLedgerDay(
      ymd: fields[0] as int,
      paidBonusXp: fields[1] as int,
      overflowXp: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BonusLedgerDay obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.ymd)
      ..writeByte(1)
      ..write(obj.paidBonusXp)
      ..writeByte(2)
      ..write(obj.overflowXp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BonusLedgerDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MomentumWalletAdapter extends TypeAdapter<MomentumWallet> {
  @override
  final int typeId = 124;

  @override
  MomentumWallet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MomentumWallet(
      balanceMc: fields[0] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MomentumWallet obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.balanceMc);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MomentumWalletAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SkipReceiptAdapter extends TypeAdapter<SkipReceipt> {
  @override
  final int typeId = 125;

  @override
  SkipReceipt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SkipReceipt(
      objectiveId: fields[0] as String,
      ymd: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SkipReceipt obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.objectiveId)
      ..writeByte(1)
      ..write(obj.ymd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkipReceiptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
