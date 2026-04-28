# P-0b Encrypted Database + EncryptionService — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Drift+SQLCipher local database (schema + DAOs), the domain entity models, key management via `flutter_secure_storage`, the cloud-backup `EncryptionService` (AES-256-GCM + Argon2id), Riverpod providers for the data layer, and full unit tests.

**Architecture context:** P-0a delivered the 4-tab navigation shell. P-0b adds the data layer below it. The layering rule is strict: `features/ → repositories/ → data/` — no feature imports from `data/database/` directly. The `domain/` layer stays pure (no Flutter, no Drift imports). EncryptionService is for cloud backup blob encryption only; the DB itself is encrypted via SQLCipher pragma key.

**Tech stack additions:**
- `drift ^2.18.0` — ORM (uses `package:drift/native.dart` directly, no `drift_flutter` needed)
- `path_provider ^2.1.0` — resolves application documents directory
- `sqlcipher_flutter_libs ^0.5.4` — SQLCipher native libs replacing sqlite3
- `cryptography ^2.7.0` — AES-256-GCM + Argon2id
- `flutter_secure_storage ^9.2.2` — DB key in iOS Keychain / Android Keystore
- `drift_dev ^2.18.0` (dev) — code generation
- `sqlite3 ^2.4.4` (dev, test-only) — in-memory DB for unit tests without SQLCipher

**DoD for this plan:** `flutter test` passes (all new + existing tests), `flutter analyze` clean, DB key is generated on first run and retrievable from secure storage, `AppDatabase` opens and performs round-trip CRUD via DAOs.

**Working directory:** `/home/paolo/Sviluppo/metra`
**Flutter binary:** `/home/paolo/Sviluppo/flutter/bin/flutter`
**PATH needed:** `export PATH="/home/paolo/Sviluppo/flutter/bin:$PATH"`

---

## File structure created by this plan

```
lib/
  core/
    errors/
      metra_exception.dart        # already exists — add DatabaseException, CryptoException
  domain/
    entities/
      flow_intensity.dart         # FlowIntensity enum
      pain_symptom_type.dart      # PainSymptomType enum
      daily_log_entity.dart       # Pure Dart DailyLogEntity
      cycle_entry_entity.dart     # Pure Dart CycleEntryEntity
  data/
    database/
      app_database.dart           # @DriftDatabase, tables, migrations
      app_database.g.dart         # generated (do not edit)
      daos/
        daily_log_dao.dart        # DailyLogDao
        daily_log_dao.g.dart      # generated
        cycle_entry_dao.dart      # CycleEntryDao
        cycle_entry_dao.g.dart    # generated
        app_settings_dao.dart     # AppSettingsDao
        app_settings_dao.g.dart   # generated
    services/
      key_management_service.dart # generate/retrieve DB key from secure storage
      encryption_service.dart     # AES-256-GCM + Argon2id
  providers/
    database_provider.dart        # databaseProvider (AsyncNotifier)
    encryption_provider.dart      # encryptionServiceProvider, keyManagementProvider
test/
  data/
    database/
      app_database_test.dart      # CRUD round-trip for each DAO (in-memory)
    services/
      encryption_service_test.dart # encrypt→decrypt, IV uniqueness, wrong key
```

**Not in this plan:**
- Repositories (`lib/data/repositories/`) → P-1 (data entry feature)
- Use cases (`lib/domain/use_cases/`) → P-1
- UI wiring to real data → P-1

---

## Architectural constraints

1. **Domain entities are pure Dart.** `lib/domain/entities/*.dart` may not import `package:drift/`, `package:flutter/`, or any `data/` package. They are plain Dart classes (can use `freezed` if already in deps, otherwise hand-written).

2. **SQLCipher key handling.** The DB encryption key is a 32-byte random key generated once on first launch and stored as a hex string in `flutter_secure_storage`. It is never logged, never serialised in plaintext, never passed to non-Dart code as a String beyond the single `PRAGMA key` call at DB open time.

3. **EncryptionService is for backup blobs, not for the DB.** The service takes a user-supplied passphrase and data bytes, and returns an encrypted blob (random IV prepended). It does not touch the DB key.

4. **Tests use in-memory SQLite, not SQLCipher.** Adding `sqlite3 ^2.4.4` as a dev dependency allows `NativeDatabase.memory()` in tests without requiring the SQLCipher native libs. The `sqlcipher_flutter_libs` dep is only for the app target.

5. **License headers.** Every new `.dart` source file must carry the GPL-3.0 header (see existing files for the exact format).

---

## Task 1: Uncomment P-0b dependencies in pubspec.yaml

**Files:** `pubspec.yaml`

**Context:** P-0a left the P-0b deps commented out. This task uncomments them and adds the required dev deps.

- [ ] **Step 1: Edit pubspec.yaml**

In the `dependencies:` section, uncomment these lines (removing the `#` prefix):

```yaml
  # Local DB
  drift: ^2.18.0
  path_provider: ^2.1.0

  # DB encryption
  sqlcipher_flutter_libs: ^0.5.4

  # Cryptography
  cryptography: ^2.7.0

  # Keychain
  flutter_secure_storage: ^9.2.2
```

**Note:** Do NOT add `drift_flutter` — this plan uses `package:drift/native.dart` directly with `NativeDatabase.createInBackground`, so `drift_flutter` is not needed.

In the `dev_dependencies:` section, add:

```yaml
  drift_dev: ^2.18.0
  sqlite3: ^2.4.4
```

- [ ] **Step 2: Run `flutter pub get`**

```bash
export PATH="/home/paolo/Sviluppo/flutter/bin:$PATH"
flutter pub get
```

Expected: resolves without conflicts. If version conflicts arise, adjust the upper bound (e.g., `^2.19.0`) to match what pub resolves.

- [ ] **Step 3: Verify no analyzer errors on existing files**

```bash
flutter analyze lib/app.dart lib/main.dart lib/router/app_router.dart
```

Expected: no errors.

---

## Task 2: Domain entities (pure Dart)

**Files:**
- `lib/domain/entities/flow_intensity.dart`
- `lib/domain/entities/pain_symptom_type.dart`
- `lib/domain/entities/daily_log_entity.dart`
- `lib/domain/entities/cycle_entry_entity.dart`

**Context:** Domain entities are pure Dart classes that have zero dependency on Flutter, Drift, or any `data/` layer. They are the canonical in-memory representation used by use cases, UI, and tests. The Drift `Companion` classes are separate (generated); converters map between them.

- [ ] **Step 1: Create `lib/domain/entities/flow_intensity.dart`**

```dart
// [GPL-3.0 header]
enum FlowIntensity { none, spotting, light, medium, heavy, veryHeavy }
```

- [ ] **Step 2: Create `lib/domain/entities/pain_symptom_type.dart`**

```dart
// [GPL-3.0 header]
enum PainSymptomType { cramps, backPain, headache, migraine, bloating, custom }
```

- [ ] **Step 3: Create `lib/domain/entities/daily_log_entity.dart`**

Fields (all nullable except `date`):
- `final DateTime date` — the calendar day (time is midnight UTC)
- `final FlowIntensity? flowIntensity`
- `final bool spotting`
- `final bool painEnabled`
- `final int? painIntensity` — 0–10 scale, only meaningful if `painEnabled`
- `final bool notesEnabled`
- `final String? notes`

Include a `copyWith` method. No `fromJson`/`toJson` (that belongs in the data layer).

- [ ] **Step 4: Create `lib/domain/entities/cycle_entry_entity.dart`**

Fields:
- `final int id`
- `final DateTime startDate`
- `final DateTime? endDate`
- `final int? cycleLength` — days from this start to next start
- `final int? periodLength` — days of actual flow

Include a `copyWith` method.

- [ ] **Step 5: Verify — `flutter analyze lib/domain/`**

Expected: clean. If any issue, fix it before proceeding.

---

## Task 3: Drift schema + DAOs (all source files first, then one build_runner run)

**Files:**
- `lib/data/database/app_database.dart`
- `lib/data/database/app_database.g.dart` (generated)
- `lib/data/database/daos/daily_log_dao.dart` + `.g.dart` (generated)
- `lib/data/database/daos/cycle_entry_dao.dart` + `.g.dart` (generated)
- `lib/data/database/daos/app_settings_dao.dart` + `.g.dart` (generated)

**Context:** Drift uses `@DriftDatabase` to declare the schema and references DAO classes in the annotation. The DAO files must exist on disk BEFORE `build_runner` is invoked — otherwise the generator cannot resolve the DAO class references and will fail. The correct order is: write ALL source files (schema + all DAO stubs), run build_runner EXACTLY ONCE, then verify.

DAOs use Drift's `@DriftAccessor` annotation. All reactive queries return `Stream<T>`; mutation methods return `Future<void>` or `Future<int>`.

SQLCipher encryption is applied via a `PRAGMA key` in the `LazyDatabase` setup callback. Schema version starts at 1; migrations are a no-op for now.

- [ ] **Step 1: Create `lib/data/database/app_database.dart`**

Define these tables and reference the DAO classes (they will exist as stubs by Step 4):

**`DailyLogs`** (one row per calendar day):
```dart
class DailyLogs extends Table {
  DateTimeColumn get date => dateTime()();
  IntColumn get flowIntensity => integer().nullable()();  // FlowIntensity.index
  BoolColumn get spotting => boolean().withDefault(const Constant(false))();
  BoolColumn get painEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get painIntensity => integer().nullable()();
  BoolColumn get notesEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {date};
}
```

**`PainSymptoms`** (many-to-one with DailyLogs):
```dart
class PainSymptoms extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get dailyLogDate => dateTime().references(DailyLogs, #date)();
  IntColumn get symptomType => integer()();  // PainSymptomType.index
  TextColumn get customLabel => text().nullable()();
}
```

**`CycleEntries`**:
```dart
class CycleEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get cycleLength => integer().nullable()();
  IntColumn get periodLength => integer().nullable()();
}
```

**`SymptomTemplates`**:
```dart
class SymptomTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
```

**`AppSettings`** (singleton — always id=1):
```dart
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get languageCode => text().withDefault(const Constant('it'))();
  BoolColumn get darkMode => boolean().nullable()();  // null = system
  BoolColumn get painEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get notesEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get notificationDaysBefore => integer().withDefault(const Constant(2))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(false))();
}
```

**`SyncLogs`**:
```dart
class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get provider => text()();   // 'google_drive' | 'dropbox' | 'onedrive'
  TextColumn get operation => text()();  // 'backup' | 'restore'
  BoolColumn get success => boolean()();
  TextColumn get errorMessage => text().nullable()();
}
```

**`AppDatabase` class** (include all 3 DAOs in the annotation from the start):

```dart
@DriftDatabase(
  tables: [DailyLogs, PainSymptoms, CycleEntries, SymptomTemplates, AppSettings, SyncLogs],
  daos: [DailyLogDao, CycleEntryDao, AppSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) => m.createAll());

  static QueryExecutor openConnection(String dbPath, String hexKey) {
    return LazyDatabase(() async {
      final file = File(dbPath);
      return NativeDatabase.createInBackground(file, setup: (rawDb) {
        // SQLCipher: unlock with raw hex key (not passphrase)
        rawDb.execute("PRAGMA key = \"x'$hexKey'\"");
      });
    });
  }
}
```

Imports needed: `dart:io`, `package:drift/drift.dart`, `package:drift/native.dart`, and the three DAO import paths.

- [ ] **Step 2: Create `lib/data/database/daos/daily_log_dao.dart`**

```dart
@DriftAccessor(tables: [DailyLogs, PainSymptoms])
class DailyLogDao extends DatabaseAccessor<AppDatabase> with _$DailyLogDaoMixin {
  DailyLogDao(super.db);

  Stream<DailyLog?> watchDay(DateTime date) =>
      (select(dailyLogs)..where((t) => t.date.equals(date))).watchSingleOrNull();

  Stream<List<DailyLog>> watchMonth(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (select(dailyLogs)
          ..where((t) => t.date.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Future<void> upsertDailyLog(DailyLogsCompanion entry) =>
      into(dailyLogs).insertOnConflictUpdate(entry);

  Future<void> deleteDailyLog(DateTime date) =>
      (delete(dailyLogs)..where((t) => t.date.equals(date))).go();

  Future<List<PainSymptom>> getPainSymptoms(DateTime date) =>
      (select(painSymptoms)..where((t) => t.dailyLogDate.equals(date))).get();

  Future<void> replacePainSymptoms(DateTime date, List<PainSymptomsCompanion> symptoms) =>
      transaction(() async {
        await (delete(painSymptoms)..where((t) => t.dailyLogDate.equals(date))).go();
        await batch((b) => b.insertAll(painSymptoms, symptoms));
      });
}
```

- [ ] **Step 3: Create `lib/data/database/daos/cycle_entry_dao.dart`**

```dart
@DriftAccessor(tables: [CycleEntries])
class CycleEntryDao extends DatabaseAccessor<AppDatabase> with _$CycleEntryDaoMixin {
  CycleEntryDao(super.db);

  Stream<List<CycleEntry>> watchAllOrderedByStart() =>
      (select(cycleEntries)..orderBy([(t) => OrderingTerm.desc(t.startDate)])).watch();

  Future<List<CycleEntry>> getRecentCycles(int n) =>
      (select(cycleEntries)
            ..orderBy([(t) => OrderingTerm.desc(t.startDate)])
            ..limit(n))
          .get();

  Future<int> insertCycleEntry(CycleEntriesCompanion entry) =>
      into(cycleEntries).insert(entry);

  Future<void> updateCycleEntry(CycleEntriesCompanion entry) =>
      (update(cycleEntries)..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteCycleEntry(int id) =>
      (delete(cycleEntries)..where((t) => t.id.equals(id))).go();
}
```

- [ ] **Step 4: Create `lib/data/database/daos/app_settings_dao.dart`**

```dart
@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase> with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  Stream<AppSetting?> watchSettings() =>
      (select(appSettings)..where((t) => t.id.equals(1))).watchSingleOrNull();

  Future<AppSetting> getOrCreateSettings() async {
    final existing = await (select(appSettings)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (existing != null) return existing;
    await into(appSettings).insert(const AppSettingsCompanion(id: Value(1)));
    return (select(appSettings)..where((t) => t.id.equals(1))).getSingle();
  }

  Future<void> updateSettings(AppSettingsCompanion settings) =>
      (update(appSettings)..where((t) => t.id.equals(1))).write(settings);
}
```

- [ ] **Step 5: Run code generation (ONCE — all source files now exist)**

```bash
export PATH="/home/paolo/Sviluppo/flutter/bin:$PATH"
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: generates `app_database.g.dart` and all three `daos/*.g.dart` files in one pass. The `.g.dart` files are committed to the repo (checked-in generated code — not gitignored).

If build_runner reports a resolution error about missing DAO classes, verify that all three DAO files were created before running this step.

- [ ] **Step 6: SQLCipher pragma smoke-test**

Verify the SQLCipher pragma syntax works with the actual Drift+SQLCipher integration before wiring it to production. In a temporary test script or inline in the test suite, open a file-based `NativeDatabase` with the setup callback and immediately execute a simple query. If this step succeeds, the `PRAGMA key = "x'...'"` syntax is confirmed working with this version of `sqlcipher_flutter_libs`. If it fails, investigate: (a) key format (hex vs passphrase), (b) whether `sqlcipher_flutter_libs` version requires `PRAGMA cipher_compatibility`, (c) whether the `setup` callback is the correct hook point. Do not proceed to Task 7 until this is confirmed.

- [ ] **Step 7: Verify — `flutter analyze lib/data/database/`**

Expected: clean.

---

## Task 5: Key management service

**Files:**
- `lib/data/services/key_management_service.dart`

**Context:** The DB encryption key is a 32-byte random key generated on the very first app launch. It is stored in `flutter_secure_storage` under a fixed key name. All subsequent launches read it from the keychain. The key is stored and retrieved as a 64-character hex string (lowercase). It is **never** logged or exposed beyond the single `PRAGMA key` call.

- [ ] **Step 1: Create `lib/data/services/key_management_service.dart`**

```dart
// [GPL-3.0 header]
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManagementService {
  static const _dbKeyStorageKey = 'metra_db_encryption_key_v1';

  final FlutterSecureStorage _storage;

  const KeyManagementService(this._storage);

  /// Returns the DB key as a 64-char hex string.
  /// Generates and persists it on first call.
  Future<String> getOrCreateDatabaseKey() async {
    final existing = await _storage.read(key: _dbKeyStorageKey);
    if (existing != null && existing.length == 64) return existing;

    final key = _generateHexKey();
    await _storage.write(key: _dbKeyStorageKey, value: key);
    return key;
  }

  /// Deletes the DB key from secure storage.
  /// Call only during full data wipe / factory reset — data becomes irrecoverable.
  Future<void> deleteDatabaseKey() => _storage.delete(key: _dbKeyStorageKey);

  String _generateHexKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
```

- [ ] **Step 2: Verify — `flutter analyze lib/data/services/key_management_service.dart`**

Expected: clean.

---

## Task 6: EncryptionService (cloud backup blobs)

**Files:**
- `lib/data/services/encryption_service.dart`

**Context:** The `EncryptionService` is used exclusively for cloud backup blobs. It never touches the DB key. The user provides a passphrase; Argon2id derives a 256-bit key from it; AES-256-GCM encrypts the data. The blob format is `[16-byte salt][12-byte IV][ciphertext]`. A wrong passphrase causes GCM authentication to fail and throws a `CryptoException`.

**Security parameters (CLAUDE.md §11):**
- Argon2id: memory 64 MB, iterations 3, parallelism 4
- AES-256-GCM: 256-bit key, random 96-bit IV per call
- Salt: 128 bits (16 bytes), random per encryption call

- [ ] **Step 1: Create `lib/data/services/encryption_service.dart`**

```dart
// [GPL-3.0 header]
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../core/errors/metra_exception.dart';

class EncryptionService {
  static const _saltLength = 16;
  static const _ivLength = 12;

  static final _argon2id = Argon2id(
    memory: 65536,    // 64 MB
    iterations: 3,
    parallelism: 4,
    hashLength: 32,
  );

  static final _aesGcm = AesGcm.with256bits();

  final Random _random;

  EncryptionService({Random? random}) : _random = random ?? Random.secure();

  /// Encrypts [plaintext] with a key derived from [passphrase].
  /// Returns blob: [16-byte salt][12-byte nonce][ciphertext+MAC].
  Future<Uint8List> encrypt(Uint8List plaintext, String passphrase) async {
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);

    final secretKey = await _deriveKey(passphrase, salt);
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: iv,
    );

    final result = Uint8List(_saltLength + _ivLength + secretBox.cipherText.length + secretBox.mac.bytes.length);
    result.setRange(0, _saltLength, salt);
    result.setRange(_saltLength, _saltLength + _ivLength, iv);
    result.setRange(_saltLength + _ivLength, result.length - secretBox.mac.bytes.length, secretBox.cipherText);
    result.setRange(result.length - secretBox.mac.bytes.length, result.length, secretBox.mac.bytes);

    return result;
  }

  /// Decrypts a blob produced by [encrypt].
  /// Throws [CryptoException] if the passphrase is wrong or the blob is corrupted.
  Future<Uint8List> decrypt(Uint8List blob, String passphrase) async {
    const macLength = 16; // AES-GCM MAC is always 16 bytes
    if (blob.length < _saltLength + _ivLength + macLength) {
      throw const CryptoException('Blob too short');
    }

    final salt = blob.sublist(0, _saltLength);
    final iv = blob.sublist(_saltLength, _saltLength + _ivLength);
    final cipherTextWithMac = blob.sublist(_saltLength + _ivLength);
    final cipherText = cipherTextWithMac.sublist(0, cipherTextWithMac.length - macLength);
    final mac = cipherTextWithMac.sublist(cipherTextWithMac.length - macLength);

    final secretKey = await _deriveKey(passphrase, salt);
    try {
      final secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(mac));
      final plaintext = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError {
      throw const CryptoException('Decryption failed: wrong passphrase or corrupted data');
    }
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) async {
    final newSecretKey = await _argon2id.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    return newSecretKey;
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));
}
```

- [ ] **Step 2: Extend `metra_exception.dart` with `CryptoException`**

Open `lib/core/errors/metra_exception.dart` and add:

```dart
class CryptoException extends MetraException {
  const CryptoException(super.message);
}
```

(assuming `MetraException` is already there from P-0a — verify before adding)

- [ ] **Step 3: Verify — `flutter analyze lib/data/services/encryption_service.dart`**

Expected: clean.

---

## Task 7: Riverpod providers for data layer

**Files:**
- `lib/providers/database_provider.dart`
- `lib/providers/encryption_provider.dart`

**Context:** The database must be initialised asynchronously (key retrieval from secure storage + file path resolution). Use an `AsyncNotifierProvider` so the rest of the app can react to the initialisation state. The app startup in `main.dart` must await DB readiness before rendering (or show a loading splash).

- [ ] **Step 1: Create `lib/providers/database_provider.dart`**

```dart
// [GPL-3.0 header]
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';  // see note below
import '../data/database/app_database.dart';
import '../data/services/key_management_service.dart';
import 'encryption_provider.dart';

/// Provides the initialised AppDatabase.
/// Consumers must handle the loading/error states from AsyncValue.
final databaseProvider = AsyncNotifierProvider<DatabaseNotifier, AppDatabase>(
  DatabaseNotifier.new,
);

class DatabaseNotifier extends AsyncNotifier<AppDatabase> {
  @override
  Future<AppDatabase> build() async {
    final keyService = ref.read(keyManagementServiceProvider);
    final hexKey = await keyService.getOrCreateDatabaseKey();

    final dbPath = kIsWeb
        ? ':memory:'
        : await _resolveDatabasePath('metra.db');

    final executor = AppDatabase.openConnection(dbPath, hexKey);
    final db = AppDatabase(executor);

    // Dispose when the provider is disposed
    ref.onDispose(db.close);
    return db;
  }

  Future<String> _resolveDatabasePath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}$filename';
  }
}
```

**Note on `path_provider`:** This package is listed as an explicit dependency (`path_provider: ^2.1.0`) added in Task 1.

- [ ] **Step 2: Create `lib/providers/encryption_provider.dart`**

```dart
// [GPL-3.0 header]
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/services/encryption_service.dart';
import '../data/services/key_management_service.dart';

final _secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final keyManagementServiceProvider = Provider<KeyManagementService>(
  (ref) => KeyManagementService(ref.read(_secureStorageProvider)),
);

final encryptionServiceProvider = Provider<EncryptionService>(
  (_) => EncryptionService(),
);
```

- [ ] **Step 3: Wire ProviderScope in `main.dart`**

`main.dart` already has `runApp(const MetraApp())`. The `MetraApp` already wraps in `ProviderScope`. No structural change needed — providers are lazy by default and will initialise when first read.

Add an `AsyncValue` guard in the root widget if desired (optional for P-0b; can be a bare splash in P-1 when the calendar screen reads from the DB).

- [ ] **Step 4: Verify — `flutter analyze lib/providers/`**

Expected: clean.

---

## Task 8: Tests

**Files:**
- `test/data/database/app_database_test.dart`
- `test/data/services/encryption_service_test.dart`

**Context:** Tests run against an **in-memory** SQLite database (not SQLCipher) using `NativeDatabase.memory()`. This avoids requiring native SQLCipher libs in the test environment. The `EncryptionService` tests are pure Dart (no Flutter, no native code).

- [ ] **Step 1: Create `test/data/services/encryption_service_test.dart`**

Tests to cover (minimum — add more edge cases as appropriate):

1. **Round-trip:** encrypt plaintext with passphrase → decrypt → matches original.
2. **IV uniqueness:** encrypt same plaintext+passphrase twice → blobs differ (random salt+IV).
3. **Wrong passphrase throws CryptoException:** encrypt with passphrase A, decrypt with passphrase B → `CryptoException`.
4. **Truncated blob throws CryptoException:** pass a blob shorter than `16 + 12 + 16` bytes → `CryptoException`.
5. **Empty plaintext round-trip:** encrypt empty `Uint8List(0)` → decrypt → returns empty.
6. **Unicode passphrase:** passphrase with non-ASCII characters (e.g. `'pässwörð'`) round-trips correctly.

Use `test` package (available via `flutter_test`). No mocking needed — `EncryptionService` has no external dependencies.

- [ ] **Step 2: Create `test/data/database/app_database_test.dart`**

Use `NativeDatabase.memory()` for an in-memory DB:

```dart
late AppDatabase db;
setUp(() {
  db = AppDatabase(NativeDatabase.memory());
});
tearDown(() => db.close());
```

Tests to cover:

1. **DailyLog upsert + watch:** insert a `DailyLogsCompanion`, read it back, verify fields.
2. **DailyLog upsert idempotent:** upsert same date twice with different flow → second wins.
3. **PainSymptoms replace:** insert 2 symptoms, replace with 1 → only 1 remains.
4. **CycleEntry insert + getRecent:** insert 5 entries, `getRecentCycles(3)` returns 3 latest.
5. **AppSettings getOrCreate singleton:** calling twice returns same row, not two rows.
6. **AppSettings update:** update `languageCode` → reads back updated value.

- [ ] **Step 3: Create `test/data/database/sqlcipher_integration_test.dart`**

This test verifies that the SQLCipher `PRAGMA key` path actually works end-to-end with a real file on disk (not in-memory). It must run in an environment where `sqlcipher_flutter_libs` is available (i.e., on Android/iOS device, not on the Linux host test runner). Mark it with a skip guard so it is skipped in CI unit tests but can be run manually.

```dart
// Integration test — skip on non-device environments
@TestOn('android || ios')
library;

// Test 1: Same-key access succeeds
//   - Open a temp file DB with hexKey A
//   - Insert a row into DailyLogs
//   - Close the DB
//   - Re-open the same file with hexKey A
//   - Read the row — must succeed and match

// Test 2: Wrong-key access fails
//   - Open a temp file DB with hexKey A, insert a row, close
//   - Re-open the same file with hexKey B (different random key)
//   - Attempt any query — must throw (SQLite error / "file is not a database")

// Test 3: No-key access fails
//   - Open a temp file DB with hexKey A, insert a row, close
//   - Re-open without the setup callback (plain NativeDatabase)
//   - Attempt any query — must throw
```

Use `dart:io` `Directory.systemTemp` for the temp file, and clean up in `tearDown`.

- [ ] **Step 4: Run all tests**

```bash
export PATH="/home/paolo/Sviluppo/flutter/bin:$PATH"
flutter test
```

Expected: all new tests + all P-0a tests pass. The SQLCipher integration test will be skipped on the Linux host (correct). If any test fails, fix before proceeding.

- [ ] **Step 5: Run flutter analyze (full project)**

```bash
flutter analyze
```

Expected: zero issues.

---

## Definition of Done

- [ ] `flutter pub get` completes without version conflicts (no `drift_flutter` — only `drift` + `path_provider`).
- [ ] `flutter pub run build_runner build` generates all `.g.dart` files cleanly in a single pass.
- [ ] `flutter analyze` — zero issues across the full project.
- [ ] `flutter test` — all unit/widget tests pass (new + existing P-0a tests); SQLCipher integration test skipped on Linux host.
- [ ] `lib/domain/entities/` contains 4 pure Dart files with zero Drift/Flutter imports.
- [ ] `lib/data/database/app_database.dart` defines 6 tables + 3 DAOs.
- [ ] `lib/data/services/key_management_service.dart` generates and stores a 64-char hex key.
- [ ] `lib/data/services/encryption_service.dart` passes all 6 unit tests.
- [ ] SQLCipher pragma smoke-test (Task 3, Step 6) confirmed working.
- [ ] `test/data/database/sqlcipher_integration_test.dart` exists with same-key/wrong-key/no-key test cases.
- [ ] No `debugPrint` or `print` of sensitive data anywhere in new files.
- [ ] Every new `.dart` file carries the GPL-3.0 license header.

---

## Notes for implementer

**build_runner and generated files:**
- Run `build_runner build` after any schema change.
- The `.g.dart` files are **committed** (not gitignored).
- If build_runner hangs, kill with Ctrl-C and retry with `--delete-conflicting-outputs`.

**SQLCipher vs sqlite3 in tests:**
- `sqlcipher_flutter_libs` overrides the native sqlite3 binary at runtime. In tests (`flutter test`), this binary may or may not be available depending on the test runner.
- If tests fail with "Failed to load dynamic library", add `sqlite3: ^2.4.4` to dev_dependencies and use `NativeDatabase.memory()` (which uses the `sqlite3` dart package's bundled binary).

**path_provider resolution:**
- `path_provider: ^2.1.0` is listed as an explicit direct dependency in pubspec.yaml. The `drift_flutter` package is NOT used — the plan uses `package:drift/native.dart` directly.

**Argon2id on low-end devices:**
- CLAUDE.md §11 specifies memory=64MB, iterations=3, parallelism=4. This is for backup blob encryption only (called infrequently). The DB key is random (never Argon2id-derived), so app startup has no KDF cost.

**`kIsWeb` guard in DatabaseNotifier:**
- Métra targets Android + iOS only. The `kIsWeb` guard in `databaseProvider` is a compile-time constant that dead-codes the `:memory:` path in production builds. This is correct defensive practice, not a "web support" promise.
