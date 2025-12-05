# Backup Manifest Schema

This document tracks the JSON format used by `DataBackupService` when exporting or importing a full-app snapshot. The manifest is designed to be:
- A single JSON file (`.kontinuum-backup.json`).
- Versioned at the schema level **and** per-module so individual sections can evolve with transformers.
- Transport-agnostic (local file picker today, cloud/iCloud/Drive later via `BackupTransport`).

## Top-level shape

```json
{
  "schemaVersion": 1,
  "createdAt": "2024-03-01T19:20:30.000Z",
  "moduleVersions": {
    "progress": 1,
    "missions": 1,
    "streaks": 1,
    "workouts": 1,
    "sessions": 1,
    "budgets": 1,
    "transactions": 1,
    "diet": 1,
    "fitnessProfile": 1,
    "projects": 1,
    "notebooks": 1,
    "meta": 1
  },
  "sections": {
    "<moduleKey>": {
      "key": "progress",
      "moduleVersion": 1,
      "counts": { "skills": 12, "objectives": 140 },
      "payload": {
        "boxes": [
          {
            "name": "skillsBox",
            "entries": [
              { "key": "skill-1", "data": "<base64>", "typeId": 5 }
            ]
          }
        ]
      }
    }
  },
  "meta": {
    "appVersion": "1.0.0"
  }
}
```

Notes:
- `schemaVersion` gates coarse changes to the envelope. Individual modules track their own `moduleVersion` to allow targeted transformers.
- `counts` is optional, but helps the importer validate that write counts match the manifest.
- Every record payload captures a base64-encoded Hive binary snapshot (`data`) plus the detected `typeId`. This preserves adapter fields without hand-written `toJson` mappers and lets future migrations reconcile schema changes.

## Record encoding

Each box entry is exported as `{ "key": <Hive key>, "data": "<base64>", "typeId": <int?> }`, where `data` is produced by Hive's binary writer so adapters and enums are preserved. During import we decode with Hive's binary reader, so adapters must be registered before running an import.

## Module keys

Canonical keys live in `BackupModuleKeys` (see `lib/services/backup/backup_manifest.dart`). The manifest always includes entries for:
- `progress`
- `missions`
- `streaks`
- `workouts`
- `sessions`
- `budgets`
- `transactions`
- `diet`
- `fitnessProfile`
- `projects`
- `notebooks`
- `meta`

## Transformers

Use `BackupTransformerRegistry` (`lib/services/backup/backup_transformer.dart`) to register ordered transformers per module. Each transformer receives the raw payload, section metadata, and full manifest, and should return an updated payload. Add a short note in this doc whenever a breaking change is introduced and bump that module's version.

### Current transformer policy
- No breaking transformers registered yet. Any future schema bump should add a transformer entry and bump the affected `moduleVersion`.

## Reset/restore guardrails

- `ResetService.clearAllData()` now wipes all known boxes (progress, streaks, workouts, sessions, budgets/transactions, diet, fitness profile) to keep imports from mixing histories.
- Imports run a dry-run first: decode manifest → apply transformers → validate required modules and adapter registrations → surface a summary. Actual imports now (a) create `.bak` copies of box files, (b) verify record counts against the manifest after writes, and (c) refresh providers so UI state matches restored data without a restart.
- Required Hive adapters are checked up-front (workout, diet, session state, streaks, budgets). Missing adapters block imports with a clear error.
- Long-running operations expose stage progress and cancellation hooks; UI should surface a progress indicator and cancel affordance.

## Outstanding work

- Add per-module serializers/deserializers that produce `{ adapterTypeId, fields }` envelopes for every Hive record.
- Wire transports (local file picker, share) to `DataBackupService.saveManifest`.
- Add tests to round-trip each module and verify provider refresh after import.
