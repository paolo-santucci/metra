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
import 'package:metra/core/widgets/settings/settings_divider.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? MetraTheme.light(),
      home: Scaffold(body: SizedBox(width: 400, child: child)),
    );

void main() {
  testWidgets('SettingsDivider is 1 dp tall', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsDivider()));
    final size = tester.getSize(find.byType(SettingsDivider));
    expect(size.height, 1.0);
  });

  testWidgets('SettingsDivider resolves borderSubtle colour in light theme',
      (tester) async {
    await tester.pumpWidget(_wrap(const SettingsDivider()));
    // The widget is a Container; locate the underlying ColoredBox or Container.
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(SettingsDivider),
        matching: find.byType(Container),
      ),
    );
    expect(container.color, MetraColors.light.borderSubtle);
  });

  testWidgets('SettingsDivider resolves borderSubtle colour in dark theme',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const SettingsDivider(), theme: MetraTheme.dark()),
    );
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(SettingsDivider),
        matching: find.byType(Container),
      ),
    );
    expect(container.color, MetraColors.dark.borderSubtle);
  });

  // ── No horizontal indent (Group B) ───────────────────────────────────────
  // Spec: "No horizontal indent; spans the full card width."
  // The Container must have no margin/padding that would create an offset line.

  testWidgets('SettingsDivider has no horizontal indent or margin',
      (tester) async {
    // Give the parent a known width so we can measure alignment.
    const parentWidth = 400.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: MetraTheme.light(),
        home: const Scaffold(
          body: SizedBox(width: parentWidth, child: SettingsDivider()),
        ),
      ),
    );
    await tester.pump();

    // The Container backing the divider must fill the parent width — no
    // margin or padding that would reduce it.
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(SettingsDivider),
        matching: find.byType(Container),
      ),
    );

    // margin and padding should both be null/zero — no indent.
    final margin = container.margin;
    final padding = container.padding;

    if (margin != null) {
      final resolved = margin.resolve(TextDirection.ltr);
      expect(
        resolved.left,
        0.0,
        reason: 'SettingsDivider must not have a left margin (no indent)',
      );
      expect(
        resolved.right,
        0.0,
        reason: 'SettingsDivider must not have a right margin (no indent)',
      );
    }

    if (padding != null) {
      final resolved = padding.resolve(TextDirection.ltr);
      expect(
        resolved.left,
        0.0,
        reason: 'SettingsDivider must not have left padding (no indent)',
      );
      expect(
        resolved.right,
        0.0,
        reason: 'SettingsDivider must not have right padding (no indent)',
      );
    }

    // The divider's render width equals the parent's width (full-bleed).
    final size = tester.getSize(find.byType(SettingsDivider));
    expect(
      size.width,
      parentWidth,
      reason: 'SettingsDivider should span the full container width',
    );
  });
}
