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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';

void main() {
  test('schema version is 6', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 6);
  });

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
