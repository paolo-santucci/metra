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
  });

  /// Factory returning the defaults that match DB column defaults.
  const factory AppSettingsData.defaults() = _AppSettingsDataDefaults;

  final String languageCode;

  /// null means "follow system".
  final bool? darkMode;

  final bool painEnabled;
  final bool notesEnabled;
  final int notificationDaysBefore;
  final bool notificationsEnabled;

  /// Dropbox account email linked to this device, or null if not connected.
  final String? dropboxEmail;

  /// Timestamp of the last successful backup, or null if no backup has run.
  final DateTime? lastBackupAt;

  AppSettingsData copyWith({
    String? languageCode,
    bool? darkMode,
    bool? painEnabled,
    bool? notesEnabled,
    int? notificationDaysBefore,
    bool? notificationsEnabled,
    String? dropboxEmail,
    DateTime? lastBackupAt,
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
          lastBackupAt == other.lastBackupAt;

  @override
  int get hashCode =>
      languageCode.hashCode ^
      darkMode.hashCode ^
      painEnabled.hashCode ^
      notesEnabled.hashCode ^
      notificationDaysBefore.hashCode ^
      notificationsEnabled.hashCode ^
      dropboxEmail.hashCode ^
      lastBackupAt.hashCode;
}

class _AppSettingsDataDefaults extends AppSettingsData {
  const _AppSettingsDataDefaults()
      : super(
          languageCode: 'it',
          darkMode: null,
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
        );
}
