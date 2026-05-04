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
import 'package:metra/features/calendar/widgets/calendar_legend.dart';
import 'package:metra/l10n/app_localizations.dart';

Widget _wrap(ThemeData theme) => MaterialApp(
      theme: theme,
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CalendarLegend()),
    );

void main() {
  group('CalendarLegend', () {
    testWidgets(
      'given_light_theme_when_rendered_then_flusso_label_is_visible',
      (tester) async {
        await tester.pumpWidget(_wrap(MetraTheme.light()));
        await tester.pump();
        expect(find.text('Flusso'), findsOneWidget);
      },
    );

    testWidgets(
      'given_light_theme_when_rendered_then_previsione_label_is_visible',
      (tester) async {
        await tester.pumpWidget(_wrap(MetraTheme.light()));
        await tester.pump();
        expect(find.text('Previsione'), findsOneWidget);
      },
    );

    testWidgets(
      'given_light_theme_when_rendered_then_sintomi_label_is_visible',
      (tester) async {
        await tester.pumpWidget(_wrap(MetraTheme.light()));
        await tester.pump();
        expect(find.text('Sintomi'), findsOneWidget);
      },
    );

    testWidgets(
      'given_light_theme_when_rendered_then_dolore_label_is_visible',
      (tester) async {
        await tester.pumpWidget(_wrap(MetraTheme.light()));
        await tester.pump();
        expect(find.text('Dolore'), findsOneWidget);
      },
    );

    testWidgets(
      'given_light_theme_when_rendered_then_note_label_is_visible',
      (tester) async {
        await tester.pumpWidget(_wrap(MetraTheme.light()));
        await tester.pump();
        expect(find.text('Note'), findsOneWidget);
      },
    );

    testWidgets(
      'given_dark_theme_when_rendered_then_all_five_labels_are_visible',
      (tester) async {
        await tester.pumpWidget(_wrap(MetraTheme.dark()));
        await tester.pump();
        expect(find.text('Flusso'), findsOneWidget);
        expect(find.text('Previsione'), findsOneWidget);
        expect(find.text('Sintomi'), findsOneWidget);
        expect(find.text('Dolore'), findsOneWidget);
        expect(find.text('Note'), findsOneWidget);
      },
    );
  });
}
