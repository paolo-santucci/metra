---
domain: backup
last-updated: 2026-06-01
last-verified: 2026-05-15
applied-deltas:
  - 9e9aab6d5ddc6aec78b3fbd068495d4a56ab0b7788dedcdd783d887eb59e5148
  - 8d73e3099f5e44f18122a0f11d6f8113a942448b13d2abc2e68e9fdf8fc90d60
  - 25af2a7e9dd0f83cbe9a02b34c85fe0bfc03a107609b2ec6b9ae5d4de7e8ae5f
  - 7b0df03f8a4c5e4a9ebc95b5faaf81ec613b68c3d7016699cd94fd49567d52f1
  - e2eb94828bd27399a8c31fb4941842d4337c26c46ac78fa72cc374332ea29c94
  - 52f47e34ba83c7b8caa048888d6476cdee7b8980cf601c36aaf067f742841514
  - dc64a9d08b9ace5082f0066cada7a890a05af4900b427bb8e7dd4d88c95d41c3
  - 5e63ba40e55cb07c5398a1d6945ac138d100583c0cb0a6335ad183aa49b2fa76
  - e38d48d7d7800869cce48b179a8d04fb4fafa9ffb9094148343a9357733ce2b1
  - b93fc724c26ae23e69aaf4c44a6857d7d9dc75f0b57649753d0944302b309546
  - d565350d288cb96a558a31c89a32f1bf7491c426a2214f35237fcaaae1c448e6
applied-feature-ids:
  - backup-retention-N-files
  - backup-filename-grammar-suffix
  - backup-restore-version-picker
  - backup-listfiles-return-type
  - backup-suspend-on-wipe
  - backup-manual-bypass-recency
  - backup-retention-cap
  - backup-state-auto-active-indicator
  - backup-storage-full-typed-exception
  - restore-success-toast-add
  - backup-restore-success-toast
---

## Overview
The backup domain gives the user an *optional* zero-knowledge cloud copy of her daily logs and pain symptoms so she can restore them on a new device or after wiping the app. Plaintext data never leaves the device: the snapshot is serialised to JSON, encrypted with AES-256-GCM using a key derived from a user-chosen passphrase (Argon2id, 64 MB / 3 iterations / 4-lane), and uploaded as an opaque `.enc` blob. The passphrase lives only in `flutter_secure_storage` on the device — there is no server-side reset and the cloud provider only ever sees ciphertext. Restore is therefore impossible without the original passphrase. As of code state on 2026-05-15 the only enumerated and wired provider is **Dropbox** (`SyncProvider.dropbox`); Google Drive and OneDrive are referenced in code comments as "v1.1" and are not present in the enum.

## Current behaviour
1. `BackupNotifier.build()` reads `AppSettingsRepository.getOrCreate()` and returns `BackupNotConnected` when `dropboxEmail == null`, otherwise `BackupConnected(email, lastBackupAt)`.
2. `BackupNotifier.connect()` transitions to `BackupRunning(BackupOperation.connecting)`, calls `CloudBackupProvider.authorize()`, then `currentEmail()`; if `currentEmail()` returns `null` it throws `SyncException('Could not fetch account')` and surfaces a `BackupErrorState`.
3. During `connect()`, after a successful `authorize()` + `currentEmail()` the notifier calls `listFiles()` (best-effort, swallows any exception) and parses the newest filename via `BackupFilename.parseTimestamp(files.first)` to seed `lastBackupAt`; if the listing fails or the cloud is empty, `lastBackupAt` is persisted as `null`.
4. `connect()` persists `dropboxEmail` and the discovered `lastBackupAt` via `AppSettingsRepository.updateBackupState(...)`. Before calling `ref.invalidateSelf()`, it **deletes `metra_backup_passphrase_v1` from secure storage** (BUG-B06 fix). This wipe is safe because: (a) iOS `KeychainAccessibility.first_unlock` items survive app uninstall, and Android `EncryptedSharedPreferences` survive on API 23+; without the delete, `build()` would read a stale passphrase from a prior install and compute `passphraseSet=true` → `autoBackupActive=true` before the user has entered any passphrase; (b) `disconnect()` already deletes the same key, so this is idempotent on a fresh-install first-connect; (c) `backupSilent()` and `backupNow()` both guard on `pass == null` and will not fire until the user enters a passphrase via `backupWithPassphrase()`.
5. `connect()`'s catch block calls `debugPrint('[BackupNotifier.connect] ${e.runtimeType}: $e')` **before** transitioning the state to `BackupErrorState`; `MetraException` instances surface `e.message`, anything else surfaces the literal `'Something went wrong. Please try again.'` (FR-17 / BUG-C04).
6. `BackupNotifier.disconnect()` enters `BackupRunning(BackupOperation.disconnecting)`, calls `CloudBackupProvider.disconnect()`, calls `AppSettingsRepository.updateBackupState(dropboxEmail: null, lastBackupAt: null)`, then deletes the secure-storage key `metra_backup_passphrase_v1`, then `invalidateSelf()`.
7. `BackupNotifier.backupWithPassphrase(passphrase)`: returns immediately (no-op) if the current state is `BackupRunning`; otherwise reads the existing passphrase (if any), writes the new passphrase under `metra_backup_passphrase_v1`, awaits `_runBackup()`, and — if `_runBackup()` produced a `BackupErrorState` — rolls the secure-storage value back to the old value (or deletes the key entirely when there was no prior value). Invariant: a failed backup must not change the persisted passphrase since the cloud blob is still encrypted with the old key.
8. `BackupNotifier.backupSilent()` is gated by four early-return guards, in order:
   - **Concurrency guard:** returns immediately if the state is `BackupRunning`.
   - **Not-connected guard:** returns immediately if the state is `BackupNotConnected`.
   - **Suspend guard (FR-12d, M3):** loads `AppSettingsData.backupSuspended`; if `true`, appends `SyncLogEntity(operation: backupSkipped, success: true, errorMessage: 'skipped: backupSuspended=true')` and returns. This check fires BEFORE any secure-storage write or snapshot work. `DeleteAllData.execute()` sets `backupSuspended = true` after both repository-level `deleteAll()` calls return; user-initiated `DailyLogRepository.{saveDailyLog, replacePainSymptoms, upsertAllLogs}` and `CycleEntryRepository.{insert, update}` clear it via `AppSettingsRepository.clearBackupSuspended()` (decoupled from the `lastLogOrSymptomWriteAt` bumper).
   - **Write-recency skip guard (unchanged from M2):** loads `AppSettingsData.lastBackupAt` and `lastLogOrSymptomWriteAt`; if `lastBackupAt != null` AND (`lastLogOrSymptomWriteAt == null` OR `!lastLogOrSymptomWriteAt.isAfter(lastBackupAt)`), appends the existing `backupSkipped` entry and returns. The same suspend-guard semantics apply to `backupWithPassphrase` and any auto-sync entry — in `backupWithPassphrase` the sentinel read MUST precede the secure-storage write currently at `backup_notifier.dart:100` (R-M3-A architectural invariant).
9. After the skip guard, `backupSilent()` reads the passphrase from secure storage. If it is `null` it returns silently (no error, no state change). Otherwise it calls `_runBackup()`.
10. `_runBackup()` transitions to `BackupRunning(BackupOperation.backingUp)`, awaits `BackupData()` (which delegates to `SyncOrchestrator.backup()`). On `Ok` it calls `ref.invalidateSelf()`; on `Err` it sets `BackupErrorState(error.message)`; on a raw `MetraException` thrown out of band it surfaces `e.message`; on any other thrown object it surfaces `'Something went wrong. Please try again.'`.
11. `BackupNotifier.restore()` transitions to `BackupRunning(BackupOperation.restoring)`, awaits `RestoreData()`; same Ok/Err handling pattern as `_runBackup()`.
12. `BackupNotifier.restoreWithPassphrase(passphrase)` mirrors `backupWithPassphrase`: capture old → write new → run `restore()` → if state is `BackupErrorState`, roll the passphrase back (or delete it).
13. `SyncOrchestrator.backup()` reads the passphrase from secure storage (throws `SyncException('No passphrase configured')` if absent), calls `BackupService.buildSnapshot()`, UTF-8 encodes the JSON, calls `EncryptionService.encrypt(bytes, passphrase)`, uploads to `CloudBackupProvider.upload(blob, filename)` where `filename = BackupFilename.filenameFor(now)`, then calls `listFiles()` and throws `SyncException('Upload verification failed')` if the new filename is not present in the listing.
14. After verifying the upload, `SyncOrchestrator.backup()` best-effort deletes every other file in `listFiles()` (one failure does not abort the rest — each delete is wrapped in its own try/catch).
15. `SyncOrchestrator.backup()` then calls `AppSettingsRepository.updateBackupState(dropboxEmail: <current>, lastBackupAt: <now()>)` — passing the existing `dropboxEmail` through unchanged — and appends `SyncLogEntity(provider: dropbox, operation: backup, success: true)`. On any thrown exception it appends `SyncLogEntity(... success: false, errorMessage: e.toString())` and rethrows.
16. `SyncOrchestrator.restore({String? filename})` reads the passphrase (throws `SyncException('No passphrase configured')` if absent), calls `listFiles()`. When `filename` is non-null, downloads that exact file; throws `SyncException('Download failed: ...')` if the named file is not present (race with concurrent prune from another device). When `filename` is null, downloads `entries.first` (legacy newest path; preserved for the 'Use newest' shortcut and for any caller that bypasses the picker). Decryption + `BackupSnapshot.decode()` behaviour is unchanged from M2.
17. After decoding, `SyncOrchestrator.restore()` invokes `DailyLogRepository.deleteAllAndReplace(logs, symptomsMap)` (transactional delete + reinsert), then awaits the injected `RecomputeFn` to rebuild `CycleEntries`.
18. **Restore alignment (FR-15):** after `deleteAllAndReplace` returns, `restore()` re-reads settings; if `lastBackupAt != null` it calls `AppSettingsRepository.updateLastDataWriteAt(lastBackupAt!)`. Without this, the bulk reinsert would bump `lastLogOrSymptomWriteAt` to the restore time, and the very next cold-start `backupSilent()` would re-upload identical data.
19. `SyncOrchestrator.restore()` appends `SyncLogEntity(... operation: restore, success: true)` on success; on any thrown exception it appends a failure log and rethrows.
20. `BackupService.buildSnapshot()` reads `DailyLogRepository.getAllOrderedByDate()`, then for each log loads `getPainSymptoms(log.date)`, and returns a `BackupSnapshot(version: 2, exportedAt: DateTime.now().toUtc(), logsWithSymptoms: ...)`. It does **not** include `AppSettings`, `CycleEntries`, or any other table.
21. `BackupSnapshot.encode()` emits JSON at `currentVersion = 2`. `BackupSnapshot.decode()` accepts versions `[1, 2]` and throws `BackupFormatException` on every parse failure: invalid JSON, non-object root, missing/invalid `version`, unsupported version, missing/invalid `exported_at`, non-list `daily_logs`, invalid enum indices, and TypeError during field coercion.
22. `BackupSnapshot._parseLog` enforces invariant DM-02 a second time on the way in: if `flowType != FlowType.mestruazioni` the parsed `flowIntensity` is forced to `null` regardless of what the blob contained.
23. `BackupFilename.filenameFor(t)` always converts `t.toUtc()` first and returns `metra_backup_YYYYMMDDTHHMMSSZ.enc`. `BackupFilename.parseTimestamp(filename)` returns `DateTime.utc(...)` on a canonical match and `null` (never throws) for anything else.
24. `DropboxProvider.authorize()` runs PKCE OAuth2: generates a 64-character `code_verifier`, derives the SHA-256 `code_challenge`, generates a 32-hex-char `state` token, opens the system browser via `FlutterWebAuth2.authenticate` with `callbackUrlScheme: 'metra'` and redirect URI `metra://oauth-callback`, with a 5-minute timeout that throws `SyncException('OAuth timed out — please try again')` (BUG-C03 / NFR-05).
25. On the OAuth callback, `DropboxProvider.authorize()` verifies the returned `state` matches the generated one (`SyncException('OAuth state mismatch — possible CSRF attack')`) and that `code` is present (`SyncException('OAuth callback missing code')`); it then POSTs to `/oauth2/token` (throws `SyncException('Token exchange failed: ${statusCode}')` on non-200) and stores `access_token` under `metra_dropbox_access_token_v1` and `refresh_token` under `metra_dropbox_refresh_token_v1`.
26. `DropboxProvider._authenticatedPost` injects `Authorization: Bearer <token>`; on a `401` response it calls `_refreshAccessToken()` (POST `grant_type=refresh_token`; throws `SyncException('No refresh token')` if missing, `SyncException('Refresh failed')` if non-200), persists the new access token, and retries the original request exactly once.
27. `DropboxProvider.upload(blob, filename)` POSTs the raw bytes to `/2/files/upload` with `Dropbox-API-Arg = {"path": "/<filename>", "mode": "overwrite", "mute": true}`; non-200 → `SyncException('Upload failed: ${statusCode}')`. Path is always relative because the Dropbox app console is configured as "App folder" type.
28. `DropboxProvider.listFiles()` POSTs `{"path": ""}` to `/2/files/list_folder`. A `409` (path/not_found, empty App folder) returns `[]`. Any other non-200 throws `SyncException('List failed: ${statusCode}')`. Pagination via `has_more` and `/list_folder/continue` is best-effort: a non-200 from `continue` stops paging but returns the partial list. The returned filenames are filtered to those starting with `metra_backup_` and ending with `.enc`, sorted descending so newest first.
29. `DropboxProvider.download(filename)` POSTs to `/2/files/download` with `Dropbox-API-Arg = {"path": "/<filename>"}`; non-200 → `SyncException('Download failed: ${statusCode}')`.
30. `DropboxProvider.deleteFile(filename)` POSTs to `/2/files/delete_v2` with `{"path": "/<filename>"}`; non-200 → `SyncException('Delete failed: ${statusCode}')`.
31. `DropboxProvider.disconnect()` best-effort POSTs to `/2/auth/token/revoke` (swallows any exception) and then unconditionally deletes both `metra_dropbox_access_token_v1` and `metra_dropbox_refresh_token_v1` from secure storage.
32. `DropboxProvider.currentEmail()` returns `null` if the access token is absent or the `/2/users/get_current_account` call returns non-200; otherwise returns `data['email'] as String?`.
33. `PassphraseDialog` has two modes: `setNew` (two fields — passphrase + confirmation, min-8 length, mismatch error) used before the first backup, and `unlock` (single field, no min length, any non-empty value enables submit) used before a restore. An incorrect passphrase in `unlock` mode is reported downstream by the AES-GCM authentication failure, not by the dialog.
34. `BackupScreen._ConnectedBody._handleBackup` reads `metra_backup_passphrase_v1` from secure storage **before showing any dialog**: if it is present and non-empty it calls `BackupNotifier.backupSilent()` (no dialog — FR-12 Nth-time path); otherwise it shows `PassphraseDialog.show(..., mode: setNew)` (FR-13 first-time path) and on confirm calls `backupWithPassphrase`.
35. `BackupScreen._ConnectedBody._handleRestore` first shows an `AlertDialog` asking the user to confirm the destructive replace (`backup_restore_confirm_title`/`_body`); only on confirm does it show `PassphraseDialog.show(..., mode: unlock)` and call `restoreWithPassphrase` with the entered value, plus a SnackBar showing `backup_restore_in_progress`.
36. `BackupScreen._ConnectedBody._handleDisconnect` shows a confirmation `AlertDialog`; on confirm it calls `BackupNotifier.disconnect()`.
37. `BackupScreen._ErrorBody` wraps the error message in a `Semantics(liveRegion: true, ...)` so screen readers announce it and offers a single button that calls `ref.invalidate(backupNotifierProvider)` to retry.

`BackupNotifier.backupNow()`: user-initiated manual backup entry point. Preserves the BackupRunning concurrency guard (refuses to start a second backup while one is in flight), the BackupNotConnected precondition (refuses to upload when no Dropbox account is connected), and the `backupSuspended` HC-2 sentinel (skips silently after a wipe, appending a `SyncOperation.backupSkipped` log entry); but **bypasses** the `lastBackupAt`/`lastLogOrSymptomWriteAt` write-recency guard that gates `backupSilent`. Reuses the cached passphrase via `secureStorageProvider.read(key: 'metra_backup_passphrase_v1')` — never writes to secure storage (does not invoke `backupWithPassphrase`). Returns silently when no passphrase is cached. The Backup screen's `_ConnectedBody._handleBackup` routes the cached-passphrase branch through `backupNow()` (not `backupSilent()`).

After `BackupNotifier.restoreWithPassphrase(passphrase)` returns a non-null restored-record count, `BackupConnectedView.handleRestore` (mixin in `lib/features/backup/views/backup_connected_view_handlers.dart`) dispatches a snackbar via the pre-captured `ScaffoldMessengerState` displaying `AppLocalizations.restoreSuccessToast(count)`. The dispatch happens BEFORE the post-await `mounted` guard so it is not suppressed by the view-unmount that the dispatcher performs when `restore()` flips state to `BackupRunning(restoring)`.

## Restore flow

Items 11–12 and 16–19 in [§ Current behaviour](#current-behaviour) document the orchestration layer (`BackupNotifier.restore()`, `restoreWithPassphrase()`, `SyncOrchestrator.restore()`). This section records UI-side affordances and user-observable outcomes of the restore operation.

After a successful restore, Métra displays a localised snackbar showing the number of daily logs restored from the chosen backup. The snackbar uses the new `restoreSuccessToast` ARB key with `{count}` placeholder (IT: "Ripristinati {count} elementi"; EN: "{count} entries restored").

## Public contracts

### `CloudBackupProvider` (lib/data/services/backup/dropbox_provider.dart)
```dart
abstract class CloudBackupProvider {
  Future<void> upload(Uint8List blob, String filename);
  Future<Uint8List> download(String filename);
  Future<List<BackupFileEntry>> listFiles();  // sorted newest-first by filename; each entry carries {name, timestampUtc, sizeBytes} parsed from the Dropbox list_folder server-side metadata (previously discarded). BackupFileEntry lives at lib/data/services/backup/backup_file_entry.dart.
  Future<void> deleteFile(String filename);

  // C-08 additive-only OAuth/account widening:
  Future<void> authorize();
  Future<String?> currentEmail();
  Future<void> disconnect();
}
```

### `BackupRunner` (lib/domain/use_cases/backup_data.dart)
```dart
abstract class BackupRunner {
  Future<void> backup();
  Future<void> restore();
}

class BackupData {
  const BackupData(BackupRunner runner);
  Future<Result<void>> call();   // catches MetraException → Err; other → Err(SyncException('Backup failed: $e'))
}

class RestoreData {
  const RestoreData(BackupRunner runner);
  Future<Result<void>> call();   // catches MetraException → Err; other → Err(SyncException('Restore failed: $e'))
}
```

### `SyncOrchestrator` (lib/data/services/backup/sync_orchestrator.dart)
```dart
typedef RecomputeFn = Future<dynamic> Function();

class SyncOrchestrator implements BackupRunner {
  SyncOrchestrator({
    required BackupService backupService,
    required EncryptionService encryptionService,
    required CloudBackupProvider provider,
    required AppSettingsRepository settingsRepo,
    required SyncLogRepository syncLogRepo,
    required DailyLogRepository logRepo,
    required RecomputeFn recompute,
    required FlutterSecureStorage secureStorage,
    DateTime Function()? now,        // defaults to () => DateTime.now().toUtc()
  });

  static const _passphraseKey = 'metra_backup_passphrase_v1';

  @override Future<void> backup();   // throws SyncException / CryptoException / MetraException; always appends a SyncLogEntity
  @override Future<void> restore();  // ditto; on success aligns lastLogOrSymptomWriteAt to lastBackupAt
}
```

### `BackupService` (lib/data/services/backup/backup_service.dart)
```dart
class BackupService {
  const BackupService(DailyLogRepository logRepo);
  Future<BackupSnapshot> buildSnapshot();   // version = 2, exportedAt = DateTime.now().toUtc()
}
```

### `BackupSnapshot` (lib/domain/entities/backup_snapshot.dart)
```dart
class BackupSnapshot {
  static const int currentVersion = 2;     // accepts read of v1 and v2; writes v2
  final int version;
  final DateTime exportedAt;
  final List<DailyLogWithSymptoms> logsWithSymptoms;

  String encode();                          // jsonEncode
  static BackupSnapshot decode(String json);// throws BackupFormatException on any parse failure
}
```

### `BackupFilename` (lib/data/services/backup/backup_filename.dart)
```dart
class BackupFilename {
  static String   filenameFor(DateTime t);       // "metra_backup_YYYYMMDDTHHMMSSZ.enc" (always UTC)
  static DateTime? parseTimestamp(String name);  // null for non-canonical input, never throws
}
```

### `BackupNotifier` / `BackupState` (lib/features/backup/state/)
```dart
sealed class BackupState { const BackupState(); }
class BackupNotConnected extends BackupState { const BackupNotConnected(); }
class BackupConnected   extends BackupState {
  // Constructor no longer `const` (new required field).
  final String email;
  final DateTime? lastBackupAt;
  final bool autoBackupActive;   // runtime projection of: !AppSettingsData.backupSuspended AND secureStorage.read(kPassphraseKey) != null; not persisted. BUG-B06: was previously derived only from !backupSuspended, causing a false-true after reinstall when a stale iOS Keychain / Android EncryptedSharedPrefs passphrase survived uninstall.
}
enum BackupOperation { connecting, backingUp, restoring, disconnecting }
class BackupRunning     extends BackupState { final BackupOperation operation; }
class BackupErrorState  extends BackupState { final String message; }

class BackupNotifier extends AsyncNotifier<BackupState> {
  static const String kPassphraseKey = 'metra_backup_passphrase_v1'; // public alias used by app.dart._autoSyncIfConfigured (BUG-B06)
  @override Future<BackupState> build();
  Future<void> connect();   // BUG-B06: deletes kPassphraseKey before invalidateSelf() — see item 4 above
  Future<void> disconnect();
  Future<void> backupWithPassphrase(String passphrase); // FR-14 manual path, bypasses skip guard
  Future<void> backupSilent();                          // FR-11/12/13 skip-guard path
  Future<void> restore();
  Future<void> restoreWithPassphrase(String passphrase);
}
```

### `SyncLogEntity` (lib/domain/entities/sync_log_entity.dart)
```dart
enum SyncProvider  { dropbox }                       // googleDrive / oneDrive marked "v1.1"
enum SyncOperation { backup, restore, backupSkipped }

class SyncLogEntity {
  final int?         id;
  final DateTime     timestamp;
  final SyncProvider provider;
  final SyncOperation operation;
  final bool         success;
  final String?      errorMessage;     // for backupSkipped, "skipped: lastWriteAt=... lastBackupAt=..."
}
```

### `PassphraseDialog` (lib/features/backup/widgets/passphrase_dialog.dart)
```dart
enum PassphraseDialogMode { setNew, unlock }

class PassphraseDialog extends StatefulWidget {
  final void Function(String passphrase) onConfirmed;
  final PassphraseDialogMode mode;        // default setNew

  static Future<void> show(
    BuildContext context, {
    required void Function(String) onConfirmed,
    PassphraseDialogMode mode = PassphraseDialogMode.setNew,
  });
}
```

`InsufficientStorageException` — `final class InsufficientStorageException extends SyncException`, co-located in `lib/core/errors/metra_exception.dart`. Carries `final int statusCode = 507` and a constant `message = 'backup_error_storage_full'` (ARB key, not a localised string). Thrown by `DropboxProvider.upload` when the HTTP response is 507. Thrown by `SyncOrchestrator.backup` as the terminal failure mode of the progressive-deletion retry loop (loop deletes the oldest remote backup, retries upload, repeats until success or only one prior backup remains; capped at `kBackupRetentionMaxFiles - 1 = 2` deletions per attempt).

## Enumerated providers / limits

- **Enumerated cloud providers** (`SyncProvider` enum, `lib/domain/entities/sync_log_entity.dart`): `dropbox` is the only value. The file comment states "googleDrive and oneDrive will be added in v1.1" — those values are **not** present in the enum and there is no corresponding `CloudBackupProvider` implementation in the codebase.
- **Wired provider**: `DropboxProvider implements CloudBackupProvider` (lib/data/services/backup/dropbox_provider.dart). Wired via `cloudBackupProvider` (Riverpod) which is a thin seam over `dropboxProviderProvider` for testability.
- **OAuth/API mechanism (Dropbox)**: OAuth 2.0 with PKCE (SHA-256 S256), `token_access_type=offline` so the app gets a refresh token. App-key from `--dart-define=DROPBOX_APP_KEY`. Redirect URI: `metra://oauth-callback`. Callback scheme: `metra`. App-folder access type (paths relative to `/Apps/<AppName>/`).
- **Sync operations** (`SyncOperation` enum): `backup`, `restore`, `backupSkipped` (FR-16 diagnostic entry, `success: true`).
- **Sync state machine** (`BackupState` sealed class): `BackupNotConnected` → `BackupConnected(email, lastBackupAt?)` → `BackupRunning(BackupOperation)` → `BackupConnected` (on success, via `invalidateSelf`) **or** `BackupErrorState(message)` (on failure). `BackupOperation` covers `{connecting, backingUp, restoring, disconnecting}`.
- **File naming convention**: `metra_backup_YYYYMMDDTHHMMSSZ_<6char>.enc` where `<6char>` is a six-character `[a-z0-9]` suffix drawn from `Random.secure()` per filename (FR-15). The parse regex is widened to accept BOTH the new suffixed form AND the legacy `metra_backup_YYYYMMDDTHHMMSSZ.enc` form for backwards compatibility with pre-M3 user folders: `^metra_backup_(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z(?:_([a-z0-9]{6}))?\.enc$`. Timestamp is always UTC. The suffix makes same-second collisions statistically vanishing (`≈ 4.6e-9` per backup at N=10 retention).
- **Blob format** (`EncryptionService`): `[16-byte salt][12-byte IV/nonce][ciphertext][16-byte GCM MAC]`. Cipher = AES-256-GCM. KDF = Argon2id at production parameters `memory: 65536, iterations: 3, parallelism: 4, hashLength: 32`. Salt and IV are freshly generated per encryption via `Random.secure()`.
- **Retention policy**: the newest `kBackupRetentionMaxFiles = 3` backup blobs are kept in the App folder. After every successful upload, `SyncOrchestrator.backup()` lists files and deletes entries beyond the keep-set of 3 newest by descending name-sort; the just-uploaded file is always preserved. Verification via `listFiles().contains(filename)` is mandatory. Per-file prune failures append a `SyncLogEntity(operation: backup, success: false, errorMessage: 'prune-failure: ...')` and do not abort the remaining prunes. On the first successful backup after upgrading from a version with the prior cap of 10, pre-existing surplus files beyond the new cap are silently pruned (no warning dialog or notification).
- **Secure-storage keys** (`flutter_secure_storage`):
  - `metra_backup_passphrase_v1` — user passphrase (`SyncOrchestrator._passphraseKey`, `BackupNotifier.kPassphraseKey`). **Platform survival note (BUG-B06):** iOS `KeychainAccessibility.first_unlock` items survive app uninstall; Android `EncryptedSharedPreferences` survive on API 23+. `BackupNotifier.connect()` deletes this key at the start of every OAuth connect so a stale value from a prior install cannot propagate.
  - `metra_dropbox_access_token_v1` — OAuth access token.
  - `metra_dropbox_refresh_token_v1` — OAuth refresh token.
- **OAuth timeout**: 5 minutes (`Duration(minutes: 5)`) on the `FlutterWebAuth2.authenticate` call.
- **Snapshot version range**: reads accept `[_minSupportedVersion=1, currentVersion=2]`; writes always emit `2`.
- **Passphrase rules** (`setNew` mode): minimum 8 characters, exact match required between the two fields. `unlock` mode requires only non-empty input.

## Cross-domain dependencies

- `← encryption` — backup depends on `EncryptionService` (AES-256-GCM + Argon2id) to produce/consume the blob; `CryptoException` from this layer surfaces as restore failure.
- `← cycle-log` — backup serialises `DailyLogEntity` + `PainSymptomData` rows via `DailyLogRepository.getAllOrderedByDate` and `getPainSymptoms(date)`; restore replaces them via `deleteAllAndReplace`. The skip guard reads `AppSettingsData.lastLogOrSymptomWriteAt`, which is bumped by every cycle-log write path (`saveDailyLog`, `replacePainSymptoms`, `deleteDailyLog`, `deleteAll`, `deleteAllAndReplace`, `upsertAllLogs`).
- `← cycle-analytics` — `SyncOrchestrator.restore()` invokes the injected `RecomputeFn` (wired to `RecomputeCycleEntries.call`) after `deleteAllAndReplace` so `CycleEntries` are rebuilt from the restored logs.
- `← settings/app-settings` — backup reads/writes `AppSettingsRepository.{getOrCreate, updateBackupState, updateLastDataWriteAt}` for `dropboxEmail`, `lastBackupAt`, and `lastLogOrSymptomWriteAt`.
- `← sync-log` — `SyncOrchestrator` and `BackupNotifier.backupSilent` both append to `SyncLogRepository`; this is the only writer of `backupSkipped` entries.
- `→ ui/settings` — a settings/help surface that lists Dropbox connection status and "last backup at" reads `BackupNotifier`. (Out-of-scope here; mentioned for completeness.)
- `→ diagnostic-log-view` — any UI that displays sync history reads `SyncLogRepository.getRecent` and must render the three `SyncOperation` values including `backupSkipped`.

## Gaps

1. **No multi-provider path**: `SyncProvider.googleDrive` and `oneDrive` are referenced in the file comment but are not enum members, have no `CloudBackupProvider` implementation, and no UI affordance to choose a provider. Anything labelled "the three enumerated providers" in product copy is aspirational, not code-grounded as of 2026-05-15.
2. **Passphrase rotation has no UI**: changing the passphrase requires `disconnect()` (which deletes `metra_backup_passphrase_v1`) followed by reconnecting and re-running the first-time backup flow. There is no in-place "change passphrase" affordance, no re-encryption of the existing cloud blob, and no test covering a rotation scenario.
3. **Partial-upload failure is undefined**: `DropboxProvider.upload` is a single POST with no resumable-upload session. A network failure mid-upload can leave a truncated blob; only the `listFiles().contains(filename)` verification step catches it, and the user-visible error is the generic `SyncException('Upload failed: ${statusCode}')` or `SyncException('Upload verification failed')` with no resume option. No test covers a partial / truncated response body.
4. **Pruning is best-effort and silent**: in `SyncOrchestrator.backup()` lines 79–86, each `deleteFile` is wrapped in an empty `catch (_)`. A persistent failure to prune older blobs leaks cloud storage and is never surfaced to the user or to `SyncLogRepository`. There is no test for "prune one file, second prune throws".
5. **`listFiles` pagination failure is silently truncated**: in `DropboxProvider.listFiles()` lines 232–234, a non-200 from `/list_folder/continue` is silently swallowed and the partial list is returned. If the truncated page omits the newest blob, `restore()` would download an older blob without any warning. No test exercises pagination at all.
6. **`disconnect` revoke failure is silent**: `DropboxProvider.disconnect()` wraps the `/2/auth/token/revoke` call in `try { ... } catch (_) {}`. A failure leaves a still-valid token on Dropbox's side; the local tokens are wiped regardless. No test covers a revoke-failure path.
7. **No test for `EncryptionService.decrypt` on truncated/corrupted blob length**: `decrypt` checks `blob.length < salt+iv+mac` and throws `CryptoException('Blob too short')`, but this branch is not exercised by the backup test suite (only by `encryption_service_test.dart` which is out of the scope this slice).
8. **Dropbox 5xx / rate-limit handling is undefined**: there is no retry policy on 429, 500, 502, 503. Every non-200 (except 401, which triggers exactly one refresh+retry, and 409 on `listFiles`) becomes a `SyncException('<verb> failed: ${statusCode}')` and bubbles to `BackupErrorState`. No test simulates a Dropbox 5xx.
9. **`currentEmail` failure mode is "user-disappeared"**: returning `null` causes `connect()` to throw `SyncException('Could not fetch account')` even though the tokens were just written successfully; the tokens are not rolled back, so a subsequent `connect()` may already be considered "connected" by `DropboxProvider.isConnected` while `AppSettingsRepository.dropboxEmail` remains null. No test covers this token-vs-settings inconsistency.
10. **No coverage for invalid filename in `connect()` listing**: `BackupFilename.parseTimestamp` returns `null` for non-canonical names; `connect()` assigns `null` to `discoveredLastBackupAt` in that case. If the App folder contains *only* a non-canonical file (e.g. user-uploaded), `lastBackupAt` is silently null and the user has no signal that there is something foreign in the folder.
11. **Concurrent `connect()` invocations are not guarded**: only `backupSilent` and `backupWithPassphrase` check `state.valueOrNull is BackupRunning`. A double-tap on the "Connect Dropbox" button could in principle launch two OAuth flows; no test covers this.
12. **Snapshot does not include `AppSettings`**: only `DailyLogs` + `PainSymptoms` are serialised. Restored devices lose `darkMode`, `notificationsEnabled`, `notificationDaysBefore`, `notificationTimeMinutes`, `firstDayOfWeek`, `declaredCycleLength`, and `painEnabled`/`notesEnabled` preferences. The `lastBackupAt` and `dropboxEmail` fields are also not in the blob — they are recovered indirectly via `connect()`'s `listFiles()` discovery, but the rest of the preferences are silently lost.
13. **No test that the `RecomputeFn` failure mode is handled** in `restore()`: if `recompute()` throws after `deleteAllAndReplace` succeeds, the orchestrator's catch block appends a failed restore log and rethrows, but the `DailyLogs` table is already replaced and `lastLogOrSymptomWriteAt` is bumped — leaving the device in an inconsistent state (logs restored, cycles not computed, alignment skipped). No test covers this partial-failure window.
14. **No verification that `BackupNotConnected` early-return survives a stale provider connection**: if `dropboxEmail` is null in settings but `DropboxProvider.isConnected` is still true (e.g. settings table reset but secure storage not), `backupSilent()` returns early due to the BackupNotConnected guard, but the next manual backup would succeed using the orphan tokens. No test for this drift.
