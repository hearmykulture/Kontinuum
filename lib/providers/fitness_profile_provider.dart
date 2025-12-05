import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class FitnessProfileProvider extends ChangeNotifier {
  FitnessProfileProvider(Box<FitnessNutritionProfile> box) : _box = box {
    _profile = box.get(_kPrimaryKey);
  }

  static const _kPrimaryKey = 'profile';

  final Box<FitnessNutritionProfile> _box;
  FitnessNutritionProfile? _profile;

  FitnessNutritionProfile? get profile => _profile;
  bool get hasProfile => _profile != null;

  Future<void> reloadFromStorage() async {
    _profile = _box.get(_kPrimaryKey);
    notifyListeners();
  }

  Future<void> saveProfile(FitnessNutritionProfile profile) async {
    _profile = profile.copyWith(updatedAt: AppClock.now());
    await _box.put(_kPrimaryKey, _profile!);
    notifyListeners();
  }

  Future<void> update(void Function(FitnessNutritionProfile) mutator) async {
    final current = _profile;
    if (current == null) return;
    mutator(current);
    current.updatedAt = AppClock.now();
    await _box.put(_kPrimaryKey, current);
    notifyListeners();
  }
}
