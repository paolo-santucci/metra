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
import 'package:metra/data/repositories/drift_app_settings_repository.dart';
import 'package:metra/data/repositories/drift_daily_log_repository.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/daily_log_with_symptoms.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';

import '../../helpers/fake_app_settings_repository.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late DailyLogDao dao;
  late DriftDailyLogRepository repo;

  setUp(() {
    db = _openTestDb();
    dao = db.dailyLogDao;
    repo = DriftDailyLogRepository(dao, FakeAppSettingsRepository());
  });

  tearDown(() => db.close());

  final day1 = DateTime.utc(2026, 1, 15);
  final day2 = DateTime.utc(2026, 1, 20);

  DailyLogEntity makeEntity(DateTime date, {FlowIntensity? flow}) {
    final fi = flow ?? FlowIntensity.medium;
    return DailyLogEntity(
      date: date,
      flowType: FlowType.mestruazioni,
      flowIntensity: fi,
      otherDischarge: false,
      painEnabled: false,
      notesEnabled: false,
    );
  }

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
      const PainSymptomData(symptomType: PainSymptomType.bloating),
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

  group('lastLogOrSymptomWriteAt bumps', () {
    late FakeAppSettingsRepository fakeSettings;
    late AppDatabase bumpDb;
    late DriftDailyLogRepository bumpRepo;
    final fixedTime = DateTime.utc(2026, 5, 14, 10);

    setUp(() async {
      fakeSettings = FakeAppSettingsRepository();
      bumpDb = AppDatabase(NativeDatabase.memory());
      bumpRepo = DriftDailyLogRepository(
        bumpDb.dailyLogDao,
        fakeSettings,
        now: () => fixedTime,
      );
    });

    tearDown(() => bumpDb.close());

    test('saveDailyLog bumps lastLogOrSymptomWriteAt', () async {
      await bumpRepo.saveDailyLog(makeEntity(DateTime.utc(2026, 5, 14)));
      expect(
        (await fakeSettings.getOrCreate()).lastLogOrSymptomWriteAt,
        equals(fixedTime),
      );
    });

    test('deleteDailyLog bumps lastLogOrSymptomWriteAt', () async {
      await bumpRepo.saveDailyLog(makeEntity(DateTime.utc(2026, 5, 14)));
      final time2 = DateTime.utc(2026, 5, 14, 11);
      final repo2 = DriftDailyLogRepository(
        bumpDb.dailyLogDao,
        fakeSettings,
        now: () => time2,
      );
      await repo2.deleteDailyLog(DateTime.utc(2026, 5, 14));
      expect(
        (await fakeSettings.getOrCreate()).lastLogOrSymptomWriteAt,
        equals(time2),
      );
    });

    test('replacePainSymptoms bumps lastLogOrSymptomWriteAt', () async {
      await bumpRepo.saveDailyLog(makeEntity(DateTime.utc(2026, 5, 14)));
      await bumpRepo.replacePainSymptoms(DateTime.utc(2026, 5, 14), []);
      expect(
        (await fakeSettings.getOrCreate()).lastLogOrSymptomWriteAt,
        equals(fixedTime),
      );
    });

    test('deleteAll bumps lastLogOrSymptomWriteAt', () async {
      await bumpRepo.deleteAll();
      expect(
        (await fakeSettings.getOrCreate()).lastLogOrSymptomWriteAt,
        equals(fixedTime),
      );
    });

    test('deleteAllAndReplace bumps lastLogOrSymptomWriteAt after transaction',
        () async {
      await bumpRepo.deleteAllAndReplace(
        [makeEntity(DateTime.utc(2026, 5, 14))],
        {},
      );
      expect(
        (await fakeSettings.getOrCreate()).lastLogOrSymptomWriteAt,
        equals(fixedTime),
      );
    });

    test('upsertAllLogs bumps lastLogOrSymptomWriteAt after transaction',
        () async {
      await bumpRepo.upsertAllLogs([
        DailyLogWithSymptoms(
          log: makeEntity(DateTime.utc(2026, 5, 14)),
          symptoms: [],
        ),
      ]);
      expect(
        (await fakeSettings.getOrCreate()).lastLogOrSymptomWriteAt,
        equals(fixedTime),
      );
    });
  });

  // -----------------------------------------------------------------------
  // TASK-07: real-Drift bump round-trip across all 6 write methods
  // Platform: Android + Linux (in-memory Drift, no device dependency)
  // -----------------------------------------------------------------------
  group('real-Drift bump round-trip', () {
    late AppDatabase roundTripDb;
    late DriftAppSettingsRepository realSettingsRepo;

    setUp(() {
      roundTripDb = AppDatabase(NativeDatabase.memory());
      realSettingsRepo = DriftAppSettingsRepository(roundTripDb.appSettingsDao);
    });

    tearDown(() => roundTripDb.close());

    test(
      'all 6 write methods bump lastLogOrSymptomWriteAt under real Drift',
      () async {
        // Ensure the settings singleton row exists before any targeted write.
        await realSettingsRepo.getOrCreate();

        var clock = DateTime.utc(2026, 5, 14, 10, 0, 0);
        final realRepo = DriftDailyLogRepository(
          roundTripDb.dailyLogDao,
          realSettingsRepo,
          now: () => clock,
        );

        // Helper dates: use different dates to avoid FK / unique conflicts.
        final d1 = DateTime.utc(2026, 5, 14);
        final d2 = DateTime.utc(2026, 5, 15);
        final d3 = DateTime.utc(2026, 5, 16);

        // Sequence of actions for the 6 write methods.
        // Order chosen to satisfy FK constraints:
        //   saveDailyLog (creates d1 row)
        //   replacePainSymptoms (operates on existing d1 row)
        //   deleteDailyLog (removes d1 row)
        //   upsertAllLogs (creates d2 row)
        //   deleteAllAndReplace (replaces with d3 row)
        //   deleteAll (removes everything)
        final actions = <Future<void> Function()>[
          () => realRepo.saveDailyLog(makeEntity(d1)),
          () => realRepo.replacePainSymptoms(d1, [
                const PainSymptomData(symptomType: PainSymptomType.headache),
              ]),
          () => realRepo.deleteDailyLog(d1),
          () => realRepo.upsertAllLogs([
                DailyLogWithSymptoms(log: makeEntity(d2), symptoms: []),
              ]),
          () => realRepo.deleteAllAndReplace([makeEntity(d3)], {}),
          realRepo.deleteAll,
        ];

        DateTime? lastTs;
        for (final action in actions) {
          clock = clock.add(const Duration(minutes: 1));
          await action();
          final ts = (await realSettingsRepo.getOrCreate())
              .lastLogOrSymptomWriteAt
              ?.toUtc();
          expect(
            ts,
            isNotNull,
            reason: 'bump must set lastLogOrSymptomWriteAt',
          );
          if (lastTs != null) {
            expect(
              ts!.isAfter(lastTs) || ts == lastTs,
              isTrue,
              reason: 'timestamps must be monotonically non-decreasing',
            );
          }
          lastTs = ts;
        }
      },
    );

    // TASK-07 Test 2: watchSettings emits after a daily log write
    test(
      'watchSettings emits updated lastLogOrSymptomWriteAt after saveDailyLog',
      () async {
        // Ensure the settings singleton row exists so the stream has an
        // initial value before we subscribe.
        await realSettingsRepo.getOrCreate();

        final writeTime = DateTime.utc(2026, 5, 14, 12, 0, 0);
        final realRepo = DriftDailyLogRepository(
          roundTripDb.dailyLogDao,
          realSettingsRepo,
          now: () => writeTime,
        );

        // Subscribe before the write to capture the emission triggered by it.
        final stream = realSettingsRepo.watchSettings();

        // Perform the write.
        await realRepo.saveDailyLog(makeEntity(DateTime.utc(2026, 5, 14)));

        // The stream must emit a value where lastLogOrSymptomWriteAt is set.
        // Take 1 emission after the write; the Drift stream emits on every
        // DB change so the first post-write value should carry the new ts.
        final emitted = await stream
            .where((s) => s?.lastLogOrSymptomWriteAt != null)
            .first
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw StateError(
                'watchSettings did not emit lastLogOrSymptomWriteAt != null '
                'within 5 s after saveDailyLog',
              ),
            );
        expect(emitted, isNotNull);
        expect(emitted!.lastLogOrSymptomWriteAt?.toUtc(), equals(writeTime));
      },
    );
  });
}
