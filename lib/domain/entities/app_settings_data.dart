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
import 'package:metra/domain/entities/first_day_of_week_setting.dart';

class AppSettingsData {
  const AppSettingsData({
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
  });

  /// Factory returning the defaults that match DB column defaults.
  const factory AppSettingsData.defaults() = _AppSettingsDataDefaults;

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

  AppSettingsData copyWith({
    String? languageCode,
    bool? darkMode,
    bool? painEnabled,
    bool? notesEnabled,
    int? notificationDaysBefore,
    bool? notificationsEnabled,
    String? dropboxEmail,
    DateTime? lastBackupAt,
    bool? onboardingCompleted,
    int? notificationTimeMinutes,
    FirstDayOfWeekSetting? firstDayOfWeek,
  }) {
    return AppSettingsData(
      languageCode: languageCode ?? this.languageCode,
      darkMode: darkMode ?? this.darkMode,
      painEnabled: painEnabled ?? this.painEnabled,
      notesEnabled: notesEnabled ?? this.notesEnabled,
      notificationDaysBefore:
          notificationDaysBefore ?? this.notificationDaysBefore,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dropboxEmail: dropboxEmail ?? this.dropboxEmail,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      // declaredCycleLength intentionally omitted from copyWith — it is
      // written exclusively via saveDeclaredCycleLength() and never needs
      // to be reset to null by a general settings update.
      declaredCycleLength: declaredCycleLength,
      notificationTimeMinutes:
          notificationTimeMinutes ?? this.notificationTimeMinutes,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
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
          firstDayOfWeek == other.firstDayOfWeek;

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
      firstDayOfWeek.hashCode;
}

class _AppSettingsDataDefaults extends AppSettingsData {
  const _AppSettingsDataDefaults()
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
