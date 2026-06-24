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

import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/domain/repositories/app_settings_repository.dart';

class FakeAppSettingsRepository implements AppSettingsRepository {
  AppSettingsData? storedSettings;

  /// Records the name of each mutating method call in invocation order.
  ///
  /// Used by downstream tests to assert call-order invariants — e.g. that
  /// [clearBackupSuspended] fires after the primary write, or that
  /// [updateBackupSuspended] fires before [clearBackupSuspended] in a
  /// suspend-then-clear sequence.
  final List<String> callLog = [];

  // ---------------------------------------------------------------------------
  // Private rebuild helper — eliminates the six-block silent-reset risk (EC-10).
  //
  // Every field is forwarded from [current] unless the caller passes a named
  // override. A nullable-field override is expressed as a zero-arg function
  // (factory) so callers can distinguish "set to null" from "no override".
  //
  // New fields added to AppSettingsData MUST be added here too — the compiler
  // will flag the missing named parameter in the AppSettingsData(...) call
  // below if a required param is omitted, making future omissions a compile
  // error rather than a silent runtime reset.
  // ---------------------------------------------------------------------------
  AppSettingsData _rebuild(
    AppSettingsData current, {
    String? languageCode,
    // nullable bool — factory pattern lets callers set to null
    bool? Function()? darkMode,
    bool? painEnabled,
    bool? notesEnabled,
    int? notificationDaysBefore,
    bool? notificationsEnabled,
    // nullable String — factory pattern
    String? Function()? dropboxEmail,
    // nullable DateTime — factory pattern
    DateTime? Function()? lastBackupAt,
    bool? onboardingCompleted,
    // nullable int — factory pattern
    int? Function()? declaredCycleLength,
    int? notificationTimeMinutes,
    FirstDayOfWeekSetting? firstDayOfWeek,
    // nullable DateTime — factory pattern
    DateTime? Function()? lastLogOrSymptomWriteAt,
    bool? backupSuspended,
    SyncProvider? activeProvider,
  }) {
    return AppSettingsData(
      languageCode: languageCode ?? current.languageCode,
      darkMode: darkMode != null ? darkMode() : current.darkMode,
      painEnabled: painEnabled ?? current.painEnabled,
      notesEnabled: notesEnabled ?? current.notesEnabled,
      notificationDaysBefore:
          notificationDaysBefore ?? current.notificationDaysBefore,
      notificationsEnabled:
          notificationsEnabled ?? current.notificationsEnabled,
      dropboxEmail:
          dropboxEmail != null ? dropboxEmail() : current.dropboxEmail,
      lastBackupAt:
          lastBackupAt != null ? lastBackupAt() : current.lastBackupAt,
      onboardingCompleted: onboardingCompleted ?? current.onboardingCompleted,
      declaredCycleLength: declaredCycleLength != null
          ? declaredCycleLength()
          : current.declaredCycleLength,
      notificationTimeMinutes:
          notificationTimeMinutes ?? current.notificationTimeMinutes,
      firstDayOfWeek: firstDayOfWeek ?? current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: lastLogOrSymptomWriteAt != null
          ? lastLogOrSymptomWriteAt()
          : current.lastLogOrSymptomWriteAt,
      backupSuspended: backupSuspended ?? current.backupSuspended,
      activeProvider: activeProvider ?? current.activeProvider,
    );
  }

  @override
  Stream<AppSettingsData?> watchSettings() => Stream.value(storedSettings);

  @override
  Future<AppSettingsData> getOrCreate() async =>
      storedSettings ?? AppSettingsData.defaults();

  @override
  Future<void> updateSettings(AppSettingsData settings) async {
    storedSettings = settings;
  }

  @override
  Future<void> updateBackupState({
    required String? dropboxEmail,
    required DateTime? lastBackupAt,
  }) async {
    final current = storedSettings ?? AppSettingsData.defaults();
    // Full constructor used intentionally — copyWith cannot clear nullable
    // fields to null, which is exactly what callers of updateBackupState need.
    storedSettings = _rebuild(
      current,
      dropboxEmail: () => dropboxEmail,
      lastBackupAt: () => lastBackupAt,
    );
  }

  @override
  Future<void> markOnboardingComplete() async {
    final current = storedSettings ?? AppSettingsData.defaults();
    storedSettings = _rebuild(current, onboardingCompleted: true);
  }

  @override
  Future<void> saveDeclaredCycleLength(int cycleLength) async {
    final current = storedSettings ?? AppSettingsData.defaults();
    storedSettings = _rebuild(
      current,
      declaredCycleLength: () => cycleLength,
    );
  }

  @override
  Future<void> updateLastDataWriteAt(DateTime timestamp) async {
    final current = storedSettings ?? AppSettingsData.defaults();
    storedSettings = _rebuild(
      current,
      lastLogOrSymptomWriteAt: () => timestamp,
    );
  }

  @override
  Future<void> updateBackupSuspended(bool value) async {
    final current = storedSettings ?? AppSettingsData.defaults();
    // backupSuspended is excluded from copyWith — dedicated-writer pattern.
    // Full constructor used via _rebuild to set backupSuspended directly.
    storedSettings = _rebuild(current, backupSuspended: value);
    callLog.add('updateBackupSuspended:$value');
  }

  /// Clears the backup-suspended sentinel.
  ///
  /// Sets [AppSettingsData.backupSuspended] = `false`. Does NOT mutate
  /// [AppSettingsData.lastLogOrSymptomWriteAt] (HC-6 decoupling).
  /// Records the invocation in [callLog] to support call-order assertions.
  @override
  Future<void> clearBackupSuspended() async {
    final current = storedSettings ?? AppSettingsData.defaults();
    // Dedicated writer — touches only backupSuspended.
    // lastLogOrSymptomWriteAt is preserved unchanged (HC-6, NFR-05).
    storedSettings = _rebuild(current, backupSuspended: false);
    callLog.add('clearBackupSuspended');
  }

  /// Updates the active cloud backup provider.
  ///
  /// Dedicated writer — touches only [AppSettingsData.activeProvider].
  /// Every other field is preserved byte-for-byte (FR-13, NFR-05).
  @override
  Future<void> setActiveProvider(SyncProvider provider) async {
    final current = storedSettings ?? AppSettingsData.defaults();
    storedSettings = _rebuild(current, activeProvider: provider);
  }
}
