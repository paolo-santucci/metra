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
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/features/calendar/calendar_screen.dart';
import 'package:metra/features/calendar/state/calendar_month_controller.dart';
import 'package:metra/features/calendar/state/prediction_controller.dart';
import 'package:metra/features/calendar/widgets/calendar_day.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/repository_providers.dart';

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
      flowType: FlowType.mestruazioni,
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

class _StubCalendarMonthNotifierForYear extends CalendarMonthNotifier {
  _StubCalendarMonthNotifierForYear({required this.year, required this.month});
  final int year;
  final int month;

  @override
  Future<CalendarMonthState> build() async =>
      CalendarMonthState(year: year, month: month);

  @override
  void goToPrevMonth() {}

  @override
  void goToNextMonth() {}
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

/// Wraps CalendarScreen with a minimal GoRouter for navigation tests.
///
/// Always overrides [cyclePredictionProvider] with a no-DB stub so widget
/// tests do not attempt database access. Pass an explicit prediction override
/// in [overrides] to replace the default null stub.
Widget _wrapWithRouter(
  List<Override> overrides, {
  CyclePrediction? prediction,
}) {
  final testRouter = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (_, __) => const CalendarScreen(),
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
    overrides: [
      // Default: no prediction (null) — prevents DB access in widget tests.
      cyclePredictionProvider.overrideWith(
        (ref) => Stream.value(prediction),
      ),
      // Prevent DB access — no symptoms in widget tests by default.
      painSymptomsProvider.overrideWith((ref, date) async => []),
      ...overrides,
    ],
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

    testWidgets('day-detail card is visible on initial load (today selected)',
        (tester) async {
      // SliverFillRemaining needs extra vertical space beyond the calendar grid.
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      // The stub has no logs, so the card shows "Nessun dato registrato"
      // and "Aggiungi giornata" (not "Modifica giornata" — no prior entry).
      expect(find.text('Nessun dato registrato'), findsOneWidget);
      expect(find.text('Aggiungi giornata'), findsOneWidget);
    });

    testWidgets('tapping a day cell shows the day-detail card', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      // Tap the first CalendarDay in the grid — selects it and shows the card.
      final firstDay = find.byType(CalendarDay).first;
      await tester.tap(firstDay);
      await tester.pumpAndSettle();

      // Detail card is visible: the stub has no logs so "Nessun dato registrato"
      // and "Aggiungi giornata" (no prior entry) must both appear.
      expect(find.text('Nessun dato registrato'), findsOneWidget);
      expect(find.text('Aggiungi giornata'), findsOneWidget);
    });

    testWidgets('tapping the day-card CTA navigates to /daily-entry/:date',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      // First tap: select a day to reveal the detail card.
      final firstDay = find.byType(CalendarDay).first;
      await tester.tap(firstDay);
      await tester.pumpAndSettle();

      // Second tap: stub has no logs so the CTA reads "Aggiungi giornata".
      await tester.tap(find.text('Aggiungi giornata'));
      await tester.pumpAndSettle();

      expect(find.text('daily-entry-stub'), findsOneWidget);
    });
  });

  group('CalendarScreen — future date read-only', () {
    testWidgets('future day cells have isFuture true', (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();
      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);

      for (final day in days) {
        if (day.date.isAfter(todayUtc)) {
          expect(
            day.isFuture,
            isTrue,
            reason: 'day ${day.date.day} is after today and must have isFuture',
          );
        } else {
          expect(
            day.isFuture,
            isFalse,
            reason:
                'day ${day.date.day} is today or past and must not have isFuture',
          );
        }
      }
    });

    testWidgets(
        'tapping a future cell does not change the selected date in the detail card',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      // The initial detail card shows today — grab today's date label.
      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);
      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();
      final futureDays = days.where((d) => d.date.isAfter(todayUtc)).toList();

      // Only run this assertion when the current month has future days
      // (always true if today is not the last day of the month).
      if (futureDays.isEmpty) return;

      // Record how many CTA buttons are visible before the tap.
      // Stub has no logs so the label will be "Aggiungi giornata".
      int _ctaCount(WidgetTester t) =>
          t.widgetList(find.text('Aggiungi giornata')).length +
          t.widgetList(find.text('Modifica giornata')).length;
      final editButtonsBefore = _ctaCount(tester);

      // Attempt to tap the first future cell.
      await tester.tap(
        find.byWidget(futureDays.first),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // CTA count must not have changed — future date blocks the button.
      expect(_ctaCount(tester), equals(editButtonsBefore));
    });

    testWidgets('CTA is visible when selected date is today (no future guard)',
        (tester) async {
      // Today is not in the future — CTA must be visible ("Aggiungi giornata"
      // since the stub has no existing log for today).
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(_StubCalendarMonthNotifier.new),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aggiungi giornata'), findsOneWidget);
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

  group('CalendarScreen prediction window', () {
    // Build a future month (+2 months from today) so the prediction window
    // is always in the future, making these tests immune to calendar drift.
    DateTime futureWindowDate(int offsetDays) {
      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);
      return todayUtc.add(Duration(days: offsetDays));
    }

    testWidgets('days inside prediction window have hasPrediction true',
        (tester) async {
      // Anchor the prediction window 60 days from today so it is always future.
      final windowStart = futureWindowDate(58);
      final expectedStart = futureWindowDate(60);
      final windowEnd = futureWindowDate(62);
      final prediction = CyclePrediction(
        windowStart: windowStart,
        windowEnd: windowEnd,
        expectedStart: expectedStart,
        cyclesUsed: 3,
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          [
            calendarMonthProvider.overrideWith(
              () => _StubCalendarMonthNotifierForYear(
                year: expectedStart.year,
                month: expectedStart.month,
              ),
            ),
          ],
          prediction: prediction,
        ),
      );
      await tester.pumpAndSettle();

      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();

      // The expectedStart day is inside the window — hasPrediction must be true.
      final dayInWindow =
          days.firstWhere((d) => d.date.day == expectedStart.day);
      expect(dayInWindow.hasPrediction, isTrue);

      // A day clearly outside the window: windowEnd + 3 days (guaranteed to
      // be > windowEnd.day; if it overflows to the next month, skip the check).
      final outsideDate = windowEnd.add(const Duration(days: 3));
      if (outsideDate.month == expectedStart.month) {
        final dayOutside =
            days.firstWhere((d) => d.date.day == outsideDate.day);
        expect(dayOutside.hasPrediction, isFalse);
      }
    });

    testWidgets('days outside prediction window have hasPrediction false',
        (tester) async {
      final windowStart = futureWindowDate(58);
      final expectedStart = futureWindowDate(60);
      final windowEnd = futureWindowDate(62);
      final prediction = CyclePrediction(
        windowStart: windowStart,
        windowEnd: windowEnd,
        expectedStart: expectedStart,
        cyclesUsed: 3,
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          [
            calendarMonthProvider.overrideWith(
              () => _StubCalendarMonthNotifierForYear(
                year: expectedStart.year,
                month: expectedStart.month,
              ),
            ),
          ],
          prediction: prediction,
        ),
      );
      await tester.pumpAndSettle();

      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();

      for (final day in days) {
        final inWindow =
            !day.date.isBefore(windowStart) && !day.date.isAfter(windowEnd);
        if (!inWindow) {
          expect(
            day.hasPrediction,
            isFalse,
            reason: 'day ${day.date.day} should not be in prediction window',
          );
        }
      }
    });

    testWidgets(
        'prediction window day with no log emits prediction semantics label',
        (tester) async {
      final windowStart = futureWindowDate(58);
      final expectedStart = futureWindowDate(60);
      final windowEnd = futureWindowDate(62);
      final prediction = CyclePrediction(
        windowStart: windowStart,
        windowEnd: windowEnd,
        expectedStart: expectedStart,
        cyclesUsed: 3,
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          [
            calendarMonthProvider.overrideWith(
              () => _StubCalendarMonthNotifierForYear(
                year: expectedStart.year,
                month: expectedStart.month,
              ),
            ),
          ],
          prediction: prediction,
        ),
      );
      await tester.pumpAndSettle();

      // Days in the future window have no log and hasPrediction = true →
      // semantics label must start with "Ciclo previsto,".
      expect(
        find.bySemanticsLabel(RegExp(r'^Ciclo previsto,')),
        findsWidgets,
      );
    });

    testWidgets('when prediction is null no day has hasPrediction true',
        (tester) async {
      final futureMonth = futureWindowDate(60);
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(
            () => _StubCalendarMonthNotifierForYear(
              year: futureMonth.year,
              month: futureMonth.month,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();

      for (final day in days) {
        expect(
          day.hasPrediction,
          isFalse,
          reason: 'no prediction set — day ${day.date.day} must be false',
        );
      }
    });

    testWidgets(
        'elapsed prediction window does not paint prediction outline on past cells',
        (tester) async {
      // Regression test: stale data scenario where the prediction window
      // has already passed (windowEnd < today). No past cell should show
      // the prediction outline, regardless of containsDate returning true.
      final now = DateTime.now();
      final pastBase = DateTime.utc(now.year, now.month, now.day)
          .subtract(const Duration(days: 60));
      final pastWindowStart =
          DateTime.utc(pastBase.year, pastBase.month, pastBase.day - 2);
      final pastExpectedStart =
          DateTime.utc(pastBase.year, pastBase.month, pastBase.day);
      final pastWindowEnd =
          DateTime.utc(pastBase.year, pastBase.month, pastBase.day + 2);
      final stalePrediction = CyclePrediction(
        windowStart: pastWindowStart,
        windowEnd: pastWindowEnd,
        expectedStart: pastExpectedStart,
        cyclesUsed: 3,
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          [
            calendarMonthProvider.overrideWith(
              () => _StubCalendarMonthNotifierForYear(
                year: pastExpectedStart.year,
                month: pastExpectedStart.month,
              ),
            ),
          ],
          prediction: stalePrediction,
        ),
      );
      await tester.pumpAndSettle();

      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();

      // Every cell in the past month must have hasPrediction false — the
      // elapsed window must not paint a prediction outline on past cells.
      for (final day in days) {
        expect(
          day.hasPrediction,
          isFalse,
          reason:
              'day ${day.date} is in an elapsed prediction window and must not show prediction outline',
        );
      }

      // No "Ciclo previsto" semantics label should appear for the past window.
      expect(
        find.bySemanticsLabel(RegExp(r'^Ciclo previsto,')),
        findsNothing,
      );
    });
  });
}
