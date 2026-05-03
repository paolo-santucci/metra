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
import '../entities/pain_trend.dart';
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
            dominantPainIntensity: s.dominantPainIntensity,
          ),
        )
        .toList();

    const fixedTypes = [
      PainSymptomType.cramps,
      PainSymptomType.backPain,
      PainSymptomType.headache,
      PainSymptomType.migraine,
      PainSymptomType.bloating,
      PainSymptomType.fatigue,
      PainSymptomType.nausea,
      PainSymptomType.breastTenderness,
    ];

    final counts = <PainSymptomType, int>{
      for (final type in fixedTypes)
        type: complete
            .where((s) => s.symptoms.any((d) => d.symptomType == type))
            .length,
    };

    final cycleLengths = points.map((p) => p.cycleLength).toList();
    final cycleLengthSum = cycleLengths.fold(0, (a, b) => a + b);
    final cycleLengthAvg = (cycleLengthSum / points.length).round();
    final cycleLengthMin = cycleLengths.reduce((a, b) => a < b ? a : b);
    final cycleLengthMax = cycleLengths.reduce((a, b) => a > b ? a : b);

    final periodLengths =
        points.map((p) => p.periodLength).whereType<int>().toList();
    double? periodLengthAvg;
    int? periodLengthMin;
    int? periodLengthMax;
    if (periodLengths.isNotEmpty) {
      final periodSum = periodLengths.fold(0, (a, b) => a + b);
      periodLengthAvg = periodSum / periodLengths.length;
      periodLengthMin = periodLengths.reduce((a, b) => a < b ? a : b);
      periodLengthMax = periodLengths.reduce((a, b) => a > b ? a : b);
    }

    final painValues =
        points.map((p) => p.dominantPainIntensity).whereType<int>().toList();
    double? painIntensityAvg;
    PainTrend? painTrend;
    if (painValues.isNotEmpty) {
      final painSum = painValues.fold(0, (a, b) => a + b);
      painIntensityAvg = painSum / painValues.length;
    }
    if (painValues.length >= 3) {
      painTrend = _computePainTrend(painValues);
    }

    return CycleStatsData(
      points: points,
      cycleLengthAvg: cycleLengthAvg,
      cycleLengthMin: cycleLengthMin,
      cycleLengthMax: cycleLengthMax,
      periodLengthAvg: periodLengthAvg,
      periodLengthMin: periodLengthMin,
      periodLengthMax: periodLengthMax,
      painIntensityAvg: painIntensityAvg,
      painTrend: painTrend,
      cyclesTrackedCount: points.length,
      symptomCounts: counts,
    );
  }

  static PainTrend _computePainTrend(List<int> painValues) {
    final midpoint = painValues.length ~/ 2;
    final firstHalf = painValues.sublist(0, midpoint);
    final secondHalf = painValues.sublist(midpoint);

    final firstSum = firstHalf.fold(0, (a, b) => a + b);
    final secondSum = secondHalf.fold(0, (a, b) => a + b);
    final firstMean = firstSum / firstHalf.length;
    final secondMean = secondSum / secondHalf.length;
    final diff = secondMean - firstMean;

    if (diff > 0.3) return PainTrend.increasing;
    if (diff < -0.3) return PainTrend.decreasing;
    return PainTrend.stable;
  }
}
