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

import '../app_database.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  /// Watches the singleton settings row (id = 1).
  Stream<AppSetting?> watchSettings() =>
      (select(appSettings)..where((t) => t.id.equals(1))).watchSingleOrNull();

  /// Returns the singleton settings row, creating it with defaults if absent.
  ///
  /// Runs inside a transaction to avoid a TOCTOU race on first launch.
  Future<AppSetting> getOrCreateSettings() async {
    return transaction(() async {
      final existing = await (select(appSettings)..where((t) => t.id.equals(1)))
          .getSingleOrNull();
      if (existing != null) return existing;
      await into(appSettings).insert(const AppSettingsCompanion(id: Value(1)));
      return (select(appSettings)..where((t) => t.id.equals(1))).getSingle();
    });
  }

  Future<void> updateSettings(AppSettingsCompanion settings) =>
      (update(appSettings)..where((t) => t.id.equals(1))).write(settings);
}
