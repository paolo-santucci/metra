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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/util/nullable.dart';
import 'package:metra/data/database/app_database.dart';
import 'package:metra/data/database/daos/app_settings_dao.dart';
import 'package:metra/data/repositories/drift_app_settings_repository.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

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

  // ---- DriftAppSettingsRepository.clearBackupSuspended — FR-12e, NFR-05, HC-6 ----

  group(
    'DriftAppSettingsRepository.clearBackupSuspended — FR-12e, NFR-05, HC-6',
    () {
      test(
        'clearBackupSuspended sets backupSuspended=false; lastLogOrSymptomWriteAt unchanged (NFR-05)',
        () async {
          await repo.getOrCreate(); // ensure singleton row exists
          final t = DateTime.utc(2026, 1, 1, 12, 0, 0);
          await repo.updateLastDataWriteAt(t);
          await repo.updateBackupSuspended(true);
          await repo.clearBackupSuspended();
          final settings = await repo.getOrCreate();
          expect(settings.backupSuspended, isFalse);
          expect(settings.lastLogOrSymptomWriteAt, equals(t));
        },
      );

      test(
        'updateLastDataWriteAt does NOT mutate backupSuspended (NFR-05)',
        () async {
          await repo.getOrCreate(); // ensure singleton row exists
          await repo.updateBackupSuspended(true);
          await repo.updateLastDataWriteAt(DateTime.utc(2026, 1, 1, 12));
          expect((await repo.getOrCreate()).backupSuspended, isTrue);
        },
      );

      test(
        'clearBackupSuspended on empty DB is a no-op (does not throw)',
        () async {
          await repo.clearBackupSuspended(); // expect no throw
        },
      );

      test(
        '_toCompanion exclusion regression: updateSettings does not touch backupSuspended',
        () async {
          await repo.getOrCreate(); // ensure singleton row exists
          await repo.updateBackupSuspended(true);
          final settings = await repo.getOrCreate();
          await repo.updateSettings(
            settings.copyWith(darkMode: const Nullable(false)),
          );
          expect((await repo.getOrCreate()).backupSuspended, isTrue);
        },
      );
    },
  );

  // ---- DriftAppSettingsRepository.updateBackupSuspended — FR-07, EC-14 ----

  group('DriftAppSettingsRepository.updateBackupSuspended — FR-07, EC-14', () {
    test(
        'sets backup_suspended to true; every other column byte-for-byte unchanged',
        () async {
      // Seed: fully-populated row with known values for every field.
      final initial = await repo.getOrCreate();
      await repo.updateSettings(
        initial.copyWith(
          darkMode: const Nullable(true),
          notificationTimeMinutes: 480,
          firstDayOfWeek: FirstDayOfWeekSetting.monday,
        ),
      );
      await repo.updateBackupState(
        dropboxEmail: 'x@y.com',
        lastBackupAt: DateTime.utc(2025, 1, 1),
      );
      await repo.updateLastDataWriteAt(DateTime.utc(2026, 5, 1));
      // Confirm starting state.
      final before = await repo.getOrCreate();
      expect(before.backupSuspended, isFalse);

      // Act.
      await repo.updateBackupSuspended(true);

      // Assert.
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isTrue);
      expect(after.darkMode, isTrue);
      expect(after.dropboxEmail, 'x@y.com');
      expect(after.lastBackupAt?.toUtc(), equals(DateTime.utc(2025, 1, 1)));
      expect(after.notificationTimeMinutes, 480);
      expect(after.firstDayOfWeek, FirstDayOfWeekSetting.monday);
      expect(
        after.lastLogOrSymptomWriteAt?.toUtc(),
        equals(DateTime.utc(2026, 5, 1)),
      );
    });

    test(
        'idempotency — updateBackupSuspended(false) on row already at false is a no-op',
        () async {
      await repo.getOrCreate();
      // Row starts at backupSuspended=false (DB default).
      await repo.updateBackupSuspended(false);
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isFalse);
    });

    test(
        '_toCompanion exclusion regression guard — updateSettings(copyWith) on row with backupSuspended=true preserves backupSuspended==true',
        () async {
      // Seed backupSuspended=true via the dedicated writer.
      await repo.getOrCreate();
      await repo.updateBackupSuspended(true);

      // Call updateSettings with a copyWith-ed entity (does NOT touch backupSuspended).
      final current = await repo.getOrCreate();
      await repo
          .updateSettings(current.copyWith(darkMode: const Nullable(true)));

      // backupSuspended must still be true — _toCompanion must not include it.
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isTrue);
      expect(after.darkMode, isTrue);
    });

    test(
        '_fromRow mapping — fresh v10 DB row has backupSuspended==false; updateBackupSuspended(true) then returns true',
        () async {
      // Fresh in-memory DB at v10 (onCreate path).
      final fresh = await repo.getOrCreate();
      expect(fresh.backupSuspended, isFalse);

      await repo.updateBackupSuspended(true);
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isTrue);
    });
  });
}
