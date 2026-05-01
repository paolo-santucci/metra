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
import 'package:metra/features/stats/widgets/stat_card.dart';
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

void main() {
  group('StatSummaryCard', () {
    testWidgets('renders title text correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatSummaryCard(
            title: 'Durata media ciclo',
            value: '29',
            unit: 'giorni',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Durata media ciclo'), findsOneWidget);
    });

    testWidgets('renders value text correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatSummaryCard(
            title: 'Durata media ciclo',
            value: '29',
            unit: 'giorni',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('29'), findsOneWidget);
    });

    testWidgets('renders unit text correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatSummaryCard(
            title: 'Durata media ciclo',
            value: '29',
            unit: 'giorni',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('giorni'), findsOneWidget);
    });

    testWidgets('renders sub text when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatSummaryCard(
            title: 'Durata media ciclo',
            value: '29',
            unit: 'giorni',
            sub: 'min 28 — max 30',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('min 28 — max 30'), findsOneWidget);
    });

    testWidgets('does not render sub widget when sub is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatSummaryCard(
            title: 'Durata media ciclo',
            value: '29',
            unit: 'giorni',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The card must not contain any text beyond the three main strings.
      expect(find.text('Durata media ciclo'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
      expect(find.text('giorni'), findsOneWidget);
      // Widget tree must be shallow — confirm no extra Text widgets are present.
      final allText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(StatSummaryCard),
              matching: find.byType(Text),
            ),
          )
          .toList();
      // Only title, value, and unit — no sub.
      expect(allText.length, 3);
    });

    testWidgets('isAccent=true colors the value Text with a terracotta variant',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatSummaryCard(
            title: 'Durata media ciclo',
            value: '29',
            unit: 'giorni',
            isAccent: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locate the value Text widget.
      final valueText = tester.widget<Text>(find.text('29'));
      final valueColor = valueText.style?.color;

      // The accent value must be rendered in one of the terracotta tokens.
      // Both accentFlow (#C87456) and accentFlowText (#9A4D32) are valid —
      // the parallel widget author chooses the AA-compliant variant.
      const terracotta = MetraColors.light;
      expect(
        valueColor == terracotta.accentFlow ||
            valueColor == terracotta.accentFlowText ||
            valueColor == terracotta.terracotta ||
            valueColor == terracotta.terracottaDeep,
        isTrue,
        reason:
            'isAccent value should be colored with a terracotta palette token',
      );
    });

    testWidgets('isAccent=false (default) value Text is NOT a terracotta color',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatSummaryCard(
            title: 'Durata media ciclo',
            value: '29',
            unit: 'giorni',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final valueText = tester.widget<Text>(find.text('29'));
      final valueColor = valueText.style?.color;

      const terracotta = MetraColors.light;
      final isTerracotta = valueColor == terracotta.accentFlow ||
          valueColor == terracotta.accentFlowText ||
          valueColor == terracotta.terracotta ||
          valueColor == terracotta.terracottaDeep;
      expect(
        isTerracotta,
        isFalse,
        reason:
            'Non-accent value should not be colored with a terracotta token',
      );
    });
  });
}
