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
import 'package:google_fonts/google_fonts.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/theme/metra_colors.dart';

void main() {
  setUpAll(() {
    // Disable network fetching so google_fonts does not attempt HTTP calls.
    // Font-not-found errors are expected and non-fatal: these tests only exercise
    // ThemeData properties (colors, brightness), not font rendering.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('MetraTheme.light', () {
    testWidgets('brightness is light', (WidgetTester tester) async {
      final theme = MetraTheme.light();
      expect(theme.brightness, Brightness.light);
    });

    testWidgets('scaffold background is sand', (WidgetTester tester) async {
      final theme = MetraTheme.light();
      expect(theme.scaffoldBackgroundColor, MetraColors.light.sand);
    });

    testWidgets(
      'primary color is terracottaDeep (AA-compliant for text)',
      (WidgetTester tester) async {
        final theme = MetraTheme.light();
        expect(theme.colorScheme.primary, MetraColors.light.terracottaDeep);
      },
    );
  });

  group('MetraTheme.dark', () {
    testWidgets('brightness is dark', (WidgetTester tester) async {
      final theme = MetraTheme.dark();
      expect(theme.brightness, Brightness.dark);
    });

    testWidgets('scaffold background is deepNight',
        (WidgetTester tester) async {
      final theme = MetraTheme.dark();
      expect(theme.scaffoldBackgroundColor, MetraColors.dark.deepNight);
    });

    testWidgets(
      'primary color is mutedTerracottaSoft (AA-compliant for text)',
      (WidgetTester tester) async {
        final theme = MetraTheme.dark();
        expect(theme.colorScheme.primary, MetraColors.dark.mutedTerracottaSoft);
      },
    );
  });

  group('MetraTheme design contract', () {
    testWidgets(
      'light and dark themes have different scaffold backgrounds',
      (WidgetTester tester) async {
        expect(
          MetraTheme.light().scaffoldBackgroundColor,
          isNot(equals(MetraTheme.dark().scaffoldBackgroundColor)),
        );
      },
    );

    testWidgets(
      'no pure black in dark theme scaffold (warm brown-black)',
      (WidgetTester tester) async {
        expect(
          MetraTheme.dark().scaffoldBackgroundColor,
          isNot(equals(Colors.black)),
        );
      },
    );
  });
}
