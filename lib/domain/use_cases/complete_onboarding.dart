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
import '../repositories/app_settings_repository.dart';
import '../repositories/cycle_entry_repository.dart';

class CompleteOnboarding {
  const CompleteOnboarding(this._cycleRepo, this._settingsRepo);

  final CycleEntryRepository _cycleRepo;
  final AppSettingsRepository _settingsRepo;

  Future<void> execute({
    required DateTime lastPeriodDate,
    required int cycleLength,
  }) async {
    await _cycleRepo.insert(
      CycleEntryEntity(
        id: 0, // ignored by DB — auto-generated
        startDate: lastPeriodDate,
        endDate: null,
        cycleLength: cycleLength,
        periodLength: null,
      ),
    );
    await _settingsRepo.markOnboardingComplete();
  }
}
