import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:kontinuum/models/diet_models.dart';
import 'package:kontinuum/services/open_food_facts_service.dart';
import 'package:kontinuum/services/fdc_service.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class DietProvider extends ChangeNotifier {
  // boxes
  final Box<DietEntry>? _entryBox;
  final Box<DietGoal>? _goalBox;
  // foods + weights are dynamic → no DietFood adapter needed
  final Box<dynamic>? _foodsBox;
  final Box<dynamic>? _weightsBox;

  // services
  final FdcService _fdc;

  // in-memory
  late DietGoal _goal;
  final List<DietEntry> _entries = [];
  final List<DietFood> _foods = [];
  final List<DietWeightLog> _weights = [];

  // remote (Open Food Facts) transient list
  List<DietFood> _remoteFoods = [];
  List<DietFood> get remoteFoods => List.unmodifiable(_remoteFoods);

  // remote (USDA FoodData Central) transient list
  List<FdcSearchItem> _fdcResults = [];
  List<FdcSearchItem> get fdcResults => List.unmodifiable(_fdcResults);

  bool _isSearchingFdc = false;
  bool get isSearchingFdc => _isSearchingFdc;

  DietProvider({
    Box<DietEntry>? entryBox,
    Box<DietGoal>? goalBox,
    Box<dynamic>? foodsBox,
    Box<dynamic>? weightsBox,
    FdcService? fdc,
  })  : _entryBox = entryBox,
        _goalBox = goalBox,
        _foodsBox = foodsBox,
        _weightsBox = weightsBox,
        _fdc = fdc ??
            FdcService(
              apiKey: const String.fromEnvironment(
                'FDC_API_KEY',
                defaultValue: 'JC413OgX3M0bKG9inueE4wpx4YFMgJIHxadmRuWa',
              ),
            ) {
    // ----- load goal -----
    final goalBoxRef = _goalBox;
    if (goalBoxRef != null) {
      final saved = goalBoxRef.get('goal');
      if (saved != null) {
        final fixedBase =
            (saved.baseCalories == null || saved.baseCalories == 0)
                ? 2200
                : saved.baseCalories!;
        final fixedMode = saved.mode.isEmpty ? 'cut' : saved.mode;
        final derived = _deriveCaloriesForMode(fixedBase, fixedMode);
        _goal = saved.copyWith(
          baseCalories: fixedBase,
          mode: fixedMode,
          caloriesTarget: derived,
        );
      } else {
        _goal = DietGoal(
          baseCalories: 2200,
          caloriesTarget: 2200,
          mode: 'maintain',
        );
      }
    } else {
      _goal = DietGoal(
        baseCalories: 2200,
        caloriesTarget: 2200,
        mode: 'maintain',
      );
    }

    // ----- load entries -----
    final entryBoxRef = _entryBox;
    if (entryBoxRef != null) {
      _entries.addAll(entryBoxRef.values);
    }

    // ----- load foods (dynamic maps → DietFood) -----
    final foodsBoxRef = _foodsBox;
    if (foodsBoxRef != null) {
      for (final key in foodsBoxRef.keys) {
        final raw = foodsBoxRef.get(key);
        final f = _mapToFood(raw);
        if (f != null) {
          _foods.add(f);
        }
      }
      if (_foods.isEmpty) {
        _seedDefaultFoods();
      }
    } else {
      _foods.addAll(_defaultFoods());
    }

    // ----- load weights (optional) -----
    final weightsBoxRef = _weightsBox;
    if (weightsBoxRef != null) {
      for (final key in weightsBoxRef.keys) {
        final raw = weightsBoxRef.get(key);
        final w = _mapToWeight(raw);
        if (w != null) {
          _weights.add(w);
        }
      }
      _weights.sort((a, b) => b.date.compareTo(a.date));
    }
  }

  Future<void> reloadFromStorage() async {
    _entries.clear();
    _foods.clear();
    _weights.clear();

    final goalBoxRef = _goalBox;
    if (goalBoxRef != null) {
      final saved = goalBoxRef.get('goal');
      if (saved != null) {
        final fixedBase =
            (saved.baseCalories == null || saved.baseCalories == 0)
                ? 2200
                : saved.baseCalories!;
        final fixedMode = saved.mode.isEmpty ? 'cut' : saved.mode;
        final derived = _deriveCaloriesForMode(fixedBase, fixedMode);
        _goal = saved.copyWith(
          baseCalories: fixedBase,
          mode: fixedMode,
          caloriesTarget: derived,
        );
      } else {
        _goal = DietGoal(
          baseCalories: 2200,
          caloriesTarget: 2200,
          mode: 'maintain',
        );
      }
    } else {
      _goal = DietGoal(
        baseCalories: 2200,
        caloriesTarget: 2200,
        mode: 'maintain',
      );
    }

    final entryBoxRef = _entryBox;
    if (entryBoxRef != null) {
      _entries.addAll(entryBoxRef.values);
    }

    final foodsBoxRef = _foodsBox;
    if (foodsBoxRef != null) {
      for (final key in foodsBoxRef.keys) {
        final raw = foodsBoxRef.get(key);
        final f = _mapToFood(raw);
        if (f != null) {
          _foods.add(f);
        }
      }
      if (_foods.isEmpty) {
        _seedDefaultFoods();
      }
    }

    final weightsBoxRef = _weightsBox;
    if (weightsBoxRef != null) {
      for (final key in weightsBoxRef.keys) {
        final raw = weightsBoxRef.get(key);
        final w = _mapToWeight(raw);
        if (w != null) {
          _weights.add(w);
        }
      }
      _weights.sort((a, b) => b.date.compareTo(a.date));
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  DietGoal get goal => _goal;
  List<DietEntry> get allEntries => List.unmodifiable(_entries);
  List<DietFood> get foods => List.unmodifiable(_foods);
  List<DietWeightLog> get weightLogs => List.unmodifiable(_weights);
  DietWeightLog? get latestWeight => _weights.isEmpty ? null : _weights.first;

  // ---------------------------------------------------------------------------
  // GOAL
  // ---------------------------------------------------------------------------

  int _deriveCaloriesForMode(int base, String mode) {
    switch (mode) {
      case 'cut':
        return base - 350.clamp(1200, 10000);
      case 'bulk':
        return base + 300.clamp(1200, 10000);
      case 'maintain':
      default:
        return base.clamp(1200, 10000);
    }
  }

  Future<void> updateGoal(DietGoal newGoal) async {
    final safeBase = (newGoal.baseCalories == null || newGoal.baseCalories == 0)
        ? 2200
        : newGoal.baseCalories!;
    final safeMode = newGoal.mode.isEmpty ? 'maintain' : newGoal.mode;
    final derived = _deriveCaloriesForMode(safeBase, safeMode);

    _goal = newGoal.copyWith(
      baseCalories: safeBase,
      mode: safeMode,
      caloriesTarget: derived,
    );

    final goalBoxRef = _goalBox;
    if (goalBoxRef != null) {
      await goalBoxRef.put('goal', _goal);
    }
    notifyListeners();
  }

  Future<void> updateGoalMode(String mode) async {
    final base = (_goal.baseCalories == null || _goal.baseCalories == 0)
        ? 2200
        : _goal.baseCalories!;
    final derivedCalories = _deriveCaloriesForMode(base, mode);

    _goal = _goal.copyWith(
      mode: mode,
      caloriesTarget: derivedCalories,
      baseCalories: base,
    );

    final goalBoxRef = _goalBox;
    if (goalBoxRef != null) {
      await goalBoxRef.put('goal', _goal);
    }
    notifyListeners();
  }

  Future<void> updateBaseCalories(int base) async {
    final safeBase = base <= 0 ? 2200 : base;
    final mode = _goal.mode.isEmpty ? 'maintain' : _goal.mode;
    final derived = _deriveCaloriesForMode(safeBase, mode);

    _goal = _goal.copyWith(
      baseCalories: safeBase,
      caloriesTarget: derived,
    );

    final goalBoxRef = _goalBox;
    if (goalBoxRef != null) {
      await goalBoxRef.put('goal', _goal);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ENTRIES
  // ---------------------------------------------------------------------------

  List<DietEntry> entriesForDay(DateTime day) {
    final y = day.year, m = day.month, d = day.day;
    return _entries.where((e) {
      final ed = e.date;
      return ed.year == y && ed.month == m && ed.day == d;
    }).toList();
  }

  List<DietEntry> entriesForSlotEnum(DateTime day, MealSlot slot) {
    final y = day.year, m = day.month, d = day.day;
    return _entries.where((e) {
      final ed = e.date;
      return ed.year == y && ed.month == m && ed.day == d && e.mealSlot == slot;
    }).toList();
  }

  int caloriesForDay(DateTime day) {
    final list = entriesForDay(day);
    return list.fold<int>(0, (sum, e) => sum + e.calories);
  }

  Future<void> addEntry({
    required DateTime date,
    required MealSlot slot,
    required String name,
    required int calories,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
  }) async {
    final entry = DietEntry(
      id: _randomId(),
      date: DateTime(date.year, date.month, date.day),
      mealSlot: slot,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );

    _entries.add(entry);
    final entryBoxRef = _entryBox;
    if (entryBoxRef != null) {
      await entryBoxRef.put(entry.id, entry);
    }
    notifyListeners();
  }

  Future<void> addEntryEnum({
    required DateTime date,
    required MealSlot slot,
    required String name,
    required int calories,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
  }) {
    return addEntry(
      date: date,
      slot: slot,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
  }

  Future<void> addEntryRaw({
    required DateTime date,
    required String mealSlotStorage,
    required String name,
    required int calories,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
  }) {
    return addEntry(
      date: date,
      slot: mealSlotFromStorage(mealSlotStorage),
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
  }

  DietEntry? getEntryById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateEntry(DietEntry entry) async {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx == -1) return;

    final normalized = DietEntry(
      id: entry.id,
      date: DateTime(entry.date.year, entry.date.month, entry.date.day),
      mealSlot: entry.mealSlot,
      name: entry.name,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fats: entry.fats,
    );

    _entries[idx] = normalized;

    final entryBoxRef = _entryBox;
    if (entryBoxRef != null) {
      await entryBoxRef.put(normalized.id, normalized);
    }
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    final entryBoxRef = _entryBox;
    if (entryBoxRef != null) {
      await entryBoxRef.delete(id);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // FOODS (local)
  // ---------------------------------------------------------------------------

  List<DietFood> get foodsUnfiltered => List.unmodifiable(_foods);

  Future<void> saveFood(DietFood food) async {
    final idx = _foods.indexWhere((f) => f.id == food.id);
    if (idx == -1) {
      _foods.add(food);
    } else {
      _foods[idx] = food;
    }

    final foodsBoxRef = _foodsBox;
    if (foodsBoxRef != null) {
      await foodsBoxRef.put(food.id, _foodToMap(food));
    }
    notifyListeners();
  }

  Future<void> addFood({
    required String name,
    required int calories,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
  }) async {
    final food = DietFood(
      id: _randomId(),
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
    _foods.add(food);

    final foodsBoxRef = _foodsBox;
    if (foodsBoxRef != null) {
      await foodsBoxRef.put(food.id, _foodToMap(food));
    }
    notifyListeners();
  }

  Future<void> updateFood(DietFood food) async {
    final idx = _foods.indexWhere((f) => f.id == food.id);
    if (idx == -1) return;
    _foods[idx] = food;

    final foodsBoxRef = _foodsBox;
    if (foodsBoxRef != null) {
      await foodsBoxRef.put(food.id, _foodToMap(food));
    }
    notifyListeners();
  }

  Future<void> deleteFood(String id) async {
    _foods.removeWhere((f) => f.id == id);
    final foodsBoxRef = _foodsBox;
    if (foodsBoxRef != null) {
      await foodsBoxRef.delete(id);
    }
    notifyListeners();
  }

  DietFood? getFoodById(String id) {
    try {
      return _foods.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// UI → "Add to day" (Foods tab)
  Future<void> addFoodToDay(
    DietFood food, {
    DateTime? date,
    required MealSlot slot,
  }) {
    final d = date ?? AppClock.now();
    return addEntry(
      date: d,
      slot: slot,
      name: food.name,
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fats: food.fats,
    );
  }

  // ---------------------------------------------------------------------------
  // FOODS (remote / Open Food Facts)
  // ---------------------------------------------------------------------------

  Future<void> searchRemoteFoods(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _remoteFoods = [];
      notifyListeners();
      return;
    }

    final off = OpenFoodFactsService.instance;
    final products = await off.search(q);

    _remoteFoods = products.map((p) {
      return DietFood(
        id: 'off_${p.name}_${AppClock.now().millisecondsSinceEpoch}',
        name: p.brand != null && p.brand!.isNotEmpty
            ? '${p.name} (${p.brand})'
            : p.name,
        calories: p.kcal ?? 0,
        protein: p.protein,
        carbs: p.carbs,
        fats: p.fats,
      );
    }).toList();

    notifyListeners();
  }

  /// Promote a remote OFF food into local saved foods.
  Future<void> saveRemoteFood(DietFood food) async {
    await saveFood(food);
    _remoteFoods.removeWhere((f) => f.id == food.id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // FOODS (remote / USDA FoodData Central)
  // ---------------------------------------------------------------------------

  /// Search USDA FoodData Central by keyword.
  Future<void> searchFoodsFdc(String query, {int page = 1}) async {
    _isSearchingFdc = true;
    notifyListeners();
    try {
      _fdcResults = await _fdc.searchFoods(
        query,
        pageNumber: page,
        pageSize: 25,
        dataTypes: const ['Branded', 'Survey (FNDDS)', 'SR Legacy', 'Foundation'],
        sortBy: 'fdcId',
        sortOrder: 'desc',
      );
    } catch (e) {
      debugPrint('FDC search error: $e');
      _fdcResults = [];
    } finally {
      _isSearchingFdc = false;
      notifyListeners();
    }
  }

  /// Lookup food by barcode (UPC/GTIN) from USDA FoodData Central.
  Future<FdcSearchItem?> lookupBarcodeFdc(String upc) async {
    try {
      return await _fdc.searchByBarcode(upc);
    } catch (e) {
      debugPrint('FDC barcode lookup error: $e');
      return null;
    }
  }

  /// Convert a picked FDC search item into a DietEntry.
  /// Adjust calories/macros by 'servings' if the user picks a multiplier.
  DietEntry toDietEntryFromFdc(
    FdcSearchItem item, {
    required DateTime date,
    required MealSlot mealSlot,
    double servings = 1.0,
  }) {
    final mult = servings;
    final kcal = (item.calories ?? 0) * mult;
    final p = (item.protein ?? 0) * mult;
    final c = (item.carbs ?? 0) * mult;
    final f = (item.fat ?? 0) * mult;

    return DietEntry(
      id: 'fdc-${item.fdcId}-${AppClock.now().millisecondsSinceEpoch}',
      date: date,
      mealSlot: mealSlot,
      name: _friendlyNameFromFdc(item),
      calories: kcal.round(),
      protein: p,
      carbs: c,
      fats: f,
    );
  }

  /// Create a friendly display name from FDC item.
  String _friendlyNameFromFdc(FdcSearchItem i) {
    if ((i.brandName ?? '').isNotEmpty) {
      return '${i.brandName} - ${i.description}';
    }
    if ((i.brandOwner ?? '').isNotEmpty) {
      return '${i.brandOwner} - ${i.description}';
    }
    return i.description;
  }

  /// Save an FDC item to local foods library.
  Future<void> saveFdcFood(FdcSearchItem item) async {
    final food = DietFood(
      id: 'fdc_${item.fdcId}',
      name: _friendlyNameFromFdc(item),
      calories: (item.calories ?? 0).round(),
      protein: item.protein ?? 0,
      carbs: item.carbs ?? 0,
      fats: item.fat ?? 0,
      notes: item.servingText,
    );
    await saveFood(food);
  }

  // ---------------------------------------------------------------------------
  // WEIGHTS
  // ---------------------------------------------------------------------------

  Future<void> logWeight({
    required DateTime date,
    required double weightKg,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    _weights.removeWhere((w) =>
        w.date.year == normalizedDate.year &&
        w.date.month == normalizedDate.month &&
        w.date.day == normalizedDate.day);

    final log = DietWeightLog(
      id: _randomId(),
      date: normalizedDate,
      weightKg: weightKg,
    );
    _weights.add(log);
    _weights.sort((a, b) => b.date.compareTo(a.date));

    final weightsBoxRef = _weightsBox;
    if (weightsBoxRef != null) {
      await weightsBoxRef.put(log.id, {
        'id': log.id,
        'date': log.date.toIso8601String(),
        'weightKg': log.weightKg,
      });
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // INTERNAL / HELPERS
  // ---------------------------------------------------------------------------

  void _seedDefaultFoods() {
    final seeds = _defaultFoods();
    _foods.addAll(seeds);
    final foodsBoxRef = _foodsBox;
    if (foodsBoxRef != null) {
      for (final f in seeds) {
        foodsBoxRef.put(f.id, _foodToMap(f));
      }
    }
  }

  List<DietFood> _defaultFoods() {
    return [
      DietFood(
        id: 'food_protein_shake',
        name: 'Protein shake',
        calories: 220,
        protein: 30,
      ),
      DietFood(
        id: 'food_oatmeal_pb',
        name: 'Oatmeal + PB',
        calories: 410,
        protein: 14,
        carbs: 45,
        fats: 16,
      ),
      DietFood(
        id: 'food_chicken_rice',
        name: 'Chicken + rice',
        calories: 520,
        protein: 38,
        carbs: 55,
        fats: 12,
      ),
      DietFood(
        id: 'food_salmon_rice',
        name: 'Salmon + rice + veg',
        calories: 620,
        protein: 35,
        carbs: 45,
        fats: 22,
      ),
    ];
  }

  Map<String, dynamic> _foodToMap(DietFood f) => {
        'id': f.id,
        'name': f.name,
        'calories': f.calories,
        'protein': f.protein,
        'carbs': f.carbs,
        'fats': f.fats,
      };

  DietFood? _mapToFood(dynamic raw) {
    if (raw is DietFood) return raw;
    if (raw is! Map) return null;
    return DietFood(
      id: raw['id'] as String? ?? _randomId(),
      name: raw['name'] as String? ?? 'Food',
      calories: (raw['calories'] as num?)?.toInt() ?? 0,
      protein: (raw['protein'] as num?)?.toDouble() ?? 0,
      carbs: (raw['carbs'] as num?)?.toDouble() ?? 0,
      fats: (raw['fats'] as num?)?.toDouble() ?? 0,
    );
  }

  DietWeightLog? _mapToWeight(dynamic raw) {
    if (raw is! Map) return null;
    return DietWeightLog(
      id: raw['id'] as String? ?? _randomId(),
      date: DateTime.tryParse(raw['date'] as String? ?? '') ?? AppClock.now(),
      weightKg: (raw['weightKg'] as num?)?.toDouble() ?? 0,
    );
  }

  String _randomId() {
    final r = Random();
    return '${AppClock.now().millisecondsSinceEpoch}_${r.nextInt(999999)}';
  }
}

/// SINGLE source of truth for meal-slot helpers
extension MealSlotX on MealSlot {
  String get label {
    switch (this) {
      case MealSlot.breakfast:
        return 'Breakfast';
      case MealSlot.lunch:
        return 'Lunch';
      case MealSlot.dinner:
        return 'Dinner';
      case MealSlot.snack:
        return 'Snack';
    }
  }

  String get storage {
    switch (this) {
      case MealSlot.breakfast:
        return 'breakfast';
      case MealSlot.lunch:
        return 'lunch';
      case MealSlot.dinner:
        return 'dinner';
      case MealSlot.snack:
        return 'snack';
    }
  }
}

MealSlot mealSlotFromStorage(String storage) {
  switch (storage) {
    case 'breakfast':
      return MealSlot.breakfast;
    case 'lunch':
      return MealSlot.lunch;
    case 'dinner':
      return MealSlot.dinner;
    case 'snack':
      return MealSlot.snack;
    default:
      return MealSlot.snack;
  }
}

/// public so UI can read it
class DietWeightLog {
  final String id;
  final DateTime date;
  final double weightKg;

  DietWeightLog({
    required this.id,
    required this.date,
    required this.weightKg,
  });
}
