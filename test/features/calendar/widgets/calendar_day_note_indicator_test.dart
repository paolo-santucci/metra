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
import 'package:metra/core/widgets/metra_icon.dart';
import 'package:metra/features/calendar/widgets/calendar_day.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

final _date = DateTime.utc(2026, 4, 15);
const _semanticsLabel = '15 aprile 2026';

CalendarDay _day({
  bool isFlow = false,
  bool hasPain = false,
  bool hasNote = false,
}) =>
    CalendarDay(
      date: _date,
      semanticsLabel: _semanticsLabel,
      isFlow: isFlow,
      hasPain: hasPain,
      hasNote: hasNote,
    );

/// Finds any MetraIcon rendered with the pen SVG body.
final _penFinder = find.byWidgetPredicate(
  (widget) => widget is MetraIcon && widget.svgBody == MetraIcons.pen,
);

void main() {
  group('CalendarDay — note indicator (pen icon)', () {
    testWidgets(
        'should_show_pen_icon_when_hasNote_is_true', (tester) async {
      // Arrange
      final widget = _wrap(_day(hasNote: true), MetraTheme.light());

      // Act
      await tester.pumpWidget(widget);

      // Assert
      expect(_penFinder, findsOneWidget);
    });

    testWidgets(
        'should_not_show_pen_icon_when_hasNote_is_false_with_no_other_indicators',
        (tester) async {
      // Arrange — plain cell, no indicators at all
      final widget = _wrap(_day(), MetraTheme.light());

      // Act
      await tester.pumpWidget(widget);

      // Assert
      expect(_penFinder, findsNothing);
    });

    testWidgets(
        'should_not_show_pen_icon_when_hasNote_is_false_with_other_indicators_present',
        (tester) async {
      // Arrange — flow + pain indicators are rendered; pen must NOT appear
      final widget = _wrap(
        _day(isFlow: true, hasPain: true, hasNote: false),
        MetraTheme.light(),
      );

      // Act
      await tester.pumpWidget(widget);

      // Assert: other MetraIcons are present, but none carries the pen body
      expect(_penFinder, findsNothing);
    });
  });
}
