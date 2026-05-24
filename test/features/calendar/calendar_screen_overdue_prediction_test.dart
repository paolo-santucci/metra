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

// T-D tests for BUG-P4: verify that the !date.isBefore(todayUtc) guard
// has been removed from hasPrediction in calendar_screen.dart so that
// past prediction-window dates render the prediction dot for overdue users.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/features/calendar/calendar_screen.dart';
import 'package:metra/features/calendar/state/calendar_month_controller.dart';
import 'package:metra/features/calendar/state/prediction_controller.dart';
import 'package:metra/features/calendar/widgets/calendar_day.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/repository_providers.dart';

// ---------------------------------------------------------------------------
// Stub notifiers (replicated from calendar_screen_test.dart — private scope)
// ---------------------------------------------------------------------------

/// Stub that pins to a specific year/month and optionally seeds logs.
class _StubCalendarForMonth extends CalendarMonthNotifier {
  _StubCalendarForMonth({
    required this.year,
    required this.month,
    this.logs = const {},
  });

  final int year;
  final int month;
  final Map<DateTime, DailyLogEntity> logs;

  @override
  Future<CalendarMonthState> build() async =>
      CalendarMonthState(year: year, month: month, logs: logs);

  @override
  void goToPrevMonth() {}

  @override
  void goToNextMonth() {}
}

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._initial);

  final AppSettingsData _initial;

  @override
  Future<AppSettingsData> build() async => _initial;
}

// ---------------------------------------------------------------------------
// Helper: build the widget under test
// ---------------------------------------------------------------------------

/// Wraps CalendarScreen with a minimal GoRouter + ProviderScope.
///
/// Always overrides [cyclePredictionProvider] (defaulting to null) and
/// [painSymptomsProvider] (no symptoms) so the widget makes no DB calls.
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
      cyclePredictionProvider.overrideWith(
        (ref) => Stream.value(prediction),
      ),
      painSymptomsProvider.overrideWith((ref, date) async => []),
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

// ---------------------------------------------------------------------------
// Tests — T-D BUG-P4
// ---------------------------------------------------------------------------

void main() {
  // All tests use a tall surface so the lazy SliverGrid renders all day cells.
  const testSurface = Size(800, 1400);

  group('T-D BUG-P4 — hasPrediction guard removed', () {
    testWidgets(
        'calendar_renders_prediction_dot_for_past_window_dates_when_user_overdue',
        (tester) async {
      // Surface: tall enough for the entire month grid.
      await tester.binding.setSurfaceSize(testSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);

      // Prediction window centred 1 day in the past:
      //   windowStart = today - 3, expectedStart = today - 1, windowEnd = today + 1.
      final windowStart = todayUtc.subtract(const Duration(days: 3));
      final expectedStart = todayUtc.subtract(const Duration(days: 1));
      final windowEnd = todayUtc.add(const Duration(days: 1));

      final prediction = CyclePrediction(
        windowStart: windowStart,
        windowEnd: windowEnd,
        expectedStart: expectedStart,
        cyclesUsed: 5,
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          [
            calendarMonthProvider.overrideWith(
              () => _StubCalendarForMonth(
                year: todayUtc.year,
                month: todayUtc.month,
              ),
            ),
          ],
          prediction: prediction,
        ),
      );
      await tester.pumpAndSettle();

      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();

      // today - 2 is inside [windowStart, windowEnd] and is before today.
      // Before the fix: hasPrediction was false (blocked by !date.isBefore(todayUtc)).
      // After the fix: hasPrediction must be true.
      final pastDate = todayUtc.subtract(const Duration(days: 2));

      // Only assert if pastDate is in the currently displayed month.
      if (pastDate.year == todayUtc.year && pastDate.month == todayUtc.month) {
        final matchingDays = days.where((d) => d.date == pastDate).toList();
        expect(
          matchingDays,
          isNotEmpty,
          reason:
              'Expected a CalendarDay for $pastDate to be rendered in the grid',
        );
        for (final day in matchingDays) {
          expect(
            day.hasPrediction,
            isTrue,
            reason:
                'CalendarDay for $pastDate (inside past prediction window) must have hasPrediction=true',
          );
        }
      }

      // expectedStart = today - 1: also past, also inside window.
      if (expectedStart.year == todayUtc.year &&
          expectedStart.month == todayUtc.month) {
        final matchingDays =
            days.where((d) => d.date == expectedStart).toList();
        expect(
          matchingDays,
          isNotEmpty,
          reason:
              'Expected a CalendarDay for expectedStart $expectedStart to be rendered',
        );
        for (final day in matchingDays) {
          expect(
            day.hasPrediction,
            isTrue,
            reason:
                'CalendarDay for expectedStart $expectedStart must have hasPrediction=true',
          );
        }
      }
    });

    testWidgets('calendar_renders_both_flow_and_prediction_when_overlap',
        (tester) async {
      await tester.binding.setSurfaceSize(testSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);

      // today - 2: past date inside the prediction window; also has flow.
      final overlapDate = todayUtc.subtract(const Duration(days: 2));

      final windowStart = todayUtc.subtract(const Duration(days: 3));
      final expectedStart = todayUtc.subtract(const Duration(days: 1));
      final windowEnd = todayUtc.add(const Duration(days: 1));

      final prediction = CyclePrediction(
        windowStart: windowStart,
        windowEnd: windowEnd,
        expectedStart: expectedStart,
        cyclesUsed: 5,
      );

      // Seed a flow log on overlapDate.
      final logs = overlapDate.year == todayUtc.year &&
              overlapDate.month == todayUtc.month
          ? {
              overlapDate: DailyLogEntity(
                date: overlapDate,
                flowType: FlowType.mestruazioni,
                flowIntensity: FlowIntensity.medium,
              ),
            }
          : <DateTime, DailyLogEntity>{};

      await tester.pumpWidget(
        _wrapWithRouter(
          [
            calendarMonthProvider.overrideWith(
              () => _StubCalendarForMonth(
                year: todayUtc.year,
                month: todayUtc.month,
                logs: logs,
              ),
            ),
          ],
          prediction: prediction,
        ),
      );
      await tester.pumpAndSettle();

      // Only assert if overlapDate is rendered in this month.
      if (overlapDate.year == todayUtc.year &&
          overlapDate.month == todayUtc.month) {
        final days =
            tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();
        final overlapDays = days.where((d) => d.date == overlapDate).toList();
        expect(
          overlapDays,
          isNotEmpty,
          reason: 'CalendarDay for overlapDate $overlapDate must be rendered',
        );
        for (final day in overlapDays) {
          expect(
            day.isFlow,
            isTrue,
            reason: 'CalendarDay for $overlapDate must have isFlow=true',
          );
          expect(
            day.hasPrediction,
            isTrue,
            reason:
                'CalendarDay for $overlapDate must have hasPrediction=true (CL-01: both indicators rendered independently)',
          );
        }
      }
    });

    testWidgets('calendar_still_renders_prediction_dot_for_future_window_dates',
        (tester) async {
      await tester.binding.setSurfaceSize(testSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);

      // Future prediction window: windowStart = today+1, expectedStart = today+3,
      // windowEnd = today+5. Regression: future dots must still render.
      final windowStart = todayUtc.add(const Duration(days: 1));
      final expectedStart = todayUtc.add(const Duration(days: 3));
      final windowEnd = todayUtc.add(const Duration(days: 5));

      final prediction = CyclePrediction(
        windowStart: windowStart,
        windowEnd: windowEnd,
        expectedStart: expectedStart,
        cyclesUsed: 5,
      );

      // today+2 is inside [windowStart, windowEnd] and is in the future.
      final futureDate = todayUtc.add(const Duration(days: 2));

      // Display the month that contains futureDate.
      await tester.pumpWidget(
        _wrapWithRouter(
          [
            calendarMonthProvider.overrideWith(
              () => _StubCalendarForMonth(
                year: futureDate.year,
                month: futureDate.month,
              ),
            ),
          ],
          prediction: prediction,
        ),
      );
      await tester.pumpAndSettle();

      final days =
          tester.widgetList<CalendarDay>(find.byType(CalendarDay)).toList();

      // Assert future date inside window has hasPrediction=true (regression
      // guard: the fix must not break existing future-dot behaviour).
      if (futureDate.year == todayUtc.year &&
          futureDate.month == todayUtc.month) {
        final futureDays = days.where((d) => d.date == futureDate).toList();
        expect(
          futureDays,
          isNotEmpty,
          reason: 'CalendarDay for futureDate $futureDate must be rendered',
        );
        for (final day in futureDays) {
          expect(
            day.hasPrediction,
            isTrue,
            reason:
                'CalendarDay for future $futureDate (inside window) must have hasPrediction=true',
          );
        }
      }
    });
  });
}
