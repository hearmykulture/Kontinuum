// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diet_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DietEntryAdapter extends TypeAdapter<DietEntry> {
  @override
  final int typeId = 240;

  @override
  DietEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      mealSlot: fields[2] as MealSlot,
      name: fields[3] as String,
      calories: fields[4] as int,
      protein: fields[5] as double,
      carbs: fields[6] as double,
      fats: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DietEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.mealSlot)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.calories)
      ..writeByte(5)
      ..write(obj.protein)
      ..writeByte(6)
      ..write(obj.carbs)
      ..writeByte(7)
      ..write(obj.fats);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DietGoalAdapter extends TypeAdapter<DietGoal> {
  @override
  final int typeId = 241;

  @override
  DietGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietGoal(
      caloriesTarget: fields[0] as int,
      proteinTarget: fields[1] as double,
      carbsTarget: fields[2] as double,
      fatsTarget: fields[3] as double,
      mode: fields[4] as String,
      baseCalories: fields[5] as int?,
      name: fields[6] as String?,
      fastingHours: fields[7] as double?,
      enabledSlots: (fields[8] as List?)?.cast<MealSlot>(),
      slotLabels: (fields[9] as Map?)?.cast<int, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DietGoal obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.caloriesTarget)
      ..writeByte(1)
      ..write(obj.proteinTarget)
      ..writeByte(2)
      ..write(obj.carbsTarget)
      ..writeByte(3)
      ..write(obj.fatsTarget)
      ..writeByte(4)
      ..write(obj.mode)
      ..writeByte(5)
      ..write(obj.baseCalories)
      ..writeByte(6)
      ..write(obj.name)
      ..writeByte(7)
      ..write(obj.fastingHours)
      ..writeByte(8)
      ..write(obj.enabledSlots)
      ..writeByte(9)
      ..write(obj.slotLabels);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DietFoodAdapter extends TypeAdapter<DietFood> {
  @override
  final int typeId = 242;

  @override
  DietFood read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietFood(
      id: fields[0] as String,
      name: fields[1] as String,
      calories: fields[2] as int,
      protein: fields[3] as double,
      carbs: fields[4] as double,
      fats: fields[5] as double,
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DietFood obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.calories)
      ..writeByte(3)
      ..write(obj.protein)
      ..writeByte(4)
      ..write(obj.carbs)
      ..writeByte(5)
      ..write(obj.fats)
      ..writeByte(6)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietFoodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealSlotAdapter extends TypeAdapter<MealSlot> {
  @override
  final int typeId = 239;

  @override
  MealSlot read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MealSlot.breakfast;
      case 1:
        return MealSlot.lunch;
      case 2:
        return MealSlot.dinner;
      case 3:
        return MealSlot.snack;
      default:
        return MealSlot.breakfast;
    }
  }

  @override
  void write(BinaryWriter writer, MealSlot obj) {
    switch (obj) {
      case MealSlot.breakfast:
        writer.writeByte(0);
        break;
      case MealSlot.lunch:
        writer.writeByte(1);
        break;
      case MealSlot.dinner:
        writer.writeByte(2);
        break;
      case MealSlot.snack:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealSlotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
