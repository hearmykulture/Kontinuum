import 'package:hive/hive.dart';
import 'package:kontinuum/core/time/app_clock.dart';

enum TrainingGoal { hypertrophy, strength, athletic, mobility, fatLoss }

class TrainingGoalAdapter extends TypeAdapter<TrainingGoal> {
  @override
  final int typeId = 170;

  @override
  TrainingGoal read(BinaryReader reader) {
    final index = reader.readByte();
    return TrainingGoal.values[index.clamp(0, TrainingGoal.values.length - 1)];
  }

  @override
  void write(BinaryWriter writer, TrainingGoal obj) {
    writer.writeByte(obj.index);
  }
}

enum TrainingEnvironment { fullGym, partialHome, bodyweight }

class TrainingEnvironmentAdapter extends TypeAdapter<TrainingEnvironment> {
  @override
  final int typeId = 171;

  @override
  TrainingEnvironment read(BinaryReader reader) {
    final index = reader.readByte();
    return TrainingEnvironment
        .values[index.clamp(0, TrainingEnvironment.values.length - 1)];
  }

  @override
  void write(BinaryWriter writer, TrainingEnvironment obj) {
    writer.writeByte(obj.index);
  }
}

enum DietGoalKind { cut, maintain, bulk }

class DietGoalKindAdapter extends TypeAdapter<DietGoalKind> {
  @override
  final int typeId = 172;

  @override
  DietGoalKind read(BinaryReader reader) {
    final index = reader.readByte();
    return DietGoalKind.values[index.clamp(0, DietGoalKind.values.length - 1)];
  }

  @override
  void write(BinaryWriter writer, DietGoalKind obj) {
    writer.writeByte(obj.index);
  }
}

enum TrackingStyle { trackExact, eyeball, hateTracking }

class TrackingStyleAdapter extends TypeAdapter<TrackingStyle> {
  @override
  final int typeId = 173;

  @override
  TrackingStyle read(BinaryReader reader) {
    final index = reader.readByte();
    return TrackingStyle.values[index.clamp(0, TrackingStyle.values.length - 1)];
  }

  @override
  void write(BinaryWriter writer, TrackingStyle obj) {
    writer.writeByte(obj.index);
  }
}

enum ExperienceLevel {
  newLifter,
  threeToTwelveMonths,
  oneToThreeYears,
  threePlusYears,
}

class ExperienceLevelAdapter extends TypeAdapter<ExperienceLevel> {
  @override
  final int typeId = 174;

  @override
  ExperienceLevel read(BinaryReader reader) {
    final index = reader.readByte();
    return ExperienceLevel
        .values[index.clamp(0, ExperienceLevel.values.length - 1)];
  }

  @override
  void write(BinaryWriter writer, ExperienceLevel obj) {
    writer.writeByte(obj.index);
  }
}

class FitnessNutritionProfile extends HiveObject {
  FitnessNutritionProfile({
    required this.age,
    required this.sexAtBirth,
    required this.heightCm,
    required this.weightKg,
    this.goalWeightKg,
    required this.daysPerWeek,
    required this.sessionLengthMin,
    required this.trainingEnvironment,
    required this.experienceLevel,
    required this.trainingGoal,
    required this.protectedAreas,
    required this.excludedMovementPatterns,
    required this.dietGoal,
    required this.dietGoalAggressiveness,
    required this.tdeeEstimate,
    required this.proteinPerKg,
    required this.preferredMealsPerDay,
    required this.trackingStyle,
    required this.dietaryRules,
    required this.equipment,
    required this.weighingFrequency,
    required this.createdAt,
    required this.updatedAt,
    required this.source,
    this.currentRoutineId,
  });

  @HiveField(0)
  int age;

  @HiveField(1)
  String sexAtBirth;

  @HiveField(2)
  double heightCm;

  @HiveField(3)
  double weightKg;

  @HiveField(4)
  double? goalWeightKg;

  @HiveField(5)
  int daysPerWeek;

  @HiveField(6)
  int sessionLengthMin;

  @HiveField(7)
  TrainingEnvironment trainingEnvironment;

  @HiveField(8)
  ExperienceLevel experienceLevel;

  @HiveField(9)
  TrainingGoal trainingGoal;

  @HiveField(10)
  List<String> protectedAreas;

  @HiveField(11)
  List<String> excludedMovementPatterns;

  @HiveField(12)
  DietGoalKind dietGoal;

  @HiveField(13)
  double dietGoalAggressiveness;

  @HiveField(14)
  int tdeeEstimate;

  @HiveField(15)
  double proteinPerKg;

  @HiveField(16)
  int preferredMealsPerDay;

  @HiveField(17)
  TrackingStyle trackingStyle;

  @HiveField(18)
  List<String> dietaryRules;

  @HiveField(19)
  List<String> equipment;

  @HiveField(20)
  String weighingFrequency;

  @HiveField(21)
  DateTime createdAt;

  @HiveField(22)
  DateTime updatedAt;

  @HiveField(23)
  String source;

  @HiveField(24)
  String? currentRoutineId;

  FitnessNutritionProfile copyWith({
    int? age,
    String? sexAtBirth,
    double? heightCm,
    double? weightKg,
    double? goalWeightKg,
    int? daysPerWeek,
    int? sessionLengthMin,
    TrainingEnvironment? trainingEnvironment,
    ExperienceLevel? experienceLevel,
    TrainingGoal? trainingGoal,
    List<String>? protectedAreas,
    List<String>? excludedMovementPatterns,
    DietGoalKind? dietGoal,
    double? dietGoalAggressiveness,
    int? tdeeEstimate,
    double? proteinPerKg,
    int? preferredMealsPerDay,
    TrackingStyle? trackingStyle,
    List<String>? dietaryRules,
    List<String>? equipment,
    String? weighingFrequency,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
    String? currentRoutineId,
  }) {
    return FitnessNutritionProfile(
      age: age ?? this.age,
      sexAtBirth: sexAtBirth ?? this.sexAtBirth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      sessionLengthMin: sessionLengthMin ?? this.sessionLengthMin,
      trainingEnvironment: trainingEnvironment ?? this.trainingEnvironment,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      trainingGoal: trainingGoal ?? this.trainingGoal,
      protectedAreas: protectedAreas ?? List.of(this.protectedAreas),
      excludedMovementPatterns:
          excludedMovementPatterns ?? List.of(this.excludedMovementPatterns),
      dietGoal: dietGoal ?? this.dietGoal,
      dietGoalAggressiveness:
          dietGoalAggressiveness ?? this.dietGoalAggressiveness,
      tdeeEstimate: tdeeEstimate ?? this.tdeeEstimate,
      proteinPerKg: proteinPerKg ?? this.proteinPerKg,
      preferredMealsPerDay:
          preferredMealsPerDay ?? this.preferredMealsPerDay,
      trackingStyle: trackingStyle ?? this.trackingStyle,
      dietaryRules: dietaryRules ?? List.of(this.dietaryRules),
      equipment: equipment ?? List.of(this.equipment),
      weighingFrequency: weighingFrequency ?? this.weighingFrequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      currentRoutineId: currentRoutineId ?? this.currentRoutineId,
    );
  }

  static TrainingGoal defaultTrainingGoalForDiet(DietGoalKind goal) {
    switch (goal) {
      case DietGoalKind.cut:
        return TrainingGoal.fatLoss;
      case DietGoalKind.bulk:
        return TrainingGoal.hypertrophy;
      case DietGoalKind.maintain:
        return TrainingGoal.hypertrophy;
    }
  }
}

class FitnessNutritionProfileAdapter
    extends TypeAdapter<FitnessNutritionProfile> {
  @override
  final int typeId = 175;

  @override
  FitnessNutritionProfile read(BinaryReader reader) {
    final age = reader.readInt();
    final sexAtBirth = reader.readString();
    final heightCm = reader.readDouble();
    final weightKg = reader.readDouble();
    final hasGoalWeight = reader.readBool();
    final goalWeightKg = hasGoalWeight ? reader.readDouble() : null;
    final daysPerWeek = reader.readInt();
    final sessionLengthMin = reader.readInt();
    final trainingEnvironment =
        TrainingEnvironment.values[reader.readByte().clamp(
      0,
      TrainingEnvironment.values.length - 1,
    )];
    final experienceLevel = ExperienceLevel.values[reader.readByte().clamp(
      0,
      ExperienceLevel.values.length - 1,
    )];
    final trainingGoal = TrainingGoal.values[reader.readByte().clamp(
      0,
      TrainingGoal.values.length - 1,
    )];
    final protectedAreas = reader.readList().cast<String>();
    final excludedMovementPatterns = reader.readList().cast<String>();
    final dietGoal = DietGoalKind.values[reader.readByte().clamp(
      0,
      DietGoalKind.values.length - 1,
    )];
    final dietGoalAggressiveness = reader.readDouble();
    final tdeeEstimate = reader.readInt();
    final proteinPerKg = reader.readDouble();
    final preferredMealsPerDay = reader.readInt();
    final trackingStyle = TrackingStyle.values[reader.readByte().clamp(
      0,
      TrackingStyle.values.length - 1,
    )];
    final dietaryRules = reader.readList().cast<String>();
    final equipment = reader.readList().cast<String>();
    final weighingFrequency = reader.readString();
    final createdAt = reader.read() as DateTime;
    final updatedAt = reader.read() as DateTime;
    final source = reader.readString();
    String? currentRoutineId;
    if (reader.availableBytes > 0) {
      final hasCurrent = reader.readBool();
      if (hasCurrent) {
        currentRoutineId = reader.readString();
      }
    }

    return FitnessNutritionProfile(
      age: age,
      sexAtBirth: sexAtBirth,
      heightCm: heightCm,
      weightKg: weightKg,
      goalWeightKg: goalWeightKg,
      daysPerWeek: daysPerWeek,
      sessionLengthMin: sessionLengthMin,
      trainingEnvironment: trainingEnvironment,
      experienceLevel: experienceLevel,
      trainingGoal: trainingGoal,
      protectedAreas: protectedAreas,
      excludedMovementPatterns: excludedMovementPatterns,
      dietGoal: dietGoal,
      dietGoalAggressiveness: dietGoalAggressiveness,
      tdeeEstimate: tdeeEstimate,
      proteinPerKg: proteinPerKg,
      preferredMealsPerDay: preferredMealsPerDay,
      trackingStyle: trackingStyle,
      dietaryRules: dietaryRules,
      equipment: equipment,
      weighingFrequency: weighingFrequency,
      createdAt: createdAt,
      updatedAt: updatedAt,
      source: source,
      currentRoutineId: currentRoutineId,
    );
  }

  @override
  void write(BinaryWriter writer, FitnessNutritionProfile obj) {
    writer
      ..writeInt(obj.age)
      ..writeString(obj.sexAtBirth)
      ..writeDouble(obj.heightCm)
      ..writeDouble(obj.weightKg)
      ..writeBool(obj.goalWeightKg != null);
    if (obj.goalWeightKg != null) {
      writer.writeDouble(obj.goalWeightKg!);
    }
    writer
      ..writeInt(obj.daysPerWeek)
      ..writeInt(obj.sessionLengthMin)
      ..writeByte(obj.trainingEnvironment.index)
      ..writeByte(obj.experienceLevel.index)
      ..writeByte(obj.trainingGoal.index)
      ..writeList(obj.protectedAreas)
      ..writeList(obj.excludedMovementPatterns)
      ..writeByte(obj.dietGoal.index)
      ..writeDouble(obj.dietGoalAggressiveness)
      ..writeInt(obj.tdeeEstimate)
      ..writeDouble(obj.proteinPerKg)
      ..writeInt(obj.preferredMealsPerDay)
      ..writeByte(obj.trackingStyle.index)
      ..writeList(obj.dietaryRules)
      ..writeList(obj.equipment)
      ..writeString(obj.weighingFrequency)
      ..write(obj.createdAt)
      ..write(obj.updatedAt)
      ..writeString(obj.source)
      ..writeBool(obj.currentRoutineId != null);
    if (obj.currentRoutineId != null) {
      writer.writeString(obj.currentRoutineId!);
    }
  }
}

double calculateBmr({
  required double weightKg,
  required double heightCm,
  required int age,
  required String sexAtBirth,
}) {
  final s = sexAtBirth.toLowerCase();
  final sexOffset = s == 'male'
      ? 5
      : s == 'female'
          ? -161
          : -78;
  return 10 * weightKg + 6.25 * heightCm - 5 * age + sexOffset;
}

double activityMultiplierForDays(int daysPerWeek) {
  if (daysPerWeek <= 2) return 1.3;
  if (daysPerWeek == 3) return 1.4;
  if (daysPerWeek == 4) return 1.55;
  return 1.7;
}

double adjustmentForDietGoal(DietGoalKind goal) {
  switch (goal) {
    case DietGoalKind.cut:
      return 0.85;
    case DietGoalKind.bulk:
      return 1.08;
    case DietGoalKind.maintain:
      return 1.0;
  }
}

double defaultProteinPerKg(DietGoalKind goal) {
  switch (goal) {
    case DietGoalKind.cut:
      return 1.8;
    case DietGoalKind.bulk:
      return 1.6;
    case DietGoalKind.maintain:
      return 1.5;
  }
}

FitnessNutritionProfile buildMvpProfile({
  required int age,
  required String sexAtBirth,
  required double heightCm,
  required double weightKg,
  required DietGoalKind dietGoal,
  required int daysPerWeek,
  required TrainingEnvironment trainingEnvironment,
  required List<String> dietaryRules,
  required List<String> protectedAreas,
  required List<String> excludedMovements,
  required List<String> equipment,
}) {
  final bmr = calculateBmr(
    weightKg: weightKg,
    heightCm: heightCm,
    age: age,
    sexAtBirth: sexAtBirth,
  );
  final tdee = (bmr * activityMultiplierForDays(daysPerWeek)).round();
  final adjustment = adjustmentForDietGoal(dietGoal);
  final calorieTarget = (tdee * adjustment).round();

  final now = AppClock.now();

  return FitnessNutritionProfile(
    age: age,
    sexAtBirth: sexAtBirth,
    heightCm: heightCm,
    weightKg: weightKg,
    goalWeightKg: null,
    daysPerWeek: daysPerWeek,
    sessionLengthMin: 45,
    trainingEnvironment: trainingEnvironment,
    experienceLevel: ExperienceLevel.newLifter,
    trainingGoal: FitnessNutritionProfile.defaultTrainingGoalForDiet(dietGoal),
    protectedAreas: protectedAreas,
    excludedMovementPatterns: excludedMovements,
    dietGoal: dietGoal,
    dietGoalAggressiveness: adjustment,
    tdeeEstimate: calorieTarget,
    proteinPerKg: defaultProteinPerKg(dietGoal),
    preferredMealsPerDay: 3,
    trackingStyle: TrackingStyle.trackExact,
    dietaryRules: dietaryRules,
    equipment: equipment,
    weighingFrequency: 'weekly',
    createdAt: now,
    updatedAt: now,
    source: 'screening_v1',
    currentRoutineId: null,
  );
}
