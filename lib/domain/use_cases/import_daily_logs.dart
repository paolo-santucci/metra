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

enum ImportMode { deleteAndImport, overwrite, keepExisting }

class ImportResult {
  const ImportResult({required this.imported, required this.skipped});

  final int imported;

  /// Rows skipped because they already existed (keepExisting mode) or
  /// were excluded due to parse errors before this use case was called.
  final int skipped;
}

class ImportDailyLogs {
  const ImportDailyLogs(this._logRepo, this._recompute);

  final DailyLogRepository _logRepo;
  final RecomputeCycleEntries _recompute;

  Future<ImportResult> execute({
    required List<DailyLogRow> rows,
    required ImportMode mode,
  }) async {
    switch (mode) {
      case ImportMode.deleteAndImport:
        final symptomsMap = {
          for (final r in rows) r.log.date: r.symptoms,
        };
        await _logRepo.deleteAllAndReplace(
          rows.map((r) => r.log).toList(),
          symptomsMap,
        );
        await _recompute();
        return ImportResult(imported: rows.length, skipped: 0);

      case ImportMode.overwrite:
        for (final r in rows) {
          await _logRepo.saveDailyLog(r.log);
          await _logRepo.replacePainSymptoms(r.log.date, r.symptoms);
        }
        await _recompute();
        return ImportResult(imported: rows.length, skipped: 0);

      case ImportMode.keepExisting:
        final existing = await _logRepo.getAllOrderedByDate();
        final existingDates = {for (final l in existing) l.date};
        var imported = 0;
        var skipped = 0;
        for (final r in rows) {
          if (existingDates.contains(r.log.date)) {
            skipped++;
          } else {
            await _logRepo.saveDailyLog(r.log);
            await _logRepo.replacePainSymptoms(r.log.date, r.symptoms);
            imported++;
          }
        }
        await _recompute();
        return ImportResult(imported: imported, skipped: skipped);
    }
  }
}
