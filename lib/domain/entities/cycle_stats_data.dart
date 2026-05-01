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

import 'flow_intensity.dart';
import 'pain_symptom_type.dart';
import 'pain_trend.dart';

/// A single cycle's data as rendered on a chart axis.
class CycleDataPoint {
  const CycleDataPoint({
    required this.startDate,
    required this.cycleLength,
    this.periodLength,
    this.dominantFlow,
    this.dominantPainIntensity,
  });

  /// UTC midnight — used as the X-axis label.
  final DateTime startDate;

  /// Total length of this cycle in days (complete cycles only — always set).
  final int cycleLength;

  /// Length of the bleeding period in days; null if not recorded.
  final int? periodLength;

  final FlowIntensity? dominantFlow;

  /// Most-frequent pain intensity (1–3) for this cycle; null if no pain logged.
  final int? dominantPainIntensity;
}

/// Aggregated statistics ready for consumption by the stats screen.
class CycleStatsData {
  const CycleStatsData({
    required this.points,
    required this.cycleLengthAvg,
    required this.cycleLengthMin,
    required this.cycleLengthMax,
    required this.cyclesTrackedCount,
    required this.symptomCounts,
    this.periodLengthAvg,
    this.periodLengthMin,
    this.periodLengthMax,
    this.painIntensityAvg,
    this.painTrend,
  });

  /// Chronologically ordered data points (oldest first).
  final List<CycleDataPoint> points;

  /// Rounded mean of all cycle lengths in [points].
  final int cycleLengthAvg;

  /// Minimum cycle length across all [points].
  final int cycleLengthMin;

  /// Maximum cycle length across all [points].
  final int cycleLengthMax;

  /// Mean of non-null [CycleDataPoint.periodLength] values; null if none.
  final double? periodLengthAvg;

  /// Minimum period length; null if no period-length data.
  final int? periodLengthMin;

  /// Maximum period length; null if no period-length data.
  final int? periodLengthMax;

  /// Mean of non-null [CycleDataPoint.dominantPainIntensity] values; null if none.
  final double? painIntensityAvg;

  /// Null if fewer than 3 points have non-null [CycleDataPoint.dominantPainIntensity].
  final PainTrend? painTrend;

  /// Total number of complete cycles included in [points].
  final int cyclesTrackedCount;

  /// Absolute cycle count per symptom type for the 8 fixed [PainSymptomType] values.
  /// All 8 types are always present in the map.
  final Map<PainSymptomType, int> symptomCounts;
}
