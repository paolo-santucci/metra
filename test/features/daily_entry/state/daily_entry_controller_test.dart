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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/use_cases/recompute_cycle_entries.dart';
import 'package:metra/domain/use_cases/save_daily_log.dart';
import 'package:metra/features/daily_entry/state/daily_entry_controller.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../../helpers/fake_cycle_entry_repository.dart';
import '../../../helpers/fake_daily_log_repository.dart';

// Controllable fake that allows pushing new values after initial subscription.
class _StreamableFakeDailyLogRepository extends FakeDailyLogRepository {
  final Map<DateTime, StreamController<DailyLogEntity?>> _dayControllers = {};

  void pushDay(DateTime date, DailyLogEntity? log) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    _dayControllers[utcDate]?.add(log);
  }

  void dispose() {
    for (final c in _dayControllers.values) {
      c.close();
    }
    _dayControllers.clear();
  }

  @override
  Stream<DailyLogEntity?> watchDay(DateTime date) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    // ignore: close_sinks — controller is closed in dispose().
    final controller = StreamController<DailyLogEntity?>.broadcast();
    _dayControllers[utcDate] = controller;
    final match = savedLogs.where((l) => l.date == utcDate).toList();
    // Seed the initial value immediately.
    Future.microtask(() => controller.add(match.isEmpty ? null : match.last));
    return controller.stream;
  }
}

ProviderContainer _makeContainer(
  FakeDailyLogRepository fakeRepo,
  FakeCycleEntryRepository fakeCycleRepo,
) {
  final container = ProviderContainer(
    overrides: [
      dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
      cycleEntryRepositoryProvider.overrideWith((_) async => fakeCycleRepo),
      saveDailyLogProvider.overrideWith(
        (_) async => SaveDailyLog(fakeRepo),
      ),
      recomputeCycleEntriesProvider.overrideWith(
        (_) async => RecomputeCycleEntries(fakeRepo, fakeCycleRepo),
      ),
    ],
  );
  return container;
}

void main() {
  // Fixed past date — always valid, never in the future.
  final kDate = DateTime.utc(2026, 1, 15);

  group('DailyEntryNotifier — build()', () {
    test('initializes to null for an unknown date', () async {
      final fakeRepo = _StreamableFakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final container = _makeContainer(fakeRepo, fakeCycleRepo);
      addTearDown(() {
        container.dispose();
        fakeRepo.dispose();
      });

      final value = await container.read(dailyEntryProvider(kDate).future);
      expect(value, isNull);
    });

    test('initializes with existing log when repo has data', () async {
      final fakeRepo = _StreamableFakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final log = DailyLogEntity(
        date: kDate,
        flowIntensity: FlowIntensity.medium,
      );
      fakeRepo.savedLogs.add(log);
      final container = _makeContainer(fakeRepo, fakeCycleRepo);
      addTearDown(() {
        container.dispose();
        fakeRepo.dispose();
      });

      final value = await container.read(dailyEntryProvider(kDate).future);
      expect(value, equals(log));
    });
  });

  group('DailyEntryNotifier — save()', () {
    test('upserts log in repository', () async {
      final fakeRepo = _StreamableFakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final container = _makeContainer(fakeRepo, fakeCycleRepo);
      addTearDown(() {
        container.dispose();
        fakeRepo.dispose();
      });

      // Await build() to complete.
      await container.read(dailyEntryProvider(kDate).future);

      final log = DailyLogEntity(
        date: kDate,
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.heavy,
      );
      await container.read(dailyEntryProvider(kDate).notifier).save(log);

      expect(fakeRepo.savedLogs, hasLength(1));
      expect(fakeRepo.savedLogs.last.flowIntensity, FlowIntensity.heavy);
    });

    test('triggers cycle recomputation after save', () async {
      final fakeRepo = _StreamableFakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final container = _makeContainer(fakeRepo, fakeCycleRepo);
      addTearDown(() {
        container.dispose();
        fakeRepo.dispose();
      });

      await container.read(dailyEntryProvider(kDate).future);

      final log = DailyLogEntity(
        date: kDate,
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.medium,
      );
      await container.read(dailyEntryProvider(kDate).notifier).save(log);

      // RecomputeCycleEntries calls replaceAll — entries list reflects recompute.
      // With one flow day we expect one cycle entry.
      expect(fakeCycleRepo.entries, hasLength(1));
    });

    test('cycleDayForDateProvider resets to day 1 when new cycle starts',
        () async {
      // Cycle 1 starts 2026-01-01; cycle 2 starts 2026-02-01 (31d gap > 21d).
      final cycle1Start = DateTime.utc(2026, 1, 1);
      final cycle2Start = DateTime.utc(2026, 2, 1);

      final fakeRepo = _StreamableFakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final container = _makeContainer(fakeRepo, fakeCycleRepo);
      addTearDown(() {
        container.dispose();
        fakeRepo.dispose();
      });

      // Seed cycle 1 log so the provider has a result to cache.
      final cycle1Log = DailyLogEntity(
        date: cycle1Start,
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.medium,
      );
      await container.read(dailyEntryProvider(cycle1Start).future);
      await container
          .read(dailyEntryProvider(cycle1Start).notifier)
          .save(cycle1Log);

      // Prime the cache for cycle2Start — currently no cycle entry for it.
      // Day returned will be null or a large number relative to cycle 1 start.
      await container.read(cycleDayForDateProvider(cycle2Start).future);

      // Now log a mestruazioni day on cycle2Start to start a new cycle.
      final cycle2Log = DailyLogEntity(
        date: cycle2Start,
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.light,
      );
      await container.read(dailyEntryProvider(cycle2Start).future);
      await container
          .read(dailyEntryProvider(cycle2Start).notifier)
          .save(cycle2Log);

      // After save, the provider must have been invalidated and re-evaluated.
      // cycle2Start is day 1 of the new cycle, so the result must be 1.
      final cycleDay =
          await container.read(cycleDayForDateProvider(cycle2Start).future);
      expect(cycleDay, 1);
    });

    test('sets state to AsyncError on validation failure (future date)',
        () async {
      final fakeRepo = _StreamableFakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final container = _makeContainer(fakeRepo, fakeCycleRepo);
      addTearDown(() {
        container.dispose();
        fakeRepo.dispose();
      });

      // Use a future date to trigger SaveDailyLog validation error.
      final futureDate = DateTime.now().toUtc().add(const Duration(days: 1));
      final futureKey = DateTime.utc(
        futureDate.year,
        futureDate.month,
        futureDate.day,
      );

      await container.read(dailyEntryProvider(futureKey).future);

      final futureLog = DailyLogEntity(
        date: futureKey,
        flowIntensity: FlowIntensity.light,
      );
      await container
          .read(dailyEntryProvider(futureKey).notifier)
          .save(futureLog);

      final stateAfter = container.read(dailyEntryProvider(futureKey));
      expect(stateAfter, isA<AsyncError<DailyLogEntity?>>());
      expect(
        (stateAfter as AsyncError<DailyLogEntity?>).error,
        isA<ValidationException>(),
      );
    });
  });

  group('DailyEntryNotifier — delete()', () {
    test('removes log from repository', () async {
      final fakeRepo = _StreamableFakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final log = DailyLogEntity(
        date: kDate,
        flowIntensity: FlowIntensity.light,
      );
      fakeRepo.savedLogs.add(log);
      final container = _makeContainer(fakeRepo, fakeCycleRepo);
      addTearDown(() {
        container.dispose();
        fakeRepo.dispose();
      });

      await container.read(dailyEntryProvider(kDate).future);
      await container.read(dailyEntryProvider(kDate).notifier).delete();

      expect(fakeRepo.savedLogs, isEmpty);
      expect(fakeRepo.deletedDates, contains(kDate));
    });
  });

  group('DailyEntryNotifier — live stream', () {
    test('state updates when repo emits a new value', () async {
      final fakeRepo = _StreamableFakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final container = _makeContainer(fakeRepo, fakeCycleRepo);

      // Establish a listener to prevent auto-dispose for the duration of the test.
      final states = <AsyncValue<DailyLogEntity?>>[];
      final sub = container.listen(
        dailyEntryProvider(kDate),
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      addTearDown(() {
        sub.close();
        container.dispose();
        fakeRepo.dispose();
      });

      // Wait for the initial state (null) to resolve.
      await container.read(dailyEntryProvider(kDate).future);

      final newLog = DailyLogEntity(
        date: kDate,
        flowIntensity: FlowIntensity.veryHeavy,
      );

      // Push a new value from the stream controller.
      fakeRepo.pushDay(kDate, newLog);

      // Allow the state update to propagate through the stream.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(dailyEntryProvider(kDate));
      expect(state, isA<AsyncData<DailyLogEntity?>>());
      expect((state as AsyncData<DailyLogEntity?>).value, equals(newLog));
    });
  });
}
