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
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/stats/widgets/mini_bar_chart.dart';
import 'package:metra/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: MetraTheme.light(),
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

// Three canonical data points for standard tests.
const _threePoints = [
  (label: 'gen', value: 28.0),
  (label: 'feb', value: 30.0),
  (label: 'mar', value: 29.0),
];

void main() {
  group('MiniBarChart', () {
    testWidgets('renders correct number of label Text widgets', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MiniBarChart(
            points: _threePoints,
            color: MetraColors.light.accentFlow,
            maxValue: 35.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Each data point has a label rendered as a Text widget.
      expect(find.text('gen'), findsOneWidget);
      expect(find.text('feb'), findsOneWidget);
      expect(find.text('mar'), findsOneWidget);
    });

    testWidgets('renders correct number of value Text widgets', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MiniBarChart(
            points: _threePoints,
            color: MetraColors.light.accentFlow,
            maxValue: 35.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Each data point value rendered — using integer display (28, 30, 29).
      expect(find.text('28'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
    });

    testWidgets('empty points list renders without error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MiniBarChart(
            points: const [],
            color: MetraColors.light.accentFlow,
            maxValue: 35.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No overflow or exception — chart root (Row) is present but empty.
      expect(tester.takeException(), isNull);
      // The widget tree renders a MiniBarChart at minimum.
      expect(find.byType(MiniBarChart), findsOneWidget);
    });

    testWidgets('value greater than maxValue does not cause bar overflow',
        (tester) async {
      // value (100) > maxValue (35) — bar height must be clamped.
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 200,
            child: MiniBarChart(
              points: const [(label: 'gen', value: 100.0)],
              color: MetraColors.light.accentFlow,
              maxValue: 35.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No overflow errors in the widget tree.
      expect(tester.takeException(), isNull);

      // The rendered bar widget (Container/SizedBox used for the bar)
      // must not exceed 80px in height — that's the spec-defined clamp ceiling.
      final barCandidates = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byType(MiniBarChart),
              matching: find.byType(SizedBox),
            ),
          )
          .where((w) => w.height != null && w.height! > 0)
          .toList();

      // At least one bar SizedBox must be present and none may exceed 80.
      expect(barCandidates, isNotEmpty);
      for (final bar in barCandidates) {
        expect(
          bar.height,
          lessThanOrEqualTo(80),
          reason: 'Bar height must be clamped to ≤ 80 when value > maxValue',
        );
      }
    });

    testWidgets('single data point renders label and value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MiniBarChart(
            points: const [(label: 'apr', value: 27.0)],
            color: MetraColors.light.accentPain,
            maxValue: 35.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('apr'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
    });
  });
}
