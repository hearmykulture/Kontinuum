// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetTransactionAdapter extends TypeAdapter<BudgetTransaction> {
  @override
  final int typeId = 40;

  @override
  BudgetTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetTransaction(
      id: fields[0] as String,
      accountId: fields[1] as String,
      date: fields[2] as DateTime?,
      amountCents: fields[3] as int,
      isExpense: fields[4] as bool,
      status: fields[5] as String,
      category: fields[6] as String?,
      merchant: fields[7] as String?,
      memo: fields[8] as String?,
      pendingTransactionId: fields[9] as String?,
      currency: fields[10] as String?,
      reviewed: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetTransaction obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.accountId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.amountCents)
      ..writeByte(4)
      ..write(obj.isExpense)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.merchant)
      ..writeByte(8)
      ..write(obj.memo)
      ..writeByte(9)
      ..write(obj.pendingTransactionId)
      ..writeByte(10)
      ..write(obj.currency)
      ..writeByte(11)
      ..write(obj.reviewed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
