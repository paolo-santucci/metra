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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/app.dart';
import 'package:metra/features/calendar/calendar_screen.dart';
import 'package:metra/features/calendar/state/calendar_month_controller.dart';
import 'package:metra/features/settings/settings_screen.dart';
import 'package:metra/features/stats/stats_screen.dart';
import 'package:metra/features/timeline/timeline_screen.dart';

/// A stub [CalendarMonthNotifier] that returns an empty state immediately
/// without touching the database. Used in navigation tests to prevent the
/// [calendarMonthProvider] from hanging on an unavailable SQLCipher backend.
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

/// Provider override that injects [_StubCalendarMonthNotifier].
final _calendarOverride = calendarMonthProvider.overrideWith(
  _StubCalendarMonthNotifier.new,
);

void main() {
  group('Bottom navigation shell', () {
    testWidgets('renders 4 navigation destinations', (tester) async {
      await tester.pumpWidget(MetraApp(overrides: [_calendarOverride]));
      await tester.pumpAndSettle();

      // NavigationBar has 4 items: Calendar, Timeline, Stats, Settings.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets('Calendar is the initial route', (tester) async {
      await tester.pumpWidget(MetraApp(overrides: [_calendarOverride]));
      await tester.pumpAndSettle();

      // Assert by widget type to avoid collision with the destination label
      // (e.g. 'Timeline' appears both as NavigationDestination label and as
      // TimelineScreen body text).
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('tapping Timeline tab shows timeline screen', (tester) async {
      await tester.pumpWidget(MetraApp(overrides: [_calendarOverride]));
      await tester.pumpAndSettle();

      // Tap the 2nd navigation destination (index 1 = Timeline).
      final destinations = find.byType(NavigationDestination);
      await tester.tap(destinations.at(1));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('tapping Stats tab shows stats screen', (tester) async {
      await tester.pumpWidget(MetraApp(overrides: [_calendarOverride]));
      await tester.pumpAndSettle();

      final destinations = find.byType(NavigationDestination);
      await tester.tap(destinations.at(2));
      await tester.pumpAndSettle();

      expect(find.byType(StatsScreen), findsOneWidget);
    });

    testWidgets('tapping Settings tab shows settings screen', (tester) async {
      await tester.pumpWidget(MetraApp(overrides: [_calendarOverride]));
      await tester.pumpAndSettle();

      final destinations = find.byType(NavigationDestination);
      await tester.tap(destinations.at(3));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
