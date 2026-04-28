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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/features/daily_entry/quick_entry_modal.dart';
import 'package:metra/features/daily_entry/state/daily_entry_controller.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake notifiers — must extend DailyEntryNotifier to satisfy overrideWith type.
// ---------------------------------------------------------------------------

/// Fake that captures save() calls and optionally fails.
class _FakeDailyEntryNotifier extends DailyEntryNotifier {
  DailyLogEntity? lastSaved;
  bool failOnSave = false;

  @override
  Future<DailyLogEntity?> build(DateTime arg) async => null;

  @override
  Future<void> save(DailyLogEntity log) async {
    if (failOnSave) {
      state = AsyncError(
        const ValidationException('forced test error'),
        StackTrace.current,
      );
      return;
    }
    lastSaved = log;
    state = AsyncData(log);
  }

  @override
  Future<void> delete() async {}
}

/// Fake that stays loading indefinitely.
class _LoadingDailyEntryNotifier extends DailyEntryNotifier {
  @override
  Future<DailyLogEntity?> build(DateTime arg) =>
      Completer<DailyLogEntity?>().future; // never resolves
}

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

/// Builds a GoRouter that starts at /calendar, then pushes /daily-entry/today
/// on top, so context.pop() in QuickEntryModal has somewhere to return to.
Widget _wrapWithRouter(List<Override> overrides) {
  final testRouter = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (_, __) => Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => ctx.push('/daily-entry/today'),
              child: const Text('open-modal'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/daily-entry/today',
        builder: (_, __) => const QuickEntryModal(),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: testRouter,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('QuickEntryModal', () {
    testWidgets('renders flow picker and save button', (tester) async {
      final fakeNotifier = _FakeDailyEntryNotifier();

      await tester.pumpWidget(
        _wrapWithRouter([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
        ]),
      );
      await tester.pumpAndSettle();
      // Navigate to the modal.
      await tester.tap(find.text('open-modal'));
      await tester.pumpAndSettle();

      // FlowIntensityPicker section label.
      expect(find.text('Flusso'), findsOneWidget);
      // Save button.
      expect(find.text('Salva'), findsOneWidget);
    });

    testWidgets('tapping a flow chip then Salva calls save() with correct flow',
        (tester) async {
      final fakeNotifier = _FakeDailyEntryNotifier();

      await tester.pumpWidget(
        _wrapWithRouter([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-modal'));
      await tester.pumpAndSettle();

      // Select "Flusso leggero".
      await tester.tap(find.text('Flusso leggero'));
      await tester.pumpAndSettle();

      // Tap save.
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastSaved, isNotNull);
      expect(
        fakeNotifier.lastSaved!.flowIntensity,
        equals(FlowIntensity.light),
      );
    });

    testWidgets('shows loading indicator while log is loading', (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          dailyEntryProvider.overrideWith(_LoadingDailyEntryNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-modal'));
      // Pump through the GoRouter navigation transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The loading notifier never resolves, so the modal is in loading state.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error snackbar when save fails', (tester) async {
      final fakeNotifier = _FakeDailyEntryNotifier()..failOnSave = true;

      await tester.pumpWidget(
        _wrapWithRouter([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      // The snackbar shows the generic error text; it may also appear in the
      // screen's error state — use findsWidgets to accept one or more instances.
      expect(
        find.text('Qualcosa è andato storto. Riprova.'),
        findsWidgets,
      );
    });
  });
}
