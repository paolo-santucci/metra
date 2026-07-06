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
import 'package:intl/intl.dart' as intl;
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/features/calendar/calendar_screen.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';
import 'package:metra/features/calendar/state/calendar_month_controller.dart';
import 'package:metra/features/calendar/state/prediction_controller.dart';
import 'package:metra/features/calendar/widgets/calendar_day.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/calendar_focus_provider.dart';
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
    // Provide a flow log on day 5 of the current month — but never on today:
    // the today cell prepends "Oggi, " to its semantics label, which would
    // break the '^Flusso moderato,' anchor whenever the 5th is today.
    final day = now.day == 5 ? 6 : 5;
    final logDate = DateTime.utc(now.year, now.month, day);
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

/// Navigable stub: `goToPrevMonth` / `goToNextMonth` actually transition state
/// so that [CalendarScreen]'s navigation callbacks can be exercised.
class _NavigableCalendarMonthNotifier extends CalendarMonthNotifier {
  _NavigableCalendarMonthNotifier({
    required this.initialYear,
    required this.initialMonth,
  });

  final int initialYear;
  final int initialMonth;

  @override
  Future<CalendarMonthState> build() async =>
      CalendarMonthState(year: initialYear, month: initialMonth);

  @override
  void goToPrevMonth() {
    final current = state.requireValue;
    final prevMonth = current.month == 1 ? 12 : current.month - 1;
    final prevYear = current.month == 1 ? current.year - 1 : current.year;
    state = AsyncData(CalendarMonthState(year: prevYear, month: prevMonth));
  }

  @override
  void goToNextMonth() {
    final current = state.requireValue;
    final nextMonth = current.month == 12 ? 1 : current.month + 1;
    final nextYear = current.month == 12 ? current.year + 1 : current.year;
    state = AsyncData(CalendarMonthState(year: nextYear, month: nextMonth));
  }
}

/// Stub notifier for TASK-10 focus-consumption tests (#3): `goToMonth` sets
/// `AsyncData` directly (mirrors production `CalendarMonthNotifier.goToMonth`'s
/// synchronous-first shape without touching real repositories/DB).
/// `goToPrevMonth`/`goToNextMonth` are also functional (mirrors
/// [_NavigableCalendarMonthNotifier]) so EC-04 can prove a manual nav
/// performed after focus-consumption survives an unrelated rebuild.
///
/// `build()` deliberately never completes (like
/// [_LoadingThenFocusableCalendarMonthNotifier]) rather than using an
/// `async => value` shorthand: `_applyFocus()` runs from a post-frame
/// callback fired in the *same* initial frame as this notifier's own
/// `build()`, so an `async`-shorthand build() — which Dart still defers to a
/// microtask even with no real `await` — can resolve *after* `goToMonth()`
/// and silently clobber the state back to the pre-focus value. Production
/// `CalendarMonthNotifier` avoids this because `goToMonth`/relative-nav
/// methods always cancel the previous subscription first, so the original
/// `build()` future can never complete once a jump has happened; a
/// never-completing stub reproduces that same guarantee without touching
/// real repositories.
class _FocusableCalendarMonthNotifier extends CalendarMonthNotifier {
  @override
  Future<CalendarMonthState> build() => Completer<CalendarMonthState>().future;

  @override
  void goToMonth(int year, int month) {
    state = AsyncData(CalendarMonthState(year: year, month: month));
  }

  @override
  void goToPrevMonth() {
    final current = state.requireValue;
    final prevMonth = current.month == 1 ? 12 : current.month - 1;
    final prevYear = current.month == 1 ? current.year - 1 : current.year;
    state = AsyncData(CalendarMonthState(year: prevYear, month: prevMonth));
  }

  @override
  void goToNextMonth() {
    final current = state.requireValue;
    final nextMonth = current.month == 12 ? 1 : current.month + 1;
    final nextYear = current.month == 12 ? current.year + 1 : current.year;
    state = AsyncData(CalendarMonthState(year: nextYear, month: nextMonth));
  }
}

/// Stub notifier for EC-02: `build()` never completes (stays `AsyncLoading`)
/// until `goToMonth` is called — mirrors production `goToMonth`'s contract of
/// NOT early-returning on unloaded state, without touching real repositories.
class _LoadingThenFocusableCalendarMonthNotifier extends CalendarMonthNotifier {
  @override
  Future<CalendarMonthState> build() {
    return Completer<CalendarMonthState>().future;
  }

  @override
  void goToMonth(int year, int month) {
    state = AsyncData(CalendarMonthState(year: year, month: month));
  }
}

/// Stub notifier for EC-05: `goToMonth` sets `AsyncData` synchronously (like
/// production), then asynchronously resolves to `AsyncError` — simulating a
/// subscription failure that arrives after the jump. Because `_applyFocus`
/// clears the pending request synchronously before this error arrives, the
/// error must not trigger a retry / re-consumption. `build()` never completes
/// — same rationale as [_FocusableCalendarMonthNotifier] above.
class _ErrorAfterGoToMonthNotifier extends CalendarMonthNotifier {
  @override
  Future<CalendarMonthState> build() => Completer<CalendarMonthState>().future;

  @override
  void goToMonth(int year, int month) {
    state = AsyncData(CalendarMonthState(year: year, month: month));
    Future<void>.delayed(Duration.zero, () {
      state = AsyncError(
        Exception('test subscription error'),
        StackTrace.current,
      );
    });
  }
}

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._initial);

  final AppSettingsData _initial;

  @override
  Future<AppSettingsData> build() async => _initial;
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
      // Default: system first-day-of-week (Monday in Italian locale).
      // Prevents DB access in widget tests; override per-test for specific cases.
      settingsNotifierProvider.overrideWith(
        () => _StubSettingsNotifier(AppSettingsData.defaults()),
      ),
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

/// Wraps [CalendarScreen] with a caller-supplied [ProviderContainer] instead
/// of letting `ProviderScope` build its own — needed by the TASK-10 focus
/// tests so they can pre-seed `calendarFocusRequestProvider` (via
/// `container.read(...).notifier.request(...)`) BEFORE the first pump.
/// Mirrors [_wrapWithRouter]'s router/MaterialApp shape.
Widget _wrapWithContainer(ProviderContainer container) {
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

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: testRouter,
    ),
  );
}

/// Common non-DB-touching overrides shared by every TASK-10 focus test.
/// [settings] lets EC-04 supply a settings-notifier factory whose instance
/// it can capture (to force an unrelated rebuild later).
List<Override> _focusTestBaseOverrides({
  SettingsNotifier Function()? settings,
}) =>
    [
      cyclePredictionProvider.overrideWith((ref) => Stream.value(null)),
      painSymptomsProvider.overrideWith((ref, date) async => []),
      settingsNotifierProvider.overrideWith(
        settings ?? () => _StubSettingsNotifier(AppSettingsData.defaults()),
      ),
    ];

/// Two months before "now", pinned to day 12 (exists in every month) — always
/// distinct from the notifier's initial month, immune to calendar drift.
DateTime _targetFocusDate() {
  final now = DateTime.now();
  var year = now.year;
  var month = now.month - 2;
  if (month < 1) {
    month += 12;
    year -= 1;
  }
  return DateTime.utc(year, month, 12);
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
      int ctaCount(WidgetTester t) =>
          t.widgetList(find.text('Aggiungi giornata')).length +
          t.widgetList(find.text('Modifica giornata')).length;
      final editButtonsBefore = ctaCount(tester);

      // Attempt to tap the first future cell.
      await tester.tap(
        find.byWidget(futureDays.first),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // CTA count must not have changed — future date blocks the button.
      expect(ctaCount(tester), equals(editButtonsBefore));
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
        'elapsed prediction window DOES paint prediction outline on past cells (BUG-P4)',
        (tester) async {
      // BUG-P4 fix: the !date.isBefore(todayUtc) guard was removed from
      // hasPrediction. Past cells inside the prediction window now render the
      // prediction dot so overdue users see why the Today card shows 'X days late'.
      // This test was updated from the pre-fix assertion (hasPrediction=false for
      // all past cells) to the correct post-fix assertion (hasPrediction=true for
      // cells inside the window).
      final now = DateTime.now();
      final pastBase = DateTime.utc(now.year, now.month, now.day)
          .subtract(const Duration(days: 60));
      final pastWindowStart = pastBase.subtract(const Duration(days: 2));
      final pastExpectedStart = pastBase;
      final pastWindowEnd = pastBase.add(const Duration(days: 2));
      final pastPrediction = CyclePrediction(
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
          prediction: pastPrediction,
        ),
      );
      await tester.pumpAndSettle();

      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();

      // Cells inside the past window must have hasPrediction=true (post-fix
      // behaviour). Cells outside must have hasPrediction=false.
      for (final day in days) {
        final inWindow = !day.date.isBefore(pastWindowStart) &&
            !day.date.isAfter(pastWindowEnd);
        if (inWindow) {
          expect(
            day.hasPrediction,
            isTrue,
            reason:
                'day ${day.date} is inside the elapsed prediction window and must have hasPrediction=true (BUG-P4)',
          );
        } else {
          expect(
            day.hasPrediction,
            isFalse,
            reason:
                'day ${day.date} is outside the prediction window and must have hasPrediction=false',
          );
        }
      }

      // "Ciclo previsto" semantics labels must appear for cells in the past window.
      expect(
        find.bySemanticsLabel(RegExp(r'^Ciclo previsto,')),
        findsWidgets,
      );
    });
  });

  group('CalendarScreen — first day of week', () {
    // March 2026 starts on Sunday (DateTime(2026,3,1).weekday == 7).
    // This makes it a clear test case:
    //   monday-first: 6 leading blanks → day 1 is at column 6 (far right)
    //   sunday-first: 0 leading blanks → day 1 is at column 0 (far left)

    testWidgets('monday-first: day headers include L as first letter (IT)',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(
            () => _StubCalendarMonthNotifierForYear(year: 2026, month: 3),
          ),
          settingsNotifierProvider.overrideWith(
            () => _StubSettingsNotifier(
              AppSettingsData.defaults().copyWith(
                firstDayOfWeek: FirstDayOfWeekSetting.monday,
              ),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // Italian Monday-first: L M M G V S D — 'L' (lunedì) is the first header.
      expect(find.text('L'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets(
        'sunday-first: March 2026 day 1 is in leftmost column (no leading blanks)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(
            () => _StubCalendarMonthNotifierForYear(year: 2026, month: 3),
          ),
          settingsNotifierProvider.overrideWith(
            () => _StubSettingsNotifier(
              AppSettingsData.defaults().copyWith(
                firstDayOfWeek: FirstDayOfWeekSetting.sunday,
              ),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // With sunday-first + March 2026 (starts Sunday): 0 leading blanks.
      // The first CalendarDay in the viewport is March 1st and it occupies
      // the leftmost column. Its left edge (dx) should be close to the grid's
      // left padding (MetraSpacing.s3 = 12 px).
      final day1 = find.byWidgetPredicate(
        (w) => w is CalendarDay && w.date == DateTime.utc(2026, 3, 1),
      );
      expect(day1, findsOneWidget);

      // Column 0 → left edge < 100 dp.
      final dx = tester.getTopLeft(day1).dx;
      expect(
        dx,
        lessThan(100),
        reason:
            'Day 1 of March 2026 with sunday-first should be at column 0 (left edge < 100 dp), got $dx',
      );
    });

    testWidgets(
        'monday-first: March 2026 day 1 is in rightmost column (6 leading blanks)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(
            () => _StubCalendarMonthNotifierForYear(year: 2026, month: 3),
          ),
          settingsNotifierProvider.overrideWith(
            () => _StubSettingsNotifier(
              AppSettingsData.defaults().copyWith(
                firstDayOfWeek: FirstDayOfWeekSetting.monday,
              ),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // With monday-first + March 2026 (starts Sunday = weekday 7):
      // leadingBlanks = (7 - 1 + 7) % 7 = 6 → day 1 is at column 6 (rightmost).
      final day1 = find.byWidgetPredicate(
        (w) => w is CalendarDay && w.date == DateTime.utc(2026, 3, 1),
      );
      expect(day1, findsOneWidget);

      // Column 6 (rightmost) → left edge > 500 dp on a 700 dp surface.
      final dx = tester.getTopLeft(day1).dx;
      expect(
        dx,
        greaterThan(500),
        reason:
            'Day 1 of March 2026 with monday-first should be at column 6 (left edge > 500 dp), got $dx',
      );
    });

    testWidgets(
        'changing setting from monday to sunday re-renders grid (day 1 moves)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late _StubSettingsNotifier stub;

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(
            () => _StubCalendarMonthNotifierForYear(year: 2026, month: 3),
          ),
          settingsNotifierProvider.overrideWith(() {
            stub = _StubSettingsNotifier(
              AppSettingsData.defaults().copyWith(
                firstDayOfWeek: FirstDayOfWeekSetting.monday,
              ),
            );
            return stub;
          }),
        ]),
      );
      await tester.pumpAndSettle();

      final day1Monday = find.byWidgetPredicate(
        (w) => w is CalendarDay && w.date == DateTime.utc(2026, 3, 1),
      );
      final dxMonday = tester.getTopLeft(day1Monday).dx;

      // Switch to sunday-first.
      stub.state = AsyncData(
        AppSettingsData.defaults()
            .copyWith(firstDayOfWeek: FirstDayOfWeekSetting.sunday),
      );
      await tester.pumpAndSettle();

      final day1Sunday = find.byWidgetPredicate(
        (w) => w is CalendarDay && w.date == DateTime.utc(2026, 3, 1),
      );
      final dxSunday = tester.getTopLeft(day1Sunday).dx;

      expect(
        dxSunday,
        lessThan(dxMonday),
        reason:
            'Day 1 should shift left when switching from monday-first to sunday-first',
      );
    });
  });

  group('CalendarScreen — month navigation syncs selected date', () {
    testWidgets(
        'navigating to the previous month updates detail card to that month',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      final prevYear = now.month == 1 ? now.year - 1 : now.year;

      // Lowercase month names used by intl/DateFormat in Italian locale.
      final currentMonthName =
          intl.DateFormat('MMMM', 'it').format(DateTime(now.year, now.month));
      final prevMonthName =
          intl.DateFormat('MMMM', 'it').format(DateTime(prevYear, prevMonth));

      await tester.pumpWidget(
        _wrapWithRouter([
          calendarMonthProvider.overrideWith(
            () => _NavigableCalendarMonthNotifier(
              initialYear: now.year,
              initialMonth: now.month,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // Initially the detail card shows today's month.
      expect(
        find.textContaining(currentMonthName),
        findsOneWidget,
        reason: 'Detail card must show current month before navigation',
      );

      // Tap the prev chevron.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // After navigating back the detail card must show the previous month.
      expect(
        find.textContaining(prevMonthName),
        findsOneWidget,
        reason:
            'Detail card must show previous-month date after navigating back',
      );
      // Current month must no longer appear in the detail card title.
      // Header title is capitalised ("Maggio 2026"), detail card uses lowercase
      // ("10 maggio") — textContaining is case-sensitive, so only the detail
      // card label matches the lowercase currentMonthName.
      expect(
        find.textContaining(currentMonthName),
        findsNothing,
        reason:
            'Current month must not appear in detail card after navigating back',
      );
    });
  });

  group('CalendarScreen — pending focus request (#3, TASK-10)', () {
    testWidgets(
        'jumps to target month and selects target day; clears the request',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final target = _targetFocusDate();

      final container = ProviderContainer(
        overrides: [
          ..._focusTestBaseOverrides(),
          calendarMonthProvider
              .overrideWith(_FocusableCalendarMonthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      // Seed the pending request BEFORE the widget is pumped — mirrors a
      // Timeline card tap that happened before navigating to /calendar.
      container.read(calendarFocusRequestProvider.notifier).request(target);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      // Month header shows the target month/year (Bible § 8.1: "Month Year").
      final rawMonth = intl.DateFormat.MMMM('it')
          .format(DateTime(target.year, target.month));
      final title =
          '${rawMonth.substring(0, 1).toUpperCase()}${rawMonth.substring(1)} ${target.year}';
      expect(find.text(title), findsOneWidget);

      // The target day cell is rendered and in the Selected state
      // (ui-design-bible § 8.3.1).
      final targetDay = find.byWidgetPredicate(
        (w) => w is CalendarDay && w.date == target,
      );
      expect(targetDay, findsOneWidget);
      expect(tester.widget<CalendarDay>(targetDay).isSelected, isTrue);

      // The request is consumed — reading it again yields null.
      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    testWidgets(
        'EC-02: applies focus even while calendarMonthProvider is AsyncLoading',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final target = _targetFocusDate();

      final container = ProviderContainer(
        overrides: [
          ..._focusTestBaseOverrides(),
          calendarMonthProvider.overrideWith(
            _LoadingThenFocusableCalendarMonthNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(calendarFocusRequestProvider.notifier).request(target);

      await tester.pumpWidget(_wrapWithContainer(container));
      // First frame: calendarMonthProvider is still AsyncLoading (spinner).
      // Settle to let the post-frame callbacks apply the focus and flip the
      // provider to AsyncData — this must NOT no-op just because the
      // provider was loading (unlike goToPrevMonth/goToNextMonth).
      await tester.pumpAndSettle();

      final monthState = container.read(calendarMonthProvider).valueOrNull;
      expect(monthState?.year, equals(target.year));
      expect(monthState?.month, equals(target.month));

      // The grid replaced the loading spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    testWidgets(
        'EC-04: after consume+clear, a forced rebuild does not re-apply '
        'focus; a manual month nav in between is preserved', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final target = _targetFocusDate();
      late _StubSettingsNotifier settingsStub;

      final container = ProviderContainer(
        overrides: [
          ..._focusTestBaseOverrides(
            settings: () {
              settingsStub = _StubSettingsNotifier(AppSettingsData.defaults());
              return settingsStub;
            },
          ),
          calendarMonthProvider
              .overrideWith(_FocusableCalendarMonthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      container.read(calendarFocusRequestProvider.notifier).request(target);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      // Sanity: focus applied, request cleared.
      expect(container.read(calendarFocusRequestProvider), isNull);
      final monthAfterFocus = container.read(calendarMonthProvider).valueOrNull;
      expect(monthAfterFocus?.year, equals(target.year));
      expect(monthAfterFocus?.month, equals(target.month));

      // Manual nav away from the focused month.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      final expectedNextMonth = target.month == 12 ? 1 : target.month + 1;
      final expectedNextYear =
          target.month == 12 ? target.year + 1 : target.year;
      final monthAfterNav = container.read(calendarMonthProvider).valueOrNull;
      expect(monthAfterNav?.year, equals(expectedNextYear));
      expect(monthAfterNav?.month, equals(expectedNextMonth));

      // Force a CalendarScreen rebuild unrelated to the focus request:
      // mutating an unrelated watched provider re-runs build() (and
      // re-registers ref.listen) WITHOUT re-running initState — the same
      // State object survives, mirroring a StatefulShellRoute-style rebuild.
      settingsStub.state = AsyncData(
        AppSettingsData.defaults()
            .copyWith(firstDayOfWeek: FirstDayOfWeekSetting.sunday),
      );
      await tester.pumpAndSettle();

      // No second goToMonth: the manually-navigated month must be preserved,
      // NOT reverted back to `target`.
      final monthAfterRebuild =
          container.read(calendarMonthProvider).valueOrNull;
      expect(monthAfterRebuild?.year, equals(expectedNextYear));
      expect(monthAfterRebuild?.month, equals(expectedNextMonth));
      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    testWidgets(
        'EC-05: subscription error after the jump renders the generic error '
        'state; request stays cleared (no retry storm)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final target = _targetFocusDate();

      final container = ProviderContainer(
        overrides: [
          ..._focusTestBaseOverrides(),
          calendarMonthProvider.overrideWith(_ErrorAfterGoToMonthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      container.read(calendarFocusRequestProvider.notifier).request(target);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      // The generic error state is shown once the subscription resolves to
      // AsyncError.
      expect(
        find.text('Qualcosa è andato storto. Riprova.'),
        findsOneWidget,
      );

      // The request was already cleared by _applyFocus before the error
      // arrived — no stuck pending focus, no retry storm.
      expect(container.read(calendarFocusRequestProvider), isNull);
    });
  });
}
