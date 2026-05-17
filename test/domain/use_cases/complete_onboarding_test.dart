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
import 'package:metra/domain/entities/cycle_entry_entity.dart';
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
      'inserts seed CycleEntry as anchor (cycleLength null) with given startDate and periodLength',
      () async {
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 28,
      periodLength: 3,
    );

    expect(cycleRepo.entries, hasLength(1));
    expect(cycleRepo.entries.first.startDate, lastPeriod);
    // Strategy B: anchor entry has no measured length; declared value goes
    // to AppSettings.declaredCycleLength instead.
    expect(cycleRepo.entries.first.cycleLength, isNull);
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

  test('saves declared cycleLength to AppSettings, not to the cycle entry',
      () async {
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 35,
      periodLength: 3,
    );

    // Cycle entry must have null cycleLength (anchor only).
    expect(cycleRepo.entries.first.cycleLength, isNull);
    // Declared average must be stored in settings.
    final settings = await settingsRepo.getOrCreate();
    expect(settings.declaredCycleLength, 35);
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

      // No logs → recompute is a no-op → anchor entry must survive.
      expect(cycleRepo.entries, hasLength(1));
      expect(cycleRepo.entries.first.startDate, lastPeriod);
      // Strategy B: anchor entry has null cycleLength; declared value is in settings.
      expect(cycleRepo.entries.first.cycleLength, isNull);
    },
  );

  // ── FR-05: Idempotency guard (M2) ────────────────────────────────────────

  test('execute() twice with identical lastPeriodDate → exactly one anchor row',
      () async {
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 28,
      periodLength: 3,
    );
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 28,
      periodLength: 3,
    );

    expect(cycleRepo.entries, hasLength(1));
  });

  test(
      'execute() with lastPeriodDate = DateTime.now() (today) → succeeds (boundary: today is not future)',
      () async {
    final today = DateTime.now();
    await expectLater(
      useCase.execute(
        lastPeriodDate: today,
        cycleLength: 28,
        periodLength: 3,
      ),
      completes,
    );
  });

  test(
      'execute() with lastPeriodDate = tomorrow → throws ArgumentError (defensive future-date check)',
      () async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await expectLater(
      useCase.execute(
        lastPeriodDate: tomorrow,
        cycleLength: 28,
        periodLength: 3,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
      'execute() when getByStartDate returns non-null → returns normally, no second insert',
      () async {
    // Pre-populate the repo with an anchor entry for lastPeriod.
    await cycleRepo.insert(
      CycleEntryEntity(
        id: 0,
        startDate: lastPeriod,
        endDate: null,
        cycleLength: null,
        periodLength: 3,
      ),
    );
    final countBefore = cycleRepo.entries.length;

    // Second execute — getByStartDate returns non-null → no insert.
    await useCase.execute(
      lastPeriodDate: lastPeriod,
      cycleLength: 28,
      periodLength: 3,
    );

    expect(cycleRepo.entries.length, countBefore);
  });
}
