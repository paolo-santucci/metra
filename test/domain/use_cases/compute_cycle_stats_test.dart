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
import 'package:metra/domain/entities/pain_trend.dart';
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

// Three cycles with pain intensities [3, 2, 1] (oldest→newest).
// First half mean = 3.0, second half mean = 1.5 (midpoint = 1, so secondHalf=[2,1]).
// Actually for 3 values: midpoint=1, first=[3], second=[2,1], firstMean=3.0, secondMean=1.5 → diff=-1.5 → decreasing.
Future<ComputeCycleStats> _makePainTrendUseCase({
  required List<int> painIntensities,
}) async {
  final cycleRepo = FakeCycleEntryRepository();
  final logRepo = FakeDailyLogRepository();

  for (var i = 0; i < painIntensities.length; i++) {
    final start = DateTime.utc(2026, 1 + i, 15);
    final end = DateTime.utc(2026, 1 + i, 20);
    cycleRepo.entries.add(
      CycleEntryEntity(
        id: i + 1,
        startDate: start,
        endDate: end,
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    logRepo.savedLogs.add(
      DailyLogEntity(
        date: start,
        painEnabled: true,
        painIntensity: painIntensities[i],
      ),
    );
  }

  return ComputeCycleStats(GetCycleSummaries(logRepo, cycleRepo));
}

void main() {
  group('ComputeCycleStats', () {
    test('returns null when no cycles', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries());
      expect(await uc().first, isNull);
    });

    test('returns null when only in-progress cycle (no cycleLength)', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
            CycleEntryEntity(
              id: 1,
              startDate: DateTime.utc(2026, 4, 13),
              endDate: null,
              cycleLength: null,
              periodLength: null,
            ),
          ],
        ),
      );
      expect(await uc().first, isNull);
    });

    test('returns one data point for one complete cycle', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
            CycleEntryEntity(
              id: 1,
              startDate: DateTime.utc(2026, 1, 15),
              endDate: DateTime.utc(2026, 1, 20),
              cycleLength: 28,
              periodLength: 6,
            ),
          ],
        ),
      );
      final result = await uc().first;
      expect(result, isNotNull);
      expect(result!.points, hasLength(1));
      expect(result.points.first.cycleLength, 28);
      expect(result.points.first.periodLength, 6);
    });

    test('points are oldest-first', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
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
          ],
        ),
      );
      final result = await uc().first;
      expect(result!.points.first.startDate, DateTime.utc(2026, 1, 15));
      expect(result.points.last.startDate, DateTime.utc(2026, 2, 12));
    });

    test('excludes in-progress cycle from points', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
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
          ],
        ),
      );
      final result = await uc().first;
      expect(result!.points, hasLength(1));
    });

    test('symptomCounts contains all 8 fixed types', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
            CycleEntryEntity(
              id: 1,
              startDate: DateTime.utc(2026, 1, 15),
              endDate: DateTime.utc(2026, 1, 20),
              cycleLength: 28,
              periodLength: 6,
            ),
          ],
        ),
      );
      final result = await uc().first;
      expect(
        result!.symptomCounts.keys,
        containsAll([
          PainSymptomType.cramps,
          PainSymptomType.backPain,
          PainSymptomType.headache,
          PainSymptomType.migraine,
          PainSymptomType.bloating,
          PainSymptomType.fatigue,
          PainSymptomType.nausea,
          PainSymptomType.breastTenderness,
        ]),
      );
      expect(
        result.symptomCounts.containsKey(PainSymptomType.custom),
        isFalse,
      );
    });

    test('symptomCounts is 1 (int) when symptom present in all cycles',
        () async {
      final cycleRepo = FakeCycleEntryRepository();
      final logRepo = FakeDailyLogRepository();
      final start = DateTime.utc(2026, 1, 15);
      final end = DateTime.utc(2026, 1, 20);
      cycleRepo.entries.add(
        CycleEntryEntity(
          id: 1,
          startDate: start,
          endDate: end,
          cycleLength: 28,
          periodLength: 6,
        ),
      );
      logRepo.savedLogs.add(
        DailyLogEntity(date: start, flowIntensity: FlowIntensity.medium),
      );
      logRepo.symptoms[start] = [
        const PainSymptomData(symptomType: PainSymptomType.cramps),
      ];

      final uc = ComputeCycleStats(GetCycleSummaries(logRepo, cycleRepo));
      final result = await uc().first;
      expect(result!.symptomCounts[PainSymptomType.cramps], 1);
    });

    test('cycleLengthAvg computed correctly for one complete cycle', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
            CycleEntryEntity(
              id: 1,
              startDate: DateTime.utc(2026, 1, 15),
              endDate: DateTime.utc(2026, 1, 20),
              cycleLength: 28,
              periodLength: 6,
            ),
          ],
        ),
      );
      final result = await uc().first;
      expect(result!.cycleLengthAvg, 28);
    });

    test('cycleLengthAvg rounds mean of multiple cycles', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
            CycleEntryEntity(
              id: 1,
              startDate: DateTime.utc(2026, 1, 15),
              endDate: DateTime.utc(2026, 1, 20),
              cycleLength: 28,
              periodLength: 5,
            ),
            CycleEntryEntity(
              id: 2,
              startDate: DateTime.utc(2026, 2, 12),
              endDate: DateTime.utc(2026, 2, 17),
              cycleLength: 29,
              periodLength: 5,
            ),
            CycleEntryEntity(
              id: 3,
              startDate: DateTime.utc(2026, 3, 13),
              endDate: DateTime.utc(2026, 3, 18),
              cycleLength: 30,
              periodLength: 5,
            ),
          ],
        ),
      );
      final result = await uc().first;
      // (28 + 29 + 30) / 3 = 29
      expect(result!.cycleLengthAvg, 29);
    });

    test('cycleLengthMin and cycleLengthMax computed correctly', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
            CycleEntryEntity(
              id: 1,
              startDate: DateTime.utc(2026, 1, 15),
              endDate: DateTime.utc(2026, 1, 20),
              cycleLength: 25,
              periodLength: 5,
            ),
            CycleEntryEntity(
              id: 2,
              startDate: DateTime.utc(2026, 2, 9),
              endDate: DateTime.utc(2026, 2, 14),
              cycleLength: 32,
              periodLength: 5,
            ),
          ],
        ),
      );
      final result = await uc().first;
      expect(result!.cycleLengthMin, 25);
      expect(result.cycleLengthMax, 32);
    });

    test('painIntensityAvg is null when no pain data', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
            CycleEntryEntity(
              id: 1,
              startDate: DateTime.utc(2026, 1, 15),
              endDate: DateTime.utc(2026, 1, 20),
              cycleLength: 28,
              periodLength: 6,
            ),
          ],
        ),
      );
      final result = await uc().first;
      expect(result!.painIntensityAvg, isNull);
    });

    test('painTrend is null with fewer than 3 pain data points', () async {
      final uc = await _makePainTrendUseCase(painIntensities: [2, 3]);
      final result = await uc().first;
      expect(result!.painTrend, isNull);
    });

    test('painTrend is PainTrend.decreasing for pain series [3, 2, 1]',
        () async {
      final uc = await _makePainTrendUseCase(painIntensities: [3, 2, 1]);
      final result = await uc().first;
      expect(result!.painTrend, PainTrend.decreasing);
    });

    test('cyclesTrackedCount equals points.length', () async {
      final uc = ComputeCycleStats(
        _makeGetCycleSummaries(
          cycles: [
            CycleEntryEntity(
              id: 1,
              startDate: DateTime.utc(2026, 1, 15),
              endDate: DateTime.utc(2026, 1, 20),
              cycleLength: 28,
              periodLength: 6,
            ),
            CycleEntryEntity(
              id: 2,
              startDate: DateTime.utc(2026, 2, 12),
              endDate: DateTime.utc(2026, 2, 17),
              cycleLength: 29,
              periodLength: 5,
            ),
          ],
        ),
      );
      final result = await uc().first;
      expect(result!.cyclesTrackedCount, result.points.length);
      expect(result.cyclesTrackedCount, 2);
    });
  });
}
