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

import '../../data/database/app_database.dart';
import '../../data/database/daos/app_settings_dao.dart';
import '../../domain/entities/app_settings_data.dart';
import '../../domain/repositories/app_settings_repository.dart';

class DriftAppSettingsRepository implements AppSettingsRepository {
  const DriftAppSettingsRepository(this._dao);

  final AppSettingsDao _dao;

  // ---- mapping helpers ----

  static AppSettingsData _fromRow(AppSetting row) => AppSettingsData(
        languageCode: row.languageCode,
        darkMode: row.darkMode,
        painEnabled: row.painEnabled,
        notesEnabled: row.notesEnabled,
        notificationDaysBefore: row.notificationDaysBefore,
        notificationsEnabled: row.notificationsEnabled,
        dropboxEmail: row.dropboxEmail,
        lastBackupAt: row.lastBackupAt,
        onboardingCompleted: row.onboardingCompleted,
      );

  static AppSettingsCompanion _toCompanion(AppSettingsData data) =>
      AppSettingsCompanion(
        languageCode: Value(data.languageCode),
        darkMode: Value(data.darkMode),
        painEnabled: Value(data.painEnabled),
        notesEnabled: Value(data.notesEnabled),
        notificationDaysBefore: Value(data.notificationDaysBefore),
        notificationsEnabled: Value(data.notificationsEnabled),
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
}
