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
import 'package:metra/domain/use_cases/get_or_create_settings.dart';

import '../../helpers/fake_app_settings_repository.dart';

void main() {
  late FakeAppSettingsRepository repo;
  late GetOrCreateSettings useCase;

  setUp(() {
    repo = FakeAppSettingsRepository();
    useCase = GetOrCreateSettings(repo);
  });

  test('returns defaults when no settings exist', () async {
    final settings = await useCase();
    expect(settings, equals(const AppSettingsData.defaults()));
  });

  test('returns existing settings when already set', () async {
    const custom = AppSettingsData(
      languageCode: 'en',
      painEnabled: false,
      notesEnabled: true,
      notificationDaysBefore: 1,
      notificationsEnabled: true,
    );
    repo.storedSettings = custom;

    final result = await useCase();
    expect(result, equals(custom));
  });
}
