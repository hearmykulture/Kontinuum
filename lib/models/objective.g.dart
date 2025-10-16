// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'objective.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ObjectiveAdapter extends TypeAdapter<Objective> {
  @override
  final int typeId = 3;

  @override
  Objective read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Objective(
      id: fields[0] as String,
      title: fields[1] as String,
      type: fields[2] as ObjectiveType,
      categoryIds: (fields[3] as List).cast<String>(),
      statIds: (fields[4] as List).cast<String>(),
      targetAmount: fields[5] as int,
      xpReward: fields[6] as int,
      activeDays: (fields[7] as Map).cast<int, bool>(),
      subtaskIds: (fields[8] as List).cast<String>(),
      prerequisiteIds: (fields[9] as List).cast<String>(),
      description: fields[10] as String?,
      writingBlockId: fields[11] as String?,
      isLocked: fields[12] as bool,
      lockedReason: fields[13] as String?,
      completedAmount: fields[14] as int,
      isCompleted: fields[15] as bool,
      actualXpEarned: fields[16] as int?,
      completedOn: fields[17] as DateTime?,
      completedAmounts: (fields[18] as Map?)?.cast<String, int>(),
      repeatEveryNDays: fields[19] as int?,
      repeatAnchorDate: fields[20] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Objective obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.categoryIds)
      ..writeByte(4)
      ..write(obj.statIds)
      ..writeByte(5)
      ..write(obj.targetAmount)
      ..writeByte(6)
      ..write(obj.xpReward)
      ..writeByte(7)
      ..write(obj.activeDays)
      ..writeByte(8)
      ..write(obj.subtaskIds)
      ..writeByte(9)
      ..write(obj.prerequisiteIds)
      ..writeByte(10)
      ..write(obj.description)
      ..writeByte(11)
      ..write(obj.writingBlockId)
      ..writeByte(12)
      ..write(obj.isLocked)
      ..writeByte(13)
      ..write(obj.lockedReason)
      ..writeByte(14)
      ..write(obj.completedAmount)
      ..writeByte(15)
      ..write(obj.isCompleted)
      ..writeByte(16)
      ..write(obj.actualXpEarned)
      ..writeByte(17)
      ..write(obj.completedOn)
      ..writeByte(18)
      ..write(obj.completedAmounts)
      ..writeByte(19)
      ..write(obj.repeatEveryNDays)
      ..writeByte(20)
      ..write(obj.repeatAnchorDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ObjectiveTypeAdapter extends TypeAdapter<ObjectiveType> {
  @override
  final int typeId = 2;

  @override
  ObjectiveType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ObjectiveType.standard;
      case 1:
        return ObjectiveType.tally;
      case 2:
        return ObjectiveType.writingPrompt;
      case 3:
        return ObjectiveType.stopwatch;
      case 4:
        return ObjectiveType.subtask;
      case 5:
        return ObjectiveType.reflective;
      default:
        return ObjectiveType.standard;
    }
  }

  @override
  void write(BinaryWriter writer, ObjectiveType obj) {
    switch (obj) {
      case ObjectiveType.standard:
        writer.writeByte(0);
        break;
      case ObjectiveType.tally:
        writer.writeByte(1);
        break;
      case ObjectiveType.writingPrompt:
        writer.writeByte(2);
        break;
      case ObjectiveType.stopwatch:
        writer.writeByte(3);
        break;
      case ObjectiveType.subtask:
        writer.writeByte(4);
        break;
      case ObjectiveType.reflective:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectiveTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
