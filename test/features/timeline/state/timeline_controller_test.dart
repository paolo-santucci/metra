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
import 'package:metra/domain/use_cases/get_cycle_summaries.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
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
}
