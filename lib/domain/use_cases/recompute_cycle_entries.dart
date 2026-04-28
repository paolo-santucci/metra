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

import '../../core/errors/metra_exception.dart';
import '../../core/utils/result.dart';
import '../entities/cycle_entry_entity.dart';
import '../entities/daily_log_entity.dart';
import '../entities/flow_intensity.dart';
import '../repositories/cycle_entry_repository.dart';
import '../repositories/daily_log_repository.dart';

class RecomputeCycleEntries {
  const RecomputeCycleEntries(this._logRepo, this._cycleRepo);

  final DailyLogRepository _logRepo;
  final CycleEntryRepository _cycleRepo;

  // FIGO minimum inter-cycle gap: two bleeding episodes separated by ≥ this
  // many days are considered distinct cycles.
  static const int _kNewCycleGapDays = 21;

  Future<Result<List<CycleEntryEntity>>> call() async {
    try {
      final logs = await _logRepo.getAllOrderedByDate();
      final entries = _compute(logs);
      await _cycleRepo.replaceAll(entries);
      return Ok(entries);
    } on MetraException catch (e) {
      return Err(e);
    } catch (e) {
      return Err(StorageException('Failed to recompute cycle entries: $e'));
    }
  }

  /// Pure computation; exposed for unit-testing without DB.
  static List<CycleEntryEntity> compute(List<DailyLogEntity> logs) =>
      _compute(logs);

  static List<CycleEntryEntity> _compute(List<DailyLogEntity> logs) {
    // Only actual flow days (not spotting-only) define cycle boundaries.
    final flowDays = logs
        .where(
          (l) =>
              l.flowIntensity != null && l.flowIntensity != FlowIntensity.none,
        )
        .toList();

    if (flowDays.isEmpty) return const [];

    // Group flow days into runs separated by ≥ _kNewCycleGapDays.
    final groups = <_CycleGroup>[];
    var groupStart = flowDays.first.date;
    var groupEnd = flowDays.first.date;

    for (var i = 1; i < flowDays.length; i++) {
      final gap = flowDays[i].date.difference(groupEnd).inDays;
      if (gap >= _kNewCycleGapDays) {
        groups.add(_CycleGroup(start: groupStart, end: groupEnd));
        groupStart = flowDays[i].date;
      }
      groupEnd = flowDays[i].date;
    }
    groups.add(_CycleGroup(start: groupStart, end: groupEnd));

    // Build CycleEntryEntity list; IDs are placeholder (replaceAll ignores them).
    return List.generate(groups.length, (i) {
      final group = groups[i];
      final periodLength = group.end.difference(group.start).inDays + 1;
      final cycleLength = i + 1 < groups.length
          ? groups[i + 1].start.difference(group.start).inDays
          : null;
      return CycleEntryEntity(
        id: 0,
        startDate: group.start,
        endDate: group.end,
        periodLength: periodLength,
        cycleLength: cycleLength,
      );
    });
  }
}

class _CycleGroup {
  const _CycleGroup({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}
