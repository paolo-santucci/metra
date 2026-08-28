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
import '../../domain/entities/sync_log_entity.dart';
import '../../domain/repositories/app_settings_repository.dart';

class DriftAppSettingsRepository implements AppSettingsRepository {
  const DriftAppSettingsRepository(this._dao);

  final AppSettingsDao _dao;

  // ---- mapping helpers ----

  /// Maps a [SyncProvider] enum value to its stable DB wire string.
  ///
  /// Wire strings are defined by the DB contract (FR-04, NFR-06) and MUST
  /// never use `.name`. An exhaustive switch here enforces that any future
  /// enum member forces an explicit mapping before it compiles.
  ///
  /// Note: `DriftSyncLogRepository.providerToString` carries `@visibleForTesting`
  /// and cannot be called from production code. This local copy is the canonical
  /// settings-layer encoder. Both must produce identical wire strings.
  static String _providerToWireString(SyncProvider provider) =>
      switch (provider) {
        SyncProvider.dropbox => 'dropbox',
        SyncProvider.googleDrive => 'google_drive',
        SyncProvider.iCloud => 'icloud',
      };

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

  /// Maps a raw DB wire string to [SyncProvider].
  ///
  /// Clamp-don't-throw posture (FR-09, NFR-06, EC-03): any unrecognized or
  /// forward value (e.g. a string written by a later build, then rolled back)
  /// falls back to [SyncProvider.dropbox] rather than throwing. This keeps
  /// settings load resilient to corruption and forward-migration artefacts.
  ///
  /// MUST remain a separate function from the strict sync-log mapper
  /// (`_stringToProvider` in `DriftSyncLogRepository`), which throws on
  /// unknown strings. The settings read path tolerates corrupt/forward values;
  /// the sync-log read path does not.
  static SyncProvider _activeProviderFromString(String value) =>
      switch (value) {
        'dropbox' => SyncProvider.dropbox,
        'google_drive' => SyncProvider.googleDrive,
        'icloud' => SyncProvider.iCloud,
        _ => SyncProvider.dropbox, // clamp: unknown/forward value → dropbox
      };

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
        backupSuspended: row.backupSuspended,
        activeProvider: _activeProviderFromString(row.activeProvider),
      );

  // Excluded from _toCompanion (each owned by a dedicated writer):
  //   - dropboxEmail, lastBackupAt   → updateBackupState
  //   - declaredCycleLength          → saveDeclaredCycleLength
  //   - lastLogOrSymptomWriteAt      → updateLastDataWriteAt
  //   - backupSuspended              → updateBackupSuspended
  //   - activeProvider               → setActiveProvider
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
        // backupSuspended: NOT in _toCompanion — owned by updateBackupSuspended (dedicated-writer pattern).
        // See AppSettingsRepository.updateBackupSuspended. Analogue: lastLogOrSymptomWriteAt.
        // activeProvider: NOT in _toCompanion — owned by setActiveProvider (dedicated-writer pattern).
        // See AppSettingsRepository.setActiveProvider. Emitting Companion.absent() here
        // ensures updateSettings() can never clobber the dedicated-writer value (FR-10, EC-06).
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
  Future<void> updateLastDataWriteAt(DateTime timestamp) => _dao.updateSettings(
        AppSettingsCompanion(lastLogOrSymptomWriteAt: Value(timestamp)),
      );

  @override
  Future<void> updateBackupSuspended(bool value) => _dao.updateSettings(
        AppSettingsCompanion(backupSuspended: Value(value)),
      );

  @override
  Future<void> setActiveProvider(SyncProvider provider) =>
      _dao.setActiveProvider(_providerToWireString(provider));

  @override
  Future<void> clearBackupSuspended() => _dao.setBackupSuspended(false);
}
