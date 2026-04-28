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

import '../entities/cycle_stats_data.dart';
import '../entities/cycle_summary.dart';
import '../entities/pain_symptom_type.dart';
import 'get_cycle_summaries.dart';

class ComputeCycleStats {
  const ComputeCycleStats(this._getCycleSummaries);

  final GetCycleSummaries _getCycleSummaries;

  Stream<CycleStatsData?> call() => _getCycleSummaries().map(_compute);

  static CycleStatsData? _compute(List<CycleSummary> summaries) {
    final complete = summaries
        .where((s) => s.cycle.endDate != null && s.cycle.cycleLength != null)
        .toList();
    if (complete.isEmpty) return null;

    // GetCycleSummaries returns newest-first; reverse for oldest-first points.
    final points = complete.reversed
        .map(
          (s) => CycleDataPoint(
            startDate: s.cycle.startDate,
            cycleLength: s.cycle.cycleLength!,
            periodLength: s.cycle.periodLength,
            dominantFlow: s.dominantFlow,
          ),
        )
        .toList();

    const fixedTypes = [
      PainSymptomType.cramps,
      PainSymptomType.backPain,
      PainSymptomType.headache,
      PainSymptomType.migraine,
      PainSymptomType.bloating,
    ];
    final frequencies = <PainSymptomType, double>{
      for (final type in fixedTypes)
        type: complete.where((s) => s.symptoms.contains(type)).length /
            complete.length,
    };

    return CycleStatsData(points: points, symptomFrequencies: frequencies);
  }
}
