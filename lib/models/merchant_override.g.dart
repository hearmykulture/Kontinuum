// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merchant_override.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MerchantOverrideAdapter extends TypeAdapter<MerchantOverride> {
  @override
  final int typeId = 41;

  @override
  MerchantOverride read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MerchantOverride(
      merchantKey: fields[0] as String,
      category: fields[1] as String,
      updatedAt: fields[2] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MerchantOverride obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.merchantKey)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MerchantOverrideAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
