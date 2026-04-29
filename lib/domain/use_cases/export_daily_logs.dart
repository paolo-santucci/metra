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

import '../repositories/daily_log_repository.dart';
import '../services/csv_codec.dart';
import 'recompute_cycle_entries.dart';

class ExportDailyLogs {
  const ExportDailyLogs(this._logRepo);

  final DailyLogRepository _logRepo;

  Future<String> execute() async {
    final logs = await _logRepo.getAllOrderedByDate();

    // Derive cycle start dates from logs using the pure static computation,
    // avoiding a separate CycleEntryRepository dependency.
    final cycleEntries = RecomputeCycleEntries.compute(logs);
    final startDates = {for (final e in cycleEntries) e.startDate};

    final rows = <DailyLogRow>[];
    for (final log in logs) {
      final symptoms = await _logRepo.getPainSymptoms(log.date);
      rows.add(
        DailyLogRow(
          log: log,
          symptoms: symptoms,
          cycleStart: startDates.contains(log.date),
        ),
      );
    }

    return const CsvCodec().encode(rows);
  }
}
