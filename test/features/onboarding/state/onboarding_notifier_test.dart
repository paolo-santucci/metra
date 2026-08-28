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

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/constants/app_constants.dart';
import 'package:metra/features/onboarding/state/onboarding_notifier.dart';
import 'package:metra/providers/encryption_provider.dart';

import '../../../helpers/in_memory_secure_storage.dart';

/// Throws on every [read] call — simulates a secure-storage platform-channel
/// failure during [OnboardingNotifier] hydration (EC-12).
class _ThrowingReadSecureStorage extends InMemorySecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: 'test_failure',
      message: 'simulated secure-storage read failure',
    );
  }
}

/// Throws on [delete] for exactly one configured key — simulates a partial
/// platform-channel failure during `OnboardingNotifier.clearDraft()`.
class _ThrowingDeleteSecureStorage extends InMemorySecureStorage {
  _ThrowingDeleteSecureStorage({required this.throwingKey});

  final String throwingKey;

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == throwingKey) {
      throw PlatformException(
        code: 'test_failure',
        message: 'simulated secure-storage delete failure',
      );
    }
    await super.delete(key: key);
  }
}

void main() {
  ProviderContainer makeContainer({FlutterSecureStorage? storage}) =>
      ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(
            storage ?? InMemorySecureStorage(),
          ),
        ],
      );

  test('initial cycleLength is 28', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 28);
  });

  test('initial lastPeriodDate is null', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.lastPeriodDate, isNull);
  });

  test('setDate updates lastPeriodDate', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final date = DateTime.utc(2026, 3, 15);
    container.read(onboardingNotifierProvider.notifier).setDate(date);
    final state = container.read(onboardingNotifierProvider);
    expect(state.lastPeriodDate, date);
  });

  test('incrementCycleLength increments by 1', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).incrementCycleLength();
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 29);
  });

  test('decrementCycleLength decrements by 1', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).decrementCycleLength();
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 27);
  });

  test('incrementCycleLength clamps at 45', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    for (var i = 0; i < 40; i++) {
      container
          .read(onboardingNotifierProvider.notifier)
          .incrementCycleLength();
    }
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 45);
  });

  test('decrementCycleLength clamps at 21', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    for (var i = 0; i < 30; i++) {
      container
          .read(onboardingNotifierProvider.notifier)
          .decrementCycleLength();
    }
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 21);
  });

  test('initial periodLength is 3', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.periodLength, 3);
  });

  test('setPeriodLength updates periodLength', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).setPeriodLength(5);
    final state = container.read(onboardingNotifierProvider);
    expect(state.periodLength, 5);
  });

  test('setPeriodLength clamps at 1', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).setPeriodLength(0);
    final state = container.read(onboardingNotifierProvider);
    expect(state.periodLength, 1);
  });

  test('setPeriodLength clamps at 8', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).setPeriodLength(9);
    final state = container.read(onboardingNotifierProvider);
    expect(state.periodLength, 8);
  });

  test('canSubmit is false when lastPeriodDate is null', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.canSubmit, isFalse);
  });

  test('canSubmit is true when lastPeriodDate is set', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final date = DateTime.utc(2026, 3, 15);
    container.read(onboardingNotifierProvider.notifier).setDate(date);
    final state = container.read(onboardingNotifierProvider);
    expect(state.canSubmit, isTrue);
  });

  // ── FR-06 / FR-07: isSubmitting + future-date guard (M2) ─────────────────

  test('initial state: isSubmitting is false', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.isSubmitting, isFalse);
  });

  test('setDate(futureDate) → state unchanged, canSubmit unchanged', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    // Set a valid date first so canSubmit is true.
    final validDate = DateTime.utc(2026, 3, 15);
    container.read(onboardingNotifierProvider.notifier).setDate(validDate);
    final stateBefore = container.read(onboardingNotifierProvider);
    expect(stateBefore.lastPeriodDate, validDate);

    // Attempt to set a future date — must be ignored.
    final futureDate = DateTime.now().add(const Duration(days: 1));
    container.read(onboardingNotifierProvider.notifier).setDate(futureDate);
    final stateAfter = container.read(onboardingNotifierProvider);
    expect(
      stateAfter.lastPeriodDate,
      validDate,
      reason: 'future date must be silently ignored',
    );
    expect(
      stateAfter.canSubmit,
      isTrue,
      reason: 'canSubmit must remain unchanged after future-date rejection',
    );
  });

  test(
      'setDate(DateTime.now()) (today) → state updated (boundary: today is not future)',
      () {
    final container = makeContainer();
    addTearDown(container.dispose);
    // Use a UTC date at the start of today to avoid timezone drift in tests.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    container.read(onboardingNotifierProvider.notifier).setDate(today);
    final state = container.read(onboardingNotifierProvider);
    expect(state.lastPeriodDate, today);
  });

  test('setDate(pastDate) → state updated normally', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final pastDate = DateTime.utc(2020, 1, 1);
    container.read(onboardingNotifierProvider.notifier).setDate(pastDate);
    final state = container.read(onboardingNotifierProvider);
    expect(state.lastPeriodDate, pastDate);
  });

  test('setSubmitting(true) sets isSubmitting to true', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).setSubmitting(true);
    final state = container.read(onboardingNotifierProvider);
    expect(state.isSubmitting, isTrue);
  });

  test('setSubmitting(false) clears isSubmitting', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).setSubmitting(true);
    container.read(onboardingNotifierProvider.notifier).setSubmitting(false);
    final state = container.read(onboardingNotifierProvider);
    expect(state.isSubmitting, isFalse);
  });

  // ── TASK-06 (#26): hydrate/persist/clear + draft keys ────────────────────
  // Spec refs: FR-04, FR-05, FR-06, §5.1, §5.3, §7.1 Groups E/F/G, NFR-05,
  // NFR-07, EC-08…EC-14.

  group('Group E — hydration (FR-05)', () {
    test(
      'build() returns default state synchronously with isHydrated false',
      () {
        final container = makeContainer();
        addTearDown(container.dispose);
        final state = container.read(onboardingNotifierProvider);
        expect(state.isHydrated, isFalse);
        expect(state.lastPeriodDate, isNull);
        expect(state.cycleLength, 28);
        expect(state.periodLength, 3);
      },
    );

    test(
      '_hydrate restores a well-formed draft and flips isHydrated (EC-08)',
      () async {
        final storage = InMemorySecureStorage();
        storage.values[AppConstants.kOnboardingDraftDateKey] = '2026-03-15';
        storage.values[AppConstants.kOnboardingDraftCycleLengthKey] = '30';
        storage.values[AppConstants.kOnboardingDraftPeriodLengthKey] = '5';
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);

        container.read(onboardingNotifierProvider); // triggers build()
        await Future<void>.delayed(Duration.zero);

        final state = container.read(onboardingNotifierProvider);
        expect(state.isHydrated, isTrue);
        expect(state.lastPeriodDate, DateTime.utc(2026, 3, 15));
        expect(state.cycleLength, 30);
        expect(state.periodLength, 5);
      },
    );

    test(
      '_hydrate flips isHydrated with defaults when no draft key is present '
      '(EC-09 / EC-14)',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(onboardingNotifierProvider);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(onboardingNotifierProvider);
        expect(state.isHydrated, isTrue);
        expect(state.lastPeriodDate, isNull);
        expect(state.cycleLength, 28);
        expect(state.periodLength, 3);
      },
    );

    test(
      '_hydrate treats a secure-storage read failure as "no draft" and does '
      'not propagate to the caller (EC-12)',
      () async {
        final container = makeContainer(storage: _ThrowingReadSecureStorage());
        addTearDown(container.dispose);

        container.read(onboardingNotifierProvider);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(onboardingNotifierProvider);
        expect(state.isHydrated, isTrue);
        expect(state.lastPeriodDate, isNull);
        expect(state.cycleLength, 28);
        expect(state.periodLength, 3);
      },
    );

    test(
      '_hydrate treats a malformed stored date as "no draft" without an '
      'uncaught FormatException',
      () async {
        final storage = InMemorySecureStorage();
        storage.values[AppConstants.kOnboardingDraftDateKey] = 'not-a-date';
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);

        container.read(onboardingNotifierProvider);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(onboardingNotifierProvider);
        expect(state.isHydrated, isTrue);
        expect(state.lastPeriodDate, isNull);
        expect(state.cycleLength, 28);
        expect(state.periodLength, 3);
      },
    );

    test(
      'a listener registered before hydration resolves observes exactly one '
      'isHydrated:false→true transition (EC-11, registered-before ordering)',
      () async {
        final storage = InMemorySecureStorage();
        storage.values[AppConstants.kOnboardingDraftDateKey] = '2026-03-15';
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);

        final hydratedTransitions = <bool>[];
        container.listen(
          onboardingNotifierProvider,
          (previous, next) => hydratedTransitions.add(next.isHydrated),
          fireImmediately: true,
        );

        await Future<void>.delayed(Duration.zero);

        expect(
          hydratedTransitions.where((v) => v).length,
          1,
          reason: 'isHydrated must flip to true exactly once',
        );
      },
    );

    test(
      'a listener registered after hydration has already resolved observes '
      'the settled isHydrated value exactly once (EC-11, registered-after '
      'ordering)',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);
        container.read(onboardingNotifierProvider); // triggers build()
        await Future<void>.delayed(Duration.zero); // let hydration settle

        final hydratedTransitions = <bool>[];
        container.listen(
          onboardingNotifierProvider,
          (previous, next) => hydratedTransitions.add(next.isHydrated),
          fireImmediately: true,
        );

        await Future<void>.delayed(Duration.zero);

        expect(hydratedTransitions, [true]);
      },
    );
  });

  group('Group F — draft persistence (FR-04, NFR-05, NFR-07)', () {
    test(
      'setDate persists all 3 keys and returns before the write future '
      'completes (NFR-05)',
      () async {
        final storage = InMemorySecureStorage();
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);
        await Future<void>.delayed(Duration.zero); // let hydration settle
        storage.resetCallCounts();

        final date = DateTime.utc(2026, 3, 15);
        container.read(onboardingNotifierProvider.notifier).setDate(date);

        // The setter must return before the underlying write() completes.
        expect(storage.writeCount, 0);

        await Future<void>.delayed(Duration.zero);

        expect(storage.writeCount, 3);
        expect(
          storage.values[AppConstants.kOnboardingDraftDateKey],
          '2026-03-15',
        );
        expect(
          storage.values[AppConstants.kOnboardingDraftCycleLengthKey],
          '28',
        );
        expect(
          storage.values[AppConstants.kOnboardingDraftPeriodLengthKey],
          '3',
        );
      },
    );

    test(
      'landing on page 2 with no date chosen never persists (EC-09, zero '
      'writes)',
      () async {
        final storage = InMemorySecureStorage();
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);
        await Future<void>.delayed(Duration.zero);
        storage.resetCallCounts();

        final notifier = container.read(onboardingNotifierProvider.notifier);
        notifier.incrementCycleLength();
        notifier.setPeriodLength(5);
        await Future<void>.delayed(Duration.zero);

        expect(storage.writeCount, 0);
      },
    );

    test(
      'rapid incrementCycleLength calls serialize through _writeChain — the '
      'terminal stored value is the LAST mutation (EC-10, last-write-wins, '
      'no debounce)',
      () async {
        final storage = InMemorySecureStorage();
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);
        final notifier = container.read(onboardingNotifierProvider.notifier);
        notifier.setDate(DateTime.utc(2026, 3, 15));
        await Future<void>.delayed(Duration.zero);
        storage.resetCallCounts();

        // Rapid stepper taps within the same synchronous burst.
        for (var i = 0; i < 5; i++) {
          notifier.incrementCycleLength();
        }

        await Future<void>.delayed(Duration.zero);

        final finalState = container.read(onboardingNotifierProvider);
        expect(finalState.cycleLength, 33); // 28 + 5
        expect(
          storage.values[AppConstants.kOnboardingDraftCycleLengthKey],
          '33',
          reason: 'terminal keystore value must equal the LAST mutation',
        );
      },
    );

    test('draft values are stored as 3 separate strings, not JSON', () async {
      final storage = InMemorySecureStorage();
      final container = makeContainer(storage: storage);
      addTearDown(container.dispose);
      container
          .read(onboardingNotifierProvider.notifier)
          .setDate(DateTime.utc(2020, 12, 1));
      await Future<void>.delayed(Duration.zero);

      expect(
        storage.values[AppConstants.kOnboardingDraftDateKey],
        '2020-12-01',
      );
      expect(
        storage.values[AppConstants.kOnboardingDraftCycleLengthKey],
        '28',
      );
      expect(
        storage.values[AppConstants.kOnboardingDraftPeriodLengthKey],
        '3',
      );
      for (final value in storage.values.values) {
        expect(
          value.trim().startsWith('{'),
          isFalse,
          reason: 'draft values must not be JSON-encoded',
        );
      }
    });

    test(
      'the 3 AppConstants draft keys are static const, follow the '
      'metra_<feature>_<purpose>_v1 convention, are pairwise distinct, and '
      'do not collide with kBackupPassphraseKey',
      () {
        const keys = [
          AppConstants.kOnboardingDraftDateKey,
          AppConstants.kOnboardingDraftCycleLengthKey,
          AppConstants.kOnboardingDraftPeriodLengthKey,
        ];
        final keyPattern = RegExp(r'^metra_[a-z0-9_]+_v1$');
        for (final key in keys) {
          expect(
            keyPattern.hasMatch(key),
            isTrue,
            reason: '$key must follow metra_<feature>_<purpose>_v1',
          );
        }
        expect(
          keys.toSet().length,
          keys.length,
          reason: 'draft keys must be pairwise distinct',
        );
        expect(keys, isNot(contains(AppConstants.kBackupPassphraseKey)));
      },
    );

    test(
      'NFR-07 static guard: no SharedPreferences reference in '
      'lib/features/onboarding/',
      () {
        final offending = Directory('lib/features/onboarding')
            .listSync(recursive: true)
            .whereType<File>()
            .where((entity) => entity.path.endsWith('.dart'))
            .where(
              (entity) => RegExp('SharedPreferences|shared_preferences')
                  .hasMatch(entity.readAsStringSync()),
            )
            .map((entity) => entity.path)
            .toList();

        expect(
          offending,
          isEmpty,
          reason: 'The onboarding draft must live only in secure storage. '
              'Offending files:\n${offending.join('\n')}',
        );
      },
    );
  });

  group('Group G — clearDraft() (FR-06, EC-13/EC-14)', () {
    test('clearDraft deletes all three keys', () async {
      final storage = InMemorySecureStorage();
      final container = makeContainer(storage: storage);
      addTearDown(container.dispose);
      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.setDate(DateTime.utc(2026, 3, 15));
      await Future<void>.delayed(Duration.zero);
      expect(storage.values[AppConstants.kOnboardingDraftDateKey], isNotNull);

      await notifier.clearDraft();

      expect(
        await storage.read(key: AppConstants.kOnboardingDraftDateKey),
        isNull,
      );
      expect(
        await storage.read(key: AppConstants.kOnboardingDraftCycleLengthKey),
        isNull,
      );
      expect(
        await storage.read(key: AppConstants.kOnboardingDraftPeriodLengthKey),
        isNull,
      );
    });

    test(
      'clearDraft is idempotent when the keys are already absent',
      () async {
        final storage = InMemorySecureStorage();
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);
        final notifier = container.read(onboardingNotifierProvider.notifier);
        await Future<void>.delayed(Duration.zero);

        await notifier.clearDraft();
        await expectLater(notifier.clearDraft(), completes);
      },
    );

    test(
      'clearDraft swallows a delete() failure for one key and does not '
      'rethrow',
      () async {
        final storage = _ThrowingDeleteSecureStorage(
          throwingKey: AppConstants.kOnboardingDraftCycleLengthKey,
        );
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);
        final notifier = container.read(onboardingNotifierProvider.notifier);
        notifier.setDate(DateTime.utc(2026, 3, 15));
        await Future<void>.delayed(Duration.zero);

        await expectLater(notifier.clearDraft(), completes);
      },
    );

    test(
      'clearDraft still deletes the other keys when one delete() throws '
      '(best-effort)',
      () async {
        final storage = _ThrowingDeleteSecureStorage(
          throwingKey: AppConstants.kOnboardingDraftCycleLengthKey,
        );
        final container = makeContainer(storage: storage);
        addTearDown(container.dispose);
        final notifier = container.read(onboardingNotifierProvider.notifier);
        notifier.setDate(DateTime.utc(2026, 3, 15));
        await Future<void>.delayed(Duration.zero);

        await notifier.clearDraft();

        expect(
          await storage.read(key: AppConstants.kOnboardingDraftDateKey),
          isNull,
        );
        expect(
          await storage.read(
            key: AppConstants.kOnboardingDraftPeriodLengthKey,
          ),
          isNull,
        );
      },
    );
  });
}
