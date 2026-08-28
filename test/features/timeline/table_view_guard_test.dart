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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/features/calendar/calendar_screen.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/features/timeline/timeline_screen.dart';
import 'package:metra/features/timeline/widgets/table_view.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/calendar_focus_provider.dart';

// TASK-17 (sp-20260705-gh-issues-batch-onboard-notif-calendar): Scenario B /
// Group D (FR-03) — proves the Archive Table view stays non-interactive.
// Traces to ui-design-bible §15 anti-pattern 9, scoped to Table view only
// (TASK-01): "display-only" still applies there; only the Timeline card
// single-tap exception was carved out. TEST-ONLY — table_view.dart is
// confirmed UNCHANGED by this task (verified via grep below, never edited).

class _DataTimelineNotifier extends TimelineNotifier {
  _DataTimelineNotifier(this._data);
  final List<CycleSummary> _data;

  @override
  Future<List<CycleSummary>> build() async => _data;
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

/// Wraps [TimelineScreen] with a real GoRouter (also routing to
/// [CalendarScreen], so a false-positive navigation would be observable, not
/// masked by a stub route as in some older harnesses).
Widget _wrapTimelineScreen(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
      GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// Standalone [TableView] harness for the widget-tree interactivity guard —
/// no router/provider machinery needed since [TableView] takes summaries
/// directly and does not read Riverpod providers.
Widget _wrapTableViewOnly(List<CycleSummary> summaries) => MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: TableView(summaries: summaries)),
    );

void main() {
  group('Table view non-interactivity — Scenario B / EC-06 (#3, FR-03)', () {
    testWidgets(
        'should_not_navigate_or_set_focus_request_when_data_row_tapped_given_table_mode',
        (tester) async {
      final summary = _makeSummary(DateTime.utc(2026, 1, 15));

      await tester.pumpWidget(
        _wrapTimelineScreen([
          timelineProvider.overrideWith(() => _DataTimelineNotifier([summary])),
        ]),
      );
      await tester.pumpAndSettle();

      // Switch to Table ("Tabella") mode. warnIfMissed:false — same
      // pre-existing SegmentedControlMetra hit-test-offset warning already
      // documented in timeline_screen_test.dart for this exact tap target,
      // unrelated to this file's assertions.
      await tester.tap(find.text('Tabella'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Sanity: the data row rendered ("Gen" is the capitalised Italian
      // abbreviation for January the table applies to its month label —
      // table_view.dart._DataRow uppercases the first letter of the
      // formatted month).
      expect(find.textContaining('Gen'), findsWidgets);
      expect(container(tester).read(calendarFocusRequestProvider), isNull);

      // Tap on the row's content (the private _DataRow itself has no
      // GestureDetector/InkWell to receive the tap on — warnIfMissed:false
      // mirrors the pre-existing, documented "Tabella" hit-test warning
      // pattern in timeline_screen_test.dart for this exact non-interactive
      // surface).
      final dataRow = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_DataRow',
      );
      expect(dataRow, findsOneWidget);
      await tester.tap(dataRow, warnIfMissed: false);
      await tester.pumpAndSettle();

      // EC-06: no navigation occurred, provider stays null.
      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(find.byType(CalendarScreen), findsNothing);
      expect(container(tester).read(calendarFocusRequestProvider), isNull);
    });
  });

  group('Table view widget-tree guard — Group D (§15.9 display-only)', () {
    testWidgets(
        'should_have_no_interactive_wrapper_anywhere_in_the_table_view_subtree',
        (tester) async {
      final summaries = [
        _makeSummary(DateTime.utc(2026, 1, 15)),
        _makeSummary(DateTime.utc(2026, 2, 10)),
      ];

      await tester.pumpWidget(_wrapTableViewOnly(summaries));
      await tester.pumpAndSettle();

      final tableViewFinder = find.byType(TableView);
      expect(tableViewFinder, findsOneWidget);

      // No GestureDetector, no InkWell, no Material-ripple ancestor anywhere
      // under TableView — descendant-scoped so the outer MaterialApp/Scaffold
      // Material (an ANCESTOR, not a descendant) does not produce a false
      // failure.
      expect(
        find.descendant(
          of: tableViewFinder,
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: tableViewFinder,
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: tableViewFinder,
          matching: find.byType(InkResponse),
        ),
        findsNothing,
      );
    });
  });

  group('Static grep guard — table_view.dart unchanged / no nav wiring', () {
    test(
        'should_find_zero_occurrences_of_onCardTap_or_calendarFocusRequestProvider_in_table_view_dart',
        () async {
      const path = 'lib/features/timeline/widgets/table_view.dart';
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must exist');

      final content = file.readAsStringSync();
      // Direct content assertion (backup to the grep process below).
      expect(content.contains('onCardTap'), isFalse);
      expect(content.contains('calendarFocusRequestProvider'), isFalse);

      // Exact grep guard specified in the task: 0 matching lines.
      final result = await Process.run(
        'grep',
        ['-n', r'onCardTap\|calendarFocusRequestProvider', path],
      );
      // grep exit code 1 == no matches found; stdout must be empty.
      expect(
        result.exitCode,
        equals(1),
        reason: 'grep must find 0 matches (exit code 1); got stdout: '
            '${result.stdout}',
      );
      expect((result.stdout as String).trim(), isEmpty);
    });
  });
}

/// Reads the [ProviderContainer] backing the currently-pumped widget tree.
/// `listen: false` — called outside of a build phase, so the
/// `dependOnInheritedWidgetOfExactType`-based `listen: true` path (the
/// default) would assert.
ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
