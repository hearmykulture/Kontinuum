// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stat.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StatAdapter extends TypeAdapter<Stat> {
  @override
  final int typeId = 6;

  @override
  Stat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Stat(
      id: fields[0] as String,
      label: fields[1] as String,
      count: fields[2] as int,
      xp: fields[3] as int,
      averageMinutesPerUnit: fields[4] as int,
      repsForMastery: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Stat obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.count)
      ..writeByte(3)
      ..write(obj.xp)
      ..writeByte(4)
      ..write(obj.averageMinutesPerUnit)
      ..writeByte(5)
      ..write(obj.repsForMastery);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
