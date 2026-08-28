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

// GROUP D — CI-ONLY (NativeDatabase.memory() requires native sqlite3 absent locally).
// These tests are authored and GREEN-ON-CI-ONLY. Never report passing locally.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';
import 'package:metra/data/database/daos/app_settings_dao.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late AppSettingsDao dao;

  setUp(() {
    db = _openTestDb();
    dao = db.appSettingsDao;
  });

  tearDown(() => db.close());

  // ---- AppSettingsDao.setActiveProvider — FR-07, TASK-06 ----

  group('AppSettingsDao.setActiveProvider — FR-07, dedicated-writer isolation',
      () {
    test(
      'setActiveProvider writes active_provider; every other column unchanged',
      () async {
        // Seed: create the singleton row, then populate several other columns
        // with known non-default values so we can assert they are untouched.
        final initial = await dao.getOrCreateSettings();

        // Populate unrelated columns via updateSettings.
        await dao.updateSettings(
          const AppSettingsCompanion(
            languageCode: Value('en'),
            darkMode: Value(true),
            notificationsEnabled: Value(true),
            backupSuspended: Value(true),
          ),
        );

        // Capture the row before the writer runs.
        final before = await dao.getOrCreateSettings();
        expect(before.languageCode, 'en');
        expect(before.darkMode, isTrue);
        expect(before.notificationsEnabled, isTrue);
        expect(before.backupSuspended, isTrue);
        expect(before.activeProvider, 'dropbox'); // DB column default

        // Act: call the dedicated writer.
        await dao.setActiveProvider('google_drive');

        // Assert: only active_provider changed.
        final after = await dao.getOrCreateSettings();
        expect(after.activeProvider, 'google_drive');

        // Every other column must be byte-for-byte identical to before.
        expect(after.id, before.id);
        expect(after.languageCode, before.languageCode);
        expect(after.darkMode, before.darkMode);
        expect(after.notificationsEnabled, before.notificationsEnabled);
        expect(after.backupSuspended, before.backupSuspended);
        expect(after.dropboxEmail, before.dropboxEmail);
        expect(after.lastBackupAt, before.lastBackupAt);
        expect(after.notificationDaysBefore, before.notificationDaysBefore);
        expect(after.onboardingCompleted, before.onboardingCompleted);
        expect(after.declaredCycleLength, before.declaredCycleLength);
        expect(after.notificationTimeMinutes, before.notificationTimeMinutes);
        expect(after.firstDayOfWeek, before.firstDayOfWeek);
        expect(after.lastLogOrSymptomWriteAt, before.lastLogOrSymptomWriteAt);

        // Suppress unused-variable warning — initial used only for row creation.
        expect(initial.id, 1);
      },
    );

    test(
      'setActiveProvider("icloud") persists "icloud" wire string',
      () async {
        await dao.getOrCreateSettings();
        await dao.setActiveProvider('icloud');
        final row = await dao.getOrCreateSettings();
        expect(row.activeProvider, 'icloud');
      },
    );

    test(
      'setActiveProvider is idempotent — calling twice with same value is a no-op',
      () async {
        await dao.getOrCreateSettings();
        await dao.setActiveProvider('google_drive');
        await dao.setActiveProvider('google_drive');
        final row = await dao.getOrCreateSettings();
        expect(row.activeProvider, 'google_drive');
      },
    );
  });
}
