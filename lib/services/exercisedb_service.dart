// lib/services/exercisedb_service.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/workout_boxes.dart';

/// Remote API base URL (dev-only).
/// You can override this with:
///   --dart-define=EXERCISE_API_BASE_URL=http://192.168.1.23:8000/api/v1/exercises
const String _kExerciseRemoteBaseUrl = String.fromEnvironment(
  'EXERCISE_API_BASE_URL',
  defaultValue: 'http://localhost:80/api/v1/exercises',
);

/// Pulls exercises from:
/// 1) assets/workout/exercisedb.json (preferred, offline)
/// 2) optional dev server (desktop-only, debug-only)
///
/// We store everything into WorkoutBoxes.exerciseBox as our `Exercise` model.
class ExerciseDbService {
  ExerciseDbService._();
  static final ExerciseDbService instance = ExerciseDbService._();

  bool _didSync = false;
  bool _hasPurgedExcluded = false;

  Future<void> ensureSynced() async {
    // If the box is empty (after reset/clear), force a fresh sync.
    if (WorkoutBoxes.exerciseBox.isEmpty) {
      _didSync = false;
    }
    if (_didSync) return;

    // 1) try local asset first
    final ok = await _tryAssetSync();
    if (ok) {
      _didSync = true;
      return;
    }

    // 2) optional remote dev sync (desktop + debug only)
    await _tryRemoteSync();

    _didSync = true;
  }

  /// Reads assets/workout/exercisedb.json and upserts into Hive.
  /// Returns true only if we actually parsed a non-empty list.
  Future<bool> _tryAssetSync() async {
    try {
      final raw = await rootBundle.loadString('assets/workout/exercisedb.json');

      if (raw.trim().isEmpty) {
        debugPrint('⚠️ ExerciseDbService: asset is empty, skipping.');
        return false;
      }

      final dynamic decoded = json.decode(raw);

      // We accept:
      // - pure array: [ {...}, {...} ]
      // - object with data: { "data": [ {...}, ... ] }
      List<dynamic> rows;
      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
        rows = decoded['data'] as List<dynamic>;
      } else {
        debugPrint(
          '⚠️ ExerciseDbService: asset is not a list (got ${decoded.runtimeType}), skipping.',
        );
        return false;
      }

      if (rows.isEmpty) {
        debugPrint('⚠️ ExerciseDbService: asset list is empty, skipping.');
        return false;
      }

      await _upsertRows(rows);
      debugPrint(
        '✅ ExerciseDbService (asset): loaded ${rows.length} exercises',
      );
      return true;
    } catch (e, st) {
      debugPrint('⚠️ ExerciseDbService asset sync failed: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Dev-only: hit your local server and page through results.
  /// This is *only* called on desktop + in debug builds to avoid
  /// "Connection refused" on physical devices.
  Future<void> _tryRemoteSync() async {
    // Skip completely in release.
    if (!kDebugMode) {
      debugPrint(
        'ℹ️ ExerciseDbService remote sync skipped (not in debug mode).',
      );
      return;
    }

    // Skip on non-desktop platforms (Android/iOS).
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      debugPrint(
        'ℹ️ ExerciseDbService remote sync skipped (not on desktop platform).',
      );
      return;
    }

    const limit = 50;
    var offset = 0;
    var totalImported = 0;

    try {
      while (true) {
        final uri = Uri.parse(_kExerciseRemoteBaseUrl).replace(
          queryParameters: <String, String>{
            'offset': '$offset',
            'limit': '$limit',
          },
        );

        debugPrint('🌐 ExerciseDbService remote: GET $uri');
        final resp = await http.get(uri);

        if (resp.statusCode != 200) {
          debugPrint(
            '⚠️ ExerciseDbService remote: got ${resp.statusCode} at offset=$offset',
          );
          break;
        }

        final decoded = json.decode(resp.body);
        final List<dynamic> data = decoded is Map && decoded['data'] is List
            ? decoded['data'] as List
            : const [];

        if (data.isEmpty) break;

        await _upsertRows(data);
        totalImported += data.length;
        offset += limit;
      }

      debugPrint(
        '✅ ExerciseDbService (remote): imported $totalImported exercises',
      );
    } catch (e, st) {
      debugPrint('⚠️ ExerciseDbService remote sync failed: $e');
      debugPrint('$st');
      // Swallow: remote is best-effort dev sugar.
    }
  }

  /// Convert generic ExerciseDB rows into our Exercise model + put into box.
  Future<void> _upsertRows(List<dynamic> rows) async {
    final box = WorkoutBoxes.exerciseBox;

    if (!_hasPurgedExcluded) {
      await _purgeExcluded(box);
      await _purgeLegacyCdn(box);
      _hasPurgedExcluded = true;
    }

    for (final item in rows) {
      if (item is! Map<String, dynamic>) continue;
      final map = item;

      // v1 API uses "exerciseId"
      final String idRaw =
          (map['exerciseId'] ?? map['id'] ?? '').toString().trim();
      final String nameRaw = map['name'] ?? '').toString().trim();

      if (idRaw.isEmpty && nameRaw.isEmpty) continue;

      if (_shouldExcludeName(nameRaw)) {
        continue;
      }

      final String exerciseId =
          idRaw.isNotEmpty ? 'exdb_$idRaw' : 'exdb_${nameRaw.toLowerCase()}';

      // normalize instructions
      final String instructionsJoined = (() {
        final instr = map['instructions'];
        if (instr is List) {
          return instr.map((e) => e.toString()).join('\n');
        }
        if (instr is String) return instr;
        return '';
      })();

      // normalize muscles/bodyparts
      final List<String> muscles = [
        ..._asStringList(map['targetMuscles']),
        ..._asStringList(map['bodyParts']),
        ..._asStringList(map['secondaryMuscles']),
        if (map['target'] != null) map['target'].toString(),
        if (map['bodyPart'] != null) map['bodyPart'].toString(),
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();

      final List<String> equipment = [
        ..._asStringList(map['equipments']),
        if (map['equipment'] != null) map['equipment'].toString(),
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      final String? mediaUrl = map['gifUrl'] ?? map['mediaUrl'])?.toString();

      final existing = box.get(exerciseId);

      if (existing is Exercise) {
        // Manual patch (no copyWith in your model)
        final List<String> fallbackMuscles =
            existing.muscles.isNotEmpty ? existing.muscles : muscles;
        final List<String> primaryMuscles = existing.primaryMuscles.isNotEmpty
            ? existing.primaryMuscles
            : (fallbackMuscles.isNotEmpty
                ? <String>[fallbackMuscles.first]
                : const <String>[]);
        final List<String> secondaryMuscles =
            existing.secondaryMuscles.isNotEmpty
                ? existing.secondaryMuscles
                : (fallbackMuscles.length > 1
                    ? fallbackMuscles.sublist(1)
                    : const <String>[]);

        final updated = Exercise(
          id: existing.id,
          name: existing.name.isNotEmpty ? existing.name : nameRaw,
          muscles: existing.muscles.isNotEmpty ? existing.muscles : muscles,
          equipment:
              existing.equipment.isNotEmpty ? existing.equipment : equipment,
          difficulty: existing.difficulty,
          intent: existing.intent,
          instructions: existing.instructions.isNotEmpty
              ? existing.instructions
              : instructionsJoined,
          cues: existing.cues,
          primaryMuscles: primaryMuscles,
          secondaryMuscles: secondaryMuscles,
          mediaUrl: mediaUrl ?? existing.mediaUrl,
          attribution: existing.attribution ?? 'ExerciseDB',
        );
        await box.put(exerciseId, updated);
      } else {
        final List<String> primaryMuscles =
            muscles.isNotEmpty ? <String>[muscles.first] : const <String>[];
        final List<String> secondaryMuscles =
            muscles.length > 1 ? muscles.sublist(1) : const <String>[];

        final ex = Exercise(
          id: exerciseId,
          name: nameRaw.isNotEmpty ? nameRaw : 'Exercise',
          muscles: muscles,
          equipment: equipment,
          difficulty: ExerciseDifficulty.intermediate,
          intent: ExerciseIntent.hypertrophy,
          instructions: instructionsJoined,
          cues: const <String>[],
          primaryMuscles: primaryMuscles,
          secondaryMuscles: secondaryMuscles,
          mediaUrl: mediaUrl,
          attribution: 'ExerciseDB',
        );
        await box.put(ex.id, ex);
      }
    }
  }

  Future<void> _purgeLegacyCdn(Box<Exercise> box) async {
    final keysToDelete = <dynamic>[];
    for (final key in box.keys) {
      final Exercise? exercise = box.get(key);
      final String? url = exercise?.mediaUrl;
      if (url != null && url.contains('static.exercisedb.dev')) {
        keysToDelete.add(key);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
      debugPrint(
        '🧹 ExerciseDbService: purged ${keysToDelete.length} legacy static.exercisedb.dev entries',
      );
    }
  }

  List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<void> _purgeExcluded(Box<Exercise> box) async {
    final List<dynamic> keysToDelete = [];
    for (final key in box.keys) {
      final Exercise? ex = box.get(key);
      if (ex == null) continue;
      if (_shouldExcludeName(ex.name)) {
        keysToDelete.add(key);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
  }

  bool _shouldExcludeName(String name) {
    final String normalized = _normalizeName(name);
    if (normalized.isEmpty) return false;
    for (final pattern in _kExcludedNamePatterns) {
      if (normalized == pattern || normalized.contains(pattern)) {
        return true;
      }
    }
    return false;
  }
}

const List<String> _kExcludedNamePatterns = <String>[
  'barbell bench press',
  'plank hold',
  'single arm dumbbell row',
  '3 4 sit up',
];

String _normalizeName(String raw) {
  if (raw.isEmpty) return '';
  final String lower = raw.toLowerCase();
  final String cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
}
