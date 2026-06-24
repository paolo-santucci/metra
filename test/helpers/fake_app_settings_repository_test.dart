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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/util/nullable.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

import 'fake_app_settings_repository.dart';

void main() {
  group('FakeAppSettingsRepository.updateBackupSuspended — FR-07', () {
    test(
        'given_fresh_fake_seeded_with_backupSuspended_false_when_updateBackupSuspended_true_then_getOrCreate_returns_backupSuspended_true',
        () async {
      final repo = FakeAppSettingsRepository();
      await repo.updateBackupSuspended(true);
      final settings = await repo.getOrCreate();
      expect(settings.backupSuspended, isTrue);
    });

    test(
        'EC-14_fully_populated_entity_when_updateBackupSuspended_true_then_backupSuspended_true_and_all_other_fields_preserved',
        () async {
      final repo = FakeAppSettingsRepository();
      repo.storedSettings = AppSettingsData(
        languageCode: 'it',
        darkMode: true,
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        dropboxEmail: 'x@y',
        lastBackupAt: DateTime.utc(2025, 1, 1),
        onboardingCompleted: true,
        declaredCycleLength: 28,
        notificationTimeMinutes: 480,
        firstDayOfWeek: FirstDayOfWeekSetting.monday,
        lastLogOrSymptomWriteAt: DateTime.utc(2026, 5, 1),
        backupSuspended: false,
      );
      await repo.updateBackupSuspended(true);
      final s = await repo.getOrCreate();
      expect(s.backupSuspended, isTrue);
      expect(s.darkMode, isTrue);
      expect(s.dropboxEmail, equals('x@y'));
      expect(s.lastBackupAt, equals(DateTime.utc(2025, 1, 1)));
      expect(s.lastLogOrSymptomWriteAt, equals(DateTime.utc(2026, 5, 1)));
      expect(s.notificationTimeMinutes, equals(480));
    });

    test('fragility_guard_updateBackupState_preserves_backupSuspended_true',
        () async {
      final repo = FakeAppSettingsRepository();
      await repo.updateBackupSuspended(true);
      await repo.updateBackupState(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
      );
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isTrue);
    });

    test(
        'fragility_guard_markOnboardingComplete_preserves_backupSuspended_true',
        () async {
      final repo = FakeAppSettingsRepository();
      await repo.updateBackupSuspended(true);
      await repo.markOnboardingComplete();
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isTrue);
    });

    test(
        'fragility_guard_saveDeclaredCycleLength_preserves_backupSuspended_true',
        () async {
      final repo = FakeAppSettingsRepository();
      await repo.updateBackupSuspended(true);
      await repo.saveDeclaredCycleLength(28);
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isTrue);
    });

    test('fragility_guard_updateLastDataWriteAt_preserves_backupSuspended_true',
        () async {
      final repo = FakeAppSettingsRepository();
      await repo.updateBackupSuspended(true);
      await repo.updateLastDataWriteAt(DateTime.utc(2026, 5, 17));
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isTrue);
    });

    test(
        'manual_copy_guard_updateSettings_via_copyWith_preserves_backupSuspended_true',
        () async {
      final repo = FakeAppSettingsRepository();
      await repo.updateBackupSuspended(true);
      final current = await repo.getOrCreate();
      await repo.updateSettings(
        current.copyWith(darkMode: const Nullable(true)),
      );
      final after = await repo.getOrCreate();
      expect(after.backupSuspended, isTrue);
    });

    test(
        'given_fresh_fake_when_getOrCreate_then_backupSuspended_is_false_by_default',
        () async {
      final repo = FakeAppSettingsRepository();
      final settings = await repo.getOrCreate();
      expect(settings.backupSuspended, isFalse);
    });
  });

  group('FakeAppSettingsRepository.clearBackupSuspended — FR-12e, HC-6', () {
    test(
        'given_backupSuspended_true_when_clearBackupSuspended_then_backupSuspended_false_and_invocation_recorded',
        () async {
      final fake = FakeAppSettingsRepository();
      await fake.updateBackupSuspended(true);
      expect((await fake.getOrCreate()).backupSuspended, isTrue);
      await fake.clearBackupSuspended();
      final settings = await fake.getOrCreate();
      expect(settings.backupSuspended, isFalse);
      expect(fake.callLog, contains('clearBackupSuspended'));
    });

    test(
        'given_lastLogOrSymptomWriteAt_set_when_clearBackupSuspended_then_lastLogOrSymptomWriteAt_unchanged',
        () async {
      final fake = FakeAppSettingsRepository();
      final t = DateTime.utc(2026, 1, 1, 12, 0, 0);
      await fake.updateLastDataWriteAt(t);
      await fake.clearBackupSuspended();
      expect(
        (await fake.getOrCreate()).lastLogOrSymptomWriteAt,
        equals(t),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group E — activeProvider threading (EC-10, TASK-04 / FR-13, NFR-05)
  // ---------------------------------------------------------------------------
  // Each of the six full-constructor copy blocks in FakeAppSettingsRepository
  // must forward activeProvider unchanged. These tests are the silent-reset
  // regression guard: they set activeProvider=googleDrive, invoke the
  // operation that exercises each block, then assert activeProvider is STILL
  // googleDrive. If any block omits the field, the default (dropbox) resets it
  // and the corresponding test fails.
  group(
      'FakeAppSettingsRepository.activeProvider threading — EC-10 six-block guard',
      () {
    /// Seeds [repo] with [googleDrive] as the active provider.
    Future<void> seedGoogleDrive(FakeAppSettingsRepository repo) async {
      await repo.setActiveProvider(SyncProvider.googleDrive);
    }

    test('EC-10_block1_updateBackupState_preserves_activeProvider_googleDrive',
        () async {
      final repo = FakeAppSettingsRepository();
      await seedGoogleDrive(repo);
      await repo.updateBackupState(dropboxEmail: 'a@b', lastBackupAt: null);
      final s = await repo.getOrCreate();
      expect(
        s.activeProvider,
        equals(SyncProvider.googleDrive),
        reason:
            'updateBackupState (block 1) must not reset activeProvider to dropbox',
      );
    });

    test(
        'EC-10_block2_markOnboardingComplete_preserves_activeProvider_googleDrive',
        () async {
      final repo = FakeAppSettingsRepository();
      await seedGoogleDrive(repo);
      await repo.markOnboardingComplete();
      final s = await repo.getOrCreate();
      expect(
        s.activeProvider,
        equals(SyncProvider.googleDrive),
        reason:
            'markOnboardingComplete (block 2) must not reset activeProvider to dropbox',
      );
    });

    test(
        'EC-10_block3_saveDeclaredCycleLength_preserves_activeProvider_googleDrive',
        () async {
      final repo = FakeAppSettingsRepository();
      await seedGoogleDrive(repo);
      await repo.saveDeclaredCycleLength(28);
      final s = await repo.getOrCreate();
      expect(
        s.activeProvider,
        equals(SyncProvider.googleDrive),
        reason:
            'saveDeclaredCycleLength (block 3) must not reset activeProvider to dropbox',
      );
    });

    test(
        'EC-10_block4_updateLastDataWriteAt_preserves_activeProvider_googleDrive',
        () async {
      final repo = FakeAppSettingsRepository();
      await seedGoogleDrive(repo);
      await repo.updateLastDataWriteAt(DateTime.utc(2026, 6, 24));
      final s = await repo.getOrCreate();
      expect(
        s.activeProvider,
        equals(SyncProvider.googleDrive),
        reason:
            'updateLastDataWriteAt (block 4) must not reset activeProvider to dropbox',
      );
    });

    test(
        'EC-10_block5_updateBackupSuspended_preserves_activeProvider_googleDrive',
        () async {
      final repo = FakeAppSettingsRepository();
      await seedGoogleDrive(repo);
      await repo.updateBackupSuspended(true);
      final s = await repo.getOrCreate();
      expect(
        s.activeProvider,
        equals(SyncProvider.googleDrive),
        reason:
            'updateBackupSuspended (block 5) must not reset activeProvider to dropbox',
      );
    });

    test(
        'EC-10_block6_clearBackupSuspended_preserves_activeProvider_googleDrive',
        () async {
      final repo = FakeAppSettingsRepository();
      await seedGoogleDrive(repo);
      await repo.clearBackupSuspended();
      final s = await repo.getOrCreate();
      expect(
        s.activeProvider,
        equals(SyncProvider.googleDrive),
        reason:
            'clearBackupSuspended (block 6) must not reset activeProvider to dropbox',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // setActiveProvider override — FR-13, NFR-05
  // ---------------------------------------------------------------------------
  group('FakeAppSettingsRepository.setActiveProvider', () {
    test(
        'setActiveProvider_iCloud_emits_AppSettingsData_with_activeProvider_iCloud_and_every_other_field_unchanged',
        () async {
      final repo = FakeAppSettingsRepository();
      // Seed with a fully-populated entity so we can assert NO other field flips.
      repo.storedSettings = AppSettingsData(
        languageCode: 'it',
        darkMode: true,
        painEnabled: true,
        notesEnabled: false,
        notificationDaysBefore: 3,
        notificationsEnabled: true,
        dropboxEmail: 'x@y.com',
        lastBackupAt: DateTime.utc(2026, 1, 15),
        onboardingCompleted: true,
        declaredCycleLength: 29,
        notificationTimeMinutes: 600,
        firstDayOfWeek: FirstDayOfWeekSetting.monday,
        lastLogOrSymptomWriteAt: DateTime.utc(2026, 5, 1),
        backupSuspended: false,
        activeProvider: SyncProvider.dropbox,
      );

      await repo.setActiveProvider(SyncProvider.iCloud);

      final s = await repo.getOrCreate();
      expect(s.activeProvider, equals(SyncProvider.iCloud));
      // Every other field must be preserved byte-for-byte.
      expect(s.languageCode, equals('it'));
      expect(s.darkMode, isTrue);
      expect(s.painEnabled, isTrue);
      expect(s.notesEnabled, isFalse);
      expect(s.notificationDaysBefore, equals(3));
      expect(s.notificationsEnabled, isTrue);
      expect(s.dropboxEmail, equals('x@y.com'));
      expect(s.lastBackupAt, equals(DateTime.utc(2026, 1, 15)));
      expect(s.onboardingCompleted, isTrue);
      expect(s.declaredCycleLength, equals(29));
      expect(s.notificationTimeMinutes, equals(600));
      expect(s.firstDayOfWeek, equals(FirstDayOfWeekSetting.monday));
      expect(s.lastLogOrSymptomWriteAt, equals(DateTime.utc(2026, 5, 1)));
      expect(s.backupSuspended, isFalse);
    });

    test('setActiveProvider_defaults_to_dropbox', () async {
      final repo = FakeAppSettingsRepository();
      final s = await repo.getOrCreate();
      expect(s.activeProvider, equals(SyncProvider.dropbox));
    });
  });

  group('FakeAppSettingsRepository updateLastDataWriteAt', () {
    test(
        'given_fresh_fake_when_updateLastDataWriteAt_then_field_set_and_others_unchanged',
        () async {
      final fake = FakeAppSettingsRepository();
      fake.storedSettings = AppSettingsData.defaults().copyWith(
        languageCode: 'en',
      );
      final t1 = DateTime.utc(2026, 5, 14, 10);
      await fake.updateLastDataWriteAt(t1);
      final after = await fake.getOrCreate();
      expect(after.lastLogOrSymptomWriteAt, equals(t1));
      expect(after.languageCode, 'en'); // unrelated field unchanged
    });

    test(
        'given_lastLogOrSymptomWriteAt_set_when_updateBackupState_then_field_preserved',
        () async {
      final fake = FakeAppSettingsRepository();
      final t1 = DateTime.utc(2026, 5, 14, 10);
      await fake.updateLastDataWriteAt(t1);
      await fake.updateBackupState(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
      );
      final after = await fake.getOrCreate();
      expect(after.lastLogOrSymptomWriteAt, equals(t1));
    });

    test(
        'given_lastLogOrSymptomWriteAt_set_when_markOnboardingComplete_then_field_preserved',
        () async {
      final fake = FakeAppSettingsRepository();
      final t1 = DateTime.utc(2026, 5, 14, 10);
      await fake.updateLastDataWriteAt(t1);
      await fake.markOnboardingComplete();
      final after = await fake.getOrCreate();
      expect(after.lastLogOrSymptomWriteAt, equals(t1));
    });

    test(
        'given_lastLogOrSymptomWriteAt_set_when_saveDeclaredCycleLength_then_field_preserved',
        () async {
      final fake = FakeAppSettingsRepository();
      final t1 = DateTime.utc(2026, 5, 14, 10);
      await fake.updateLastDataWriteAt(t1);
      await fake.saveDeclaredCycleLength(28);
      final after = await fake.getOrCreate();
      expect(after.lastLogOrSymptomWriteAt, equals(t1));
    });
  });
}
