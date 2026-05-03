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
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/use_cases/complete_onboarding.dart';
import 'package:metra/domain/use_cases/recompute_cycle_entries.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

void main() {
  late FakeCycleEntryRepository cycleRepo;
  late FakeAppSettingsRepository settingsRepo;
  late FakeDailyLogRepository logRepo;
  late CompleteOnboarding useCase;

  setUp(() {
    cycleRepo = FakeCycleEntryRepository();
    settingsRepo = FakeAppSettingsRepository();
    logRepo = FakeDailyLogRepository();
    useCase = CompleteOnboarding(
      cycleRepo,
      settingsRepo,
      logRepo,
      RecomputeCycleEntries(logRepo, cycleRepo),
    );
  });

  final lastPeriod = DateTime.utc(2026, 4, 1);

  test(
      'inserts seed CycleEntry with given startDate, cycleLength, and periodLength',
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

  test(
    'given_existing_mestruazioni_logs_when_execute_then_cycle_entries_reflect_all_periods',
    () async {
      // Two distinct menstrual periods separated by 28 days.
      final period1Start = DateTime.utc(2026, 1, 1);
      final period2Start = DateTime.utc(2026, 1, 29);
      for (var i = 0; i < 5; i++) {
        await logRepo.saveDailyLog(
          DailyLogEntity(
            date: period1Start.add(Duration(days: i)),
            flowType: FlowType.mestruazioni,
            flowIntensity: FlowIntensity.medium,
          ),
        );
        await logRepo.saveDailyLog(
          DailyLogEntity(
            date: period2Start.add(Duration(days: i)),
            flowType: FlowType.mestruazioni,
            flowIntensity: FlowIntensity.medium,
          ),
        );
      }

      await useCase.execute(
        lastPeriodDate: lastPeriod,
        cycleLength: 28,
        periodLength: 5,
      );

      // Recompute must have produced 2 entries from the logs (not just 1 seed).
      expect(cycleRepo.entries, hasLength(2));
    },
  );

  test(
    'given_no_daily_logs_when_execute_then_seed_entry_is_preserved',
    () async {
      await useCase.execute(
        lastPeriodDate: lastPeriod,
        cycleLength: 28,
        periodLength: 5,
      );

      // No logs → recompute is a no-op → seed must survive.
      expect(cycleRepo.entries, hasLength(1));
      expect(cycleRepo.entries.first.startDate, lastPeriod);
      expect(cycleRepo.entries.first.cycleLength, 28);
    },
  );
}
