import 'dart:convert';
import 'package:kontinuum/core/time/app_clock.dart';

/// Canonical module keys so the manifest stays consistent across exports.
class BackupModuleKeys {
  static const String progress = 'progress';
  static const String missions = 'missions';
  static const String streaks = 'streaks';
  static const String workouts = 'workouts';
  static const String sessions = 'sessions';
  static const String budgets = 'budgets';
  static const String transactions = 'transactions';
  static const String diet = 'diet';
  static const String fitnessProfile = 'fitnessProfile';
  static const String projects = 'projects';
  static const String notebooks = 'notebooks';
  static const String meta = 'meta';

  static const List<String> all = [
    progress,
    missions,
    streaks,
    workouts,
    sessions,
    budgets,
    transactions,
    diet,
    fitnessProfile,
    projects,
    notebooks,
    meta,
  ];
}

/// Envelope for a single module in the manifest.
class BackupSection {
  final String key;
  final int moduleVersion;
  final Map<String, dynamic> payload;
  final Map<String, int> counts;

  const BackupSection({
    required this.key,
    required this.moduleVersion,
    required this.payload,
    this.counts = const <String, int>{},
  });

  BackupSection copyWith({
    int? moduleVersion,
    Map<String, dynamic>? payload,
    Map<String, int>? counts,
  }) {
    return BackupSection(
      key: key,
      moduleVersion: moduleVersion ?? this.moduleVersion,
      payload: payload ?? this.payload,
      counts: counts ?? this.counts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'moduleVersion': moduleVersion,
      'counts': counts,
      'payload': payload,
    };
  }

  factory BackupSection.fromJson(String key, Map<String, dynamic> json) {
    return BackupSection(
      key: key,
      moduleVersion: (json['moduleVersion'] as num?)?.toInt() ?? 1,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      counts: (json['counts'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
          ) ??
          const <String, int>{},
    );
  }

  factory BackupSection.empty(String key, {int moduleVersion = 1}) {
    return BackupSection(
      key: key,
      moduleVersion: moduleVersion,
      payload: const <String, dynamic>{},
    );
  }
}

/// Full manifest container written to disk.
class BackupManifest {
  final int schemaVersion;
  final DateTime createdAt;
  final Map<String, int> moduleVersions;
  final Map<String, BackupSection> sections;
  final Map<String, dynamic> meta;

  const BackupManifest({
    required this.schemaVersion,
    required this.createdAt,
    required this.moduleVersions,
    required this.sections,
    this.meta = const <String, dynamic>{},
  });

  factory BackupManifest.empty({
    int schemaVersion = 1,
    DateTime? createdAt,
    Map<String, int>? moduleVersions,
    Map<String, dynamic> meta = const <String, dynamic>{},
  }) {
    final resolvedModuleVersions = <String, int>{
      for (final key in BackupModuleKeys.all)
        key: moduleVersions?[key] ?? 1,
    };
    final sectionMap = <String, BackupSection>{
      for (final entry in resolvedModuleVersions.entries)
        entry.key: BackupSection.empty(
          entry.key,
          moduleVersion: entry.value,
        ),
    };

    return BackupManifest(
      schemaVersion: schemaVersion,
      createdAt: createdAt ?? AppClock.now().toUtc(),
      moduleVersions: resolvedModuleVersions,
      sections: sectionMap,
      meta: meta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'createdAt': createdAt.toIso8601String(),
      'moduleVersions': moduleVersions,
      'sections': {
        for (final entry in sections.entries) entry.key: entry.value.toJson(),
      },
      'meta': meta,
    };
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final moduleVersions = (json['moduleVersions'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ) ??
        const <String, int>{};

    final sectionJson =
        (json['sections'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sections = <String, BackupSection>{
      for (final entry in sectionJson.entries)
        entry.key: BackupSection.fromJson(
          entry.key,
          (entry.value as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
    };

    return BackupManifest(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')
              ?.toUtc() ??
          AppClock.now().toUtc(),
      moduleVersions: moduleVersions,
      sections: sections,
      meta: (json['meta'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  BackupManifest copyWith({
    int? schemaVersion,
    DateTime? createdAt,
    Map<String, int>? moduleVersions,
    Map<String, BackupSection>? sections,
    Map<String, dynamic>? meta,
  }) {
    return BackupManifest(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      moduleVersions: moduleVersions ?? this.moduleVersions,
      sections: sections ?? this.sections,
      meta: meta ?? this.meta,
    );
  }
}
