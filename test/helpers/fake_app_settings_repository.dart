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
    storedSettings = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: dropboxEmail,
      lastBackupAt: lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
      declaredCycleLength: current.declaredCycleLength,
      notificationTimeMinutes: current.notificationTimeMinutes,
      firstDayOfWeek: current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: current.lastLogOrSymptomWriteAt,
      backupSuspended: current.backupSuspended,
    );
  }

  @override
  Future<void> markOnboardingComplete() async {
    final current = storedSettings ?? AppSettingsData.defaults();
    storedSettings = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: true,
      declaredCycleLength: current.declaredCycleLength,
      notificationTimeMinutes: current.notificationTimeMinutes,
      firstDayOfWeek: current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: current.lastLogOrSymptomWriteAt,
      backupSuspended: current.backupSuspended,
    );
  }

  @override
  Future<void> saveDeclaredCycleLength(int cycleLength) async {
    final current = storedSettings ?? AppSettingsData.defaults();
    storedSettings = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
      declaredCycleLength: cycleLength,
      notificationTimeMinutes: current.notificationTimeMinutes,
      firstDayOfWeek: current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: current.lastLogOrSymptomWriteAt,
      backupSuspended: current.backupSuspended,
    );
  }

  @override
  Future<void> updateLastDataWriteAt(DateTime timestamp) async {
    final current = storedSettings ?? AppSettingsData.defaults();
    storedSettings = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
      declaredCycleLength: current.declaredCycleLength,
      notificationTimeMinutes: current.notificationTimeMinutes,
      firstDayOfWeek: current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: timestamp,
      backupSuspended: current.backupSuspended,
    );
  }

  @override
  Future<void> updateBackupSuspended(bool value) async {
    final current = storedSettings ?? AppSettingsData.defaults();
    // backupSuspended is excluded from copyWith — dedicated-writer pattern.
    // Full constructor used to set backupSuspended directly.
    storedSettings = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
      declaredCycleLength: current.declaredCycleLength,
      notificationTimeMinutes: current.notificationTimeMinutes,
      firstDayOfWeek: current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: current.lastLogOrSymptomWriteAt,
      backupSuspended: value,
    );
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
    storedSettings = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
      declaredCycleLength: current.declaredCycleLength,
      notificationTimeMinutes: current.notificationTimeMinutes,
      firstDayOfWeek: current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: current.lastLogOrSymptomWriteAt,
      backupSuspended: false,
    );
    callLog.add('clearBackupSuspended');
  }
}
