# Module: Backup / Cloud Sync
**Path**: `lib/data/services/`, `lib/features/settings/`, `lib/features/backup/`, `lib/domain/use_cases/`, `lib/providers/`
**Agent**: bug-hunter

---

## Issue #11 — Auto backup must be suppressed after "Delete all data"

### Current behavior

When the user taps "Delete all data" → confirms the dialog, `settings_screen.dart:652–699` fires `deleteAllDataProvider.future` which calls `DeleteAllData.execute()` (`lib/domain/use_cases/delete_all_data.dart:27–30`). That calls `_logRepo.deleteAll()` → `DriftDailyLogRepository.deleteAll()` (`lib/data/repositories/drift_daily_log_repository.dart:195–198`):

```dart
@override
Future<void> deleteAll() async {
  await _dao.deleteAll();
  await _settingsRepo.updateLastDataWriteAt(_now());  // line 197 — bumps the skip-guard signal
}
```

`_settingsRepo.updateLastDataWriteAt(_now())` sets `lastLogOrSymptomWriteAt = now()`.

On the next cold-start, `app.dart:113–122` calls `backupSilent()`. The skip guard in `BackupNotifier.backupSilent()` (`lib/features/backup/state/backup_notifier.dart:129–151`) reads:

```dart
final lastBackupAt = settings.lastBackupAt;          // line 129 — e.g. 2026-05-10T08:00Z
final lastWriteAt  = settings.lastLogOrSymptomWriteAt; // line 130 — now() from delete, e.g. 2026-05-16T14:30Z

if (lastBackupAt != null) {
  if (lastWriteAt == null || !lastWriteAt.isAfter(lastBackupAt)) {  // line 136
    // skip
  }
}
```

After delete-all, `lastWriteAt` (the deletion timestamp) is always after `lastBackupAt`, so `!lastWriteAt.isAfter(lastBackupAt)` is `false` → guard does **not** skip → `_runBackup()` is called → an empty encrypted snapshot is uploaded to Dropbox, **overwriting the user's real backup with an empty blob**.

### Root cause / missing piece

`DriftDailyLogRepository.deleteAll()` (line 197) calls `updateLastDataWriteAt(_now())` — it treats deletion as a write event indistinguishable from logging new data. The skip guard at `backupSilent():136` cannot distinguish "fresh data was written" from "all data was deleted". After deletion, `lastLogOrSymptomWriteAt > lastBackupAt` is always true, so the guard proceeds and uploads an empty snapshot.

The `SyncOrchestrator.restore()` method already solves an analogous problem: after restore it re-aligns `lastLogOrSymptomWriteAt` to `lastBackupAt` (lines 139–142 of `sync_orchestrator.dart`) to prevent the skip guard from seeing "new data" from `deleteAllAndReplace`. The same alignment must happen after delete-all.

`DriftCycleEntryRepository.deleteAll()` (`lib/data/repositories/drift_cycle_entry_repository.dart:89`) does **not** bump `lastLogOrSymptomWriteAt`, so the partial fix of removing the bump from the daily-log path alone would be insufficient: future symptom deletions (if any) must be audited too.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/repositories/drift_daily_log_repository.dart` | 195–198 | Root cause: bumps `lastLogOrSymptomWriteAt` on `deleteAll()` |
| `lib/domain/use_cases/delete_all_data.dart` | 21–31 | Fix site: add post-delete alignment |
| `lib/providers/use_case_providers.dart` | 95–99 | Wires `DeleteAllData`; needs `settingsRepo` injection if fix is here |
| `lib/features/backup/state/backup_notifier.dart` | 116–158 | Skip guard — correct, but tricked by stale timestamp |
| `lib/app.dart` | 113–122 | Cold-start trigger for `backupSilent()` |
| `lib/domain/repositories/app_settings_repository.dart` | 35, 62 | `updateBackupState` / `updateLastDataWriteAt` contracts |
| `test/features/backup/state/backup_notifier_test.dart` | 656–1009 | Skip-guard tests — no coverage for delete-all-then-backupSilent |

### Fix sketch

**Option A (recommended) — align in `DeleteAllData`**, mirroring the restore pattern:

1. Add `AppSettingsRepository _settingsRepo` parameter to `DeleteAllData` (`delete_all_data.dart:21`).
2. After `await _cycleRepo.deleteAll()`, read `settings.lastBackupAt`. If non-null, call `_settingsRepo.updateLastDataWriteAt(settings.lastBackupAt!)`. If null (no prior backup), call `_settingsRepo.updateLastDataWriteAt(DateTime.utc(1970))` or leave `lastLogOrSymptomWriteAt` unchanged — either way the guard will see `lastBackupAt == null` and proceed only if this is the first backup, which is correct (there is nothing to protect).
3. Inject `settingsRepo` in `deleteAllDataProvider` (`use_case_providers.dart:95`).
4. Add a test to `backup_notifier_test.dart`: `deleteAll()` followed by `backupSilent()` → `backupSilent()` appends a `backupSkipped` log and does **not** upload.

This mirrors `sync_orchestrator.dart:139–142` exactly and does not change any domain invariants.

**Option B — remove the bump from `DriftDailyLogRepository.deleteAll()`** (line 197):

Do not call `updateLastDataWriteAt` on deletion. The bump exists because deletion is a valid data-state change; removing it silently ignores that signal. If `lastLogOrSymptomWriteAt` was set before the delete, it stays at its old value, and the guard behaves correctly. However, this leaves `lastLogOrSymptomWriteAt` pointing to a timestamp when data *did* exist, which is semantically stale. Option A is safer.

**Option B is not recommended on its own.** It would fix the cold-start path but leave an in-session manual backup call after delete-all still able to upload (because `backupSilent()` isn't called in-session — only cold-start — so this is actually safe, but it is a latent trap if the caller ever changes).

---

## Issue #12 — Keep more than one backup on cloud storage

### Current behavior

`SyncOrchestrator.backup()` (`lib/data/services/backup/sync_orchestrator.dart:78–86`) prunes every file except the just-uploaded one:

```dart
for (final f in files) {
  if (f != filename) {
    try {
      await _provider.deleteFile(f);
    } catch (_) {}
  }
}
```

`files` comes from `_provider.listFiles()` which returns all `metra_backup_*.enc` files sorted descending (newest first). After upload + verification, all older backups are deleted. The user is left with exactly one backup at all times. If that single backup becomes corrupt or the upload fails mid-session, there is no fallback.

### Root cause / missing piece

The prune loop has no retention policy. It treats "not the current filename" as "delete". The `BackupFilename.parseTimestamp()` utility (`lib/data/services/backup/backup_filename.dart:37–48`) already extracts a UTC `DateTime` from any filename and returns `null` for non-conforming names, making it safe to call on any entry.

The proposed retention policy is:

1. **Always keep**: the file just uploaded (current backup).
2. **Keep**: the most recent file among those present before the current upload (i.e., at most one previous backup — second-newest overall).
3. **Keep**: the most recent backup from the calendar month prior to `ts.month / ts.year` (so the user retains at least one cross-month recovery point).
4. **Delete**: everything else.

`_now()` is already injectable (constructor param `now`, used for `ts`), so the month boundary is deterministic in tests.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/backup/sync_orchestrator.dart` | 73–86 | Prune loop — fix location |
| `lib/data/services/backup/backup_filename.dart` | 37–48 | `parseTimestamp()` already available |
| `lib/data/services/backup/dropbox_provider.dart` | 209–247, 250–259 | `listFiles()` / `deleteFile()` contracts |
| `test/data/services/backup/sync_orchestrator_test.dart` | 107–128 | "deletes older files after uploading new one" — **will break** |

### Fix sketch

Replace the prune loop in `SyncOrchestrator.backup()` (lines 78–86) with a helper:

```dart
// After upload + verification, files is already fetched (line 74).
// files is sorted descending (newest first) per DropboxProvider contract.
final prevMonth = DateTime.utc(ts.year, ts.month - 1); // Dart handles month=0 → December prior year
final toKeep = _retentionSet(filename, files, prevMonth);
for (final f in files) {
  if (!toKeep.contains(f)) {
    try {
      await _provider.deleteFile(f);
    } catch (_) {}
  }
}
```

```dart
/// Returns the set of filenames to retain under the 3-slot retention policy:
/// 1. [current]   — the file just uploaded.
/// 2. [previous]  — the most recent file that existed before this upload.
/// 3. [monthly]   — the most recent file from [prevMonth] (year/month pair).
static Set<String> _retentionSet(
  String current,
  List<String> files,     // sorted descending, includes current
  DateTime prevMonth,
) {
  final keep = <String>{current};
  String? previous;
  String? monthly;
  for (final f in files) {
    if (f == current) continue;
    final ts = BackupFilename.parseTimestamp(f);
    if (ts == null) continue;
    // Slot 2: most recent prior backup.
    previous ??= f;
    // Slot 3: most recent backup in prevMonth (year+month match).
    if (monthly == null &&
        ts.year == prevMonth.year &&
        ts.month == prevMonth.month) {
      monthly = f;
    }
    if (previous != null && monthly != null) break;
  }
  if (previous != null) keep.add(previous);
  if (monthly != null) keep.add(monthly);
  return keep;
}
```

Notes:
- `DateTime.utc(ts.year, ts.month - 1)` when `ts.month == 1` produces `DateTime.utc(ts.year, 0)` which Dart normalises to `DateTime.utc(ts.year - 1, 12)` — correct December of prior year.
- Files that do not parse (null from `parseTimestamp`) are excluded from the keep set and thus pruned — safe, as they are not canonical backups.
- The helper is `static` and pure, so it can be unit-tested independently.
- `sync_orchestrator_test.dart:107–128` ("deletes older files after uploading new one") asserts exactly 1 file after backup. It must be rewritten to assert the new retention semantics: current + at most 1 previous + optional monthly.

---

## Risks

1. **Issue #11 — silent data loss in production.** If a user deletes all data and the app cold-starts before the fix is deployed, the Dropbox backup is overwritten with an empty snapshot. Recovery requires the user to still have the previous backup locally (they don't — it was replaced). This is the highest-severity risk in the module.

2. **Issue #11 — `lastBackupAt == null` edge case.** If the user has never backed up but has a passphrase configured (e.g., configured passphrase, never ran first backup), delete-all sets `lastLogOrSymptomWriteAt = now()`. On next cold-start, `backupSilent()` enters the `lastBackupAt == null` branch (case c — first-ever backup) and uploads an empty snapshot. Fix option A must also handle this edge: if `lastBackupAt` is null, set `lastLogOrSymptomWriteAt` to a sentinel (epoch or null) so the guard skips on empty DB.

3. **Issue #12 — `listFiles()` ordering contract.** The prune logic assumes `listFiles()` returns filenames sorted descending. `DropboxProvider.listFiles()` (lines 209–247) sorts descending via `sort((a, b) => b.compareTo(a))`. The fake `FakeDropboxProvider` used in tests must replicate this sort; verify it does before shipping.

4. **Issue #12 — prevMonth boundary at year rollover.** `DateTime.utc(ts.year, ts.month - 1)` when `ts.month == 1` evaluates to `DateTime.utc(year, 0)`. Dart normalises month 0 to December of the prior year. Verify with a unit test at the January boundary (ts = 2026-01-15 → prevMonth = 2025-12).

5. **Partial prune failure leaves extra files.** Both current and new prune loops use `catch (_) {}` (best-effort delete). If deletion fails, the next backup cycle will attempt deletion again (idempotent). The retention set being a superset of the previous state means no data is lost; at worst, more than 3 files accumulate temporarily.

---

## Tech debt

1. **`deleteAll()` semantics are overloaded.** `DriftDailyLogRepository.deleteAll()` bumps `lastLogOrSymptomWriteAt` for good reasons on the restore path (`deleteAllAndReplace` calls it indirectly), but for the delete-all-data path it is harmful. The interface does not distinguish "delete as part of a restore" from "delete as a user action". Splitting into `deleteAllForRestore()` (no bump) and `deleteAll()` (no bump) with alignment at the call site would make intent explicit.

2. **`DeleteAllData` does not inject `AppSettingsRepository`.** The use case is minimal by design, but the fix for Issue #11 requires it. The provider wiring at `use_case_providers.dart:95–99` is a 3-line change; document the reason for the addition (alignment post-delete).

3. **`_retentionSet` is a private static.** Once Issue #12 is fixed, the retention logic should have its own unit test file (e.g., `test/data/services/backup/backup_retention_test.dart`) rather than being tested only through the orchestrator integration test.

4. **No integration test for delete-all → cold-start backup path.** The existing `backup_notifier_test.dart` integration group covers backup → restore → re-backup but not delete-all → backupSilent. This gap is what allowed Issue #11 to ship undetected.

5. **`FakeDropboxProvider` sort order.** If `FakeDropboxProvider.listFiles()` returns files in insertion order rather than descending-sorted order, Issue #12's retention logic will compute the wrong `previous` and `monthly` slots. Audit and fix the fake before writing Issue #12 tests.
