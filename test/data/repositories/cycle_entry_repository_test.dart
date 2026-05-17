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
import 'package:metra/data/database/daos/cycle_entry_dao.dart';
import 'package:metra/data/repositories/drift_cycle_entry_repository.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';

import '../../helpers/fake_app_settings_repository.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late CycleEntryDao dao;
  late DriftCycleEntryRepository repo;
  late FakeAppSettingsRepository settingsRepo;

  setUp(() {
    db = _openTestDb();
    dao = db.cycleEntryDao;
    settingsRepo = FakeAppSettingsRepository();
    repo = DriftCycleEntryRepository(dao, settingsRepo);
  });

  test('DriftCycleEntryRepository ctor accepts AppSettingsRepository', () {
    // Verifies the two-arg constructor compiles and constructs without error.
    final constructed =
        DriftCycleEntryRepository(dao, FakeAppSettingsRepository());
    expect(constructed, isA<DriftCycleEntryRepository>());
  });

  tearDown(() => db.close());

  CycleEntryEntity makeEntry({
    int id = 0,
    required DateTime startDate,
    DateTime? endDate,
    int? cycleLength,
    int? periodLength,
  }) =>
      CycleEntryEntity(
        id: id,
        startDate: startDate,
        endDate: endDate,
        cycleLength: cycleLength,
        periodLength: periodLength,
      );

  test('insert + getRecent(n) returns n most recent by startDate desc',
      () async {
    final jan = DateTime.utc(2026, 1, 1);
    final feb = DateTime.utc(2026, 2, 1);
    final mar = DateTime.utc(2026, 3, 1);

    await repo.insert(makeEntry(startDate: jan, cycleLength: 28));
    await repo.insert(makeEntry(startDate: feb, cycleLength: 27));
    await repo.insert(makeEntry(startDate: mar, cycleLength: 29));

    final recent = await repo.getRecent(2);
    expect(recent.length, 2);
    // Most recent first (descending).
    expect(recent.first.startDate, mar);
    expect(recent.last.startDate, feb);
  });

  test('update changes fields', () async {
    final start = DateTime.utc(2026, 1, 1);
    final inserted =
        await repo.insert(makeEntry(startDate: start, cycleLength: 28));
    final updated = inserted.copyWith(cycleLength: 30);
    await repo.update(updated);

    final all = await repo.getRecent(10);
    expect(all.first.cycleLength, 30);
  });

  test('delete removes entry', () async {
    final start = DateTime.utc(2026, 1, 1);
    final inserted = await repo.insert(makeEntry(startDate: start));
    await repo.delete(inserted.id);

    final all = await repo.getRecent(10);
    expect(all, isEmpty);
  });

  test('watchAll emits updated list on change', () async {
    final start = DateTime.utc(2026, 1, 1);
    final stream = repo.watchAll();

    // First emission is empty.
    expect(await stream.first, isEmpty);

    await repo.insert(makeEntry(startDate: start));

    // Second emission contains the inserted entry.
    final emitted = await stream.first;
    expect(emitted.length, 1);
    expect(emitted.first.startDate, start);
  });

  test('replaceAll clears previous and inserts new entries', () async {
    final jan = DateTime.utc(2026, 1, 1);
    final feb = DateTime.utc(2026, 2, 1);
    final mar = DateTime.utc(2026, 3, 1);

    await repo.insert(makeEntry(startDate: jan));
    await repo.insert(makeEntry(startDate: feb));

    await repo.replaceAll([makeEntry(startDate: mar, cycleLength: 29)]);

    final all = await repo.getRecent(10);
    expect(all.length, 1);
    expect(all.first.startDate, mar);
  });

  test('replaceAll with empty list clears all entries', () async {
    final jan = DateTime.utc(2026, 1, 1);
    await repo.insert(makeEntry(startDate: jan));

    await repo.replaceAll([]);

    final all = await repo.getRecent(10);
    expect(all, isEmpty);
  });

  test('getByStartDate returns matching entity when it exists', () async {
    final date = DateTime.utc(2025, 1, 15);
    await repo.insert(makeEntry(startDate: date, cycleLength: 28));

    final result = await repo.getByStartDate(date);

    expect(result, isNotNull);
    expect(result!.startDate, date);
    expect(result.cycleLength, 28);
  });

  test('getByStartDate returns null when no entry exists for the date',
      () async {
    final result = await repo.getByStartDate(DateTime.utc(2025, 6, 1));

    expect(result, isNull);
  });

  test('getByStartDate returns null when an entry exists for a different date',
      () async {
    await repo.insert(makeEntry(startDate: DateTime.utc(2025, 1, 15)));

    final result = await repo.getByStartDate(DateTime.utc(2025, 2, 15));

    expect(result, isNull);
  });

  // ---- clear-on-write sentinel tests (FR-12b / FR-12c) ----

  test('insert clears sentinel (FR-12b)', () async {
    await settingsRepo.updateBackupSuspended(true);
    await repo.insert(makeEntry(startDate: DateTime.utc(2026, 5, 1)));
    expect((await settingsRepo.getOrCreate()).backupSuspended, isFalse);
  });

  test('update clears sentinel (FR-12b)', () async {
    final entry = makeEntry(startDate: DateTime.utc(2026, 5, 1));
    final inserted = await repo.insert(entry);
    await settingsRepo.updateBackupSuspended(true);
    await repo.update(
      inserted.copyWith(endDate: DateTime.utc(2026, 5, 20)),
    );
    expect((await settingsRepo.getOrCreate()).backupSuspended, isFalse);
  });

  test('replaceAll does NOT clear sentinel (FR-12c — restore/recompute path)',
      () async {
    await settingsRepo.updateBackupSuspended(true);
    await repo.replaceAll([makeEntry(startDate: DateTime.utc(2026, 5, 1))]);
    expect((await settingsRepo.getOrCreate()).backupSuspended, isTrue);
  });
}
