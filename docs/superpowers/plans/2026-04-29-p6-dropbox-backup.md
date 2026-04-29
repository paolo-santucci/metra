# Métra — Sprint Plan: P-6 — Dropbox E2E Encrypted Backup (F-08)

> **For agentic workers:** Use `superpowers:subagent-driven-development` to execute task-by-task with spec+quality review after each. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement end-to-end encrypted backup and restore via Dropbox. The user's data is encrypted on-device with AES-256-GCM (key from Argon2id over a user-chosen passphrase) before upload; Dropbox sees only opaque `.enc` blobs. Single timestamped file in `/Apps/Métra/`, "latest backup wins" conflict resolution. Auto-sync on app open (silent if passphrase is in secure storage). Google Drive and OneDrive deferred to v1.1.

**Architecture:** New `lib/data/services/backup/` directory with `BackupService` (snapshot ↔ JSON), `DropboxProvider` (OAuth 2.0 PKCE + Dropbox API v2), and `SyncOrchestrator` (combines services). New `BackupSnapshot` domain entity. Schema migration v1→v2 adds `dropboxEmail` and `lastBackupAt` to `AppSettings`. Tokens and passphrase live in `flutter_secure_storage` only — never in DB or logs. New `BackupScreen` route reachable from Settings.

**Tech:** `flutter_web_auth_2: ^4.0.0` (new), `http: ^1.2.2` (uncommented). Reuses existing `EncryptionService`.

**Spec:** `docs/superpowers/specs/2026-04-29-p6-dropbox-backup-design.md`

---

## What is already done (do not recreate)

- `EncryptionService` (`lib/data/services/encryption_service.dart`) — AES-256-GCM + Argon2id, complete and tested. Reused as-is.
- `KeyManagementService` (`lib/data/services/key_management_service.dart`) — DB key in secure storage. Pattern to follow for new secure-storage keys.
- `SyncLogs` table — already in `app_database.dart`; no DAO yet.
- `AppSettings` table — exists, needs schema bump for two new columns.
- `DailyLogRepository.deleteAllAndReplace(logs, symptomsMap)` — already exists, atomically replaces logs + symptoms via FK cascade. Used directly in the restore path.
- `DailyLogRepository.getAllOrderedByDate()` and `getPainSymptoms(DateTime date)` — backup uses these.
- Settings backup row (`settings_screen.dart` line 172) — currently calls `_showComingSoon`; will be replaced with route push.
- `MetraApp` is already a `ConsumerStatefulWidget` (per P-3) — `initState` is the hook for auto-sync.
- Result/Err/Ok pattern + `MetraException` hierarchy in `core/`. New use cases follow this pattern.

---

## Critical files to read before coding

| File | Why |
|---|---|
| `lib/data/services/encryption_service.dart` | API used by `SyncOrchestrator`: `encrypt(Uint8List, passphrase)`, `decrypt(Uint8List, passphrase)` |
| `lib/data/services/key_management_service.dart` | Pattern for secure-storage helpers |
| `lib/data/database/app_database.dart` | `SyncLogs` table definition + `AppSettings` schema |
| `lib/domain/repositories/daily_log_repository.dart` | `deleteAllAndReplace`, `getAllOrderedByDate`, `getPainSymptoms` signatures |
| `lib/domain/use_cases/import_daily_logs.dart` | Reference for restore-style use case |
| `lib/domain/use_cases/export_daily_logs.dart` | Reference for backup-style use case |
| `lib/providers/use_case_providers.dart` | Provider pattern (FutureProvider with `.future`) |
| `lib/providers/repository_providers.dart` | Repository provider pattern |
| `lib/features/settings/settings_screen.dart` line 169–182 | Where to wire `/backup` route |
| `lib/app.dart` | `MetraApp.initState` for auto-sync hook |
| `test/helpers/fake_daily_log_repository.dart` | Fake repository pattern for tests |
| `test/features/settings/settings_screen_test.dart` | Widget test pattern |

---

## Wave structure

```
Wave 1 (parallel × 5): T1 · T2 · T3 · T4 · T5
Wave 2 (parallel × 2): T6 (after T5) · T7 (after T1)
Wave 3 (sequential):   T8 (after T3 + T4 + T6 + T7)
Wave 4 (parallel × 2): T9 · T10 (after T8)
Wave 5 (sequential):   T11 (after T9 + T10)
Wave 6 (parallel × 2): T12 (after T11) · T13 (after T2)
Wave 7 (sequential):   T14 (after T12 + T13)
Wave 8 (sequential):   T15 (after T11 + T14)
Wave 9 (gate):         T16 (after all)
```

---

## Tasks

### T1 — Dependencies + native config

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Enable dependencies in `pubspec.yaml`**

Uncomment the existing `http: ^1.2.2` line. Add `flutter_web_auth_2: ^4.0.0` in the same dependencies block.

```yaml
  http: ^1.2.2
  flutter_web_auth_2: ^4.0.0
```

- [ ] **Step 2: Run `flutter pub get`**

Run: `flutter pub get`
Expected: no errors, lockfile updates.

- [ ] **Step 3: Add intent filter to AndroidManifest.xml**

Inside the existing `<activity android:name=".MainActivity" ...>` element, add a second `<intent-filter>` for the OAuth callback scheme `metra://oauth-callback`:

```xml
<intent-filter android:label="metra_oauth">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="metra" android:host="oauth-callback" />
</intent-filter>
```

- [ ] **Step 4: Add URL scheme to ios/Runner/Info.plist**

Inside the top-level `<dict>`, add:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>com.paolosantucci.metra.oauth</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>metra</string>
    </array>
  </dict>
</array>
```

- [ ] **Step 5: Verify analyze/test still green**

Run: `flutter analyze && flutter test`
Expected: no errors, all existing tests pass.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore(deps): enable flutter_web_auth_2 and http; configure metra:// URL scheme"
```

---

### T2 — L10n strings

**Files:**
- Modify: `lib/l10n/app_it.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add 20 keys to both ARB files**

Add to `app_en.arb`:

```json
"backup_screen_title": "Backup",
"backup_not_connected_body": "Your data stays on your device. Connect Dropbox to keep an encrypted copy in the cloud — only you can read it.",
"backup_connect_dropbox": "Connect Dropbox",
"backup_connected_as": "Connected as: {email}",
"@backup_connected_as": { "placeholders": { "email": { "type": "String" } } },
"backup_last_backup_never": "Never backed up",
"backup_last_backup_at": "Last backup: {datetime}",
"@backup_last_backup_at": { "placeholders": { "datetime": { "type": "String" } } },
"backup_now": "Back up now",
"backup_restore": "Restore from backup",
"backup_disconnect": "Disconnect",
"backup_in_progress": "Backing up…",
"backup_restore_in_progress": "Restoring…",
"backup_passphrase_title": "Set a backup passphrase",
"backup_passphrase_body": "This passphrase encrypts your backup. If you lose it, your backup cannot be recovered — there is no reset.",
"backup_passphrase_input_label": "Passphrase",
"backup_passphrase_confirm_label": "Confirm passphrase",
"backup_passphrase_mismatch": "Passphrases do not match.",
"backup_passphrase_too_short": "Passphrase must be at least 8 characters.",
"backup_passphrase_confirm_button": "I understand — save and back up",
"backup_restore_confirm_title": "Restore backup?",
"backup_restore_confirm_body": "This will replace all current data. This cannot be undone.",
"backup_restore_confirm_button": "Restore",
"backup_error_wrong_passphrase": "Wrong passphrase. Please try again.",
"backup_error_generic": "Backup failed. Please try again.",
"backup_error_no_backup_found": "No backup found in your Dropbox.",
"backup_disconnect_confirm_title": "Disconnect Dropbox?",
"backup_disconnect_confirm_body": "Your cloud backup will not be deleted.",
"backup_disconnect_confirm_button": "Disconnect"
```

Add the corresponding IT translations to `app_it.arb` (use the IT strings from the spec §L10n keys table).

- [ ] **Step 2: Generate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations*.dart` updated; `flutter analyze` clean.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/app_it.arb lib/l10n/app_en.arb lib/l10n/app_localizations*.dart
git commit -m "feat(l10n): add backup screen and dialog strings (IT + EN)"
```

---

### T3 — DB schema migration v1→v2

**Files:**
- Modify: `lib/data/database/app_database.dart`
- Modify: `lib/data/database/daos/app_settings_dao.dart`
- Modify: `lib/data/database/app_database.g.dart` (generated)
- Modify: `lib/data/repositories/drift_app_settings_repository.dart`
- Modify: `lib/domain/entities/app_settings_data.dart`
- Modify: `lib/domain/repositories/app_settings_repository.dart`
- Test: `test/data/database/app_database_migration_test.dart` (new)

- [ ] **Step 1: Add columns to `AppSettings` table**

In `lib/data/database/app_database.dart`, inside `class AppSettings extends Table`:

```dart
TextColumn get dropboxEmail => text().nullable()();
DateTimeColumn get lastBackupAt => dateTime().nullable()();
```

- [ ] **Step 2: Bump schema version + add migration**

In the same file:

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(appSettings, appSettings.dropboxEmail);
          await m.addColumn(appSettings, appSettings.lastBackupAt);
        }
      },
    );
```

- [ ] **Step 3: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` regenerated; analyze clean.

- [ ] **Step 4: Add fields to domain entity `AppSettingsData`**

In `lib/domain/entities/app_settings_data.dart`, add `dropboxEmail` (nullable String) and `lastBackupAt` (nullable DateTime). Update constructor, `copyWith`, `==`, `hashCode`. Remember the **P-4 lesson** (lessons.jsonl `p4-001`): `copyWith` cannot reset a nullable to null — for any caller that needs to clear `dropboxEmail`, use the full constructor.

- [ ] **Step 5: Update `AppSettingsRepository` interface and Drift impl**

Update mapping in `lib/data/repositories/drift_app_settings_repository.dart` to read/write the two new columns. Add a method:

```dart
Future<void> updateBackupState({
  required String? dropboxEmail,
  required DateTime? lastBackupAt,
});
```

This method writes both fields atomically (used after successful backup and after disconnect). Implement in both interface and Drift class. Companion construction in the impl must use `Value(dropboxEmail)` and `Value(lastBackupAt)` so explicit `null` actually overwrites.

- [ ] **Step 6: Add migration test**

Create `test/data/database/app_database_migration_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';

void main() {
  test('schema version is 2', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 2);
  });

  test('AppSettings has dropboxEmail and lastBackupAt columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Force createAll by issuing a read.
    final settings = await db.appSettingsDao.getOrCreate();
    expect(settings.dropboxEmail, isNull);
    expect(settings.lastBackupAt, isNull);
  });
}
```

- [ ] **Step 7: Update `FakeAppSettingsRepository`**

In `test/helpers/fake_app_settings_repository.dart` (if exists; otherwise add fields to whatever fake is used by P-4 settings tests). Mirror the new `updateBackupState` method.

- [ ] **Step 8: Run all tests**

Run: `flutter test`
Expected: all green, including existing settings tests (which may need updating to the new constructor — fix any compilation errors caused by the entity change).

- [ ] **Step 9: Commit**

```bash
git add lib/data/database/ lib/data/repositories/drift_app_settings_repository.dart lib/domain/entities/app_settings_data.dart lib/domain/repositories/app_settings_repository.dart test/
git commit -m "feat(db): bump schema to v2 with dropboxEmail and lastBackupAt on AppSettings"
```

---

### T4 — SyncLog domain layer (entity, interface, DAO, repository)

**Files:**
- Create: `lib/domain/entities/sync_log_entity.dart`
- Create: `lib/domain/repositories/sync_log_repository.dart`
- Create: `lib/data/database/daos/sync_log_dao.dart`
- Create: `lib/data/repositories/drift_sync_log_repository.dart`
- Modify: `lib/data/database/app_database.dart` (register new DAO)
- Test: `test/data/repositories/drift_sync_log_repository_test.dart`
- Test: `test/helpers/fake_sync_log_repository.dart` (new helper)

- [ ] **Step 1: Create `SyncLogEntity`**

```dart
// Copyright header...

enum SyncProvider { dropbox } // googleDrive, oneDrive added in v1.1

enum SyncOperation { backup, restore }

class SyncLogEntity {
  const SyncLogEntity({
    this.id,
    required this.timestamp,
    required this.provider,
    required this.operation,
    required this.success,
    this.errorMessage,
  });

  final int? id;
  final DateTime timestamp;
  final SyncProvider provider;
  final SyncOperation operation;
  final bool success;
  final String? errorMessage;
}
```

Include `==`, `hashCode`, `copyWith` in the standard project style.

- [ ] **Step 2: Create `SyncLogRepository` interface**

```dart
abstract class SyncLogRepository {
  Future<void> append(SyncLogEntity log);
  Future<List<SyncLogEntity>> getRecent({int limit = 50});
  Future<void> deleteAll();
}
```

- [ ] **Step 3: Create `SyncLogDao`**

```dart
@DriftAccessor(tables: [SyncLogs])
class SyncLogDao extends DatabaseAccessor<AppDatabase> with _$SyncLogDaoMixin {
  SyncLogDao(super.db);

  Future<int> insertSyncLog(SyncLogsCompanion entry) =>
      into(syncLogs).insert(entry);

  Future<List<SyncLog>> getRecent(int limit) => (select(syncLogs)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
        ..limit(limit))
      .get();

  Future<void> deleteAllLogs() => delete(syncLogs).go();
}
```

- [ ] **Step 4: Register DAO in `AppDatabase`**

In `lib/data/database/app_database.dart`, add `SyncLogDao` to the `daos:` list of the `@DriftDatabase` annotation. Add the import at the top. Run `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 5: Create `DriftSyncLogRepository`**

Mirror the pattern of `DriftCycleEntryRepository`. Sanitize `errorMessage` before persisting: redact substrings that look like passphrases or tokens. Pragma: keep error messages short and generic; always strip query strings and bearer tokens.

```dart
String _redactErrorMessage(String? msg) {
  if (msg == null) return '';
  // Truncate to 500 chars to bound size; redact known token patterns.
  var clean = msg.length > 500 ? '${msg.substring(0, 500)}…' : msg;
  clean = clean.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._\-]+'), 'Bearer [REDACTED]');
  clean = clean.replaceAll(RegExp(r'access_token=[^&\s]+'), 'access_token=[REDACTED]');
  clean = clean.replaceAll(RegExp(r'refresh_token=[^&\s]+'), 'refresh_token=[REDACTED]');
  return clean;
}
```

- [ ] **Step 6: Add `FakeSyncLogRepository` helper**

```dart
class FakeSyncLogRepository implements SyncLogRepository {
  final List<SyncLogEntity> appended = [];
  @override
  Future<void> append(SyncLogEntity log) async => appended.add(log);
  @override
  Future<List<SyncLogEntity>> getRecent({int limit = 50}) async =>
      appended.reversed.take(limit).toList();
  @override
  Future<void> deleteAll() async => appended.clear();
}
```

- [ ] **Step 7: Test the Drift implementation**

Round-trip test: append a `SyncLogEntity` → `getRecent(1)` returns it. `deleteAll` empties.

Redaction test: append a log with `errorMessage: "401 Bearer abc.def.ghi unauthorized"` → reading back returns `"401 Bearer [REDACTED] unauthorized"`.

- [ ] **Step 8: Run tests**

Run: `flutter test test/data/repositories/drift_sync_log_repository_test.dart`
Expected: all pass.

- [ ] **Step 9: Commit**

```bash
git add lib/domain/entities/sync_log_entity.dart lib/domain/repositories/sync_log_repository.dart lib/data/database/daos/sync_log_dao.dart lib/data/database/daos/sync_log_dao.g.dart lib/data/database/app_database.dart lib/data/database/app_database.g.dart lib/data/repositories/drift_sync_log_repository.dart test/
git commit -m "feat(data): add SyncLog domain layer with redacted error messages"
```

---

### T5 — `BackupSnapshot` + `DailyLogWithSymptoms` entities

**Files:**
- Create: `lib/domain/entities/daily_log_with_symptoms.dart`
- Create: `lib/domain/entities/backup_snapshot.dart`
- Modify: `lib/core/errors/metra_exception.dart` (add `BackupFormatException`)
- Test: `test/domain/entities/backup_snapshot_test.dart`

- [ ] **Step 1: Create `DailyLogWithSymptoms`**

```dart
import 'daily_log_entity.dart';
import 'pain_symptom_data.dart';

class DailyLogWithSymptoms {
  const DailyLogWithSymptoms({required this.log, required this.symptoms});
  final DailyLogEntity log;
  final List<PainSymptomData> symptoms;
}
```

- [ ] **Step 2: Add `BackupFormatException`**

In `lib/core/errors/metra_exception.dart`:

```dart
final class BackupFormatException extends MetraException {
  const BackupFormatException(super.message);
}
```

- [ ] **Step 3: Create `BackupSnapshot` with JSON ser/de**

```dart
import 'dart:convert';
import '../../core/errors/metra_exception.dart';
import 'daily_log_entity.dart';
import 'daily_log_with_symptoms.dart';
import 'flow_intensity.dart';
import 'pain_symptom_data.dart';
import 'pain_symptom_type.dart';

class BackupSnapshot {
  const BackupSnapshot({
    required this.version,
    required this.exportedAt,
    required this.logsWithSymptoms,
  });

  static const int currentVersion = 1;

  final int version;
  final DateTime exportedAt;
  final List<DailyLogWithSymptoms> logsWithSymptoms;

  Map<String, dynamic> toJson() => {
        'version': version,
        'exported_at': exportedAt.toUtc().toIso8601String(),
        'daily_logs': logsWithSymptoms.map((lws) {
          return {
            'date': lws.log.date.toUtc().toIso8601String(),
            'flow_intensity': lws.log.flowIntensity?.index,
            'spotting': lws.log.spotting,
            'other_discharge': lws.log.otherDischarge,
            'pain_enabled': lws.log.painEnabled,
            'pain_intensity': lws.log.painIntensity,
            'notes_enabled': lws.log.notesEnabled,
            'notes': lws.log.notes,
            'pain_symptoms': lws.symptoms
                .map((s) => {
                      'symptom_type': s.symptomType.index,
                      'custom_label': s.customLabel,
                    })
                .toList(),
          };
        }).toList(),
      };

  String encode() => jsonEncode(toJson());

  static BackupSnapshot decode(String json) {
    final dynamic raw;
    try {
      raw = jsonDecode(json);
    } catch (e) {
      throw const BackupFormatException('Invalid JSON');
    }
    if (raw is! Map<String, dynamic>) {
      throw const BackupFormatException('Top-level JSON must be an object');
    }
    final version = raw['version'];
    if (version is! int) {
      throw const BackupFormatException('Missing or invalid version');
    }
    if (version != currentVersion) {
      throw BackupFormatException('Unsupported snapshot version $version');
    }
    final exportedAtStr = raw['exported_at'];
    if (exportedAtStr is! String) {
      throw const BackupFormatException('Missing or invalid exported_at');
    }
    final exportedAt = DateTime.tryParse(exportedAtStr);
    if (exportedAt == null) {
      throw const BackupFormatException('exported_at is not ISO-8601');
    }
    final logsRaw = raw['daily_logs'];
    if (logsRaw is! List) {
      throw const BackupFormatException('daily_logs must be a list');
    }
    final logs = logsRaw.map(_parseLog).toList();
    return BackupSnapshot(
      version: version,
      exportedAt: exportedAt,
      logsWithSymptoms: logs,
    );
  }

  static DailyLogWithSymptoms _parseLog(dynamic e) {
    if (e is! Map<String, dynamic>) {
      throw const BackupFormatException('Each log must be an object');
    }
    // Defensive parsing — every field validated; throw BackupFormatException on miss.
    final date = DateTime.tryParse(e['date'] as String? ?? '');
    if (date == null) {
      throw const BackupFormatException('log.date missing or invalid');
    }
    final flowIdx = e['flow_intensity'] as int?;
    final flow = flowIdx == null
        ? null
        : (flowIdx >= 0 && flowIdx < FlowIntensity.values.length
            ? FlowIntensity.values[flowIdx]
            : throw const BackupFormatException('Invalid flow_intensity index'));
    final symptomsRaw = e['pain_symptoms'];
    if (symptomsRaw is! List) {
      throw const BackupFormatException('pain_symptoms must be a list');
    }
    final symptoms = symptomsRaw.map((s) {
      if (s is! Map<String, dynamic>) {
        throw const BackupFormatException('Each symptom must be an object');
      }
      final typeIdx = s['symptom_type'] as int?;
      if (typeIdx == null ||
          typeIdx < 0 ||
          typeIdx >= PainSymptomType.values.length) {
        throw const BackupFormatException('Invalid symptom_type index');
      }
      return PainSymptomData(
        symptomType: PainSymptomType.values[typeIdx],
        customLabel: s['custom_label'] as String?,
      );
    }).toList();
    final log = DailyLogEntity(
      date: date,
      flowIntensity: flow,
      spotting: e['spotting'] as bool? ?? false,
      otherDischarge: e['other_discharge'] as bool? ?? false,
      painEnabled: e['pain_enabled'] as bool? ?? false,
      painIntensity: e['pain_intensity'] as int?,
      notesEnabled: e['notes_enabled'] as bool? ?? false,
      notes: e['notes'] as String?,
    );
    return DailyLogWithSymptoms(log: log, symptoms: symptoms);
  }
}
```

- [ ] **Step 4: Write tests (TDD — write first, watch fail, then implement)**

Tests in `test/domain/entities/backup_snapshot_test.dart`:

```dart
void main() {
  group('BackupSnapshot encode/decode round-trip', () {
    test('empty snapshot', () {
      final s = BackupSnapshot(
        version: 1,
        exportedAt: DateTime.utc(2026, 4, 29),
        logsWithSymptoms: const [],
      );
      final decoded = BackupSnapshot.decode(s.encode());
      expect(decoded.version, 1);
      expect(decoded.exportedAt, s.exportedAt);
      expect(decoded.logsWithSymptoms, isEmpty);
    });

    test('snapshot with logs and symptoms', () {
      final log = DailyLogEntity(
        date: DateTime.utc(2026, 4, 29),
        flowIntensity: FlowIntensity.medium,
        painEnabled: true,
        painIntensity: 2,
      );
      final symptoms = [
        const PainSymptomData(symptomType: PainSymptomType.cramps),
        const PainSymptomData(
            symptomType: PainSymptomType.custom, customLabel: 'jaw'),
      ];
      final s = BackupSnapshot(
        version: 1,
        exportedAt: DateTime.utc(2026, 4, 29),
        logsWithSymptoms: [DailyLogWithSymptoms(log: log, symptoms: symptoms)],
      );
      final decoded = BackupSnapshot.decode(s.encode());
      expect(decoded.logsWithSymptoms, hasLength(1));
      expect(decoded.logsWithSymptoms.first.log, log);
      expect(decoded.logsWithSymptoms.first.symptoms, symptoms);
    });
  });

  group('BackupSnapshot.decode rejects invalid input', () {
    test('non-JSON', () {
      expect(() => BackupSnapshot.decode('not json'),
          throwsA(isA<BackupFormatException>()));
    });
    test('missing version', () {
      expect(() => BackupSnapshot.decode('{}'),
          throwsA(isA<BackupFormatException>()));
    });
    test('unsupported version', () {
      expect(() => BackupSnapshot.decode('{"version":99,"exported_at":"2026-04-29T00:00:00Z","daily_logs":[]}'),
          throwsA(isA<BackupFormatException>()));
    });
    test('invalid date', () {
      expect(() => BackupSnapshot.decode('{"version":1,"exported_at":"not-a-date","daily_logs":[]}'),
          throwsA(isA<BackupFormatException>()));
    });
    test('out-of-range flow_intensity', () {
      const bad = '{"version":1,"exported_at":"2026-04-29T00:00:00Z","daily_logs":[{"date":"2026-04-29T00:00:00Z","flow_intensity":99,"pain_symptoms":[]}]}';
      expect(() => BackupSnapshot.decode(bad),
          throwsA(isA<BackupFormatException>()));
    });
  });
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/domain/entities/backup_snapshot_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/backup_snapshot.dart lib/domain/entities/daily_log_with_symptoms.dart lib/core/errors/metra_exception.dart test/domain/entities/backup_snapshot_test.dart
git commit -m "feat(domain): add BackupSnapshot entity with versioned JSON envelope (TDD)"
```

---

### T6 — `BackupService`

**Files:**
- Create: `lib/data/services/backup/backup_service.dart`
- Test: `test/data/services/backup/backup_service_test.dart`

- [ ] **Step 1: Write test first (TDD)**

```dart
void main() {
  test('buildSnapshot pulls logs and their symptoms', () async {
    final repo = FakeDailyLogRepository();
    final log1 = DailyLogEntity(date: DateTime.utc(2026, 4, 28));
    final log2 = DailyLogEntity(date: DateTime.utc(2026, 4, 29), painEnabled: true);
    final symptoms2 = [
      const PainSymptomData(symptomType: PainSymptomType.cramps),
    ];
    repo.savedLogs.addAll([log1, log2]);
    repo.symptomsByDate[log2.date] = symptoms2;

    final svc = BackupService(repo);
    final snap = await svc.buildSnapshot();

    expect(snap.version, 1);
    expect(snap.logsWithSymptoms, hasLength(2));
    expect(snap.logsWithSymptoms[0].log, log1);
    expect(snap.logsWithSymptoms[0].symptoms, isEmpty);
    expect(snap.logsWithSymptoms[1].log, log2);
    expect(snap.logsWithSymptoms[1].symptoms, symptoms2);
  });
}
```

(Add `symptomsByDate` map to `FakeDailyLogRepository` if not already present, plus `getPainSymptoms` returning from the map.)

- [ ] **Step 2: Implement `BackupService`**

```dart
import '../../../domain/entities/backup_snapshot.dart';
import '../../../domain/entities/daily_log_with_symptoms.dart';
import '../../../domain/repositories/daily_log_repository.dart';

class BackupService {
  const BackupService(this._logRepo);
  final DailyLogRepository _logRepo;

  Future<BackupSnapshot> buildSnapshot() async {
    final logs = await _logRepo.getAllOrderedByDate();
    final logsWithSymptoms = <DailyLogWithSymptoms>[];
    for (final log in logs) {
      final symptoms = await _logRepo.getPainSymptoms(log.date);
      logsWithSymptoms.add(
        DailyLogWithSymptoms(log: log, symptoms: symptoms),
      );
    }
    return BackupSnapshot(
      version: BackupSnapshot.currentVersion,
      exportedAt: DateTime.now().toUtc(),
      logsWithSymptoms: logsWithSymptoms,
    );
  }
}
```

- [ ] **Step 3: Run tests**

Run: `flutter test test/data/services/backup/backup_service_test.dart`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add lib/data/services/backup/backup_service.dart test/data/services/backup/ test/helpers/fake_daily_log_repository.dart
git commit -m "feat(data): add BackupService that builds snapshot from DailyLogRepository (TDD)"
```

---

### T7 — `DropboxProvider`

**Files:**
- Create: `lib/data/services/backup/dropbox_provider.dart`
- Test: `test/data/services/backup/dropbox_provider_test.dart`

- [ ] **Step 1: Write the class skeleton**

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/metra_exception.dart';

class DropboxProvider {
  DropboxProvider({
    required String appKey,
    FlutterSecureStorage? storage,
    http.Client? client,
    Future<String> Function(String url, {required String callbackUrlScheme})?
        webAuth,
    Random? random,
  })  : _appKey = appKey,
        _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client(),
        _webAuth = webAuth ?? _defaultWebAuth,
        _random = random ?? Random.secure();

  static const _accessTokenKey = 'metra_dropbox_access_token_v1';
  static const _refreshTokenKey = 'metra_dropbox_refresh_token_v1';
  static const _appFolder = '/Apps/Métra';
  static const _filePrefix = 'metra_backup_';
  static const _fileSuffix = '.enc';
  static const _redirectUri = 'metra://oauth-callback';

  final String _appKey;
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final Future<String> Function(String url, {required String callbackUrlScheme})
      _webAuth;
  final Random _random;

  static Future<String> _defaultWebAuth(String url,
          {required String callbackUrlScheme}) =>
      FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
      );

  Future<bool> get isConnected async =>
      (await _storage.read(key: _accessTokenKey)) != null;

  Future<void> authorize() async {
    final verifier = _generateCodeVerifier();
    final challenge = _codeChallenge(verifier);
    final authUrl = Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': _appKey,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
    });
    final result =
        await _webAuth(authUrl.toString(), callbackUrlScheme: 'metra');
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) {
      throw const SyncException('OAuth callback missing code');
    }
    final tokenRes = await _client.post(
      Uri.https('api.dropbox.com', '/oauth2/token'),
      body: {
        'code': code,
        'grant_type': 'authorization_code',
        'client_id': _appKey,
        'code_verifier': verifier,
        'redirect_uri': _redirectUri,
      },
    );
    if (tokenRes.statusCode != 200) {
      throw SyncException('Token exchange failed: ${tokenRes.statusCode}');
    }
    final tokens = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    await _storage.write(
        key: _accessTokenKey, value: tokens['access_token'] as String);
    await _storage.write(
        key: _refreshTokenKey, value: tokens['refresh_token'] as String);
  }

  Future<String?> currentEmail() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) return null;
    final res = await _authenticatedPost(
      Uri.https('api.dropboxapi.com', '/2/users/get_current_account'),
      body: 'null',
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['email'] as String?);
  }

  Future<void> disconnect() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token != null) {
      // Best effort revoke; ignore errors.
      try {
        await _authenticatedPost(
          Uri.https('api.dropboxapi.com', '/2/auth/token/revoke'),
          body: 'null',
          headers: {'Content-Type': 'application/json'},
        );
      } catch (_) {}
    }
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> upload(Uint8List blob, String filename) async {
    final res = await _authenticatedPost(
      Uri.https('content.dropboxapi.com', '/2/files/upload'),
      bodyBytes: blob,
      headers: {
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({
          'path': '$_appFolder/$filename',
          'mode': 'add',
          'autorename': false,
          'mute': true,
        }),
      },
    );
    if (res.statusCode != 200) {
      throw SyncException('Upload failed: ${res.statusCode}');
    }
  }

  Future<Uint8List> download(String filename) async {
    final res = await _authenticatedPost(
      Uri.https('content.dropboxapi.com', '/2/files/download'),
      body: '',
      headers: {
        'Dropbox-API-Arg': jsonEncode({'path': '$_appFolder/$filename'}),
      },
    );
    if (res.statusCode != 200) {
      throw SyncException('Download failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  Future<List<String>> listFiles() async {
    final res = await _authenticatedPost(
      Uri.https('api.dropboxapi.com', '/2/files/list_folder'),
      body: jsonEncode({'path': _appFolder}),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 409) {
      // path/not_found — folder doesn't exist yet, treat as empty.
      return [];
    }
    if (res.statusCode != 200) {
      throw SyncException('List failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final entries = (data['entries'] as List<dynamic>);
    return entries
        .where((e) => e['.tag'] == 'file')
        .map((e) => e['name'] as String)
        .where((n) => n.startsWith(_filePrefix) && n.endsWith(_fileSuffix))
        .toList()
      ..sort((a, b) => b.compareTo(a)); // newest first
  }

  Future<void> deleteFile(String filename) async {
    final res = await _authenticatedPost(
      Uri.https('api.dropboxapi.com', '/2/files/delete_v2'),
      body: jsonEncode({'path': '$_appFolder/$filename'}),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw SyncException('Delete failed: ${res.statusCode}');
    }
  }

  // ---- internals ----

  Future<http.Response> _authenticatedPost(
    Uri uri, {
    Object? body,
    Uint8List? bodyBytes,
    Map<String, String>? headers,
  }) async {
    Future<http.Response> doPost(String token) async {
      final h = {
        'Authorization': 'Bearer $token',
        ...?headers,
      };
      if (bodyBytes != null) {
        return _client.post(uri, headers: h, body: bodyBytes);
      }
      return _client.post(uri, headers: h, body: body);
    }

    var token = await _storage.read(key: _accessTokenKey);
    if (token == null) throw const SyncException('Not connected');
    var res = await doPost(token);
    if (res.statusCode == 401) {
      token = await _refreshAccessToken();
      res = await doPost(token);
    }
    return res;
  }

  Future<String> _refreshAccessToken() async {
    final refresh = await _storage.read(key: _refreshTokenKey);
    if (refresh == null) throw const SyncException('No refresh token');
    final res = await _client.post(
      Uri.https('api.dropbox.com', '/oauth2/token'),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
        'client_id': _appKey,
      },
    );
    if (res.statusCode != 200) {
      throw const SyncException('Refresh failed');
    }
    final tokens = jsonDecode(res.body) as Map<String, dynamic>;
    final access = tokens['access_token'] as String;
    await _storage.write(key: _accessTokenKey, value: access);
    return access;
  }

  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    return List.generate(64, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier)).bytes;
    return base64Url
        .encode(digest)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }
}
```

- [ ] **Step 2: Add `crypto` to pubspec if not already present**

Run: `grep "^  crypto:" pubspec.yaml`
If not present, add `crypto: ^3.0.3` to dependencies and `flutter pub get`.

- [ ] **Step 3: Write tests with `MockClient`**

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra/data/services/backup/dropbox_provider.dart';

import '../../../helpers/in_memory_secure_storage.dart';

void main() {
  late InMemorySecureStorage storage;

  setUp(() {
    storage = InMemorySecureStorage();
  });

  test('upload sends bearer token and correct API arg', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'tok';
    final calls = <http.Request>[];
    final client = MockClient((req) async {
      calls.add(req as http.Request);
      return http.Response('{}', 200);
    });
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    await p.upload(Uint8List.fromList([1, 2, 3]), 'metra_backup_x.enc');
    expect(calls.single.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(calls.single.headers['Dropbox-API-Arg']!),
        containsPair('path', '/Apps/Métra/metra_backup_x.enc'));
    expect(calls.single.bodyBytes, [1, 2, 3]);
  });

  test('listFiles returns sorted backup filenames newest first', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'tok';
    final client = MockClient((req) async {
      return http.Response(
          jsonEncode({
            'entries': [
              {'.tag': 'file', 'name': 'metra_backup_2026-04-28T10:00:00Z.enc'},
              {'.tag': 'file', 'name': 'metra_backup_2026-04-29T10:00:00Z.enc'},
              {'.tag': 'file', 'name': 'unrelated.txt'},
            ],
          }),
          200);
    });
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    final files = await p.listFiles();
    expect(files, [
      'metra_backup_2026-04-29T10:00:00Z.enc',
      'metra_backup_2026-04-28T10:00:00Z.enc',
    ]);
  });

  test('listFiles returns [] on 409 path/not_found', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'tok';
    final client = MockClient((req) async => http.Response('{}', 409));
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    expect(await p.listFiles(), isEmpty);
  });

  test('401 triggers refresh and retry once', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'expired';
    storage.values['metra_dropbox_refresh_token_v1'] = 'r';
    var callCount = 0;
    final client = MockClient((req) async {
      callCount++;
      if (req.url.path == '/oauth2/token') {
        return http.Response(jsonEncode({'access_token': 'new'}), 200);
      }
      if (callCount == 1) return http.Response('{}', 401);
      return http.Response('{}', 200);
    });
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    await p.upload(Uint8List.fromList([1]), 'metra_backup_x.enc');
    expect(storage.values['metra_dropbox_access_token_v1'], 'new');
  });

  test('isConnected reflects token presence', () async {
    final p = DropboxProvider(appKey: 'key', storage: storage);
    expect(await p.isConnected, isFalse);
    storage.values['metra_dropbox_access_token_v1'] = 't';
    expect(await p.isConnected, isTrue);
  });

  test('disconnect clears storage', () async {
    storage.values['metra_dropbox_access_token_v1'] = 't';
    storage.values['metra_dropbox_refresh_token_v1'] = 'r';
    final client = MockClient((_) async => http.Response('{}', 200));
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    await p.disconnect();
    expect(storage.values, isEmpty);
  });
}
```

Create `test/helpers/in_memory_secure_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InMemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read({required String key, /* … */}) async => values[key];
  @override
  Future<void> write({required String key, required String? value, /* … */}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
  @override
  Future<void> delete({required String key, /* … */}) async => values.remove(key);
  // Implement remaining members of FlutterSecureStorage to throw UnimplementedError
  // or return reasonable defaults; only the three above are used in tests.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/data/services/backup/dropbox_provider_test.dart`
Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/backup/dropbox_provider.dart test/data/services/backup/dropbox_provider_test.dart test/helpers/in_memory_secure_storage.dart pubspec.yaml pubspec.lock
git commit -m "feat(data): add DropboxProvider with OAuth 2.0 PKCE and 401-refresh-retry"
```

---

### T8 — `SyncOrchestrator`

**Files:**
- Create: `lib/data/services/backup/sync_orchestrator.dart`
- Create: `test/helpers/fake_dropbox_provider.dart`
- Test: `test/data/services/backup/sync_orchestrator_test.dart`

- [ ] **Step 1: Define a minimal abstract interface for the provider**

To keep tests simple, extract the methods used by the orchestrator into an interface in the same file as `DropboxProvider`:

```dart
abstract class CloudBackupProvider {
  Future<void> upload(Uint8List blob, String filename);
  Future<Uint8List> download(String filename);
  Future<List<String>> listFiles();
  Future<void> deleteFile(String filename);
}

class DropboxProvider implements CloudBackupProvider {
  // existing impl
}
```

(This adds the interface; existing `DropboxProvider` already has these methods.)

- [ ] **Step 2: Create `FakeDropboxProvider`**

```dart
class FakeDropboxProvider implements CloudBackupProvider {
  final Map<String, Uint8List> files = {};
  bool failNextUpload = false;
  bool failNextDownload = false;
  @override
  Future<void> upload(Uint8List blob, String filename) async {
    if (failNextUpload) {
      failNextUpload = false;
      throw const SyncException('upload failed');
    }
    files[filename] = blob;
  }
  @override
  Future<Uint8List> download(String filename) async {
    if (failNextDownload) {
      failNextDownload = false;
      throw const SyncException('download failed');
    }
    final blob = files[filename];
    if (blob == null) throw const SyncException('not found');
    return blob;
  }
  @override
  Future<List<String>> listFiles() async => files.keys.toList()
    ..sort((a, b) => b.compareTo(a));
  @override
  Future<void> deleteFile(String filename) async => files.remove(filename);
}
```

- [ ] **Step 3: Implement `SyncOrchestrator`**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/errors/metra_exception.dart';
import '../../../domain/entities/sync_log_entity.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../domain/repositories/daily_log_repository.dart';
import '../../../domain/repositories/sync_log_repository.dart';
import '../../../domain/use_cases/recompute_cycle_entries.dart';
import '../encryption_service.dart';
import 'backup_service.dart';
import 'dropbox_provider.dart';

class SyncOrchestrator {
  const SyncOrchestrator({
    required BackupService backupService,
    required EncryptionService encryptionService,
    required CloudBackupProvider provider,
    required AppSettingsRepository settingsRepo,
    required SyncLogRepository syncLogRepo,
    required DailyLogRepository logRepo,
    required RecomputeCycleEntries recompute,
    required FlutterSecureStorage secureStorage,
    DateTime Function() now = _defaultNow,
  })  : _backupService = backupService,
        _encryption = encryptionService,
        _provider = provider,
        _settingsRepo = settingsRepo,
        _syncLogRepo = syncLogRepo,
        _logRepo = logRepo,
        _recompute = recompute,
        _secureStorage = secureStorage,
        _now = now;

  static const _passphraseKey = 'metra_backup_passphrase_v1';
  static DateTime _defaultNow() => DateTime.now().toUtc();

  final BackupService _backupService;
  final EncryptionService _encryption;
  final CloudBackupProvider _provider;
  final AppSettingsRepository _settingsRepo;
  final SyncLogRepository _syncLogRepo;
  final DailyLogRepository _logRepo;
  final RecomputeCycleEntries _recompute;
  final FlutterSecureStorage _secureStorage;
  final DateTime Function() _now;

  Future<void> backup() async {
    final ts = _now();
    String? errorMsg;
    try {
      final passphrase = await _secureStorage.read(key: _passphraseKey);
      if (passphrase == null) {
        throw const SyncException('No passphrase configured');
      }
      final snapshot = await _backupService.buildSnapshot();
      final bytes = Uint8List.fromList(utf8.encode(snapshot.encode()));
      final blob = await _encryption.encrypt(bytes, passphrase);
      final filename = _filenameFor(ts);
      await _provider.upload(blob, filename);
      // Verify by listing — must include our filename.
      final files = await _provider.listFiles();
      if (!files.contains(filename)) {
        throw const SyncException('Upload verification failed');
      }
      // Delete all other files.
      for (final f in files) {
        if (f != filename) {
          try {
            await _provider.deleteFile(f);
          } catch (_) {/* best-effort cleanup */}
        }
      }
      // Persist last-backup timestamp; preserve current dropboxEmail.
      final settings = await _settingsRepo.getOrCreate();
      await _settingsRepo.updateBackupState(
        dropboxEmail: settings.dropboxEmail,
        lastBackupAt: ts,
      );
      await _syncLogRepo.append(SyncLogEntity(
        timestamp: ts,
        provider: SyncProvider.dropbox,
        operation: SyncOperation.backup,
        success: true,
      ));
    } catch (e) {
      errorMsg = e.toString();
      await _syncLogRepo.append(SyncLogEntity(
        timestamp: ts,
        provider: SyncProvider.dropbox,
        operation: SyncOperation.backup,
        success: false,
        errorMessage: errorMsg,
      ));
      rethrow;
    }
  }

  Future<void> restore() async {
    final ts = _now();
    try {
      final passphrase = await _secureStorage.read(key: _passphraseKey);
      if (passphrase == null) {
        throw const SyncException('No passphrase configured');
      }
      final files = await _provider.listFiles();
      if (files.isEmpty) {
        throw const SyncException('No backup found');
      }
      final blob = await _provider.download(files.first);
      final bytes = await _encryption.decrypt(blob, passphrase);
      final snapshot =
          BackupSnapshot.decode(utf8.decode(bytes)); // throws BackupFormatException
      final logs = snapshot.logsWithSymptoms.map((e) => e.log).toList();
      final symptoms = {
        for (final lws in snapshot.logsWithSymptoms)
          lws.log.date: lws.symptoms,
      };
      await _logRepo.deleteAllAndReplace(logs, symptoms);
      await _recompute();
      await _syncLogRepo.append(SyncLogEntity(
        timestamp: ts,
        provider: SyncProvider.dropbox,
        operation: SyncOperation.restore,
        success: true,
      ));
    } catch (e) {
      await _syncLogRepo.append(SyncLogEntity(
        timestamp: ts,
        provider: SyncProvider.dropbox,
        operation: SyncOperation.restore,
        success: false,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  String _filenameFor(DateTime t) {
    final iso = t
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first; // YYYYMMDDTHHMMSS
    return 'metra_backup_${iso}Z.enc';
  }
}
```

(Add `import` for `BackupSnapshot` from `domain/entities/backup_snapshot.dart`.)

- [ ] **Step 4: Write tests with all fakes**

Test cases:
1. `backup()` happy path: blob uploaded, `lastBackupAt` updated, `SyncLog(success: true)` appended.
2. `backup()` deletes older files: pre-populate fake with 3 files, after backup only the new one remains.
3. `backup()` upload failure: old files untouched, `SyncLog(success: false)` appended, exception rethrown.
4. `backup()` no passphrase: throws `SyncException`, `SyncLog(success: false)` appended.
5. `restore()` happy path: data replaced, `RecomputeCycleEntries` invoked, success log.
6. `restore()` wrong passphrase: `EncryptionException` from real `EncryptionService` (use real one with mismatched passphrase), data NOT mutated, `SyncLog(success: false)` appended.
7. `restore()` empty Dropbox: throws `SyncException`, no data mutation.

Use a real `EncryptionService` (it's already tested) — round-trip with a fixture passphrase. Use `FakeDailyLogRepository`, `FakeAppSettingsRepository`, `FakeSyncLogRepository`, `FakeDropboxProvider`, `InMemorySecureStorage`, and a fake `RecomputeCycleEntries` that records call count.

Inject `now: () => DateTime.utc(2026, 4, 29, 10)` into the orchestrator for deterministic filenames.

- [ ] **Step 5: Run tests**

Run: `flutter test test/data/services/backup/sync_orchestrator_test.dart`
Expected: all 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/data/services/backup/sync_orchestrator.dart lib/data/services/backup/dropbox_provider.dart test/
git commit -m "feat(data): add SyncOrchestrator coordinating BackupService + DropboxProvider + EncryptionService (TDD)"
```

---

### T9 — `BackupData` use case

**Files:**
- Create: `lib/domain/use_cases/backup_data.dart`
- Test: `test/domain/use_cases/backup_data_test.dart`

- [ ] **Step 1: Create the use case (thin wrapper)**

Note: this use case needs to import `SyncOrchestrator` from `data/services/backup/`. To keep `domain/` pure, define a minimal abstract `BackupRunner` interface in the same file as the use case, with `Future<void> backup()`. `SyncOrchestrator` implements it (add `implements BackupRunner` to the class).

```dart
import '../../core/errors/metra_exception.dart';
import '../../core/utils/result.dart';

abstract class BackupRunner {
  Future<void> backup();
}

class BackupData {
  const BackupData(this._runner);
  final BackupRunner _runner;

  Future<Result<void>> call() async {
    try {
      await _runner.backup();
      return const Ok(null);
    } on MetraException catch (e) {
      return Err(e);
    } catch (e) {
      return Err(SyncException('Backup failed: $e'));
    }
  }
}
```

Add `implements BackupRunner` to `SyncOrchestrator` — already has the `backup()` method.

- [ ] **Step 2: Test with a `FakeBackupRunner`**

```dart
class _FakeRunner implements BackupRunner {
  Object? error;
  bool called = false;
  @override
  Future<void> backup() async {
    called = true;
    if (error != null) throw error!;
  }
}

void main() {
  test('returns Ok on success', () async {
    final r = _FakeRunner();
    expect(await BackupData(r)(), isA<Ok<void>>());
    expect(r.called, isTrue);
  });
  test('returns Err on MetraException', () async {
    final r = _FakeRunner()..error = const SyncException('x');
    expect((await BackupData(r)()) is Err, isTrue);
  });
  test('wraps unknown error in SyncException Err', () async {
    final r = _FakeRunner()..error = StateError('x');
    final result = await BackupData(r)();
    expect(result, isA<Err<void>>());
    expect((result as Err<void>).error, isA<SyncException>());
  });
}
```

- [ ] **Step 3: Run tests**

Run: `flutter test test/domain/use_cases/backup_data_test.dart`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/use_cases/backup_data.dart lib/data/services/backup/sync_orchestrator.dart test/domain/use_cases/backup_data_test.dart
git commit -m "feat(domain): add BackupData use case wrapping SyncOrchestrator (TDD)"
```

---

### T10 — `RestoreData` use case

**Files:**
- Create: `lib/domain/use_cases/restore_data.dart`
- Test: `test/domain/use_cases/restore_data_test.dart`

- [ ] **Step 1: Create use case**

Reuse the abstract approach from T9 but with `RestoreRunner` interface (or a single `BackupRunner` with both methods — preferred). Update `BackupRunner` to:

```dart
abstract class BackupRunner {
  Future<void> backup();
  Future<void> restore();
}
```

Update `SyncOrchestrator` to satisfy this (already does).

```dart
class RestoreData {
  const RestoreData(this._runner);
  final BackupRunner _runner;

  Future<Result<void>> call() async {
    try {
      await _runner.restore();
      return const Ok(null);
    } on MetraException catch (e) {
      return Err(e);
    } catch (e) {
      return Err(SyncException('Restore failed: $e'));
    }
  }
}
```

- [ ] **Step 2: Tests**

Mirror T9's tests, plus a test that `EncryptionException` (from wrong passphrase) flows through as `Err`.

- [ ] **Step 3: Run tests + commit**

```bash
git add lib/domain/use_cases/restore_data.dart test/domain/use_cases/restore_data_test.dart
git commit -m "feat(domain): add RestoreData use case (TDD)"
```

---

### T11 — Provider wiring

**Files:**
- Modify: `lib/providers/repository_providers.dart`
- Modify: `lib/providers/use_case_providers.dart`
- Create: `lib/providers/backup_providers.dart`

- [ ] **Step 1: Add `syncLogRepositoryProvider` to `repository_providers.dart`**

The existing database provider is `databaseProvider` (in `lib/providers/database_provider.dart`):

```dart
final syncLogRepositoryProvider = FutureProvider<SyncLogRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return DriftSyncLogRepository(SyncLogDao(db));
});
```

- [ ] **Step 2: Make existing `_secureStorageProvider` public**

In `lib/providers/encryption_provider.dart`, rename the private `_secureStorageProvider` to `secureStorageProvider` (drop the leading underscore). Update the reference in `keyManagementServiceProvider` accordingly. This is the canonical secure-storage provider — backup providers reuse it (no duplication).

- [ ] **Step 3: Create `lib/providers/backup_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/backup/backup_service.dart';
import '../data/services/backup/dropbox_provider.dart';
import '../data/services/backup/sync_orchestrator.dart';
import '../data/services/encryption_service.dart';
import '../domain/use_cases/backup_data.dart';
import '../domain/use_cases/restore_data.dart';
import 'encryption_provider.dart';
import 'repository_providers.dart';
import 'use_case_providers.dart';

const _dropboxAppKey = String.fromEnvironment('DROPBOX_APP_KEY');

final encryptionServiceProvider = Provider<EncryptionService>(
  (_) => EncryptionService(),
);

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  return BackupService(logRepo);
});

final dropboxProviderProvider = Provider<DropboxProvider>((ref) {
  return DropboxProvider(
    appKey: _dropboxAppKey,
    storage: ref.watch(secureStorageProvider),
  );
});

final syncOrchestratorProvider = FutureProvider<SyncOrchestrator>((ref) async {
  final backupService = await ref.watch(backupServiceProvider.future);
  final settingsRepo = await ref.watch(appSettingsRepositoryProvider.future);
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final syncLogRepo = await ref.watch(syncLogRepositoryProvider.future);
  final recompute = await ref.watch(recomputeCycleEntriesProvider.future);
  return SyncOrchestrator(
    backupService: backupService,
    encryptionService: ref.watch(encryptionServiceProvider),
    provider: ref.watch(dropboxProviderProvider),
    settingsRepo: settingsRepo,
    syncLogRepo: syncLogRepo,
    logRepo: logRepo,
    recompute: recompute,
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final backupDataProvider = FutureProvider<BackupData>((ref) async {
  final orch = await ref.watch(syncOrchestratorProvider.future);
  return BackupData(orch);
});

final restoreDataProvider = FutureProvider<RestoreData>((ref) async {
  final orch = await ref.watch(syncOrchestratorProvider.future);
  return RestoreData(orch);
});
```

- [ ] **Step 4: Verify analyze**

Run: `flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/
git commit -m "feat(providers): register backup providers (DropboxProvider, SyncOrchestrator, BackupData, RestoreData)"
```

---

### T12 — `BackupNotifier`

**Files:**
- Create: `lib/features/backup/state/backup_state.dart`
- Create: `lib/features/backup/state/backup_notifier.dart`
- Test: `test/features/backup/state/backup_notifier_test.dart`

- [ ] **Step 1: Define `BackupState` sealed class**

```dart
sealed class BackupState {
  const BackupState();
}

class BackupNotConnected extends BackupState {
  const BackupNotConnected();
}

class BackupConnected extends BackupState {
  const BackupConnected({required this.email, this.lastBackupAt});
  final String email;
  final DateTime? lastBackupAt;
}

class BackupRunning extends BackupState {
  const BackupRunning(this.operation);
  final BackupOperation operation;
}

enum BackupOperation { connecting, backingUp, restoring, disconnecting }

class BackupErrorState extends BackupState {
  const BackupErrorState(this.message);
  final String message;
}
```

- [ ] **Step 2: Implement `BackupNotifier`**

```dart
class BackupNotifier extends AsyncNotifier<BackupState> {
  static const _passphraseKey = 'metra_backup_passphrase_v1';

  @override
  Future<BackupState> build() async {
    final settings = await ref.watch(appSettingsRepositoryProvider.future);
    final settingsData = await settings.getOrCreate();
    if (settingsData.dropboxEmail == null) {
      return const BackupNotConnected();
    }
    return BackupConnected(
      email: settingsData.dropboxEmail!,
      lastBackupAt: settingsData.lastBackupAt,
    );
  }

  Future<void> connect() async {
    state = const AsyncData(BackupRunning(BackupOperation.connecting));
    try {
      final dropbox = ref.read(dropboxProviderProvider);
      await dropbox.authorize();
      final email = await dropbox.currentEmail();
      if (email == null) throw const SyncException('Could not fetch account');
      final settings = await ref.read(appSettingsRepositoryProvider.future);
      final current = await settings.getOrCreate();
      await settings.updateBackupState(
        dropboxEmail: email,
        lastBackupAt: current.lastBackupAt,
      );
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncData(BackupErrorState(e.toString()));
    }
  }

  Future<void> disconnect() async {
    state = const AsyncData(BackupRunning(BackupOperation.disconnecting));
    final dropbox = ref.read(dropboxProviderProvider);
    await dropbox.disconnect();
    final settings = await ref.read(appSettingsRepositoryProvider.future);
    await settings.updateBackupState(
      dropboxEmail: null,
      lastBackupAt: null,
    );
    // Also clear passphrase — disconnecting means user is leaving the feature.
    await ref.read(secureStorageProvider).delete(key: _passphraseKey);
    ref.invalidateSelf();
  }

  Future<void> backupWithPassphrase(String passphrase) async {
    await ref.read(secureStorageProvider).write(
          key: _passphraseKey,
          value: passphrase,
        );
    await _runBackup();
  }

  Future<void> backupSilent() async {
    final pass =
        await ref.read(secureStorageProvider).read(key: _passphraseKey);
    if (pass == null) return; // first backup not done yet — UX prompts
    await _runBackup();
  }

  Future<void> _runBackup() async {
    state = const AsyncData(BackupRunning(BackupOperation.backingUp));
    try {
      final uc = await ref.read(backupDataProvider.future);
      final result = await uc();
      switch (result) {
        case Ok():
          ref.invalidateSelf();
        case Err(:final error):
          state = AsyncData(BackupErrorState(error.message));
      }
    } catch (e) {
      state = AsyncData(BackupErrorState(e.toString()));
    }
  }

  Future<void> restore() async {
    state = const AsyncData(BackupRunning(BackupOperation.restoring));
    try {
      final uc = await ref.read(restoreDataProvider.future);
      final result = await uc();
      switch (result) {
        case Ok():
          ref.invalidateSelf();
        case Err(:final error):
          state = AsyncData(BackupErrorState(error.message));
      }
    } catch (e) {
      state = AsyncData(BackupErrorState(e.toString()));
    }
  }
}

final backupNotifierProvider =
    AsyncNotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
```

- [ ] **Step 3: Tests**

Use `ProviderContainer` with overrides for `appSettingsRepositoryProvider`, `dropboxProviderProvider`, `backupDataProvider`, `restoreDataProvider`, `secureStorageProvider`.

Test cases:
1. Initial state when `dropboxEmail == null` → `BackupNotConnected`.
2. Initial state when connected → `BackupConnected(email, lastBackupAt)`.
3. `backupWithPassphrase` stores passphrase then calls `BackupData`.
4. `backupSilent` skips when no passphrase in storage.
5. `restore` Ok → invalidate self.
6. `restore` Err → state becomes `BackupErrorState`.
7. `disconnect` clears email, lastBackupAt, and passphrase.

- [ ] **Step 4: Run + commit**

```bash
git add lib/features/backup/state/ test/features/backup/state/
git commit -m "feat(backup): add BackupNotifier with connect/disconnect/backup/restore actions"
```

---

### T13 — Settings screen wiring

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/app.dart` (add `/backup` route)
- Test: `test/features/settings/settings_screen_test.dart` (update existing)

- [ ] **Step 1: Add `/backup` route**

In `lib/app.dart` `GoRouter` config, add a new route:

```dart
GoRoute(
  path: '/backup',
  builder: (_, __) => const BackupScreen(),
),
```

(`BackupScreen` will exist after T14, but the route declaration can land here without yet importing it — leave the import as a forward reference. If the build fails, defer this step to T14.)

**Better approach:** add the route as part of T14 (which creates `BackupScreen`). For T13, only wire the Settings tap.

- [ ] **Step 2: Replace `_showComingSoon` call**

In `lib/features/settings/settings_screen.dart` line 179, change:

```dart
onTap: () => _showComingSoon(context, l10n),
```

to:

```dart
onTap: () => context.push('/backup'),
```

The trailing widget (`_ChevronTrailing`) currently shows "not configured". Update it to reflect the live state — for now, leave as-is; the BackupScreen itself shows the connection state. (Or watch `backupNotifierProvider` here; pick the simpler path: leave the trailing static for v1.0, update only on next polish pass.)

- [ ] **Step 3: Update settings_screen_test if needed**

The existing test for the backup row tap may assert on `_showComingSoon` text — update to assert on navigation. Use a `MockGoRouter` or wrap in a router that records pushes.

- [ ] **Step 4: Run + commit**

```bash
git add lib/features/settings/settings_screen.dart test/features/settings/settings_screen_test.dart
git commit -m "feat(settings): wire backup row to /backup route"
```

---

### T14 — `BackupScreen` UI + widget tests

**Files:**
- Create: `lib/features/backup/backup_screen.dart`
- Create: `lib/features/backup/widgets/passphrase_dialog.dart`
- Modify: `lib/app.dart` (register `/backup` route)
- Test: `test/features/backup/backup_screen_test.dart`

- [ ] **Step 1: Implement `BackupScreen`**

Single `ConsumerWidget` reading `backupNotifierProvider`. Branch on the state:

- `BackupNotConnected` — body, "Connect Dropbox" button → `notifier.connect()`.
- `BackupRunning` — loading + label by operation.
- `BackupConnected` — email, lastBackupAt formatted via `intl`, "Back up now" button (opens passphrase dialog if passphrase not stored, else direct `backupSilent`), "Restore" button (confirm dialog, then `restore`), "Disconnect" link (confirm dialog, then `disconnect`).
- `BackupErrorState` — inline error + "Try again".

Apply lessons:
- **p4-004**: Capture `ScaffoldMessenger.of(context)` before any async gap.
- **p4-005**: Theme color reads use direct field access, not ternary on the `MetraColors` types.
- **p4-006**: Wrap fire-and-forget destructive flows in `.catchError` to surface errors via SnackBar.

Use `ButtonPrimary`, `ButtonGhost`, `ListRowMetra`, `_GroupCard` patterns from existing settings_screen.

- [ ] **Step 2: Implement `PassphraseDialog`**

Modal with two password fields (passphrase + confirm), inline validation. Button enabled only when:
- `passphrase.length >= 8`
- `passphrase == confirm`

On submit, call `notifier.backupWithPassphrase(passphrase)`. Close dialog. Show SnackBar with progress feedback if needed.

- [ ] **Step 3: Register `/backup` route in `app.dart`**

```dart
GoRoute(
  path: '/backup',
  builder: (_, __) => const BackupScreen(),
),
```

- [ ] **Step 4: Widget tests**

Test cases:
1. Renders not-connected body with "Connect Dropbox" button.
2. Renders connected body with email and "Back up now" + "Restore" buttons.
3. Tapping "Back up now" with no stored passphrase opens passphrase dialog.
4. Passphrase dialog shows mismatch error when fields differ.
5. Passphrase dialog disables submit when shorter than 8 chars.
6. Tapping "Restore" shows confirm dialog before invoking notifier.
7. Tapping "Disconnect" shows confirm dialog before invoking notifier.
8. Error state is wrapped in `Semantics(liveRegion: true)` (per existing P-1 pattern).

Stub `backupNotifierProvider` with a test notifier exposing the required state transitions.

Use `tester.view.physicalSize = const Size(800, 4000)` (per **p4-002**) to force lazy children to render.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/backup/`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/backup/ lib/app.dart test/features/backup/
git commit -m "feat(backup): add BackupScreen with passphrase dialog and a11y live region"
```

---

### T15 — App-level auto-sync on app open

**Files:**
- Modify: `lib/app.dart` (add `_autoSyncIfConfigured` in `initState`)

- [ ] **Step 1: Add silent auto-sync**

In `MetraApp.initState` (already a `ConsumerStatefulWidget` per P-3), add:

```dart
@override
void initState() {
  super.initState();
  // Existing init…
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_autoSyncIfConfigured());
  });
}

Future<void> _autoSyncIfConfigured() async {
  try {
    final settings = await ref.read(appSettingsRepositoryProvider.future);
    final data = await settings.getOrCreate();
    if (data.dropboxEmail == null) return; // not connected
    final pass =
        await ref.read(secureStorageProvider).read(key: 'metra_backup_passphrase_v1');
    if (pass == null) return; // no passphrase stored
    final uc = await ref.read(backupDataProvider.future);
    await uc();
  } catch (_) {
    // Silent — user can retry from BackupScreen.
  }
}
```

- [ ] **Step 2: Verify analyze + manual smoke (in Settings → Backup → Connect → Back up now → restart app → see auto-sync log in DB)**

Run: `flutter analyze && flutter test`
Expected: clean. Smoke verification documented but not automated (requires real Dropbox).

- [ ] **Step 3: Commit**

```bash
git add lib/app.dart
git commit -m "feat(app): silent auto-sync on app open when Dropbox configured"
```

---

### T16 — Security gate + appsec review + version bump + tag

**Files:**
- Create: `docs/security/p6-appsec-review.md`
- Modify: `pubspec.yaml` (version bump)

- [ ] **Step 1: Security review (appsec-engineer agent or manual checklist)**

Verify each item:
- [ ] Passphrase never logged: grep `lib/` for `passphrase` and confirm no `print`/`debugPrint`.
- [ ] Tokens never logged: grep `lib/` for `access_token`, `refresh_token`.
- [ ] `SyncLog.errorMessage` redacts bearer tokens (test it with a synthesized error message).
- [ ] Dropbox app key not in source: `grep -r "key=" lib/` returns no hardcoded values.
- [ ] No raw stack traces shown to user (all errors go through `_localizeError`-style helpers).
- [ ] Encryption uses `AesGcm.with256bits` and Argon2id (existing — verify no regression).
- [ ] Snapshot JSON contains zero `AppSettings` data.
- [ ] Schema migration v1→v2 runs cleanly: integration test with a v1 DB file.
- [ ] OAuth scope is `files.content.write files.content.read` (app folder only).

Document findings in `docs/security/p6-appsec-review.md`. Zero Critical/High findings is the gate.

- [ ] **Step 2: Run `dart format --set-exit-if-changed .`**

Expected: exits 0.

- [ ] **Step 3: Run `flutter analyze`**

Expected: exits 0.

- [ ] **Step 4: Run `flutter test --coverage`**

Expected: all green; ≥80% coverage on new files in `lib/data/services/backup/`, `lib/domain/use_cases/backup_data.dart`, `lib/domain/use_cases/restore_data.dart`, `lib/features/backup/`.

- [ ] **Step 5: Bump version**

In `pubspec.yaml`: `version: 0.1.0-p6+6` (continuing existing convention `+5` was P-5a).

- [ ] **Step 6: Commit + tag**

```bash
git add pubspec.yaml docs/security/p6-appsec-review.md
git commit -m "chore(release): appsec review P-6, bump version to 0.1.0-p6+6"
git tag v0.1.0-p6
```

---

## Resolved decisions

- **Provider scope:** Dropbox only for v1.0. Google Drive + OneDrive deferred to v1.1. Decision logged in `docs/decisions/2026-04-29-p6-dropbox-only.md`.
- **Passphrase storage:** Stored in `flutter_secure_storage` after first backup (deviates from CLAUDE.md §11 in favour of auto-sync UX; passphrase is still user-chosen and required for cross-device restore).
- **Auto-sync:** Silent on app open when both `dropboxEmail` and stored passphrase are present. Failures are silent.
- **File strategy:** Single timestamped `.enc` file in `/Apps/Métra/`. Upload new → verify → delete old. New file uses UTC compact ISO-8601 (`YYYYMMDDTHHMMSSZ`).
- **Backup content:** `DailyLogs` with embedded `PainSymptoms` per log. Excludes `SymptomTemplates` (no domain layer yet — deferred to v1.1), `CycleEntries`, `AppSettings`, `SyncLogs`.
- **Conflict resolution:** Latest backup wins (CLAUDE.md §16).
- **Dropbox app key:** Compile-time `--dart-define=DROPBOX_APP_KEY=...`; never in source.

---

## Definition of Done

- [ ] `flutter analyze` clean, `dart format` clean.
- [ ] All tests pass; ≥80% coverage on new `lib/` files.
- [ ] Schema migration from v1 → v2 runs cleanly on existing DB (verified via test or manual DB file).
- [ ] Manual round-trip on Android device: connect → back up → reinstall app → restore → data identical.
- [ ] Wrong passphrase shows localised error, data unchanged.
- [ ] Auto-sync on app open works silently when passphrase is stored; fails silently when not.
- [ ] `SyncLogs` table populated correctly after each operation.
- [ ] `SyncLog.errorMessage` contains zero passphrase, token, or raw URL substrings (redaction verified).
- [ ] No health data in any backup metadata (Dropbox file path uses generic name only).
- [ ] `appsec-engineer` review: zero Critical/High findings.
- [ ] Tag `v0.1.0-p6` pushed.
