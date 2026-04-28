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

import '../entities/cycle_entry_entity.dart';
import '../entities/cycle_summary.dart';
import '../entities/flow_intensity.dart';
import '../entities/pain_symptom_type.dart';
import '../repositories/cycle_entry_repository.dart';
import '../repositories/daily_log_repository.dart';

class GetCycleSummaries {
  const GetCycleSummaries(this._logRepo, this._cycleRepo);

  final DailyLogRepository _logRepo;
  final CycleEntryRepository _cycleRepo;

  Stream<List<CycleSummary>> call() {
    return _cycleRepo.watchAll().asyncMap(_enrich);
  }

  Future<List<CycleSummary>> _enrich(List<CycleEntryEntity> cycles) async {
    if (cycles.isEmpty) return const [];

    final allLogs = await _logRepo.getAllOrderedByDate();

    final summaries = await Future.wait(cycles.map((cycle) async {
      final today = DateTime.now().toUtc();
      final todayNorm = DateTime.utc(today.year, today.month, today.day);
      final rangeEnd = cycle.endDate ?? todayNorm;

      final logsInRange = allLogs
          .where(
            (l) =>
                !l.date.isBefore(cycle.startDate) && !l.date.isAfter(rangeEnd),
          )
          .toList();

      // Collect distinct fixed symptom types; custom is excluded per spec.
      final symptomSet = <PainSymptomType>{};
      for (final log in logsInRange) {
        final symptoms = await _logRepo.getPainSymptoms(log.date);
        for (final s in symptoms) {
          if (s.symptomType != PainSymptomType.custom) {
            symptomSet.add(s.symptomType);
          }
        }
      }

      // Compute dominant flow: mode with highest ordinal winning ties.
      // FlowIntensity.none (index 0) is excluded — it means no flow logged.
      final flowCounts = <FlowIntensity, int>{};
      for (final log in logsInRange) {
        final fi = log.flowIntensity;
        if (fi != null && fi != FlowIntensity.none) {
          flowCounts[fi] = (flowCounts[fi] ?? 0) + 1;
        }
      }
      FlowIntensity? dominant;
      var maxCount = 0;
      for (final entry in flowCounts.entries) {
        if (entry.value > maxCount ||
            (entry.value == maxCount &&
                (dominant == null || entry.key.index > dominant.index))) {
          maxCount = entry.value;
          dominant = entry.key;
        }
      }

      return CycleSummary(
        cycle: cycle,
        symptoms: symptomSet.toList(),
        dominantFlow: dominant,
      );
    }));

    summaries.sort(
      (a, b) => b.cycle.startDate.compareTo(a.cycle.startDate),
    );
    return summaries;
  }
}
