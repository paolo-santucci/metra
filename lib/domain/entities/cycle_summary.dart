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

import 'cycle_entry_entity.dart';
import 'flow_intensity.dart';
import 'pain_symptom_type.dart';

/// A cycle together with the aggregated data derived from its date range.
class CycleSummary {
  const CycleSummary({
    required this.cycle,
    required this.symptoms,
    required this.dominantPainIntensity,
    this.dominantFlow,
  });

  final CycleEntryEntity cycle;

  /// Distinct fixed symptom types seen across this cycle's date range.
  /// Never contains [PainSymptomType.custom].
  final List<PainSymptomType> symptoms;

  /// Most-frequent non-null [FlowIntensity]; highest ordinal wins on ties.
  /// Null if no flow was logged for this cycle.
  final FlowIntensity? dominantFlow;

  /// Most-frequent pain intensity (1–3) across this cycle's date range.
  /// Null if no log has painEnabled=true with painIntensity > 0.
  /// On tie, the highest value wins.
  final int? dominantPainIntensity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleSummary &&
          runtimeType == other.runtimeType &&
          cycle == other.cycle &&
          _listEquals(symptoms, other.symptoms) &&
          dominantFlow == other.dominantFlow &&
          dominantPainIntensity == other.dominantPainIntensity;

  @override
  int get hashCode =>
      cycle.hashCode ^
      Object.hashAll(symptoms) ^
      dominantFlow.hashCode ^
      dominantPainIntensity.hashCode;

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
