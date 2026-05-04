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
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/services/csv_codec.dart';
import 'package:metra/domain/use_cases/import_daily_logs.dart';
import 'package:metra/domain/use_cases/recompute_cycle_entries.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

void main() {
  late FakeDailyLogRepository fakeLogRepo;
  late FakeCycleEntryRepository fakeCycleRepo;
  late RecomputeCycleEntries recompute;
  late ImportDailyLogs useCase;

  final date1 = DateTime.utc(2026, 1, 1);
  final date2 = DateTime.utc(2026, 2, 1);
  final date3 = DateTime.utc(2026, 3, 1);

  DailyLogRow makeRow(DateTime date) => DailyLogRow(
        log: DailyLogEntity(date: date),
        symptoms: const [],
      );

  DailyLogRow makeRowWithSymptom(DateTime date) => DailyLogRow(
        log: DailyLogEntity(date: date, painEnabled: true),
        symptoms: [
          const PainSymptomData(symptomType: PainSymptomType.headache),
        ],
      );

  setUp(() {
    fakeLogRepo = FakeDailyLogRepository();
    fakeCycleRepo = FakeCycleEntryRepository();
    recompute = RecomputeCycleEntries(fakeLogRepo, fakeCycleRepo);
    useCase = ImportDailyLogs(fakeLogRepo, recompute);
  });

  group('deleteAndImport mode', () {
    test('calls deleteAllAndReplace with correct logs', () async {
      final rows = [makeRow(date1), makeRow(date2)];
      await useCase.execute(rows: rows, mode: ImportMode.deleteAndImport);

      expect(
        fakeLogRepo.deleteAllAndReplaceCalledWithLogs,
        isNotNull,
      );
      expect(
        fakeLogRepo.deleteAllAndReplaceCalledWithLogs!.map((l) => l.date),
        containsAll([date1, date2]),
      );
    });

    test('returns imported = rows.length, skipped = 0', () async {
      final result = await useCase.execute(
        rows: [makeRow(date1), makeRow(date2)],
        mode: ImportMode.deleteAndImport,
      );
      expect(result.imported, 2);
      expect(result.skipped, 0);
    });

    test('symptoms are stored via deleteAllAndReplace', () async {
      final rows = [makeRowWithSymptom(date1)];
      await useCase.execute(rows: rows, mode: ImportMode.deleteAndImport);

      final storedSymptoms = await fakeLogRepo.getPainSymptoms(date1);
      expect(storedSymptoms, hasLength(1));
      expect(storedSymptoms.first.symptomType, PainSymptomType.headache);
    });
  });

  group('overwrite mode', () {
    test('existing date is replaced by CSV row', () async {
      await fakeLogRepo.saveDailyLog(
        DailyLogEntity(date: date1, notes: 'old note', notesEnabled: true),
      );

      final csvRow = DailyLogRow(
        log: DailyLogEntity(date: date1, notes: 'new note', notesEnabled: true),
        symptoms: const [],
      );
      await useCase.execute(rows: [csvRow], mode: ImportMode.overwrite);

      final saved = fakeLogRepo.savedLogs.firstWhere((l) => l.date == date1);
      expect(saved.notes, 'new note');
    });

    test('date not in CSV is left untouched', () async {
      await fakeLogRepo.saveDailyLog(DailyLogEntity(date: date3));

      await useCase.execute(
        rows: [makeRow(date1)],
        mode: ImportMode.overwrite,
      );

      expect(
        fakeLogRepo.savedLogs.any((l) => l.date == date3),
        isTrue,
      );
    });

    test('returns imported = rows.length, skipped = 0', () async {
      final result = await useCase.execute(
        rows: [makeRow(date1), makeRow(date2)],
        mode: ImportMode.overwrite,
      );
      expect(result.imported, 2);
      expect(result.skipped, 0);
    });
  });

  group('keepExisting mode', () {
    test('existing date is NOT overwritten', () async {
      await fakeLogRepo.saveDailyLog(
        DailyLogEntity(date: date1, notes: 'original', notesEnabled: true),
      );

      await useCase.execute(
        rows: [
          DailyLogRow(
            log: DailyLogEntity(date: date1, notes: 'csv', notesEnabled: true),
            symptoms: const [],
          ),
        ],
        mode: ImportMode.keepExisting,
      );

      final saved = fakeLogRepo.savedLogs.firstWhere((l) => l.date == date1);
      expect(saved.notes, 'original');
    });

    test('new date IS inserted', () async {
      await useCase.execute(
        rows: [makeRow(date2)],
        mode: ImportMode.keepExisting,
      );
      expect(
        fakeLogRepo.savedLogs.any((l) => l.date == date2),
        isTrue,
      );
    });

    test('skipped count matches existing-date rows', () async {
      await fakeLogRepo.saveDailyLog(DailyLogEntity(date: date1));

      final result = await useCase.execute(
        rows: [makeRow(date1), makeRow(date2)],
        mode: ImportMode.keepExisting,
      );
      expect(result.imported, 1);
      expect(result.skipped, 1);
    });
  });

  group('recompute called after all modes', () {
    test('deleteAndImport: cycle entries recomputed', () async {
      await useCase.execute(rows: [], mode: ImportMode.deleteAndImport);
      // replaceAll called with empty list (no flow days)
      expect(fakeCycleRepo.entries, isEmpty);
    });

    test('overwrite: cycle entries recomputed', () async {
      await useCase.execute(rows: [], mode: ImportMode.overwrite);
      expect(fakeCycleRepo.entries, isEmpty);
    });

    test('keepExisting: cycle entries recomputed', () async {
      await useCase.execute(rows: [], mode: ImportMode.keepExisting);
      expect(fakeCycleRepo.entries, isEmpty);
    });
  });
}
