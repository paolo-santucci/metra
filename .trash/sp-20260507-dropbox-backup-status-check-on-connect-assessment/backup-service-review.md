# Pre-Implementation Assessment
## Feature: Verify existing Dropbox backup on connect

**Date:** 2026-05-07  
**Reviewer:** code-reviewer agent

---

## Summary

The backup module is well-structured and the critical path (auth → connect → `BackupNotifier.connect()`) is already clear. The architecture supports the new feature without invasive changes, but there are three concrete gaps that the spec must address before implementation starts: an undefined arch decision (where does the new behaviour live?), a filename parsing gap (no inverse of `_filenameFor` is exposed), and a coupling hazard in `updateBackupState` when the feature overwrites `lastBackupAt`.

---

## Findings

### Critical

**None.** No correctness bugs, security issues, or broken tests were found in the module as it stands.

---

### Important

**1. `updateBackupState` couples email + lastBackupAt — ordering hazard**  
`lib/domain/repositories/app_settings_repository.dart:35–38`  
`BackupNotifier.connect()` at line 40–43 already works around this by round-tripping the existing `lastBackupAt` to avoid clobbering it:
```dart
await settingsRepo.updateBackupState(
  dropboxEmail: email,
  lastBackupAt: current.lastBackupAt,  // preserve existing value
);
```
The new feature must do the same — it must call `getOrCreate()` first, preserve `dropboxEmail`, and only then update `lastBackupAt`. If the implementation writes directly without reading first (a natural mistake given the method name), it will clear the connected email.  
**Fix:** Either document this hazard in the repository interface docstring, or split into `updateDropboxEmail(String?)` and `updateLastBackupAt(DateTime?)` — two setters remove the ordering trap.

**2. No filename→DateTime parser exists: tech debt the feature will need to invent**  
`lib/data/services/backup/sync_orchestrator.dart:156–165` (`_filenameFor` method)  
`listFiles()` returns sorted filename strings. The new feature needs to extract the backup timestamp from the most-recent filename (e.g., to show "last remote backup: 2026-04-29 10:00 UTC"). There is no `parseFilenameTimestamp(String)` helper anywhere. The filename format constant is also duplicated: `_filePrefix`/`_fileSuffix` live in `dropbox_provider.dart`, but the full format template lives in `sync_orchestrator.dart`.  
**Fix:** Extract a `BackupFilename` value object (or static helpers) into a shared location — e.g., `lib/data/services/backup/backup_filename.dart` — exposing both `filenameFor(DateTime)` and `parseTimestamp(String): DateTime?`. Both `SyncOrchestrator` and the new use case consume it.

**3. `BackupOperation` enum missing a `checkingRemote` variant — UI state gap**  
`lib/features/backup/state/backup_state.dart:20`  
The `BackupRunning` state is what the UI shows during an in-progress async operation. The new feature will call `listFiles()` after auth, which may take 1–3 seconds. Without a dedicated `BackupOperation.checkingRemote` variant, the notifier must either emit `connecting` (misleading — auth is done) or invent an ad-hoc message. Neither is clean.  
**Fix:** Add `checkingRemote` to the enum before implementing the use case. The UI can then show a distinct loading indicator or message.

---

### Suggestions

**4. `FakeDropboxProvider` has no failure injection for `listFiles`**  
`test/helpers/fake_dropbox_provider.dart:36–38`  
`failNextUpload` and `failNextDownload` exist; `failNextList` does not. The new feature's failure path (Dropbox is reachable but listing fails) cannot currently be tested without modifying the fake.  
**Fix:** Add `bool failNextList = false;` to the fake, guarded analogously to the existing flags. One-line change; do it before writing tests for the new feature.

**5. `backup_providers.dart:38` — `backupServiceProvider` is a `FutureProvider`, but `BackupService` has no async init**  
`lib/providers/backup_providers.dart:38–41`  
`BackupService` constructor is `const` and synchronous; wrapping it in a `FutureProvider` adds an unnecessary `.future` unwrap every place it is consumed. This propagates the `FutureProvider` chain upward — `syncOrchestratorProvider`, `backupDataProvider`, and `restoreDataProvider` all chain on `.future` unnecessarily.  
**Fix (low-urgency):** Convert `backupServiceProvider` to `Provider<BackupService>`, reducing one async hop in the provider tree. Resolve before adding a new provider in this file, otherwise the new provider inherits the same unnecessary pattern.

**6. Short license header in `backup_service.dart` vs full GPL header in sibling files**  
`lib/data/services/backup/backup_service.dart:1–4`  
The file uses the abbreviated SPDX-only form while `dropbox_provider.dart` and `sync_orchestrator.dart` carry the full GPL-3.0 boilerplate. Inconsistent — the project convention uses the full form for service files.

---

## What was done well

1. **PKCE + CSRF state token in `authorize()`** (lines 84–101) is correctly implemented. The code verifier is generated with `Random.secure()`, the code challenge uses SHA-256 base64url with proper padding removal, and the returned OAuth state is verified before using the code. No security shortcuts.
2. **`SyncOrchestrator` failure paths are fully logged.** Both `backup()` and `restore()` catch all exceptions, append a `SyncLogEntity(success: false)` with the error message, and rethrow — so the notifier sees the error and the log is never empty on failure.
3. **`BackupNotifier.restoreWithPassphrase` / `backupWithPassphrase` rollback logic** correctly detects failure via state inspection and restores the previous passphrase to secure storage. This is a non-obvious but critical invariant (cloud blob remains encrypted with the old key) that is correctly handled.

---

## Verdict

**APPROVE WITH NOTES** (pre-implementation assessment, no new code yet)  
The existing code is sound and can support the feature. Implementation should address findings 1–3 before merging the new feature.

---

## Spec Inputs

### Components and files affected

| File | Change type |
|---|---|
| `lib/features/backup/state/backup_notifier.dart` | Add `checkRemoteBackupStatus()` method (or inline in `connect()`) |
| `lib/features/backup/state/backup_state.dart` | Add `BackupOperation.checkingRemote` enum value |
| `lib/data/services/backup/backup_filename.dart` | **New file** — shared `filenameFor` + `parseTimestamp` helpers |
| `lib/data/services/backup/sync_orchestrator.dart` | Consume `BackupFilename`; optionally expose `checkRemoteStatus()` |
| `lib/domain/use_cases/backup_data.dart` or new `lib/domain/use_cases/check_remote_backup.dart` | **Arch decision required** (see below) |
| `lib/domain/repositories/app_settings_repository.dart` | Document or fix `updateBackupState` ordering hazard |
| `test/helpers/fake_dropbox_provider.dart` | Add `failNextList` flag |

### Patterns to follow

- **Use `Result<T, E>` at use-case boundary.** Both `BackupData` and `RestoreData` return `Future<Result<void>>`. The new use case must follow the same contract — not `Future<bool>` or `Future<DateTime?>`.
- **`BackupRunner` pattern for domain/data separation.** If the feature adds an orchestration method, it should be declared on `BackupRunner` (domain interface) and implemented in `SyncOrchestrator` (data layer). The domain use case must never import `SyncOrchestrator` directly.
- **`AsyncNotifier` + explicit `BackupRunning` transition.** `BackupNotifier.connect()` sets `BackupRunning(BackupOperation.connecting)` before async work. The new code must set `BackupRunning(BackupOperation.checkingRemote)` after auth succeeds and before the `listFiles()` call.
- **`ref.invalidateSelf()` to publish state.** After writing settings, `connect()` calls `ref.invalidateSelf()` so `build()` re-reads from the repository and emits the final `BackupConnected` state. Follow this — do not manually construct and assign the final state.

### Anti-patterns present — do not propagate

- **Do not call `updateBackupState` without first reading current settings.** The method writes both `dropboxEmail` and `lastBackupAt` atomically; calling it with only the new `lastBackupAt` and a null email will disconnect the account. Always round-trip `current.dropboxEmail` (see `connect()` lines 38–43 for the correct pattern).
- **Do not duplicate the filename format string.** A fourth file knowing the `metra_backup_YYYYMMDDTHHMMSSZ.enc` format would add a third copy of the constant. Extract `BackupFilename` first.
- **Do not add another `FutureProvider` wrapping a sync constructor.** See finding 5.

### Integration constraints

- **Auth completion signal:** `BackupNotifier.connect()` (`lib/features/backup/state/backup_notifier.dart:31–54`) is the only call site of `dropbox.authorize()`. The new check must be triggered from within `connect()`, after `currentEmail()` returns successfully and before `ref.invalidateSelf()`. No new entry point is needed.
- **Remote listing API:** `CloudBackupProvider.listFiles()` returns `List<String>` sorted newest-first (Dropbox `name` field only — no server timestamp). The filename itself encodes the timestamp. The new check must parse it via the to-be-extracted `BackupFilename.parseTimestamp(String)`.
- **Settings persistence:** `AppSettingsRepository.updateBackupState(dropboxEmail, lastBackupAt)` is the only setter for these fields. Both parameters are `required` — there is no partial update. Read first, preserve `dropboxEmail`, pass the remote timestamp as `lastBackupAt`.
- **State publication:** `BackupConnected.lastBackupAt` (`backup_state.dart:16`) is the field the UI reads. The feature must ensure this field is populated from the remote file timestamp before `ref.invalidateSelf()` is called so the UI shows the correct value on first connect.

### Arch decision required before implementation

**Where does the new orchestration step live?**

Option A — inline in `BackupNotifier.connect()`: after `currentEmail()`, call `provider.listFiles()` directly in the notifier, parse the timestamp, and pass it to `updateBackupState`. Simple, no new files. Violates the current pattern of keeping network calls out of the notifier and behind the `BackupRunner` interface.

Option B — new use case `CheckRemoteBackup`: add `checkRemoteStatus(): Future<DateTime?>` to `BackupRunner`; implement in `SyncOrchestrator`; wrap in a use case `CheckRemoteBackupStatus`. More files, but preserves SRP and ISP (the notifier stays a coordinator, not an HTTP caller). Easier to unit-test without standing up the notifier.

**Recommendation:** Option B. The existing `BackupData`/`RestoreData` pattern is clean; adding a third method to `BackupRunner` is one interface change and keeps the notifier free of direct HTTP dependency. ISP risk is low — all three operations are logically cohesive on the backup runner.

### Tech debt that blocks or complicates the feature

1. **No `BackupFilename` abstraction** — required to parse timestamps from `listFiles()` output. Must be resolved before writing the new use case, otherwise the timestamp parse logic is duplicated or inlined in the notifier.
2. **`updateBackupState` ordering trap** — must be documented (or split) before the feature PR to prevent a latent bug from being introduced.

### Test coverage baseline

| Test file | Coverage |
|---|---|
| `test/data/services/backup/dropbox_provider_test.dart` | upload, listFiles (happy + 409), 401 refresh, isConnected, disconnect, not-connected guard. Missing: `listFiles` failure injection. |
| `test/data/services/backup/backup_service_test.dart` | empty repo, logs + symptoms. Complete for current scope. |
| `test/data/services/backup/sync_orchestrator_test.dart` | backup happy path, prune, upload failure, no-passphrase; restore happy, wrong-passphrase, empty Dropbox. Good coverage. Missing: test for the new `checkRemoteStatus` path. |
| `test/domain/use_cases/backup_data_test.dart` | Exists (not read). |
| `test/helpers/fake_dropbox_provider.dart` | Covers upload/download/list/delete. Missing: `failNextList`. |

**New tests required by this feature:**
- `checkRemoteStatus()` in orchestrator: happy (one file found → returns parsed DateTime), empty (no files → returns null), listFiles failure → SyncException propagated.
- `BackupNotifier.connect()`: after auth, if remote backup exists, `BackupConnected.lastBackupAt` is non-null; if remote is empty, it is null.
- `BackupFilename.parseTimestamp`: valid name → correct UTC DateTime; malformed name → null (no throw).
