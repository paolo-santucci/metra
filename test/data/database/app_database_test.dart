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

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('DailyLogDao', () {
    test('upsert + watchDay returns the inserted row', () async {
      final date = DateTime.utc(2026, 4, 1);
      await db.dailyLogDao.upsertDailyLog(
        DailyLogsCompanion(
          date: Value(date),
          flowIntensity: const Value(3), // FlowIntensity.medium.index
          spotting: const Value(false),
          otherDischarge: const Value(false),
          painEnabled: const Value(true),
          painIntensity: const Value(4),
          notesEnabled: const Value(true),
          notes: const Value('mild headache'),
        ),
      );

      final row = await db.dailyLogDao.watchDay(date).first;

      expect(row, isNotNull);
      // Drift reads DateTime back in local time; compare epoch to avoid isUtc mismatch.
      expect(
        row!.date.millisecondsSinceEpoch,
        equals(date.millisecondsSinceEpoch),
      );
      expect(row.flowIntensity, equals(3));
      expect(row.notes, equals('mild headache'));
      expect(row.painIntensity, equals(4));
    });

    test('upsert is idempotent: second write for same date wins, no duplicates',
        () async {
      final date = DateTime.utc(2026, 4, 2);

      await db.dailyLogDao.upsertDailyLog(
        DailyLogsCompanion(
          date: Value(date),
          flowIntensity: const Value(2), // light
        ),
      );
      await db.dailyLogDao.upsertDailyLog(
        DailyLogsCompanion(
          date: Value(date),
          flowIntensity: const Value(4), // heavy — overwrites
        ),
      );

      final row = await db.dailyLogDao.watchDay(date).first;
      expect(row, isNotNull);
      expect(row!.flowIntensity, equals(4));

      // Confirm there is only one row for this date.
      // Compare epoch because Drift returns local DateTime while `date` is UTC.
      final all = await db.select(db.dailyLogs).get();
      expect(
        all
            .where(
              (r) =>
                  r.date.millisecondsSinceEpoch == date.millisecondsSinceEpoch,
            )
            .length,
        equals(1),
      );
    });
  });

  group('PainSymptoms via DailyLogDao', () {
    test(
        'replacePainSymptoms replaces all: insert 2 then replace with 1 → only 1 remains',
        () async {
      final date = DateTime.utc(2026, 4, 3);
      // Insert parent row first so FK cascade works on production; in memory FK
      // is not enforced, but we add the parent to mirror realistic usage.
      await db.dailyLogDao.upsertDailyLog(
        DailyLogsCompanion(date: Value(date)),
      );

      await db.dailyLogDao.replacePainSymptoms(
        date,
        [
          PainSymptomsCompanion(
            dailyLogDate: Value(date),
            symptomType: const Value(0), // cramps
          ),
          PainSymptomsCompanion(
            dailyLogDate: Value(date),
            symptomType: const Value(1), // back
          ),
        ],
      );

      await db.dailyLogDao.replacePainSymptoms(
        date,
        [
          PainSymptomsCompanion(
            dailyLogDate: Value(date),
            symptomType: const Value(2), // headache
          ),
        ],
      );

      final symptoms = await db.dailyLogDao.getPainSymptoms(date);
      expect(symptoms.length, equals(1));
      expect(symptoms.first.symptomType, equals(2));
    });
  });

  group('CycleEntryDao', () {
    test('insert 5 entries, getRecentCycles(3) returns 3 latest in desc order',
        () async {
      // Insert 5 entries with distinct startDates.
      for (var i = 1; i <= 5; i++) {
        await db.cycleEntryDao.insertCycleEntry(
          CycleEntriesCompanion(
            startDate: Value(DateTime.utc(2026, i, 1)),
            cycleLength: Value(28 + i),
          ),
        );
      }

      final recent = await db.cycleEntryDao.getRecentCycles(3);

      expect(recent.length, equals(3));
      // Verify descending order by startDate.
      // Compare epoch because Drift returns local DateTime while DateTime.utc is UTC.
      expect(
        recent[0].startDate.millisecondsSinceEpoch,
        equals(DateTime.utc(2026, 5, 1).millisecondsSinceEpoch),
      );
      expect(
        recent[1].startDate.millisecondsSinceEpoch,
        equals(DateTime.utc(2026, 4, 1).millisecondsSinceEpoch),
      );
      expect(
        recent[2].startDate.millisecondsSinceEpoch,
        equals(DateTime.utc(2026, 3, 1).millisecondsSinceEpoch),
      );
    });
  });

  group('AppSettingsDao', () {
    test('getOrCreateSettings: calling twice returns same singleton row',
        () async {
      final first = await db.appSettingsDao.getOrCreateSettings();
      final second = await db.appSettingsDao.getOrCreateSettings();

      expect(first.id, equals(1));
      expect(second.id, equals(1));

      // Confirm there is only one row in the table.
      final all = await db.select(db.appSettings).get();
      expect(all.length, equals(1));
    });

    test('updateSettings: languageCode persists as "en"', () async {
      await db.appSettingsDao.getOrCreateSettings();

      await db.appSettingsDao.updateSettings(
        const AppSettingsCompanion(languageCode: Value('en')),
      );

      final row = await db.appSettingsDao.getOrCreateSettings();
      expect(row.languageCode, equals('en'));
    });
  });
}
