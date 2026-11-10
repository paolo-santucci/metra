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
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/use_cases/get_cycle_summaries.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../../helpers/fake_cycle_entry_repository.dart';
import '../../../helpers/fake_daily_log_repository.dart';

// ---------------------------------------------------------------------------
// _FakeGetCycleSummaries — backed by a single-subscription StreamController
// that buffers events until the notifier subscribes (async build()).
// ---------------------------------------------------------------------------

class _FakeGetCycleSummaries extends GetCycleSummaries {
  _FakeGetCycleSummaries()
      : super(FakeDailyLogRepository(), FakeCycleEntryRepository());

  // Single-subscription: buffers events added before listener attaches.
  final _controller = StreamController<List<CycleSummary>>();

  void add(List<CycleSummary> value) => _controller.add(value);
  void close() => _controller.close();

  @override
  Stream<List<CycleSummary>> call() => _controller.stream;
}

// ---------------------------------------------------------------------------
// Minimal CycleSummary builder.
// ---------------------------------------------------------------------------

CycleSummary _stubSummary(int id) => CycleSummary(
      cycle: CycleEntryEntity(
        id: id,
        startDate: DateTime.utc(2026, 1, id),
        endDate: DateTime.utc(2026, 1, id + 28),
        cycleLength: 28,
      ),
      symptoms: const [],
      dominantPainIntensity: null,
    );

// ---------------------------------------------------------------------------
// Fixtures for the notes path
// ---------------------------------------------------------------------------

final _jan15 = DateTime.utc(2026, 1, 15);
final _jan16 = DateTime.utc(2026, 1, 16);

CycleEntryEntity _cycle() =>
    CycleEntryEntity(id: 1, startDate: _jan15, endDate: _jan16);

// ---------------------------------------------------------------------------
// _FailingLogRepository — FakeDailyLogRepository with an injectable
// getAllOrderedByDate() failure, so the notes error path and its recovery can
// be driven from the fake repository providers.
// ---------------------------------------------------------------------------

class _FailingLogRepository extends FakeDailyLogRepository {
  /// When non-null, [getAllOrderedByDate] throws it instead of reading.
  Object? errorOnGetAllOrderedByDate;

  @override
  Future<List<DailyLogEntity>> getAllOrderedByDate() async {
    final error = errorOnGetAllOrderedByDate;
    if (error != null) throw error;
    return super.getAllOrderedByDate();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('timelineProvider', () {
    test(
      'resolves to AsyncData([]) when stream emits an empty list',
      () async {
        // Arrange — buffer empty list before provider subscribes
        final fake = _FakeGetCycleSummaries();
        addTearDown(fake.close);
        final container = ProviderContainer(
          overrides: [
            getCycleSummariesProvider.overrideWith((_) async => fake),
          ],
        );
        addTearDown(container.dispose);

        fake.add([]);

        // Act
        final result = await container.read(timelineProvider.future);

        // Assert
        expect(result, isEmpty);
      },
    );

    test(
      'resolves to AsyncData([cycleSummary]) when stream emits a single item',
      () async {
        // Arrange
        final fake = _FakeGetCycleSummaries();
        addTearDown(fake.close);
        final container = ProviderContainer(
          overrides: [
            getCycleSummariesProvider.overrideWith((_) async => fake),
          ],
        );
        addTearDown(container.dispose);
        final summary = _stubSummary(1);

        fake.add([summary]);

        // Act
        final result = await container.read(timelineProvider.future);

        // Assert
        expect(result, [summary]);
      },
    );

    test(
      'state updates when stream emits a second value',
      () async {
        // Arrange
        final fake = _FakeGetCycleSummaries();
        addTearDown(fake.close);
        final container = ProviderContainer(
          overrides: [
            getCycleSummariesProvider.overrideWith((_) async => fake),
          ],
        );
        addTearDown(container.dispose);
        final first = [_stubSummary(1)];
        final second = [_stubSummary(1), _stubSummary(2)];

        // Seed first value before subscription (buffered).
        fake.add(first);

        // Keep the provider alive so auto-dispose doesn't drop the subscription.
        final sub = container.listen(timelineProvider, (_, __) {});
        addTearDown(sub.close);

        // Resolve the build() future.
        await container.read(timelineProvider.future);

        // Act — second emission triggers `state = AsyncData(summaries)`.
        fake.add(second);
        await Future<void>.delayed(Duration.zero);

        // Assert
        expect(container.read(timelineProvider).valueOrNull, second);
      },
    );
  });

  group('timelineNotesProvider', () {
    test(
      'resolves to the note map once the repository futures resolve',
      () async {
        // Arrange — real GetCycleNotes over fake repository providers.
        final logRepo = FakeDailyLogRepository()
          ..savedLogs.addAll([
            DailyLogEntity(date: _jan15, notes: 'Crampi forti'),
            DailyLogEntity(date: _jan16),
          ]);
        final cycleRepo = FakeCycleEntryRepository()..entries.add(_cycle());
        final container = ProviderContainer(
          overrides: [
            dailyLogRepositoryProvider.overrideWith((_) async => logRepo),
            cycleEntryRepositoryProvider.overrideWith((_) async => cycleRepo),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(timelineNotesProvider, (_, __) {});
        addTearDown(sub.close);

        // Act
        final notes = await container.read(timelineNotesProvider.future);

        // Assert
        expect(notes, {_jan15: 'Crampi forti'});
      },
    );

    test(
      'cancels the watchAll subscription when the provider disposes',
      () async {
        // Arrange
        final logRepo = FakeDailyLogRepository()
          ..savedLogs.add(DailyLogEntity(date: _jan15, notes: 'Nota'));
        final cycleRepo = FakeCycleEntryRepository()..entries.add(_cycle());
        // ignore: close_sinks — closed by cycleRepo.close() in addTearDown.
        final controller = cycleRepo.enableControllableWatchAll();
        final container = ProviderContainer(
          overrides: [
            dailyLogRepositoryProvider.overrideWith((_) async => logRepo),
            cycleEntryRepositoryProvider.overrideWith((_) async => cycleRepo),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(cycleRepo.close);

        final sub = container.listen(timelineNotesProvider, (_, __) {});
        cycleRepo.emitCycles([_cycle()]);
        await container.read(timelineNotesProvider.future);
        expect(controller.hasListener, isTrue);

        // Act — the last listener leaves, so autoDispose tears the stream down.
        sub.close();
        await pumpEventQueue();

        // Assert
        expect(controller.hasListener, isFalse);
      },
    );

    test(
      'restores AsyncData after a failed log read and a good emission',
      () async {
        // Arrange
        final logRepo = _FailingLogRepository()
          ..savedLogs.add(DailyLogEntity(date: _jan15, notes: 'Nota'))
          ..errorOnGetAllOrderedByDate = StateError('log read failed');
        final cycleRepo = FakeCycleEntryRepository();
        cycleRepo.enableControllableWatchAll();
        final container = ProviderContainer(
          overrides: [
            dailyLogRepositoryProvider.overrideWith((_) async => logRepo),
            cycleEntryRepositoryProvider.overrideWith((_) async => cycleRepo),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(cycleRepo.close);

        final sub = container.listen(timelineNotesProvider, (_, __) {});
        addTearDown(sub.close);

        // Act — the first emission fails inside GetCycleNotes.
        cycleRepo.emitCycles([_cycle()]);
        await pumpEventQueue();

        final failed = container.read(timelineNotesProvider);
        expect(failed, isA<AsyncError<Map<DateTime, String>>>());

        // Act — the read recovers and the next emission succeeds.
        logRepo.errorOnGetAllOrderedByDate = null;
        cycleRepo.emitCycles([_cycle()]);
        await pumpEventQueue();

        // Assert
        final recovered = container.read(timelineNotesProvider);
        expect(recovered, isA<AsyncData<Map<DateTime, String>>>());
        expect(recovered.valueOrNull, {_jan15: 'Nota'});
      },
    );
  });
}
