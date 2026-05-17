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
