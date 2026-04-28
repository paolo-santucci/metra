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

part 'daily_log_dao.g.dart';

@DriftAccessor(tables: [DailyLogs, PainSymptoms])
class DailyLogDao extends DatabaseAccessor<AppDatabase>
    with _$DailyLogDaoMixin {
  DailyLogDao(super.db);

  Stream<DailyLog?> watchDay(DateTime date) =>
      (select(dailyLogs)..where((t) => t.date.equals(date)))
          .watchSingleOrNull();

  Stream<List<DailyLog>> watchMonth(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (select(dailyLogs)
          ..where((t) => t.date.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Future<void> upsertDailyLog(DailyLogsCompanion entry) =>
      into(dailyLogs).insertOnConflictUpdate(entry);

  Future<void> deleteDailyLog(DateTime date) =>
      (delete(dailyLogs)..where((t) => t.date.equals(date))).go();

  Future<List<PainSymptom>> getPainSymptoms(DateTime date) =>
      (select(painSymptoms)..where((t) => t.dailyLogDate.equals(date))).get();

  Future<void> replacePainSymptoms(
    DateTime date,
    List<PainSymptomsCompanion> symptoms,
  ) =>
      transaction(() async {
        await (delete(painSymptoms)
              ..where((t) => t.dailyLogDate.equals(date)))
            .go();
        await batch((b) => b.insertAll(painSymptoms, symptoms));
      });
}
