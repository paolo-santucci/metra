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
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/metra_wordmark.dart';
import 'package:metra/core/widgets/segmented_control_metra.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/use_cases/complete_onboarding.dart';
import 'package:metra/features/onboarding/onboarding_screen.dart';
import 'package:metra/features/onboarding/state/onboarding_notifier.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/use_case_providers.dart';

// ---------------------------------------------------------------------------
// Stub: OnboardingNotifier that seeds lastPeriodDate so canSubmit is true.
// ---------------------------------------------------------------------------

class _StubOnboardingNotifier extends OnboardingNotifier {
  _StubOnboardingNotifier({
    DateTime? seedDate,
    bool isHydrated = false,
    this.clearDraftError,
    Completer<void>? clearDraftGate,
    Future<void>? hydrateAfter,
  })  : _seedDate = seedDate,
        _initialIsHydrated = isHydrated,
        _clearDraftGate = clearDraftGate,
        _hydrateAfter = hydrateAfter;

  final DateTime? _seedDate;
  final bool _initialIsHydrated;
  final Completer<void>? _clearDraftGate;
  final Future<void>? _hydrateAfter;

  /// Error to throw from [clearDraft], if set — lets tests exercise the
  /// widget's own defensive swallow-and-log wrapper even though the real
  /// [OnboardingNotifier.clearDraft] is documented to never rethrow.
  final Object? clearDraftError;

  /// Number of times [clearDraft] has been invoked.
  int clearDraftCallCount = 0;

  @override
  OnboardingState build() {
    final hydrateAfter = _hydrateAfter;
    if (hydrateAfter != null) {
      hydrateAfter.then((_) {
        state = OnboardingState(lastPeriodDate: _seedDate, isHydrated: true);
      });
    }
    return OnboardingState(
      lastPeriodDate: _seedDate,
      isHydrated: _initialIsHydrated,
    );
  }

  @override
  Future<void> clearDraft() async {
    clearDraftCallCount++;
    final gate = _clearDraftGate;
    if (gate != null) await gate.future;
    final error = clearDraftError;
    if (error != null) throw error;
  }
}

// ---------------------------------------------------------------------------
// Stub: SettingsNotifier — TASK-14 (#27 welcome-page language selector).
//
// _WelcomePage now watches settingsNotifierProvider (to derive the
// selector's selectedIndex and to call save() on selection), so every test
// in this file that mounts OnboardingScreen must override it — the real
// SettingsNotifier.build() reaches the Drift database, which is not wired
// in a bare widget-test ProviderScope (same convention as
// calendar_screen_test.dart / settings_screen_test.dart).
// ---------------------------------------------------------------------------

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._initial);

  final AppSettingsData _initial;
  AppSettingsData? savedSettings;
  int saveCallCount = 0;

  @override
  Future<AppSettingsData> build() async => _initial;

  @override
  Future<void> save(AppSettingsData settings) async {
    savedSettings = settings;
    saveCallCount++;
    state = AsyncData(settings);
  }
}

/// Minimal valid [AppSettingsData] with the given [languageCode] — the only
/// field this test file's assertions care about.
AppSettingsData _settingsWith({required String languageCode}) =>
    AppSettingsData(
      languageCode: languageCode,
      darkMode: null,
      painEnabled: true,
      notesEnabled: true,
      notificationDaysBefore: 2,
      notificationsEnabled: false,
      onboardingCompleted: false,
    );

// ---------------------------------------------------------------------------
// Stub: CompleteOnboarding backed by a Completer so tests control timing.
// ---------------------------------------------------------------------------

class _StubCompleteOnboarding implements CompleteOnboarding {
  _StubCompleteOnboarding({required Completer<void> completer})
      : _completer = completer;

  final Completer<void> _completer;
  int executeCount = 0;

  @override
  Future<void> execute({
    required DateTime lastPeriodDate,
    required int cycleLength,
    required int periodLength,
  }) async {
    executeCount++;
    await _completer.future;
  }
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

/// Plain MaterialApp wrapper — used for tests that do NOT tap "All set →".
///
/// [settings] seeds the default `settingsNotifierProvider` stub consumed by
/// `_WelcomePage`'s language selector (TASK-14); pass an explicit override
/// for that provider via [overrides] to replace it (e.g. to capture
/// `save()` calls) — a later entry in the combined overrides list wins.
Widget _wrap({
  List<Override> overrides = const [],
  AppSettingsData? settings,
}) =>
    ProviderScope(
      overrides: [
        settingsNotifierProvider.overrideWith(
          () => _StubSettingsNotifier(
            settings ?? _settingsWith(languageCode: 'en'),
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: MetraTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingScreen(),
      ),
    );

/// GoRouter wrapper — used for tests that complete the submit flow so that
/// `context.go('/calendar')` does not throw (no GoRouter in scope).
///
/// See [_wrap] for the [settings] / [overrides] precedence note.
Widget _wrapWithRouter({
  required List<Override> overrides,
  AppSettingsData? settings,
}) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (_, __) => const Scaffold(body: Text('calendar')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StubSettingsNotifier(
          settings ?? _settingsWith(languageCode: 'en'),
        ),
      ),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// ---------------------------------------------------------------------------
// Shared setup helper: navigate to data page (step 2 of 2).
// ---------------------------------------------------------------------------

Future<void> _goToDataPage(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OnboardingScreen — welcome page (step 1 of 2)', () {
    testWidgets('shows tagline and Get started button', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('Your rhythm'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('Get started navigates directly to data page', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      // Lands on the data page (step 2 of 2), not a privacy screen.
      expect(find.textContaining('Tell me'), findsOneWidget);
    });
  });

  group('OnboardingScreen — data page (step 2 of 2)', () {
    testWidgets('navigates to data page after tapping Get started',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tell me'), findsOneWidget);
    });

    testWidgets('All set button is disabled with no date selected',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'All set →'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('cycle length defaults to 28', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.text('28'), findsOneWidget);
    });

    testWidgets('+ button increments cycle length', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      expect(find.text('29'), findsOneWidget);
    });
  });

  // ── FR-06: double-submission guard ─────────────────────────────────────────

  group('OnboardingScreen — FR-06 double-submission guard', () {
    final seedDate = DateTime.utc(2026, 5, 1);

    testWidgets(
        'double-tap All set → CompleteOnboarding.execute called exactly once',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Completer that never completes: keeps the button in disabled state.
      final completer = Completer<void>();
      final stub = _StubCompleteOnboarding(completer: completer);

      await tester.pumpWidget(
        _wrap(
          overrides: [
            onboardingNotifierProvider.overrideWith(
              () => _StubOnboardingNotifier(seedDate: seedDate),
            ),
            completeOnboardingProvider.overrideWith((_) async => stub),
          ],
        ),
      );
      await _goToDataPage(tester);

      // Tap once — this starts the async submit and sets isSubmitting=true.
      await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
      await tester.pump(); // one frame so setSubmitting(true) is processed

      // Second tap: button should be disabled (onPressed=null), ignored.
      await tester.tap(
        find.widgetWithText(FilledButton, 'All set →'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(stub.executeCount, equals(1));
    });

    testWidgets(
        'during submit: CTA onPressed is null and Semantics.enabled is false',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Completer that never completes: keeps isSubmitting=true indefinitely.
      final completer = Completer<void>();
      final stub = _StubCompleteOnboarding(completer: completer);

      await tester.pumpWidget(
        _wrap(
          overrides: [
            onboardingNotifierProvider.overrideWith(
              () => _StubOnboardingNotifier(seedDate: seedDate),
            ),
            completeOnboardingProvider.overrideWith((_) async => stub),
          ],
        ),
      );
      await _goToDataPage(tester);

      // Tap once to begin submit.
      await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
      await tester.pump(); // process setSubmitting(true)

      // While the future is pending, the button must be disabled.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'All set →'),
      );
      expect(button.onPressed, isNull);

      // Semantics node must report enabled=false (disabled state).
      final semantics = tester.getSemantics(
        find.widgetWithText(FilledButton, 'All set →'),
      );
      // SemanticsNode.hasFlag is deprecated; use flagsCollection (dart:ui).
      expect(
        semantics.flagsCollection.isEnabled,
        equals(Tristate.isFalse),
      );
    });

    testWidgets('after submit completes successfully: CTA is re-enabled',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final completer = Completer<void>();
      final stub = _StubCompleteOnboarding(completer: completer);

      await tester.pumpWidget(
        _wrapWithRouter(
          overrides: [
            onboardingNotifierProvider.overrideWith(
              () => _StubOnboardingNotifier(seedDate: seedDate),
            ),
            completeOnboardingProvider.overrideWith((_) async => stub),
          ],
        ),
      );
      await _goToDataPage(tester);

      // Begin submit.
      await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
      await tester.pump(); // setSubmitting(true) applied

      // Verify disabled mid-flight.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'All set →'),
            )
            .onPressed,
        isNull,
      );

      // Complete the use case — triggers finally { setSubmitting(false) }
      // then context.go('/calendar').
      completer.complete();
      await tester.pumpAndSettle();

      // After navigation to /calendar the OnboardingScreen is no longer in the
      // tree, so we just verify we've landed on the calendar placeholder.
      expect(find.text('calendar'), findsOneWidget);
    });

    testWidgets('after submit throws: CTA is re-enabled (isSubmitting=false)',
        (tester) async {
      // This test verifies the widget wiring: when isSubmitting transitions
      // from true → false (via the finally block), the CTA re-enables.
      // The notifier-level behaviour (finally clears isSubmitting on throw)
      // is covered by onboarding_notifier_test.dart (EC-11 unit test).
      // Here we focus only on the widget reflecting state transitions.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Use a Completer-backed stub that never completes so we can control
      // the isSubmitting state directly via the notifier.
      final completer = Completer<void>();
      final stub = _StubCompleteOnboarding(completer: completer);

      await tester.pumpWidget(
        _wrap(
          overrides: [
            onboardingNotifierProvider.overrideWith(
              () => _StubOnboardingNotifier(seedDate: seedDate),
            ),
            completeOnboardingProvider.overrideWith((_) async => stub),
          ],
        ),
      );
      await _goToDataPage(tester);

      // Begin submit — sets isSubmitting=true.
      await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
      await tester.pump();

      // CTA is disabled while isSubmitting=true.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'All set →'),
            )
            .onPressed,
        isNull,
      );

      // Simulate the finally block: directly set isSubmitting=false via the
      // notifier (as the finally block would on both success and error).
      // This decouples the widget-wiring test from async error propagation
      // machinery, which is already covered in onboarding_notifier_test.dart.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)),
      );
      container.read(onboardingNotifierProvider.notifier).setSubmitting(false);
      await tester.pump(); // apply the state update

      // CTA must be re-enabled when isSubmitting returns to false.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'All set →'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  // ── #26: draft auto-advance on hydration ───────────────────────────────────

  group('OnboardingScreen — draft auto-advance on hydration', () {
    testWidgets(
        'EC-08: hydrated draft with lastPeriodDate auto-advances to data '
        'page with fields pre-filled', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final seedDate = DateTime.utc(2026, 5, 1);

      await tester.pumpWidget(
        _wrap(
          overrides: [
            onboardingNotifierProvider.overrideWith(
              () => _StubOnboardingNotifier(
                seedDate: seedDate,
                isHydrated: true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Auto-advanced to page 2 without tapping "Get started".
      expect(find.textContaining('Tell me'), findsOneWidget);
      // Date field pre-filled with the restored draft date.
      expect(find.text('1 May 2026'), findsOneWidget);
    });

    testWidgets(
        'EC-09: hydrated with no draft stays on welcome page '
        '(no auto-advance)', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(
          overrides: [
            onboardingNotifierProvider.overrideWith(
              () => _StubOnboardingNotifier(isHydrated: true),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Get started'), findsOneWidget);
      expect(find.textContaining('Tell me'), findsNothing);
    });
  });

  // ── EC-11: hydration-timing race vs. ref.listen registration ──────────────

  group('OnboardingScreen — EC-11 auto-advance race (guard)', () {
    testWidgets(
        'ordering A: hydration already resolved before first build — '
        'advances exactly once', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final seedDate = DateTime.utc(2026, 5, 1);
      final notifier = _StubOnboardingNotifier(
        seedDate: seedDate,
        isHydrated: true,
      );

      await tester.pumpWidget(
        _wrap(
          overrides: [
            onboardingNotifierProvider.overrideWith(() => notifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tell me'), findsOneWidget);

      // A further harmless state mutation after auto-advance already fired
      // must not trigger a second jump attempt or throw — proves the
      // `_didAutoAdvance` guard, not just idempotent re-navigation.
      notifier.state = notifier.state.copyWith(
        cycleLength: notifier.state.cycleLength + 1,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tell me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ordering B: hydration resolves after listener registration — '
        'advances exactly once', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final seedDate = DateTime.utc(2026, 5, 1);
      final hydrateSignal = Completer<void>();
      final notifier = _StubOnboardingNotifier(
        seedDate: seedDate,
        hydrateAfter: hydrateSignal.future,
      );

      await tester.pumpWidget(
        _wrap(
          overrides: [
            onboardingNotifierProvider.overrideWith(() => notifier),
          ],
        ),
      );
      await tester.pump();

      // Hydration hasn't resolved yet — the ref.listen callback registered
      // at build() time only, with nothing to react to. Still on page 1.
      expect(find.text('Get started'), findsOneWidget);

      // Hydration resolves in a later event-loop turn (as the real
      // secure-storage read would).
      hydrateSignal.complete();
      await tester.pumpAndSettle();

      expect(find.textContaining('Tell me'), findsOneWidget);

      // Harmless post-advance mutation must not trigger a second jump.
      notifier.state = notifier.state.copyWith(
        cycleLength: notifier.state.cycleLength + 1,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tell me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── #26: clear draft on successful submit ──────────────────────────────────

  group('OnboardingScreen — draft cleared on submit', () {
    final seedDate = DateTime.utc(2026, 5, 1);

    testWidgets(
        '_onSubmit success: clearDraft is awaited before navigating to '
        '/calendar', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final executeCompleter = Completer<void>()..complete();
      final stub = _StubCompleteOnboarding(completer: executeCompleter);
      final clearDraftGate = Completer<void>();
      final notifier = _StubOnboardingNotifier(
        seedDate: seedDate,
        clearDraftGate: clearDraftGate,
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          overrides: [
            onboardingNotifierProvider.overrideWith(() => notifier),
            completeOnboardingProvider.overrideWith((_) async => stub),
          ],
        ),
      );
      await _goToDataPage(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
      await tester.pump(); // execute() resolves; clearDraft() invoked & gated

      // clearDraft has been invoked but is still pending on its gate —
      // navigation must not have happened yet.
      expect(notifier.clearDraftCallCount, equals(1));
      expect(find.text('calendar'), findsNothing);

      // Release clearDraft — only now should context.go('/calendar') fire.
      clearDraftGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('calendar'), findsOneWidget);
    });

    testWidgets(
        '_onSubmit: clearDraft failure is swallowed and navigation still '
        'proceeds', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final executeCompleter = Completer<void>()..complete();
      final stub = _StubCompleteOnboarding(completer: executeCompleter);
      final notifier = _StubOnboardingNotifier(
        seedDate: seedDate,
        clearDraftError: StateError('secure storage unavailable'),
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          overrides: [
            onboardingNotifierProvider.overrideWith(() => notifier),
            completeOnboardingProvider.overrideWith((_) async => stub),
          ],
        ),
      );
      await _goToDataPage(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'All set →'));
      await tester.pumpAndSettle();

      // clearDraft was attempted (and threw) but the failure must not
      // prevent navigation — defense in depth, matching
      // OnboardingNotifier.clearDraft's own never-rethrow contract.
      expect(notifier.clearDraftCallCount, equals(1));
      expect(find.text('calendar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── #27: _WelcomePage IT·EN language selector (Group H) ────────────────────

  group('OnboardingScreen — _WelcomePage language selector (Group H)', () {
    testWidgets(
        'renders SegmentedControlMetra(["IT","EN"]) via '
        'Positioned(top:8,right:12) in a Stack; hero Column is unchanged '
        'and does not overlap the selector', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Structural: SafeArea's direct child is a Stack; its first entry is
      // the (verbatim, unchanged) hero Column, and a Positioned(top:8,
      // right:12) entry wraps the selector.
      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      final stack = safeArea.child as Stack;
      expect(stack.children.first, isA<Column>());
      final positioned = stack.children.whereType<Positioned>().single;
      expect(positioned.top, 8);
      expect(positioned.right, 12);

      final segmented = tester.widget<SegmentedControlMetra>(
        find.byType(SegmentedControlMetra),
      );
      expect(segmented.segments, ['IT', 'EN']);

      // Geometric: the selector must not visually collide with the actual
      // hero content — the wordmark or the bottom-pinned CTA. (The
      // surrounding hero Column's own bounding box trivially fills the
      // entire page, because its content zone is `Expanded` — that rect is
      // not a meaningful non-overlap signal on its own.)
      final selectorRect = tester.getRect(find.byType(SegmentedControlMetra));
      final wordmarkRect = tester.getRect(find.byType(MetraWordmark));
      final ctaRect = tester.getRect(
        find.widgetWithText(FilledButton, 'Get started'),
      );
      expect(selectorRect.overlaps(wordmarkRect), isFalse);
      expect(selectorRect.overlaps(ctaRect), isFalse);
    });

    testWidgets("selectedIndex derives from settings.languageCode: 'it'→0",
        (tester) async {
      await tester.pumpWidget(
        _wrap(settings: _settingsWith(languageCode: 'it')),
      );
      await tester.pumpAndSettle();

      final segmented = tester.widget<SegmentedControlMetra>(
        find.byType(SegmentedControlMetra),
      );
      expect(segmented.selectedIndex, 0);
    });

    testWidgets("selectedIndex derives from settings.languageCode: 'en'→1",
        (tester) async {
      await tester.pumpWidget(
        _wrap(settings: _settingsWith(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      final segmented = tester.widget<SegmentedControlMetra>(
        find.byType(SegmentedControlMetra),
      );
      expect(segmented.selectedIndex, 1);
    });

    testWidgets(
        'selecting the OTHER language calls SettingsNotifier.save exactly '
        'once', (tester) async {
      final stub = _StubSettingsNotifier(_settingsWith(languageCode: 'it'));

      await tester.pumpWidget(
        _wrap(overrides: [settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      // FR-12 stacks an invisible, opaque hit-region over the visible pill
      // text by design — silence the benign "obscured" warning (see
      // SegmentedControlMetra's class doc-comment).
      await tester.tap(find.text('EN'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(stub.saveCallCount, 1);
      expect(stub.savedSettings?.languageCode, 'en');
    });

    testWidgets(
        'EC-15: selecting the ALREADY-ACTIVE language does not call save',
        (tester) async {
      final stub = _StubSettingsNotifier(_settingsWith(languageCode: 'it'));

      await tester.pumpWidget(
        _wrap(overrides: [settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('IT'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(stub.saveCallCount, 0);
    });

    testWidgets(
        "container Semantics(label) reads the localized 'Language' label "
        '(not the SegmentedControlMetra default "Vista")', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(SegmentedControlMetra));
      expect(semantics.label, 'Language');
    });

    testWidgets('each segment hit-region is >= 44x44 dp', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final hitRegions = find.descendant(
        of: find.byType(SegmentedControlMetra),
        matching: find.byType(GestureDetector),
      );
      expect(hitRegions, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final size = tester.getSize(hitRegions.at(i));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });
  });
}
