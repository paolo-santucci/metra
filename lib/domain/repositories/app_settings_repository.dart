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

import '../entities/app_settings_data.dart';

abstract class AppSettingsRepository {
  Stream<AppSettingsData?> watchSettings();

  Future<AppSettingsData> getOrCreate();

  Future<void> updateSettings(AppSettingsData settings);

  /// Marks onboarding as completed. Idempotent.
  Future<void> markOnboardingComplete();

  /// Persists Dropbox backup state after a successful backup or sign-out.
  ///
  /// Pass explicit nulls to clear either field — callers must not use
  /// [updateSettings] for this because [AppSettingsData.copyWith] cannot
  /// reset nullable fields to null.
  Future<void> updateBackupState({
    required String? dropboxEmail,
    required DateTime? lastBackupAt,
  });
}
