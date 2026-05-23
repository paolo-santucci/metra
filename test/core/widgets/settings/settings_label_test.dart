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
import 'package:metra/core/theme/metra_typography.dart';
import 'package:metra/core/widgets/settings/settings_label.dart';

Widget _wrap(Widget child, {ThemeMode themeMode = ThemeMode.light}) =>
    MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets(
    'SettingsLabel first:false → top padding 24, bottom 12, uppercase, Inter 12 w600',
    (tester) async {
      await tester.pumpWidget(_wrap(const SettingsLabel('Account connesso')));
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(SettingsLabel),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect((padding.padding as EdgeInsets).top, 24);
      expect((padding.padding as EdgeInsets).bottom, 12);
      expect(find.text('ACCOUNT CONNESSO'), findsOneWidget);
    },
  );

  testWidgets('SettingsLabel first:true → top padding 8', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsLabel('Stato', first: true)));
    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(SettingsLabel),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect((padding.padding as EdgeInsets).top, 8);
  });

  testWidgets(
    'SettingsLabel left and right padding = 24 (MetraSpacing.s6)',
    (tester) async {
      await tester.pumpWidget(_wrap(const SettingsLabel('Preferenze')));
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(SettingsLabel),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect((padding.padding as EdgeInsets).left, 24);
      expect((padding.padding as EdgeInsets).right, 24);
    },
  );

  testWidgets('SettingsLabel marks text as semantic header', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsLabel('Sezione')));
    final semantics = tester.getSemantics(find.byType(Semantics).last);
    expect(semantics.flagsCollection.isHeader, isTrue);
  });

  // ── Typography (Group B) ──────────────────────────────────────────────────

  testWidgets(
    'SettingsLabel typography: Inter 12 / w600 / letterSpacing 0.72',
    (tester) async {
      await tester.pumpWidget(_wrap(const SettingsLabel('Preferenze')));
      await tester.pump();

      final textWidget = tester.widget<Text>(find.text('PREFERENZE'));
      final style = textWidget.style!;

      // MetraTypography.sectionLabel: Inter 12 / w600 / letterSpacing 0.72
      expect(style.fontSize, MetraTypography.sectionLabel.fontSize);
      expect(style.fontWeight, MetraTypography.sectionLabel.fontWeight);
      expect(style.letterSpacing, MetraTypography.sectionLabel.letterSpacing);
    },
  );

  // ── Colour (Group B) ─────────────────────────────────────────────────────

  testWidgets(
    'SettingsLabel colour: resolves to textSecondary (ink-at-40%) in light theme',
    (tester) async {
      await tester.pumpWidget(_wrap(const SettingsLabel('Stato')));
      await tester.pump();

      final element = tester.element(find.text('STATO'));
      final colors = MetraColors.of(element);

      final textWidget = tester.widget<Text>(find.text('STATO'));
      expect(
        textWidget.style!.color,
        colors.textSecondary,
        reason: 'Label must use MetraColors.of(context).textSecondary, '
            'not a hardcoded hex',
      );
    },
  );

  // ── Dual-palette dark (Group B) ───────────────────────────────────────────

  testWidgets(
    'SettingsLabel dual-palette dark: resolves dark textSecondary token',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsLabel('Account connesso'),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();

      final element = tester.element(find.text('ACCOUNT CONNESSO'));
      final colors = MetraColors.of(element);

      final textWidget = tester.widget<Text>(find.text('ACCOUNT CONNESSO'));
      expect(
        textWidget.style!.color,
        colors.textSecondary,
        reason: 'Dark palette: label must use dark textSecondary token',
      );

      // Confirm we are actually in the dark palette: dark textSecondary
      // must differ from light textSecondary.
      expect(colors.textSecondary, isNot(MetraColors.light.textSecondary));
    },
  );
}
