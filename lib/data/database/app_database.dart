// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import 'daos/app_settings_dao.dart';
import 'daos/cycle_entry_dao.dart';
import 'daos/daily_log_dao.dart';
import 'daos/sync_log_dao.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// One row per calendar day. The primary key is the date (UTC midnight).
///
/// Schema v4 (P-B): added `flowType` column (FlowType.index: 0=assente,
/// 1=mestruazioni, 2=spotting). The legacy `spotting` boolean column is
/// retained for migration provenance but is no longer authoritative — the
/// application reads `flowType` instead. `flowIntensity` is meaningful only
/// when `flowType == FlowType.mestruazioni`.
class DailyLogs extends Table {
  DateTimeColumn get date => dateTime()();
  IntColumn get flowType => integer().nullable()(); // FlowType.index
  IntColumn get flowIntensity => integer().nullable()(); // FlowIntensity.index
  BoolColumn get spotting => boolean().withDefault(const Constant(false))();
  BoolColumn get otherDischarge =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get painEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get painIntensity => integer().nullable()();
  BoolColumn get notesEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {date};
}

/// Many-to-one with [DailyLogs]. Stores individual pain/symptom entries for
/// a given day.
class PainSymptoms extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get dailyLogDate =>
      dateTime().references(DailyLogs, #date, onDelete: KeyAction.cascade)();
  IntColumn get symptomType => integer()(); // PainSymptomType.index
  TextColumn get customLabel => text().nullable()();
}

/// Derived from [DailyLogs] and persisted for query performance.
/// Recomputed on every mutation.
class CycleEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get cycleLength => integer().nullable()();
  IntColumn get periodLength => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {startDate},
      ];
}

/// User-defined custom pain/symptom types.
class SymptomTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Singleton settings row — always id = 1.
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get languageCode => text().withDefault(const Constant('it'))();
  BoolColumn get darkMode => boolean().nullable()(); // null = follow system
  BoolColumn get painEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get notesEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get notificationDaysBefore =>
      integer().withDefault(const Constant(2))();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get dropboxEmail => text().nullable()();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  /// User-declared average cycle length (days), stored during onboarding.
  ///
  /// Used as a fallback for [CyclePredictionService] when fewer than 3
  /// measured cycles exist. Null means the user skipped the question or
  /// no onboarding data was recorded.
  IntColumn get declaredCycleLength => integer().nullable()();

  /// Time of day for the prediction notification, in minutes from midnight.
  ///
  /// Range: [0, 1439]. Default 540 = 09:00 local time.
  IntColumn get notificationTimeMinutes =>
      integer().withDefault(const Constant(540))();

  /// First day of week preference. Stored as [FirstDayOfWeekSetting.index].
  ///
  /// 0 = system (follow locale), 1 = sunday, 2 = monday.
  /// Default 0 (system) — matches DB column default and enum index.
  IntColumn get firstDayOfWeek => integer().withDefault(const Constant(0))();

  /// UTC timestamp of the most recent DailyLog or PainSymptom write.
  ///
  /// Set by [DriftDailyLogRepository] after every successful write (saveDailyLog,
  /// deleteDailyLog, replacePainSymptoms, deleteAll, deleteAllAndReplace,
  /// upsertAllLogs). Reset to [lastBackupAt] by [SyncOrchestrator.restore()]
  /// after a successful restore so that the next cold-start backup does not
  /// re-upload data that was just restored. Null means no log or symptom has
  /// ever been written on this device (or the app was installed before schema v9).
  ///
  /// Not included in [AppSettingsCompanion] built by [DriftAppSettingsRepository._toCompanion]
  /// — it is owned exclusively by [DriftAppSettingsRepository.updateLastDataWriteAt].
  DateTimeColumn get lastLogOrSymptomWriteAt => dateTime().nullable()();

  /// Whether cloud backup is temporarily suspended by the user.
  ///
  /// When true, [SyncOrchestrator] skips the backup step on cold-start even
  /// if [lastLogOrSymptomWriteAt] is newer than [lastBackupAt].
  /// Default false — backup is active by default.
  BoolColumn get backupSuspended =>
      boolean().withDefault(const Constant(false))();
}

/// Local-only audit trail of cloud backup/restore operations.
/// Never included in the backup blob.
class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get provider =>
      text()(); // 'google_drive' | 'dropbox' | 'onedrive'
  TextColumn get operation => text()(); // 'backup' | 'restore'
  BoolColumn get success => boolean()();
  TextColumn get errorMessage => text().nullable()();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    DailyLogs,
    PainSymptoms,
    CycleEntries,
    SymptomTemplates,
    AppSettings,
    SyncLogs,
  ],
  daos: [DailyLogDao, CycleEntryDao, AppSettingsDao, SyncLogDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(appSettings, appSettings.dropboxEmail);
            await m.addColumn(appSettings, appSettings.lastBackupAt);
          }
          if (from < 3) {
            await m.addColumn(
              appSettings,
              appSettings.onboardingCompleted,
            );
          }
          if (from < 4) {
            // P-B Flow domain migration
            //
            // Adds `flow_type` column to daily_logs and reshapes existing data:
            //
            // FlowIntensity index changes (drop `none`):
            //   v3: none(0), light(1), medium(2), heavy(3), veryHeavy(4)
            //   v4: light(0), medium(1), heavy(2), veryHeavy(3)
            //
            // FlowType derivation (new column):
            //   spotting=1                       → flowType=2 (spotting)
            //   flow_intensity v3=0 (none)       → flowType=0 (assente)
            //   flow_intensity v3 in [1..4]      → flowType=1 (mestruazioni)
            //   neither                          → flowType=NULL (not logged)
            //
            // Order matters: read from old fields, write new ones. We do this
            // in raw SQL to avoid any dependence on the (already-evolved) Drift
            // generated columns.
            await m.addColumn(dailyLogs, dailyLogs.flowType);

            // Spotting → flowType=2; clear intensity (mutually exclusive).
            await customStatement(
              "UPDATE daily_logs SET flow_type = 2, flow_intensity = NULL "
              "WHERE spotting = 1",
            );

            // FlowIntensity v3=0 (none) AND not spotting → flowType=0 (assente),
            // clear intensity (no longer a valid value in v4).
            await customStatement(
              "UPDATE daily_logs SET flow_type = 0, flow_intensity = NULL "
              "WHERE spotting = 0 AND flow_intensity = 0",
            );

            // FlowIntensity v3 in [1..4] AND not spotting → flowType=1
            // (mestruazioni), shift intensity index down by 1.
            await customStatement(
              "UPDATE daily_logs "
              "SET flow_type = 1, flow_intensity = flow_intensity - 1 "
              "WHERE spotting = 0 AND flow_intensity BETWEEN 1 AND 4",
            );
          }
          if (from < 5) {
            // Strategy B: store user-declared average cycle length separately
            // from the measured gaps computed by RecomputeCycleEntries.
            await m.addColumn(
              appSettings,
              appSettings.declaredCycleLength,
            );
          }
          if (from < 6) {
            // Drop PainSymptomType.cramps (was index 0). Existing cramps rows
            // are preserved as custom-label rows; remaining indices shift down
            // by one to match the new enum.
            //
            // Old: cramps=0, backPain=1, headache=2, migraine=3, bloating=4,
            //      custom=5, fatigue=6, nausea=7, breastTenderness=8.
            // New: backPain=0, headache=1, migraine=2, bloating=3, custom=4,
            //      fatigue=5, nausea=6, breastTenderness=7.
            //
            // The transient sentinel (-1) prevents the just-converted rows
            // from being shifted again by the BETWEEN 1 AND 8 update.
            await customStatement(
              "UPDATE pain_symptoms "
              "SET symptom_type = -1, custom_label = 'Crampi' "
              "WHERE symptom_type = 0",
            );
            await customStatement(
              "UPDATE pain_symptoms "
              "SET symptom_type = symptom_type - 1 "
              "WHERE symptom_type BETWEEN 1 AND 8",
            );
            await customStatement(
              "UPDATE pain_symptoms "
              "SET symptom_type = 4 "
              "WHERE symptom_type = -1",
            );
          }
          if (from < 7) {
            // Add configurable notification time-of-day column.
            // Purely additive; existing rows receive the default (540 = 09:00).
            await m.addColumn(
              appSettings,
              appSettings.notificationTimeMinutes,
            );
          }
          if (from < 8) {
            // Add first-day-of-week preference column.
            // Purely additive; existing rows receive the default (0 = system).
            await m.addColumn(
              appSettings,
              appSettings.firstDayOfWeek,
            );
          }
          if (from < 9) {
            // Add UTC timestamp tracking the most recent DailyLog/PainSymptom
            // write. Nullable — null means no write has occurred on this device
            // since installation (or device was on schema v8). No backfill: the
            // skip-backup guard treats null as "nothing new" (FR-13).
            await m.addColumn(
              appSettings,
              appSettings.lastLogOrSymptomWriteAt,
            );
          }
          if (from < 10) {
            // Three-step migration wrapped in a single transaction so that any
            // failure rolls back all steps atomically (NFR-01).
            //
            // Step 1: Deduplicate cycle_entries — keep the row with the smallest
            //   id for each start_date. Real installations should have no
            //   duplicates, but the constraint cannot be enforced before this
            //   clean-up runs.
            //
            // Step 2: Rebuild cycle_entries with UNIQUE(start_date) via
            //   alterTable — Drift's TableMigration picks up the uniqueKeys
            //   override automatically and recreates the table with the
            //   constraint (SQLite does not support ADD CONSTRAINT after the
            //   fact, so a table rebuild is required).
            //
            // Step 3: Add backup_suspended column to app_settings with
            //   default false. Existing rows receive false via the column
            //   default; no backfill is needed.
            //
            // Note: customStatement is intentional here (Step 1) — this
            // migration block is explicitly excluded from NFR-14 purity checks.
            await transaction(() async {
              // Step 1: dedup — keep only the row with the smallest id per
              // start_date value.
              await customStatement(
                'DELETE FROM cycle_entries WHERE id NOT IN '
                '(SELECT MIN(id) FROM cycle_entries GROUP BY start_date)',
              );

              // Step 2: rebuild cycle_entries with UNIQUE(start_date).
              // ignore: experimental_member_use
              await m.alterTable(TableMigration(cycleEntries));

              // Step 3: add backup_suspended column (default false).
              await m.addColumn(appSettings, appSettings.backupSuspended);
            });
          }
        },
      );

  /// Must be called once at app startup, before any database is opened.
  ///
  /// Wires the `sqlite3` dynamic library to use the SQLCipher build provided
  /// by `sqlcipher_flutter_libs`.
  ///
  /// Android: uses [openCipherOnAndroid] from sqlcipher_flutter_libs.
  ///
  /// iOS: sqlite3 ≥ 2.9 first attempts to load `sqlite3.framework/sqlite3`
  /// (bundled by sqlite3_flutter_libs). When only sqlcipher_flutter_libs is
  /// present that path does not exist, so sqlite3 falls back to
  /// DynamicLibrary.process() which resolves the SYSTEM sqlite3 — not
  /// SQLCipher. We explicitly override with [_openCipherOnIOS], which tries
  /// the dynamic-framework path first, then falls back to process().
  static void initializeSQLCipher() {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    if (Platform.isIOS) {
      open.overrideFor(OperatingSystem.iOS, _openCipherOnIOS);
    }
  }

  /// iOS SQLCipher loader — called by both the main isolate and the
  /// background isolate (registrations are isolate-local).
  ///
  /// Tries paths in order and logs each attempt via [debugPrint] so the
  /// result is visible in the iOS system log (Settings → Privacy →
  /// Analytics → Analytics Data, or Xcode Devices console).
  static DynamicLibrary _openCipherOnIOS() {
    // Candidates for the SQLCipher dynamic framework produced by the
    // SQLCipher CocoaPod when the Podfile uses use_frameworks!.
    const candidates = [
      'SQLCipher.framework/SQLCipher', // canonical CocoaPods module name
      'sqlcipher.framework/sqlcipher', // lowercase variant (some pod versions)
    ];
    for (final path in candidates) {
      try {
        final lib = DynamicLibrary.open(path);
        debugPrint('[SQLCipher/iOS] loaded via DynamicLibrary.open($path)');
        return lib;
      } catch (e) {
        debugPrint(
          '[SQLCipher/iOS] DynamicLibrary.open($path) failed: '
          '${e.runtimeType}: $e',
        );
      }
    }
    // Fallback: SQLCipher may be statically linked (no use_frameworks!, or
    // static xcframework). DynamicLibrary.process() finds symbols baked into
    // the binary. WARNING: if SQLCipher is a dynamic framework and this path
    // is reached, process() resolves the SYSTEM sqlite3 instead — the
    // PRAGMA cipher_version smoke-test in setup() will then throw StateError.
    debugPrint('[SQLCipher/iOS] falling back to DynamicLibrary.process()');
    return DynamicLibrary.process();
  }

  /// Opens an encrypted SQLCipher database at [dbPath] using [hexKey].
  ///
  /// [hexKey] must be a 64-character hex string (32 bytes = 256 bits).
  /// The key is passed directly to SQLCipher via `PRAGMA key = "x'…'"` so
  /// it is treated as a raw binary key, not a passphrase.
  static QueryExecutor openConnection(String dbPath, String hexKey) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexKey)) {
      throw ArgumentError(
        'hexKey must be a 64-character hex string (0-9, a-f, A-F) representing 32 bytes',
      );
    }
    return LazyDatabase(() async {
      final file = File(dbPath);
      return NativeDatabase.createInBackground(
        file,
        // Re-register the SQLCipher override in the background isolate.
        // open.overrideFor registrations are isolate-local and are NOT
        // inherited by child isolates spawned by createInBackground.
        isolateSetup: () async {
          open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
          if (Platform.isIOS) {
            open.overrideFor(OperatingSystem.iOS, _openCipherOnIOS);
          }
        },
        setup: (rawDb) {
          // Unlock the SQLCipher database with the raw hex key.
          rawDb.execute("PRAGMA key = \"x'$hexKey'\"");
          // Verify SQLCipher loaded. If cipher_version is empty, the DB would
          // be unencrypted. Fail loudly rather than silently.
          final result = rawDb.select('PRAGMA cipher_version');
          if (result.isEmpty ||
              (result.first['cipher_version'] as String? ?? '').isEmpty) {
            throw StateError(
              'SQLCipher not loaded — database would be unencrypted. '
              'Ensure sqlcipher_flutter_libs is correctly linked.',
            );
          }
          // Enforce referential integrity for ON DELETE CASCADE to take effect.
          rawDb.execute('PRAGMA foreign_keys = ON');
        },
      );
    });
  }
}
