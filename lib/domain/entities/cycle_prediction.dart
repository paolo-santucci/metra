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

/// A predicted next-cycle window derived from the WMA algorithm.
///
/// The window spans [windowStart, windowEnd] — a 5-day range
/// (expectedStart ± 2 days) that communicates inherent uncertainty.
class CyclePrediction {
  const CyclePrediction({
    required this.windowStart,
    required this.windowEnd,
    required this.expectedStart,
    required this.cyclesUsed,
  });

  /// Two days before [expectedStart].
  final DateTime windowStart;

  /// Two days after [expectedStart].
  final DateTime windowEnd;

  /// WMA result rounded to the nearest day.
  final DateTime expectedStart;

  /// Number of complete cycles used in the WMA computation (3–6).
  final int cyclesUsed;

  /// Returns true if [d] falls within the inclusive prediction window.
  bool containsDate(DateTime d) =>
      !d.isBefore(windowStart) && !d.isAfter(windowEnd);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CyclePrediction &&
          windowStart == other.windowStart &&
          windowEnd == other.windowEnd &&
          expectedStart == other.expectedStart &&
          cyclesUsed == other.cyclesUsed;

  @override
  int get hashCode =>
      Object.hash(windowStart, windowEnd, expectedStart, cyclesUsed);
}
