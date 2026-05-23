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

// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/settings/cupertino_picker_scaffold.dart';
import 'package:metra/l10n/app_localizations.dart';

/// Wraps [child] in a fully localised MaterialApp with Métra themes.
/// Defaults to Italian locale (primary app locale) so default labels
/// resolve to "Ripristina" / "OK" as per ARB keys.
Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      locale: const Locale('it'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  // ── Toolbar layout ────────────────────────────────────────────────────────

  testWidgets(
    'CupertinoPickerScaffold: Ripristina left + OK right, both Inter 16 w500 terracotta',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      // Both default labels must appear.
      expect(find.text('Ripristina'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Verify left/right positions: Ripristina must be to the left of OK.
      final resetOffset = tester.getCenter(find.text('Ripristina'));
      final confirmOffset = tester.getCenter(find.text('OK'));
      expect(resetOffset.dx, lessThan(confirmOffset.dx));

      // Verify text style: Inter 16 w500 terracotta.
      final expectedColor = MetraColors.light.accentFlow;
      final expectedStyle = GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: expectedColor,
      );

      // Find the Text widget for 'Ripristina' and inspect its resolved style.
      final resetText = tester.widget<Text>(find.text('Ripristina'));
      expect(resetText.style?.fontSize, expectedStyle.fontSize);
      expect(resetText.style?.fontWeight, expectedStyle.fontWeight);
      expect(resetText.style?.color, expectedColor);

      final confirmText = tester.widget<Text>(find.text('OK'));
      expect(confirmText.style?.fontSize, expectedStyle.fontSize);
      expect(confirmText.style?.fontWeight, expectedStyle.fontWeight);
      expect(confirmText.style?.color, expectedColor);
    },
  );

  // ── Tap interactions ──────────────────────────────────────────────────────

  testWidgets(
    'CupertinoPickerScaffold: onReset fires on Ripristina tap only',
    (tester) async {
      var resetCount = 0;
      var confirmCount = 0;

      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () => resetCount++,
            onConfirm: () => confirmCount++,
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Ripristina'));
      await tester.pump();

      expect(resetCount, 1);
      expect(confirmCount, 0);
    },
  );

  testWidgets(
    'CupertinoPickerScaffold: onConfirm fires on OK tap only',
    (tester) async {
      var resetCount = 0;
      var confirmCount = 0;

      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () => resetCount++,
            onConfirm: () => confirmCount++,
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(resetCount, 0);
      expect(confirmCount, 1);
    },
  );

  // ── useSafeArea ───────────────────────────────────────────────────────────

  testWidgets(
    'CupertinoPickerScaffold: useSafeArea parameter forwarded to scaffold body',
    (tester) async {
      // useSafeArea: false (default) — no SafeArea in the widget tree.
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            child: const SizedBox(key: ValueKey('child'), height: 200),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('child')),
          matching: find.byType(SafeArea),
        ),
        findsNothing,
      );

      // useSafeArea: true — child is wrapped in SafeArea.
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            useSafeArea: true,
            child: const SizedBox(key: ValueKey('child'), height: 200),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('child')),
          matching: find.byType(SafeArea),
        ),
        findsOneWidget,
      );
    },
  );

  // ── Tap targets ≥ 44 dp (regression guard for sp14 fix) ──────────────────
  // Both toolbar buttons must present a hit area at least 44 dp tall so
  // they meet iOS / WCAG touch-target minimums.

  testWidgets(
    'CupertinoPickerScaffold: Ripristina tap target height ≥ 44 dp',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      // The GestureDetector wrapping "Ripristina" has opaque hit-test
      // behaviour — its render height equals the Padding height.
      // Find GestureDetectors that are ancestors of the "Ripristina" text.
      final resetDetector = find.ancestor(
        of: find.text('Ripristina'),
        matching: find.byType(GestureDetector),
      );
      expect(resetDetector, findsAtLeastNWidgets(1));

      final height = tester.getSize(resetDetector.first).height;
      expect(
        height,
        greaterThanOrEqualTo(44.0),
        reason:
            'Ripristina tap target must be ≥ 44 dp (text 16px + 2×14dp padding = 44 dp)',
      );
    },
  );

  testWidgets(
    'CupertinoPickerScaffold: OK tap target height ≥ 44 dp',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      final confirmDetector = find.ancestor(
        of: find.text('OK'),
        matching: find.byType(GestureDetector),
      );
      expect(confirmDetector, findsAtLeastNWidgets(1));

      final height = tester.getSize(confirmDetector.first).height;
      expect(
        height,
        greaterThanOrEqualTo(44.0),
        reason:
            'OK tap target must be ≥ 44 dp (text 16px + 2×14dp padding = 44 dp)',
      );
    },
  );

  // ── Semantics(button: true) on both toolbar buttons ───────────────────────
  // After the TASK-33 fix, both Ripristina and OK are wrapped in
  // Semantics(button: true, label: ...). These tests guard the fix.

  testWidgets(
    'CupertinoPickerScaffold: Ripristina has Semantics isButton flag',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      // The Semantics widget wraps the GestureDetector for the reset button.
      // tester.getSemantics resolves the semantics data for the nearest
      // Semantics ancestor that carries flags/labels.
      final semantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Ripristina'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        semantics.flagsCollection.isButton,
        isTrue,
        reason: 'Ripristina button must have Semantics isButton flag',
      );
    },
  );

  testWidgets(
    'CupertinoPickerScaffold: OK has Semantics isButton flag',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      final semantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('OK'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        semantics.flagsCollection.isButton,
        isTrue,
        reason: 'OK button must have Semantics isButton flag',
      );
    },
  );

  // ── Background colour = bgPrimary ─────────────────────────────────────────

  testWidgets(
    'CupertinoPickerScaffold: background resolves to bgPrimary in light theme',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      // The ColoredBox is the direct child of the ClipRRect in
      // CupertinoPickerScaffold. Use .first to select it when
      // the widget tree also contains ColoredBox from MaterialApp.
      final coloredBox = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(ClipRRect),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(
        coloredBox.color,
        MetraColors.light.bgPrimary,
        reason: 'Scaffold background must be MetraColors.bgPrimary (sabbia)',
      );
    },
  );

  testWidgets(
    'CupertinoPickerScaffold: background resolves to bgPrimary in dark theme',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            child: const SizedBox(height: 200),
          ),
          theme: MetraTheme.dark(),
        ),
      );
      await tester.pump();

      final coloredBox = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(ClipRRect),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(
        coloredBox.color,
        MetraColors.dark.bgPrimary,
        reason:
            'Dark palette: scaffold background must be MetraColors.dark.bgPrimary',
      );
      // Confirm the dark palette token is distinct from the light one.
      expect(coloredBox.color, isNot(MetraColors.light.bgPrimary));
    },
  );
}
