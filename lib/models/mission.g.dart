// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MissionAdapter extends TypeAdapter<Mission> {
  @override
  final int typeId = 13;

  @override
  Mission read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Mission(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      categoryIds: (fields[3] as List).cast<String>(),
      statIds: (fields[4] as List).cast<String>(),
      xpReward: fields[5] as int,
      rarity: fields[6] as MissionRarity,
      isCompleted: fields[7] as bool,
      recommendedBySmartSuggestion: fields[8] as bool,
      timesRecommended: fields[9] as int,
      isAccepted: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Mission obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.categoryIds)
      ..writeByte(4)
      ..write(obj.statIds)
      ..writeByte(5)
      ..write(obj.xpReward)
      ..writeByte(6)
      ..write(obj.rarity)
      ..writeByte(7)
      ..write(obj.isCompleted)
      ..writeByte(8)
      ..write(obj.recommendedBySmartSuggestion)
      ..writeByte(9)
      ..write(obj.timesRecommended)
      ..writeByte(10)
      ..write(obj.isAccepted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MissionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MissionRarityAdapter extends TypeAdapter<MissionRarity> {
  @override
  final int typeId = 12;

  @override
  MissionRarity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MissionRarity.common;
      case 1:
        return MissionRarity.rare;
      case 2:
        return MissionRarity.legendary;
      default:
        return MissionRarity.common;
    }
  }

  @override
  void write(BinaryWriter writer, MissionRarity obj) {
    switch (obj) {
      case MissionRarity.common:
        writer.writeByte(0);
        break;
      case MissionRarity.rare:
        writer.writeByte(1);
        break;
      case MissionRarity.legendary:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MissionRarityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
