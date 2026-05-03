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

import 'dart:async';

import '../../core/errors/metra_exception.dart';
import '../../core/utils/result.dart';
import '../entities/cycle_entry_entity.dart';
import '../entities/daily_log_entity.dart';
import '../entities/flow_type.dart';
import '../repositories/cycle_entry_repository.dart';
import '../repositories/daily_log_repository.dart';

class RecomputeCycleEntries {
  RecomputeCycleEntries(this._logRepo, this._cycleRepo);

  final DailyLogRepository _logRepo;
  final CycleEntryRepository _cycleRepo;

  // FIGO minimum inter-cycle gap: two bleeding episodes separated by ≥ this
  // many days are considered distinct cycles.
  static const int _kNewCycleGapDays = 21;

  // Future-chain mutex; catchError keeps the chain alive after a failed run.
  Future<void> _serialized = Future.value();

  Future<Result<List<CycleEntryEntity>>> call() {
    final completer = Completer<Result<List<CycleEntryEntity>>>();
    _serialized = _serialized.then((_) async {
      completer.complete(await _doCall());
    }).catchError((Object e, StackTrace s) {
      if (!completer.isCompleted) {
        completer.complete(
          Err(StorageException('Failed to recompute cycle entries: $e')),
        );
      }
    });
    return completer.future;
  }

  Future<Result<List<CycleEntryEntity>>> _doCall() async {
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
    // Only menstruation days define cycle boundaries
    // (spotting / assente / unlogged are excluded).
    final flowDays =
        logs.where((l) => l.flowType == FlowType.mestruazioni).toList();

    if (flowDays.isEmpty) return const [];

    final groups = _groupFlowDays(flowDays);

    // Build CycleEntryEntity list; IDs are placeholder (replaceAll ignores them).
    return List.generate(groups.length, (i) {
      final group = groups[i];
      final cycleLength = i + 1 < groups.length
          ? groups[i + 1].start.difference(group.start).inDays
          : null;
      return CycleEntryEntity(
        id: 0,
        startDate: group.start,
        endDate: group.end,
        periodLength: group.flowDayCount,
        cycleLength: cycleLength,
      );
    });
  }

  // Groups flow days into bleeding episodes separated by ≥ _kNewCycleGapDays.
  // flowDayCount is the number of logged days, not the calendar span.
  static List<_CycleGroup> _groupFlowDays(List<DailyLogEntity> flowDays) {
    final groups = <_CycleGroup>[];
    var groupStart = flowDays.first.date;
    var groupEnd = flowDays.first.date;
    var flowDayCount = 1;

    for (var i = 1; i < flowDays.length; i++) {
      final gap = flowDays[i].date.difference(groupEnd).inDays;
      if (gap >= _kNewCycleGapDays) {
        groups.add(
            (start: groupStart, end: groupEnd, flowDayCount: flowDayCount));
        groupStart = flowDays[i].date;
        flowDayCount = 1;
      } else {
        flowDayCount++;
      }
      groupEnd = flowDays[i].date;
    }
    groups.add((start: groupStart, end: groupEnd, flowDayCount: flowDayCount));
    return groups;
  }
}

typedef _CycleGroup = ({DateTime start, DateTime end, int flowDayCount});
