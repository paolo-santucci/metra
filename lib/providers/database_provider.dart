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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/database/app_database.dart';
import 'encryption_provider.dart';

/// Provides the initialized AppDatabase.
/// Consumers must handle the loading/error states from AsyncValue.
final databaseProvider = AsyncNotifierProvider<DatabaseNotifier, AppDatabase>(
  DatabaseNotifier.new,
);

class DatabaseNotifier extends AsyncNotifier<AppDatabase> {
  @override
  Future<AppDatabase> build() async {
    final keyService = ref.read(keyManagementServiceProvider);
    final hexKey = await keyService.getOrCreateDatabaseKey();

    final dbPath = kIsWeb
        ? ':memory:'
        : await _resolveDatabasePath('metra.db');

    final executor = AppDatabase.openConnection(dbPath, hexKey);
    final db = AppDatabase(executor);

    ref.onDispose(db.close);
    return db;
  }

  Future<String> _resolveDatabasePath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}$filename';
  }
}
