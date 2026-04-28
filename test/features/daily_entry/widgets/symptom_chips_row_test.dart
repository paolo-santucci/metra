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
import 'package:metra/core/widgets/choice_chip_metra.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/features/daily_entry/widgets/symptom_chips_row.dart';
import 'package:metra/l10n/app_localizations.dart';

// Stateful wrapper so we can test multi-select interactions.
class _SymptomChipsWrapper extends StatefulWidget {
  const _SymptomChipsWrapper({this.initial = const {}});

  final Set<PainSymptomType> initial;

  @override
  State<_SymptomChipsWrapper> createState() => _SymptomChipsWrapperState();
}

class _SymptomChipsWrapperState extends State<_SymptomChipsWrapper> {
  late Set<PainSymptomType> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return SymptomChipsRow(
      selected: _selected,
      onChanged: (updated) => setState(() => _selected = updated),
    );
  }
}

Widget _wrap({Set<PainSymptomType> initial = const {}}) => MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _SymptomChipsWrapper(initial: initial)),
    );

void main() {
  group('SymptomChipsRow', () {
    testWidgets('renders chips for all fixed PainSymptomType values',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // SymptomChipsRow shows 5 fixed types (custom is excluded).
      expect(find.text('Crampi'), findsOneWidget);
      expect(find.text('Mal di schiena'), findsOneWidget);
      expect(find.text('Mal di testa'), findsOneWidget);
      expect(find.text('Emicrania'), findsOneWidget);
      expect(find.text('Gonfiore'), findsOneWidget);
    });

    testWidgets('tapping a chip adds it to the selection', (tester) async {
      Set<PainSymptomType>? lastChanged;

      await tester.pumpWidget(
        MaterialApp(
          theme: MetraTheme.light(),
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SymptomChipsRow(
              selected: const {},
              onChanged: (s) => lastChanged = s,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crampi'));
      await tester.pumpAndSettle();

      expect(lastChanged, contains(PainSymptomType.cramps));
    });

    testWidgets('tapping a selected chip removes it from the selection',
        (tester) async {
      Set<PainSymptomType>? lastChanged;

      await tester.pumpWidget(
        MaterialApp(
          theme: MetraTheme.light(),
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SymptomChipsRow(
              selected: const {PainSymptomType.cramps},
              onChanged: (s) => lastChanged = s,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crampi'));
      await tester.pumpAndSettle();

      expect(lastChanged, isNotNull);
      expect(lastChanged!, isNot(contains(PainSymptomType.cramps)));
    });

    testWidgets('multiple chips can be selected simultaneously', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crampi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emicrania'));
      await tester.pumpAndSettle();

      // Verify both ChoiceChipMetra widgets report selected=true.
      // This distinguishes genuine multi-select from a radio (single-select) implementation.
      final crampsChip = tester.widget<ChoiceChipMetra>(
        find.ancestor(
          of: find.text('Crampi'),
          matching: find.byType(ChoiceChipMetra),
        ),
      );
      final migraineChip = tester.widget<ChoiceChipMetra>(
        find.ancestor(
          of: find.text('Emicrania'),
          matching: find.byType(ChoiceChipMetra),
        ),
      );
      expect(crampsChip.selected, isTrue);
      expect(migraineChip.selected, isTrue);
    });
  });
}
