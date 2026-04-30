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
import 'package:metra/domain/use_cases/complete_onboarding.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/fake_cycle_entry_repository.dart';

void main() {
  late FakeCycleEntryRepository cycleRepo;
  late FakeAppSettingsRepository settingsRepo;
  late CompleteOnboarding useCase;

  setUp(() {
    cycleRepo = FakeCycleEntryRepository();
    settingsRepo = FakeAppSettingsRepository();
    useCase = CompleteOnboarding(cycleRepo, settingsRepo);
  });

  final lastPeriod = DateTime.utc(2026, 4, 1);

  test('inserts seed CycleEntry with given startDate, cycleLength, and periodLength',
      () async {
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 28,
      periodLength: 3,
    );

    expect(cycleRepo.entries, hasLength(1));
    expect(cycleRepo.entries.first.startDate, lastPeriod);
    expect(cycleRepo.entries.first.cycleLength, 28);
    expect(cycleRepo.entries.first.endDate, isNull);
    expect(cycleRepo.entries.first.periodLength, 3);
  });

  test('marks onboarding complete in settings', () async {
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 28,
      periodLength: 3,
    );

    final settings = await settingsRepo.getOrCreate();
    expect(settings.onboardingCompleted, isTrue);
  });

  test('uses provided cycleLength, not a hardcoded default', () async {
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 35,
      periodLength: 3,
    );

    expect(cycleRepo.entries.first.cycleLength, 35);
  });

  test('uses provided periodLength, not a hardcoded default', () async {
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 28,
      periodLength: 5,
    );

    expect(cycleRepo.entries.first.periodLength, 5);
  });
}
