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
import 'package:metra/domain/entities/app_settings_data.dart';

import 'fake_app_settings_repository.dart';

void main() {
  group('FakeAppSettingsRepository updateLastDataWriteAt', () {
    test(
        'given_fresh_fake_when_updateLastDataWriteAt_then_field_set_and_others_unchanged',
        () async {
      final fake = FakeAppSettingsRepository();
      fake.storedSettings = const AppSettingsData.defaults().copyWith(
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
