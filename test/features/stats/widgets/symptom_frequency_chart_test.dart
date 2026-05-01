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
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/features/stats/widgets/symptom_frequency_chart.dart';
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

// All symptoms with zero count — the "empty" case.
const _allZeroCounts = {
  PainSymptomType.cramps: 0,
  PainSymptomType.backPain: 0,
  PainSymptomType.headache: 0,
  PainSymptomType.migraine: 0,
  PainSymptomType.bloating: 0,
  PainSymptomType.fatigue: 0,
  PainSymptomType.nausea: 0,
  PainSymptomType.breastTenderness: 0,
};

void main() {
  group('SymptomFrequencyChart', () {
    testWidgets('shows "Dati insufficienti" when all symptom counts are zero',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SymptomFrequencyChart(
            counts: _allZeroCounts,
            totalCycles: 6,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dati insufficienti'), findsOneWidget);
    });

    testWidgets('shows "Dati insufficienti" when totalCycles is zero',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SymptomFrequencyChart(
            counts: {PainSymptomType.cramps: 3},
            totalCycles: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dati insufficienti'), findsOneWidget);
    });

    testWidgets('renders a row for each non-zero symptom', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SymptomFrequencyChart(
            counts: {
              PainSymptomType.cramps: 3,
              PainSymptomType.backPain: 2,
              PainSymptomType.headache: 0,
              PainSymptomType.bloating: 1,
              PainSymptomType.fatigue: 0,
            },
            totalCycles: 6,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Three non-zero symptoms: cramps (3), backPain (2), bloating (1).
      expect(find.text('Crampi'), findsOneWidget);
      expect(find.text('Mal di schiena'), findsOneWidget);
      expect(find.text('Gonfiore'), findsOneWidget);

      // Zero-count symptoms must not appear.
      expect(find.text('Mal di testa'), findsNothing);
      expect(find.text('Stanchezza'), findsNothing);
    });

    testWidgets('renders count/totalCycles fraction text correctly',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SymptomFrequencyChart(
            counts: {PainSymptomType.cramps: 3},
            totalCycles: 6,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3/6'), findsOneWidget);
    });

    testWidgets('renders fractions for multiple non-zero symptoms',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SymptomFrequencyChart(
            counts: {
              PainSymptomType.cramps: 4,
              PainSymptomType.backPain: 2,
              PainSymptomType.nausea: 1,
            },
            totalCycles: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4/5'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('1/5'), findsOneWidget);
    });

    testWidgets(
        'orders symptoms by descending count — highest count appears first',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SymptomFrequencyChart(
            counts: {
              PainSymptomType.nausea: 1,
              PainSymptomType.cramps: 4,
              PainSymptomType.backPain: 2,
            },
            totalCycles: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collect top-level positions to verify rendering order.
      final crampsFinder = find.text('Crampi');
      final backPainFinder = find.text('Mal di schiena');
      final nauseaFinder = find.text('Nausea');

      // All three are present.
      expect(crampsFinder, findsOneWidget);
      expect(backPainFinder, findsOneWidget);
      expect(nauseaFinder, findsOneWidget);

      // Vertical position: cramps (4) must appear above backPain (2),
      // which must appear above nausea (1).
      final crampsY = tester.getTopLeft(crampsFinder).dy;
      final backPainY = tester.getTopLeft(backPainFinder).dy;
      final nauseaY = tester.getTopLeft(nauseaFinder).dy;

      expect(
        crampsY,
        lessThan(backPainY),
        reason: 'cramps (count=4) must render above backPain (count=2)',
      );
      expect(
        backPainY,
        lessThan(nauseaY),
        reason: 'backPain (count=2) must render above nausea (count=1)',
      );
    });

    testWidgets('does not render "Dati insufficienti" when data is present',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SymptomFrequencyChart(
            counts: {PainSymptomType.cramps: 2},
            totalCycles: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dati insufficienti'), findsNothing);
    });
  });
}
