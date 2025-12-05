// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_models_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetHiveAdapter extends TypeAdapter<BudgetHive> {
  @override
  final int typeId = 100;

  @override
  BudgetHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetHive(
      id: fields[0] as String,
      title: fields[1] as String,
      monthlyAmount: fields[2] as int,
      categories: (fields[3] as List).cast<BudgetCategoryHive>(),
      recurrings: (fields[4] as List).cast<RecurringExpenseHive>(),
      unallocatedAsSavings: fields[5] as bool,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetHive obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.monthlyAmount)
      ..writeByte(3)
      ..write(obj.categories)
      ..writeByte(4)
      ..write(obj.recurrings)
      ..writeByte(5)
      ..write(obj.unallocatedAsSavings)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BudgetCategoryHiveAdapter extends TypeAdapter<BudgetCategoryHive> {
  @override
  final int typeId = 101;

  @override
  BudgetCategoryHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetCategoryHive(
      name: fields[0] as String,
      iconCodePoint: fields[1] as int,
      colorValue: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetCategoryHive obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.iconCodePoint)
      ..writeByte(2)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetCategoryHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecurringExpenseHiveAdapter extends TypeAdapter<RecurringExpenseHive> {
  @override
  final int typeId = 102;

  @override
  RecurringExpenseHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringExpenseHive(
      name: fields[0] as String,
      amountCents: fields[1] as int,
      cadence: fields[2] as int,
      iconCodePoint: fields[3] as int,
      colorValue: fields[4] as int,
      categoryName: fields[5] as String?,
      weekdayMask: fields[6] as int?,
      monthlyDay: fields[7] as int?,
      yearlyMonth: fields[8] as int?,
      yearlyDay: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringExpenseHive obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.amountCents)
      ..writeByte(2)
      ..write(obj.cadence)
      ..writeByte(3)
      ..write(obj.iconCodePoint)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.categoryName)
      ..writeByte(6)
      ..write(obj.weekdayMask)
      ..writeByte(7)
      ..write(obj.monthlyDay)
      ..writeByte(8)
      ..write(obj.yearlyMonth)
      ..writeByte(9)
      ..write(obj.yearlyDay);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringExpenseHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
