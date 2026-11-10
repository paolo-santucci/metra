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
import '../repositories/cycle_entry_repository.dart';
import '../repositories/daily_log_repository.dart';

/// Projects the free-note text of every daily log onto a date-keyed map.
///
/// Re-emits on every [CycleEntryRepository.watchAll] emission — the same
/// trigger `GetCycleSummaries` watches — so note filtering and the cycle
/// summaries re-emit in lockstep. Each emission reads the log table exactly
/// once and never queries symptoms (NFR-02 read budget).
class GetCycleNotes {
  const GetCycleNotes(this._logRepo, this._cycleRepo);

  final DailyLogRepository _logRepo;
  final CycleEntryRepository _cycleRepo;

  /// Emits `{normalizedDate: noteText}` for every daily log whose note is
  /// neither null nor empty — the same predicate `_enrich` uses for
  /// `hasNote`; `notesEnabled` is not consulted.
  ///
  /// An empty cycle list emits an empty map without reading logs, mirroring
  /// `_enrich`'s early return. Repository and stream failures propagate as
  /// stream errors.
  Stream<Map<DateTime, String>> call() =>
      _cycleRepo.watchAll().asyncMap(_notesFor);

  Future<Map<DateTime, String>> _notesFor(
    List<CycleEntryEntity> cycles,
  ) async {
    if (cycles.isEmpty) return const <DateTime, String>{};

    final logs = await _logRepo.getAllOrderedByDate();
    final notes = <DateTime, String>{};
    for (final log in logs) {
      final note = log.notes;
      if (note == null || note.isEmpty) continue;
      notes[_normalize(log.date)] = note;
    }
    return notes;
  }

  static DateTime _normalize(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
