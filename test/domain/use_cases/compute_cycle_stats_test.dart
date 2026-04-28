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
import 'package:metra/domain/use_cases/compute_cycle_stats.dart';
import 'package:metra/domain/use_cases/get_cycle_summaries.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

GetCycleSummaries _makeGetCycleSummaries({
  List<CycleEntryEntity> cycles = const [],
}) {
  final cycleRepo = FakeCycleEntryRepository();
  cycleRepo.entries.addAll(cycles);
  return GetCycleSummaries(FakeDailyLogRepository(), cycleRepo);
}

void main() {
  group('ComputeCycleStats', () {
    test('returns null when no cycles', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries());
      expect(await uc().first, isNull);
    });

    test('returns null when only in-progress cycle (no cycleLength)', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(
          id: 1,
          startDate: DateTime.utc(2026, 4, 13),
          endDate: null,
          cycleLength: null,
          periodLength: null,
        ),
      ]));
      expect(await uc().first, isNull);
    });

    test('returns one data point for one complete cycle', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(
          id: 1,
          startDate: DateTime.utc(2026, 1, 15),
          endDate: DateTime.utc(2026, 1, 20),
          cycleLength: 28,
          periodLength: 6,
        ),
      ]));
      final result = await uc().first;
      expect(result, isNotNull);
      expect(result!.points, hasLength(1));
      expect(result.points.first.cycleLength, 28);
      expect(result.points.first.periodLength, 6);
    });

    test('points are oldest-first', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(
          id: 1,
          startDate: DateTime.utc(2026, 2, 12),
          endDate: DateTime.utc(2026, 2, 17),
          cycleLength: 28,
          periodLength: 6,
        ),
        CycleEntryEntity(
          id: 2,
          startDate: DateTime.utc(2026, 1, 15),
          endDate: DateTime.utc(2026, 1, 20),
          cycleLength: 28,
          periodLength: 6,
        ),
      ]));
      final result = await uc().first;
      expect(result!.points.first.startDate, DateTime.utc(2026, 1, 15));
      expect(result.points.last.startDate, DateTime.utc(2026, 2, 12));
    });

    test('excludes in-progress cycle from points', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(
          id: 1,
          startDate: DateTime.utc(2026, 1, 15),
          endDate: DateTime.utc(2026, 1, 20),
          cycleLength: 28,
          periodLength: 6,
        ),
        CycleEntryEntity(
          id: 2,
          startDate: DateTime.utc(2026, 4, 13),
          endDate: null,
          cycleLength: null,
          periodLength: null,
        ),
      ]));
      final result = await uc().first;
      expect(result!.points, hasLength(1));
    });

    test('symptomFrequencies contains all 5 fixed types', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(
          id: 1,
          startDate: DateTime.utc(2026, 1, 15),
          endDate: DateTime.utc(2026, 1, 20),
          cycleLength: 28,
          periodLength: 6,
        ),
      ]));
      final result = await uc().first;
      expect(
          result!.symptomFrequencies.keys,
          containsAll([
            PainSymptomType.cramps,
            PainSymptomType.backPain,
            PainSymptomType.headache,
            PainSymptomType.migraine,
            PainSymptomType.bloating,
          ]));
      expect(
        result.symptomFrequencies.containsKey(PainSymptomType.custom),
        isFalse,
      );
    });

    test('symptom frequency is 1.0 when symptom present in all cycles',
        () async {
      final cycleRepo = FakeCycleEntryRepository();
      final logRepo = FakeDailyLogRepository();
      final start = DateTime.utc(2026, 1, 15);
      final end = DateTime.utc(2026, 1, 20);
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1,
        startDate: start,
        endDate: end,
        cycleLength: 28,
        periodLength: 6,
      ));
      logRepo.savedLogs.add(
          DailyLogEntity(date: start, flowIntensity: FlowIntensity.medium));
      logRepo.symptoms[start] = [
        PainSymptomData(symptomType: PainSymptomType.cramps),
      ];

      final uc = ComputeCycleStats(GetCycleSummaries(logRepo, cycleRepo));
      final result = await uc().first;
      expect(result!.symptomFrequencies[PainSymptomType.cramps], 1.0);
    });
  });
}
