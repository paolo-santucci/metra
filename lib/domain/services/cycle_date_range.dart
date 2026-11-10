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

/// The date range a cycle covers, as used by `GetCycleSummaries` to select
/// the daily logs that belong to it.
///
/// Extracted verbatim from `GetCycleSummaries._enrich` so the cycle summaries
/// and the timeline note matcher resolve identical ranges.
class CycleDateRange {
  const CycleDateRange({required this.start, required this.end});

  /// First day of the cycle (inclusive).
  final DateTime start;

  /// Last day of the cycle (inclusive).
  final DateTime end;

  /// Inclusive bounds, UTC-midnight normalized — the exact values
  /// `GetCycleSummaries._enrich` compares logs against today.
  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);

  /// Greatest `startDate` across [cycles]. Throws `StateError` on an empty
  /// list — callers early-return on empty exactly like `_enrich`'s `reduce`.
  static DateTime trailingStartOf(List<CycleEntryEntity> cycles) =>
      cycles.map((c) => c.startDate).reduce((a, b) => a.isAfter(b) ? a : b);

  /// UTC-midnight normalization of [now] (defaults to `DateTime.now()`).
  static DateTime todayNorm([DateTime? now]) {
    final today = (now ?? DateTime.now()).toUtc();
    return DateTime.utc(today.year, today.month, today.day);
  }

  /// The `_enrich` rule, verbatim: the trailing cycle (`startDate ==
  /// [trailingStart]`) ends at [todayNorm] regardless of `endDate`; every
  /// other cycle ends at `endDate ?? [todayNorm]`.
  static CycleDateRange resolve({
    required CycleEntryEntity cycle,
    required DateTime trailingStart,
    required DateTime todayNorm,
  }) {
    final isTrailing = cycle.startDate == trailingStart;
    return CycleDateRange(
      start: cycle.startDate,
      end: isTrailing ? todayNorm : (cycle.endDate ?? todayNorm),
    );
  }
}
