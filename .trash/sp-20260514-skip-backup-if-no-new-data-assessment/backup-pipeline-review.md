# Backup Pipeline — Pre-implementation Assessment
**Feature:** Skip automatic cold-start backup when no data has changed since last backup
**Date:** 2026-05-14  **Reviewer:** code-reviewer  **Schema version at review:** v8

---

## Summary

The backup pipeline is clean, well-tested, and uses a consistent dedicated-writer pattern for
out-of-band fields (`lastBackupAt`, `dropboxEmail`). The skip-check can be inserted cleanly at
`BackupNotifier.backupSilent()` without touching the manual-backup path or the orchestrator.
The blocking constraint is that **no "last DB write" timestamp exists anywhere in the codebase**.
The feature requires introducing one, which means a schema-v9 migration and a new dedicated
writer. Three edge cases that the spec must address before build are: first-ever backup,
post-restore state, and the risk of AppSettings writes advancing the timestamp erroneously.

---

## Findings

### Critical

**C-1 — No `lastDataChangedAt` field exists; scope must be defined precisely**
`lib/data/database/app_database.dart` (all tables), `lib/domain/entities/app_settings_data.dart`

Neither `DailyLogs`, `PainSymptoms`, nor `AppSettings` carry an audit timestamp for "when was
user data last written." Without this, the skip-check has no comparand.

Options (ordered by fit with existing patterns):
- **(Recommended) A** — new `lastDataChangedAt DateTimeColumn` on `AppSettings` (singleton
  row), nullable (`null` = never written = always upload). Follows the `lastBackupAt` precedent.
  Schema v9: `m.addColumn(appSettings, appSettings.lastDataChangedAt)`.
- **B** — `updatedAt` column on `DailyLogs` + `PainSymptoms`, `SELECT MAX(...)`. Two-table
  schema change, N-row churn on every daily entry, more migration surface.
- **C** — In-memory only. Rejected — cold-start kills it, which is exactly the target scenario.

Lean: **Option A**. Single additive migration, zero per-row overhead, mirror of `lastBackupAt`.

Fix: new nullable `DateTimeColumn get lastDataChangedAt` on `AppSettings`; schema v9 migration;
default `null` (semantically "no writes yet → always upload").

---

**C-2 — `_toCompanion` exclusion trap applies to `lastDataChangedAt`**
`lib/data/repositories/drift_app_settings_repository.dart:61-71`

`_toCompanion` deliberately excludes fields with dedicated writers (`lastBackupAt`,
`declaredCycleLength`, `onboardingCompleted`). If `lastDataChangedAt` is NOT excluded from
`_toCompanion`, every call to `updateSettings()` via the settings screen will silently revert it
to the column default (null), making the skip-check permanently useless.

Fix: exclude `lastDataChangedAt` from `_toCompanion`; give it a dedicated method on
`AppSettingsRepository`:
```dart
Future<void> updateLastDataChangedAt(DateTime ts);
```
Implemented in `DriftAppSettingsRepository` as a narrow `AppSettingsCompanion` write (mirrors
`updateBackupState`).

---

**C-3 — All 6 `DailyLogRepository` write paths must advance `lastDataChangedAt`**
`lib/data/repositories/drift_daily_log_repository.dart:150-213`

Write methods: `saveDailyLog`, `deleteDailyLog`, `replacePainSymptoms`, `deleteAllAndReplace`,
`upsertAllLogs`, `deleteAll`. All six must call `updateLastDataChangedAt(now)` or the timestamp
drifts. Centralize the call inside `DriftDailyLogRepository`—not in callers—to avoid leakage.

---

### Important

**I-1 — Post-restore edge case: restore must not trigger the next cold-start backup**
`lib/data/services/backup/sync_orchestrator.dart:114-155`

`restore()` calls `_logRepo.deleteAllAndReplace()`, which will advance `lastDataChangedAt`
(after C-3 is addressed). The next cold-start will then see `lastDataChangedAt > lastBackupAt`
(restore writes new data, but `lastBackupAt` is not updated by restore) and trigger a full
re-upload. This round-trips the just-restored data back to Dropbox unnecessarily.

Fix: after a successful restore, set `lastDataChangedAt` to the same timestamp as
`lastBackupAt` (or to the snapshot's `exportedAt`). This marks the DB as "in sync" until the
user writes new entries. The orchestrator already reads `_settingsRepo` — it can call
`updateLastDataChangedAt(existingBackupTs)` as the last step of `restore()`.

---

**I-2 — `lastBackupAt == null` branch must always upload (no `lastDataChangedAt` check)**
`lib/features/backup/state/backup_notifier.dart:115-126`

The proposed check is `lastDataChangedAt <= lastBackupAt → skip`. When `lastBackupAt == null`
(first backup ever), any comparison result would be undefined/wrong. The spec must explicitly
guard: "if `lastBackupAt == null` → always upload."

Fix: in the skip-check:
```dart
final settings = await settingsRepo.getOrCreate();
if (settings.lastBackupAt != null &&
    settings.lastDataChangedAt != null &&
    !settings.lastDataChangedAt!.isAfter(settings.lastBackupAt!)) {
  return; // no new data
}
```

---

**I-3 — Skip applies to `backupSilent()` only; manual backup must always force**
`lib/features/backup/state/backup_notifier.dart:90-113, 115-126`

`backupWithPassphrase()` (user-initiated manual backup) must bypass the skip-check. The
recommended insertion point (`backupSilent()`) naturally satisfies this because
`backupWithPassphrase()` calls `_runBackup()` directly.

Fix: confirm the check lives exclusively in `backupSilent()`, documented with a comment citing
this intent.

---

### Suggestion

**S-1 — `backupSilent()` skip should emit a `debugPrint` diagnostic line**

`_autoSyncIfConfigured` in `lib/app.dart:113-122` has `debugPrint` on the catch path. A skip-due-to-no-change should also emit a `debugPrint('[autoSync] skipped: no data change since last backup')` for field diagnostics (consistent with CLAUDE.md §2.3 — local-only logs, no telemetry).

---

## What Was Done Well

1. **Dedicated-writer pattern** (`updateBackupState`, `saveDeclaredCycleLength`,
   `markOnboardingComplete`) is consistently applied and the `_toCompanion` exclusion
   is well-documented. The pattern has a clear seam for adding `updateLastDataChangedAt`.

2. **`backupSilent()` already has layered guards** (BackupNotConnected at :121, passphrase-null
   at :123, BackupRunning at :116) with unit tests at backup_notifier_test.dart Fix #1 and
   FR-14 groups. The new skip-check is one more guard in the same idiom.

3. **Schema migration history is clean** — v5 (declaredCycleLength), v7
   (notificationTimeMinutes), v8 (firstDayOfWeek) all use the same additive `m.addColumn`
   pattern with `withDefault`. The v9 migration for `lastDataChangedAt` has exact precedent.

---

## Spec Inputs

### Components and files affected

| File | Change |
|---|---|
| `lib/data/database/app_database.dart` | New `lastDataChangedAt` column on `AppSettings`; schemaVersion → 9; `onUpgrade if (from < 9)` block |
| `lib/domain/entities/app_settings_data.dart` | New `lastDataChangedAt DateTime?` field; update `==` / `hashCode`; **do NOT add to `copyWith`** (out-of-band lifecycle) |
| `lib/domain/repositories/app_settings_repository.dart` | New abstract method `updateLastDataChangedAt(DateTime ts)` |
| `lib/data/repositories/drift_app_settings_repository.dart` | Implement `updateLastDataChangedAt`; exclude field from `_toCompanion` |
| `lib/data/repositories/drift_daily_log_repository.dart` | All 6 write methods call `updateLastDataChangedAt(now)` after their DB write |
| `lib/features/backup/state/backup_notifier.dart` | Skip-check in `backupSilent()` between existing guards; `debugPrint` on skip |
| `lib/data/services/backup/sync_orchestrator.dart` | `restore()` calls `updateLastDataChangedAt(existingBackupTs)` on success |
| `test/data/services/backup/sync_orchestrator_test.dart` | New test: restore sets `lastDataChangedAt` to match `lastBackupAt` |
| `test/features/backup/state/backup_notifier_test.dart` | New tests: skip when no change; first-ever backup forces upload; post-restore state |
| `test/data/repositories/drift_app_settings_repository_test.dart` | `updateLastDataChangedAt` round-trip; excluded from `_toCompanion` |

### Patterns to follow (and anti-patterns to avoid)

- **Follow**: `updateBackupState` / `saveDeclaredCycleLength` pattern for the new dedicated
  writer — narrow `AppSettingsCompanion` with `Value(ts)` only.
- **Follow**: v7/v8 migration block structure for v9: `if (from < 9) { await m.addColumn(...); }`.
- **Follow**: `getOrCreateSettings()` invariant — new column must declare
  `withDefault(const Constant(null))` (nullable DateTimeColumn defaults to null automatically).
- **Avoid**: adding `lastDataChangedAt` to `_toCompanion` (would be overwritten by every
  settings save — the _toCompanion exclusion trap, lessons.jsonl cr-m3-01).
- **Avoid**: adding `lastDataChangedAt` to `AppSettingsData.copyWith` — same trap.
- **Avoid**: placing the skip-check in `SyncOrchestrator.backup()` — affects the manual path
  and violates the orchestrator's single-responsibility (it runs a backup; it does not decide
  *whether* to run one).

### Integration constraints

- `lastBackupAt` is written by `settingsRepo.updateBackupState()` in `SyncOrchestrator.backup()`
  at line :88-91. The new skip-check reads it from `settingsRepo.getOrCreate()` — same read
  path used by `BackupNotifier.build()`.
- `BackupNotifier.backupSilent()` already reads `secureStorageProvider` synchronously before
  calling `_runBackup()`. The new `settingsRepo.getOrCreate()` call must be awaited before the
  passphrase read (or after it — order does not matter, both are in the same async function).
- `DailyLogRepository.deleteAllAndReplace()` is called by `SyncOrchestrator.restore()` and
  also by the CSV import flow. The `lastDataChangedAt` write in the repository layer covers
  both callers automatically — no orchestrator-level plumbing needed for CSV import.

### Tech debt that blocks or complicates the feature

- **Schema is at v8 now**: v9 migration is straightforward (additive) but must be done first.
  No other pending schema work is queued.
- **No `updateLastDataChangedAt` API exists** on the repository interface or implementation —
  must be added before any feature code can compile.
- **`DailyLogRepository` has 6 write paths** (see C-3) — all must be instrumented. This is
  mechanical but noisy; a missed path silently breaks the skip-check for that specific operation
  (e.g., CSV import or restore) without any test failure unless explicit coverage exists.

### Test coverage baseline

Existing relevant tests (all in `test/data/services/backup/sync_orchestrator_test.dart` and
`test/features/backup/state/backup_notifier_test.dart`):
- Orchestrator: upload happy path, upload failure, restore wrong-passphrase, no-passphrase.
- Notifier: `BackupNotConnected` early-return (Fix #1), `BackupRunning` guard (FR-14),
  `backupWithPassphrase` passphrase rollback on failure, `restoreWithPassphrase` rollback.

**Gaps this feature must close** (none are covered today):
1. `backupSilent()` skips when `lastDataChangedAt <= lastBackupAt` (runner not called).
2. `backupSilent()` uploads when `lastBackupAt == null` even if `lastDataChangedAt == null`.
3. `backupSilent()` uploads when `lastDataChangedAt > lastBackupAt`.
4. `restore()` sets `lastDataChangedAt` to match `lastBackupAt` so next cold-start skips.
5. `saveDailyLog` (and each of the other 5 write paths) advances `lastDataChangedAt`.
6. AppSettings-only write (via `updateSettings`) does NOT advance `lastDataChangedAt`.
