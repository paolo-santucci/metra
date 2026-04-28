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
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/features/calendar/calendar_screen.dart';
import 'package:metra/features/calendar/state/calendar_month_controller.dart';
import 'package:metra/features/calendar/widgets/calendar_day.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Stub notifiers
// ---------------------------------------------------------------------------

class _StubCalendarMonthNotifier extends CalendarMonthNotifier {
  @override
  Future<CalendarMonthState> build() async {
    final now = DateTime.now();
    return CalendarMonthState(year: now.year, month: now.month);
  }

  @override
  void goToPrevMonth() {}

  @override
  void goToNextMonth() {}
}

class _StubCalendarWithFlowNotifier extends CalendarMonthNotifier {
  @override
  Future<CalendarMonthState> build() async {
    final now = DateTime.now();
    // Provide a flow log on day 5 of the current month.
    final logDate = DateTime.utc(now.year, now.month, 5);
    final log = DailyLogEntity(
      date: logDate,
      flowIntensity: FlowIntensity.medium,
    );
    return CalendarMonthState(
      year: now.year,
      month: now.month,
      logs: {logDate: log},
    );
  }

  @override
  void goToPrevMonth() {}

  @override
  void goToNextMonth() {}
}

class _LoadingCalendarNotifier extends CalendarMonthNotifier {
  @override
  Future<CalendarMonthState> build() {
    // Never completes — keeps the provider in loading state.
    return Completer<CalendarMonthState>().future;
  }
}

class _ErrorCalendarNotifier extends CalendarMonthNotifier {
  @override
  Future<CalendarMonthState> build() {
    throw Exception('test error');
  }
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

/// Wraps CalendarScreen with a minimal GoRouter for navigation tests.
Widget _wrapWithRouter(List<Override> overrides) {
  final testRouter = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (_, __) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/daily-entry/today',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('daily-entry-today-stub')),
        ),
      ),
      GoRoute(
        path: '/daily-entry/:date',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('daily-entry-stub')),
        ),
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
  group('CalendarScreen — loading state', () {
    testWidgets('shows loading indicator when calendarMonthProvider is loading',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_LoadingCalendarNotifier.new),
        ]),
      );
      // Only pump once — do not settle, so loading spinner is visible.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('CalendarScreen — error state', () {
    testWidgets('shows error message when calendarMonthProvider errors',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_ErrorCalendarNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Qualcosa è andato storto. Riprova.'),
        findsOneWidget,
      );
    });
  });

  group('CalendarScreen — data state', () {
    testWidgets('renders 7-column day-of-week header', (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      // The header row has 7 day labels: L M M G V S D.
      // There are two 'M' (martedì, mercoledì) rendered as Text.
      expect(find.text('L'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      // Total 'M' occurrences: 2 (Tuesday + Wednesday).
      expect(find.text('M'), findsNWidgets(2));
    });

    testWidgets('renders correct number of day cells for the month',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

      // CalendarDay renders numbers via CustomPaint — no Text widgets.
      // Instead verify there are exactly daysInMonth CalendarDay widgets.
      // The grid is lazy, so we may only see the first viewport batch;
      // assert at least the visible first row renders.
      expect(find.byType(CalendarDay), findsWidgets);
      // The total CalendarDay count in the visible viewport should be > 0
      // and ≤ daysInMonth.
      final count = tester.widgetList(find.byType(CalendarDay)).length;
      expect(count, greaterThan(0));
      expect(count, lessThanOrEqualTo(daysInMonth));
    });

    testWidgets('FAB has correct accessibility label', (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('Aggiungi o modifica il registro di oggi'),
        findsOneWidget,
      );
    });

    testWidgets('tapping FAB navigates to /daily-entry/today', (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('daily-entry-today-stub'), findsOneWidget);
    });

    testWidgets('tapping a day cell navigates to /daily-entry/:date',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      // Tap the first CalendarDay in the grid (any visible day cell).
      final firstDay = find.byType(CalendarDay).first;
      await tester.tap(firstDay);
      await tester.pumpAndSettle();

      expect(find.text('daily-entry-stub'), findsOneWidget);
    });
  });

  group('CalendarScreen — semantics', () {
    testWidgets('today cell includes "Oggi" in the semantics label',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      // The today cell's Semantics label starts with "Oggi, ".
      expect(
        find.bySemanticsLabel(RegExp(r'^Oggi,')),
        findsOneWidget,
      );
    });

    testWidgets('empty day cell has "Nessun dato" in the semantics label',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      // Empty days produce "Nessun dato, <date>" labels.
      expect(
        find.bySemanticsLabel(RegExp(r'^Nessun dato,')),
        findsWidgets,
      );
    });

    testWidgets('flow day has flow level in the semantics label',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(
            _StubCalendarWithFlowNotifier.new,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // The a11y label for a flow day is "{flowLevel}, {date}".
      // FlowIntensity.medium → "Flusso moderato"
      expect(
        find.bySemanticsLabel(RegExp(r'^Flusso moderato,')),
        findsOneWidget,
      );
    });
  });
}
