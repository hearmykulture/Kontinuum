// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedSetDataAdapter extends TypeAdapter<SavedSetData> {
  @override
  final int typeId = 222;

  @override
  SavedSetData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedSetData(
      index: fields[0] as int,
      loadLb: fields[1] as double,
      reps: fields[2] as int,
      timestampIso: fields[3] as String,
      elapsedSeconds: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SavedSetData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.index)
      ..writeByte(1)
      ..write(obj.loadLb)
      ..writeByte(2)
      ..write(obj.reps)
      ..writeByte(3)
      ..write(obj.timestampIso)
      ..writeByte(4)
      ..write(obj.elapsedSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedSetDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutSessionStateAdapter extends TypeAdapter<WorkoutSessionState> {
  @override
  final int typeId = 223;

  @override
  WorkoutSessionState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final Map<String, List<SavedSetData>> exerciseSets = {};
    if (fields.containsKey(17)) {
      final raw = fields[17];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (key is String && value is List) {
            exerciseSets[key] = value.cast<SavedSetData>();
          }
        });
      }
    }
    return WorkoutSessionState(
      workoutId: fields[0] as String,
      routineId: fields[1] as String?,
      currentBlockIndex: fields[2] as int,
      currentExerciseIndex: fields[3] as int,
      elapsedSeconds: fields[4] as int,
      wasRunning: fields[5] as bool,
      timerMode: fields[6] as String,
      restTotalSeconds: fields[7] as int,
      restRemainingSeconds: fields[8] as int,
      restWasPaused: fields[9] as bool,
      completedSets: (fields[10] as Map).cast<String, int>(),
      savedAtIso: fields[11] as String,
      currentExerciseNotes: fields[12] as String?,
      completedSetsList: (fields[13] as List?)?.cast<SavedSetData>(),
      finalRestStarted: fields[14] as bool?,
      finalRestDone: fields[15] as bool?,
      scheduledDateIso: fields[16] as String?,
      exerciseSets: exerciseSets,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSessionState obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.workoutId)
      ..writeByte(1)
      ..write(obj.routineId)
      ..writeByte(2)
      ..write(obj.currentBlockIndex)
      ..writeByte(3)
      ..write(obj.currentExerciseIndex)
      ..writeByte(4)
      ..write(obj.elapsedSeconds)
      ..writeByte(5)
      ..write(obj.wasRunning)
      ..writeByte(6)
      ..write(obj.timerMode)
      ..writeByte(7)
      ..write(obj.restTotalSeconds)
      ..writeByte(8)
      ..write(obj.restRemainingSeconds)
      ..writeByte(9)
      ..write(obj.restWasPaused)
      ..writeByte(10)
      ..write(obj.completedSets)
      ..writeByte(11)
      ..write(obj.savedAtIso)
      ..writeByte(12)
      ..write(obj.currentExerciseNotes)
      ..writeByte(13)
      ..write(obj.completedSetsList)
      ..writeByte(14)
      ..write(obj.finalRestStarted)
      ..writeByte(15)
      ..write(obj.finalRestDone)
      ..writeByte(16)
      ..write(obj.scheduledDateIso)
      ..writeByte(17)
      ..write(obj.exerciseSets);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
