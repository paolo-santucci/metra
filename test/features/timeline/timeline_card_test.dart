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

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/features/timeline/widgets/timeline_card.dart';
import 'package:metra/l10n/app_localizations.dart';

// TASK-09 (sp-20260705-gh-issues-batch-onboard-notif-calendar): TimelineCard
// tap target. Mirrors the CalendarDay tap idiom (see calendar_day.dart) and
// traces to ui-design-bible §10.3 (card anatomy), §5 (no-ripple — the primary
// CTA is the only "button"), and §15 anti-pattern 9 (Timeline single-tap
// exception, added by TASK-01).

final _summary = CycleSummary(
  cycle: CycleEntryEntity(
    id: 1,
    startDate: DateTime.utc(2026, 4, 1),
    endDate: DateTime.utc(2026, 4, 5),
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
  group('TimelineCard — onTap wired', () {
    testWidgets('tapping the card body invokes onTap exactly once',
        (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            summary: _summary,
            isLast: true,
            onTap: () => tapCount++,
          ),
        ),
      );

      await tester.tap(find.byType(TimelineCard));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets(
        'wraps the card subtree in Semantics(button: true, enabled: true)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(summary: _summary, isLast: true, onTap: () {}),
        ),
      );

      final semantics = tester.getSemantics(find.byType(TimelineCard));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, Tristate.isTrue);
    });

    testWidgets('uses an opaque GestureDetector for the tap target',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(summary: _summary, isLast: true, onTap: () {}),
        ),
      );

      final detectorFinder = find.descendant(
        of: find.byType(TimelineCard),
        matching: find.byType(GestureDetector),
      );
      expect(detectorFinder, findsOneWidget);
      final detector = tester.widget<GestureDetector>(detectorFinder);
      expect(detector.behavior, HitTestBehavior.opaque);
      expect(detector.onTap, isNotNull);
    });

    testWidgets(
        'EC-07: zero InkWell/Material-ripple ancestors anywhere in the subtree',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(summary: _summary, isLast: true, onTap: () {}),
        ),
      );

      final inkWellFinder = find.descendant(
        of: find.byType(TimelineCard),
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsNothing);
    });

    testWidgets('card body hit region is at least 44x44 dp', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(summary: _summary, isLast: true, onTap: () {}),
        ),
      );

      final detectorFinder = find.descendant(
        of: find.byType(TimelineCard),
        matching: find.byType(GestureDetector),
      );
      final size = tester.getSize(detectorFinder);
      expect(size.width, greaterThanOrEqualTo(44.0));
      expect(size.height, greaterThanOrEqualTo(44.0));
    });
  });

  group('TimelineCard — onTap null (display-only, no regression)', () {
    testWidgets('emits no Semantics(button:) wrapper', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(summary: _summary, isLast: true),
        ),
      );

      final semantics = tester.getSemantics(find.byType(TimelineCard));
      expect(semantics.flagsCollection.isButton, isFalse);
    });

    testWidgets('emits no GestureDetector', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(summary: _summary, isLast: true),
        ),
      );

      final detectorFinder = find.descendant(
        of: find.byType(TimelineCard),
        matching: find.byType(GestureDetector),
      );
      expect(detectorFinder, findsNothing);
    });
  });
}
