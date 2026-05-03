<!-- voice: second person, contractions on, formality 3/5, dry and direct, no exclamation points; no established VOICE.md — derived from README tone and inline code comment style -->
<!-- remove this comment before publishing -->

# Data layer

`lib/data/` implements the domain repository interfaces using Drift ORM on top of an SQLCipher-encrypted SQLite database. No domain or feature code touches Drift types, raw SQL, or HTTP directly — those concerns stay inside this layer.

## Table of contents

1. [Architecture overview](#1-architecture-overview)
2. [Database encryption](#2-database-encryption)
   - [SQLCipher database key](#21-sqlcipher-database-key)
   - [Key management service](#22-key-management-service)
3. [Schema reference (v5)](#3-schema-reference-v5)
   - [daily_logs](#31-daily_logs)
   - [pain_symptoms](#32-pain_symptoms)
   - [cycle_entries](#33-cycle_entries)
   - [symptom_templates](#34-symptom_templates)
   - [app_settings](#35-app_settings)
   - [sync_logs](#36-sync_logs)
4. [Schema migration history](#4-schema-migration-history)
5. [DAOs](#5-daos)
6. [Repository implementations](#6-repository-implementations)
7. [Backup and cloud sync](#7-backup-and-cloud-sync)
   - [Backup blob encryption](#71-backup-blob-encryption)
   - [Backup blob format](#72-backup-blob-format)
   - [BackupSnapshot versioning](#73-backupsnapshot-versioning)
   - [SyncOrchestrator flow](#74-syncorchestrator-flow)
   - [Dropbox OAuth2 flow](#75-dropbox-oauth2-flow)
8. [Code generation](#8-code-generation)
9. [Testing guidance](#9-testing-guidance)

---

## 1. Architecture overview

```
UI (features/)
    │
    ▼
Domain interfaces (domain/repositories/)
    │
    ▼
Drift implementations (data/repositories/)
    │
    ▼
Drift DAOs (data/database/daos/)
    │
    ▼
AppDatabase — SQLCipher-encrypted SQLite
```

**Layering rules:**
- `domain/` never imports from `data/`.
- `features/` never imports from `data/database/` or `data/services/` — always through the repository interfaces.
- Domain error types (`MetraException` subclasses) must not expose Drift or HTTP internals. Repository implementations catch infrastructure errors and rethrow as domain errors.

---

## 2. Database encryption

### 2.1 SQLCipher database key

The database file is encrypted at the page level by SQLCipher (AES-256-CBC by default). Unlocking happens in `AppDatabase.openConnection`:

```dart
static QueryExecutor openConnection(String dbPath, String hexKey) {
  // hexKey: exactly 64 hex characters (32 bytes / 256 bits)
  return LazyDatabase(() async {
    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () async {
        // SQLCipher library override is isolate-local; must be re-registered
        // in the background isolate spawned by createInBackground.
        open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      },
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = \"x'$hexKey'\"");
        // Fail loudly if SQLCipher is not actually loaded.
        final result = rawDb.select('PRAGMA cipher_version');
        if (result.isEmpty || (result.first['cipher_version'] as String? ?? '').isEmpty) {
          throw StateError('SQLCipher not loaded — database would be unencrypted.');
        }
        rawDb.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}
```

Key points:
- The key is passed as `x'<hex>'` — SQLCipher interprets this as a **raw binary key**, not a passphrase. No KDF is applied at this step.
- `PRAGMA cipher_version` is verified immediately after unlocking. An empty result means the plain sqlite3 library loaded instead of SQLCipher; the code throws rather than opening an unencrypted file.
- `PRAGMA foreign_keys = ON` is set here because SQLite resets it to off on every new connection. This makes `ON DELETE CASCADE` on `pain_symptoms` take effect.
- On Android, `open.overrideFor(OperatingSystem.android, openCipherOnAndroid)` must be called both on the main isolate (via `AppDatabase.initializeSQLCipher()`) and inside the `isolateSetup` callback, because isolate overrides are not inherited by child isolates.

### 2.2 Key management service

`lib/data/services/key_management_service.dart`

| Responsibility | Detail |
|---|---|
| Storage key | `metra_db_encryption_key_v1` in `flutter_secure_storage` |
| Key format | 64 lowercase hex characters (32 bytes, `Random.secure()`) |
| First launch | Generates key, writes to keychain, returns it |
| Subsequent launches | Reads existing key; re-generates only if the stored value is missing or invalid |
| Key deletion | `deleteDatabaseKey()` — call only during full data wipe; data becomes **permanently irrecoverable** |

The key never leaves the device. On Android it is stored in the Android Keystore-backed `EncryptedSharedPreferences`; on iOS in the Keychain.

---

## 3. Schema reference (v5)

File: `lib/data/database/app_database.dart`

### 3.1 `daily_logs`

One row per logged calendar day. The primary key is a UTC midnight `DateTime`.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `date` | `DATETIME` | no | — | PK; always UTC midnight |
| `flow_type` | `INTEGER` | yes | — | `FlowType.index`: 0=assente, 1=mestruazioni, 2=spotting |
| `flow_intensity` | `INTEGER` | yes | — | `FlowIntensity.index`: 0=light, 1=medium, 2=heavy, 3=veryHeavy. Non-null only when `flow_type = 1`. |
| `spotting` | `BOOLEAN` | no | `false` | Legacy column kept for migration provenance. Not authoritative — read `flow_type`. |
| `other_discharge` | `BOOLEAN` | no | `false` | |
| `pain_enabled` | `BOOLEAN` | no | `false` | |
| `pain_intensity` | `INTEGER` | yes | — | 0–3 overall pain score |
| `notes_enabled` | `BOOLEAN` | no | `false` | |
| `notes` | `TEXT` | yes | — | |

**Domain invariant (DM-02):** `flow_intensity` is meaningful only when `flow_type = 1` (mestruazioni). The repository enforces this in both directions: on write, intensity is set to `NULL` unless `flowType == FlowType.mestruazioni`; on read, intensity is discarded if `flowType` is not `mestruazioni`.

**Date normalisation:** `DailyLogDao.upsertDailyLog` and all query methods normalise every incoming `DateTime` to UTC midnight via `DateTime.utc(y, m, d)` before querying or writing. Callers may pass local `DateTime` values safely.

### 3.2 `pain_symptoms`

Many-to-one with `daily_logs`. Each row is one symptom logged for a given day.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `INTEGER` | no | autoincrement | PK |
| `daily_log_date` | `DATETIME` | no | — | FK → `daily_logs.date` ON DELETE CASCADE |
| `symptom_type` | `INTEGER` | no | — | `PainSymptomType.index` |
| `custom_label` | `TEXT` | yes | — | Non-null for user-created symptom types |

`ON DELETE CASCADE` is enforced at the SQLite level (`PRAGMA foreign_keys = ON` is set on every connection open). Deleting a `daily_logs` row automatically removes all its `pain_symptoms` rows.

`replacePainSymptoms` runs inside a transaction: delete all rows for the date, then batch-insert the new set. Drift streams watching that date re-emit automatically.

### 3.3 `cycle_entries`

Derived table, recomputed from `daily_logs` by the `RecomputeCycleEntries` use case on every mutation. **Never write to this table directly.**

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `INTEGER` | no | autoincrement | PK |
| `start_date` | `DATETIME` | no | — | UTC midnight of the cycle's first day |
| `end_date` | `DATETIME` | yes | — | UTC midnight of the day before the next cycle starts |
| `cycle_length` | `INTEGER` | yes | — | Days to the next cycle's `start_date`; `NULL` for the most recent cycle |
| `period_length` | `INTEGER` | yes | — | Count of consecutive logged flow days |

### 3.4 `symptom_templates`

User-defined custom symptom types.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `INTEGER` | no | autoincrement | PK |
| `label` | `TEXT` | no | — | Display name |
| `is_active` | `BOOLEAN` | no | `true` | Soft-delete flag |

### 3.5 `app_settings`

Singleton — always `id = 1`. `AppSettingsDao.getOrCreateSettings` runs the insert inside a transaction to avoid a TOCTOU race on first launch.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `INTEGER` | no | autoincrement | Always 1 |
| `language_code` | `TEXT` | no | `'it'` | BCP-47 tag |
| `dark_mode` | `BOOLEAN` | yes | — | `NULL` = follow system |
| `pain_enabled` | `BOOLEAN` | no | `true` | |
| `notes_enabled` | `BOOLEAN` | no | `true` | |
| `notification_days_before` | `INTEGER` | no | `2` | |
| `notifications_enabled` | `BOOLEAN` | no | `false` | |
| `dropbox_email` | `TEXT` | yes | — | Connected Dropbox account |
| `last_backup_at` | `DATETIME` | yes | — | UTC timestamp of last successful backup |
| `onboarding_completed` | `BOOLEAN` | no | `false` | |
| `declared_cycle_length` | `INTEGER` | yes | — | Added v5. User-declared average cycle length; prediction fallback when fewer than 3 measured cycles exist. `NULL` means the user skipped the question. |

**Partial updates:** `DriftAppSettingsRepository` exposes named update methods (`markOnboardingComplete`, `updateBackupState`, `saveDeclaredCycleLength`) that write only the relevant columns using `Value(...)` companions. This avoids accidental overwrites from stale in-memory state.

### 3.6 `sync_logs`

Local audit trail of backup and restore operations. Never included in the backup blob.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `INTEGER` | no | autoincrement | PK |
| `timestamp` | `DATETIME` | no | — | UTC |
| `provider` | `TEXT` | no | — | `'google_drive'` \| `'dropbox'` \| `'onedrive'` |
| `operation` | `TEXT` | no | — | `'backup'` \| `'restore'` |
| `success` | `BOOLEAN` | no | — | |
| `error_message` | `TEXT` | yes | — | Non-null on failure |

---

## 4. Schema migration history

Drift's `MigrationStrategy.onUpgrade` applies incremental branches. Each branch is guarded by `if (from < N)` so a database upgrading from v1 to v5 in one step passes through all intermediate branches.

| Version | Changes |
|---|---|
| v1 | Initial schema |
| v2 | Added `dropbox_email`, `last_backup_at` to `app_settings` |
| v3 | Added `onboarding_completed` to `app_settings` |
| v4 | Added `flow_type` column to `daily_logs`; migrated legacy `spotting` bool and `flow_intensity = 0` ("none") to the new enum; shifted `FlowIntensity` indices (dropped `none`, so indices shift down by 1 for light/medium/heavy/veryHeavy) |
| v5 | Added `declared_cycle_length` to `app_settings` |

**v4 migration detail.** This migration is written in raw SQL rather than using Drift's column-add helpers, because the migration logic reads from columns that the Drift-generated code has already evolved (the `flowType` field is present in the v5 Dart class). Raw SQL prevents any dependency on generated column accessors during migration.

The three UPDATE statements run in order:

```sql
-- 1. spotting=1 rows: set flow_type=2, clear intensity (mutually exclusive with flow)
UPDATE daily_logs SET flow_type = 2, flow_intensity = NULL WHERE spotting = 1;

-- 2. flow_intensity v3=0 (none) and not spotting: set flow_type=0 (assente), clear intensity
UPDATE daily_logs SET flow_type = 0, flow_intensity = NULL
  WHERE spotting = 0 AND flow_intensity = 0;

-- 3. flow_intensity v3 in [1..4] and not spotting: set flow_type=1 (mestruazioni), shift index
UPDATE daily_logs SET flow_type = 1, flow_intensity = flow_intensity - 1
  WHERE spotting = 0 AND flow_intensity BETWEEN 1 AND 4;
```

---

## 5. DAOs

All DAOs use Drift's `@DriftAccessor` annotation. Generated code lives in the corresponding `.g.dart` file; run `dart run build_runner build` after any schema change.

| DAO | File | Tables |
|---|---|---|
| `DailyLogDao` | `daos/daily_log_dao.dart` | `daily_logs`, `pain_symptoms` |
| `CycleEntryDao` | `daos/cycle_entry_dao.dart` | `cycle_entries` |
| `AppSettingsDao` | `daos/app_settings_dao.dart` | `app_settings` |
| `SyncLogDao` | `daos/sync_log_dao.dart` | `sync_logs` |

**Notable DAO behaviour:**

- `DailyLogDao.upsertDailyLog` uses `insertOnConflictUpdate` — it is safe to call for both create and update.
- `DailyLogDao.watchMonth` uses a half-open interval `[start, end)` where `end = DateTime.utc(year, month + 1)`. This correctly handles December by relying on Dart's date arithmetic.
- `DailyLogDao.watchSymptomDatesForMonth` returns a `Stream<Set<DateTime>>` of UTC-midnight dates that have at least one `pain_symptoms` row. The stream re-emits whenever those rows change, powering the calendar grid's per-day indicators without a manual invalidation step.
- `CycleEntryDao.replaceAll` runs inside a transaction: delete all rows, then insert the provided set.
- `AppSettingsDao.getOrCreateSettings` runs inside a transaction (read → insert if absent → re-read) to avoid a TOCTOU race on first launch.

---

## 6. Repository implementations

| Implementation | Interface | File |
|---|---|---|
| `DriftDailyLogRepository` | `DailyLogRepository` | `repositories/drift_daily_log_repository.dart` |
| `DriftCycleEntryRepository` | `CycleEntryRepository` | `repositories/drift_cycle_entry_repository.dart` |
| `DriftAppSettingsRepository` | `AppSettingsRepository` | `repositories/drift_app_settings_repository.dart` |
| `DriftSyncLogRepository` | `SyncLogRepository` | `repositories/drift_sync_log_repository.dart` |

Each implementation:

1. **Maps** between Drift row types (`DailyLog`, `CycleEntry`, …) and domain entities (`DailyLogEntity`, `CycleEntryEntity`, …). Domain entities never reference Drift types.
2. **Exposes Drift streams** as `Stream<List<Entity>>` by mapping the emitted row lists.
3. **Wraps multi-row mutations** in `_dao.transaction()`. For example, `DriftDailyLogRepository.deleteAllAndReplace` deletes all `daily_logs` rows (which cascade-deletes `pain_symptoms`) and then re-inserts the replacement set atomically.

**`DriftDailyLogRepository._fromRow` — read-time guard:**
When reading `flowType`, the repository first checks the `flowType` column (authoritative since v4). If that column is `NULL` on a legacy row that pre-dates the migration, it falls back to the `spotting` boolean. This is a defensive path; in practice every row has been migrated.

**`DriftDailyLogRepository._toCompanion` — write-time invariant:**
`spotting` is kept in sync with `flowType` on every write (`spotting: Value(entity.flowType == FlowType.spotting)`). This ensures any legacy reader (e.g., old CSV export code) still sees a consistent value.

---

## 7. Backup and cloud sync

### 7.1 Backup blob encryption

Cloud backup uses a **separate** encryption layer on top of the database encryption, keyed from a user-supplied passphrase. This is handled by `EncryptionService` (`lib/data/services/encryption_service.dart`).

| Parameter | Value |
|---|---|
| KDF | Argon2id — memory: 64 MB, iterations: 3, parallelism: 4, hash length: 32 bytes |
| Cipher | AES-256-GCM |
| Salt length | 16 bytes (random per backup) |
| Nonce/IV length | 12 bytes (random per backup) |
| MAC length | 16 bytes (GCM authentication tag, appended) |

### 7.2 Backup blob format

```
┌──────────────────┬──────────────────┬──────────────┬──────────────────┐
│  16-byte salt    │  12-byte nonce   │  ciphertext  │  16-byte GCM MAC │
└──────────────────┴──────────────────┴──────────────┴──────────────────┘
```

Total overhead per blob: **44 bytes** (salt + nonce + MAC), plus the ciphertext which is the same length as the plaintext. The plaintext is the UTF-8-encoded JSON of `BackupSnapshot.encode()`.

On decrypt, `EncryptionService.decrypt` validates the blob length before slicing, then passes the ciphertext + MAC to AES-GCM. A wrong passphrase or a corrupted blob causes AES-GCM authentication to fail; `SecretBoxAuthenticationError` is caught and rethrown as `CryptoException('Decryption failed: wrong passphrase or corrupted data')`.

The passphrase itself is stored under key `metra_backup_passphrase_v1` in `flutter_secure_storage` — it never leaves the device.

### 7.3 BackupSnapshot versioning

`BackupSnapshot` (`lib/domain/entities/backup_snapshot.dart`) carries a `version` integer.

| Version | Format |
|---|---|
| 1 | `flow_intensity` is v3 enum (indices 0–4: none/light/medium/heavy/veryHeavy); `spotting` is a separate boolean field |
| 2 (current) | `flow_type` (FlowType index) is authoritative; `flow_intensity` is v4 enum (indices 0–3: light/medium/heavy/veryHeavy); `spotting` field omitted |

`BackupSnapshot.decode` accepts both v1 and v2. When parsing a v1 snapshot it applies the same index-shifting logic as the v4 database migration: `flow_intensity = 0` maps to `FlowType.assente` with no intensity; `flow_intensity` in 1–4 maps to `FlowType.mestruazioni` with intensity shifted down by 1. Writes always emit v2.

Minimum supported version: 1. A version outside `[1, 2]` throws `BackupFormatException('Unsupported snapshot version N')`.

### 7.4 SyncOrchestrator flow

`SyncOrchestrator` (`lib/data/services/backup/sync_orchestrator.dart`) coordinates backup and restore end-to-end.

**Backup:**

1. Read passphrase from `flutter_secure_storage` (`metra_backup_passphrase_v1`).
2. `BackupService.buildSnapshot()` — reads all `daily_logs` and their `pain_symptoms`.
3. Serialize snapshot to JSON (`BackupSnapshot.encode()`), encode to UTF-8 bytes.
4. `EncryptionService.encrypt(bytes, passphrase)` — produces the blob.
5. Upload blob with filename `metra_backup_YYYYMMDDTHHMMSSZ.enc`.
6. Verify the file appears in `listFiles()` before pruning older backups.
7. Prune all older `.enc` files in the app folder (best-effort; individual delete failures are swallowed).
8. Update `app_settings.last_backup_at`.
9. Append a `SyncLogEntity` (success or failure).

**Restore:**

1. Read passphrase from `flutter_secure_storage`.
2. `listFiles()` — take the lexicographically first result (files are sorted descending by name, so the most recent backup is `files.first`).
3. Download blob.
4. `EncryptionService.decrypt(blob, passphrase)`.
5. `BackupSnapshot.decode(utf8.decode(bytes))`.
6. `DailyLogRepository.deleteAllAndReplace(logs, symptomsMap)` — runs in a single transaction.
7. `recompute()` — triggers `RecomputeCycleEntries`.
8. Append a `SyncLogEntity`.

On any error, `SyncOrchestrator` appends a failure `SyncLogEntity` and rethrows so the UI can display the error.

### 7.5 Dropbox OAuth2 flow

`DropboxProvider` (`lib/data/services/backup/dropbox_provider.dart`) implements the `CloudBackupProvider` interface for Dropbox.

**Authorization (`authorize()`):**

1. Generate a PKCE code verifier (64-character URL-safe random string) and derive the SHA-256 challenge.
2. Generate a 16-byte random CSRF state token.
3. Open the Dropbox authorization URL in a Chrome Custom Tab via `flutter_web_auth_2`.
4. On callback, verify the returned `state` parameter matches the generated token — mismatches throw `SyncException('OAuth state mismatch — possible CSRF attack')`.
5. Exchange the authorization code for tokens at `https://api.dropbox.com/oauth2/token` (offline access → returns both access token and refresh token).
6. Persist both tokens in `flutter_secure_storage` under `metra_dropbox_access_token_v1` and `metra_dropbox_refresh_token_v1`.

**Token refresh:** `_authenticatedPost` automatically retries with a refreshed access token when the API returns HTTP 401.

**App-folder scope:** The Dropbox app is configured for "App folder" access. All paths are relative to `/Apps/<AppName>/`, so `listFiles` uses path `""` (empty string = app folder root) and upload/download use `/<filename>`.

**Android platform integration:** The callback intent-filter is declared on `MainActivity` (launch mode `singleTop`) with scheme `metra://oauth-callback`. `MainActivity.consumeOAuthCallback()` intercepts the intent **before** `super.onCreate`/`super.onNewIntent` to prevent go_router from treating the OAuth redirect URL as a navigation deep link.

---

## 8. Code generation

Drift uses `build_runner` to generate `.g.dart` files from table and DAO definitions. Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

After any change to:
- `lib/data/database/app_database.dart` — table definitions
- Any file in `lib/data/database/daos/` — DAO query definitions

Do not commit without regenerating. The generated files (`app_database.g.dart`, `daily_log_dao.g.dart`, etc.) are checked in to the repository.

---

## 9. Testing guidance

**Key invariants to cover in unit tests:**

| Area | What to test |
|---|---|
| `EncryptionService` | encrypt → decrypt round-trip with same passphrase succeeds; two separate `encrypt` calls on the same plaintext produce different blobs (distinct random salt + nonce); `decrypt` with the wrong passphrase throws `CryptoException`; blob shorter than 44 bytes throws `CryptoException('Blob too short')` |
| `KeyManagementService` | First call generates and persists a valid 64-char hex key; second call returns the same key; `deleteDatabaseKey` followed by `getOrCreateDatabaseKey` generates a new, different key |
| `BackupSnapshot` | `decode(encode(snapshot)) == snapshot` round-trip; v1 snapshot decodes correctly with index shifting; version out of range throws `BackupFormatException`; malformed JSON throws `BackupFormatException` |
| `DriftDailyLogRepository` | `flowIntensity` is `null` after a round-trip when `flowType` is not `mestruazioni`; `spotting` column stays in sync on write; UTC-midnight normalisation is applied regardless of input timezone |
| `SyncOrchestrator` | Backup calls `upload` with a correctly formatted filename; restore calls `deleteAllAndReplace` and then `recompute`; failure path appends a `SyncLogEntity` with `success: false` and rethrows |

Use an in-memory Drift database (`NativeDatabase.memory()`) for repository and DAO tests — no SQLCipher key required in tests unless specifically testing the encryption path.

---

<!-- author notes
Voice: second person, contractions on, formality ~3/5 (developer audience — slightly more
formal than consumer docs), dry and direct, no exclamation points. No established VOICE.md
found; calibrated from project README tone and code comment style.

Sections cut: none — the brief enumerated all sections.

Verification gaps:
- [VERIFY: SyncLogDao implementation file path — not read directly; inferred from brief
  and repository pattern. Check lib/data/repositories/drift_sync_log_repository.dart exists.]
- [VERIFY: The Dropbox "App folder" path behaviour (listFiles uses empty string "") is
  documented in code comments in dropbox_provider.dart and confirmed in the listFiles
  implementation; marked accurate.]
-->
