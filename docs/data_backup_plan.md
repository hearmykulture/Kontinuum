# Data Backup & Restore Implementation Plan

## Goal & Success Criteria
- Allow users to export, import, and locally back up **all module data** (progress, missions, objectives, workouts, routines, budgets, stats, calendar history, banking/transactions, streaks, diet, fitness profile, notebooks/writing, etc.) as a single JSON payload without corrupting existing Hive storage.
- Provide guardrails so restores happen atomically, validate schema versions, and leave the app in a consistent state with providers refreshed.
- Offer an in-app UX entry point (e.g., from the Progress screen) that surfaces "Export", "Import", and "Factory Reset" actions with progress + error messaging.

## 1. Deep Scan Inventory (what must be captured)

### 1.1 Progress, stats, calendar, and missions
- Core boxes are declared in `HiveService` (`skillsBox`, `statsBox`, `categoriesBox`, `staticObjectivesBox`, `objectivesByDateBox`, `statHistoryBox`, `milestoneBox`, `activeMissionsBox`, `missionMetaBox`, `budgetsBox`). Export has to preserve custom date keys and relationships (`lib/data/hive_service.dart:12-204`).
- `ObjectiveProvider` maintains in-memory mirrors of skills/stats/objectives/milestones and per-day completions that drive the Progress screen, XP level bar, and calendar (`lib/providers/objective_provider.dart:24-149`).
- Missions rely on two Hive boxes for board state + metadata (`lib/providers/mission_provider.dart:13-132`). Any snapshot must include both `_byId` missions and `_metaBox` fields like `visibleIds`, `legendaryDaysYmd`, and suggestion cooldowns.

### 1.2 Streaks, rollover metadata, and XP side-effects
- Streak data lives in dedicated boxes opened in `main.dart` (`objectiveStreaks`, `categoryStreaks`, `dayStreak`, `bonusLedger`, `momentumWallet`, `skipReceipts`) plus `appMeta` for rollover checkpoints (`lib/main.dart:391-455`).
- `RolloverService` depends on `appMeta['lastSeenYmd']` and streak boxes to avoid double-paying XP or missing autocollects (`lib/core/time/rollover_service.dart:1-55`). These values must round-trip in backups so day streaks and skip receipts remain accurate.

### 1.3 Workouts, routines, logs, overrides, and active sessions
- Hive box names live in `WorkoutBoxes` (`workoutRoutines`, `workoutWorkouts`, `exerciseLibrary`, `workoutLogs`, `workoutSchedules`, `workoutRestOverrides`, plus legacy casing variants). They also run lightweight migrations that should not be re-triggered on import unless necessary (`lib/services/workout_boxes.dart:4-200`).
- `WorkoutProvider` mirrors those boxes into `_routines`, `_workouts`, `_history`, `_schedules` (`lib/providers/workout_provider.dart:91-190`). Export must include every model referenced there (routines, workouts, exercises, workout items, logs, schedules, rest overrides) and respect adapter differences.
- In-progress workout sessions are stored in `workout_session_state` with composite keys and rest-day logic (`lib/services/session_persistence_service.dart:1-200`). We need to serialize/deserialise `WorkoutSessionState` safely, keeping `_kCurrentKey` semantics intact.

### 1.4 Budgets, banking sync, and transactions
- `BudgetProvider` persists budgets via `HiveService.saveBudgets` using the `BudgetHive` model (`lib/providers/budget_provider.dart:280-384`).
- Transactions, merchant overrides, and Plaid sync timestamps store data in `BudgetBoxes` (`budgetTransactionsBox`, `budgetCategoryOverridesBox`, `budgetBankMetaBox`) that are ingested via `TransactionsStore` (`lib/services/budget_boxes.dart:5-41`, `lib/services/transactions_store.dart:1-95`).
- `BankSyncService` writes last-sync timestamps into `budgetBankMetaBox` (`lib/services/bank_sync_service.dart:5-48`), so meta exports must retain those keys.

### 1.5 Diet, fitness profile, and food libraries
- `DietProvider` directly reads/writes Hive boxes for entries, goal, foods, and weights; foods/weights boxes store dynamic maps, so serialization must preserve shape + nullables (`lib/providers/diet_provider.dart:9-200`).
- `FitnessProfileProvider` keeps a single `fitnessProfile` record under the `profile` key (`lib/providers/fitness_profile_provider.dart:1-28`).

### 1.6 Writing / notebooks / project manager
- `ProjectProvider` currently keeps projects and notebooks in-memory only (`lib/providers/project_provider.dart:1-151`). There is no persistence, so backups would lose writing dashboard data unless we add storage or encode provider state inside the export payload.
- `NotebookScreen` / `PageScreen` operate on `ProjectProvider` data (`lib/ui/screens/notebook_screen.dart:1-87`, `lib/ui/screens/page_screen.dart:1-120`). We'll need a plan to serialize projects, notebooks, and eventually page content once editors ship.

### 1.7 UI entry points & reset gaps
- Progress screen already centralizes access to missions, budgets, diet, workouts, and projects (`lib/ui/screens/progress_screen.dart:1-160`). It's the natural entry point for data management actions.
- `ResetService` only clears the core progress boxes (`lib/data/reset_service.dart:13-68`). Import needs a more complete reset that also wipes workouts, budgets, diet, streaks, banking, and notebook data to avoid mixing histories.

## 2. Design Constraints & Guardrails
1. **Single file JSON**: user requirement is a JSON file, so we package everything into one manifest (`.kontinuum-backup.json`). Large binary payloads are out of scope; we only serialize scalar/textual data already stored in Hive.
2. **Versioned schema**: treat the top-level `schemaVersion` as the coarse gate, but also stamp each payload section with its own `moduleVersion`. Maintain a declarative `transformersByModule` registry (e.g., `Map<String, List<JsonTransformer>>`) that executes during import before writing to Hive so we can remap enums, synthesize defaults, or swap adapters using the captured `adapterTypeId`. Document every transformer contract in `/docs/backup_schema.md` so future incompatibilities only require adding a transformer + bumping that module version rather than blocking imports outright.
3. **Atomic restore**: imports happen in memory + temp boxes first, then replace live boxes only if validation passes. Any failure must leave the previous data untouched.
4. **Provider refresh**: after import we must re-seed providers (`ObjectiveProvider`, `MissionProvider`, `WorkoutProvider`, etc.) so UI immediately reflects restored state without forcing an app restart.
5. **Platform file access**: use `file_selector`/`file_picker` + `path_provider` to copy exports into user-visible storage; on iOS we likely share via `share_plus` if direct path selection is not possible (deeper iCloud/Drive sync will land later).
6. **Long-running tasks**: large histories (workout logs, diet entries) require isolates or chunked streaming to prevent UI jank. Surface a modal progress indicator with cancel support.
7. **Manifest always all-in**: no per-module toggles—the backup always includes every supported section so restores produce a complete snapshot.
8. **Sensitive banking data**: transactions already live locally; ensure exported JSON clearly labels that it contains banking data (since we do not offer exclusion).
9. **Writing dashboard scope**: writing data still lives in memory-only providers, so either block the public backup launch on persistence work or ship the feature with explicit warnings that notebook/page bodies are omitted. Document whichever path we take in the UX copy + release notes so users understand the limitation.
10. **Migration hints**: capture each record’s Hive adapter `typeId` plus a serialized field map so future schema migrations can reconcile differences.
11. **Transport abstraction**: keep `DataBackupService` focused solely on converting Hive ↔ JSON. Define a minimal `BackupTransport` interface (`Future<void> save(Uint8List bytes)`, `Future<Uint8List> load()`) so the current local file picker transport and future cloud/iCloud/Drive sync transports can reuse the same serialization pipeline without special cases.

## 3. Step-by-Step Implementation Plan

### Phase 0 – Foundational prep
1. **Finalize manifest schema**: define `BackupManifest` Dart class with header + `payload` map. Plan sections: `progress`, `missions`, `streaks`, `workouts`, `sessions`, `budgets`, `transactions`, `diet`, `fitnessProfile`, `projects`, `notebooks`, `meta`. Document types in `/docs/backup_schema.md`.
2. **Extend ResetService**: add methods to clear every Hive box mentioned in §1 (workout boxes, rest overrides, session state, diet boxes, streak boxes, budget boxes, and any future writing boxes if we persist them). Make this callable both manually (factory reset) and internally during import preflight.

### Phase 1 – Serialization layer per domain
1. **Add `toBackupJson` helpers** for each Hive model that lacks `toJson`. Prefer standalone mappers to avoid polluting generated adapters (e.g., `ObjectiveBackupMapper.toMap(Objective)`) and have them emit `{ "adapterTypeId": <int>, "fields": { ... } }` envelopes the importer can validate, plus stamp each section with its `moduleVersion` so the transformer registry knows what upgrades to run.
2. **Progress/calendars**:
   - Serialize skills, stats, categories, static objectives, stat history, milestones, missions via existing `HiveService` iterators.
   - Convert `objectivesByDateBox` into `{ "yyyy-MM-dd": [ObjectiveMap...] }`, preserving normalized keys.
   - Include ObjectiveProvider-only state such as `_skillsByCategory` or computed XP only if it cannot be derived; otherwise keep manifest lean.
3. **Missions**: store `_byId` map plus meta fields (`visibleIds`, `lastRollYmd`, legendary history) exactly as `MissionProvider` expects when rehydrating.
4. **Streaks/meta**: dump every entry from the streak boxes + `appMeta['lastSeenYmd']` so rollover picks up where it left off.
5. **Workouts**: read raw Hive boxes rather than provider copies to avoid missing items. Export routines/workouts/exercises/logs/schedules/rest overrides plus workout-specific Hive adapters (type IDs already registered in `WorkoutBoxes`).
6. **Session drafts**: iterate over `workout_session_state` box keys, serializing both `_kCurrentKey` snapshot and any `<workout>|<YMD>` entries.
7. **Budgets + transactions**: re-use `BudgetProvider` conversions plus direct Hive reads for transactions, overrides, and bank meta.
8. **Diet + fitness**: export entries, goal, foods (maps), weights, and fitness profile. For dynamic boxes, serialize as literal `Map<String,dynamic>` structures.
9. **Projects/notebooks**: once persisted, dump them as arrays, including nested tracks/pages metadata when available.

### Phase 2 – Export pipeline
1. **`DataBackupService.export()`**: orchestrates reads above inside an isolate (using `compute`) and returns a `Uint8List` or string that is agnostic of how/where it is stored. Expose methods that accept a `BackupTransport` implementation so transports (local file picker today, cloud sync later) can reuse the same serializer.
2. **Transport implementations**: keep the default transport as a local picker flow—prompt the user via `file_selector`, write to temp storage, then pass the bytes to `LocalFileTransport.save()`. Future transports (iCloud Drive, background sync server) simply implement the same interface without touching `DataBackupService`. Add a share fallback for platforms without pickers.
3. **Progress UI**: create a modal bottom sheet `DataManagementSheet` (triggered from Progress screen overflow menu) that shows export progress, file path, and share button.
4. **Telemetry/logging**: log export start/finish events via `AnalyticsService` (if relevant) to help debug failures.

### Phase 3 – Import pipeline
1. **Choose file & validation**: invoke the selected `BackupTransport.load()` to obtain the JSON bytes, decode into `BackupManifest`, check `schemaVersion`/`moduleVersion`s, ensure required sections exist, and surface a diff summary (counts per module) before proceeding.
2. **Dry-run rehydration**: convert JSON back into model objects in memory, running the appropriate `transformersByModule` entries to upgrade legacy payloads and catching any adapter incompatibilities early.
3. **Transactional restore**:
   - Open all target boxes, back up current files (copy `.hive` to `*.bak` so users can revert manually).
   - Clear boxes via enhanced `ResetService`.
   - Write imported objects using `putAll` (respecting keying strategy, e.g., mission IDs, workout IDs, `_kCurrentKey`).
   - Flush boxes and verify record counts match manifest counts.
4. **Provider refresh**: call newly exposed `reloadFromStorage()` helpers on `ObjectiveProvider`, `MissionProvider`, `WorkoutProvider`, `DietProvider`, `BudgetProvider`, `ProjectProvider`, `FitnessProfileProvider`, etc., or rebuild the `MultiProvider` tree if necessary.
5. **Post-import housekeeping**: re-run `WorkoutBoxes.init()` migrations, `MissionProvider.ensureMissionSlotsFilled()`, `StreakEngine` recomputations, and `RolloverService.maybeRoll()` to synchronize derived state.
6. **Error handling**: if any write fails, restore `.bak` copies and show a descriptive error dialog. Keep a debug log file similar to the existing Hive init logging in `main.dart`.

### Phase 4 – UI/UX integration
1. **Entry point**: add a “⋯” overflow button or “Data” card on `ProgressScreen` that opens `DataManagementSheet` (wire via `ProgressScreen`’s FAB stack or app bar actions, `lib/ui/screens/progress_screen.dart:54-145`).
2. **Sheet layout**: three primary actions — `Export backup`, `Import backup`, `Factory reset` — plus copy that explains the export always includes every module (with a banking-data disclaimer) and reiterates overwrite warnings.
3. **User confirmations**: require explicit acknowledgment before destructive operations. On import, show a summary (counts per module + file timestamp) and a checkbox like “I understand this will overwrite all existing data”.
4. **Accessibility & theming**: reuse dark theme palette (Budget mint, XP gradients) so the screen matches existing UI.

### Phase 5 – Testing & verification
1. **Unit tests**: add serialization round-trip tests per domain (Objective ↔ map, Workout ↔ map, etc.).
2. **Integration tests**: script an end-to-end flow on Flutter integration test harness — seed data, export, clear boxes, import, assert providers show identical counts/values.
3. **Manual smoke tests**: on iOS + Android + macOS, verify file pickers, share flows, and error states (invalid JSON, mismatched schema version, truncated files).
4. **Performance profiling**: measure export/import time with large workout logs and bank histories; optimize by streaming large arrays or compressing JSON if necessary (optional gzip toggle).
5. **Security review**: ensure backups are stored only where the user explicitly chooses; remind them the JSON is unencrypted when containing banking data.

## 4. Outstanding Questions / Decisions
1. **Notebook/page persistence**: GA release should wait until notebook + page bodies live in Hive (e.g., `projectsBox`/`pagesBox`) so backups stay truthful. If we must soft-launch sooner, gate it behind an "experimental" label that states notebooks are metadata-only and exclude the action from marketing copy.
2. **Schema evolution transformers**: adopt module-level version numbers plus a `transformersByModule` registry and require that every breaking change adds a transformer + docs entry (`/docs/backup_schema.md`) instead of invalidating imports.
3. **Cloud storage hooks**: keep `DataBackupService` transport-agnostic by routing all persistence through the `BackupTransport` interface; today's local picker is one transport, while future iCloud/Drive sync just plugs in another implementation that reuses the same serialization/import pipeline.

## 5. Next Steps
1. Approve schema + module coverage list (Sections 1 & 2).
2. Decide on the writing module approach (delay launch until persistence exists vs. ship with explicit omissions) and expand ResetService accordingly.
3. Build serialization helpers + `DataBackupService` (Phases 1–3).
4. Ship the UI surface + provider refresh hooks.
5. Add automated tests + smoke the feature on target platforms.
