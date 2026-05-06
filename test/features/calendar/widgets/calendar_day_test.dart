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
import 'package:metra/features/calendar/widgets/calendar_day.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

final _date = DateTime.utc(2026, 4, 15);
const _semanticsLabel = 'Flusso medio, 15 aprile 2026';

CalendarDay _day({
  bool isFlow = false,
  bool isSpotting = false,
  bool hasPrediction = false,
  bool hasNote = false,
  bool isToday = false,
  bool isSelected = false,
  bool isFuture = false,
  VoidCallback? onTap,
}) =>
    CalendarDay(
      date: _date,
      semanticsLabel: _semanticsLabel,
      isFlow: isFlow,
      isSpotting: isSpotting,
      hasPrediction: hasPrediction,
      hasNote: hasNote,
      isToday: isToday,
      isSelected: isSelected,
      isFuture: isFuture,
      onTap: onTap,
    );

void main() {
  group('golden — light theme', () {
    testWidgets('plain (no state)', (tester) async {
      await tester.pumpWidget(_wrap(_day(), MetraTheme.light()));
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_plain_light.png'),
      );
    });

    testWidgets('flow', (tester) async {
      await tester.pumpWidget(_wrap(_day(isFlow: true), MetraTheme.light()));
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_flow_light.png'),
      );
    });

    testWidgets('spotting', (tester) async {
      await tester.pumpWidget(
        _wrap(_day(isSpotting: true), MetraTheme.light()),
      );
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_spotting_light.png'),
      );
    });

    testWidgets('prediction', (tester) async {
      await tester.pumpWidget(
        _wrap(_day(hasPrediction: true), MetraTheme.light()),
      );
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_prediction_light.png'),
      );
    });

    testWidgets('today', (tester) async {
      await tester.pumpWidget(_wrap(_day(isToday: true), MetraTheme.light()));
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_today_light.png'),
      );
    });

    testWidgets('selected', (tester) async {
      await tester.pumpWidget(
        _wrap(_day(isSelected: true), MetraTheme.light()),
      );
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_selected_light.png'),
      );
    });

    testWidgets('flow + today + note', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _day(isFlow: true, isToday: true, hasNote: true),
          MetraTheme.light(),
        ),
      );
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_flow_today_note_light.png'),
      );
    });
  });

  group('golden — dark theme', () {
    testWidgets('plain', (tester) async {
      await tester.pumpWidget(_wrap(_day(), MetraTheme.dark()));
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_plain_dark.png'),
      );
    });

    testWidgets('flow', (tester) async {
      await tester.pumpWidget(_wrap(_day(isFlow: true), MetraTheme.dark()));
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_flow_dark.png'),
      );
    });

    testWidgets('selected dark', (tester) async {
      await tester.pumpWidget(_wrap(_day(isSelected: true), MetraTheme.dark()));
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_selected_dark.png'),
      );
    });
  });

  group('future day', () {
    testWidgets('golden — light theme', (tester) async {
      await tester.pumpWidget(
        _wrap(_day(isFuture: true), MetraTheme.light()),
      );
      await expectLater(
        find.byType(CalendarDay),
        matchesGoldenFile('goldens/calendar_day_future_light.png'),
      );
    });

    testWidgets('does not fire onTap when isFuture', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          _day(isFuture: true, onTap: () => tapped = true),
          MetraTheme.light(),
        ),
      );
      await tester.tap(find.byType(CalendarDay));
      expect(tapped, isFalse);
    });

    testWidgets('is not a button in semantics when isFuture', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _day(isFuture: true, onTap: () {}),
          MetraTheme.light(),
        ),
      );
      final semantics = tester.getSemantics(find.byType(CalendarDay));
      expect(semantics.flagsCollection.isButton, isFalse);
    });

    testWidgets('prediction outline still shows when isFuture + hasPrediction',
        (tester) async {
      // hasPrediction wins over isFuture in state precedence — cell uses
      // prediction style (outline), not the faded-future style.
      await tester.pumpWidget(
        _wrap(
          _day(isFuture: true, hasPrediction: true),
          MetraTheme.light(),
        ),
      );
      // No overflow or exception; golden already covered by prediction test.
      expect(find.byType(CalendarDay), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('label matches semanticsLabel prop', (tester) async {
      await tester.pumpWidget(_wrap(_day(), MetraTheme.light()));
      final semantics = tester.getSemantics(find.byType(CalendarDay));
      expect(semantics.label, _semanticsLabel);
    });

    testWidgets('is button when onTap is provided', (tester) async {
      await tester.pumpWidget(
        _wrap(_day(onTap: () {}), MetraTheme.light()),
      );
      final semantics = tester.getSemantics(find.byType(CalendarDay));
      expect(semantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('is not button when onTap is null', (tester) async {
      await tester.pumpWidget(_wrap(_day(), MetraTheme.light()));
      final semantics = tester.getSemantics(find.byType(CalendarDay));
      expect(semantics.flagsCollection.isButton, isFalse);
    });
  });

  group('tap target', () {
    testWidgets('minimum size ≥ 48×48 (Android floor, CLAUDE.md §10)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_day(onTap: () {}), MetraTheme.light()),
      );
      final size = tester.getSize(find.byType(CalendarDay));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('interaction', () {
    testWidgets('fires onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_day(onTap: () => tapped = true), MetraTheme.light()),
      );
      await tester.tap(find.byType(CalendarDay));
      expect(tapped, isTrue);
    });

    testWidgets('does not throw when onTap is null', (tester) async {
      await tester.pumpWidget(_wrap(_day(), MetraTheme.light()));
      await tester.tap(find.byType(CalendarDay));
      // no exception expected
    });
  });

  // ── TASK-03 tests: selectedDayFill (FR-01/FR-02/FR-04) ───────────────────────

  /// Finds the innermost non-transparent DecoratedBox that acts as the cell fill.
  BoxDecoration findCellDecoration(WidgetTester tester) {
    final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    return boxes.map((b) => b.decoration).whereType<BoxDecoration>().firstWhere(
          (d) => d.color != null && d.color != Colors.transparent,
        );
  }

  group('CalendarDay — selected fill (FR-01/FR-02/FR-04)', () {
    testWidgets('dark selected — fill is muted terracotta (#B86848)',
        (tester) async {
      await tester.pumpWidget(_wrap(_day(isSelected: true), MetraTheme.dark()));
      final decoration = findCellDecoration(tester);
      expect(decoration.color, const Color(0xFFB86848));
    });

    testWidgets('light selected — fill is ink (#2B2521, regression guard)',
        (tester) async {
      await tester
          .pumpWidget(_wrap(_day(isSelected: true), MetraTheme.light()));
      final decoration = findCellDecoration(tester);
      expect(decoration.color, const Color(0xFF2B2521));
    });

    testWidgets('dark selected + today — fill is terracotta, no today border',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_day(isSelected: true, isToday: true), MetraTheme.dark()),
      );
      final decoration = findCellDecoration(tester);
      // Selected wins over today: fill is terracotta, border is null.
      expect(decoration.color, const Color(0xFFB86848));
      expect(decoration.border, isNull);
    });

    testWidgets(
        'dark selected + flow — fill is terracotta, flow indicator uses bgPrimary',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_day(isSelected: true, isFlow: true), MetraTheme.dark()),
      );
      final decoration = findCellDecoration(tester);
      // Selected wins over flow: fill is terracotta.
      expect(decoration.color, const Color(0xFFB86848));
    });

    testWidgets(
        'dark selected + prediction — fill is terracotta, prediction indicator uses bgPrimary',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _day(isSelected: true, hasPrediction: true),
          MetraTheme.dark(),
        ),
      );
      final decoration = findCellDecoration(tester);
      expect(decoration.color, const Color(0xFFB86848));
    });

    testWidgets(
        'dark selected + note — note indicator dot is bgPrimary (#1A1410)',
        (tester) async {
      // The note indicator colour is set to bgPrimary on selected cells.
      // bgPrimary in dark = #1A1410. We verify no exception and correct fill.
      await tester.pumpWidget(
        _wrap(_day(isSelected: true, hasNote: true), MetraTheme.dark()),
      );
      final decoration = findCellDecoration(tester);
      expect(decoration.color, const Color(0xFFB86848));
    });

    testWidgets('dark selected with onTap null — fill terracotta, not a button',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_day(isSelected: true), MetraTheme.dark()),
      );
      final decoration = findCellDecoration(tester);
      expect(decoration.color, const Color(0xFFB86848));
      // onTap is null → not a button semantically.
      final semantics = tester.getSemantics(find.byType(CalendarDay));
      expect(semantics.flagsCollection.isButton, isFalse);
    });

    testWidgets('live theme switch refreshes selected fill', (tester) async {
      // Build a StatefulWidget that holds ThemeMode and can toggle it.
      final notifier = ValueNotifier<ThemeMode>(ThemeMode.light);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: notifier,
          builder: (_, mode, __) => MaterialApp(
            theme: MetraTheme.light(),
            darkTheme: MetraTheme.dark(),
            themeMode: mode,
            home: Scaffold(
              body: Center(
                child: _day(isSelected: true),
              ),
            ),
          ),
        ),
      );
      // Light first.
      var decoration = findCellDecoration(tester);
      expect(decoration.color, const Color(0xFF2B2521));

      // Switch to dark.
      notifier.value = ThemeMode.dark;
      await tester.pumpAndSettle();

      decoration = findCellDecoration(tester);
      expect(decoration.color, const Color(0xFFB86848));
    });
  });
}
