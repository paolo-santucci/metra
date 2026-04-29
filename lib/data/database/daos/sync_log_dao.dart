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

part 'sync_log_dao.g.dart';

@DriftAccessor(tables: [SyncLogs])
class SyncLogDao extends DatabaseAccessor<AppDatabase> with _$SyncLogDaoMixin {
  SyncLogDao(super.db);

  Future<int> insertLog(SyncLogsCompanion entry) =>
      into(syncLogs).insert(entry);

  Future<List<SyncLog>> getRecent(int limit) => (select(syncLogs)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
        ..limit(limit))
      .get();

  Future<void> deleteAllLogs() => delete(syncLogs).go();
}
