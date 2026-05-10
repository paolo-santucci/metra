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

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/constants/app_constants.dart';
import 'package:metra/data/database/app_database.dart';
import 'package:metra/data/database/daos/app_settings_dao.dart';
import 'package:metra/data/repositories/drift_app_settings_repository.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

/// Seeds a raw integer into firstDayOfWeek, bypassing entity clamping.
Future<void> _setRawFirstDayOfWeek(AppDatabase db, int rawValue) async {
  await (db.update(db.appSettings)..where((t) => t.id.equals(1)))
      .write(AppSettingsCompanion(firstDayOfWeek: Value(rawValue)));
}

/// Seeds a raw integer into notificationTimeMinutes, bypassing entity clamping.
Future<void> _setRawNotificationTimeMinutes(
  AppDatabase db,
  int rawValue,
) async {
  await (db.update(db.appSettings)..where((t) => t.id.equals(1)))
      .write(AppSettingsCompanion(notificationTimeMinutes: Value(rawValue)));
}

/// Seeds a raw integer into notificationDaysBefore, bypassing entity clamping.
Future<void> _setRawNotificationDaysBefore(
  AppDatabase db,
  int rawValue,
) async {
  await (db.update(db.appSettings)..where((t) => t.id.equals(1)))
      .write(AppSettingsCompanion(notificationDaysBefore: Value(rawValue)));
}

void main() {
  late AppDatabase db;
  late AppSettingsDao dao;
  late DriftAppSettingsRepository repo;

  setUp(() {
    db = _openTestDb();
    dao = db.appSettingsDao;
    repo = DriftAppSettingsRepository(dao);
  });

  tearDown(() => db.close());

  // ---- firstDayOfWeek ----

  group('firstDayOfWeek', () {
    test('default is system (0) from fresh row', () async {
      final result = await repo.getOrCreate();
      expect(result.firstDayOfWeek, FirstDayOfWeekSetting.system);
    });

    test('round-trip: persist sunday → reload → sunday', () async {
      final initial = await repo.getOrCreate();
      await repo.updateSettings(
        initial.copyWith(firstDayOfWeek: FirstDayOfWeekSetting.sunday),
      );
      final result = await repo.getOrCreate();
      expect(result.firstDayOfWeek, FirstDayOfWeekSetting.sunday);
    });

    test('round-trip: persist monday → reload → monday', () async {
      final initial = await repo.getOrCreate();
      await repo.updateSettings(
        initial.copyWith(firstDayOfWeek: FirstDayOfWeekSetting.monday),
      );
      final result = await repo.getOrCreate();
      expect(result.firstDayOfWeek, FirstDayOfWeekSetting.monday);
    });

    test('out-of-range DB value 99 is clamped to system', () async {
      await repo.getOrCreate();
      await _setRawFirstDayOfWeek(db, 99);
      final result = await repo.getOrCreate();
      expect(result.firstDayOfWeek, FirstDayOfWeekSetting.system);
    });

    test('updateSettings(firstDayOfWeek) does not revert other fields',
        () async {
      final initial = await repo.getOrCreate();
      await repo.updateSettings(
        initial.copyWith(notificationTimeMinutes: 750),
      );
      final before = await repo.getOrCreate();
      await repo.updateSettings(
        before.copyWith(firstDayOfWeek: FirstDayOfWeekSetting.sunday),
      );
      final after = await repo.getOrCreate();
      expect(after.firstDayOfWeek, FirstDayOfWeekSetting.sunday);
      expect(after.notificationTimeMinutes, 750);
    });
  });

  // ---- _fromRow happy path ----

  group('_fromRow', () {
    test('reads notificationTimeMinutes=720 unchanged', () async {
      // Create row then overwrite the column with 720 at DB level.
      await repo.getOrCreate();
      await _setRawNotificationTimeMinutes(db, 720);

      final result = await repo.getOrCreate();
      expect(result.notificationTimeMinutes, 720);
    });

    test('reads default notificationTimeMinutes=540 from fresh row', () async {
      final result = await repo.getOrCreate();
      expect(result.notificationTimeMinutes, 540);
    });

    test('clamps notificationTimeMinutes=-5 to 0', () async {
      await repo.getOrCreate();
      await _setRawNotificationTimeMinutes(db, -5);

      final result = await repo.getOrCreate();
      expect(result.notificationTimeMinutes, 0);
    });

    test('clamps notificationTimeMinutes=2000 to 1439', () async {
      await repo.getOrCreate();
      await _setRawNotificationTimeMinutes(db, 2000);

      final result = await repo.getOrCreate();
      expect(result.notificationTimeMinutes, 1439);
    });

    test(
        'clamps notificationDaysBefore=99 to kMaxAdvanceDays (${AppConstants.kMaxAdvanceDays})',
        () async {
      await repo.getOrCreate();
      await _setRawNotificationDaysBefore(db, 99);

      final result = await repo.getOrCreate();
      expect(result.notificationDaysBefore, AppConstants.kMaxAdvanceDays);
    });
  });

  // ---- _toCompanion persists notificationTimeMinutes ----

  group('_toCompanion', () {
    test(
        'updateSettings with notificationTimeMinutes=750 persists 750 (not Value.absent)',
        () async {
      // Row starts with column default 540.
      final initial = await repo.getOrCreate();
      expect(initial.notificationTimeMinutes, 540);

      // Write 750 through the public API.
      await repo.updateSettings(
        initial.copyWith(notificationTimeMinutes: 750),
      );

      // Read directly from the DAO to verify the column was written.
      final raw = await (db.select(db.appSettings)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(raw.notificationTimeMinutes, 750);
    });
  });

  // ---- EC-16: updateSettings with unrelated field does not revert ----

  group('updateSettings preservation EC-16', () {
    test(
        'updateSettings(themeMode only) does NOT revert notificationTimeMinutes from 750',
        () async {
      // First persist 750 via the public API.
      final initial = await repo.getOrCreate();
      await repo.updateSettings(
        initial.copyWith(notificationTimeMinutes: 750),
      );

      // Now update an unrelated field.
      final before = await repo.getOrCreate();
      expect(before.notificationTimeMinutes, 750);
      await repo.updateSettings(before.copyWith(darkMode: true));

      // Confirm 750 survived.
      final after = await repo.getOrCreate();
      expect(after.notificationTimeMinutes, 750);
    });
  });

  // ---- Stream re-emit (NFR-10) ----

  group('stream re-emit NFR-10', () {
    test(
        'watchSettings emits new value with notificationTimeMinutes=1080 after updateSettings',
        () async {
      // Ensure the row exists.
      await repo.getOrCreate();

      final initial = await repo.getOrCreate();
      await repo.updateSettings(
        initial.copyWith(notificationTimeMinutes: 1080),
      );

      final emitted = await repo.watchSettings().first;
      expect(emitted, isNotNull);
      expect(emitted!.notificationTimeMinutes, 1080);
    });
  });
}
