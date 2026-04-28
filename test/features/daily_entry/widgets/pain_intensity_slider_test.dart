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
import 'package:metra/features/daily_entry/widgets/pain_intensity_slider.dart';
import 'package:metra/l10n/app_localizations.dart';

Widget _wrap({required bool enabled, int? value}) => MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PainIntensitySlider(
          enabled: enabled,
          value: value,
          onChanged: (_) {},
        ),
      ),
    );

void main() {
  group('PainIntensitySlider', () {
    testWidgets('renders nothing when enabled=false', (tester) async {
      await tester.pumpWidget(_wrap(enabled: false, value: 0));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNothing);
      expect(find.byType(SizedBox), findsWidgets); // SizedBox.shrink
    });

    testWidgets('renders slider and label when enabled=true', (tester) async {
      await tester.pumpWidget(_wrap(enabled: true, value: 1));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('label shows "Nessun dolore" when value=0', (tester) async {
      await tester.pumpWidget(_wrap(enabled: true, value: 0));
      await tester.pumpAndSettle();

      expect(find.text('Nessun dolore'), findsOneWidget);
    });

    testWidgets('label shows "Intenso" when value=3', (tester) async {
      await tester.pumpWidget(_wrap(enabled: true, value: 3));
      await tester.pumpAndSettle();

      expect(find.text('Intenso'), findsOneWidget);
    });
  });
}
