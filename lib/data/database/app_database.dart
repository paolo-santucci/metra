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

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// One row per calendar day. The primary key is the date (UTC midnight).
class DailyLogs extends Table {
  DateTimeColumn get date => dateTime()();
  IntColumn get flowIntensity => integer().nullable()(); // FlowIntensity.index
  BoolColumn get spotting => boolean().withDefault(const Constant(false))();
  BoolColumn get otherDischarge => boolean().withDefault(const Constant(false))();
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
  TextColumn get languageCode =>
      text().withDefault(const Constant('it'))();
  BoolColumn get darkMode => boolean().nullable()(); // null = follow system
  BoolColumn get painEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get notesEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get notificationDaysBefore =>
      integer().withDefault(const Constant(2))();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(false))();
}

/// Local-only audit trail of cloud backup/restore operations.
/// Never included in the backup blob.
class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get provider => text()(); // 'google_drive' | 'dropbox' | 'onedrive'
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
  daos: [DailyLogDao, CycleEntryDao, AppSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

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
    assert(
      RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexKey),
      'hexKey must be a 64-character lowercase hex string (32 bytes)',
    );
    return LazyDatabase(() async {
      final file = File(dbPath);
      return NativeDatabase.createInBackground(
        file,
        setup: (rawDb) {
          // Unlock the SQLCipher database with the raw hex key.
          rawDb.execute("PRAGMA key = \"x'$hexKey'\"");
          // Enforce referential integrity for ON DELETE CASCADE to take effect.
          rawDb.execute('PRAGMA foreign_keys = ON');
        },
      );
    });
  }
}
