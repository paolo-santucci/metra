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
import '../entities/flow_type.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/cycle_entry_repository.dart';
import '../repositories/daily_log_repository.dart';
import 'recompute_cycle_entries.dart';

class CompleteOnboarding {
  const CompleteOnboarding(
    this._cycleRepo,
    this._settingsRepo,
    this._logRepo,
    this._recompute,
  );

  final CycleEntryRepository _cycleRepo;
  final AppSettingsRepository _settingsRepo;
  final DailyLogRepository _logRepo;
  final RecomputeCycleEntries _recompute;

  Future<void> execute({
    required DateTime lastPeriodDate,
    required int cycleLength,
    required int periodLength,
  }) async {
    // Defensive future-date guard: lastPeriodDate must not be in the future.
    // This prevents invalid anchor entries from being inserted.
    if (lastPeriodDate.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        lastPeriodDate,
        'lastPeriodDate',
        'lastPeriodDate must not be in the future',
      );
    }

    // Idempotency guard: if an anchor entry already exists for this date,
    // skip the insert. This makes the use case safe to call multiple times
    // with the same lastPeriodDate (e.g., on double-tap or retry).
    final existing = await _cycleRepo.getByStartDate(lastPeriodDate);
    if (existing == null) {
      // The cycle entry is an anchor date only — cycleLength is left null so
      // RecomputeCycleEntries can fill it in from measured gaps over time.
      // The declared average is stored separately in AppSettings (Strategy B).
      try {
        await _cycleRepo.insert(
          CycleEntryEntity(
            id: 0, // ignored by DB — auto-generated
            startDate: lastPeriodDate,
            endDate: null,
            cycleLength: null,
            periodLength: periodLength,
          ),
        );
      } on Exception catch (e) {
        // Race condition: two concurrent calls may both pass the getByStartDate
        // check and both attempt to insert. The second will hit the UNIQUE
        // constraint on start_date. Treat this as idempotent — the entry was
        // inserted by the first call; the second can proceed safely.
        // Re-throw any non-UNIQUE exception.
        if (!e.toString().contains('UNIQUE constraint')) rethrow;
      }
    }

    final logs = await _logRepo.getAllOrderedByDate();
    final hasFlowLogs = logs.any((l) => l.flowType == FlowType.mestruazioni);
    if (hasFlowLogs) await _recompute();
    await _settingsRepo.saveDeclaredCycleLength(cycleLength);
    await _settingsRepo.markOnboardingComplete();
  }
}
