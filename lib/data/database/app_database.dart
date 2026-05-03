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
  int get schemaVersion => 5;

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
        },
      );

  /// Must be called once at app startup, before any database is opened.
  ///
  /// Wires the `sqlite3` dynamic library to use the SQLCipher build provided
  /// by `sqlcipher_flutter_libs` instead of the system sqlite3 on Android.
  /// On iOS/macOS the CocoaPod handles linking automatically.
  static void initializeSQLCipher() {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
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
