# Backup UI Pre-Implementation Assessment
## Feature: verify existing Dropbox backup on account connect

---

## Summary

The backup module has a clean, well-tested foundation. `BackupNotifier.connect()` already performs
the two steps that bracket the missing check: `authorize()` and `updateBackupState(...)`. The
insertion point for a "check for existing backup" call is unambiguous. One design decision (plain
vs. strict state model) must be resolved before implementing; all infrastructure is already in
place for the plain reading. A testability gap on `connect()` is the only structural finding — it
must be addressed alongside the feature, not after.

---

## Findings

### Important — Testability gap on `connect()`
**File:** `lib/providers/backup_providers.dart` line 31 / `test/features/backup/state/backup_notifier_test.dart`

`dropboxProviderProvider` is typed `Provider<DropboxProvider>` (concrete). There is no test for
`connect()` and no test for the new check-existing logic, because `DropboxProvider` cannot OAuth in
tests. `FakeDropboxProvider` (`test/helpers/`) already implements `CloudBackupProvider` and supports
`listFiles()` with a seeded `files` map, but it cannot be used to override a
`Provider<DropboxProvider>`.

**Fix:** Change the provider to `Provider<CloudBackupProvider>`, or add a seam:

```dart
// backup_providers.dart
final cloudBackupProvider = Provider<CloudBackupProvider>((ref) =>
    ref.watch(dropboxProviderProvider));
```

Then override `cloudBackupProvider` in notifier tests with `FakeDropboxProvider`. This is the
minimum change that unblocks `connect()` tests without refactoring `DropboxProvider`.

### Suggestion — No-backup-found string is unused
**File:** `lib/l10n/app_localizations_en.dart` line 543 / `app_localizations_it.dart` line 543

`backup_error_no_backup_found` exists in both locales but is never referenced in code. For the
plain reading (see Spec Inputs), the no-backup case maps to `lastBackupAt: null` which renders
`backup_last_backup_never` — not an error. The string should either be wired or removed to avoid
dead localisation.

---

## What Was Done Well

1. **Sealed `BackupState` with exhaustive switch in `BackupScreen`.** Adding a new state variant
   will produce a compile-time error at every switch site — impossible to forget a UI branch.
2. **Passphrase rollback guards** in `backupWithPassphrase` and `restoreWithPassphrase` are
   correct and well-tested (8 targeted tests covering ok, err, and rollback paths).
3. **`_StubBackupNotifier` pattern** in widget tests is minimal and captures only what the test
   needs — no over-mocking, no leaking real providers into widget tests.

---

## Spec Inputs

### Components and files affected

| File | Change type |
|---|---|
| `lib/features/backup/state/backup_notifier.dart` | Add `checkExistingBackup()` call inside `connect()` |
| `lib/features/backup/state/backup_state.dart` | No change (plain reading) |
| `lib/providers/backup_providers.dart` | Add `cloudBackupProvider` seam (testability) |
| `test/features/backup/state/backup_notifier_test.dart` | New tests for `connect()` paths |
| `lib/l10n/app_localizations_en.dart` | No new strings (plain); wire or remove unused `backup_error_no_backup_found` |
| `lib/l10n/app_localizations_it.dart` | Same as EN |

No changes needed to `backup_screen.dart` or `passphrase_dialog.dart`.

---

### Insertion point for the check

`BackupNotifier.connect()` lines 31–54. After obtaining `email` and before calling
`settingsRepo.updateBackupState(...)`, call `provider.listFiles()` and parse the first filename to
derive `discoveredLastBackupAt`:

```dart
// Inside connect(), after: final email = await dropbox.currentEmail();
DateTime? discoveredLastBackupAt;
try {
  final files = await dropbox.listFiles(); // already sorted desc
  if (files.isNotEmpty) {
    discoveredLastBackupAt = _parseBackupTimestamp(files.first);
  }
} catch (_) {
  // best-effort: listing failure does not abort the connect flow
}
await settingsRepo.updateBackupState(
  dropboxEmail: email,
  lastBackupAt: discoveredLastBackupAt,   // replaces current.lastBackupAt
);
ref.invalidateSelf();
```

`listFiles()` is already implemented on `CloudBackupProvider`, returns filenames sorted
descending (newest first), and handles an empty folder (returns `[]`). No new API surface needed.

---

### Filename-to-DateTime derivation

Filename format: `metra_backup_YYYYMMDDTHHMMSSZ.enc` (produced by `SyncOrchestrator._filenameFor`).
Parse with a regex to avoid a `package:intl` dependency:

```dart
DateTime? _parseBackupTimestamp(String filename) {
  final m = RegExp(
    r'metra_backup_(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z\.enc',
  ).firstMatch(filename);
  if (m == null) return null;
  return DateTime.utc(
    int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!),
    int.parse(m.group(4)!), int.parse(m.group(5)!), int.parse(m.group(6)!),
  );
}
```

---

### State model decision (spec must resolve)

**Plain reading** (recommended): reuse `BackupConnected.lastBackupAt`. The UI already shows
"Last backup: \<datetime\>" or "Never backed up" — both correct for a remote backup discovered at
connect time. No new state, no new strings.

**Strict reading**: add `remoteBackupFoundAt` to `BackupConnected` (or a new `BackupFoundRemote`
substate) to distinguish "backed up from this device" from "discovered someone else's backup".
Requires 1–2 new l10n strings. Adopt only if the product requires the user to know which device
produced the backup.

The feature description ("update the backup status shown to the user") does not require the strict
reading. Use plain unless overridden by product decision.

---

### Localisation strings needed

**Plain reading:** none. All required strings already exist:
- `backup_last_backup_at(String datetime)` — EN: "Last backup: \<datetime\>"
- `backup_last_backup_never` — EN: "Never backed up"

**Strict reading only** (if adopted): add two strings per locale:
- `backup_remote_backup_found(String datetime)` — e.g. EN: "Existing backup found: \<datetime\>"
- IT equivalent

**Dead string to resolve:** `backup_error_no_backup_found` — wire it to the error body for the
case where the user taps Restore but `listFiles()` returns empty (already thrown as
`SyncException('No backup found')` in `SyncOrchestrator.restore()`), or delete it.

---

### Patterns to follow

- `connect()` already wraps the entire flow in try/catch → `BackupErrorState(message)`. The
  `listFiles()` call must be try/caught separately (best-effort, as shown above) so that a Dropbox
  listing failure does not prevent the account from being registered.
- `ref.invalidateSelf()` is the correct way to refresh state after `connect()` completes —
  already used, do not replace with manual `state = AsyncData(...)`.
- Test the notifier unit tests against `ProviderContainer` with overrides (existing pattern in
  `backup_notifier_test.dart`), not against widget tests.

### Anti-patterns present to avoid

- Do not read `dropboxProviderProvider` (typed concrete) in new tests — it cannot be overridden
  with `FakeDropboxProvider`. Use the `cloudBackupProvider` seam once added.
- Do not set `state = AsyncData(BackupRunning(...))` for the listing sub-step — the overall
  `connecting` spinner already covers it and a second state transition would flicker the UI.
- Do not store `discoveredLastBackupAt` in a separate new field unless the strict reading is
  explicitly adopted — premature state proliferation.

---

### Test coverage baseline

**Existing notifier tests (15):** cover `build()`, `backupWithPassphrase`, `backupSilent`,
`restore`, `restoreWithPassphrase`, `disconnect`. `connect()` has zero unit tests.

**New tests required for this feature:**

| Scenario | Expected result |
|---|---|
| `connect()` — Dropbox has no files | `BackupConnected(lastBackupAt: null)` |
| `connect()` — Dropbox has one file | `BackupConnected(lastBackupAt: <parsed DateTime>)` |
| `connect()` — Dropbox has multiple files | `lastBackupAt` == timestamp of first (newest) |
| `connect()` — `listFiles()` throws | Connect succeeds with `lastBackupAt: null` (best-effort) |
| `connect()` — `currentEmail()` returns null | `BackupErrorState` (existing contract, now testable) |

All five can be written using `ProviderContainer` + `FakeDropboxProvider` + `FakeAppSettingsRepository`
following the pattern in `backup_notifier_test.dart`.
