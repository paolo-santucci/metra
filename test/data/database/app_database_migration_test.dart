// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';

void main() {
  test('schema version is 4', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 4);
  });

  test('AppSettings has dropboxEmail and lastBackupAt columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = await db.appSettingsDao.getOrCreateSettings();
    expect(settings.dropboxEmail, isNull);
    expect(settings.lastBackupAt, isNull);
  });

  test('AppSettings has onboardingCompleted column defaulting to false',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = await db.appSettingsDao.getOrCreateSettings();
    expect(settings.onboardingCompleted, isFalse);
  });
}
