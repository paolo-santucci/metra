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

import '../../core/errors/metra_exception.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/daily_log_dao.dart';
import '../../domain/entities/daily_log_entity.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../domain/entities/pain_symptom_data.dart';
import '../../domain/entities/pain_symptom_type.dart';
import '../../domain/repositories/daily_log_repository.dart';

class DriftDailyLogRepository implements DailyLogRepository {
  const DriftDailyLogRepository(this._dao);

  final DailyLogDao _dao;

  // ---- mapping helpers ----

  static DateTime _utcDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  static DailyLogEntity _fromRow(DailyLog row) {
    final flowIdx = row.flowIntensity;
    FlowIntensity? flow;
    if (flowIdx != null) {
      if (flowIdx < 0 || flowIdx >= FlowIntensity.values.length) {
        throw const DatabaseException(
          'Stored flowIntensity index is out of range',
        );
      }
      flow = FlowIntensity.values[flowIdx];
    }
    return DailyLogEntity(
      date: row.date.toUtc(),
      flowIntensity: flow,
      spotting: row.spotting,
      otherDischarge: row.otherDischarge,
      painEnabled: row.painEnabled,
      painIntensity: row.painIntensity,
      notesEnabled: row.notesEnabled,
      notes: row.notes,
    );
  }

  static DailyLogsCompanion _toCompanion(DailyLogEntity entity) {
    return DailyLogsCompanion(
      date: Value(_utcDay(entity.date)),
      flowIntensity: Value(entity.flowIntensity?.index),
      spotting: Value(entity.spotting),
      otherDischarge: Value(entity.otherDischarge),
      painEnabled: Value(entity.painEnabled),
      painIntensity: Value(entity.painIntensity),
      notesEnabled: Value(entity.notesEnabled),
      notes: Value(entity.notes),
    );
  }

  static PainSymptomData _symptomFromRow(PainSymptom row) {
    final typeIdx = row.symptomType;
    if (typeIdx < 0 || typeIdx >= PainSymptomType.values.length) {
      throw const DatabaseException(
        'Stored symptomType index is out of range',
      );
    }
    return PainSymptomData(
      symptomType: PainSymptomType.values[typeIdx],
      customLabel: row.customLabel,
    );
  }

  static PainSymptomsCompanion _symptomToCompanion(
    DateTime date,
    PainSymptomData data,
  ) {
    return PainSymptomsCompanion.insert(
      dailyLogDate: _utcDay(date),
      symptomType: data.symptomType.index,
      customLabel: Value(data.customLabel),
    );
  }

  // ---- interface implementation ----

  @override
  Stream<DailyLogEntity?> watchDay(DateTime date) =>
      _dao.watchDay(date).map((row) => row == null ? null : _fromRow(row));

  @override
  Stream<List<DailyLogEntity>> watchMonth(int year, int month) =>
      _dao.watchMonth(year, month).map(
            (rows) => rows.map(_fromRow).toList(),
          );

  @override
  Future<List<DailyLogEntity>> getAllOrderedByDate() async {
    // getAllOrderedByDate is not on the DAO (DAO is frozen), so we query
    // through the database accessor exposed by the DAO.
    final db = _dao.attachedDatabase;
    final rows = await (db.select(db.dailyLogs)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> saveDailyLog(DailyLogEntity log) =>
      _dao.upsertDailyLog(_toCompanion(log));

  @override
  Future<void> deleteDailyLog(DateTime date) => _dao.deleteDailyLog(date);

  @override
  Future<List<PainSymptomData>> getPainSymptoms(DateTime date) async {
    final rows = await _dao.getPainSymptoms(date);
    return rows.map(_symptomFromRow).toList();
  }

  @override
  Future<void> replacePainSymptoms(
    DateTime date,
    List<PainSymptomData> symptoms,
  ) =>
      _dao.replacePainSymptoms(
        date,
        symptoms.map((s) => _symptomToCompanion(date, s)).toList(),
      );
}
