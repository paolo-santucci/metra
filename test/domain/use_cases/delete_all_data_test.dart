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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/use_cases/delete_all_data.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

void main() {
  late FakeDailyLogRepository fakeLogRepo;
  late FakeCycleEntryRepository fakeCycleRepo;
  late FakeAppSettingsRepository fakeSettingsRepo;
  late DeleteAllData useCase;

  setUp(() {
    fakeLogRepo = FakeDailyLogRepository();
    fakeCycleRepo = FakeCycleEntryRepository();
    fakeSettingsRepo = FakeAppSettingsRepository();
    useCase = DeleteAllData(fakeLogRepo, fakeCycleRepo, fakeSettingsRepo);
  });

  test(
    'given_three_repos_when_constructed_then_DeleteAllData_accepts_AppSettingsRepository',
    () {
      final instance = DeleteAllData(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
        FakeAppSettingsRepository(),
      );
      expect(instance, isA<DeleteAllData>());
    },
  );

  test('execute() calls deleteAll on both repositories', () async {
    await useCase.execute();

    expect(fakeLogRepo.deleteAllCalled, isTrue);
    expect(fakeCycleRepo.deleteAllCalled, isTrue);
  });

  test('execute() clears data in both fakes', () async {
    await fakeLogRepo
        .saveDailyLog(DailyLogEntity(date: DateTime.utc(2026, 1, 1)));
    await fakeCycleRepo.insert(
      CycleEntryEntity(id: 0, startDate: DateTime.utc(2026, 1, 1)),
    );

    await useCase.execute();

    expect(fakeLogRepo.savedLogs, isEmpty);
    expect(fakeCycleRepo.entries, isEmpty);
  });

  test(
    'FR-12a — happy path: updateBackupSuspended(true) recorded AFTER both deleteAll calls',
    () async {
      final fakeLogs = FakeDailyLogRepository();
      final fakeCycles = FakeCycleEntryRepository();
      final fakeSettings = FakeAppSettingsRepository();
      await DeleteAllData(fakeLogs, fakeCycles, fakeSettings).execute();
      expect(fakeLogs.callLog, contains('deleteAll'));
      expect(fakeCycles.callLog, contains('deleteAll'));
      expect(fakeSettings.callLog, contains('updateBackupSuspended:true'));
    },
  );

  test(
    'NFR-04 — partial failure: cycleRepo.deleteAll throws, settings is not mutated',
    () async {
      final fakeLogs = FakeDailyLogRepository();
      final fakeCycles = FakeCycleEntryRepository()
        ..throwOnDeleteAll = StateError('boom');
      final fakeSettings = FakeAppSettingsRepository();
      await expectLater(
        DeleteAllData(fakeLogs, fakeCycles, fakeSettings).execute(),
        throwsA(isA<StateError>()),
      );
      expect(
        fakeSettings.callLog.contains('updateBackupSuspended:true'),
        isFalse,
      );
    },
  );
}
