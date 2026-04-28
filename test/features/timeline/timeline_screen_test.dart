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

// Helper: wrap TimelineScreen with GoRouter + ProviderScope + MaterialApp
Widget _wrap(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
      GoRoute(
        path: '/daily-entry/:date',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('entry-stub'))),
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
          find.textContaining('Registra il tuo primo ciclo'), findsOneWidget);
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
      expect(find.text('Inizio'), findsOneWidget);
    });

    testWidgets('tapping a TimelineCard navigates to daily-entry',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TimelineCard).first);
      await tester.pumpAndSettle();
      expect(find.text('entry-stub'), findsOneWidget);
    });

    testWidgets('TimelineCard semantics label contains "Ciclo dal"',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'Ciclo dal')), findsOneWidget);
    });

    testWidgets('in-progress cycle shows "In corso" badge', (tester) async {
      final inProgress = [
        _makeSummary(start: DateTime.utc(2026, 4, 13)),
      ];
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(inProgress))]),
      );
      await tester.pumpAndSettle();
      expect(find.text('In corso'), findsWidgets);
    });
  });
}
