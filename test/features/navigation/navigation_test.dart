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
import 'package:metra/core/widgets/metra_tab_bar.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_stats_data.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/repositories/app_settings_repository.dart';
import 'package:metra/features/calendar/calendar_screen.dart';
import 'package:metra/features/calendar/state/calendar_month_controller.dart';
import 'package:metra/features/settings/settings_screen.dart';
import 'package:metra/features/stats/state/stats_controller.dart';
import 'package:metra/features/stats/stats_screen.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/features/timeline/timeline_screen.dart';
import 'package:metra/providers/repository_providers.dart';

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

/// A stub [StatsNotifier] that returns null immediately without touching
/// the database. Used in navigation tests to prevent [statsProvider] from
/// hanging on an unavailable SQLCipher backend.
class _StubStatsNotifier extends StatsNotifier {
  @override
  Future<CycleStatsData?> build() async => null;
}

/// A stub [TimelineNotifier] that returns an empty list immediately without
/// touching the database. Used in navigation tests to prevent [timelineProvider]
/// from hanging on an unavailable SQLCipher backend.
class _StubTimelineNotifier extends TimelineNotifier {
  @override
  Future<List<CycleSummary>> build() async => const [];
}

/// A stub [AppSettingsRepository] that returns settings with
/// [onboardingCompleted] = true so the router redirect skips onboarding.
class _StubAppSettingsRepository implements AppSettingsRepository {
  @override
  Future<AppSettingsData> getOrCreate() async =>
      AppSettingsData.defaults().copyWith(onboardingCompleted: true);

  @override
  Stream<AppSettingsData?> watchSettings() => Stream.value(null);

  @override
  Future<void> updateSettings(AppSettingsData settings) async {}

  @override
  Future<void> markOnboardingComplete() async {}

  @override
  Future<void> updateBackupState({
    required String? dropboxEmail,
    required DateTime? lastBackupAt,
  }) async {}

  @override
  Future<void> saveDeclaredCycleLength(int cycleLength) async {}

  @override
  Future<void> updateLastDataWriteAt(DateTime timestamp) async {}

  @override
  Future<void> updateBackupSuspended(bool value) async {}
}

/// Provider override that injects [_StubCalendarMonthNotifier].
final _calendarOverride = calendarMonthProvider.overrideWith(
  _StubCalendarMonthNotifier.new,
);

/// Provider override that injects [_StubStatsNotifier].
final _statsOverride = statsProvider.overrideWith(_StubStatsNotifier.new);

/// Provider override that injects [_StubTimelineNotifier].
final _timelineOverride = timelineProvider.overrideWith(
  _StubTimelineNotifier.new,
);

/// Provider override that bypasses the onboarding redirect.
final _settingsOverride = appSettingsRepositoryProvider.overrideWith(
  (ref) async => _StubAppSettingsRepository(),
);

void main() {
  group('Bottom navigation shell', () {
    testWidgets('renders MetraTabBar with 4 tabs', (tester) async {
      await tester.pumpWidget(
        MetraApp(
          overrides: [
            _calendarOverride,
            _statsOverride,
            _timelineOverride,
            _settingsOverride,
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Custom tab bar: MetraTabBar with 4 GestureDetector tabs.
      expect(find.byType(MetraTabBar), findsOneWidget);
      final tabTaps = find.descendant(
        of: find.byType(MetraTabBar),
        matching: find.byType(GestureDetector),
      );
      expect(tabTaps, findsNWidgets(4));
    });

    testWidgets('shows localized tab labels (English in test environment)',
        (tester) async {
      await tester.pumpWidget(
        MetraApp(
          overrides: [
            _calendarOverride,
            _statsOverride,
            _timelineOverride,
            _settingsOverride,
          ],
        ),
      );
      await tester.pumpAndSettle();

      // In the test environment the system locale is en, so MetraApp resolves
      // to English. The tab bar must show English labels (not hardcoded Italian).
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Calendar is the initial route', (tester) async {
      await tester.pumpWidget(
        MetraApp(
          overrides: [
            _calendarOverride,
            _statsOverride,
            _timelineOverride,
            _settingsOverride,
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('tapping Archivio tab shows timeline screen', (tester) async {
      await tester.pumpWidget(
        MetraApp(
          overrides: [
            _calendarOverride,
            _statsOverride,
            _timelineOverride,
            _settingsOverride,
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 2nd tab (index 1 = Archivio / Timeline) in MetraTabBar.
      final tabs = find.descendant(
        of: find.byType(MetraTabBar),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(tabs.at(1));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('tapping Stats tab shows stats screen', (tester) async {
      await tester.pumpWidget(
        MetraApp(
          overrides: [
            _calendarOverride,
            _statsOverride,
            _timelineOverride,
            _settingsOverride,
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 3rd tab (index 2 = Statistiche) in MetraTabBar.
      final tabs = find.descendant(
        of: find.byType(MetraTabBar),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(tabs.at(2));
      await tester.pumpAndSettle();

      expect(find.byType(StatsScreen), findsOneWidget);
    });

    testWidgets('tapping Settings tab shows settings screen', (tester) async {
      await tester.pumpWidget(
        MetraApp(
          overrides: [
            _calendarOverride,
            _statsOverride,
            _timelineOverride,
            _settingsOverride,
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 4th tab (index 3 = Impostazioni) in MetraTabBar.
      final tabs = find.descendant(
        of: find.byType(MetraTabBar),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(tabs.at(3));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
