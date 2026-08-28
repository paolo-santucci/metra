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
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/features/timeline/widgets/timeline_card.dart';
import 'package:metra/features/timeline/widgets/timeline_view.dart';
import 'package:metra/l10n/app_localizations.dart';

// TASK-13 (sp-20260705-gh-issues-batch-onboard-notif-calendar): TimelineView
// threads onCardTap down to each TimelineCard. Traces to ui-design-bible
// §10.3 (timeline card anatomy) and the empty-state hint. TimelineCard's own
// onTap wiring (Semantics(button), opaque GestureDetector, no-ripple) is
// TASK-09's concern and is not re-asserted here.

CycleSummary _summaryFor(int day) => CycleSummary(
      cycle: CycleEntryEntity(
        id: day,
        startDate: DateTime.utc(2026, 4, day),
        endDate: DateTime.utc(2026, 4, day + 4),
        cycleLength: 28,
        periodLength: 5,
      ),
      symptoms: const [],
      dominantPainIntensity: null,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('TimelineView — onCardTap threading', () {
    testWidgets(
        'tapping card i invokes onCardTap with summaries[i] '
        '(non-sequential order proves no stale/off-by-one closure)',
        (tester) async {
      final summaries = [_summaryFor(1), _summaryFor(10), _summaryFor(20)];
      final tapped = <CycleSummary>[];

      await tester.pumpWidget(
        _wrap(
          TimelineView(summaries: summaries, onCardTap: tapped.add),
        ),
      );

      await tester.tap(find.byType(TimelineCard).at(2));
      await tester.pump();
      expect(tapped, [summaries[2]]);
      tapped.clear();

      await tester.tap(find.byType(TimelineCard).at(0));
      await tester.pump();
      expect(tapped, [summaries[0]]);
      tapped.clear();

      await tester.tap(find.byType(TimelineCard).at(1));
      await tester.pump();
      expect(tapped, [summaries[1]]);
    });

    testWidgets('onCardTap:null threads a null onTap into every TimelineCard',
        (tester) async {
      final summaries = [_summaryFor(1), _summaryFor(10)];

      await tester.pumpWidget(_wrap(TimelineView(summaries: summaries)));

      final cards = tester.widgetList<TimelineCard>(find.byType(TimelineCard));
      expect(cards, hasLength(2));
      for (final card in cards) {
        expect(card.onTap, isNull);
      }
    });
  });

  group('TimelineView — empty state (EC-01)', () {
    testWidgets(
        'renders timeline_empty_hint and builds ZERO TimelineCard widgets, '
        'hence zero tap targets and zero possible focus requests',
        (tester) async {
      await tester.pumpWidget(
        _wrap(TimelineView(summaries: const [], onCardTap: (_) {})),
      );

      final l10n =
          AppLocalizations.of(tester.element(find.byType(TimelineView)))!;
      expect(find.text(l10n.timeline_empty_hint), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TimelineView),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });
}
