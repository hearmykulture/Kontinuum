import 'package:hive/hive.dart';

part 'diet_models.g.dart';

@HiveType(typeId: 239)
enum MealSlot {
  @HiveField(0)
  breakfast,
  @HiveField(1)
  lunch,
  @HiveField(2)
  dinner,
  @HiveField(3)
  snack,
}

@HiveType(typeId: 240)
class DietEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  MealSlot mealSlot;

  @HiveField(3)
  String name;

  @HiveField(4)
  int calories;

  @HiveField(5)
  double protein;

  @HiveField(6)
  double carbs;

  @HiveField(7)
  double fats;

  DietEntry({
    required this.id,
    required this.date,
    required this.mealSlot,
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
  });
}

@HiveType(typeId: 241)
class DietGoal extends HiveObject {
  /// Daily calorie target (kcal)
  @HiveField(0)
  int caloriesTarget;

  /// Daily protein target (grams)
  @HiveField(1)
  double proteinTarget;

  /// Daily carbs target (grams)
  @HiveField(2)
  double carbsTarget;

  /// Daily fats target (grams)
  @HiveField(3)
  double fatsTarget;

  /// "cut" | "maintain" | "bulk"
  @HiveField(4)
  String mode;

  /// Base maintenance calories used when computing cut/bulk offsets.
  /// Can be null from older boxes.
  @HiveField(5)
  int? baseCalories;

  /// Display name for the plan ("Spring Cut", "Maintenance", etc.).
  @HiveField(6)
  String? name;

  /// Target fasting window in hours per day (e.g. 16 for 16/8).
  @HiveField(7)
  double? fastingHours;

  /// Which meal slots are enabled for this plan.
  @HiveField(8)
  List<MealSlot> enabledSlots;

  /// Custom labels for each slot (keyed by MealSlot.index).
  /// e.g. { 0: "Pre-workout", 1: "Post-workout" }
  @HiveField(9)
  Map<int, String> slotLabels;

  DietGoal({
    this.caloriesTarget = 2000,
    this.proteinTarget = 120,
    this.carbsTarget = 200,
    this.fatsTarget = 60,
    this.mode = 'cut',
    this.baseCalories,
    this.name,
    this.fastingHours,
    List<MealSlot>? enabledSlots,
    Map<int, String>? slotLabels,
  })  : enabledSlots = enabledSlots ?? List<MealSlot>.from(MealSlot.values),
        slotLabels = slotLabels ?? <int, String>{};

  DietGoal copyWith({
    int? caloriesTarget,
    double? proteinTarget,
    double? carbsTarget,
    double? fatsTarget,
    String? mode,
    int? baseCalories,
    String? name,
    double? fastingHours,
    List<MealSlot>? enabledSlots,
    Map<int, String>? slotLabels,
  }) {
    return DietGoal(
      caloriesTarget: caloriesTarget ?? this.caloriesTarget,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      carbsTarget: carbsTarget ?? this.carbsTarget,
      fatsTarget: fatsTarget ?? this.fatsTarget,
      mode: mode ?? this.mode,
      baseCalories: baseCalories ?? this.baseCalories,
      name: name ?? this.name,
      fastingHours: fastingHours ?? this.fastingHours,
      enabledSlots: enabledSlots ?? List<MealSlot>.from(this.enabledSlots),
      slotLabels: slotLabels ?? Map<int, String>.from(this.slotLabels),
    );
  }

  DietGoal withDefaults() {
    return copyWith(
      mode: mode.isEmpty ? 'cut' : mode,
      baseCalories: baseCalories ?? caloriesTarget,
    );
  }
}

@HiveType(typeId: 242)
class DietFood extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int calories;

  @HiveField(3)
  double protein;

  @HiveField(4)
  double carbs;

  @HiveField(5)
  double fats;

  @HiveField(6)
  String? notes;

  // IMPORTANT: not const, so Hive is happy
  DietFood({
    required this.id,
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.notes,
  });

  DietFood copyWith({
    String? id,
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fats,
    String? notes,
  }) {
    return DietFood(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      notes: notes ?? this.notes,
    );
  }
}
