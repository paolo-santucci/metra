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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../helpers/fake_app_settings_repository.dart';

void main() {
  ProviderContainer makeContainer(FakeAppSettingsRepository fakeRepo) {
    return ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWith((_) async => fakeRepo),
      ],
    );
  }

  test('build() returns stored settings', () async {
    final fakeRepo = FakeAppSettingsRepository()
      ..storedSettings = const AppSettingsData(
        languageCode: 'en',
        painEnabled: false,
        notesEnabled: true,
        notificationDaysBefore: 3,
        notificationsEnabled: true,
        onboardingCompleted: false,
      );
    final container = makeContainer(fakeRepo);
    addTearDown(container.dispose);

    final settings = await container.read(settingsNotifierProvider.future);

    expect(settings.languageCode, equals('en'));
    expect(settings.painEnabled, isFalse);
    expect(settings.notificationDaysBefore, equals(3));
  });

  test('build() returns defaults when no stored settings', () async {
    final fakeRepo = FakeAppSettingsRepository();
    final container = makeContainer(fakeRepo);
    addTearDown(container.dispose);

    final settings = await container.read(settingsNotifierProvider.future);

    expect(settings.languageCode, equals('it'));
    expect(settings.painEnabled, isTrue);
    expect(settings.notificationsEnabled, isFalse);
  });

  test('save() persists to repo and updates state', () async {
    final fakeRepo = FakeAppSettingsRepository();
    final container = makeContainer(fakeRepo);
    addTearDown(container.dispose);

    await container.read(settingsNotifierProvider.future);

    const updated = AppSettingsData(
      languageCode: 'en',
      painEnabled: false,
      notesEnabled: false,
      notificationDaysBefore: 5,
      notificationsEnabled: true,
      onboardingCompleted: false,
    );
    await container.read(settingsNotifierProvider.notifier).save(updated);

    expect(fakeRepo.storedSettings, equals(updated));
    final state = container.read(settingsNotifierProvider).valueOrNull;
    expect(state, equals(updated));
  });
}
