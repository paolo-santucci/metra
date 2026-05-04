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
import 'package:metra/domain/entities/cycle_stats_data.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/use_cases/compute_cycle_stats.dart';
import 'package:metra/domain/use_cases/get_cycle_summaries.dart';
import 'package:metra/features/stats/state/stats_controller.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../../helpers/fake_cycle_entry_repository.dart';
import '../../../helpers/fake_daily_log_repository.dart';

// ---------------------------------------------------------------------------
// _NullGetCycleSummaries — satisfies the ComputeCycleStats constructor chain
// without emitting any data; the wrapping fake overrides call() anyway.
// ---------------------------------------------------------------------------

class _NullGetCycleSummaries extends GetCycleSummaries {
  _NullGetCycleSummaries()
      : super(FakeDailyLogRepository(), FakeCycleEntryRepository());

  @override
  Stream<List<CycleSummary>> call() => const Stream.empty();
}

// ---------------------------------------------------------------------------
// _FakeComputeCycleStats — backed by a single-subscription StreamController
// that buffers events until the notifier subscribes (async build()).
// ---------------------------------------------------------------------------

class _FakeComputeCycleStats extends ComputeCycleStats {
  _FakeComputeCycleStats() : super(_NullGetCycleSummaries());

  // Single-subscription: buffers events added before listener attaches.
  final _controller = StreamController<CycleStatsData?>();

  void add(CycleStatsData? value) => _controller.add(value);
  void close() => _controller.close();

  @override
  Stream<CycleStatsData?> call() => _controller.stream;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CycleStatsData _stubStatsData({int cycleLengthAvg = 28}) => CycleStatsData(
      points: const [],
      cycleLengthAvg: cycleLengthAvg,
      cycleLengthMin: cycleLengthAvg,
      cycleLengthMax: cycleLengthAvg,
      cyclesTrackedCount: 1,
      symptomCounts: {for (final t in PainSymptomType.values) t: 0},
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('statsProvider', () {
    test(
      'resolves to AsyncData(null) when stream emits null',
      () async {
        // Arrange — add null before provider subscribes (buffered by controller)
        final fake = _FakeComputeCycleStats();
        addTearDown(fake.close);
        final container = ProviderContainer(
          overrides: [
            computeCycleStatsProvider.overrideWith((_) async => fake),
          ],
        );
        addTearDown(container.dispose);

        fake.add(null);

        // Act
        final result = await container.read(statsProvider.future);

        // Assert
        expect(result, isNull);
      },
    );

    test(
      'resolves to AsyncData(data) when stream emits a CycleStatsData value',
      () async {
        // Arrange
        final fake = _FakeComputeCycleStats();
        addTearDown(fake.close);
        final container = ProviderContainer(
          overrides: [
            computeCycleStatsProvider.overrideWith((_) async => fake),
          ],
        );
        addTearDown(container.dispose);
        final expected = _stubStatsData(cycleLengthAvg: 29);

        fake.add(expected);

        // Act
        final result = await container.read(statsProvider.future);

        // Assert
        expect(result, same(expected));
      },
    );

    test(
      'state updates when stream emits a second value',
      () async {
        // Arrange
        final fake = _FakeComputeCycleStats();
        addTearDown(fake.close);
        final container = ProviderContainer(
          overrides: [
            computeCycleStatsProvider.overrideWith((_) async => fake),
          ],
        );
        addTearDown(container.dispose);
        final first = _stubStatsData(cycleLengthAvg: 28);
        final second = _stubStatsData(cycleLengthAvg: 30);

        // Seed first value before subscription (buffered).
        fake.add(first);

        // Keep the provider alive so auto-dispose doesn't drop the subscription.
        final sub = container.listen(statsProvider, (_, __) {});
        addTearDown(sub.close);

        // Resolve the build() future.
        await container.read(statsProvider.future);

        // Act — second emission triggers `state = AsyncData(data)`.
        fake.add(second);
        await Future<void>.delayed(Duration.zero);

        // Assert
        expect(container.read(statsProvider).valueOrNull, same(second));
      },
    );
  });
}
