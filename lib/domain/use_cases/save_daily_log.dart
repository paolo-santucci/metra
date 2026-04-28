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
import '../entities/daily_log_entity.dart';
import '../entities/flow_intensity.dart';
import '../repositories/daily_log_repository.dart';

class SaveDailyLog {
  const SaveDailyLog(this._repo);

  final DailyLogRepository _repo;

  // Confirmed by user: 0=none, 1=mild, 2=moderate, 3=severe.
  static const int _maxPainIntensity = 3;

  Future<Result<DailyLogEntity>> call(DailyLogEntity log) async {
    final hasFlow =
        log.flowIntensity != null && log.flowIntensity != FlowIntensity.none;
    if (hasFlow && log.spotting) {
      return const Err(
        ValidationException('A day cannot have both flow and spotting'),
      );
    }

    final today = DateTime.now().toUtc();
    final todayDay = DateTime.utc(today.year, today.month, today.day);
    final logDay = DateTime.utc(log.date.year, log.date.month, log.date.day);
    if (logDay.isAfter(todayDay)) {
      return const Err(ValidationException('Cannot log a future date'));
    }

    if (log.painIntensity != null &&
        (log.painIntensity! < 0 || log.painIntensity! > _maxPainIntensity)) {
      return const Err(
        ValidationException('Pain intensity must be between 0 and 3'),
      );
    }

    final normalized = DailyLogEntity(
      date: logDay,
      flowIntensity: log.flowIntensity,
      spotting: log.spotting,
      otherDischarge: log.otherDischarge,
      painEnabled: log.painEnabled,
      painIntensity: log.painIntensity,
      notesEnabled: log.notesEnabled,
      notes: log.notes,
    );

    try {
      await _repo.saveDailyLog(normalized);
      return Ok(normalized);
    } on MetraException catch (e) {
      return Err(e);
    } catch (e) {
      return Err(StorageException('Failed to save daily log: $e'));
    }
  }
}
