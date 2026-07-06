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

// TASK-16 — Onboarding cross-component integration (spec §7.2 Scenarios C/D).
//
// This is a NEW file, deliberately separate from the unit test files
// `test/features/onboarding/state/onboarding_notifier_test.dart` and
// `test/features/onboarding/onboarding_screen_test.dart` (both out of scope
// here — not modified). Those files stub the collaborators
// (`_StubOnboardingNotifier`) to isolate `OnboardingScreen` from
// `OnboardingNotifier`. This file does the opposite: it wires the REAL
// `OnboardingNotifier` (backed by fakes only at the outermost repository/
// platform-service boundary) through a `ProviderContainer` kill-and-relaunch
// cycle against a SHARED `InMemorySecureStorage` instance, to prove the
// cross-component contract end-to-end (spec §7.2 preamble: no REST endpoints
// in this app, so integration scenarios map onto Dart provider/notifier
// contracts rather than HTTP fixtures).
//
// Platform matrix: this file is platform-agnostic (pure Dart/Riverpod state
// + widget tests, no platform channels beyond the already-faked
// `FlutterSecureStorage`) — runs under `flutter test` on any host (Linux CI,
// developer machine).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metra/core/constants/app_constants.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/use_cases/complete_onboarding.dart';
import 'package:metra/features/onboarding/onboarding_screen.dart';
import 'package:metra/features/onboarding/state/onboarding_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Test-local collaborators (kept private to this file — none of these are
// shared fakes, per the project convention of subclassing rather than
// editing test/helpers/* for a single test file's needs).
// ---------------------------------------------------------------------------

/// Wraps [InMemorySecureStorage] so every [read] call awaits [_gate] first —
/// reproduces the EC-11 race between async hydration and `OnboardingScreen`'s
/// first `ref.listen(fireImmediately:true)`-equivalent registration.
class _DelayedReadSecureStorage extends InMemorySecureStorage {
  _DelayedReadSecureStorage(this._gate);

  final Completer<void> _gate;

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
    await _gate.future;
    return super.read(key: key);
  }
}

/// Throws on [delete] for exactly one configured key — simulates a partial
/// platform-channel failure during `OnboardingNotifier.clearDraft()`
/// (Scenario D, clear-failure-is-non-fatal case).
class _ThrowingDeleteOneKeySecureStorage extends InMemorySecureStorage {
  _ThrowingDeleteOneKeySecureStorage({required this.throwingKey});

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

/// [CompleteOnboarding] stub that never touches the database and completes
/// immediately — used everywhere Scenario C/D do not care about the use
/// case's own behaviour, only about the draft-persistence/clear wiring
/// around it.
class _NoOpCompleteOnboarding implements CompleteOnboarding {
  int executeCount = 0;

  @override
  Future<void> execute({
    required DateTime lastPeriodDate,
    required int cycleLength,
    required int periodLength,
  }) async {
    executeCount++;
  }
}

/// [CompleteOnboarding] stub gated by a [Completer] — lets Scenario D's
/// EC-13 test observe secure-storage state WHILE `execute()` is still
/// pending, proving `clearDraft()` (sequenced after `execute()` resolves in
/// `_DataPage._onSubmit`) has not yet run.
class _GatedCompleteOnboarding implements CompleteOnboarding {
  _GatedCompleteOnboarding(this._gate);

  final Completer<void> _gate;
  int executeCount = 0;

  @override
  Future<void> execute({
    required DateTime lastPeriodDate,
    required int cycleLength,
    required int periodLength,
  }) async {
    executeCount++;
    await _gate.future;
  }
}

// ---------------------------------------------------------------------------
// Container / widget-harness builders.
// ---------------------------------------------------------------------------

/// Builds a [ProviderContainer] wired against [storage] with everything else
/// (settings repository, complete-onboarding use case) defaulted to
/// lightweight, non-DB-touching fakes — the shape Scenario C/D need for
/// their kill/relaunch cycles.
ProviderContainer _makeOnboardingContainer({
  required FlutterSecureStorage storage,
  CompleteOnboarding? completeOnboarding,
}) =>
    ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        appSettingsRepositoryProvider.overrideWith(
          (_) async => FakeAppSettingsRepository(),
        ),
        completeOnboardingProvider.overrideWith(
          (_) async => completeOnboarding ?? _NoOpCompleteOnboarding(),
        ),
      ],
    );

/// Plain `MaterialApp` harness — no router. Used by Scenario C, which never
/// submits onboarding (so `context.go('/calendar')` never fires).
Widget _wrapOnboarding(ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: MetraTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingScreen(),
      ),
    );

/// `GoRouter` harness — used by Scenario D, which completes onboarding and
/// must land on a real `/calendar` route.
Widget _wrapOnboardingWithRouter(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (_, __) => const Scaffold(body: Text('calendar-stub')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// `OnboardingScreen` needs a tall viewport (§12.1/§12.3 layouts) — matches
/// the convention already used throughout `onboarding_screen_test.dart`.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Scenario C — kill/relaunch draft persistence (FR-04/FR-05)', () {
    testWidgets(
      'EC-08: a page-2 draft persisted before "kill" is restored and '
      'auto-advances after a fresh container/screen ("relaunch") against '
      'the same secure storage',
      (tester) async {
        _useTallViewport(tester);
        final storage = InMemorySecureStorage();

        final container = _makeOnboardingContainer(storage: storage);
        await tester.pumpWidget(_wrapOnboarding(container));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        final date = DateTime.utc(2026, 3, 10);
        container.read(onboardingNotifierProvider.notifier).setDate(date);
        container
            .read(onboardingNotifierProvider.notifier)
            .incrementCycleLength();
        container.read(onboardingNotifierProvider.notifier).setPeriodLength(5);
        await tester.pumpAndSettle();

        // The draft genuinely landed in the shared secure storage before
        // "kill" — not merely in the in-memory notifier state.
        expect(
          storage.values[AppConstants.kOnboardingDraftDateKey],
          '2026-03-10',
        );

        // "Kill": dispose the container — no listeners, no state survive.
        container.dispose();
        // Force a full unmount of the old element/State tree first. Without
        // this intermediate empty pump, Flutter's widget reconciliation
        // would reuse the SAME `_OnboardingScreenState` (same
        // `PageController`, same `_didAutoAdvance` guard) across the swap
        // below — that would test a widget rebuild, not a real app "kill".
        await tester.pumpWidget(const SizedBox.shrink());

        // "Relaunch": a fresh container/screen against the SAME storage.
        final freshContainer = _makeOnboardingContainer(storage: storage);
        addTearDown(freshContainer.dispose);
        await tester.pumpWidget(_wrapOnboarding(freshContainer));
        await tester.pumpAndSettle();

        // Auto-advanced to page 2 with the restored draft, per canon §12.3.
        expect(find.textContaining('Tell me'), findsOneWidget);
        expect(find.text('10 March 2026'), findsOneWidget); // date input row
        expect(find.text('29'), findsOneWidget); // number stepper (28+1)
        expect(
          freshContainer.read(onboardingNotifierProvider).periodLength,
          5,
          reason: 'period-day cell restore is verified at the state level; '
              'the rendered cell highlight is covered by '
              'onboarding_screen_test.dart canon-detail assertions',
        );
      },
    );

    testWidgets(
      'EC-09: visiting page 2 without choosing a date never persists a '
      'draft — a relaunch opens on page 1',
      (tester) async {
        _useTallViewport(tester);
        final storage = InMemorySecureStorage();

        final container = _makeOnboardingContainer(storage: storage);
        await tester.pumpWidget(_wrapOnboarding(container));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        // Adjust cycle length without ever picking a date — Group F:
        // _persistDraft() is gated on lastPeriodDate != null, so this must
        // write nothing.
        container
            .read(onboardingNotifierProvider.notifier)
            .incrementCycleLength();
        await tester.pumpAndSettle();

        expect(storage.values, isEmpty);

        container.dispose();
        // Force a full unmount before "relaunching" — see the EC-08 test's
        // comment for why this is required.
        await tester.pumpWidget(const SizedBox.shrink());

        final freshContainer = _makeOnboardingContainer(storage: storage);
        addTearDown(freshContainer.dispose);
        await tester.pumpWidget(_wrapOnboarding(freshContainer));
        await tester.pumpAndSettle();

        expect(find.text('Get started'), findsOneWidget);
        expect(find.textContaining('Tell me'), findsNothing);
      },
    );

    testWidgets(
      'EC-11: a relaunch whose secure-storage read resolves on a delayed '
      'future still auto-advances exactly once, after a transient page-1 '
      'render',
      (tester) async {
        _useTallViewport(tester);
        final gate = Completer<void>();
        final delayedStorage = _DelayedReadSecureStorage(gate)
          ..values[AppConstants.kOnboardingDraftDateKey] = '2026-03-10'
          ..values[AppConstants.kOnboardingDraftCycleLengthKey] = '30'
          ..values[AppConstants.kOnboardingDraftPeriodLengthKey] = '4';

        final container = _makeOnboardingContainer(storage: delayedStorage);
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrapOnboarding(container));
        await tester.pump();

        // Hydration hasn't resolved yet — transient page-1 render.
        expect(find.text('Get started'), findsOneWidget);
        expect(find.textContaining('Tell me'), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();

        expect(find.textContaining('Tell me'), findsOneWidget);
        expect(find.text('10 March 2026'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'no double jumpToPage / no assertion error from a '
              'duplicate auto-advance attempt',
        );
      },
    );
  });

  group('Scenario D — draft cleared on successful completion (FR-06)', () {
    testWidgets(
      "EC-13: all three secure-storage keys are deleted before "
      "context.go('/calendar') fires",
      (tester) async {
        _useTallViewport(tester);
        final storage = InMemorySecureStorage();
        final gate = Completer<void>();
        final gatedCompleteOnboarding = _GatedCompleteOnboarding(gate);

        final container = _makeOnboardingContainer(
          storage: storage,
          completeOnboarding: gatedCompleteOnboarding,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrapOnboardingWithRouter(container));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        container
            .read(onboardingNotifierProvider.notifier)
            .setDate(DateTime.utc(2026, 4, 2));
        await tester.pumpAndSettle();

        expect(
          storage.values[AppConstants.kOnboardingDraftDateKey],
          isNotNull,
          reason: 'the draft must be persisted before submission',
        );

        await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
        await tester
            .pump(); // CompleteOnboarding.execute() suspends on the gate

        // clearDraft() is sequenced strictly AFTER execute() resolves in
        // _DataPage._onSubmit — the draft must still be intact while
        // execute() is pending.
        expect(gatedCompleteOnboarding.executeCount, 1);
        expect(
          storage.values[AppConstants.kOnboardingDraftDateKey],
          isNotNull,
          reason: 'clearDraft must not run before CompleteOnboarding.execute() '
              'resolves',
        );
        expect(find.text('calendar-stub'), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();

        expect(
          storage.values,
          isEmpty,
          reason: 'all three draft keys must be gone once navigation fires',
        );
        expect(find.text('calendar-stub'), findsOneWidget);
      },
    );

    testWidgets(
      'EC-14: re-entering onboarding after a completed+cleared draft '
      'restores nothing and opens on page 1',
      (tester) async {
        _useTallViewport(tester);
        final storage = InMemorySecureStorage();
        final container = _makeOnboardingContainer(storage: storage);

        await tester.pumpWidget(_wrapOnboardingWithRouter(container));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        container
            .read(onboardingNotifierProvider.notifier)
            .setDate(DateTime.utc(2026, 4, 2));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
        await tester.pumpAndSettle();

        expect(find.text('calendar-stub'), findsOneWidget);
        expect(storage.values, isEmpty);

        container.dispose();
        // Force a full unmount before "relaunching" — see Scenario C's
        // EC-08 test comment for why this is required.
        await tester.pumpWidget(const SizedBox.shrink());

        // Re-entry (e.g. a data-reset scenario): fresh container, the SAME
        // (now-cleared) storage, a fresh screen.
        final freshContainer = _makeOnboardingContainer(storage: storage);
        addTearDown(freshContainer.dispose);
        await tester.pumpWidget(_wrapOnboarding(freshContainer));
        await tester.pumpAndSettle();

        expect(find.text('Get started'), findsOneWidget);
        expect(find.textContaining('Tell me'), findsNothing);
      },
    );

    testWidgets(
      'clearDraft failure is swallowed+logged and navigation still proceeds',
      (tester) async {
        _useTallViewport(tester);
        final storage = _ThrowingDeleteOneKeySecureStorage(
          throwingKey: AppConstants.kOnboardingDraftCycleLengthKey,
        );
        final container = _makeOnboardingContainer(storage: storage);
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrapOnboardingWithRouter(container));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        container
            .read(onboardingNotifierProvider.notifier)
            .setDate(DateTime.utc(2026, 4, 2));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
        await tester.pumpAndSettle();

        expect(find.text('calendar-stub'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
