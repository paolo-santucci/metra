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
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/use_cases/get_cycle_summaries.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

// Helpers used in this test file only.
final jan16 = DateTime.utc(2026, 1, 16);
final jan17 = DateTime.utc(2026, 1, 17);
final jan18 = DateTime.utc(2026, 1, 18);

void main() {
  final jan15 = DateTime.utc(2026, 1, 15);
  final jan20 = DateTime.utc(2026, 1, 20);
  final feb12 = DateTime.utc(2026, 2, 12);
  final feb17 = DateTime.utc(2026, 2, 17);

  group('GetCycleSummaries', () {
    test('returns empty list when no cycles', () async {
      final uc = GetCycleSummaries(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
      );
      expect(await uc().first, isEmpty);
    });

    test('returns one summary for one cycle with no logs', () async {
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: jan15,
          endDate: jan20,
          cycleLength: 28,
          periodLength: 6,
        ),
      );
      final uc = GetCycleSummaries(FakeDailyLogRepository(), cycleRepo);
      final result = await uc().first;
      expect(result, hasLength(1));
      expect(result.first.symptoms, isEmpty);
      expect(result.first.dominantFlow, isNull);
    });

    test('extracts distinct symptoms from logs in range', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: jan15,
          endDate: jan20,
          cycleLength: 28,
          periodLength: 6,
        ),
      );
      for (int d = 15; d <= 20; d++) {
        logRepo.savedLogs.add(
          DailyLogEntity(
            date: DateTime.utc(2026, 1, d),
            flowIntensity: FlowIntensity.medium,
          ),
        );
      }
      logRepo.symptoms[jan15] = [
        const PainSymptomData(symptomType: PainSymptomType.headache),
      ];
      logRepo.symptoms[jan16] = [
        const PainSymptomData(symptomType: PainSymptomType.headache),
      ];
      logRepo.symptoms[jan17] = [
        const PainSymptomData(symptomType: PainSymptomType.backPain),
      ];

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;

      expect(
        result.first.symptoms,
        containsAll([
          const PainSymptomData(symptomType: PainSymptomType.headache),
          const PainSymptomData(symptomType: PainSymptomType.backPain),
        ]),
      );
      expect(result.first.symptoms, hasLength(2));
    });

    test('computes dominant flow as mode; highest ordinal wins on tie',
        () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: jan15,
          endDate: jan20,
          cycleLength: 28,
          periodLength: 6,
        ),
      );
      // 2 × light, 2 × medium → tie → medium wins (higher ordinal)
      logRepo.savedLogs.addAll([
        DailyLogEntity(
          date: jan15,
          flowType: FlowType.mestruazioni,
          flowIntensity: FlowIntensity.light,
        ),
        DailyLogEntity(
          date: jan16,
          flowType: FlowType.mestruazioni,
          flowIntensity: FlowIntensity.light,
        ),
        DailyLogEntity(
          date: jan17,
          flowType: FlowType.mestruazioni,
          flowIntensity: FlowIntensity.medium,
        ),
        DailyLogEntity(
          date: jan18,
          flowType: FlowType.mestruazioni,
          flowIntensity: FlowIntensity.medium,
        ),
      ]);

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result.first.dominantFlow, FlowIntensity.medium);
    });

    test('sorts newest-first when multiple cycles', () async {
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.addAll([
        CycleEntryEntity(
          id: 1,
          startDate: jan15,
          endDate: jan20,
          cycleLength: 28,
          periodLength: 6,
        ),
        CycleEntryEntity(
          id: 2,
          startDate: feb12,
          endDate: feb17,
          cycleLength: null,
          periodLength: 6,
        ),
      ]);
      final uc = GetCycleSummaries(FakeDailyLogRepository(), cycleRepo);
      final result = await uc().first;
      expect(result.first.cycle.startDate, feb12);
      expect(result.last.cycle.startDate, jan15);
    });

    test('in-progress cycle (endDate null) included with today as upper bound',
        () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      final today = DateTime.now().toUtc();
      final todayNorm = DateTime.utc(today.year, today.month, today.day);
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: todayNorm,
          endDate: null,
          cycleLength: null,
          periodLength: null,
        ),
      );
      logRepo.savedLogs.add(
        DailyLogEntity(
          date: todayNorm,
          flowType: FlowType.mestruazioni,
          flowIntensity: FlowIntensity.heavy,
        ),
      );

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result, hasLength(1));
      expect(result.first.dominantFlow, FlowIntensity.heavy);
    });

    test('includes custom symptom with its label', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: jan15,
          endDate: jan20,
          cycleLength: 28,
          periodLength: 6,
        ),
      );
      logRepo.savedLogs.add(
        DailyLogEntity(date: jan15, flowIntensity: FlowIntensity.light),
      );
      logRepo.symptoms[jan15] = [
        const PainSymptomData(
          symptomType: PainSymptomType.custom,
          customLabel: 'nausea',
        ),
      ];

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result.first.symptoms, hasLength(1));
      expect(
        result.first.symptoms.first,
        const PainSymptomData(
          symptomType: PainSymptomType.custom,
          customLabel: 'nausea',
        ),
      );
    });

    test(
      'given_all_logs_painEnabled_false_when_computing_dominantPain_then_null',
      () async {
        final logRepo = FakeDailyLogRepository();
        final cycleRepo = FakeCycleEntryRepository();
        cycleRepo.entries.add(
          CycleEntryEntity(
            id: 1,
            startDate: jan15,
            endDate: jan20,
            cycleLength: 28,
            periodLength: 6,
          ),
        );
        logRepo.savedLogs.addAll([
          DailyLogEntity(date: jan15, painEnabled: false, painIntensity: null),
          DailyLogEntity(date: jan16, painEnabled: false, painIntensity: null),
        ]);

        final uc = GetCycleSummaries(logRepo, cycleRepo);
        final result = await uc().first;
        expect(result.first.dominantPainIntensity, isNull);
      },
    );

    test(
      'given_all_logs_painEnabled_true_but_intensity_zero_when_computing_dominantPain_then_null',
      () async {
        final logRepo = FakeDailyLogRepository();
        final cycleRepo = FakeCycleEntryRepository();
        cycleRepo.entries.add(
          CycleEntryEntity(
            id: 1,
            startDate: jan15,
            endDate: jan20,
            cycleLength: 28,
            periodLength: 6,
          ),
        );
        logRepo.savedLogs.addAll([
          DailyLogEntity(date: jan15, painEnabled: true, painIntensity: 0),
          DailyLogEntity(date: jan16, painEnabled: true, painIntensity: 0),
        ]);

        final uc = GetCycleSummaries(logRepo, cycleRepo);
        final result = await uc().first;
        expect(result.first.dominantPainIntensity, isNull);
      },
    );

    test(
      'given_single_qualifying_log_painIntensity_2_when_computing_dominantPain_then_2',
      () async {
        final logRepo = FakeDailyLogRepository();
        final cycleRepo = FakeCycleEntryRepository();
        cycleRepo.entries.add(
          CycleEntryEntity(
            id: 1,
            startDate: jan15,
            endDate: jan20,
            cycleLength: 28,
            periodLength: 6,
          ),
        );
        logRepo.savedLogs.add(
          DailyLogEntity(date: jan15, painEnabled: true, painIntensity: 2),
        );

        final uc = GetCycleSummaries(logRepo, cycleRepo);
        final result = await uc().first;
        expect(result.first.dominantPainIntensity, 2);
      },
    );

    test(
      'given_multiple_logs_mode_is_3_when_computing_dominantPain_then_3',
      () async {
        final logRepo = FakeDailyLogRepository();
        final cycleRepo = FakeCycleEntryRepository();
        cycleRepo.entries.add(
          CycleEntryEntity(
            id: 1,
            startDate: jan15,
            endDate: jan20,
            cycleLength: 28,
            periodLength: 6,
          ),
        );
        // 3 appears twice, 1 appears once → mode is 3
        logRepo.savedLogs.addAll([
          DailyLogEntity(date: jan15, painEnabled: true, painIntensity: 3),
          DailyLogEntity(date: jan16, painEnabled: true, painIntensity: 3),
          DailyLogEntity(date: jan17, painEnabled: true, painIntensity: 1),
        ]);

        final uc = GetCycleSummaries(logRepo, cycleRepo);
        final result = await uc().first;
        expect(result.first.dominantPainIntensity, 3);
      },
    );

    test(
      'given_tie_two_logs_intensity_1_two_logs_intensity_2_when_computing_dominantPain_then_2',
      () async {
        final logRepo = FakeDailyLogRepository();
        final cycleRepo = FakeCycleEntryRepository();
        cycleRepo.entries.add(
          CycleEntryEntity(
            id: 1,
            startDate: jan15,
            endDate: jan20,
            cycleLength: 28,
            periodLength: 6,
          ),
        );
        // 2 × intensity 1, 2 × intensity 2 → tie → highest wins → 2
        logRepo.savedLogs.addAll([
          DailyLogEntity(date: jan15, painEnabled: true, painIntensity: 1),
          DailyLogEntity(date: jan16, painEnabled: true, painIntensity: 1),
          DailyLogEntity(date: jan17, painEnabled: true, painIntensity: 2),
          DailyLogEntity(date: jan18, painEnabled: true, painIntensity: 2),
        ]);

        final uc = GetCycleSummaries(logRepo, cycleRepo);
        final result = await uc().first;
        expect(result.first.dominantPainIntensity, 2);
      },
    );

    test(
      'given_trailing_cycle_endDate_is_last_bleed_day_when_symptom_logged_after_endDate_then_included_in_summary',
      () async {
        final logRepo = FakeDailyLogRepository();
        final cycleRepo = FakeCycleEntryRepository();
        final today = DateTime.now().toUtc();
        final todayNorm = DateTime.utc(today.year, today.month, today.day);
        final d30 = todayNorm.subtract(const Duration(days: 30));
        final d25 = todayNorm.subtract(const Duration(days: 25));
        final d3 = todayNorm.subtract(const Duration(days: 3));

        // Trailing cycle: period D-30..D-25; endDate is last bleed day D-25.
        cycleRepo.entries.add(
          CycleEntryEntity(
            id: 1,
            startDate: d30,
            endDate: d25,
            cycleLength: null,
            periodLength: 6,
          ),
        );

        // Period logs D-30..D-25
        for (var d = d30; !d.isAfter(d25); d = d.add(const Duration(days: 1))) {
          logRepo.savedLogs.add(
            DailyLogEntity(date: d, flowType: FlowType.mestruazioni),
          );
        }

        // Non-period symptom log at D-3 (after endDate D-25, before today).
        logRepo.savedLogs.add(DailyLogEntity(date: d3));
        logRepo.symptoms[d3] = [
          const PainSymptomData(symptomType: PainSymptomType.headache),
        ];

        final uc = GetCycleSummaries(logRepo, cycleRepo);
        final result = await uc().first;
        expect(
          result.first.symptoms,
          contains(
            const PainSymptomData(symptomType: PainSymptomType.headache),
          ),
        );
      },
    );

    test('hasNote is false when no log in range has a note', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: jan15,
          endDate: jan20,
          cycleLength: 28,
          periodLength: 6,
        ),
      );
      logRepo.savedLogs.add(
        DailyLogEntity(date: jan15, notes: null),
      );

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result.first.hasNote, isFalse);
    });

    test('hasNote is true when at least one log in range has a note', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: jan15,
          endDate: jan20,
          cycleLength: 28,
          periodLength: 6,
        ),
      );
      logRepo.savedLogs.addAll([
        DailyLogEntity(date: jan15, notes: null),
        DailyLogEntity(date: jan16, notes: 'felt off'),
      ]);

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result.first.hasNote, isTrue);
    });

    test('hasNote ignores empty string notes', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: jan15,
          endDate: jan20,
          cycleLength: 28,
          periodLength: 6,
        ),
      );
      logRepo.savedLogs.add(
        DailyLogEntity(date: jan15, notes: ''),
      );

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result.first.hasNote, isFalse);
    });

    test(
      'given_two_cycles_when_non_trailing_cycle_has_log_after_its_endDate_then_log_not_included_in_older_cycle_summary',
      () async {
        final logRepo = FakeDailyLogRepository();
        final cycleRepo = FakeCycleEntryRepository();
        final today = DateTime.now().toUtc();
        final todayNorm = DateTime.utc(today.year, today.month, today.day);

        // Older cycle: D-60..D-55
        final olderStart = todayNorm.subtract(const Duration(days: 60));
        final olderEnd = todayNorm.subtract(const Duration(days: 55));
        // Trailing cycle: D-25..D-20
        final trailingStart = todayNorm.subtract(const Duration(days: 25));
        final trailingEnd = todayNorm.subtract(const Duration(days: 20));

        cycleRepo.entries.addAll([
          CycleEntryEntity(
            id: 1,
            startDate: olderStart,
            endDate: olderEnd,
            cycleLength: 35,
            periodLength: 6,
          ),
          CycleEntryEntity(
            id: 2,
            startDate: trailingStart,
            endDate: trailingEnd,
            cycleLength: null,
            periodLength: 6,
          ),
        ]);

        // Orphan log at D-50: after olderEnd (D-55) but before trailingStart (D-25).
        final orphanDate = todayNorm.subtract(const Duration(days: 50));
        logRepo.savedLogs.add(DailyLogEntity(date: orphanDate));
        logRepo.symptoms[orphanDate] = [
          const PainSymptomData(symptomType: PainSymptomType.headache),
        ];

        final uc = GetCycleSummaries(logRepo, cycleRepo);
        final result = await uc().first;

        // result is sorted newest-first; older cycle is result.last
        final olderSummary = result.last;
        expect(
          olderSummary.symptoms,
          isNot(
            contains(
              const PainSymptomData(symptomType: PainSymptomType.headache),
            ),
          ),
        );
      },
    );
  });
}
