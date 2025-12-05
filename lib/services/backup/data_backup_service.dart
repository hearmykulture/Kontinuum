import 'dart:convert';
import 'dart:typed_data';

import 'package:kontinuum/services/backup/backup_manifest.dart';
import 'package:kontinuum/services/backup/backup_serializer.dart';
import 'package:kontinuum/services/backup/backup_transformer.dart';
import 'package:kontinuum/services/backup/backup_transport.dart';
import 'package:kontinuum/services/backup/provider_refresh_service.dart';
import 'package:kontinuum/services/backup/local_file_backup_transport.dart'
    show BackupUserCancelled;
import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:hive/hive.dart';

enum BackupValidationSeverity { info, warning, error }

class BackupValidationMessage {
  final String module;
  final BackupValidationSeverity severity;
  final String message;

  const BackupValidationMessage({
    required this.module,
    required this.severity,
    required this.message,
  });
}

class BackupImportPreview {
  final BackupManifest manifest;
  final List<BackupValidationMessage> messages;
  final List<int> missingAdapterTypeIds;

  const BackupImportPreview({
    required this.manifest,
    required this.messages,
    this.missingAdapterTypeIds = const [],
  });

  bool get hasErrors =>
      messages.any((m) => m.severity == BackupValidationSeverity.error) ||
      missingAdapterTypeIds.isNotEmpty;
}

class BackupValidationException implements Exception {
  final List<BackupValidationMessage> messages;

  BackupValidationException(this.messages);

  @override
  String toString() =>
      'BackupValidationException: ${messages.map((m) => m.message).join(', ')}';
}

/// High-level coordinator for export/import flows.
///
/// This does **not** touch storage directly; it is responsible for manifest
/// encoding/decoding, transformer application, and transport glue. The actual
/// box ↔ JSON serialization is handled by domain-specific mappers.
class DataBackupService {
  static const int currentSchemaVersion = 1;

  final BackupTransformerRegistry transformerRegistry;
  final BackupSerializer serializer;
  final ProviderRefreshService providerRefresher;
  final Map<int, String> requiredAdapterDescriptions;

  DataBackupService({
    this.transformerRegistry = const BackupTransformerRegistry(),
    BackupSerializer? serializer,
    this.providerRefresher = const ProviderRefreshService(),
    this.requiredAdapterDescriptions = const {
      // streaks
      120: 'ObjectiveStreak (streaks)',
      121: 'CategoryStreak (streaks)',
      122: 'DayStreak (streaks)',
      123: 'BonusLedgerDay (streaks)',
      124: 'MomentumWallet (streaks)',
      125: 'SkipReceipt (streaks)',
      // budgets / transactions
      40: 'BudgetTransaction',
      41: 'MerchantOverride',
      100: 'BudgetHive',
      101: 'BudgetCategoryHive',
      102: 'RecurringExpenseHive',
      // diet (runtime uses fixed adapters below 223)
      180: 'Diet MealSlot (fixed)',
      181: 'DietEntry (fixed)',
      182: 'DietGoal (fixed)',
      // workouts
      200: 'DietGoalAdapter (workout models)',
      201: 'DietStrictness',
      202: 'ExerciseIntent',
      203: 'ExerciseDifficulty',
      204: 'BlockType',
      205: 'DietSettings',
      206: 'Exercise',
      207: 'WorkoutItem',
      208: 'WorkoutBlock',
      209: 'Workout',
      210: 'Routine',
      211: 'SetLog',
      212: 'ExerciseLog',
      213: 'StatDelta',
      214: 'SessionTotals',
      215: 'WorkoutLog',
      218: 'RepetitionMode',
      219: 'RepetitionUnit',
      220: 'WorkoutSchedule',
      221: 'RestSchedule',
      // sessions
      222: 'SavedSetData',
      223: 'WorkoutSessionState',
    },
  }) : serializer = serializer ?? BackupSerializer();

  /// Creates an empty manifest scaffold with all module keys present.
  BackupManifest scaffoldManifest() =>
      BackupManifest.empty(schemaVersion: currentSchemaVersion);

  /// Encode a manifest into UTF-8 JSON bytes for persistence.
  Uint8List encodeManifest(BackupManifest manifest) {
    final jsonString = jsonEncode(manifest.toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Decode JSON bytes into a manifest object.
  BackupManifest decodeManifest(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return BackupManifest.fromJson(decoded);
  }

  /// Save a prepared manifest using the provided [transport].
  Future<void> saveManifest({
    required BackupManifest manifest,
    required BackupTransport transport,
    String? suggestedFileName,
  }) async {
    final bytes = encodeManifest(manifest);
    await transport.save(bytes, suggestedFileName: suggestedFileName);
  }

  /// Validate and apply registered transformers to an incoming manifest.
  Future<BackupImportPreview> dryRunTransform(Uint8List bytes) async {
    final manifest = decodeManifest(bytes);
    final transformedSections = <String, BackupSection>{};

    for (final entry in manifest.sections.entries) {
      final section = entry.value;
      Map<String, dynamic> payload = section.payload;

      for (final transformer
          in transformerRegistry.transformersFor(section.key)) {
        payload = await transformer(payload, section, manifest);
      }

      transformedSections[entry.key] = section.copyWith(payload: payload);
    }

    final upgradedManifest = manifest.copyWith(sections: transformedSections);
    final messages = _validateManifest(upgradedManifest);
    final missingAdapters = _missingRequiredAdapters();

    return BackupImportPreview(
      manifest: upgradedManifest,
      messages: messages,
      missingAdapterTypeIds: missingAdapters,
    );
  }

  /// Export all modules into a manifest.
  Future<BackupManifest> exportManifest({
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  }) async {
    final sections = await serializer.exportAll(
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    return scaffoldManifest().copyWith(sections: sections);
  }

  /// Export and immediately persist via [transport].
  Future<void> exportAndSave({
    required BackupTransport transport,
    String? suggestedFileName,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
  }) async {
    final manifest = await exportManifest(
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    await saveManifest(
      manifest: manifest,
      transport: transport,
      suggestedFileName:
          suggestedFileName ?? _defaultFileName(manifest.createdAt),
    );
  }

  /// Load, validate, transform, and write data back into Hive boxes.
  Future<void> importFromBytes(
    Uint8List bytes, {
    bool resetFirst = true,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
    ObjectiveProvider? objectiveProvider,
    MissionProvider? missionProvider,
    WorkoutProvider? workoutProvider,
    DietProvider? dietProvider,
    FitnessProfileProvider? fitnessProfileProvider,
    BudgetProvider? budgetProvider,
  }) async {
    final preview = await dryRunTransform(bytes);
    if (preview.hasErrors) {
      throw BackupValidationException(preview.messages);
    }
    if (preview.missingAdapterTypeIds.isNotEmpty) {
      throw BackupValidationException([
        for (final id in preview.missingAdapterTypeIds)
          BackupValidationMessage(
            module: 'adapters',
            severity: BackupValidationSeverity.error,
            message:
                'Required Hive adapter $id (${requiredAdapterDescriptions[id] ?? 'unknown'}) is not registered.',
          ),
      ]);
    }
    await serializer.importAll(
      preview.manifest,
      resetFirst: resetFirst,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );

    await providerRefresher.refresh(
      objectiveProvider: objectiveProvider,
      missionProvider: missionProvider,
      workoutProvider: workoutProvider,
      dietProvider: dietProvider,
      fitnessProfileProvider: fitnessProfileProvider,
      budgetProvider: budgetProvider,
    );
  }

  /// Load bytes from [transport] and perform a full import.
  Future<void> importFromTransport(
    BackupTransport transport, {
    bool resetFirst = true,
    void Function(String stage)? onProgress,
    BackupCancellationToken? cancellationToken,
    ObjectiveProvider? objectiveProvider,
    MissionProvider? missionProvider,
    WorkoutProvider? workoutProvider,
    DietProvider? dietProvider,
    FitnessProfileProvider? fitnessProfileProvider,
    BudgetProvider? budgetProvider,
  }) async {
    Uint8List bytes;
    bytes = await transport.load();
    if (bytes.isEmpty) return; // silent cancel

    await importFromBytes(
      bytes,
      resetFirst: resetFirst,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
      objectiveProvider: objectiveProvider,
      missionProvider: missionProvider,
      workoutProvider: workoutProvider,
      dietProvider: dietProvider,
      fitnessProfileProvider: fitnessProfileProvider,
      budgetProvider: budgetProvider,
    );
  }

  List<BackupValidationMessage> _validateManifest(BackupManifest manifest) {
    final messages = <BackupValidationMessage>[];

    if (manifest.schemaVersion > currentSchemaVersion) {
      messages.add(
        BackupValidationMessage(
          module: 'manifest',
          severity: BackupValidationSeverity.error,
          message:
              'Backup schema ${manifest.schemaVersion} is newer than supported $currentSchemaVersion.',
        ),
      );
    }

    for (final key in BackupModuleKeys.all) {
      if (!manifest.sections.containsKey(key)) {
        messages.add(
          BackupValidationMessage(
            module: key,
            severity: BackupValidationSeverity.warning,
            message: 'Module "$key" missing from payload; restore will skip it.',
          ),
        );
      }
    }

    return messages;
  }

  List<int> _missingRequiredAdapters() {
    final missing = <int>[];
    requiredAdapterDescriptions.forEach((id, _) {
      if (!Hive.isAdapterRegistered(id)) {
        missing.add(id);
      }
    });
    return missing;
  }

  String _defaultFileName(DateTime createdAt) {
    final stamp =
        createdAt.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    return 'kontinuum-backup-$stamp.json';
  }
}

class BackupCancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) {
      throw BackupCancelledException();
    }
  }
}

class BackupCancelledException implements Exception {
  @override
  String toString() => 'BackupCancelled';
}
