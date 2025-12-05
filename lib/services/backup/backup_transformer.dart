import 'dart:async';

import 'package:kontinuum/services/backup/backup_manifest.dart';

typedef BackupTransformer = FutureOr<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
  BackupSection section,
  BackupManifest manifest,
);

/// Registry for module-level JSON upgrade transformers.
class BackupTransformerRegistry {
  final Map<String, List<BackupTransformer>> _transformersByModule;

  const BackupTransformerRegistry({
    Map<String, List<BackupTransformer>> transformersByModule =
        const <String, List<BackupTransformer>>{},
  }) : _transformersByModule = transformersByModule;

  List<BackupTransformer> transformersFor(String moduleKey) {
    return _transformersByModule[moduleKey] ?? const <BackupTransformer>[];
  }

  BackupTransformerRegistry copyWith({
    Map<String, List<BackupTransformer>>? transformersByModule,
  }) {
    return BackupTransformerRegistry(
      transformersByModule:
          transformersByModule ?? Map.of(_transformersByModule),
    );
  }
}
