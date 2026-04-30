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
import 'package:metra/features/daily_entry/widgets/circle_pain_picker.dart';
import 'package:metra/l10n/app_localizations.dart';

Widget _wrap({required int? selected, required ValueChanged<int?> onChanged}) =>
    MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CirclePainPicker(
          selected: selected,
          onChanged: onChanged,
        ),
      ),
    );

void main() {
  group('CirclePainPicker', () {
    testWidgets(
        'null state: renders all four circles without triggering onChanged',
        (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _wrap(selected: null, onChanged: (_) => callCount++),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nessuno'), findsOneWidget);
      expect(find.text('Lieve'), findsOneWidget);
      expect(find.text('Moderato'), findsOneWidget);
      expect(find.text('Intenso'), findsOneWidget);
      expect(callCount, 0);
    });

    testWidgets(
        'tapping circle 2 (Moderato) when unselected calls onChanged(2)',
        (tester) async {
      int? lastValue = -1;

      await tester.pumpWidget(
        _wrap(selected: null, onChanged: (v) => lastValue = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moderato'));
      await tester.pump();

      expect(lastValue, 2);
    });

    testWidgets(
        'tapping circle 2 (Moderato) when already selected calls onChanged(null)',
        (tester) async {
      int? lastValue = -1;

      await tester.pumpWidget(
        _wrap(selected: 2, onChanged: (v) => lastValue = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moderato'));
      await tester.pump();

      expect(lastValue, null);
    });

    testWidgets(
        'tapping circle 0 (Nessuno) when unselected calls onChanged(0)',
        (tester) async {
      int? lastValue = -1;

      await tester.pumpWidget(
        _wrap(selected: null, onChanged: (v) => lastValue = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nessuno'));
      await tester.pump();

      expect(lastValue, 0);
    });
  });
}
