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
import '../../domain/entities/daily_log_with_symptoms.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../domain/entities/flow_type.dart';
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
    // FlowType: prefer the v4 column. If absent (legacy row written before
    // the migration ran for that connection — defensive only), derive from
    // the legacy `spotting` boolean.
    FlowType? flowType;
    final ftIdx = row.flowType;
    if (ftIdx != null) {
      if (ftIdx < 0 || ftIdx >= FlowType.values.length) {
        throw const DatabaseException(
          'Stored flowType index is out of range',
        );
      }
      flowType = FlowType.values[ftIdx];
    } else if (row.spotting) {
      flowType = FlowType.spotting;
    }

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

    // Domain invariant: intensity is meaningful only for mestruazioni.
    // Drop it on read for assente/spotting rather than surfacing a stale value.
    if (flowType != FlowType.mestruazioni) {
      flow = null;
    }

    return DailyLogEntity(
      date: row.date.toUtc(),
      flowType: flowType,
      flowIntensity: flow,
      otherDischarge: row.otherDischarge,
      painEnabled: row.painEnabled,
      painIntensity: row.painIntensity,
      notesEnabled: row.notesEnabled,
      notes: row.notes,
    );
  }

  static DailyLogsCompanion _toCompanion(DailyLogEntity entity) {
    // Enforce: intensity persisted only when flowType == mestruazioni (DM-02).
    final intensityForRow = entity.flowType == FlowType.mestruazioni
        ? entity.flowIntensity?.index
        : null;
    return DailyLogsCompanion(
      date: Value(_utcDay(entity.date)),
      flowType: Value(entity.flowType?.index),
      flowIntensity: Value(intensityForRow),
      // Keep the legacy `spotting` column in sync for any reader/exporter
      // that hasn't been migrated yet (CSV codec, backup blob).
      spotting: Value(entity.flowType == FlowType.spotting),
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
    final rows = await _dao.getAllOrderedByDate();
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
  Future<Set<DateTime>> getSymptomDatesForMonth(int year, int month) =>
      _dao.getSymptomDatesForMonth(year, month);

  @override
  Stream<Set<DateTime>> watchSymptomDatesForMonth(int year, int month) =>
      _dao.watchSymptomDatesForMonth(year, month);

  @override
  Future<void> replacePainSymptoms(
    DateTime date,
    List<PainSymptomData> symptoms,
  ) =>
      _dao.replacePainSymptoms(
        date,
        symptoms.map((s) => _symptomToCompanion(date, s)).toList(),
      );

  @override
  Future<void> deleteAll() => _dao.deleteAll();

  @override
  Future<void> deleteAllAndReplace(
    List<DailyLogEntity> logs,
    Map<DateTime, List<PainSymptomData>> symptomsMap,
  ) =>
      _dao.transaction(() async {
        // Deletes all daily_logs rows; PainSymptoms cascade-deleted via FK.
        await _dao.deleteAll();
        for (final log in logs) {
          await _dao.upsertDailyLog(_toCompanion(log));
        }
        for (final entry in symptomsMap.entries) {
          final companions = entry.value
              .map((s) => _symptomToCompanion(entry.key, s))
              .toList();
          if (companions.isNotEmpty) {
            await _dao.replacePainSymptoms(entry.key, companions);
          }
        }
      });

  @override
  Future<void> upsertAllLogs(List<DailyLogWithSymptoms> entries) =>
      _dao.transaction(() async {
        for (final e in entries) {
          await _dao.upsertDailyLog(_toCompanion(e.log));
          await _dao.replacePainSymptoms(
            e.log.date,
            e.symptoms.map((s) => _symptomToCompanion(e.log.date, s)).toList(),
          );
        }
      });
}
