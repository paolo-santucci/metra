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

import 'package:metra/core/constants/app_constants.dart';
import 'package:metra/core/util/nullable.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';

class AppSettingsData {
  AppSettingsData({
    required this.languageCode,
    this.darkMode,
    required this.painEnabled,
    required this.notesEnabled,
    required this.notificationDaysBefore,
    required this.notificationsEnabled,
    this.dropboxEmail,
    this.lastBackupAt,
    required this.onboardingCompleted,
    this.declaredCycleLength,
    this.notificationTimeMinutes = AppConstants.kDefaultNotificationTimeMinutes,
    this.firstDayOfWeek = FirstDayOfWeekSetting.system,
    this.lastLogOrSymptomWriteAt,
    // NOT in copyWith — owned by updateBackupSuspended (dedicated-writer pattern).
    // See AppSettingsRepository.updateBackupSuspended.
    this.backupSuspended = false,
  }) {
    if (notificationDaysBefore < 1 || notificationDaysBefore > 7) {
      throw ArgumentError.value(
        notificationDaysBefore,
        'notificationDaysBefore',
        'must be in [1, 7]',
      );
    }
    if (notificationTimeMinutes < 0 || notificationTimeMinutes > 1439) {
      throw ArgumentError.value(
        notificationTimeMinutes,
        'notificationTimeMinutes',
        'must be in [0, 1439]',
      );
    }
  }

  /// Factory returning the defaults that match DB column defaults.
  factory AppSettingsData.defaults() = _AppSettingsDataDefaults;

  final String languageCode;

  /// null means "follow system".
  final bool? darkMode;

  final bool painEnabled;
  final bool notesEnabled;
  final int notificationDaysBefore;

  /// Time of day for the cycle reminder, encoded as minutes-since-midnight.
  ///
  /// Legal range: [0, 1439]. Default 540 = 09:00 local time.
  final int notificationTimeMinutes;

  final bool notificationsEnabled;

  /// Dropbox account email linked to this device, or null if not connected.
  final String? dropboxEmail;

  /// Timestamp of the last successful backup, or null if no backup has run.
  final DateTime? lastBackupAt;

  /// True once the user has completed onboarding.
  final bool onboardingCompleted;

  /// User-declared average cycle length (days), set during onboarding.
  ///
  /// Used by [CyclePredictionService] as a fallback when fewer than 3
  /// measured cycle gaps exist. Null means no value was declared.
  final int? declaredCycleLength;

  /// User preference for the first day of the week in the calendar grid.
  ///
  /// Defaults to [FirstDayOfWeekSetting.system], which delegates to
  /// [MaterialLocalizations.firstDayOfWeekIndex] at render time.
  final FirstDayOfWeekSetting firstDayOfWeek;

  /// UTC timestamp of the last write to DailyLogs or PainSymptoms, or null
  /// if no such write has occurred on this device since installation.
  ///
  /// Written exclusively via [AppSettingsRepository.updateLastDataWriteAt].
  /// Used by [BackupNotifier.backupSilent] as the signal for the skip guard.
  final DateTime? lastLogOrSymptomWriteAt;

  /// Whether the user has suspended automated backups.
  ///
  /// NOT in copyWith — owned by updateBackupSuspended (dedicated-writer pattern).
  /// See AppSettingsRepository.updateBackupSuspended.
  final bool backupSuspended;

  // lastLogOrSymptomWriteAt intentionally omitted from copyWith — it is
  // written exclusively via updateLastDataWriteAt() and must never be reset
  // to null by a general settings update. Mirrors the declaredCycleLength
  // exclusion pattern.
  //
  // backupSuspended intentionally omitted from copyWith — dedicated-writer
  // pattern, written exclusively via updateBackupSuspended().
  AppSettingsData copyWith({
    String? languageCode,
    Nullable<bool>? darkMode,
    bool? painEnabled,
    bool? notesEnabled,
    int? notificationDaysBefore,
    bool? notificationsEnabled,
    Nullable<String>? dropboxEmail,
    Nullable<DateTime>? lastBackupAt,
    bool? onboardingCompleted,
    int? notificationTimeMinutes,
    FirstDayOfWeekSetting? firstDayOfWeek,
  }) {
    return AppSettingsData(
      languageCode: languageCode ?? this.languageCode,
      darkMode: darkMode != null ? darkMode.value : this.darkMode,
      painEnabled: painEnabled ?? this.painEnabled,
      notesEnabled: notesEnabled ?? this.notesEnabled,
      notificationDaysBefore:
          notificationDaysBefore ?? this.notificationDaysBefore,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dropboxEmail:
          dropboxEmail != null ? dropboxEmail.value : this.dropboxEmail,
      lastBackupAt:
          lastBackupAt != null ? lastBackupAt.value : this.lastBackupAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      // declaredCycleLength intentionally omitted from copyWith — it is
      // written exclusively via saveDeclaredCycleLength() and never needs
      // to be reset to null by a general settings update.
      declaredCycleLength: declaredCycleLength,
      notificationTimeMinutes:
          notificationTimeMinutes ?? this.notificationTimeMinutes,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      // lastLogOrSymptomWriteAt preserved as-is (see comment above copyWith).
      lastLogOrSymptomWriteAt: lastLogOrSymptomWriteAt,
      // backupSuspended preserved as-is — dedicated-writer pattern.
      backupSuspended: backupSuspended,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsData &&
          runtimeType == other.runtimeType &&
          languageCode == other.languageCode &&
          darkMode == other.darkMode &&
          painEnabled == other.painEnabled &&
          notesEnabled == other.notesEnabled &&
          notificationDaysBefore == other.notificationDaysBefore &&
          notificationsEnabled == other.notificationsEnabled &&
          dropboxEmail == other.dropboxEmail &&
          lastBackupAt == other.lastBackupAt &&
          onboardingCompleted == other.onboardingCompleted &&
          declaredCycleLength == other.declaredCycleLength &&
          notificationTimeMinutes == other.notificationTimeMinutes &&
          firstDayOfWeek == other.firstDayOfWeek &&
          lastLogOrSymptomWriteAt == other.lastLogOrSymptomWriteAt &&
          backupSuspended == other.backupSuspended;

  @override
  int get hashCode =>
      languageCode.hashCode ^
      darkMode.hashCode ^
      painEnabled.hashCode ^
      notesEnabled.hashCode ^
      notificationDaysBefore.hashCode ^
      notificationsEnabled.hashCode ^
      dropboxEmail.hashCode ^
      lastBackupAt.hashCode ^
      onboardingCompleted.hashCode ^
      declaredCycleLength.hashCode ^
      notificationTimeMinutes.hashCode ^
      firstDayOfWeek.hashCode ^
      lastLogOrSymptomWriteAt.hashCode ^
      backupSuspended.hashCode;
}

class _AppSettingsDataDefaults extends AppSettingsData {
  _AppSettingsDataDefaults()
      : super(
          languageCode: '',
          darkMode: null,
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: false,
          notificationTimeMinutes: AppConstants.kDefaultNotificationTimeMinutes,
          firstDayOfWeek: FirstDayOfWeekSetting.system,
        );
}
