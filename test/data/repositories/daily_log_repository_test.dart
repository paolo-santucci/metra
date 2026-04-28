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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';
import 'package:metra/data/database/daos/daily_log_dao.dart';
import 'package:metra/data/repositories/drift_daily_log_repository.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late DailyLogDao dao;
  late DriftDailyLogRepository repo;

  setUp(() {
    db = _openTestDb();
    dao = db.dailyLogDao;
    repo = DriftDailyLogRepository(dao);
  });

  tearDown(() => db.close());

  final day1 = DateTime.utc(2026, 1, 15);
  final day2 = DateTime.utc(2026, 1, 20);

  DailyLogEntity makeEntity(DateTime date, {FlowIntensity? flow}) =>
      DailyLogEntity(
        date: date,
        flowIntensity: flow ?? FlowIntensity.medium,
        spotting: false,
        otherDischarge: false,
        painEnabled: false,
        notesEnabled: false,
      );

  test('saveDailyLog + watchDay round-trip', () async {
    final entity = makeEntity(day1);
    await repo.saveDailyLog(entity);

    final result = await repo.watchDay(day1).first;
    expect(result, isNotNull);
    expect(result!.date, day1);
    expect(result.flowIntensity, FlowIntensity.medium);
  });

  test('upsert idempotency — second save for same date wins', () async {
    await repo.saveDailyLog(makeEntity(day1, flow: FlowIntensity.light));
    await repo.saveDailyLog(makeEntity(day1, flow: FlowIntensity.heavy));

    final result = await repo.watchDay(day1).first;
    expect(result!.flowIntensity, FlowIntensity.heavy);
  });

  test('deleteDailyLog removes the entry', () async {
    await repo.saveDailyLog(makeEntity(day1));
    await repo.deleteDailyLog(day1);

    final result = await repo.watchDay(day1).first;
    expect(result, isNull);
  });

  test('watchMonth returns only entries for that month', () async {
    await repo.saveDailyLog(makeEntity(day1)); // Jan 2026
    await repo.saveDailyLog(makeEntity(day2)); // Jan 2026
    await repo.saveDailyLog(makeEntity(DateTime.utc(2026, 2, 5))); // Feb 2026

    final janLogs = await repo.watchMonth(2026, 1).first;
    expect(janLogs.length, 2);
    expect(janLogs.map((e) => e.date), containsAll([day1, day2]));

    final febLogs = await repo.watchMonth(2026, 2).first;
    expect(febLogs.length, 1);
  });

  test('replacePainSymptoms: insert 2, replace with 1 → only 1 remains',
      () async {
    await repo.saveDailyLog(makeEntity(day1));
    await repo.replacePainSymptoms(day1, [
      const PainSymptomData(symptomType: PainSymptomType.cramps),
      const PainSymptomData(symptomType: PainSymptomType.headache),
    ]);

    var symptoms = await repo.getPainSymptoms(day1);
    expect(symptoms.length, 2);

    await repo.replacePainSymptoms(day1, [
      const PainSymptomData(symptomType: PainSymptomType.backPain),
    ]);

    symptoms = await repo.getPainSymptoms(day1);
    expect(symptoms.length, 1);
    expect(symptoms.first.symptomType, PainSymptomType.backPain);
  });

  test('getPainSymptoms returns correct data including customLabel', () async {
    await repo.saveDailyLog(makeEntity(day1));
    await repo.replacePainSymptoms(day1, [
      const PainSymptomData(
        symptomType: PainSymptomType.custom,
        customLabel: 'Tension',
      ),
    ]);

    final symptoms = await repo.getPainSymptoms(day1);
    expect(symptoms.length, 1);
    expect(symptoms.first.symptomType, PainSymptomType.custom);
    expect(symptoms.first.customLabel, 'Tension');
  });

  test('getAllOrderedByDate returns all logs sorted ascending', () async {
    await repo.saveDailyLog(makeEntity(day2));
    await repo.saveDailyLog(makeEntity(day1));

    final all = await repo.getAllOrderedByDate();
    expect(all.length, 2);
    expect(all.first.date, day1);
    expect(all.last.date, day2);
  });
}
