# Consolidated Assessment — Dropbox Backup Status Check on Connect

**Date**: 2026-05-07
**Feature**: After Dropbox account registration, verify existing backup and update backup status shown to the user.

---

## Findings (merged, deduplicated)

### [Important] Testability gap — `dropboxProviderProvider` is typed as concrete
**Files:** `lib/providers/backup_providers.dart`, `test/features/backup/state/backup_notifier_test.dart`

`dropboxProviderProvider` is `Provider<DropboxProvider>`. `FakeDropboxProvider` implements `CloudBackupProvider` and cannot override a `Provider<DropboxProvider>`. `connect()` has zero unit tests today; the new check-existing logic would inherit that gap.

**Fix (required):** Add a thin seam:
```dart
final cloudBackupProvider = Provider<CloudBackupProvider>(
    (ref) => ref.watch(dropboxProviderProvider));
```
Override `cloudBackupProvider` in notifier tests with `FakeDropboxProvider`. Zero impact on production — just a one-line indirection.

### [Important] No filename→DateTime parser — duplication trap
**File:** `lib/data/services/backup/sync_orchestrator.dart:156–165` (`_filenameFor`)

`listFiles()` returns sorted filename strings. The timestamp is encoded in the name (`metra_backup_YYYYMMDDTHHMMSSZ.enc`). No `parseTimestamp` helper exists. The filename constants (`_filePrefix`, `_fileSuffix`) are split across `dropbox_provider.dart` and `sync_orchestrator.dart`.

**Fix (required):** Extract `lib/data/services/backup/backup_filename.dart` with:
- `static String filenameFor(DateTime)` — replaces `_filenameFor` in orchestrator
- `static DateTime? parseTimestamp(String)` — new; regex-based, returns null on malformed input

### [Important] `updateBackupState` ordering trap
**File:** `lib/domain/repositories/app_settings_repository.dart`

`updateBackupState(dropboxEmail, lastBackupAt)` requires both fields. If the feature updates `lastBackupAt` without round-tripping `dropboxEmail`, the account is silently disconnected.

**Fix (required):** The existing `connect()` at lines 40–43 already applies the correct pattern (read `current`, preserve `dropboxEmail`). The new code must follow the same round-trip. Document the invariant in the interface docstring.

### [Suggestion] `FakeDropboxProvider` missing `failNextList`
**File:** `test/helpers/fake_dropbox_provider.dart`

`failNextUpload` and `failNextDownload` exist; `failNextList` does not. The new feature's error path (listing fails) cannot be tested without modifying the fake.

**Fix:** Add `bool failNextList = false;` guarded the same way as existing flags.

### [Suggestion] Dead localisation string
**File:** `lib/l10n/app_localizations_en.dart:543`, `app_localizations_it.dart:543`

`backup_error_no_backup_found` exists but is never used. It should be wired to the `SyncOrchestrator.restore()` error path (which already throws `SyncException('No backup found')`) or removed. Not blocking; deferred to a separate cleanup.

---

## Arch Decision (resolved for this spec)

Both assessors agreed on the insertion point (`BackupNotifier.connect()`) but diverged on layering.

**Selected: Plain reading (inline in `connect()`).**

Rationale:
- `listFiles()` is a best-effort check; failure must not abort the connect flow.
- Adding a full `CheckRemoteBackup` use case + `BackupRunner` method is over-engineering for a single best-effort API call with no side-effects beyond reading `lastBackupAt`.
- `connect()` already has a try/catch wrapper for auth failures; the listing must be try/caught separately (best-effort, does not abort).
- The UI review explicitly cautions against adding `BackupOperation.checkingRemote` — the existing `connecting` spinner covers the auth+listing period; a mid-step transition would flicker.
- No new state variant (`BackupOperation.checkingRemote`) needed.
- No new l10n strings needed (plain reading reuses `backup_last_backup_at` / `backup_last_backup_never`).

---

## Spec Inputs

### Insertion point
`BackupNotifier.connect()` (`lib/features/backup/state/backup_notifier.dart:31–54`).
After `await dropbox.currentEmail()` returns and before `settingsRepo.updateBackupState(...)`:

```dart
DateTime? discoveredLastBackupAt;
try {
  final files = await dropbox.listFiles(); // sorted desc, newest first
  if (files.isNotEmpty) {
    discoveredLastBackupAt = BackupFilename.parseTimestamp(files.first);
  }
} catch (_) {
  // best-effort: listing failure does not abort the connect flow
}
await settingsRepo.updateBackupState(
  dropboxEmail: email,
  lastBackupAt: discoveredLastBackupAt,
);
```

### Files affected

| File | Change |
|---|---|
| `lib/data/services/backup/backup_filename.dart` | **New** — `filenameFor` + `parseTimestamp` static helpers |
| `lib/data/services/backup/sync_orchestrator.dart` | Consume `BackupFilename.filenameFor` (replaces `_filenameFor`) |
| `lib/features/backup/state/backup_notifier.dart` | Add listing check inside `connect()` |
| `lib/providers/backup_providers.dart` | Add `cloudBackupProvider` seam |
| `test/helpers/fake_dropbox_provider.dart` | Add `failNextList` flag |
| `test/features/backup/state/backup_notifier_test.dart` | 5 new tests for `connect()` paths |
| `test/data/services/backup/backup_filename_test.dart` | **New** — unit tests for `parseTimestamp` |
| `lib/domain/repositories/app_settings_repository.dart` | Docstring: document `updateBackupState` ordering invariant |

No changes to `backup_screen.dart`, `backup_state.dart`, l10n files, or domain use cases.

### Patterns to follow
- `ref.invalidateSelf()` after writing settings (existing pattern, do not replace with manual state assignment).
- Best-effort catch on the listing call — listing failure must not prevent account registration.
- Round-trip `dropboxEmail` via `getOrCreate()` before calling `updateBackupState`.
- Override `cloudBackupProvider` (not `dropboxProviderProvider`) in notifier tests.

### Anti-patterns to avoid
- Do not call `updateBackupState` with only `lastBackupAt` — always round-trip `dropboxEmail`.
- Do not add `BackupOperation.checkingRemote` — causes UI flicker with no user benefit.
- Do not duplicate the filename format string — use `BackupFilename` in both orchestrator and notifier.
- Do not add a `FutureProvider` wrapping a sync constructor.

### Test coverage required (new)

| File | Test |
|---|---|
| `backup_filename_test.dart` | `parseTimestamp`: valid name → correct UTC DateTime |
| `backup_filename_test.dart` | `parseTimestamp`: malformed name → null (no throw) |
| `backup_notifier_test.dart` | `connect()` — empty Dropbox → `BackupConnected(lastBackupAt: null)` |
| `backup_notifier_test.dart` | `connect()` — one file → `BackupConnected(lastBackupAt: <parsed>)` |
| `backup_notifier_test.dart` | `connect()` — multiple files → `lastBackupAt` = newest |
| `backup_notifier_test.dart` | `connect()` — `listFiles()` throws → connect succeeds, `lastBackupAt: null` |
| `backup_notifier_test.dart` | `connect()` — `currentEmail()` null → `BackupErrorState` (testable now) |
