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
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/use_cases/get_month_logs.dart';
import 'package:metra/features/calendar/state/calendar_month_controller.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../../helpers/fake_daily_log_repository.dart';

// A fake repo where watchMonth returns a controllable stream.
class _StreamableMonthRepo extends FakeDailyLogRepository {
  final _monthController = StreamController<List<DailyLogEntity>>.broadcast();

  void pushMonth(List<DailyLogEntity> logs) => _monthController.add(logs);

  @override
  Stream<List<DailyLogEntity>> watchMonth(int year, int month) {
    final matches = savedLogs
        .where((l) => l.date.year == year && l.date.month == month)
        .toList();
    // Seed current value immediately then keep the stream open.
    Future.microtask(() => _monthController.add(matches));
    return _monthController.stream;
  }
}

ProviderContainer _makeContainer(FakeDailyLogRepository fakeRepo) {
  final container = ProviderContainer(
    overrides: [
      dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
      getMonthLogsProvider.overrideWith(
        (_) async => GetMonthLogs(fakeRepo),
      ),
    ],
  );
  return container;
}

void main() {
  group('CalendarMonthNotifier — build()', () {
    test('initializes to current month', () async {
      final fakeRepo = _StreamableMonthRepo();
      final container = _makeContainer(fakeRepo);
      addTearDown(container.dispose);

      final state = await container.read(calendarMonthProvider.future);
      final now = DateTime.now();

      expect(state.year, equals(now.year));
      expect(state.month, equals(now.month));
    });
  });

  group('CalendarMonthNotifier — goToPrevMonth()', () {
    test('decrements month by one', () async {
      final fakeRepo = _StreamableMonthRepo();
      final container = _makeContainer(fakeRepo);
      addTearDown(container.dispose);

      await container.read(calendarMonthProvider.future);
      container.read(calendarMonthProvider.notifier).goToPrevMonth();
      // Allow the subscription + state update to propagate.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(calendarMonthProvider).valueOrNull;
      final now = DateTime.now();
      // Compute expected prev month from DateTime to handle January → December.
      final expected = DateTime(now.year, now.month - 1);

      expect(state?.year, equals(expected.year));
      expect(state?.month, equals(expected.month));
    });

    test('wraps January to December of previous year', () async {
      final fakeRepo = _StreamableMonthRepo();
      final container = _makeContainer(fakeRepo);
      addTearDown(container.dispose);

      // Navigate to January of the previous year first by going back from
      // current month until we reach month == 1.
      await container.read(calendarMonthProvider.future);
      final now = DateTime.now();
      final stepsToJanuary =
          now.month - 1; // current month - 1 steps to reach Jan

      for (var i = 0; i < stepsToJanuary; i++) {
        container.read(calendarMonthProvider.notifier).goToPrevMonth();
        await Future<void>.delayed(Duration.zero);
      }

      // Verify we are at January of the current year.
      final atJan = container.read(calendarMonthProvider).valueOrNull;
      expect(atJan?.month, equals(1));
      expect(atJan?.year, equals(now.year));

      // One more step should wrap to December of previous year.
      container.read(calendarMonthProvider.notifier).goToPrevMonth();
      await Future<void>.delayed(Duration.zero);

      final wrapped = container.read(calendarMonthProvider).valueOrNull;
      expect(wrapped?.month, equals(12));
      expect(wrapped?.year, equals(now.year - 1));
    });
  });

  group('CalendarMonthNotifier — goToNextMonth()', () {
    test('is a no-op when already on current month', () async {
      final fakeRepo = _StreamableMonthRepo();
      final container = _makeContainer(fakeRepo);
      addTearDown(container.dispose);

      await container.read(calendarMonthProvider.future);
      final now = DateTime.now();
      container.read(calendarMonthProvider.notifier).goToNextMonth();
      await Future<void>.delayed(Duration.zero);

      // State must still be current month.
      final state = container.read(calendarMonthProvider).valueOrNull;
      expect(state?.year, equals(now.year));
      expect(state?.month, equals(now.month));
    });

    test('advances month when on a past month', () async {
      final fakeRepo = _StreamableMonthRepo();
      final container = _makeContainer(fakeRepo);
      addTearDown(container.dispose);

      await container.read(calendarMonthProvider.future);
      final now = DateTime.now();

      // Step back one month.
      container.read(calendarMonthProvider.notifier).goToPrevMonth();
      await Future<void>.delayed(Duration.zero);

      final prevMonth = DateTime(now.year, now.month - 1);

      // Now advance — should return to current month.
      container.read(calendarMonthProvider.notifier).goToNextMonth();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(calendarMonthProvider).valueOrNull;
      // goToNextMonth increments from prevMonth, so result == current month.
      final expectedMonth = DateTime(prevMonth.year, prevMonth.month + 1);
      expect(state?.year, equals(expectedMonth.year));
      expect(state?.month, equals(expectedMonth.month));
    });
  });

  group('CalendarMonthNotifier — logs map', () {
    test('state.logs is populated when repo emits entries', () async {
      final fakeRepo = _StreamableMonthRepo();
      final now = DateTime.now();
      final logDate = DateTime.utc(now.year, now.month, 10);
      fakeRepo.savedLogs.add(
        DailyLogEntity(date: logDate, flowIntensity: FlowIntensity.light),
      );
      final container = _makeContainer(fakeRepo);
      addTearDown(container.dispose);

      final state = await container.read(calendarMonthProvider.future);

      expect(state.logs, contains(logDate));
      expect(
        state.logs[logDate]?.flowIntensity,
        equals(FlowIntensity.light),
      );
    });

    test('state.logs updates when repo stream emits new data', () async {
      final fakeRepo = _StreamableMonthRepo();
      final container = _makeContainer(fakeRepo);
      addTearDown(container.dispose);

      await container.read(calendarMonthProvider.future);
      expect(container.read(calendarMonthProvider).valueOrNull?.logs, isEmpty);

      final now = DateTime.now();
      final logDate = DateTime.utc(now.year, now.month, 5);
      final newLog = DailyLogEntity(
        date: logDate,
        flowIntensity: FlowIntensity.medium,
      );

      fakeRepo.pushMonth([newLog]);
      await Future<void>.delayed(Duration.zero);

      final updated = container.read(calendarMonthProvider).valueOrNull;
      expect(updated?.logs, contains(logDate));
    });
  });
}
