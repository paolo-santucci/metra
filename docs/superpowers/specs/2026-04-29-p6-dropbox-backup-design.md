# P-6 — Dropbox E2E Encrypted Backup Design

**Sprint:** P-6  
**Date:** 2026-04-29  
**Status:** Approved

---

## Goal

Implement end-to-end encrypted cloud backup and restore via Dropbox. The user's data is encrypted on-device before upload; Dropbox sees only opaque blobs. Google Drive and OneDrive are deferred to v1.1.

---

## Decisions

- **Providers in scope:** Dropbox only (v1.0). Google Drive + OneDrive deferred.
- **Passphrase storage:** User-chosen passphrase stored in `flutter_secure_storage` after first backup. Never in DB, logs, or plaintext.
- **Auto-sync on app open:** Yes — if Dropbox is connected and passphrase is in secure storage, a silent backup runs on app open.
- **File strategy:** Timestamped single file. Upload new → verify → delete old. One `.enc` file at a time in `/Apps/Métra/`.
- **Conflict resolution:** Latest backup wins (per CLAUDE.md §16).
- **Backup content:** `DailyLogs` with embedded `PainSymptoms`. Excludes `SymptomTemplates` (no domain infrastructure yet — deferred to v1.1), `CycleEntries` (derived), `AppSettings` (device-specific), `SyncLogs` (local audit only).

---

## New dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_web_auth_2` | ^4.0.0 | Browser-based OAuth 2.0 PKCE callback |
| `http` | ^1.2.2 | Dropbox API v2 calls (already in pubspec, commented) |

No additional packages. `EncryptionService` is reused as-is.

---

## Architecture

```
lib/
├── data/
│   ├── services/
│   │   └── backup/
│   │       ├── backup_service.dart        # JSON snapshot ↔ domain entities
│   │       ├── dropbox_provider.dart      # OAuth 2.0 PKCE + Dropbox API v2
│   │       └── sync_orchestrator.dart     # Orchestrates backup/restore end-to-end
│   └── repositories/
│       └── drift_sync_log_repository.dart # SyncLog CRUD
├── domain/
│   ├── entities/
│   │   ├── backup_snapshot.dart           # Versioned JSON envelope
│   │   └── sync_log_entity.dart           # SyncLog domain model
│   ├── repositories/
│   │   └── sync_log_repository.dart       # Interface
│   └── use_cases/
│       ├── backup_data.dart               # Snapshot → encrypt → upload
│       └── restore_data.dart              # Download → decrypt → replace_all
└── features/
    └── backup/
        ├── backup_screen.dart             # Connect, status, Back up now, Restore
        └── state/
            └── backup_notifier.dart       # BackupState + operations
```

**Layering rules (unchanged):**
- `domain/` has no imports from `data/` or `features/`.
- `features/backup/` accesses data only through use cases and providers.
- `DropboxProvider` and `BackupService` are `data/` — not imported by domain.

---

## Database schema changes

Schema version bumps from **1 → 2**. Two nullable columns added to `AppSettings`:

```dart
// AppSettings table additions
TextColumn get dropboxEmail => text().nullable()();
DateTimeColumn get lastBackupAt => dateTime().nullable()();
```

Migration:

```dart
MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(appSettings, appSettings.dropboxEmail);
      await m.addColumn(appSettings, appSettings.lastBackupAt);
    }
  },
)
```

Schema version: `schemaVersion => 2`.

**Secure storage keys (never in DB):**

| Key | Contents |
|---|---|
| `metra_backup_passphrase_v1` | User-chosen backup passphrase |
| `metra_dropbox_access_token_v1` | Dropbox OAuth access token |
| `metra_dropbox_refresh_token_v1` | Dropbox OAuth refresh token |

---

## `BackupSnapshot` entity

`PainSymptomData` is not embedded in `DailyLogEntity` — they are stored separately and fetched via `DailyLogRepository.getPainSymptoms(date)`. In the snapshot, symptoms are embedded inside each log's JSON object to keep restore simple.

```dart
class DailyLogWithSymptoms {
  const DailyLogWithSymptoms({
    required this.log,
    required this.symptoms,
  });

  final DailyLogEntity log;
  final List<PainSymptomData> symptoms;
}

class BackupSnapshot {
  const BackupSnapshot({
    required this.version,
    required this.exportedAt,
    required this.logsWithSymptoms,
  });

  final int version;           // always 1 for now
  final DateTime exportedAt;
  final List<DailyLogWithSymptoms> logsWithSymptoms;
}
```

JSON envelope:

```json
{
  "version": 1,
  "exported_at": "2026-04-29T10:00:00.000Z",
  "daily_logs": [
    {
      "date": "2026-04-29T00:00:00.000Z",
      "flow_intensity": 2,
      "spotting": false,
      "other_discharge": false,
      "pain_enabled": true,
      "pain_intensity": 1,
      "notes_enabled": false,
      "notes": null,
      "pain_symptoms": [
        {"symptom_type": 0, "custom_label": null}
      ]
    }
  ]
}
```

`BackupService.buildSnapshot()`:
1. Calls `DailyLogRepository.getAllOrderedByDate()` → list of logs.
2. For each log, calls `DailyLogRepository.getPainSymptoms(log.date)` → list of symptoms.
3. Returns `BackupSnapshot` with all `DailyLogWithSymptoms`.

`BackupService.parseSnapshot(String json)` validates `version == 1` and deserialises; throws `BackupFormatException` if invalid.

---

## `DropboxProvider`

Handles all Dropbox-specific I/O. No domain types imported.

```dart
class DropboxProvider {
  static const _baseUrl = 'https://api.dropboxapi.com/2';
  static const _contentUrl = 'https://content.dropboxapi.com/2';
  static const _appFolder = '/Apps/Métra';
  static const _filePrefix = 'metra_backup_';
  static const _fileSuffix = '.enc';

  Future<void> authorize();           // OAuth 2.0 PKCE — opens browser
  Future<void> disconnect();          // Revoke token + clear secure storage
  Future<String?> currentEmail();     // null if not connected
  Future<void> upload(Uint8List blob, String filename);
  Future<Uint8List> download(String filename);
  Future<List<String>> listFiles();   // filenames in _appFolder, sorted desc
  Future<void> deleteFile(String filename);
  bool get isConnected;               // checks secure storage for token
}
```

**OAuth 2.0 PKCE flow:**
1. Generate `code_verifier` (43–128 random chars), derive `code_challenge = base64url(sha256(verifier))`.
2. Open `https://www.dropbox.com/oauth2/authorize?response_type=code&client_id=...&redirect_uri=metra://oauth-callback&code_challenge=...&code_challenge_method=S256&token_access_type=offline` via `flutter_web_auth_2`.
3. Catch redirect `metra://oauth-callback?code=<code>`.
4. POST to `https://api.dropbox.com/oauth2/token` with code + verifier → `access_token` + `refresh_token`.
5. Fetch `/users/get_current_account` → extract `email`.
6. Store tokens in secure storage; save email to `AppSettings.dropboxEmail`.

**Token refresh:** On any 401 from Dropbox API, refresh using `refresh_token` → update `access_token` in secure storage → retry the original request once.

**Upload:** POST to `_contentUrl/files/upload` with `Dropbox-API-Arg: {"path": "/Apps/Métra/<filename>", "mode": "add"}`.

**Filename format:** `metra_backup_<UTC-ISO8601-compact>.enc` e.g. `metra_backup_20260429T100000Z.enc`.

---

## `SyncOrchestrator`

Thin coordinator — no business logic of its own.

```dart
class SyncOrchestrator {
  const SyncOrchestrator(
    this._backupService,
    this._encryptionService,
    this._dropboxProvider,
    this._settingsRepo,
    this._syncLogRepo,
    this._secureStorage,
  );

  Future<void> backup();
  Future<void> restore();
}
```

**`backup()` sequence:**
1. Retrieve passphrase from secure storage (key `metra_backup_passphrase_v1`).
2. `BackupService.buildSnapshot()` → `BackupSnapshot`.
3. `jsonEncode(snapshot.toJson())` → UTF-8 bytes.
4. `EncryptionService.encrypt(bytes, passphrase)` → `Uint8List` blob.
5. Generate filename with current UTC timestamp.
6. `DropboxProvider.upload(blob, filename)`.
7. `DropboxProvider.listFiles()` → delete all except new filename.
8. `AppSettings` → set `lastBackupAt = DateTime.now().toUtc()`.
9. Append `SyncLog(provider: 'dropbox', operation: 'backup', success: true)`.
10. On any error at steps 4–8: append `SyncLog(success: false, errorMessage: ...)` and rethrow.

**`restore()` sequence:**
1. Retrieve passphrase from secure storage.
2. `DropboxProvider.listFiles()` → take first (most recent).
3. `DropboxProvider.download(filename)` → blob.
4. `EncryptionService.decrypt(blob, passphrase)` → bytes. Wrong passphrase throws `DecryptionException` → surface as user-visible error.
5. `BackupService.parseSnapshot(utf8.decode(bytes))` → `BackupSnapshot`.
6. Build `logs` and `symptomsMap` from `snapshot.logsWithSymptoms`.
7. `DailyLogRepository.deleteAllAndReplace(logs, symptomsMap)` — already exists, atomically replaces logs + symptoms.
8. `RecomputeCycleEntries()`.
9. Append `SyncLog(operation: 'restore', success: true)`.
10. On error: append `SyncLog(success: false)` and rethrow without mutating data further.

---

## `BackupData` and `RestoreData` use cases

Both are thin wrappers over `SyncOrchestrator` that expose a `Result<void, MetraException>` interface to the UI layer, consistent with existing use-case patterns.

```dart
class BackupData {
  const BackupData(this._orchestrator);
  Future<Result<void, MetraException>> call() async { ... }
}

class RestoreData {
  const RestoreData(this._orchestrator);
  Future<Result<void, MetraException>> call() async { ... }
}
```

---

## `BackupNotifier`

```dart
sealed class BackupState { ... }
class BackupIdle extends BackupState { ... }      // connected + last backup info
class BackupInProgress extends BackupState { ... } // operation label
class BackupError extends BackupState { ... }      // message + retry callback

final backupNotifierProvider =
    AsyncNotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
```

Exposes:
- `connect()` — triggers OAuth flow
- `disconnect()` — revokes token, clears secure storage fields
- `backupNow(String passphrase)` — first call; stores passphrase then calls `BackupData`
- `backupSilent()` — auto-sync path; passphrase from secure storage
- `restore()` — calls `RestoreData`; passphrase from secure storage

---

## `BackupScreen` UI

Single screen, accessible via the "Backup" row in Settings (replaces `_showComingSoon`). Route: `/backup`.

**State: not connected**
- Heading: "Cloud backup"
- Body: "Your data stays on your device. Connect Dropbox to keep an encrypted copy in the cloud — only you can read it."
- Button: "Connect Dropbox" (primary)

**State: connected, no backup yet**
- Heading: "Cloud backup"
- Subtext: "Connected as: [email]"
- Last backup: "Never"
- Button: "Back up now" (primary)
- Link: "Disconnect"

**State: connected, backup exists**
- Heading: "Cloud backup"
- Subtext: "Connected as: [email]"
- Last backup: "29 April 2026, 10:00"
- Buttons: "Back up now" (primary), "Restore from backup" (ghost)
- Link: "Disconnect"

**State: in progress**
- Loading indicator + label ("Backing up…" / "Restoring…")
- Buttons disabled

**State: error**
- Inline error message (no raw exceptions)
- "Try again" button

**Passphrase modal** (first backup only):
- Title: "Set a backup passphrase"
- Body: "This passphrase encrypts your backup. If you lose it, your backup cannot be recovered — there is no reset."
- Input: password field (obscured, toggle visibility)
- Confirm input: repeat field
- Button: "I understand — save and back up"

**Restore confirmation dialog:**
- "This will replace all current data with the backup. This cannot be undone."
- "Restore" (destructive) / "Cancel"

---

## Auto-sync on app open

In `MetraApp` (already a `ConsumerStatefulWidget`), in `initState`:

```dart
Future<void> _autoSync() async {
  final orchestrator = await ref.read(syncOrchestratorProvider.future);
  final passphrase = await _secureStorage.read(key: 'metra_backup_passphrase_v1');
  if (passphrase == null) return; // not configured
  try {
    await orchestrator.backup();
  } catch (_) {
    // silent failure — user can manually retry from BackupScreen
  }
}
```

Called once per app open, after `initState` completes. Failures are silent (not surfaced to the user as a startup error).

---

## L10n keys (new)

| Key | IT | EN |
|---|---|---|
| `backup_screen_title` | `Backup` | `Backup` |
| `backup_not_connected_body` | `I tuoi dati rimangono sul dispositivo. Connetti Dropbox per conservare una copia cifrata nel cloud — solo tu puoi leggerla.` | `Your data stays on your device. Connect Dropbox to keep an encrypted copy in the cloud — only you can read it.` |
| `backup_connect_dropbox` | `Connetti Dropbox` | `Connect Dropbox` |
| `backup_connected_as` | `Connesso come: {email}` | `Connected as: {email}` |
| `backup_last_backup_never` | `Nessun backup` | `Never backed up` |
| `backup_last_backup_at` | `Ultimo backup: {datetime}` | `Last backup: {datetime}` |
| `backup_now` | `Esegui backup` | `Back up now` |
| `backup_restore` | `Ripristina dal backup` | `Restore from backup` |
| `backup_disconnect` | `Disconnetti` | `Disconnect` |
| `backup_in_progress` | `Backup in corso…` | `Backing up…` |
| `backup_restore_in_progress` | `Ripristino in corso…` | `Restoring…` |
| `backup_passphrase_title` | `Imposta una passphrase` | `Set a backup passphrase` |
| `backup_passphrase_body` | `Questa passphrase cifra il tuo backup. Se la perdi, il backup non può essere recuperato — non esiste un reset.` | `This passphrase encrypts your backup. If you lose it, your backup cannot be recovered — there is no reset.` |
| `backup_passphrase_confirm_button` | `Ho capito — salva ed esegui il backup` | `I understand — save and back up` |
| `backup_restore_confirm_title` | `Ripristinare il backup?` | `Restore backup?` |
| `backup_restore_confirm_body` | `Tutti i dati attuali saranno sostituiti. Questa azione è irreversibile.` | `This will replace all current data. This cannot be undone.` |
| `backup_error_wrong_passphrase` | `Passphrase errata. Riprova.` | `Wrong passphrase. Please try again.` |
| `backup_error_generic` | `Errore durante il backup. Riprova.` | `Backup failed. Please try again.` |
| `backup_disconnect_confirm_title` | `Disconnettere Dropbox?` | `Disconnect Dropbox?` |
| `backup_disconnect_confirm_body` | `Il backup nel cloud non verrà eliminato.` | `Your cloud backup will not be deleted.` |

---

## Security requirements

- Passphrase, access token, and refresh token never written to DB, `print`, or `debugPrint`.
- Dropbox app key stored in `--dart-define=DROPBOX_APP_KEY=...` (not in source).
- Dropbox scope: `files.content.write files.content.read` scoped to app folder only.
- `BackupSnapshot` JSON must not contain raw `AppSettings` (avoids leaking notification config, theme preferences).
- `SyncLog.errorMessage` must not contain passphrase or token substrings.

---

## Testing

- Unit: `BackupService` — snapshot round-trip (build → serialize → parse → equal).
- Unit: `SyncOrchestrator` — with fake `DropboxProvider`, `EncryptionService`, repos.
  - Backup happy path: upload called, old file deleted, `lastBackupAt` updated.
  - Backup upload failure: old file not deleted, `SyncLog(success: false)` appended.
  - Restore wrong passphrase: `DecryptionException` propagated, no data mutation.
  - Restore happy path: `deleteAllAndReplace` called, `RecomputeCycleEntries` called.
- Unit: `BackupData` / `RestoreData` — thin wrapper, verify `Result` wrapping.
- Widget: `BackupScreen` — not-connected state, connected state, in-progress state, error state, passphrase modal appearance.
- No unit test for `DropboxProvider` OAuth dance (requires device/browser); document in §13 E2E checklist.

---

## Definition of Done

- [ ] `flutter analyze` clean, `dart format` clean.
- [ ] All tests pass; ≥ 80% coverage on new `lib/` files.
- [ ] Dropbox connect → back up → disconnect → reconnect → restore round-trip works on Android device.
- [ ] Wrong passphrase shows error, data unchanged.
- [ ] Auto-sync on app open works silently when passphrase is stored.
- [ ] `SyncLogs` table populated correctly after each operation.
- [ ] No health data in `SyncLog.errorMessage`.
- [ ] `appsec-engineer` review: zero Critical/High findings.
- [ ] Schema migration from v1 → v2 runs cleanly on existing DB.
- [ ] Tag `v0.1.0-p6`.
