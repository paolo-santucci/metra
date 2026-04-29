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

// NOTE: This test requires T8 to register `watchCyclePredictionProvider` in
// `use_case_providers.dart` before it can be compiled and run.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/use_cases/watch_cycle_prediction.dart';
import 'package:metra/features/calendar/state/prediction_controller.dart';
import 'package:metra/providers/use_case_providers.dart';

void main() {
  group('CyclePredictionNotifier', () {
    test('emits AsyncData with the prediction from the stream', () async {
      final expectedStart = DateTime.utc(2026, 5, 15);
      final prediction = CyclePrediction(
        windowStart: expectedStart.subtract(const Duration(days: 2)),
        windowEnd: expectedStart.add(const Duration(days: 2)),
        expectedStart: expectedStart,
        cyclesUsed: 3,
      );

      final container = ProviderContainer(
        overrides: [
          watchCyclePredictionProvider.overrideWith(
            (ref) async => _FakeWatchCyclePrediction(prediction),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(cyclePredictionProvider.future);
      expect(result, equals(prediction));
    });

    test('emits AsyncData(null) when prediction is null', () async {
      final container = ProviderContainer(
        overrides: [
          watchCyclePredictionProvider.overrideWith(
            (ref) async => _FakeWatchCyclePrediction(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(cyclePredictionProvider.future);
      expect(result, isNull);
    });

    test('updates state when stream emits a new prediction', () async {
      final expectedStart = DateTime.utc(2026, 6, 1);
      final first = CyclePrediction(
        windowStart: expectedStart.subtract(const Duration(days: 2)),
        windowEnd: expectedStart.add(const Duration(days: 2)),
        expectedStart: expectedStart,
        cyclesUsed: 3,
      );
      final second = CyclePrediction(
        windowStart: expectedStart.add(const Duration(days: 1)),
        windowEnd: expectedStart.add(const Duration(days: 5)),
        expectedStart: expectedStart.add(const Duration(days: 3)),
        cyclesUsed: 4,
      );

      final fakeUc = _StreamingWatchCyclePrediction();
      final container = ProviderContainer(
        overrides: [
          watchCyclePredictionProvider.overrideWith(
            (ref) async => fakeUc,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Prime the stream with the first prediction.
      fakeUc.add(first);
      final initial = await container.read(cyclePredictionProvider.future);
      expect(initial, equals(first));

      // Emit a second prediction and verify state updates.
      fakeUc.add(second);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(cyclePredictionProvider).valueOrNull,
        equals(second),
      );
    });
  });
}

/// Fake that immediately emits a single value and then completes.
class _FakeWatchCyclePrediction implements WatchCyclePrediction {
  _FakeWatchCyclePrediction(this._prediction);

  final CyclePrediction? _prediction;

  @override
  Stream<CyclePrediction?> call() => Stream.value(_prediction);
}

/// Fake backed by a broadcast StreamController for multi-emission tests.
class _StreamingWatchCyclePrediction implements WatchCyclePrediction {
  final _controller = StreamController<CyclePrediction?>();

  void add(CyclePrediction? p) => _controller.add(p);

  @override
  Stream<CyclePrediction?> call() => _controller.stream;
}
