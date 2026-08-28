---
domain: backup
last-updated: 2026-07-06
last-verified: 2026-07-06
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
The backup domain gives the user an *optional* zero-knowledge cloud copy of her daily logs and pain symptoms so she can restore them on a new device or after wiping the app. Plaintext data never leaves the device: the snapshot is serialised to JSON, encrypted with AES-256-GCM using a key derived from a user-chosen passphrase (Argon2id, 64 MB / 3 iterations / 4-lane), and uploaded as an opaque `.enc` blob. The passphrase lives only in `flutter_secure_storage` on the device — there is no server-side reset and every cloud provider only ever sees ciphertext. Restore is therefore impossible without the original passphrase.

As of 2026-07-06, **three providers are enumerated and shipped**: `SyncProvider.dropbox` (Android + iOS), `SyncProvider.googleDrive` (Android only), `SyncProvider.iCloud` (iOS only). Exactly one provider is active at a time (`AppSettingsData.activeProvider`, default `dropbox`); switching providers is a first-class flow (`BackupNotifier.switchProvider`) that reuses the same passphrase and leaves the previous provider's `.enc` files intact. OneDrive — mentioned as a "v1.1" placeholder in an earlier code comment — was never implemented; iCloud was chosen instead for the iOS-native provider.

## Current behaviour

### Connection state and provider identity
1. `BackupNotifier.build()` (`lib/features/backup/state/backup_notifier.dart`) watches `appSettingsStreamProvider.future`, then calls `_isConnected(settings)`: for `dropbox`/`googleDrive` this is the email-sentinel check `dropboxEmail != null` (unchanged since M1); for `iCloud` it is `await cloudBackupProvider.authorize()` — a non-interactive iCloud-container probe — with any thrown `SyncException` caught locally and treated as not-connected (never escapes `build()`).
2. On connected, `build()` returns `BackupConnected(provider: settings.activeProvider, email: settings.dropboxEmail /* null for iCloud */, autoBackupActive, lastBackupAt)`. `email` is genuinely `null` for iCloud (no OAuth identity exists for it) — the connected view omits the email row rather than showing a blank one.
3. **`_switchInFlight` guard**: while a `switchProvider()` call is in flight, `build()` short-circuits to `BackupRunning(BackupOperation.switching)` instead of deriving state from a half-written settings row — this prevents a spurious `BackupNotConnected` flash during the Drift re-emissions that occur mid-switch.

### Connect / disconnect / switch
4. `BackupNotifier.connect()` transitions to `BackupRunning(BackupOperation.connecting)`, calls `provider.authorize()` then `provider.currentEmail()`; a `null` email fails the connect ONLY for non-iCloud providers (iCloud's `currentEmail()` always returns `null` by design and is tolerated). Deletes the stale-passphrase secure-storage key before `invalidateSelf()` (BUG-B06: a prior-install passphrase surviving uninstall — iOS Keychain `first_unlock` items and Android `EncryptedSharedPreferences` on API 23+ both survive uninstall — must not silently enable `autoBackupActive` before the user re-enters a passphrase).
5. `BackupNotifier.disconnect()` calls `provider.disconnect()`, clears `dropboxEmail`/`lastBackupAt`, **resets `activeProvider` back to `dropbox`** via the dedicated `setActiveProvider` writer, then deletes the passphrase key. The `activeProvider` reset is required because iCloud's `_isConnected` re-probes the container on every `build()` — without resetting to the email-sentinel-backed `dropbox` path, a disconnected iCloud user would immediately re-appear "connected" (this was a real bug, fixed).
6. `BackupNotifier.switchProvider(SyncProvider target)` is the confirm→revoke-old→connect-new→fresh-chain flow, in this order: (1) re-entrancy guard (no-op if already `BackupRunning`); (2) platform-availability assertion against `availableProviders(defaultTargetPlatform)`; (3) state → `BackupRunning(switching)`; (4) resolve BOTH the old and the new `CloudBackupProvider` impl *before* any Drift mutation (avoids a stale-read assertion — the resolution is by explicit `id`, not by reactive settings, so hoisting is safe); (5) **abort gate** — `await old.disconnect()`, and on throw roll back to `BackupErrorState` with `activeProvider` untouched; (6) `setActiveProvider(target)` — the point of no return; (7) clear old identity (`dropboxEmail: null, lastBackupAt: null`); (8) `newProvider.authorize()` + `currentEmail()` (null tolerated for iCloud) + best-effort `listFiles()`; (9) persist the new connected state + clear the suspend sentinel; (10) on any post-flip failure, surface `BackupErrorState` with **no rollback** — `activeProvider` stays on `target`, and the next `build()` shows a clean `BackupNotConnected` retry surface; (11) `ref.invalidateSelf()`. The **passphrase is reused across providers** — `switchProvider` never touches the passphrase secure-storage key (unlike `connect`/`disconnect`, which both delete it) — and the **old provider's `.enc` files are left intact** — `switchProvider` never calls `deleteFile` on the old provider.

### Backup / restore guards (provider-generic since M1)
7. `BackupNotifier.backupWithPassphrase(passphrase)`: no-op if `BackupRunning`; otherwise writes the new passphrase, awaits `_runBackup()`, and rolls the secure-storage value back (or deletes it) if the run produced a `BackupErrorState` — a failed backup must never change the persisted passphrase, since the cloud blob is still encrypted with the old key.
8. `BackupNotifier.backupSilent()` is gated by, in order: concurrency guard (`BackupRunning`); not-connected guard; suspend guard (`AppSettingsData.backupSuspended`, set by `DeleteAllData`, cleared by any cycle-log write); write-recency skip guard (`lastBackupAt` vs `lastLogOrSymptomWriteAt`). Every skip path appends a `SyncLogEntity(operation: backupSkipped, success: true, provider: settings.activeProvider, ...)` — the skip log now correctly stamps whichever provider is active, not a hardcoded `dropbox`.
9. `BackupNotifier.backupNow()` — manual entry point — keeps the concurrency and not-connected guards and the suspend sentinel, but bypasses the write-recency skip guard; reuses the cached passphrase without writing to secure storage; returns silently if no passphrase is cached.
10. `BackupNotifier.restore()` / `restoreWithPassphrase(passphrase)` mirror the backup path's Ok/Err handling and passphrase-rollback-on-failure semantics.
11. `SyncOrchestrator.backup()` reads the passphrase (throws if absent), builds the snapshot, encrypts it, uploads via the active `CloudBackupProvider`, then verifies the upload — **except for `SyncProvider.iCloud`**, which is in the orchestrator's `kEventuallyConsistentProviders` set and skips the synchronous post-upload `listFiles()` verification gate (see iCloud eventual-consistency note below). Retention pruning (`kBackupRetentionMaxFiles = 3`, best-effort per-file, one failure doesn't abort the rest) runs identically for all three providers, since it operates purely through the `CloudBackupProvider` interface.
12. `SyncOrchestrator.restore({filename})` downloads the named file (or the newest if `filename` is null), decrypts, `deleteAllAndReplace`s the daily logs, recomputes cycle entries, and re-aligns `lastLogOrSymptomWriteAt` to `lastBackupAt` so the very next cold-start doesn't immediately re-upload identical data.
13. `BackupSnapshot`/`BackupService`/`BackupFilename`/`EncryptionService` are unchanged and provider-agnostic — see Public contracts.

### Provider implementations
14. **`DropboxProvider`** (`lib/data/services/backup/dropbox_provider.dart`) — unchanged since M1: PKCE OAuth2, redirect URI `metra://oauth-callback`, App-folder-scoped REST calls, one-shot 401-refresh-and-retry.
15. **`GoogleDriveProvider`** (`lib/data/services/backup/google_drive_provider.dart`, Android-only by `availableProviders` + picker UI, NOT by an in-file guard) — OAuth2 PKCE with CSRF `state`, scope **`drive.file`** only (the narrow per-file scope), redirect URI **`com.paolosantucci.metraapp:/oauth-callback-google`** (reverse-domain scheme — Google rejects the generic `metra://` scheme with HTTP 400). `currentEmail()` calls `GET /drive/v3/about?fields=user(emailAddress)`, which `drive.file` grants without widening consent to identity scopes; on lookup failure it falls back to the literal label `'Google Drive'` rather than surfacing an error. Files live in a single `Metra` folder (created lazily on first upload, memoized folder ID). 401-refresh-retry wrapper mirrors Dropbox's.
16. **`IcloudProvider`** + **`IcloudGateway`**/**`ProductionIcloudGateway`** (`lib/data/services/backup/icloud_{provider,gateway}.dart`, `production_icloud_gateway.dart`; iOS/iPadOS-only) — no OAuth, no token secure-storage keys, no email (`currentEmail()` always `null`); "connected" is derived purely from the container-availability probe (`authorize()` → `ensureAvailable()` on the `iCloud.com.paolosantucci.metra` container, matching `ios/Runner/Runner.entitlements`). The gateway is a byte-oriented seam (`ProductionIcloudGateway` is documented as the only file in the codebase importing `package:icloud_storage`) so the fake in tests is a pure in-memory map with no file I/O.
    - **Upload eventual-consistency**: after the gateway write, `IcloudProvider.upload` runs a bounded best-effort poll (10 attempts, 500ms apart, no trailing delay after the last attempt) rather than treating poll-exhaustion-without-visibility as failure — a successful gateway write is the success criterion; the OS owns iCloud's own sync timing. (Fixes the "backup succeeded but app showed an error" bug.)
    - **Download eventual-consistency**: `icloud_storage 2.2.0`'s `download()` future completes *before* the file exists on disk (native side runs an async `NSMetadataQuery` and only materialises bytes once download status reaches `.current`). `ProductionIcloudGateway.download` attaches a `Completer` to the plugin's `onProgress` stream's completion and awaits it (bounded 60-second timeout, throws rather than reading a missing file) before calling `readAsBytes()`. (Fixes a restore-time `PathNotFoundException`.)
17. `PassphraseDialog` (`setNew` / `unlock` modes) is unchanged and provider-agnostic.

### UI
18. **Provider selection** uses a `CupertinoPicker` wheel in a modal bottom sheet (`BackupProviderPickerSheet`) with a cancel action and a "Connetti"/Connect confirm button; the caller supplies the platform-filtered provider list (the widget itself does not call `availableProviders`). It is reachable from **both** the empty view (first connect, no confirmation dialog) and the connected view (switching, gated behind a `MetraConfirmDialog`).
19. **`BackupEmptyView`**: CTA opens the picker sheet then calls `switchProvider(picked)` (not `connect()` directly) — `switchProvider`'s guard logic subsumes the first-connect case since there is no "old" provider identity to tear down when starting from `BackupNotConnected`.
20. **`BackupConnectedView`**: three-section layout — Account (provider name + email row omitted when null + last-backup), Stato (three-way indicator: not active / active / suspended), Azioni (Esegui backup, **Cambia provider**, Ripristina, Disconnetti). All interactive rows are wrapped so they're inert while a `BackupRunning` operation is in flight.
21. **`BackupConnectedHandlers`** (mixin): `handleBackup`, `handleRestore`, `handleDisconnect`, and **`handleSwitchProvider`** (opens the picker, no-ops if the user re-picks the already-active provider, confirms via dialog, then calls `switchProvider`).
22. **`BackupErrorView`**: unchanged — a live-region error message plus a retry button that invalidates the notifier.
23. **Restore picker** (`BackupPickerSheet`) is a separate CupertinoPicker-wheel sheet (returns a file index, not a provider); each row's label is `<localised date/time>` + `<formatted size>`, built from the `BackupFileEntry`'s parsed timestamp and byte count.

## Restore flow

Items 10 and 12 above document the orchestration layer. This section records UI-side affordances and user-observable outcomes.

After a successful restore, Métra displays a localised snackbar showing the number of daily logs restored from the chosen backup (`restoreSuccessToast` ARB key, `{count}` placeholder). The restore picker's row label shows `<date> <time> <size>` per backup entry, for every provider (the label logic is provider-agnostic, driven off `BackupFileEntry`).

## Public contracts

### `CloudBackupProvider` (lib/data/services/backup/cloud_backup_provider.dart)
```dart
abstract class CloudBackupProvider {
  Future<void> upload(Uint8List blob, String filename);
  Future<Uint8List> download(String filename);
  Future<List<BackupFileEntry>> listFiles();  // sorted newest-first by filename
  Future<void> deleteFile(String filename);

  Future<void> authorize();
  Future<String?> currentEmail();  // null is a valid, permanent answer for iCloud
  Future<void> disconnect();
  SyncProvider get id;             // stamps SyncLogEntity.provider
}
```
The abstract interface now lives in its own file (moved out of `dropbox_provider.dart`). Implementations must not leak provider-specific types (HTTP clients, OAuth libraries, plugin DTOs) across this boundary. Implemented by `DropboxProvider`, `GoogleDriveProvider`, `IcloudProvider`.

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
    required CloudBackupProvider provider,   // resolved via resolveBackupProvider(activeProvider)
    required AppSettingsRepository settingsRepo,
    required SyncLogRepository syncLogRepo,
    required DailyLogRepository logRepo,
    required RecomputeFn recompute,
    required FlutterSecureStorage secureStorage,
    DateTime Function()? now,
  });

  static const _passphraseKey = 'metra_backup_passphrase_v1';
  static const kBackupRetentionMaxFiles = 3;
  static const kEventuallyConsistentProviders = {SyncProvider.iCloud};  // skips the synchronous upload-verification gate

  @override Future<void> backup();
  @override Future<void> restore();  // aligns lastLogOrSymptomWriteAt to lastBackupAt on success
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

  String encode();
  static BackupSnapshot decode(String json);
}
```

### `BackupFilename` (lib/data/services/backup/backup_filename.dart)
```dart
class BackupFilename {
  static String   filenameFor(DateTime t);       // "metra_backup_YYYYMMDDTHHMMSSZ_<6char>.enc" (always UTC)
  static DateTime? parseTimestamp(String name);  // accepts legacy (no suffix) and suffixed forms; null, never throws
}
```

### `GoogleDriveProvider` (lib/data/services/backup/google_drive_provider.dart)
```dart
class GoogleDriveProvider implements CloudBackupProvider {
  @override SyncProvider get id => SyncProvider.googleDrive;
  // scope: https://www.googleapis.com/auth/drive.file
  // redirect: com.paolosantucci.metraapp:/oauth-callback-google
  // currentEmail() via GET /drive/v3/about?fields=user(emailAddress); falls back to literal 'Google Drive' label on failure
  // files live in a single lazily-created 'Metra' folder
}
```

### `IcloudProvider` / `IcloudGateway` (lib/data/services/backup/icloud_provider.dart, icloud_gateway.dart, production_icloud_gateway.dart)
```dart
abstract interface class IcloudGateway {
  Future<void> ensureAvailable();
  Future<void> upload(Uint8List blob, String relativePath);
  Future<List<IcloudEntry>> gather();
  Future<Uint8List> download(String relativePath);
  Future<void> delete(String relativePath);
  static const kQuotaExceededCode = 'E_QUOTA_EXCEEDED'; // TODO(M6): confirm real plugin code on-device
}

class IcloudEntry {
  final String relativePath;
  final int? sizeBytes;
}

class IcloudProvider implements CloudBackupProvider {
  @override SyncProvider get id => SyncProvider.iCloud;
  @override Future<String?> currentEmail() async => null;   // no OAuth identity for iCloud
  @override Future<void> disconnect() async {}               // no token keys to clear
}
```
`ProductionIcloudGateway` is the only file in the codebase importing `package:icloud_storage`; container id `iCloud.com.paolosantucci.metra` matches `ios/Runner/Runner.entitlements`.

### `BackupNotifier` / `BackupState` (lib/features/backup/state/{backup_notifier,backup_state}.dart)
```dart
sealed class BackupState { const BackupState(); }
class BackupNotConnected extends BackupState { const BackupNotConnected(); }
class BackupConnected   extends BackupState {
  final SyncProvider provider;      // which provider this connection is
  final String? email;              // null for iCloud — not an error state
  final bool autoBackupActive;      // !backupSuspended && passphraseSet
  final DateTime? lastBackupAt;
}
enum BackupOperation { connecting, backingUp, restoring, disconnecting, switching }
class BackupRunning     extends BackupState { final BackupOperation operation; }
class BackupErrorState  extends BackupState { final String message; }

class BackupNotifier extends AsyncNotifier<BackupState> {
  static const String kPassphraseKey = 'metra_backup_passphrase_v1';
  @override Future<BackupState> build();     // _switchInFlight short-circuit; per-provider _isConnected
  Future<void> connect();
  Future<void> disconnect();                 // resets activeProvider to dropbox
  Future<void> switchProvider(SyncProvider target);  // confirm -> revoke old -> connect new -> fresh chain
  Future<void> backupWithPassphrase(String passphrase);
  Future<void> backupSilent();
  Future<void> backupNow();
  Future<void> restore();
  Future<void> restoreWithPassphrase(String passphrase);
}
```

### `SyncLogEntity` (lib/domain/entities/sync_log_entity.dart)
```dart
enum SyncProvider  { dropbox, googleDrive, iCloud }   // OneDrive was never added; iCloud replaced it
enum SyncOperation { backup, restore, backupSkipped }

class SyncLogEntity {
  final int?         id;
  final DateTime     timestamp;
  final SyncProvider provider;
  final SyncOperation operation;
  final bool         success;
  final String?      errorMessage;
}
```

### `PassphraseDialog` (lib/features/backup/widgets/passphrase_dialog.dart)
```dart
enum PassphraseDialogMode { setNew, unlock }

class PassphraseDialog extends StatefulWidget {
  final void Function(String passphrase) onConfirmed;
  final PassphraseDialogMode mode;

  static Future<void> show(
    BuildContext context, {
    required void Function(String) onConfirmed,
    PassphraseDialogMode mode = PassphraseDialogMode.setNew,
  });
}
```

### `BackupProviderPickerSheet` (lib/features/backup/widgets/backup_provider_picker_sheet.dart)
```dart
class BackupProviderPickerSheet {
  static Future<SyncProvider?> show(
    BuildContext context, {
    required List<SyncProvider> providers,   // caller supplies the platform-filtered list
    int initialIndex = 0,
  });
}
```
CupertinoPicker wheel in a modal bottom sheet; cancel / "Connetti" confirm actions. Reachable from both the empty view (first connect) and the connected view (switching, behind a confirm dialog).

`InsufficientStorageException` — `final class InsufficientStorageException extends SyncException`, co-located in `lib/core/errors/metra_exception.dart`. Carries `final int statusCode = 507` and a constant `message = 'backup_error_storage_full'` (ARB key). Thrown by `DropboxProvider.upload` on HTTP 507, and by `IcloudProvider.upload` when the gateway throws a `PlatformException` with code `IcloudGateway.kQuotaExceededCode`. Thrown by `SyncOrchestrator.backup` as the terminal failure mode of the progressive-deletion retry loop (deletes the oldest remote backup, retries upload, repeats; capped at `kBackupRetentionMaxFiles - 1 = 2` deletions per attempt).

## Enumerated providers / limits

- **Enumerated cloud providers** (`SyncProvider` enum, `lib/domain/entities/sync_log_entity.dart`): `dropbox`, `googleDrive`, `iCloud` — all three enumerated and wired with real `CloudBackupProvider` implementations. OneDrive was floated in an earlier code comment ("v1.1") but was never implemented; a stray `// 'google_drive' | 'dropbox' | 'onedrive'` comment survives on the `SyncLogs.provider` column in `app_database.dart` (doc-only bug — no `onedrive` wire string is ever produced or accepted).
- **Platform availability** (`availableProviders(TargetPlatform)`, `lib/providers/backup_providers.dart`): Android → `[dropbox, googleDrive]`; iOS → `[dropbox, iCloud]`; any other platform (Linux/Windows dev/CI) → `[dropbox]` only. This is the sole enforcement point for Google-Drive-Android-only / iCloud-iOS-only — `resolveBackupProvider`'s per-enum-value resolution is deliberately unguarded (asymmetric by design), and the provider-picker widget itself performs no platform filtering (callers must pass an already-filtered list).
- **Single active provider**: `AppSettingsData.activeProvider` (default `dropbox`), persisted as a wire string (`'dropbox' | 'google_drive' | 'icloud'`) via a dedicated writer (`AppSettingsRepository.setActiveProvider`) — excluded from the bulk `copyWith`/`updateSettings` path, same posture as `backupSuspended`. The read-path parser (`_activeProviderFromString`) clamps any unrecognized/forward value to `dropbox` rather than throwing (EC-03/NFR-06); the strict sync-log-side parser (`stringToProvider`) still throws on unknown values, since a bad log string indicates real corruption rather than a benign forward-migration artefact.
- **OAuth/API mechanisms**:
  - **Dropbox**: OAuth 2.0 PKCE (SHA-256 S256), `token_access_type=offline`. App-key from `--dart-define=DROPBOX_APP_KEY`. Redirect URI `metra://oauth-callback`, callback scheme `metra`. App-folder-scoped paths.
  - **Google Drive**: OAuth 2.0 PKCE with CSRF `state`, scope `drive.file` only. Client ID from `--dart-define=GOOGLE_OAUTH_CLIENT_ID`. Redirect URI `com.paolosantucci.metraapp:/oauth-callback-google` (reverse-domain scheme; the generic `metra://` scheme is rejected by Google with HTTP 400). Single `Metra` app-managed Drive folder.
  - **iCloud**: no OAuth — container-based (`iCloud.com.paolosantucci.metra`, matches `Runner.entitlements`); "connected" is a non-interactive container-availability probe, not an email/token check.
- **Sync operations** (`SyncOperation` enum): `backup`, `restore`, `backupSkipped` (diagnostic entry, `success: true`, now stamped with whichever provider is active rather than a hardcoded value).
- **Sync state machine** (`BackupState` sealed class): `BackupNotConnected` → `BackupConnected(provider, email?, lastBackupAt?)` → `BackupRunning(BackupOperation)` → `BackupConnected` (success) **or** `BackupErrorState(message)` (failure). `BackupOperation` covers `{connecting, backingUp, restoring, disconnecting, switching}`.
- **File naming convention** (provider-agnostic): `metra_backup_YYYYMMDDTHHMMSSZ_<6char>.enc`, `<6char>` a `Random.secure()` `[a-z0-9]` suffix; the parser also accepts the legacy unsuffixed form. All three providers filter to this pattern and sort newest-first by filename.
- **Blob format** (`EncryptionService`, provider-agnostic): `[16-byte salt][12-byte IV/nonce][ciphertext][16-byte GCM MAC]`. AES-256-GCM; Argon2id at `memory: 65536, iterations: 3, parallelism: 4, hashLength: 32`. Salt/IV freshly generated per encryption.
- **Retention policy** (provider-agnostic): the newest `kBackupRetentionMaxFiles = 3` blobs are kept; every successful upload triggers a best-effort prune of older entries (verified via `listFiles().contains(filename)` **except for iCloud**, which is in `kEventuallyConsistentProviders` and treats poll-exhaustion-without-visibility as success rather than failure — the OS owns iCloud's own sync timing). Per-file prune failures are logged and don't abort the remaining prunes.
- **Secure-storage keys** (`flutter_secure_storage`):
  - `metra_backup_passphrase_v1` — user passphrase, shared across ALL providers (never touched by `switchProvider`).
  - `metra_dropbox_access_token_v1` / `metra_dropbox_refresh_token_v1` — Dropbox OAuth tokens.
  - `metra_google_drive_access_token_v1` / `metra_google_drive_refresh_token_v1` — Google Drive OAuth tokens.
  - (iCloud has no token keys — connection state is derived from the container probe alone.)
- **OAuth timeout**: 5 minutes on the `FlutterWebAuth2.authenticate` call, for both Dropbox and Google Drive.
- **iCloud eventual-consistency bounds**: upload-visibility poll — 10 attempts, 500ms apart, no trailing delay; download-materialisation wait — bounded 60-second timeout via the plugin's `onProgress` stream completion.
- **Snapshot version range**: reads accept `[1, 2]`; writes always emit `2`. Snapshot contains only `DailyLogs` + `PainSymptoms` — no `AppSettings` (including `activeProvider`) is included (see Gaps).
- **Passphrase rules** (`setNew` mode): minimum 8 characters, exact match between the two fields. `unlock` mode requires only non-empty input.
- **DB schema**: `activeProvider` added at schema version 11 as `TextColumn ... withDefault('dropbox')` — TEXT, never an enum-index integer (so reordering the Dart enum can never corrupt stored rows). Purely additive migration (`if (from < 11) addColumn`); existing rows receive the column default and remain on the email-sentinel connected path with zero behaviour change.

## Cross-domain dependencies

- `← encryption` — backup depends on `EncryptionService` (AES-256-GCM + Argon2id) to produce/consume the blob; `CryptoException` from this layer surfaces as restore failure.
- `← cycle-log` — backup serialises `DailyLogEntity` + `PainSymptomData` rows via `DailyLogRepository.getAllOrderedByDate` and `getPainSymptoms(date)`; restore replaces them via `deleteAllAndReplace`. The skip guard reads `AppSettingsData.lastLogOrSymptomWriteAt`, bumped by every cycle-log write path.
- `← cycle-analytics` — `SyncOrchestrator.restore()` invokes the injected `RecomputeFn` (wired to `RecomputeCycleEntries.call`) after `deleteAllAndReplace` so `CycleEntries` are rebuilt from the restored logs.
- `← settings/app-settings` — backup reads/writes `AppSettingsRepository.{getOrCreate, updateBackupState, updateLastDataWriteAt, setActiveProvider, clearBackupSuspended}` for `dropboxEmail`, `lastBackupAt`, `lastLogOrSymptomWriteAt`, and (since M1) **`activeProvider`** — the persisted single-active-provider selection, written exclusively through its own dedicated setter (excluded from the bulk `updateSettings`/`copyWith` path). `DeleteAllData.execute()` resets `activeProvider` back to `dropbox` alongside the passphrase wipe and `backupSuspended = true`.
- `← sync-log` — `SyncOrchestrator` and `BackupNotifier.backupSilent` both append to `SyncLogRepository`; this is the only writer of `backupSkipped` entries, now correctly stamped with the active provider rather than a hardcoded value.
- `→ ui/settings` — a settings/help surface that lists provider connection status and "last backup at" reads `BackupNotifier`. (Out-of-scope here; mentioned for completeness.)
- `→ diagnostic-log-view` — any UI that displays sync history reads `SyncLogRepository.getRecent` and must render the three `SyncOperation` values including `backupSkipped`, across all three providers.

## Gaps

1. **Passphrase rotation has no UI**: changing the passphrase requires `disconnect()` (deletes the passphrase key) followed by reconnecting and re-running the first-time backup flow. No in-place "change passphrase" affordance, no re-encryption of the existing cloud blob, no test covering rotation.
2. **Partial-upload failure is undefined** for the two HTTP-based providers (Dropbox, Google Drive): both are single-POST uploads with no resumable-upload session. A network failure mid-upload can leave a truncated blob; only the post-upload `listFiles().contains(filename)` check catches it (and that check is skipped entirely for iCloud, by design). No test covers a partial/truncated response body for any provider.
3. **Pruning is best-effort and silent**: each `deleteFile` in the retention-prune loop is wrapped in an empty catch, for all three providers. A persistent prune failure leaks cloud storage and is never surfaced to the user or to `SyncLogRepository`.
4. **Google Drive/Dropbox `listFiles` pagination failure is silently truncated**: a failed continuation page is swallowed and the partial list returned; if the truncated page omits the newest blob, `restore()` could download an older blob with no warning. No test exercises pagination for either provider.
5. **`disconnect` revoke failure is silent** for Dropbox and Google Drive (both wrap the OAuth-revoke call in an empty catch); a failure leaves a still-valid remote token while local tokens are wiped regardless. iCloud's `disconnect()` is a no-op (nothing to revoke). No test covers a revoke-failure path for either OAuth provider.
6. **iCloud quota error code is unconfirmed on-device**: `IcloudGateway.kQuotaExceededCode = 'E_QUOTA_EXCEEDED'` carries a `TODO(M6)` note that the real `icloud_storage` plugin error code for an over-quota write has not been confirmed against a physical device/account at quota limit.
7. **`switchProvider` post-flip failure has no rollback** (documented as a deliberate decision, OQ-01, not a bug): if `authorize()`/`currentEmail()`/`listFiles()` fail on the NEW provider after `activeProvider` has already been flipped, the user is left on the new (unconnected) provider rather than rolled back to the old one — the next screen state is a clean `BackupNotConnected` retry surface on the *new* provider, not a restored connection to the old one.
8. **Dropbox/Google Drive 5xx / rate-limit handling is undefined**: no retry policy on 429/500/502/503 for either OAuth provider; every non-200 (except a single 401-refresh-retry, and Dropbox's 409-on-listFiles empty-folder case) becomes a generic `SyncException` and bubbles to `BackupErrorState`. No test simulates a 5xx for either provider.
9. **`currentEmail` failure mode is "user-disappeared"** for Dropbox and Google Drive: a `null` currentEmail causes `connect()` to fail even though OAuth tokens were just written successfully; tokens are not rolled back, so a subsequent `connect()` may find the provider already token-authenticated while `AppSettingsRepository`'s email field remains null. No test covers this token-vs-settings inconsistency for either provider.
10. **No coverage for invalid filename in `connect()`'s listing discovery**, for any provider: an unparseable filename yields a silently-null `lastBackupAt`, with no signal to the user that something foreign exists in the backup folder.
11. **Concurrent `connect()` invocations are not guarded**: `switchProvider` has a re-entrancy guard, but plain `connect()` relies only on `backupSilent`/`backupWithPassphrase`'s own `BackupRunning` checks; a double-tap on "Connect" could in principle launch two concurrent OAuth flows for the HTTP-based providers. No test covers this.
12. **Snapshot does not include `AppSettings`**, on any provider: only `DailyLogs` + `PainSymptoms` are serialised. Restoring on a new device loses `darkMode`, `notificationsEnabled`, `notificationDaysBefore`, `notificationTimeMinutes`, `firstDayOfWeek`, `declaredCycleLength`, `painEnabled`/`notesEnabled` preferences, and — notably, since M1 — **the restored device's `activeProvider` selection itself is not part of the blob**; only `lastBackupAt`/email are indirectly recovered via `connect()`'s `listFiles()` discovery on whichever provider the user manually reconnects to.
13. **No test that the `RecomputeFn` failure mode is handled** in `restore()`, for any provider: if `recompute()` throws after `deleteAllAndReplace` succeeds, the device is left with logs restored but cycles not computed and alignment skipped — no test covers this partial-failure window.
14. **No verification that `BackupNotConnected` survives a stale provider connection**, for the HTTP-based providers: if `dropboxEmail`/Drive-equivalent is null in settings but the provider's own token state still looks valid, `backupSilent()` correctly returns early on the not-connected guard, but the next manual backup would silently succeed using orphaned tokens. No test for this drift.
15. **Stray stale doc comment**: `app_database.dart`'s `SyncLogs.provider` column carries an inline comment listing `'google_drive' | 'dropbox' | 'onedrive'` as the wire vocabulary — `onedrive` is not a real value (`stringToProvider` throws on it) and the comment predates the iCloud-over-OneDrive decision. Doc-only; no runtime effect.
