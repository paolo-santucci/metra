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
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/use_cases/watch_cycle_prediction.dart';
import 'package:metra/features/calendar/state/prediction_controller.dart';
import 'package:metra/providers/use_case_providers.dart';

void main() {
  group('cyclePredictionProvider (StreamProvider)', () {
    test('initial emission propagates to state.value', () async {
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

    test('emits AsyncData(null) when stream yields null', () async {
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

    test('subsequent stream emission updates state.value', () async {
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
      addTearDown(fakeUc.close);
      final container = ProviderContainer(
        overrides: [
          watchCyclePredictionProvider.overrideWith(
            (ref) async => fakeUc,
          ),
        ],
      );
      addTearDown(container.dispose);

      fakeUc.add(first);
      final initial = await container.read(cyclePredictionProvider.future);
      expect(initial, equals(first));

      fakeUc.add(second);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(cyclePredictionProvider).valueOrNull,
        equals(second),
      );
    });

    // Documents StreamProvider's last-write-wins contract: when the underlying
    // stream emits null then a valid prediction in rapid succession (e.g. after
    // a DELETE then INSERT), the final observable state must be the valid
    // prediction.  The previous Completer-based implementation also produced the
    // correct result empirically (Dart's FIFO microtask scheduler delivers
    // events in order), but `StreamProvider` makes the contract explicit and
    // eliminates the Completer juggling entirely.
    test('rapid null→valid emissions leave state as valid, not null', () async {
      final expectedStart = DateTime.utc(2026, 7, 1);
      final validPrediction = CyclePrediction(
        windowStart: expectedStart.subtract(const Duration(days: 2)),
        windowEnd: expectedStart.add(const Duration(days: 2)),
        expectedStart: expectedStart,
        cyclesUsed: 3,
      );

      final fakeUc = _StreamingWatchCyclePrediction();
      addTearDown(fakeUc.close);
      final container = ProviderContainer(
        overrides: [
          watchCyclePredictionProvider.overrideWith(
            (ref) async => fakeUc,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Buffer both events before the provider subscribes; single-subscription
      // StreamController delivers them in order once the listener attaches.
      fakeUc.add(null); // A
      fakeUc.add(validPrediction); // B

      await container.read(cyclePredictionProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(cyclePredictionProvider).valueOrNull,
        equals(validPrediction),
        reason: 'StreamProvider last-write-wins: B must be the final state.',
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

/// Fake backed by a single-subscription StreamController for multi-emission tests.
/// Single-subscription buffers events until the listener attaches, which is
/// required because StreamProvider subscribes asynchronously after build() resolves.
class _StreamingWatchCyclePrediction implements WatchCyclePrediction {
  final _controller = StreamController<CyclePrediction?>();

  void add(CyclePrediction? p) => _controller.add(p);
  void close() => _controller.close();

  @override
  Stream<CyclePrediction?> call() => _controller.stream;
}
