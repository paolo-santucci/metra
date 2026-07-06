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
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';
import 'package:metra/features/calendar/calendar_screen.dart';
import 'package:metra/features/calendar/state/calendar_month_controller.dart';
import 'package:metra/features/calendar/state/prediction_controller.dart';
import 'package:metra/features/calendar/widgets/calendar_day.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/features/timeline/timeline_screen.dart';
import 'package:metra/features/timeline/widgets/timeline_card.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/calendar_focus_provider.dart';
import 'package:metra/providers/repository_providers.dart';

// TASK-17 (sp-20260705-gh-issues-batch-onboard-notif-calendar): end-to-end
// integration proof for #3 (Timeline -> Calendar navigation). Production
// code (calendarFocusRequestProvider, CalendarMonthNotifier.goToMonth,
// CalendarScreen's focus-consume-on-mount, TimelineCard.onTap,
// TimelineView.onCardTap, TimelineScreen's onCardTap wiring) already ships
// from prior tasks (TASK-04/05/09/10/13/15) — this file is TEST-ONLY,
// verifying the fully-wired flow through a real GoRouter (not a
// '/calendar'-stub route, unlike timeline_screen_test.dart's harness).
//
// Harness idiom reused from test/features/calendar/calendar_screen_test.dart
// (TASK-10's "pending focus request" group): an externally-owned
// ProviderContainer + UncontrolledProviderScope so tests can both pre-read
// state before the first pump and post-read it after settling, without
// touching the real Drift-backed repositories.
//
// Scenario A traces to ui-design-bible §8.3.1 (Selected-day state table:
// bg inchiostro/tc_spenta, text sabbia/notte, weight 600) via CalendarDay's
// isSelected flag. Scenario B / Group D traces to §15 anti-pattern 9,
// scoped to Table view (display-only) with the Timeline single-tap
// exception (TASK-01).

// ---------------------------------------------------------------------------
// Stub notifiers (self-contained — do not import from other _test.dart files)
// ---------------------------------------------------------------------------

class _DataTimelineNotifier extends TimelineNotifier {
  _DataTimelineNotifier(this._data);
  final List<CycleSummary> _data;

  @override
  Future<List<CycleSummary>> build() async => _data;
}

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._initial);
  final AppSettingsData _initial;

  @override
  Future<AppSettingsData> build() async => _initial;
}

/// Mirrors production `CalendarMonthNotifier.goToMonth`'s synchronous-first
/// shape without touching real repositories/DB. `build()` never completes
/// (stays `AsyncLoading` until `goToMonth` is called) so the same stub also
/// exercises EC-02 (goToMonth applied while unloaded, unlike the relative-nav
/// methods which no-op on `null` state). `goToPrevMonth`/`goToNextMonth` are
/// functional (post-jump) so EC-04 can prove a manual nav performed after
/// focus-consumption survives an unrelated rebuild. `goToMonthCallCount`
/// makes idempotency assertions direct rather than inferred only from state.
class _FocusableCalendarMonthNotifier extends CalendarMonthNotifier {
  int goToMonthCallCount = 0;

  @override
  Future<CalendarMonthState> build() => Completer<CalendarMonthState>().future;

  @override
  void goToMonth(int year, int month) {
    goToMonthCallCount++;
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

/// EC-05 stub: `goToMonth` sets `AsyncData` synchronously (like production),
/// then asynchronously resolves to `AsyncError` — simulating a subscription
/// failure arriving after the jump. `_applyFocus` clears the pending request
/// synchronously before this error arrives, so the error must not trigger a
/// retry/re-consumption. `goToMonthCallCount` proves no retry storm directly.
class _ErrorAfterGoToMonthNotifier extends CalendarMonthNotifier {
  int goToMonthCallCount = 0;

  @override
  Future<CalendarMonthState> build() => Completer<CalendarMonthState>().future;

  @override
  void goToMonth(int year, int month) {
    goToMonthCallCount++;
    state = AsyncData(CalendarMonthState(year: year, month: month));
    Future<void>.delayed(Duration.zero, () {
      state = AsyncError(
        Exception('test subscription error'),
        StackTrace.current,
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

/// Wraps a caller-supplied [ProviderContainer] with a REAL GoRouter routing
/// both '/timeline' -> [TimelineScreen] and '/calendar' -> [CalendarScreen]
/// (unlike timeline_screen_test.dart's '/calendar'-stub harness) so the full
/// #3 navigation contract — including CalendarScreen's own focus-consumption
/// — is exercised end-to-end.
Widget _wrapWithContainer(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
      GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
      GoRoute(
        path: '/daily-entry/:date',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('entry-stub'))),
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
      routerConfig: router,
    ),
  );
}

CycleSummary _makeSummary(DateTime start) => CycleSummary(
      cycle: CycleEntryEntity(
        id: 1,
        startDate: start,
        endDate: start.add(const Duration(days: 5)),
        cycleLength: 28,
        periodLength: 6,
      ),
      symptoms: const [],
      dominantPainIntensity: null,
    );

/// Two months before "now", pinned to day 12 (exists in every month) — always
/// distinct from CalendarScreen's initial-render month, immune to calendar
/// drift. Mirrors calendar_screen_test.dart's `_targetFocusDate`.
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

/// Common non-DB-touching overrides shared by every scenario in this file.
List<Override> _baseOverrides({
  SettingsNotifier Function()? settings,
}) =>
    [
      cyclePredictionProvider.overrideWith((ref) => Stream.value(null)),
      painSymptomsProvider.overrideWith((ref, date) async => []),
      settingsNotifierProvider.overrideWith(
        settings ?? () => _StubSettingsNotifier(AppSettingsData.defaults()),
      ),
    ];

void main() {
  group('Timeline -> Calendar navigation — Scenario A (#3)', () {
    testWidgets(
        'should_show_target_month_and_select_day_when_card_tapped_given_real_router',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final target = _targetFocusDate();
      final summary = _makeSummary(target);

      final container = ProviderContainer(
        overrides: [
          ..._baseOverrides(),
          timelineProvider.overrideWith(() => _DataTimelineNotifier([summary])),
          calendarMonthProvider
              .overrideWith(_FocusableCalendarMonthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineCard), findsOneWidget);

      await tester.tap(find.byType(TimelineCard));
      await tester.pumpAndSettle();

      // Navigated: TimelineScreen replaced by CalendarScreen.
      expect(find.byType(TimelineScreen), findsNothing);
      expect(find.byType(CalendarScreen), findsOneWidget);

      // Month header shows the entry's startDate month (Bible §8.1: "Month Year").
      final rawMonth = intl.DateFormat.MMMM('it')
          .format(DateTime(target.year, target.month));
      final title =
          '${rawMonth.substring(0, 1).toUpperCase()}${rawMonth.substring(1)} ${target.year}';
      expect(find.text(title), findsOneWidget);

      // The target day cell renders in canon Selected state (§8.3.1).
      final targetDay = find.byWidgetPredicate(
        (w) => w is CalendarDay && w.date == target,
      );
      expect(targetDay, findsOneWidget);
      expect(tester.widget<CalendarDay>(targetDay).isSelected, isTrue);

      // The request is consumed — reading it again yields null.
      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    testWidgets(
        'should_apply_focus_when_calendarMonthProvider_is_still_loading_ec02',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final target = _targetFocusDate();
      final summary = _makeSummary(target);

      final container = ProviderContainer(
        overrides: [
          ..._baseOverrides(),
          timelineProvider.overrideWith(() => _DataTimelineNotifier([summary])),
          // build() never completes on its own — stays AsyncLoading until
          // goToMonth() is called. Proves goToMonth does NOT early-return on
          // unloaded state (unlike goToPrevMonth/goToNextMonth).
          calendarMonthProvider
              .overrideWith(_FocusableCalendarMonthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimelineCard));
      await tester.pumpAndSettle();

      final monthState = container.read(calendarMonthProvider).valueOrNull;
      expect(monthState?.year, equals(target.year));
      expect(monthState?.month, equals(target.month));

      // The spinner (AsyncLoading rendering) is gone — the jump replaced it.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    testWidgets(
        'should_preserve_manual_nav_and_not_reapply_focus_on_rebuild_ec04',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final target = _targetFocusDate();
      final summary = _makeSummary(target);
      late _StubSettingsNotifier settingsStub;
      late _FocusableCalendarMonthNotifier monthNotifier;

      final container = ProviderContainer(
        overrides: [
          ..._baseOverrides(
            settings: () {
              settingsStub = _StubSettingsNotifier(AppSettingsData.defaults());
              return settingsStub;
            },
          ),
          timelineProvider.overrideWith(() => _DataTimelineNotifier([summary])),
          calendarMonthProvider.overrideWith(() {
            monthNotifier = _FocusableCalendarMonthNotifier();
            return monthNotifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimelineCard));
      await tester.pumpAndSettle();

      // Sanity: focus applied exactly once, request cleared.
      expect(monthNotifier.goToMonthCallCount, equals(1));
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

      // Force a CalendarScreen rebuild unrelated to the focus request — same
      // idiom as calendar_screen_test.dart's EC-04 test: mutating an
      // unrelated watched provider re-runs build() (re-registers
      // ref.listen) WITHOUT re-running initState, mirroring a
      // StatefulShellRoute-style rebuild.
      settingsStub.state = AsyncData(
        AppSettingsData.defaults()
            .copyWith(firstDayOfWeek: FirstDayOfWeekSetting.sunday),
      );
      await tester.pumpAndSettle();

      // goToMonth must NOT have been called again — the manually-navigated
      // month must be preserved, not reverted back to `target`.
      expect(monthNotifier.goToMonthCallCount, equals(1));
      final monthAfterRebuild =
          container.read(calendarMonthProvider).valueOrNull;
      expect(monthAfterRebuild?.year, equals(expectedNextYear));
      expect(monthAfterRebuild?.month, equals(expectedNextMonth));
      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    testWidgets(
        'should_show_generic_error_with_no_retry_storm_when_month_provider_errors_after_jump_ec05',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final target = _targetFocusDate();
      final summary = _makeSummary(target);
      late _ErrorAfterGoToMonthNotifier monthNotifier;

      final container = ProviderContainer(
        overrides: [
          ..._baseOverrides(),
          timelineProvider.overrideWith(() => _DataTimelineNotifier([summary])),
          calendarMonthProvider.overrideWith(() {
            monthNotifier = _ErrorAfterGoToMonthNotifier();
            return monthNotifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimelineCard));
      await tester.pumpAndSettle();

      // Generic error state (not a raw stack trace) once the subscription
      // resolves to AsyncError.
      expect(
        find.text('Qualcosa è andato storto. Riprova.'),
        findsOneWidget,
      );

      // The request was already cleared by _applyFocus before the error
      // arrived — no stuck pending focus, no retry storm (goToMonth called
      // exactly once, not repeatedly).
      expect(container.read(calendarFocusRequestProvider), isNull);
      expect(monthNotifier.goToMonthCallCount, equals(1));
    });
  });
}
