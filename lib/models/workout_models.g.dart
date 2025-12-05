// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DietSettingsAdapter extends TypeAdapter<DietSettings> {
  @override
  final int typeId = 205;

  @override
  DietSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietSettings(
      goal: fields[0] as DietGoal,
      kcalPerDay: fields[1] as int,
      proteinTargetG: fields[2] as int,
      strictness: fields[3] as DietStrictness,
    );
  }

  @override
  void write(BinaryWriter writer, DietSettings obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.goal)
      ..writeByte(1)
      ..write(obj.kcalPerDay)
      ..writeByte(2)
      ..write(obj.proteinTargetG)
      ..writeByte(3)
      ..write(obj.strictness);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 206;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exercise(
      id: fields[0] as String,
      name: fields[1] as String,
      muscles: (fields[2] as List).cast<String>(),
      equipment: (fields[3] as List).cast<String>(),
      difficulty: fields[4] as ExerciseDifficulty,
      intent: fields[5] as ExerciseIntent,
      instructions: fields[6] as String,
      cues: (fields[7] as List).cast<String>(),
      primaryMuscles: (fields[10] as List?)?.cast<String>(),
      secondaryMuscles: (fields[11] as List?)?.cast<String>(),
      mediaUrl: fields[8] as String?,
      attribution: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.muscles)
      ..writeByte(3)
      ..write(obj.equipment)
      ..writeByte(4)
      ..write(obj.difficulty)
      ..writeByte(5)
      ..write(obj.intent)
      ..writeByte(6)
      ..write(obj.instructions)
      ..writeByte(7)
      ..write(obj.cues)
      ..writeByte(8)
      ..write(obj.mediaUrl)
      ..writeByte(9)
      ..write(obj.attribution)
      ..writeByte(10)
      ..write(obj.primaryMuscles)
      ..writeByte(11)
      ..write(obj.secondaryMuscles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutItemAdapter extends TypeAdapter<WorkoutItem> {
  @override
  final int typeId = 207;

  @override
  WorkoutItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutItem(
      exerciseId: fields[0] as String,
      targetSets: fields[1] as int,
      targetReps: fields[2] as int?,
      targetTimeSec: fields[3] as int?,
      restSec: fields[4] as int?,
      targetLoad: fields[5] as double?,
      notes: fields[6] as String?,
      cueChips: (fields[7] as List?)?.cast<String>(),
      formChecks: (fields[8] as List?)?.cast<String>(),
      consecutiveMisses: fields[9] as int?,
      lastSuggestedLoadKg: fields[10] as double?,
      lastTargetReps: fields[11] as int?,
      lastLoggedRpe: fields[12] as double?,
      adaptiveSetsEnabled: fields[13] as bool?,
      adaptivePercent: fields[14] as double?,
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

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutBlockAdapter extends TypeAdapter<WorkoutBlock> {
  @override
  final int typeId = 208;

  @override
  WorkoutBlock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutBlock(
      type: fields[0] as BlockType?,
      title: fields[1] as String?,
      items: (fields[2] as List).cast<WorkoutItem>(),
      note: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutBlock obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutBlockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutAdapter extends TypeAdapter<Workout> {
  @override
  final int typeId = 209;

  @override
  Workout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Workout(
      id: fields[0] as String,
      title: fields[1] as String,
      blocks: (fields[2] as List).cast<WorkoutBlock>(),
      notes: fields[3] as String?,
      isRestTemplate: fields[4] as bool,
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

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RoutineAdapter extends TypeAdapter<Routine> {
  @override
  final int typeId = 210;

  @override
  Routine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Routine(
      id: fields[0] as String,
      name: fields[1] as String,
      poEnabled: fields[2] as bool,
      diet: fields[3] as DietSettings,
      workoutIds: (fields[4] as List).cast<String>(),
      createdAtMs: fields[5] as int,
      restSchedule: fields[6] as RestSchedule?,
      scheduleMode: fields[7] as RepetitionMode?,
    );
  }

  @override
  void write(BinaryWriter writer, Routine obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.poEnabled)
      ..writeByte(3)
      ..write(obj.diet)
      ..writeByte(4)
      ..write(obj.workoutIds)
      ..writeByte(5)
      ..write(obj.createdAtMs)
      ..writeByte(6)
      ..write(obj.restSchedule)
      ..writeByte(7)
      ..write(obj.scheduleMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SetLogAdapter extends TypeAdapter<SetLog> {
  @override
  final int typeId = 211;

  @override
  SetLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetLog(
      reps: fields[0] as int?,
      load: fields[1] as double?,
      rpe: fields[2] as double?,
      notes: fields[3] as String?,
      tsMs: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SetLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.reps)
      ..writeByte(1)
      ..write(obj.load)
      ..writeByte(2)
      ..write(obj.rpe)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.tsMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StatDeltaAdapter extends TypeAdapter<StatDelta> {
  @override
  final int typeId = 213;

  @override
  StatDelta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StatDelta(
      strength: fields[0] as int,
      hypertrophy: fields[1] as int,
      endurance: fields[2] as int,
      mobility: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, StatDelta obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.strength)
      ..writeByte(1)
      ..write(obj.hypertrophy)
      ..writeByte(2)
      ..write(obj.endurance)
      ..writeByte(3)
      ..write(obj.mobility);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatDeltaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseLogAdapter extends TypeAdapter<ExerciseLog> {
  @override
  final int typeId = 212;

  @override
  ExerciseLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseLog(
      exerciseId: fields[0] as String,
      sets: (fields[1] as List).cast<SetLog>(),
      volume: fields[2] as double,
      prFlags: (fields[3] as List).cast<String>(),
      statDelta: fields[4] as StatDelta,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.sets)
      ..writeByte(2)
      ..write(obj.volume)
      ..writeByte(3)
      ..write(obj.prFlags)
      ..writeByte(4)
      ..write(obj.statDelta);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionTotalsAdapter extends TypeAdapter<SessionTotals> {
  @override
  final int typeId = 214;

  @override
  SessionTotals read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionTotals(
      volume: fields[0] as double,
      timeSec: fields[1] as int,
      prCount: fields[2] as int,
      statDeltas: fields[3] as StatDelta,
    );
  }

  @override
  void write(BinaryWriter writer, SessionTotals obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.volume)
      ..writeByte(1)
      ..write(obj.timeSec)
      ..writeByte(2)
      ..write(obj.prCount)
      ..writeByte(3)
      ..write(obj.statDeltas);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionTotalsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutLogAdapter extends TypeAdapter<WorkoutLog> {
  @override
  final int typeId = 215;

  @override
  WorkoutLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutLog(
      id: fields[0] as String,
      routineId: fields[1] as String,
      workoutId: fields[2] as String,
      dateYmd: fields[3] as String,
      exerciseLogs: (fields[4] as List).cast<ExerciseLog>(),
      totals: fields[5] as SessionTotals,
      source: fields[6] as String,
      missionId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.routineId)
      ..writeByte(2)
      ..write(obj.workoutId)
      ..writeByte(3)
      ..write(obj.dateYmd)
      ..writeByte(4)
      ..write(obj.exerciseLogs)
      ..writeByte(5)
      ..write(obj.totals)
      ..writeByte(6)
      ..write(obj.source)
      ..writeByte(7)
      ..write(obj.missionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RestScheduleAdapter extends TypeAdapter<RestSchedule> {
  @override
  final int typeId = 221;

  @override
  RestSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestSchedule(
      mode: fields[0] as RepetitionMode,
      weeklyDays: (fields[1] as List?)?.cast<bool>(),
      intervalValue: fields[2] as int,
      intervalUnit: fields[3] as RepetitionUnit,
      intervalStartDateIso: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RestSchedule obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.mode)
      ..writeByte(1)
      ..write(obj.weeklyDays)
      ..writeByte(2)
      ..write(obj.intervalValue)
      ..writeByte(3)
      ..write(obj.intervalUnit)
      ..writeByte(4)
      ..write(obj.intervalStartDateIso);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutScheduleAdapter extends TypeAdapter<WorkoutSchedule> {
  @override
  final int typeId = 220;

  @override
  WorkoutSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSchedule(
      workoutId: fields[0] as String,
      mode: fields[1] as RepetitionMode,
      weeklyDays: (fields[2] as List?)?.cast<bool>(),
      intervalValue: fields[3] as int,
      intervalUnit: fields[4] as RepetitionUnit,
      intervalStartDateIso: fields[5] as String?,
      restSchedule: fields[6] as RestSchedule?,
      restOverrides: (fields[7] as Map?)?.cast<String, bool>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSchedule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.workoutId)
      ..writeByte(1)
      ..write(obj.mode)
      ..writeByte(2)
      ..write(obj.weeklyDays)
      ..writeByte(3)
      ..write(obj.intervalValue)
      ..writeByte(4)
      ..write(obj.intervalUnit)
      ..writeByte(5)
      ..write(obj.intervalStartDateIso)
      ..writeByte(6)
      ..write(obj.restSchedule)
      ..writeByte(7)
      ..write(obj.restOverrides);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DietGoalAdapter extends TypeAdapter<DietGoal> {
  @override
  final int typeId = 200;

  @override
  DietGoal read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DietGoal.cut;
      case 1:
        return DietGoal.maintain;
      case 2:
        return DietGoal.bulk;
      default:
        return DietGoal.cut;
    }
  }

  @override
  void write(BinaryWriter writer, DietGoal obj) {
    switch (obj) {
      case DietGoal.cut:
        writer.writeByte(0);
        break;
      case DietGoal.maintain:
        writer.writeByte(1);
        break;
      case DietGoal.bulk:
        writer.writeByte(2);
        break;
    }
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

class DietStrictnessAdapter extends TypeAdapter<DietStrictness> {
  @override
  final int typeId = 201;

  @override
  DietStrictness read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DietStrictness.soft;
      case 1:
        return DietStrictness.hard;
      default:
        return DietStrictness.soft;
    }
  }

  @override
  void write(BinaryWriter writer, DietStrictness obj) {
    switch (obj) {
      case DietStrictness.soft:
        writer.writeByte(0);
        break;
      case DietStrictness.hard:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietStrictnessAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseIntentAdapter extends TypeAdapter<ExerciseIntent> {
  @override
  final int typeId = 202;

  @override
  ExerciseIntent read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExerciseIntent.strength;
      case 1:
        return ExerciseIntent.hypertrophy;
      case 2:
        return ExerciseIntent.endurance;
      case 3:
        return ExerciseIntent.mobility;
      case 4:
        return ExerciseIntent.conditioning;
      default:
        return ExerciseIntent.strength;
    }
  }

  @override
  void write(BinaryWriter writer, ExerciseIntent obj) {
    switch (obj) {
      case ExerciseIntent.strength:
        writer.writeByte(0);
        break;
      case ExerciseIntent.hypertrophy:
        writer.writeByte(1);
        break;
      case ExerciseIntent.endurance:
        writer.writeByte(2);
        break;
      case ExerciseIntent.mobility:
        writer.writeByte(3);
        break;
      case ExerciseIntent.conditioning:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseIntentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseDifficultyAdapter extends TypeAdapter<ExerciseDifficulty> {
  @override
  final int typeId = 203;

  @override
  ExerciseDifficulty read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExerciseDifficulty.beginner;
      case 1:
        return ExerciseDifficulty.intermediate;
      case 2:
        return ExerciseDifficulty.advanced;
      default:
        return ExerciseDifficulty.beginner;
    }
  }

  @override
  void write(BinaryWriter writer, ExerciseDifficulty obj) {
    switch (obj) {
      case ExerciseDifficulty.beginner:
        writer.writeByte(0);
        break;
      case ExerciseDifficulty.intermediate:
        writer.writeByte(1);
        break;
      case ExerciseDifficulty.advanced:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseDifficultyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BlockTypeAdapter extends TypeAdapter<BlockType> {
  @override
  final int typeId = 204;

  @override
  BlockType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BlockType.set;
      case 1:
        return BlockType.superset;
      case 2:
        return BlockType.circuit;
      case 3:
        return BlockType.emom;
      case 4:
        return BlockType.amrap;
      default:
        return BlockType.set;
    }
  }

  @override
  void write(BinaryWriter writer, BlockType obj) {
    switch (obj) {
      case BlockType.set:
        writer.writeByte(0);
        break;
      case BlockType.superset:
        writer.writeByte(1);
        break;
      case BlockType.circuit:
        writer.writeByte(2);
        break;
      case BlockType.emom:
        writer.writeByte(3);
        break;
      case BlockType.amrap:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RepetitionModeAdapter extends TypeAdapter<RepetitionMode> {
  @override
  final int typeId = 218;

  @override
  RepetitionMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepetitionMode.weekly;
      case 1:
        return RepetitionMode.interval;
      default:
        return RepetitionMode.weekly;
    }
  }

  @override
  void write(BinaryWriter writer, RepetitionMode obj) {
    switch (obj) {
      case RepetitionMode.weekly:
        writer.writeByte(0);
        break;
      case RepetitionMode.interval:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepetitionModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RepetitionUnitAdapter extends TypeAdapter<RepetitionUnit> {
  @override
  final int typeId = 219;

  @override
  RepetitionUnit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepetitionUnit.days;
      case 1:
        return RepetitionUnit.weeks;
      case 2:
        return RepetitionUnit.months;
      case 3:
        return RepetitionUnit.years;
      default:
        return RepetitionUnit.days;
    }
  }

  @override
  void write(BinaryWriter writer, RepetitionUnit obj) {
    switch (obj) {
      case RepetitionUnit.days:
        writer.writeByte(0);
        break;
      case RepetitionUnit.weeks:
        writer.writeByte(1);
        break;
      case RepetitionUnit.months:
        writer.writeByte(2);
        break;
      case RepetitionUnit.years:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepetitionUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
