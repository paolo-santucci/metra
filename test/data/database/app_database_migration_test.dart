// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema version is 7', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 7);
  });

  test(
    'v6→v7 onUpgrade adds notification_time_minutes column with default 540',
    () async {
      // Given: an in-memory database pre-seeded at user_version=6, with the
      // v6 app_settings schema (no notification_time_minutes column) and one
      // existing row. The setup callback runs synchronously before Drift opens
      // the database, so Drift will see user_version=6 and schemaVersion=7 and
      // fire onUpgrade(m, 6, 7).
      final executor = NativeDatabase.memory(
        setup: (Database rawDb) {
          rawDb.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              language_code TEXT NOT NULL DEFAULT 'it',
              dark_mode INTEGER,
              pain_enabled INTEGER NOT NULL DEFAULT 1,
              notes_enabled INTEGER NOT NULL DEFAULT 1,
              notification_days_before INTEGER NOT NULL DEFAULT 2,
              notifications_enabled INTEGER NOT NULL DEFAULT 0,
              dropbox_email TEXT,
              last_backup_at INTEGER,
              onboarding_completed INTEGER NOT NULL DEFAULT 0,
              declared_cycle_length INTEGER
            )
          ''');
          rawDb.execute('INSERT INTO app_settings (id) VALUES (1)');
          rawDb.execute('PRAGMA user_version = 6');
        },
      );

      // When: AppDatabase opens over the pre-seeded executor.
      final db = AppDatabase(executor);
      addTearDown(db.close);

      // Trigger Drift's lazy open / migration by issuing any query.
      await db.customSelect('SELECT 1').get();

      // Then: the new column exists and carries the default value 540 for the
      // pre-existing row.
      final rows = await db
          .customSelect('SELECT notification_time_minutes FROM app_settings')
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.data['notification_time_minutes'], 540);

      // And: schemaVersion is 7.
      expect(db.schemaVersion, 7);
    },
  );

  test('AppSettings has dropboxEmail and lastBackupAt columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = await db.appSettingsDao.getOrCreateSettings();
    expect(settings.dropboxEmail, isNull);
    expect(settings.lastBackupAt, isNull);
  });

  test('AppSettings has onboardingCompleted column defaulting to false',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = await db.appSettingsDao.getOrCreateSettings();
    expect(settings.onboardingCompleted, isFalse);
  });

  test(
    'AppSettings has declaredCycleLength column defaulting to null (Strategy B)',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final settings = await db.appSettingsDao.getOrCreateSettings();
      expect(settings.declaredCycleLength, isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // v6 → v7 full battery (spec §7.2, NFR-03, NFR-14)
  // ---------------------------------------------------------------------------

  test(
    'v6→v7 multi-row: cycle_entries rows in unrelated table are not lost',
    () async {
      // Given: a v6 in-memory database that already has 3 cycle_entries rows
      // (cycle_entries has no dependency on notification_time_minutes — it is
      // entirely unrelated to the migration column). We also add the v6
      // app_settings table without the new column so that the schema matches
      // what a real v6 installation would look like.
      final executor = NativeDatabase.memory(
        setup: (Database rawDb) {
          // Minimal v6 app_settings (no notification_time_minutes column).
          rawDb.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              language_code TEXT NOT NULL DEFAULT 'it',
              dark_mode INTEGER,
              pain_enabled INTEGER NOT NULL DEFAULT 1,
              notes_enabled INTEGER NOT NULL DEFAULT 1,
              notification_days_before INTEGER NOT NULL DEFAULT 2,
              notifications_enabled INTEGER NOT NULL DEFAULT 0,
              dropbox_email TEXT,
              last_backup_at INTEGER,
              onboarding_completed INTEGER NOT NULL DEFAULT 0,
              declared_cycle_length INTEGER
            )
          ''');
          // cycle_entries does not change across v6→v7.
          rawDb.execute('''
            CREATE TABLE IF NOT EXISTS cycle_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              start_date INTEGER NOT NULL,
              end_date INTEGER,
              cycle_length INTEGER,
              period_length INTEGER
            )
          ''');
          // Three cycle_entries rows with distinct start dates.
          rawDb.execute(
            'INSERT INTO cycle_entries (start_date, cycle_length) VALUES (?,?),(?,?),(?,?)',
            [1000000, 28, 2000000, 29, 3000000, 27],
          );
          rawDb.execute('PRAGMA user_version = 6');
        },
      );

      final db = AppDatabase(executor);
      addTearDown(db.close);

      // Trigger migration.
      await db.customSelect('SELECT 1').get();

      // Then: all three rows survive unchanged.
      final rows = await db
          .customSelect(
            'SELECT start_date, cycle_length FROM cycle_entries '
            'ORDER BY start_date',
          )
          .get();
      expect(rows, hasLength(3));
      expect(rows[0].data['start_date'], 1000000);
      expect(rows[0].data['cycle_length'], 28);
      expect(rows[1].data['start_date'], 2000000);
      expect(rows[1].data['cycle_length'], 29);
      expect(rows[2].data['start_date'], 3000000);
      expect(rows[2].data['cycle_length'], 27);

      // And: the new column is present.
      final settings = await db
          .customSelect('SELECT notification_time_minutes FROM app_settings')
          .get();
      // No app_settings row was inserted — the table is empty — so the
      // column-existence check is enough here; the default-value assertion
      // already lives in the happy-path smoke test.
      expect(settings, isEmpty); // table exists, column present, 0 rows
    },
  );

  test(
    'onCreate at v7: fresh database has notificationTimeMinutes == 540',
    () async {
      // Given: a freshly created in-memory database (no v6 snapshot — onCreate
      // runs, onUpgrade does not). No setup callback is needed.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // When: getOrCreateSettings initialises the singleton row.
      final settings = await db.appSettingsDao.getOrCreateSettings();

      // Then: the column default (540) is reflected in the entity field.
      expect(settings.notificationTimeMinutes, 540);

      // And: schemaVersion is 7 (no migration ran — onCreate set it directly).
      expect(db.schemaVersion, 7);
    },
  );

  test(
    'NFR-14 migration purity: v6→v7 onUpgrade block uses only addColumn',
    () async {
      // This test verifies the migration source directly rather than at runtime,
      // because Drift does not expose a statement-recorder API in tests.
      // The production file is the ground truth; if the migration is impure
      // (customStatement, backfill query), this assertion fails the build.
      final src = await File(
        'lib/data/database/app_database.dart',
      ).readAsString();

      // Locate the if (from < 7) { ... } block.
      final fromLt7Match = RegExp(
        r'if\s*\(\s*from\s*<\s*7\s*\)\s*\{([^}]*)\}',
        dotAll: true,
      ).firstMatch(src);
      expect(
        fromLt7Match,
        isNotNull,
        reason: 'Expected an "if (from < 7) { ... }" block in onUpgrade',
      );

      final blockBody = fromLt7Match!.group(1)!;

      // The block must contain m.addColumn(...).
      expect(
        blockBody,
        contains('m.addColumn'),
        reason: 'v6→v7 onUpgrade block must call m.addColumn',
      );

      // The block must NOT contain customStatement.
      expect(
        blockBody,
        isNot(contains('customStatement')),
        reason: 'NFR-14: v6→v7 onUpgrade block must not use customStatement',
      );

      // The block must NOT contain a raw SQL UPDATE or INSERT backfill.
      expect(
        blockBody,
        isNot(matches(RegExp(r'\bUPDATE\b', caseSensitive: false))),
        reason: 'NFR-14: v6→v7 onUpgrade block must not backfill via UPDATE',
      );
      expect(
        blockBody,
        isNot(matches(RegExp(r'\bINSERT\b', caseSensitive: false))),
        reason: 'NFR-14: v6→v7 onUpgrade block must not backfill via INSERT',
      );
    },
  );

  group('v5 → v6 migration: drop PainSymptomType.cramps', () {
    // The v5→v6 migration removes the `cramps` enum value (was index 0).
    // Existing rows are preserved as custom-label entries; remaining
    // indices shift down by one. The SQL is exercised here directly
    // against an in-memory DB to validate the three-step transformation.

    Future<void> runV6Sql(AppDatabase db) async {
      await db.customStatement(
        "UPDATE pain_symptoms "
        "SET symptom_type = -1, custom_label = 'Crampi' "
        "WHERE symptom_type = 0",
      );
      await db.customStatement(
        "UPDATE pain_symptoms "
        "SET symptom_type = symptom_type - 1 "
        "WHERE symptom_type BETWEEN 1 AND 8",
      );
      await db.customStatement(
        "UPDATE pain_symptoms "
        "SET symptom_type = 4 "
        "WHERE symptom_type = -1",
      );
    }

    test('cramps rows (old index 0) become custom-label "Crampi"', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // Insert a parent daily_logs row first (FK constraint).
      final date = DateTime.utc(2026, 4, 1);
      await db.customStatement(
        "INSERT INTO daily_logs (date) VALUES (?)",
        [date.millisecondsSinceEpoch ~/ 1000],
      );
      await db.customStatement(
        "INSERT INTO pain_symptoms (daily_log_date, symptom_type, custom_label) "
        "VALUES (?, 0, NULL)",
        [date.millisecondsSinceEpoch ~/ 1000],
      );

      await runV6Sql(db);

      final rows = await db
          .customSelect('SELECT symptom_type, custom_label FROM pain_symptoms')
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.data['symptom_type'], 4);
      expect(rows.first.data['custom_label'], 'Crampi');
    });

    test('higher-index rows shift down by one', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final date = DateTime.utc(2026, 4, 2);
      await db.customStatement(
        "INSERT INTO daily_logs (date) VALUES (?)",
        [date.millisecondsSinceEpoch ~/ 1000],
      );
      // Insert one row per old index 1..8.
      for (var oldIndex = 1; oldIndex <= 8; oldIndex++) {
        await db.customStatement(
          "INSERT INTO pain_symptoms (daily_log_date, symptom_type, custom_label) "
          "VALUES (?, ?, ?)",
          [
            date.millisecondsSinceEpoch ~/ 1000,
            oldIndex,
            // Old index 5 was `custom`; preserve a label to verify it survives.
            oldIndex == 5 ? 'preserved' : null,
          ],
        );
      }

      await runV6Sql(db);

      final rows = await db
          .customSelect(
            'SELECT symptom_type, custom_label FROM pain_symptoms '
            'ORDER BY symptom_type',
          )
          .get();
      // Each old index 1..8 should now be at oldIndex - 1 = 0..7.
      expect(
        rows.map((r) => r.data['symptom_type']).toList(),
        [0, 1, 2, 3, 4, 5, 6, 7],
      );
      // The pre-existing custom row's label must survive untouched.
      final customRow = rows.firstWhere((r) => r.data['symptom_type'] == 4);
      expect(customRow.data['custom_label'], 'preserved');
    });

    test('mixed scenario: cramps + higher indices migrate correctly', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final date = DateTime.utc(2026, 4, 3);
      await db.customStatement(
        "INSERT INTO daily_logs (date) VALUES (?)",
        [date.millisecondsSinceEpoch ~/ 1000],
      );
      // Two cramps rows + one each at old indices 1, 5, 8.
      await db.customStatement(
        "INSERT INTO pain_symptoms (daily_log_date, symptom_type, custom_label) "
        "VALUES (?, 0, NULL), (?, 0, NULL), (?, 1, NULL), "
        "(?, 5, 'jaw'), (?, 8, NULL)",
        List.filled(5, date.millisecondsSinceEpoch ~/ 1000),
      );

      await runV6Sql(db);

      final rows = await db
          .customSelect(
            'SELECT symptom_type, custom_label FROM pain_symptoms '
            'ORDER BY symptom_type, custom_label',
          )
          .get();
      // 2 backPain (old 1 → new 0), 2 custom-Crampi (old 0 → new 4),
      // 1 custom-jaw (old 5 → new 4), 1 breastTenderness (old 8 → new 7).
      final byKey = rows
          .map(
            (r) => '${r.data['symptom_type']}/${r.data['custom_label'] ?? ''}',
          )
          .toList()
        ..sort();
      expect(byKey, [
        '0/',
        '4/Crampi',
        '4/Crampi',
        '4/jaw',
        '7/',
      ]);
    });
  });
}
