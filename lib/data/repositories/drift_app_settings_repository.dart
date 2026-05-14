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

import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/app_settings_dao.dart';
import '../../domain/entities/app_settings_data.dart';
import '../../domain/entities/first_day_of_week_setting.dart';
import '../../domain/repositories/app_settings_repository.dart';

class DriftAppSettingsRepository implements AppSettingsRepository {
  const DriftAppSettingsRepository(this._dao);

  final AppSettingsDao _dao;

  // ---- mapping helpers ----

  /// Maps a raw DB integer to [FirstDayOfWeekSetting].
  ///
  /// Any out-of-range value (DB corruption, forward-migration artefact) falls
  /// back to [FirstDayOfWeekSetting.system] rather than throwing.
  static FirstDayOfWeekSetting _firstDayOfWeekFromIndex(int idx) {
    if (idx < 0 || idx >= FirstDayOfWeekSetting.values.length) {
      return FirstDayOfWeekSetting.system;
    }
    return FirstDayOfWeekSetting.values[idx];
  }

  static AppSettingsData _fromRow(AppSetting row) => AppSettingsData(
        languageCode: row.languageCode,
        darkMode: row.darkMode,
        painEnabled: row.painEnabled,
        notesEnabled: row.notesEnabled,
        notificationDaysBefore:
            row.notificationDaysBefore.clamp(1, AppConstants.kMaxAdvanceDays),
        notificationsEnabled: row.notificationsEnabled,
        dropboxEmail: row.dropboxEmail,
        lastBackupAt: row.lastBackupAt?.toUtc(),
        onboardingCompleted: row.onboardingCompleted,
        declaredCycleLength: row.declaredCycleLength,
        notificationTimeMinutes: row.notificationTimeMinutes.clamp(0, 1439),
        firstDayOfWeek: _firstDayOfWeekFromIndex(row.firstDayOfWeek),
        lastLogOrSymptomWriteAt: row.lastLogOrSymptomWriteAt?.toUtc(),
      );

  // Excluded from _toCompanion (each owned by a dedicated writer):
  //   - dropboxEmail, lastBackupAt   → updateBackupState
  //   - declaredCycleLength          → saveDeclaredCycleLength
  //   - lastLogOrSymptomWriteAt      → updateLastDataWriteAt
  // Adding any of these here would cause updateSettings() to silently
  // overwrite them. See spec FR-03 / NFR-08.
  static AppSettingsCompanion _toCompanion(AppSettingsData data) =>
      AppSettingsCompanion(
        languageCode: Value(data.languageCode),
        darkMode: Value(data.darkMode),
        painEnabled: Value(data.painEnabled),
        notesEnabled: Value(data.notesEnabled),
        notificationDaysBefore: Value(data.notificationDaysBefore),
        notificationsEnabled: Value(data.notificationsEnabled),
        notificationTimeMinutes: Value(data.notificationTimeMinutes),
        firstDayOfWeek: Value(data.firstDayOfWeek.index),
      );

  // ---- interface implementation ----

  @override
  Stream<AppSettingsData?> watchSettings() =>
      _dao.watchSettings().map((row) => row == null ? null : _fromRow(row));

  @override
  Future<AppSettingsData> getOrCreate() async {
    final row = await _dao.getOrCreateSettings();
    return _fromRow(row);
  }

  @override
  Future<void> updateSettings(AppSettingsData settings) =>
      _dao.updateSettings(_toCompanion(settings));

  @override
  Future<void> markOnboardingComplete() => _dao.updateSettings(
        const AppSettingsCompanion(onboardingCompleted: Value(true)),
      );

  @override
  Future<void> updateBackupState({
    required String? dropboxEmail,
    required DateTime? lastBackupAt,
  }) =>
      _dao.updateSettings(
        AppSettingsCompanion(
          // Value(...) with an explicit null writes NULL to the column,
          // unlike Value.absent() which leaves the column untouched.
          dropboxEmail: Value(dropboxEmail),
          lastBackupAt: Value(lastBackupAt),
        ),
      );

  @override
  Future<void> saveDeclaredCycleLength(int cycleLength) => _dao.updateSettings(
        AppSettingsCompanion(declaredCycleLength: Value(cycleLength)),
      );

  @override
  Future<void> updateLastDataWriteAt(DateTime timestamp) =>
      _dao.updateSettings(
        AppSettingsCompanion(lastLogOrSymptomWriteAt: Value(timestamp)),
      );
}
