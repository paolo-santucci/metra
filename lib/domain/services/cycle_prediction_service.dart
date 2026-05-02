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

import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';

/// Pure, side-effect-free service that predicts the next cycle start date
/// using a Weighted Moving Average (WMA) over the last N≤6 complete cycles.
///
/// Requires at least 3 complete cycles ([CycleEntryEntity.cycleLength] != null).
/// Returns null when the data is insufficient for a reliable prediction.
class CyclePredictionService {
  const CyclePredictionService();

  /// Computes a [CyclePrediction] from [cycles].
  ///
  /// Returns null if fewer than 3 complete cycles are available.
  CyclePrediction? predict(List<CycleEntryEntity> cycles) {
    // 1. Filter to complete cycles (cycleLength != null), sort ascending.
    final complete = cycles.where((c) => c.cycleLength != null).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // 2. Need at least 3 complete cycles.
    if (complete.length < 3) return null;

    // 3. Take the most recent min(count, 6) complete cycles for WMA.
    final n = complete.length < 6 ? complete.length : 6;
    final window = complete.sublist(complete.length - n);

    // 4. WMA: weight[i] = i + 1 (oldest = 1, most recent = n).
    var weightedSum = 0.0;
    var weightTotal = 0;
    for (var i = 0; i < n; i++) {
      final weight = i + 1;
      weightedSum += window[i].cycleLength! * weight;
      weightTotal += weight;
    }
    final avg = weightedSum / weightTotal;

    // 5. Anchor on the most-recent cycle overall (may be incomplete/null length).
    //    Decoupled from the WMA window so an in-progress cycle doesn't push the
    //    prediction into the past.
    // Keep `a` unless `b` is strictly later; ties preserve the iteration-first
    // entry (deterministic regardless of list ordering).
    final anchor = cycles.reduce(
      (a, b) => b.startDate.isBefore(a.startDate) ? a : b,
    );

    // 6. Build the prediction window around the rounded expected start.
    final expectedStart = anchor.startDate.add(Duration(days: avg.round()));
    final windowStart = expectedStart.subtract(const Duration(days: 2));
    final windowEnd = expectedStart.add(const Duration(days: 2));

    return CyclePrediction(
      windowStart: windowStart,
      windowEnd: windowEnd,
      expectedStart: expectedStart,
      cyclesUsed: n,
    );
  }
}
