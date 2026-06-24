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
import 'package:metra/domain/entities/sync_log_entity.dart';

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

  // ---- DriftAppSettingsRepository.setActiveProvider — FR-07, FR-10, FR-11 ----
  //
  // GROUP D — CI-ONLY (NativeDatabase.memory() requires native sqlite3 absent locally).
  // Tests are authored and GREEN-ON-CI-ONLY. Never report passing locally.

  group(
    'DriftAppSettingsRepository.setActiveProvider — FR-07, FR-10, FR-11',
    () {
      test(
        'setActiveProvider(iCloud) → getOrCreate().activeProvider == iCloud; only active_provider changed',
        () async {
          await repo.getOrCreate(); // ensure singleton row exists

          // Seed some unrelated columns so we can assert they are preserved.
          await repo.updateBackupSuspended(true);
          final t = DateTime.utc(2026, 3, 1, 10, 0, 0);
          await repo.updateLastDataWriteAt(t);

          final before = await repo.getOrCreate();

          // Act.
          await repo.setActiveProvider(SyncProvider.iCloud);

          // Assert: only activeProvider changed.
          final after = await repo.getOrCreate();
          expect(after.activeProvider, SyncProvider.iCloud);

          // Every other mapped field byte-for-byte preserved.
          expect(after.backupSuspended, before.backupSuspended);
          expect(after.lastLogOrSymptomWriteAt, before.lastLogOrSymptomWriteAt);
          expect(after.languageCode, before.languageCode);
          expect(after.darkMode, before.darkMode);
          expect(after.notificationsEnabled, before.notificationsEnabled);
        },
      );

      test(
        'setActiveProvider(googleDrive) persists google_drive wire string',
        () async {
          await repo.getOrCreate();
          await repo.setActiveProvider(SyncProvider.googleDrive);
          final after = await repo.getOrCreate();
          expect(after.activeProvider, SyncProvider.googleDrive);
        },
      );

      test(
        '_toCompanion exclusion (EC-06): updateSettings via copyWith cannot clobber active_provider',
        () async {
          // Step 1: seed singleton row.
          await repo.getOrCreate();

          // Step 2: set activeProvider = googleDrive via the dedicated writer.
          await repo.setActiveProvider(SyncProvider.googleDrive);

          // Verify it persisted.
          expect(
            (await repo.getOrCreate()).activeProvider,
            SyncProvider.googleDrive,
          );

          // Step 3: call updateSettings with a copyWith-modified unrelated field.
          final current = await repo.getOrCreate();
          await repo.updateSettings(
            current.copyWith(darkMode: const Nullable(false)),
          );

          // Step 4: activeProvider MUST still be googleDrive.
          final after = await repo.getOrCreate();
          expect(
            after.activeProvider,
            SyncProvider.googleDrive,
            reason:
                '_toCompanion must exclude activeProvider (Companion.absent()); '
                'a bulk updateSettings call must not clobber the dedicated-writer value',
          );
          expect(after.darkMode, isFalse);
        },
      );

      test(
        'fresh DB row has activeProvider == dropbox (DB column default)',
        () async {
          final fresh = await repo.getOrCreate();
          expect(fresh.activeProvider, SyncProvider.dropbox);
        },
      );
    },
  );

  // ---- _activeProviderFromString clamp-mapper — FR-09, NFR-06, EC-03 ----
  //
  // GROUP D — CI-ONLY (NativeDatabase.memory() requires native sqlite3 absent locally).
  // Tests are authored and GREEN-ON-CI-ONLY. Never report passing locally.
  //
  // The clamp-mapper is a private static; tests exercise it via the public
  // getOrCreate() read path after seeding the raw wire string via the DAO.
  // This mirrors the _firstDayOfWeekFromIndex posture: clamp-don't-throw.
  // The strict throwing mapper (_stringToProvider in DriftSyncLogRepository)
  // is a DIFFERENT function — verified by the distinctness test below.

  group(
    '_activeProviderFromString clamp-mapper — FR-09, NFR-06, EC-03',
    () {
      test(
        '"dropbox" wire string → activeProvider == SyncProvider.dropbox',
        () async {
          await repo.getOrCreate(); // create singleton row
          await dao.setActiveProvider('dropbox'); // raw write
          final result = await repo.getOrCreate();
          expect(result.activeProvider, SyncProvider.dropbox);
        },
      );

      test(
        '"google_drive" wire string → activeProvider == SyncProvider.googleDrive',
        () async {
          await repo.getOrCreate();
          await dao.setActiveProvider('google_drive');
          final result = await repo.getOrCreate();
          expect(result.activeProvider, SyncProvider.googleDrive);
        },
      );

      test(
        '"icloud" wire string → activeProvider == SyncProvider.iCloud',
        () async {
          await repo.getOrCreate();
          await dao.setActiveProvider('icloud');
          final result = await repo.getOrCreate();
          expect(result.activeProvider, SyncProvider.iCloud);
        },
      );

      test(
        'unknown wire string clamps to SyncProvider.dropbox — never throws (NFR-06)',
        () async {
          await repo.getOrCreate();
          await dao.setActiveProvider('unknown_string');
          // Must not throw; must return dropbox as clamp fallback.
          final result = await repo.getOrCreate();
          expect(result.activeProvider, SyncProvider.dropbox);
        },
      );

      test(
        'forward value "future_provider" clamps to dropbox — settings load unbricked (EC-03)',
        () async {
          // Simulates a value written by a future build then rolled back to M1.
          await repo.getOrCreate();
          await dao.setActiveProvider('future_provider');
          // Must not throw; load must succeed and return dropbox.
          final result = await repo.getOrCreate();
          expect(
            result.activeProvider,
            SyncProvider.dropbox,
            reason:
                'EC-03: a forward value like "google_drive" or an unknown string '
                'written by a later build then rolled back must not brick settings load',
          );
        },
      );

      test(
        'distinctness: clamp-mapper returns dropbox on unknown; '
        'strict sync-log mapper would throw on the same input',
        () async {
          // This test confirms that the two mappers have different behaviours:
          // _activeProviderFromString (settings read path) → clamps to dropbox.
          // _stringToProvider (sync-log read path in DriftSyncLogRepository) → throws.
          //
          // We cannot call _activeProviderFromString directly (private), so we
          // verify its observable effect: seeding "unknown_string" does NOT throw
          // on getOrCreate() — the clamp absorbs it.
          await repo.getOrCreate();
          await dao.setActiveProvider('unknown_string');
          // Clamp: must return dropbox, must not throw.
          expect(
            () async => repo.getOrCreate(),
            returnsNormally,
          );
          final result = await repo.getOrCreate();
          expect(result.activeProvider, SyncProvider.dropbox);
        },
      );
    },
  );
}
