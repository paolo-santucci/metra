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
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1,
        startDate: jan15,
        endDate: jan20,
        cycleLength: 28,
        periodLength: 6,
      ));
      final uc = GetCycleSummaries(FakeDailyLogRepository(), cycleRepo);
      final result = await uc().first;
      expect(result, hasLength(1));
      expect(result.first.symptoms, isEmpty);
      expect(result.first.dominantFlow, isNull);
    });

    test('extracts distinct symptoms from logs in range', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1,
        startDate: jan15,
        endDate: jan20,
        cycleLength: 28,
        periodLength: 6,
      ));
      for (int d = 15; d <= 20; d++) {
        logRepo.savedLogs.add(DailyLogEntity(
          date: DateTime.utc(2026, 1, d),
          flowIntensity: FlowIntensity.medium,
        ));
      }
      logRepo.symptoms[jan15] = [
        PainSymptomData(symptomType: PainSymptomType.cramps),
      ];
      logRepo.symptoms[jan16] = [
        PainSymptomData(symptomType: PainSymptomType.cramps),
      ];
      logRepo.symptoms[jan17] = [
        PainSymptomData(symptomType: PainSymptomType.backPain),
      ];

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;

      expect(
        result.first.symptoms,
        containsAll([PainSymptomType.cramps, PainSymptomType.backPain]),
      );
      expect(result.first.symptoms, hasLength(2));
    });

    test('computes dominant flow as mode; highest ordinal wins on tie',
        () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1,
        startDate: jan15,
        endDate: jan20,
        cycleLength: 28,
        periodLength: 6,
      ));
      // 2 × light, 2 × medium → tie → medium wins (higher ordinal)
      logRepo.savedLogs.addAll([
        DailyLogEntity(date: jan15, flowIntensity: FlowIntensity.light),
        DailyLogEntity(date: jan16, flowIntensity: FlowIntensity.light),
        DailyLogEntity(date: jan17, flowIntensity: FlowIntensity.medium),
        DailyLogEntity(date: jan18, flowIntensity: FlowIntensity.medium),
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
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1,
        startDate: todayNorm,
        endDate: null,
        cycleLength: null,
        periodLength: null,
      ));
      logRepo.savedLogs.add(
        DailyLogEntity(date: todayNorm, flowIntensity: FlowIntensity.heavy),
      );

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result, hasLength(1));
      expect(result.first.dominantFlow, FlowIntensity.heavy);
    });

    test('does not include custom symptom type', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1,
        startDate: jan15,
        endDate: jan20,
        cycleLength: 28,
        periodLength: 6,
      ));
      logRepo.savedLogs.add(
        DailyLogEntity(date: jan15, flowIntensity: FlowIntensity.light),
      );
      logRepo.symptoms[jan15] = [
        PainSymptomData(
          symptomType: PainSymptomType.custom,
          customLabel: 'nausea',
        ),
      ];

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result.first.symptoms, isEmpty);
    });
  });
}
