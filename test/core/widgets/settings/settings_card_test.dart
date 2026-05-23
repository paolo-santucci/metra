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
import 'package:metra/core/theme/metra_spacing.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/settings/settings_card.dart';

Widget _wrap(Widget child, {ThemeMode themeMode = ThemeMode.light}) =>
    MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(body: child),
    );

void main() {
  group('SettingsCard', () {
    testWidgets(
      'renders 1px borderSubtle border, 16dp radius, surface bg, clip antiAlias',
      (tester) async {
        await tester.pumpWidget(
          _wrap(SettingsCard(children: [Container(height: 40)])),
        );

        final dec = tester
            .widget<DecoratedBox>(find.byType(DecoratedBox).first)
            .decoration as BoxDecoration;

        expect(dec.borderRadius, BorderRadius.circular(MetraRadius.lg));
        expect(dec.border!.top.width, 1.0);
        expect(dec.border!.top.color, MetraColors.light.borderSubtle);
        expect(dec.color, MetraColors.light.bgSurface);
      },
    );

    testWidgets('clip antiAlias is set', (tester) async {
      await tester.pumpWidget(
        _wrap(SettingsCard(children: [Container(height: 40)])),
      );

      // Container with decoration + clipBehavior: Clip.antiAlias renders
      // an internal ClipPath (not ClipRRect) in the widget tree.
      expect(find.byType(ClipPath), findsOneWidget);
    });

    testWidgets('has 24dp horizontal margin (MetraSpacing.s6)', (tester) async {
      await tester.pumpWidget(
        _wrap(SettingsCard(children: [Container(height: 40)])),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      final edgeInsets = padding.padding as EdgeInsets;
      expect(edgeInsets.left, MetraSpacing.s6);
      expect(edgeInsets.right, MetraSpacing.s6);
    });

    testWidgets(
      'dual-palette dark: resolves bgSurface and borderSubtle dark tokens',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SettingsCard(children: [Container(height: 40)]),
            themeMode: ThemeMode.dark,
          ),
        );

        final dec = tester
            .widget<DecoratedBox>(find.byType(DecoratedBox).first)
            .decoration as BoxDecoration;

        expect(dec.border!.top.color, MetraColors.dark.borderSubtle);
        expect(dec.color, MetraColors.dark.bgSurface);
      },
    );

    testWidgets('renders all children', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsCard(
            children: [
              SizedBox(key: ValueKey('child1'), height: 20),
              SizedBox(key: ValueKey('child2'), height: 20),
            ],
          ),
        ),
      );

      expect(find.byKey(const ValueKey('child1')), findsOneWidget);
      expect(find.byKey(const ValueKey('child2')), findsOneWidget);
    });
  });
}
