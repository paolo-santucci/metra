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
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/use_cases/get_cycle_notes.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

final _jan15 = DateTime.utc(2026, 1, 15);
final _jan16 = DateTime.utc(2026, 1, 16);
final _jan19 = DateTime.utc(2026, 1, 19);
final _jan20 = DateTime.utc(2026, 1, 20);

CycleEntryEntity _cycle() =>
    CycleEntryEntity(id: 1, startDate: _jan15, endDate: _jan20);

void main() {
  group('GetCycleNotes', () {
    test(
      'given_mixed_notes_when_watching_cycles_then_emits_only_the_note_bearing_logs',
      () async {
        final cycleRepo = FakeCycleEntryRepository()..entries.add(_cycle());
        final logRepo = FakeDailyLogRepository()
          ..savedLogs.addAll([
            DailyLogEntity(date: _jan15, notes: 'Crampi forti'),
            // Non-midnight timestamps are keyed by their normalized date.
            DailyLogEntity(date: DateTime(2026, 1, 16, 14, 30), notes: '   '),
            DailyLogEntity(date: DateTime.utc(2026, 1, 17)),
            DailyLogEntity(date: DateTime.utc(2026, 1, 18), notes: ''),
            // notesEnabled is not consulted: a saved note is projected as-is.
            DailyLogEntity(
              date: _jan19,
              notes: 'Nota',
              notesEnabled: false,
            ),
          ]);
        final useCase = GetCycleNotes(logRepo, cycleRepo);

        expect(await useCase().first, {
          _jan15: 'Crampi forti',
          _jan16: '   ',
          _jan19: 'Nota',
        });
      },
    );

    test(
      'given_no_cycles_when_watching_then_emits_an_empty_map_without_reading_logs',
      () async {
        final logRepo = _CountingFakeDailyLogRepository()
          ..savedLogs.add(DailyLogEntity(date: _jan15, notes: 'Ignorata'));
        final useCase = GetCycleNotes(logRepo, FakeCycleEntryRepository());

        expect(await useCase().first, isEmpty);
        expect(logRepo.getAllOrderedByDateCalls, 0);
      },
    );

    test(
      'given_two_watch_emissions_when_a_note_is_edited_then_re_emits_the_new_text',
      () async {
        final cycleRepo = FakeCycleEntryRepository();
        final logRepo = FakeDailyLogRepository()
          ..savedLogs.add(DailyLogEntity(date: _jan15, notes: 'Prima'));
        cycleRepo.enableControllableWatchAll();

        final useCase = GetCycleNotes(logRepo, cycleRepo);
        final emissions = <Map<DateTime, String>>[];
        final subscription = useCase().listen(emissions.add);

        cycleRepo.emitCycles([_cycle()]);
        await pumpEventQueue();

        logRepo.savedLogs[0] = logRepo.savedLogs[0].copyWith(notes: 'Dopo');
        cycleRepo.emitCycles([_cycle()]);
        await pumpEventQueue();

        expect(emissions, [
          {_jan15: 'Prima'},
          {_jan15: 'Dopo'},
        ]);

        await subscription.cancel();
        await cycleRepo.close();
      },
    );

    test(
      'given_two_watch_emissions_then_reads_logs_once_per_emission_without_symptom_calls',
      () async {
        final cycleRepo = FakeCycleEntryRepository();
        final logRepo = _CountingFakeDailyLogRepository()
          ..savedLogs.add(DailyLogEntity(date: _jan15, notes: 'Prima'));
        cycleRepo.enableControllableWatchAll();

        final useCase = GetCycleNotes(logRepo, cycleRepo);
        final emissions = <Map<DateTime, String>>[];
        final subscription = useCase().listen(emissions.add);

        cycleRepo.emitCycles([_cycle()]);
        await pumpEventQueue();
        cycleRepo.emitCycles([_cycle()]);
        await pumpEventQueue();

        expect(emissions, hasLength(2));
        expect(logRepo.getAllOrderedByDateCalls, 2);
        expect(logRepo.getPainSymptomsCalls, 0);

        await subscription.cancel();
        await cycleRepo.close();
      },
    );

    test(
      'given_a_failing_log_read_when_watching_then_surfaces_a_stream_error',
      () async {
        final cycleRepo = FakeCycleEntryRepository()..entries.add(_cycle());
        final logRepo = _CountingFakeDailyLogRepository()
          ..errorOnGetAllOrderedByDate = StateError('log read failed');
        final useCase = GetCycleNotes(logRepo, cycleRepo);

        await expectLater(useCase(), emitsError(isA<StateError>()));
      },
    );

    test(
      'given_a_failing_cycle_watch_when_watching_then_propagates_the_stream_error',
      () async {
        final useCase = GetCycleNotes(
          FakeDailyLogRepository(),
          _ErroringCycleEntryRepository(),
        );

        await expectLater(useCase(), emitsError(isA<StateError>()));
      },
    );
  });
}

/// Counts the repository calls the note-path read budget cares about; every
/// other behaviour is inherited from [FakeDailyLogRepository].
class _CountingFakeDailyLogRepository extends FakeDailyLogRepository {
  int getAllOrderedByDateCalls = 0;
  int getPainSymptomsCalls = 0;

  /// When non-null, [getAllOrderedByDate] throws it instead of reading.
  Object? errorOnGetAllOrderedByDate;

  @override
  Future<List<DailyLogEntity>> getAllOrderedByDate() async {
    getAllOrderedByDateCalls++;
    final error = errorOnGetAllOrderedByDate;
    if (error != null) throw error;
    return super.getAllOrderedByDate();
  }

  @override
  Future<List<PainSymptomData>> getPainSymptoms(DateTime date) async {
    getPainSymptomsCalls++;
    return super.getPainSymptoms(date);
  }
}

/// [FakeCycleEntryRepository] whose `watchAll` fails immediately.
class _ErroringCycleEntryRepository extends FakeCycleEntryRepository {
  @override
  Stream<List<CycleEntryEntity>> watchAll() =>
      Stream.error(StateError('cycle watch failed'));
}
