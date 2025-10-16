// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stat_history_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StatHistoryEntryAdapter extends TypeAdapter<StatHistoryEntry> {
  @override
  final int typeId = 9;

  @override
  StatHistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StatHistoryEntry(
      statId: fields[0] as String,
      date: fields[1] as DateTime,
      amount: fields[2] as int,
      skillId: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StatHistoryEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.statId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.skillId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatHistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
