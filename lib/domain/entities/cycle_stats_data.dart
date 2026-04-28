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

/// A single cycle's data as rendered on a chart axis.
class CycleDataPoint {
  const CycleDataPoint({
    required this.startDate,
    required this.cycleLength,
    this.periodLength,
    this.dominantFlow,
  });

  /// UTC midnight — used as the X-axis label.
  final DateTime startDate;

  /// Total length of this cycle in days (complete cycles only — always set).
  final int cycleLength;

  /// Length of the bleeding period in days; null if not recorded.
  final int? periodLength;

  final FlowIntensity? dominantFlow;
}

/// Aggregated statistics ready for consumption by the stats screen.
class CycleStatsData {
  const CycleStatsData({
    required this.points,
    required this.symptomFrequencies,
  });

  /// Chronologically ordered data points (oldest first).
  final List<CycleDataPoint> points;

  /// Fraction [0.0–1.0] for each of the 5 fixed [PainSymptomType] values
  /// (i.e. all values except [PainSymptomType.custom]).
  /// All 5 types are always present in the map.
  final Map<PainSymptomType, double> symptomFrequencies;
}
