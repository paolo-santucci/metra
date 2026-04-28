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

  /// Normalizes [date] to UTC midnight so that all date comparisons are
  /// consistent regardless of the local timezone the caller used.
  DateTime _toUtcDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  /// Normalizes the date to UTC midnight before upserting.
  Future<void> upsertDailyLog(DailyLogsCompanion entry) {
    if (entry.date.present) {
      entry = entry.copyWith(date: Value(_toUtcDay(entry.date.value)));
    }
    return into(dailyLogs).insertOnConflictUpdate(entry);
  }

  Stream<DailyLog?> watchDay(DateTime date) =>
      (select(dailyLogs)..where((t) => t.date.equals(_toUtcDay(date))))
          .watchSingleOrNull();

  Stream<List<DailyLog>> watchMonth(int year, int month) {
    final start = DateTime.utc(year, month);
    // Half-open interval [start, end) — excludes the first day of next month.
    final end = DateTime.utc(year, month + 1);
    return (select(dailyLogs)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Future<void> deleteDailyLog(DateTime date) =>
      (delete(dailyLogs)..where((t) => t.date.equals(_toUtcDay(date)))).go();

  Future<List<PainSymptom>> getPainSymptoms(DateTime date) =>
      (select(painSymptoms)
            ..where((t) => t.dailyLogDate.equals(_toUtcDay(date))))
          .get();

  Stream<List<PainSymptom>> watchPainSymptoms(DateTime date) =>
      (select(painSymptoms)
            ..where((t) => t.dailyLogDate.equals(_toUtcDay(date))))
          .watch();

  Future<void> replacePainSymptoms(
    DateTime date,
    List<PainSymptomsCompanion> symptoms,
  ) =>
      transaction(() async {
        await (delete(painSymptoms)
              ..where((t) => t.dailyLogDate.equals(_toUtcDay(date))))
            .go();
        await batch((b) => b.insertAll(painSymptoms, symptoms));
      });
}
