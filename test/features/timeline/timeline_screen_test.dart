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
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/features/timeline/timeline_screen.dart';
import 'package:metra/features/timeline/widgets/timeline_card.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/calendar_focus_provider.dart';

// TASK-15 (sp-20260705-gh-issues-batch-onboard-notif-calendar): tapping a
// Timeline card must record a calendarFocusRequestProvider request BEFORE
// navigating to /calendar (reversed order would let CalendarScreen build —
// and consume/clear the request — before it lands, silently dropping it).
// Traces to ui-design-bible §10.3 (card anatomy) + §5 (no-ripple tap
// affordance); the Table/"Tabella" view stays non-interactive (guarded by a
// later task, not here).

/// Spy [CalendarFocusRequest] that records the router's current location at
/// the moment `request()` is invoked. `GoRouteInformationProvider.value` is
/// updated synchronously inside `context.go(...)`, before any frame/rebuild
/// — so if a future change reordered `onCardTap` to call `context.go(...)`
/// first, the recorded location would already read '/calendar' instead of
/// '/timeline', failing the order assertion below.
class _SpyCalendarFocusRequest extends CalendarFocusRequest {
  _SpyCalendarFocusRequest(this._router);

  final GoRouter _router;

  /// Router location captured on each `request()` call, in call order.
  final List<String> locationsAtRequestTime = [];

  @override
  void request(DateTime date) {
    locationsAtRequestTime
        .add(_router.routeInformationProvider.value.uri.toString());
    super.request(date);
  }
}

// Fake notifiers — extend TimelineNotifier and override build().
// Do NOT call super.build() — these are pure stubs.

class _LoadingNotifier extends TimelineNotifier {
  @override
  Future<List<CycleSummary>> build() => Completer<List<CycleSummary>>().future;
}

class _ErrorNotifier extends TimelineNotifier {
  @override
  Future<List<CycleSummary>> build() async => throw Exception('test error');
}

class _DataNotifier extends TimelineNotifier {
  _DataNotifier(this._data);
  final List<CycleSummary> _data;
  @override
  Future<List<CycleSummary>> build() async => _data;
}

// Helper: wrap TimelineScreen with GoRouter + ProviderScope + MaterialApp.
// `routerAwareOverrides` receives the constructed [GoRouter] so a test can
// spy on a provider that needs to inspect the router's live location (the
// #3 focus-before-navigate order assertion below).
Widget _wrap(
  List<Override> overrides, {
  List<Override> Function(GoRouter router)? routerAwareOverrides,
}) {
  final router = GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
      GoRoute(
        path: '/daily-entry/:date',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('entry-stub'))),
      ),
      GoRoute(
        path: '/calendar',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('calendar-stub'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      ...overrides,
      ...?routerAwareOverrides?.call(router),
    ],
    child: MaterialApp.router(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

// Helper: make a minimal CycleSummary
CycleSummary _makeSummary({
  required DateTime start,
  DateTime? end,
  int? cycleLength,
  int? periodLength,
}) =>
    CycleSummary(
      cycle: CycleEntryEntity(
        id: 1,
        startDate: start,
        endDate: end,
        cycleLength: cycleLength,
        periodLength: periodLength,
      ),
      symptoms: const [],
      dominantPainIntensity: null,
    );

void main() {
  group('TimelineScreen — loading', () {
    testWidgets('shows spinner while loading', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_LoadingNotifier.new)]),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('TimelineScreen — error', () {
    testWidgets('shows error text on failure', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_ErrorNotifier.new)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Qualcosa è andato storto. Riprova.'), findsOneWidget);
    });
  });

  group('TimelineScreen — empty data', () {
    testWidgets('shows empty-state hint when no cycles', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier([]))]),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Registra il tuo primo ciclo'),
        findsOneWidget,
      );
    });
  });

  group('TimelineScreen — with data', () {
    final kSummaries = [
      _makeSummary(
        start: DateTime.utc(2026, 1, 15),
        end: DateTime.utc(2026, 1, 20),
        cycleLength: 28,
        periodLength: 6,
      ),
    ];

    testWidgets('renders TimelineCard in timeline mode', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TimelineCard), findsOneWidget);
    });

    testWidgets('tapping Tabella segment switches to table view',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tabella'));
      await tester.pumpAndSettle();
      expect(find.byType(TimelineCard), findsNothing);
      // §10.4 rebuild renamed first column from "Inizio" to "Mese"
      expect(find.text('Mese'), findsOneWidget);
    });

    testWidgets('TimelineCard shows month label and footer', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      // Month label contains locale-formatted start date
      expect(find.textContaining('gen'), findsWidgets);
      // Footer contains cycle length
      expect(find.textContaining('Ciclo 28g'), findsOneWidget);
    });

    testWidgets('flow pill always renders, shows dash when no flow',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('TimelineScreen — onCardTap navigation (#3)', () {
    final kSummary = _makeSummary(
      start: DateTime.utc(2026, 1, 15),
      end: DateTime.utc(2026, 1, 20),
      cycleLength: 28,
      periodLength: 6,
    );

    testWidgets(
        'tapping a card requests calendar focus with the card startDate '
        'BEFORE navigating to /calendar (order regression guard)',
        (tester) async {
      late _SpyCalendarFocusRequest spy;
      await tester.pumpWidget(
        _wrap(
          [
            timelineProvider.overrideWith(() => _DataNotifier([kSummary])),
          ],
          routerAwareOverrides: (router) {
            spy = _SpyCalendarFocusRequest(router);
            return [calendarFocusRequestProvider.overrideWith(() => spy)];
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimelineCard));

      // request() ran while the router was still on '/timeline' — proves
      // it fired strictly before context.go('/calendar') took effect.
      expect(spy.locationsAtRequestTime, ['/timeline']);
      expect(spy.state, kSummary.cycle.startDate);

      await tester.pumpAndSettle();
      expect(find.text('calendar-stub'), findsOneWidget);
    });

    testWidgets('tapping a card in Timeline mode navigates to /calendar',
        (tester) async {
      await tester.pumpWidget(
        _wrap([
          timelineProvider.overrideWith(() => _DataNotifier([kSummary])),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimelineCard));
      await tester.pumpAndSettle();

      expect(find.text('calendar-stub'), findsOneWidget);
      expect(find.byType(TimelineScreen), findsNothing);
    });
  });
}
