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
  VoidCallback? onTap,
}) => CalendarDay(
      date: _date,
      semanticsLabel: _semanticsLabel,
      isFlow: isFlow,
      isSpotting: isSpotting,
      hasPrediction: hasPrediction,
      hasNote: hasNote,
      isToday: isToday,
      isSelected: isSelected,
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
    testWidgets('minimum size ≥ 44×44', (tester) async {
      await tester.pumpWidget(
        _wrap(_day(onTap: () {}), MetraTheme.light()),
      );
      final size = tester.getSize(find.byType(CalendarDay));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
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
}
