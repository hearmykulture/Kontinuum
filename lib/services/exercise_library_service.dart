// lib/services/exercise_library_service.dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';

import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/workout_boxes.dart';
import 'package:kontinuum/services/exercisedb_service.dart'; // 👈 new

/// Handles:
/// - first-run seeding of the exercise library from assets
/// - querying/filtering the library
/// - favorites / recents (P0 in-memory; can move to prefs later)
///
/// Not a ChangeNotifier. UI state (filters etc.) will live in WorkoutProvider.
class ExerciseLibraryService {
  ExerciseLibraryService._();
  static final ExerciseLibraryService instance = ExerciseLibraryService._();

  // P0 in-memory favorites/recents. We'll persist in a prefs box later.
  final List<String> _favorites = [];
  final List<String> _recents = [];

  /// Call once on startup (after WorkoutBoxes.init()).
  /// 1) seed from our small bundled JSON
  /// 2) then let ExerciseDbService pull/merge the big OSS dataset
  Future<void> ensureSeedLoaded() async {
    final Box<Exercise> box = WorkoutBoxes.exerciseBox;

    if (box.isEmpty) {
      // 1) small bundled JSON (your original seed)
      final rawJson =
          await rootBundle.loadString('assets/workout/library_seed.json');
      final List<dynamic> parsed = json.decode(rawJson) as List<dynamic>;

      for (final entry in parsed) {
        final map = entry as Map<String, dynamic>;

        final ExerciseDifficulty difficultyEnum =
            _difficultyFromString(map['difficulty'] as String?);
        final ExerciseIntent intentEnum =
            _intentFromString(map['intent'] as String?);
        final List<String> rawMuscles =
            List<String>.from((map['muscles'] as List?) ?? const <String>[]);
        List<String> primaryMuscles = List<String>.from(
          (map['primaryMuscles'] as List?) ?? const <String>[],
        );
        List<String> secondaryMuscles = List<String>.from(
          (map['secondaryMuscles'] as List?) ?? const <String>[],
        );

        if (primaryMuscles.isEmpty && rawMuscles.isNotEmpty) {
          primaryMuscles = <String>[rawMuscles.first];
        }
        if (secondaryMuscles.isEmpty && rawMuscles.length > 1) {
          secondaryMuscles = rawMuscles.sublist(1);
        }

        final List<String> combinedMuscles;
        if (rawMuscles.isNotEmpty) {
          combinedMuscles = rawMuscles;
        } else {
          final all = <String>[];
          for (final m in primaryMuscles) {
            if (!all.contains(m)) all.add(m);
          }
          for (final m in secondaryMuscles) {
            if (!all.contains(m)) all.add(m);
          }
          combinedMuscles = all;
        }

        final ex = Exercise(
          id: map['id'] as String,
          name: map['name'] as String,
          muscles: combinedMuscles,
          equipment: List<String>.from(
              (map['equipment'] as List?) ?? const <String>[]),
          difficulty: difficultyEnum,
          intent: intentEnum,
          instructions: map['instructions'] as String? ?? '',
          cues: List<String>.from((map['cues'] as List?) ?? const <String>[]),
          primaryMuscles: primaryMuscles,
          secondaryMuscles: secondaryMuscles,
          mediaUrl: map['mediaUrl'] as String?,
          attribution: map['attribution'] as String?,
        );

        // Use exercise.id as the Hive key for stable lookups.
        box.put(ex.id, ex);
      }
    }

    // 2) now merge in the big ExerciseDB (asset or local API)
    //    non-fatal → if it fails you still have the seed
    await ExerciseDbService.instance.ensureSynced();
  }

  // ============================================================
  // Accessors
  // ============================================================

  List<Exercise> allExercises() {
    final box = WorkoutBoxes.exerciseBox;
    return box.values.toList(growable: false);
  }

  Exercise? getById(String exerciseId) {
    return WorkoutBoxes.exerciseBox.get(exerciseId);
  }

  void favoriteExercise(String exerciseId) {
    if (!_favorites.contains(exerciseId)) {
      _favorites.add(exerciseId);
    }
  }

  List<Exercise> favorites() {
    final box = WorkoutBoxes.exerciseBox;
    return _favorites
        .map((id) => box.get(id))
        .where((ex) => ex != null)
        .cast<Exercise>()
        .toList(growable: false);
  }

  void recordRecent(String exerciseId) {
    _recents.remove(exerciseId);
    _recents.insert(0, exerciseId);
    if (_recents.length > 20) {
      _recents.removeRange(20, _recents.length);
    }
  }

  List<Exercise> recents() {
    final box = WorkoutBoxes.exerciseBox;
    return _recents
        .map((id) => box.get(id))
        .where((ex) => ex != null)
        .cast<Exercise>()
        .toList(growable: false);
  }

  // ============================================================
  // Filtering (Library Picker / search UI)
  // ============================================================

  /// Filter by any combo of:
  /// - muscles: match ANY
  /// - equipment: must be compatible with ALL requested
  /// - difficulty
  /// - intent
  /// - query: fuzzy text across name/instructions/cues/etc.
  List<Exercise> filter({
    List<String>? muscles,
    List<String>? equipment,
    ExerciseDifficulty? difficulty,
    ExerciseIntent? intent,
    String? query,
  }) {
    final q = query?.toLowerCase().trim();
    final List<String>? muscleFilter =
        muscles?.map((m) => m.toLowerCase().trim()).toList();
    final List<String>? equipFilter =
        equipment?.map((e) => e.toLowerCase().trim()).toList();

    return allExercises().where((ex) {
      // muscles
      if (muscleFilter != null && muscleFilter.isNotEmpty) {
        final exMusclesLower =
            ex.muscles.map((m) => m.toLowerCase().trim()).toList();
        final anyHit = muscleFilter.any(
          (want) => exMusclesLower.any((m) => m.contains(want)),
        );
        if (!anyHit) return false;
      }

      // equipment
      if (equipFilter != null && equipFilter.isNotEmpty) {
        final exEquipLower =
            ex.equipment.map((e) => e.toLowerCase().trim()).toList();
        final allSatisfied = equipFilter.every(
          (need) => exEquipLower.any((have) => have.contains(need)),
        );
        if (!allSatisfied) return false;
      }

      // difficulty
      if (difficulty != null && ex.difficulty != difficulty) {
        return false;
      }

      // intent
      if (intent != null && ex.intent != intent) {
        return false;
      }

      // free text
      if (q != null && q.isNotEmpty) {
        final haystack = [
          ex.name,
          ex.instructions,
          ...ex.cues,
          ...ex.muscles,
          ...ex.equipment,
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }

      return true;
    }).toList(growable: false);
  }

  // ============================================================
  // Similar alternatives (for Swap)
  // ============================================================

  /// Suggest swaps that:
  /// - share at least one muscle
  /// - AND share at least one equipment tag
  /// - exclude the current exercise
  List<Exercise> similarTo(String exerciseId) {
    final current = getById(exerciseId);
    if (current == null) return const [];

    final currentMusclesLower =
        current.muscles.map((m) => m.toLowerCase().trim()).toList();
    final currentEquipLower =
        current.equipment.map((e) => e.toLowerCase().trim()).toList();

    return allExercises().where((other) {
      if (other.id == current.id) return false;

      final otherMusclesLower =
          other.muscles.map((m) => m.toLowerCase().trim()).toList();
      final otherEquipLower =
          other.equipment.map((e) => e.toLowerCase().trim()).toList();

      final muscleOverlap = currentMusclesLower
          .any((m) => otherMusclesLower.any((o) => o.contains(m)));

      final equipOverlap = currentEquipLower
          .any((eq) => otherEquipLower.any((o) => o.contains(eq)));

      return muscleOverlap && equipOverlap;
    }).toList(growable: false);
  }

  // ============================================================
  // string -> enum helpers for seed parsing
  // ============================================================

  ExerciseDifficulty _difficultyFromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'beginner':
        return ExerciseDifficulty.beginner;
      case 'advanced':
        return ExerciseDifficulty.advanced;
      case 'intermediate':
      default:
        return ExerciseDifficulty.intermediate;
    }
  }

  ExerciseIntent _intentFromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'strength':
        return ExerciseIntent.strength;
      case 'hypertrophy':
        return ExerciseIntent.hypertrophy;
      case 'mobility':
        return ExerciseIntent.mobility;
      case 'conditioning':
        return ExerciseIntent.conditioning;
      case 'endurance':
      default:
        return ExerciseIntent.endurance;
    }
  }
}
