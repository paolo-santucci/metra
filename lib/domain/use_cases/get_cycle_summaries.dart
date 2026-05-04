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
import '../entities/flow_type.dart';
import '../entities/pain_symptom_data.dart';
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

    final today = DateTime.now().toUtc();
    final todayNorm = DateTime.utc(today.year, today.month, today.day);

    // The trailing (current) cycle is the one with the greatest startDate.
    // Its range must extend to today so non-period logs recorded after the
    // last bleed day (endDate) are still included in the summary.
    final trailingStart =
        cycles.map((c) => c.startDate).reduce((a, b) => a.isAfter(b) ? a : b);

    final summaries = await Future.wait(
      cycles.map((cycle) async {
        final isTrailing = cycle.startDate == trailingStart;
        final rangeEnd = isTrailing ? todayNorm : (cycle.endDate ?? todayNorm);

        final logsInRange = allLogs
            .where(
              (l) =>
                  !l.date.isBefore(cycle.startDate) &&
                  !l.date.isAfter(rangeEnd),
            )
            .toList();

        // Collect distinct symptom entries across the cycle (including custom).
        final symptomSet = <PainSymptomData>{};
        for (final log in logsInRange) {
          final symptoms = await _logRepo.getPainSymptoms(log.date);
          symptomSet.addAll(symptoms);
        }

        // Compute dominant flow: mode with highest ordinal winning ties.
        // Only menstruation days contribute (assente/spotting/null excluded).
        final flowCounts = <FlowIntensity, int>{};
        for (final log in logsInRange) {
          if (log.flowType != FlowType.mestruazioni) continue;
          final fi = log.flowIntensity;
          if (fi != null) {
            flowCounts[fi] = (flowCounts[fi] ?? 0) + 1;
          }
        }
        FlowIntensity? dominant;
        var maxFlowCount = 0;
        for (final entry in flowCounts.entries) {
          if (entry.value > maxFlowCount ||
              (entry.value == maxFlowCount &&
                  (dominant == null || entry.key.index > dominant.index))) {
            maxFlowCount = entry.value;
            dominant = entry.key;
          }
        }

        // Compute dominant pain intensity: mode with highest value winning ties.
        // Only logs with painEnabled=true and painIntensity > 0 contribute.
        final painCounts = <int, int>{};
        for (final log in logsInRange) {
          final intensity = log.painIntensity;
          if (!log.painEnabled || intensity == null || intensity <= 0) continue;
          painCounts[intensity] = (painCounts[intensity] ?? 0) + 1;
        }
        int? dominantPain;
        var maxPainCount = 0;
        for (final entry in painCounts.entries) {
          if (entry.value > maxPainCount ||
              (entry.value == maxPainCount &&
                  (dominantPain == null || entry.key > dominantPain))) {
            maxPainCount = entry.value;
            dominantPain = entry.key;
          }
        }

        final hasNote = logsInRange.any(
          (l) => l.notes != null && l.notes!.isNotEmpty,
        );

        return CycleSummary(
          cycle: cycle,
          symptoms: symptomSet.toList(),
          dominantFlow: dominant,
          dominantPainIntensity: dominantPain,
          hasNote: hasNote,
        );
      }),
    );

    summaries.sort(
      (a, b) => b.cycle.startDate.compareTo(a.cycle.startDate),
    );
    return summaries;
  }
}
