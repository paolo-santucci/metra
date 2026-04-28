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

import '../../data/database/app_database.dart';
import '../../data/database/daos/cycle_entry_dao.dart';
import '../../domain/entities/cycle_entry_entity.dart';
import '../../domain/repositories/cycle_entry_repository.dart';

class DriftCycleEntryRepository implements CycleEntryRepository {
  const DriftCycleEntryRepository(this._dao);

  final CycleEntryDao _dao;

  // ---- mapping helpers ----

  static CycleEntryEntity _fromRow(CycleEntry row) => CycleEntryEntity(
        id: row.id,
        startDate: row.startDate.toUtc(),
        endDate: row.endDate?.toUtc(),
        cycleLength: row.cycleLength,
        periodLength: row.periodLength,
      );

  static CycleEntriesCompanion _toInsertCompanion(CycleEntryEntity entity) =>
      CycleEntriesCompanion.insert(
        startDate: entity.startDate,
        endDate: Value(entity.endDate),
        cycleLength: Value(entity.cycleLength),
        periodLength: Value(entity.periodLength),
      );

  static CycleEntriesCompanion _toUpdateCompanion(CycleEntryEntity entity) =>
      CycleEntriesCompanion(
        id: Value(entity.id),
        startDate: Value(entity.startDate),
        endDate: Value(entity.endDate),
        cycleLength: Value(entity.cycleLength),
        periodLength: Value(entity.periodLength),
      );

  // ---- interface implementation ----

  @override
  Stream<List<CycleEntryEntity>> watchAll() =>
      _dao.watchAllOrderedByStart().map(
            (rows) => rows.map(_fromRow).toList(),
          );

  @override
  Future<List<CycleEntryEntity>> getRecent(int n) async {
    final rows = await _dao.getRecentCycles(n);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<CycleEntryEntity> insert(CycleEntryEntity entry) async {
    final id = await _dao.insertCycleEntry(_toInsertCompanion(entry));
    return entry.copyWith(id: id);
  }

  @override
  Future<void> update(CycleEntryEntity entry) =>
      _dao.updateCycleEntry(_toUpdateCompanion(entry));

  @override
  Future<void> delete(int id) => _dao.deleteCycleEntry(id);

  @override
  Future<void> replaceAll(List<CycleEntryEntity> entries) async {
    final db = _dao.attachedDatabase;
    await db.transaction(() async {
      // Delete all existing rows.
      await db.delete(db.cycleEntries).go();
      // Insert replacements; IDs are auto-assigned.
      for (final entry in entries) {
        await db.into(db.cycleEntries).insert(_toInsertCompanion(entry));
      }
    });
  }
}
