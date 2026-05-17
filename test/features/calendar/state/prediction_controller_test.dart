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
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/use_cases/watch_cycle_prediction.dart';
import 'package:metra/features/calendar/state/prediction_controller.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

// ---------------------------------------------------------------------------
// Helper: creates a ProviderContainer, resolves the async dependencies of
// cyclePredictionProvider, and attaches a listener so the provider is alive.
//
// Context: cyclePredictionProvider (after BUG-001 fix) has a synchronous body
// that calls ref.watch(watchCyclePredictionProvider) and
// ref.watch(appSettingsStreamProvider). Both are async and start in
// AsyncLoading; while either is loading the body returns Stream.empty() and
// cyclePredictionProvider.future never completes.
//
// Two-part fix:
//   1. Await the use-case FutureProvider (always) so the UC is ready.
//      When no custom settings stream is provided also await the settings
//      StreamProvider — a broadcast stream cannot be awaited here because
//      it has no buffered event; those tests drive timing themselves.
//   2. Call container.listen(cyclePredictionProvider, ...) so the provider
//      is alive (has a listener). Without a listener Riverpod rebuilds
//      non-autoDispose providers lazily (on next read), not eagerly.
//      With a listener, rebuilds triggered by dependency changes happen in
//      the same microtask, ensuring valueOrNull is current on the next read.
// ---------------------------------------------------------------------------
Future<ProviderContainer> _makeContainer({
  required FutureOr<WatchCyclePrediction> Function(
    Ref<AsyncValue<WatchCyclePrediction>>,
  ) ucFactory,
  Stream<AppSettingsData?> Function()? settingsStream,
}) async {
  final container = ProviderContainer(
    overrides: [
      watchCyclePredictionProvider.overrideWith(ucFactory),
      appSettingsStreamProvider.overrideWith(
        (ref) => settingsStream != null ? settingsStream() : Stream.value(null),
      ),
    ],
  );
  await container.read(watchCyclePredictionProvider.future);
  if (settingsStream == null) {
    // Static Stream.value(null): safe to await; also subscribes
    // appSettingsStreamProvider so cyclePredictionProvider builds with
    // AsyncData on its first read.
    await container.read(appSettingsStreamProvider.future);
  }
  // Attach a no-op listener so Riverpod treats the provider as active.
  // Eager rebuilds fire synchronously when dependencies change, which is
  // required for the reactivity and EC-01 tests.
  container.listen(cyclePredictionProvider, (_, __) {});
  return container;
}

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

      final container = await _makeContainer(
        ucFactory: (ref) async => _FakeWatchCyclePrediction(prediction),
      );
      addTearDown(container.dispose);

      final result = await container.read(cyclePredictionProvider.future);
      expect(result, equals(prediction));
    });

    test('emits AsyncData(null) when stream yields null', () async {
      final container = await _makeContainer(
        ucFactory: (ref) async => _FakeWatchCyclePrediction(null),
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

      final container = await _makeContainer(
        ucFactory: (ref) async => fakeUc,
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

      final container = await _makeContainer(
        ucFactory: (ref) async => fakeUc,
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

  // ===========================================================================
  // BUG-001 reactivity tests (FR-01, FR-11, EC-01, EC-02, EC-03)
  // These verify the synchronous StreamProvider body correctly reacts to
  // changes in appSettingsStreamProvider within the same app session.
  // ===========================================================================

  group('cyclePredictionProvider reactivity (BUG-001 fix)', () {
    final windowStart = DateTime.utc(2026, 6, 15);
    final predictionForDeclared = CyclePrediction(
      windowStart: windowStart.subtract(const Duration(days: 2)),
      windowEnd: windowStart.add(const Duration(days: 2)),
      expectedStart: windowStart,
      cyclesUsed: 1,
    );

    test(
      're-emits non-null prediction after settings emit declaredCycleLength (FR-11, BUG-001)',
      () async {
        final settingsController =
            StreamController<AppSettingsData?>.broadcast();
        addTearDown(settingsController.close);

        // A fake use case that returns null when declaredCycleLength is null,
        // and a real prediction when it is 28.
        final fakeUc = _DeclaredLengthAwareFakeUc(
          predictionFor28: predictionForDeclared,
        );

        final container = await _makeContainer(
          ucFactory: (ref) async => fakeUc,
          settingsStream: () => settingsController.stream,
        );
        addTearDown(container.dispose);

        // Emit first settings: declaredCycleLength = null.
        settingsController.add(AppSettingsData.defaults());
        await Future<void>.delayed(Duration.zero);

        // First state: null prediction (no declaredCycleLength, no measured
        // cycles).
        final firstResult = container.read(cyclePredictionProvider).valueOrNull;
        expect(
          firstResult,
          isNull,
          reason: 'prediction must be null when declaredCycleLength is null',
        );

        // Emit second settings: declaredCycleLength = 28 (simulating
        // onboarding).
        settingsController.add(
          AppSettingsData(
            languageCode: '',
            painEnabled: true,
            notesEnabled: true,
            notificationDaysBefore: 2,
            notificationsEnabled: false,
            onboardingCompleted: true,
            declaredCycleLength: 28,
          ),
        );
        // Allow provider to rebuild and the new stream to emit.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final secondResult =
            container.read(cyclePredictionProvider).valueOrNull;
        expect(
          secondResult,
          equals(predictionForDeclared),
          reason:
              'BUG-001: after settings emit declaredCycleLength=28, provider '
              'must re-run use case and emit a non-null prediction',
        );
      },
    );

    test(
      'emits no data when appSettingsStreamProvider errors (EC-02)',
      () async {
        final settingsController =
            StreamController<AppSettingsData?>.broadcast();
        addTearDown(settingsController.close);

        final emittedData = <CyclePrediction?>[];
        final fakeUc = _DeclaredLengthAwareFakeUc(
          predictionFor28: predictionForDeclared,
        );

        final container = await _makeContainer(
          ucFactory: (ref) async => fakeUc,
          settingsStream: () => settingsController.stream,
        );
        addTearDown(container.dispose);

        container.listen(
          cyclePredictionProvider,
          (_, next) {
            if (next is AsyncData<CyclePrediction?>) {
              emittedData.add(next.value);
            }
          },
        );

        // Emit a stream error simulating a DB error.
        settingsController.addError(Exception('db error'));
        await Future<void>.delayed(Duration.zero);

        expect(
          emittedData,
          isEmpty,
          reason: 'EC-02: cyclePredictionProvider must emit no data when '
              'appSettingsStreamProvider is in error state',
        );
      },
    );

    test(
      'emits no data when watchCyclePredictionProvider is still loading (EC-03)',
      () async {
        final emittedData = <CyclePrediction?>[];

        // Use a container that does NOT await watchCyclePredictionProvider,
        // so we can observe the loading state.
        final container = ProviderContainer(
          overrides: [
            // Never-completing future simulates the use case provider loading.
            watchCyclePredictionProvider.overrideWith(
              (ref) => Completer<WatchCyclePrediction>().future,
            ),
            appSettingsStreamProvider.overrideWith(
              (ref) => Stream.value(AppSettingsData.defaults()),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.listen(
          cyclePredictionProvider,
          (_, next) {
            if (next is AsyncData<CyclePrediction?>) {
              emittedData.add(next.value);
            }
          },
        );

        await Future<void>.delayed(Duration.zero);

        expect(
          emittedData,
          isEmpty,
          reason: 'EC-03: cyclePredictionProvider must emit no data when '
              'watchCyclePredictionProvider is loading',
        );
      },
    );

    test(
      'emits null when settings stream emits null (EC-01)',
      () async {
        final container = await _makeContainer(
          ucFactory: (ref) async => _DeclaredLengthAwareFakeUc(
            predictionFor28: predictionForDeclared,
          ),
          settingsStream: () => Stream.value(null),
        );
        addTearDown(container.dispose);

        final result = await container.read(cyclePredictionProvider.future);
        expect(
          result,
          isNull,
          reason: 'EC-01: when settings emit null, prediction is null '
              '(no declaredCycleLength, no measured cycles fallback available)',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Fake use case that returns null when declaredCycleLength is null, and
/// [predictionFor28] when declaredCycleLength is 28.
class _DeclaredLengthAwareFakeUc implements WatchCyclePrediction {
  _DeclaredLengthAwareFakeUc({required this.predictionFor28});

  final CyclePrediction predictionFor28;

  @override
  Stream<CyclePrediction?> call({int? declaredCycleLength}) {
    if (declaredCycleLength == null) return Stream.value(null);
    if (declaredCycleLength == 28) return Stream.value(predictionFor28);
    return Stream.value(null);
  }
}

/// Fake that immediately emits a single value and then completes.
class _FakeWatchCyclePrediction implements WatchCyclePrediction {
  _FakeWatchCyclePrediction(this._prediction);

  final CyclePrediction? _prediction;

  @override
  Stream<CyclePrediction?> call({int? declaredCycleLength}) =>
      Stream.value(_prediction);
}

/// Fake backed by a single-subscription StreamController for multi-emission
/// tests. Single-subscription buffers events until the listener attaches,
/// which is required because StreamProvider subscribes asynchronously after
/// build() resolves.
class _StreamingWatchCyclePrediction implements WatchCyclePrediction {
  final _controller = StreamController<CyclePrediction?>();

  void add(CyclePrediction? p) => _controller.add(p);
  void close() => _controller.close();

  @override
  Stream<CyclePrediction?> call({int? declaredCycleLength}) =>
      _controller.stream;
}
