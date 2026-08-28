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
import '../entities/sync_log_entity.dart';

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

  /// Persists the user-declared average cycle length (Strategy B).
  ///
  /// Called once from [CompleteOnboarding]. Preserved indefinitely —
  /// [RecomputeCycleEntries] never touches this value.
  Future<void> saveDeclaredCycleLength(int cycleLength);

  /// Persists the last log-or-symptom write timestamp.
  ///
  /// Called by [DriftDailyLogRepository] after each successful write to
  /// DailyLogs or PainSymptoms. Must NOT be called from [updateSettings]
  /// or any path that touches AppSettings preference fields.
  ///
  /// Pre-conditions:
  ///   - [timestamp] must be UTC (DateTime.isUtc == true).
  /// Post-conditions:
  ///   - The persisted [AppSettingsData.lastLogOrSymptomWriteAt] equals
  ///     [timestamp].
  ///   - Every other column in AppSettings is byte-for-byte unchanged.
  /// Errors:
  ///   - Propagates [DriftWrappedException] on DB failure; caller must not
  ///     swallow it silently (bump failure means the skip guard may fire
  ///     a false-skip on the next cold-start).
  Future<void> updateLastDataWriteAt(DateTime timestamp);

  /// Updates the [AppSettingsData.backupSuspended] flag in persistent storage.
  ///
  /// **Pre-conditions**: A singleton settings row exists (guaranteed by
  /// [getOrCreate]). If no row exists the implementation must propagate the
  /// storage error — do not silently swallow it.
  ///
  /// **Post-conditions**: Only [AppSettingsData.backupSuspended] changes.
  /// Every other column is byte-for-byte preserved. This is a dedicated-writer
  /// method — it must NOT touch any other field (contrast with
  /// [updateSettings], which updates all non-dedicated-writer columns).
  ///
  /// **Callers**: M3 will use this in [DeleteAllData] (suspend before wipe)
  /// and in the `lastLogOrSymptomWriteAt` bumper. M4 will use it in the
  /// notification-failure revert path.
  ///
  /// **Errors**: propagate storage exceptions to the caller unchanged.
  Future<void> updateBackupSuspended(bool value);

  /// Persists the active cloud backup provider in persistent storage.
  ///
  /// **Pre-conditions**: A singleton settings row exists (guaranteed by
  /// [getOrCreate]). If no row exists the implementation must propagate the
  /// storage error — do not silently swallow it.
  ///
  /// **Post-conditions**: Only [AppSettingsData.activeProvider] changes.
  /// Every other column is byte-for-byte preserved. This is a dedicated-writer
  /// method — it must NOT touch any other field (contrast with
  /// [updateSettings], which updates all non-dedicated-writer columns).
  ///
  /// **Errors**: propagate storage exceptions to the caller unchanged.
  Future<void> setActiveProvider(SyncProvider provider);

  /// Clears the backup-suspended sentinel by writing
  /// [AppSettingsData.backupSuspended] = `false` in persistent storage.
  ///
  /// **Callers** (FR-12b): called by the data-layer write methods that
  /// represent genuine user-initiated data writes —
  /// `DriftDailyLogRepository.saveDailyLog`,
  /// `DriftDailyLogRepository.replacePainSymptoms`,
  /// `DriftDailyLogRepository.upsertAllLogs`,
  /// `DriftCycleEntryRepository.insert`, and
  /// `DriftCycleEntryRepository.update` — each after their primary write
  /// returns successfully. Delete-path methods (`deleteDailyLog`, `deleteAll`,
  /// `deleteAllAndReplace`, `replaceAll`) MUST NOT call this method (FR-12c).
  ///
  /// **HC-6 decoupling**: this method is a dedicated writer that touches only
  /// the `backupSuspended` column. It MUST NOT read or write
  /// `lastLogOrSymptomWriteAt`. Conversely, [updateLastDataWriteAt] MUST NOT
  /// touch `backupSuspended`. The two writers are independent and MUST NOT
  /// share a transaction block, so a failure in one cannot corrupt the other.
  ///
  /// **Pre-conditions**: A singleton settings row exists (guaranteed by
  /// [getOrCreate]). If no row exists the implementation must propagate the
  /// storage error — do not silently swallow it.
  ///
  /// **Post-conditions**:
  ///   - [AppSettingsData.backupSuspended] is `false`.
  ///   - [AppSettingsData.lastLogOrSymptomWriteAt] is byte-for-byte unchanged.
  ///   - Every other column in AppSettings is byte-for-byte unchanged.
  ///
  /// **Errors**: propagate storage exceptions to the caller unchanged.
  Future<void> clearBackupSuspended();
}
