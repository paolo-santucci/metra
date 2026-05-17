# Data-layer Assessment — Skip Cold-Start Backup If No New Data

**Date:** 2026-05-14  
**Scope:** `AppSettingsData`, `AppSettingsRepository`, `DriftAppSettingsRepository`,
`AppDatabase`, `DailyLogRepository`, `DriftDailyLogRepository`  
**Purpose:** Pre-implementation assessment to inform spec design for
"skip automatic cold-start backup when no data has changed since last backup."

---

## Summary

The codebase has a clean precedent for a dedicated-writer field on AppSettings
(`updateBackupState`, `markOnboardingComplete`, `saveDeclaredCycleLength`) that
is exactly the right model for Option (a). Neither `updatedAt` rows (Option b) nor
file mtime (Option c) exist and both would require either a larger schema change or
introduce false positives. The schema is at **v8**; the next migration lands at v9.
The restore path introduces a non-trivial edge case that must be decided in the spec.

---

## Findings

### Critical

**C-1. Option (c) DB file mtime is unsuitable — eliminates itself.**  
`AppSettings.updateSettings` is called on every user-settings change (theme, language,
notification toggle). File mtime would advance on those writes even though the backup
payload (`BackupSnapshot`) contains only logs and symptoms. Every settings edit would
trigger a backup on next cold-start. No implementation needed; reject at spec time.  
_Evidence:_ `backup_service.dart:14-28` — snapshot contains only `logsWithSymptoms`.
`app_database.dart:43-67` — DailyLogs and PainSymptoms schemas only.

**C-2. Option (b) `MAX(updatedAt)` is mis-framed — no such column exists.**  
`DailyLogs` (app_database.dart:43-57) and `PainSymptoms` (61-67) have no `updatedAt`
or `modifiedAt` column. Pursuing Option (b) would require a schema migration _plus_ a
new DAO query, making it materially more invasive than Option (a). Additionally,
`MAX(date)` would not detect deletes — if the user's last action was deleting all logs,
the field remains at the previous insert date.  
_Fix suggestion:_ Discard Option (b) in the spec and explain the delete-blindness
argument as the deciding factor.

**C-3. Restore path creates a re-backup loop if `lastDataWriteAt` is bumped naively.**  
`SyncOrchestrator.restore()` (sync_orchestrator.dart:133) calls
`_logRepo.deleteAllAndReplace(logs, symptomsMap)`. If that call bumps
`lastDataWriteAt`, the next cold-start will find `lastDataWriteAt > lastBackupAt`
(because the restore sets `lastBackupAt` to a past timestamp or null) and trigger
an immediate re-backup. This is wasteful and potentially confusing. The spec must
address one of: (a) don't bump during restore, (b) after restore set
`lastDataWriteAt = lastBackupAt` = restore timestamp.  
_Evidence:_ `sync_orchestrator.dart:87-91` — `lastBackupAt` is updated only on
successful upload; the restore does not call `updateBackupState`.

### Important

**I-1. `_toCompanion` exclusion must be explicit and documented.**  
`DriftAppSettingsRepository._toCompanion` (drift_app_settings_repository.dart:61-71)
deliberately excludes dedicated-writer fields (`dropboxEmail`, `lastBackupAt`,
`onboardingCompleted`, `declaredCycleLength`). The new `lastLogOrSymptomWriteAt`
field must also be excluded here — and the exclusion needs a comment parallel to
the existing pattern. Omitting it would cause `updateSettings()` to silently overwrite
the field with whatever the current entity holds (typically null or stale).

**I-2. `copyWith` cannot reset nullable `DateTime?` to null — same trap as `lastBackupAt`.**  
`AppSettingsData.copyWith` (entity:77-109) cannot clear nullable fields to null.
The `lastBackupAt` comment at entity:84-85 and the `updateBackupState` dedicated-writer
at drift_app_settings_repository.dart:95-106 already document this pattern. The new
`lastLogOrSymptomWriteAt` field must follow the same dedicated-writer approach;
including it in `copyWith` would be incorrect for reset use cases.

**I-3. `withDefault(Constant(...))` is mandatory for the new schema column.**  
`AppSettingsDao.getOrCreateSettings` (app_settings_dao.dart:41-44) inserts only
`languageCode: Value('')`; all other columns rely on `withDefault(...)`. If the new
column lacks `withDefault(const Constant(null))`, it will be an error for NOT NULL
columns or ambiguous for nullable columns on first-launch row creation.  
_Pattern to follow:_ v7 (`notificationTimeMinutes`, app_database.dart:246-253),
v8 (`firstDayOfWeek`, 254-261).

**I-4. All six DailyLogRepository write methods are write-surface — none can be omitted.**  
The following calls can change backup-relevant data:

| Method | File:line | Notes |
|---|---|---|
| `saveDailyLog` | daily_log_repository.dart:29 | Standard log entry |
| `deleteDailyLog` | :31 | Must bump on delete |
| `replacePainSymptoms` | :43 | Symptom edits only |
| `deleteAll` | :48 | Mass-delete |
| `deleteAllAndReplace` | :53 | CSV import — restore path |
| `upsertAllLogs` | :60 | CSV merge import |

`deleteAllAndReplace` and `upsertAllLogs` are the ones most likely to be missed in
implementation.

**I-5. Both fake repositories need updating.**  
`test/helpers/fake_app_settings_repository.dart` fully reconstructs `AppSettingsData`
in `updateBackupState` and `markOnboardingComplete` (lines 44-54, 60-71) without
forwarding newer fields. When `lastLogOrSymptomWriteAt` is added, every manual-copy
block in this file will silently drop it. `test/helpers/fake_daily_log_repository.dart`
will need a new dedicated-writer method or callback for the bump.

### Suggestion

**S-1. Naming: `lastLogOrSymptomWriteAt` over `lastDataWriteAt`.**  
The brief uses `lastDataWriteAt`. A more precise name reflects exact scope — only
log/symptom mutations, not settings mutations. This prevents future confusion about
whether a settings-only session should be considered "data changed."

**S-2. First-run null handling must be spec'd explicitly.**  
At first launch both `lastLogOrSymptomWriteAt` and `lastBackupAt` are null. The
skip-logic must treat `null lastLogOrSymptomWriteAt` as "no data ever written →
nothing to backup" (skip). Treating it as "unknown → backup anyway" would make the
feature a no-op for new installs.

---

## What Was Done Well

- `updateBackupState` with explicit `Value(null)` semantics (drift_app_settings_repository.dart:103-105) is the clean precedent for writing nullable DateTime fields outside `copyWith`. No design debt to resolve here.
- The `_fromRow` clamping pattern (`clamp(1, AppConstants.kMaxAdvanceDays)`, `clamp(0, 1439)`) at drift_app_settings_repository.dart:51-57 is a good model for defensive reads on any new integer/timestamp column.
- The existing migration blocks (app_database.dart:246-261) are clean, minimal, single-column `addColumn` additions with no `customStatement` — exactly what v9 needs.

---

## Spec Inputs

### Components and files affected

| File | Change |
|---|---|
| `lib/domain/entities/app_settings_data.dart` | Add `final DateTime? lastLogOrSymptomWriteAt` field; update `_AppSettingsDataDefaults` (null default); **do not add to `copyWith`** |
| `lib/domain/repositories/app_settings_repository.dart` | Add `Future<void> recordDataWrite(DateTime ts)` (dedicated writer) |
| `lib/data/repositories/drift_app_settings_repository.dart` | Implement `recordDataWrite`; exclude field from `_toCompanion` with explicit comment |
| `lib/data/database/app_database.dart` | Add `DateTimeColumn get lastLogOrSymptomWriteAt => dateTime().nullable()()` to `AppSettings`; bump `schemaVersion` to 9; add `if (from < 9)` migration block |
| `lib/domain/repositories/daily_log_repository.dart` | No structural change; spec must decide call-site location for bump |
| `lib/data/repositories/drift_daily_log_repository.dart` | If bump is co-located here: inject `AppSettingsRepository`; add bump call in all six write methods. If bump is in use-cases: no change here |
| `lib/data/services/backup/sync_orchestrator.dart` | Restore path must set `lastLogOrSymptomWriteAt` to avoid re-backup loop |
| `lib/app.dart:113-122` (`_autoSyncIfConfigured`) | Add skip-guard: compare `settings.lastLogOrSymptomWriteAt` vs `settings.lastBackupAt` |
| `test/helpers/fake_app_settings_repository.dart` | Add `recordDataWrite` method; update all manual-copy blocks to forward new field |
| `test/helpers/fake_daily_log_repository.dart` | Add mechanism for bump (callback or direct field) |
| `test/data/repositories/app_settings_repository_test.dart` | Add tests: default null from fresh row; round-trip; `_toCompanion` exclusion (field not overwritten by `updateSettings`) |

### Patterns to follow

- **Dedicated-writer pattern** — `updateBackupState` (drift_app_settings_repository.dart:95-106): use `Value(ts)` not `copyWith`; never route through `updateSettings`.
- **`withDefault(const Constant(null))`** on the new nullable column — canonical precedent: v5 `declaredCycleLength` (app_database.dart:213-217).
- **`_toCompanion` exclusion with comment** — existing examples: `dropboxEmail`, `lastBackupAt` (both absent from lines 61-71). The new field must be absent with a parallel comment.
- **Migration block** — `if (from < 9) { await m.addColumn(appSettings, appSettings.lastLogOrSymptomWriteAt); }` — pattern identical to v7 (lines 246-253) and v8 (254-261).

### Anti-patterns present to avoid

- **`_toCompanion` omission-by-accident** — general settings fields not listed in `_toCompanion` revert to DB column default on every `updateSettings` call. For dedicated-writer fields this is desired; the omission must be deliberate and commented.
- **Manual-copy in fakes without forwarding new fields** — `fake_app_settings_repository.dart` lines 44-54, 60-71, 78-88 all use positional constructor calls that silently drop unknown fields. Every new field must be propagated through all three blocks simultaneously.
- **`copyWith` for null-reset** — `copyWith` cannot set nullable fields to null (entity:84-85 comment). Do not route `lastLogOrSymptomWriteAt` through `copyWith`.

### Integration constraints

- **Cold-start trigger:** `lib/app.dart:72-74` → `_autoSyncIfConfigured()`. The skip-guard reads `AppSettingsData` (already available via `settingsNotifierProvider`) and compares two nullable DateTime fields. No new provider or stream is needed.
- **Restore-path contract:** `sync_orchestrator.dart:133` calls `deleteAllAndReplace`. If that call bumps `lastLogOrSymptomWriteAt`, the guard at cold-start will re-trigger. Either: (a) pass a `skipBump: true` flag through to the repository, or (b) call `recordDataWrite(null)` / `recordDataWrite(lastBackupAt)` after restore to reset the comparison. Decision must be in spec.
- **First-run semantics:** both timestamps null → no backup. `null lastLogOrSymptomWriteAt` means no data has ever been written, not "unknown."
- **Backup blob compatibility:** AppSettings is never serialized into the backup blob (`backup_service.dart:14-28`). No migration concern on restore to older builds.
- **`BackupRunner` interface:** `SyncOrchestrator.backup()` returns `void`. The skip-if-unchanged logic must live in the _caller_ (`_autoSyncIfConfigured`) so that `SyncOrchestrator` itself remains independently testable.

### Tech debt that blocks or complicates the feature

- `FakeAppSettingsRepository` has three manual-copy blocks (lines 44-54, 60-71, 78-88) that don't use `copyWith` because of the nullable-reset problem. Each new field multiplies the maintenance surface. Not a blocker, but the spec author should note it as a maintenance hazard.
- No check constraint at DB level on any AppSettings column; range enforcement is done only at `_fromRow` via `.clamp(...)`. The new timestamp column is nullable with no domain constraint — consistent with `lastBackupAt`, no new debt.

### Test coverage baseline

**`test/data/repositories/app_settings_repository_test.dart` (current):**

| Coverage | Status |
|---|---|
| Default column values from fresh row | Yes — `notificationTimeMinutes`, `firstDayOfWeek` |
| Round-trip persist + reload | Yes — all recent columns |
| Out-of-range DB value clamping | Yes |
| `_toCompanion` non-overwrite of dedicated-writer fields | Partial — tested for `notificationTimeMinutes` via EC-16 but not for `lastBackupAt` / `dropboxEmail` |
| `updateBackupState(null)` writes NULL | **No test** |
| `recordDataWrite` (new method) | Not yet |

**`test/data/repositories/daily_log_repository_test.dart` (current):**

| Coverage | Status |
|---|---|
| `saveDailyLog` + `watchDay` round-trip | Yes |
| `deleteDailyLog` | Yes |
| `replacePainSymptoms` | Yes |
| `deleteAllAndReplace` atomicity | Yes |
| `upsertAllLogs` | Partial (in import tests) |
| Any write bumps `lastLogOrSymptomWriteAt` | **Not yet** (feature not built) |

**Minimum new tests required by this feature:**
1. `recordDataWrite(ts)` persists `ts` and does not overwrite other settings fields.
2. `_toCompanion` exclusion: `updateSettings` with an unrelated field change does not overwrite `lastLogOrSymptomWriteAt`.
3. `lastLogOrSymptomWriteAt = null` on fresh row (DB default).
4. Cold-start skip guard: `lastDataWriteAt ≤ lastBackupAt` → `backupSilent()` not called.
5. Cold-start backup guard: `lastDataWriteAt > lastBackupAt` → `backupSilent()` called.
6. Restore path: after restore, `lastLogOrSymptomWriteAt` vs `lastBackupAt` yields correct skip decision.
