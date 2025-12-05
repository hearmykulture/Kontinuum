import 'package:hive/hive.dart';
import 'workout_models.dart';

/// Manual override to make old workout items (without the last fields) safe.
class WorkoutItemAdapterSafe extends TypeAdapter<WorkoutItem> {
  @override
  final int typeId = 207; // MUST match the original WorkoutItemAdapter

  @override
  WorkoutItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    List<String> stringList(int key) {
      final v = fields[key];
      if (v is List) {
        return v.map((e) => e.toString()).toList();
      }
      return const <String>[];
    }

    int intValue(int key, {int defaultValue = 0}) {
      final v = fields[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return defaultValue;
    }

    double? doubleNullable(int key) {
      final v = fields[key];
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return null;
    }

    bool boolValue(int key, {bool defaultValue = false}) {
      final v = fields[key];
      if (v is bool) return v;
      if (v == null) return defaultValue;
      if (v is int) return v != 0;
      return defaultValue;
    }

    return WorkoutItem(
      exerciseId: fields[0] as String,
      targetSets: intValue(1, defaultValue: 3),
      targetReps: fields[2] as int?,
      targetTimeSec: fields[3] as int?,
      restSec: fields[4] as int?,
      targetLoad: doubleNullable(5),
      notes: fields[6] as String?,
      cueChips: stringList(7),
      formChecks: stringList(8),
      consecutiveMisses: intValue(9, defaultValue: 0),
      lastSuggestedLoadKg: doubleNullable(10),
      lastTargetReps: fields[11] as int?,
      lastLoggedRpe: doubleNullable(12),
      // 🔒 old rows may not have this → default false
      adaptiveSetsEnabled: boolValue(13, defaultValue: false),
      // 🔒 old rows may not have this → default to kDefaultAdaptivePercent
      adaptivePercent: doubleNullable(14) ?? kDefaultAdaptivePercent,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutItem obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.targetSets)
      ..writeByte(2)
      ..write(obj.targetReps)
      ..writeByte(3)
      ..write(obj.targetTimeSec)
      ..writeByte(4)
      ..write(obj.restSec)
      ..writeByte(5)
      ..write(obj.targetLoad)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.cueChips)
      ..writeByte(8)
      ..write(obj.formChecks)
      ..writeByte(9)
      ..write(obj.consecutiveMisses)
      ..writeByte(10)
      ..write(obj.lastSuggestedLoadKg)
      ..writeByte(11)
      ..write(obj.lastTargetReps)
      ..writeByte(12)
      ..write(obj.lastLoggedRpe)
      ..writeByte(13)
      ..write(obj.adaptiveSetsEnabled)
      ..writeByte(14)
      ..write(obj.adaptivePercent);
  }
}

/// Manual override to make old workouts (without `isRestTemplate`) safe.
///
/// This is what fixes the crash:
///   type 'Null' is not a subtype of type 'bool' in type cast
/// that was coming from WorkoutAdapter.read in workout_models.g.dart.
class WorkoutAdapterSafe extends TypeAdapter<Workout> {
  @override
  final int typeId = 209; // MUST match the original WorkoutAdapter

  @override
  Workout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    bool boolValue(int key, {bool defaultValue = false}) {
      final v = fields[key];
      if (v is bool) return v;
      if (v == null) return defaultValue;
      if (v is int) return v != 0;
      return defaultValue;
    }

    return Workout(
      id: fields[0] as String,
      title: fields[1] as String,
      blocks:
          (fields[2] as List?)?.cast<WorkoutBlock>() ?? const <WorkoutBlock>[],
      notes: fields[3] as String?,
      // 🔑 OLD RECORDS: no field[4] → null → we default to false instead of
      // blowing up on `fields[4] as bool`.
      isRestTemplate: boolValue(4, defaultValue: false),
    );
  }

  @override
  void write(BinaryWriter writer, Workout obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.blocks)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.isRestTemplate);
  }
}
