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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/utils/result.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/repositories/cycle_entry_repository.dart';
import 'package:metra/domain/repositories/daily_log_repository.dart';
import 'package:metra/domain/use_cases/recompute_cycle_entries.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

DailyLogEntity _flowDay(
  DateTime date, [
  FlowIntensity flow = FlowIntensity.medium,
]) =>
    DailyLogEntity(
      date: date,
      flowType: FlowType.mestruazioni,
      flowIntensity: flow,
    );

DailyLogEntity _spottingDay(DateTime date) =>
    DailyLogEntity(date: date, flowType: FlowType.spotting);

void main() {
  late FakeDailyLogRepository logRepo;
  late FakeCycleEntryRepository cycleRepo;
  late RecomputeCycleEntries useCase;

  setUp(() {
    logRepo = FakeDailyLogRepository();
    cycleRepo = FakeCycleEntryRepository();
    useCase = RecomputeCycleEntries(logRepo, cycleRepo);
  });

  group('compute() — pure function', () {
    test('empty logs → empty list', () {
      expect(RecomputeCycleEntries.compute([]), isEmpty);
    });

    test('spotting-only days → no cycles', () {
      final logs = [_spottingDay(DateTime.utc(2026, 1, 1))];
      expect(RecomputeCycleEntries.compute(logs), isEmpty);
    });

    test('single flow day → one cycle, periodLength 1, cycleLength null', () {
      final logs = [_flowDay(DateTime.utc(2026, 1, 1))];
      final entries = RecomputeCycleEntries.compute(logs);
      expect(entries, hasLength(1));
      expect(entries.first.startDate, DateTime.utc(2026, 1, 1));
      expect(entries.first.periodLength, 1);
      expect(entries.first.cycleLength, isNull);
    });

    test('5 consecutive flow days → one cycle, periodLength 5', () {
      final logs = List.generate(
        5,
        (i) => _flowDay(DateTime.utc(2026, 1, 1 + i)),
      );
      final entries = RecomputeCycleEntries.compute(logs);
      expect(entries, hasLength(1));
      expect(entries.first.periodLength, 5);
      expect(entries.first.endDate, DateTime.utc(2026, 1, 5));
    });

    test('two periods separated by 28 days → two cycles', () {
      final period1 =
          List.generate(5, (i) => _flowDay(DateTime.utc(2026, 1, 1 + i)));
      final period2 =
          List.generate(5, (i) => _flowDay(DateTime.utc(2026, 1, 29 + i)));
      final entries = RecomputeCycleEntries.compute([...period1, ...period2]);

      expect(entries, hasLength(2));
      expect(entries[0].startDate, DateTime.utc(2026, 1, 1));
      expect(entries[0].cycleLength, 28); // day 29 - day 1
      expect(entries[1].startDate, DateTime.utc(2026, 1, 29));
      expect(entries[1].cycleLength, isNull);
    });

    test('gap of exactly 21 days → two cycles', () {
      final logs = [
        _flowDay(DateTime.utc(2026, 1, 1)),
        _flowDay(DateTime.utc(2026, 1, 22)), // 21 days later
      ];
      expect(RecomputeCycleEntries.compute(logs), hasLength(2));
    });

    test('gap of 20 days → same cycle', () {
      final logs = [
        _flowDay(DateTime.utc(2026, 1, 1)),
        _flowDay(DateTime.utc(2026, 1, 21)), // 20 days later
      ];
      expect(RecomputeCycleEntries.compute(logs), hasLength(1));
    });

    test('spotting days are excluded from cycle detection', () {
      final logs = [
        _spottingDay(DateTime.utc(2026, 1, 1)),
        _flowDay(DateTime.utc(2026, 1, 2), FlowIntensity.light),
      ];
      final entries = RecomputeCycleEntries.compute(logs);
      expect(entries, hasLength(1));
      expect(entries.first.startDate, DateTime.utc(2026, 1, 2));
    });

    test('6-cycle WMA scenario: cycleLength computed correctly for each', () {
      // 6 cycles of 28 days each.
      final starts = List.generate(6, (i) => DateTime.utc(2026, 1, 1 + i * 28));
      final logs = starts
          .expand(
            (s) => List.generate(5, (j) => _flowDay(s.add(Duration(days: j)))),
          )
          .toList();

      final entries = RecomputeCycleEntries.compute(logs);
      expect(entries, hasLength(6));
      for (var i = 0; i < 5; i++) {
        expect(entries[i].cycleLength, 28);
      }
      expect(entries.last.cycleLength, isNull);
    });

    test('very short cycle (21d) and very long cycle (45d)', () {
      final period1 = [_flowDay(DateTime.utc(2026, 1, 1))];
      final period2 = [_flowDay(DateTime.utc(2026, 1, 22))]; // 21d gap
      final period3 = [
        _flowDay(DateTime.utc(2026, 3, 8)),
      ]; // 45d gap from period2
      final entries = RecomputeCycleEntries.compute([
        ...period1,
        ...period2,
        ...period3,
      ]);
      expect(entries, hasLength(3));
      expect(entries[0].cycleLength, 21);
      expect(entries[1].cycleLength, 45);
    });

    // Regression: Bug [2] — gap=19 (< threshold) keeps both days in ONE group,
    // but periodLength must be 2 (flow day count), NOT 20 (calendar span).
    test(
      'given_gap_below_threshold_when_compute_then_periodLength_counts_flow_days_not_span',
      () {
        final logs = [
          _flowDay(DateTime.utc(2026, 1, 1)),
          _flowDay(DateTime.utc(2026, 1, 20)), // gap = 19 days, below threshold
        ];
        final entries = RecomputeCycleEntries.compute(logs);
        expect(entries, hasLength(1));
        expect(entries.first.periodLength, 2);
      },
    );

    // Mixed: 3+2 flow days with intra-episode gaps, all within one cycle episode.
    test(
      'given_flow_days_with_intra_episode_gaps_when_compute_then_periodLength_counts_actual_flow_days',
      () {
        // Jan 1, 2, 3 — gap — Jan 8 — gap — Jan 14: span=14, flow days=5
        final logs = [
          _flowDay(DateTime.utc(2026, 1, 1)),
          _flowDay(DateTime.utc(2026, 1, 2)),
          _flowDay(DateTime.utc(2026, 1, 3)),
          _flowDay(DateTime.utc(2026, 1, 8)),  // +5 days gap
          _flowDay(DateTime.utc(2026, 1, 14)), // +6 days gap
        ];
        final entries = RecomputeCycleEntries.compute(logs);
        expect(entries, hasLength(1));
        expect(entries.first.periodLength, 5);
      },
    );
  });

  group('call() — integration with repos', () {
    test('populates cycle repo from log repo', () async {
      for (var i = 0; i < 3; i++) {
        await logRepo.saveDailyLog(
          _flowDay(DateTime.utc(2026, 1, 1 + i * 28)),
        );
      }
      final result = await useCase();
      expect(result, isA<Ok<List<CycleEntryEntity>>>());
      expect(cycleRepo.entries, hasLength(3));
    });

    test('replaces stale entries on second call', () async {
      await logRepo.saveDailyLog(_flowDay(DateTime.utc(2026, 1, 1)));
      await useCase();
      await logRepo.saveDailyLog(_flowDay(DateTime.utc(2026, 2, 5)));
      await useCase();
      expect(cycleRepo.entries, hasLength(2));
    });

    // Concurrency: two overlapping call() invocations must execute their
    // read→compute→write triples sequentially — the second getAllOrderedByDate
    // must not fire before the first replaceAll completes.
    test(
      'given_two_concurrent_calls_when_call_invoked_twice_then_executes_sequentially',
      () async {
        final events = <String>[];

        // Fake log repo: first getAllOrderedByDate stalls until released; second
        // proceeds immediately. Both return one flow day (content unimportant for
        // the ordering assertion).
        final firstGetCompleter = Completer<void>();

        final serialFakeLog = _SerializationFakeLogRepo(
          firstGetCompleter: firstGetCompleter,
          events: events,
          log: _flowDay(DateTime.utc(2026, 1, 1)),
        );
        final serialFakeCycle = _SerializationFakeCycleRepo(events: events);
        final uc = RecomputeCycleEntries(serialFakeLog, serialFakeCycle);

        // Launch both calls without awaiting between them.
        final f1 = uc();
        final f2 = uc();

        // Allow microtasks to run so both calls enter their bodies.
        await Future<void>.delayed(Duration.zero);

        // Release the first getAllOrderedByDate — this must trigger replaceAll#1
        // before getAllOrderedByDate#2 fires.
        firstGetCompleter.complete();

        await Future.wait([f1, f2]);

        // Sequential order: get1 → replace1 → get2 → replace2
        expect(events, ['get1', 'replace1', 'get2', 'replace2']);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Local fakes for the concurrency test — not reusable outside this file.
// ---------------------------------------------------------------------------

class _SerializationFakeLogRepo implements DailyLogRepository {
  _SerializationFakeLogRepo({
    required this.firstGetCompleter,
    required this.events,
    required this.log,
  });

  final Completer<void> firstGetCompleter;
  final List<String> events;
  final DailyLogEntity log;
  int _callCount = 0;

  @override
  Future<List<DailyLogEntity>> getAllOrderedByDate() async {
    _callCount++;
    final label = 'get$_callCount';
    if (_callCount == 1) {
      await firstGetCompleter.future; // stall until released
    }
    events.add(label);
    return [log];
  }

  // Unused interface methods — return stubs so the class compiles.
  @override
  Stream<DailyLogEntity?> watchDay(DateTime date) => const Stream.empty();
  @override
  Stream<List<DailyLogEntity>> watchMonth(int year, int month) =>
      const Stream.empty();
  @override
  Future<void> saveDailyLog(DailyLogEntity log) async {}
  @override
  Future<void> deleteDailyLog(DateTime date) async {}
  @override
  Future<List<PainSymptomData>> getPainSymptoms(DateTime date) async => [];
  @override
  Future<Set<DateTime>> getSymptomDatesForMonth(int year, int month) async =>
      {};
  @override
  Future<void> replacePainSymptoms(
    DateTime date,
    List<PainSymptomData> newSymptoms,
  ) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<void> deleteAllAndReplace(
    List<DailyLogEntity> logs,
    Map<DateTime, List<PainSymptomData>> newSymptoms,
  ) async {}
}

class _SerializationFakeCycleRepo implements CycleEntryRepository {
  _SerializationFakeCycleRepo({required this.events});

  final List<String> events;
  int _replaceCount = 0;

  @override
  Future<void> replaceAll(List<CycleEntryEntity> newEntries) async {
    _replaceCount++;
    events.add('replace$_replaceCount');
  }

  // Unused interface methods.
  @override
  Stream<List<CycleEntryEntity>> watchAll() => const Stream.empty();
  @override
  Future<List<CycleEntryEntity>> getRecent(int n) async => [];
  @override
  Future<CycleEntryEntity> insert(CycleEntryEntity entry) async => entry;
  @override
  Future<void> update(CycleEntryEntity entry) async {}
  @override
  Future<void> delete(int id) async {}
  @override
  Future<void> deleteAll() async {}
}
