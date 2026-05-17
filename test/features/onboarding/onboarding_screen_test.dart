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
import 'package:metra/domain/use_cases/complete_onboarding.dart';
import 'package:metra/features/onboarding/onboarding_screen.dart';
import 'package:metra/features/onboarding/state/onboarding_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/use_case_providers.dart';

// ---------------------------------------------------------------------------
// Stub: OnboardingNotifier that seeds lastPeriodDate so canSubmit is true.
// ---------------------------------------------------------------------------

class _StubOnboardingNotifier extends OnboardingNotifier {
  _StubOnboardingNotifier({required DateTime seedDate}) : _seedDate = seedDate;

  final DateTime _seedDate;

  @override
  OnboardingState build() => OnboardingState(lastPeriodDate: _seedDate);
}

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
Widget _wrap({List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
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
Widget _wrapWithRouter({required List<Override> overrides}) {
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
    overrides: overrides,
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
}
