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

  // ── Optional center title slot (TASK-06 / CG-2) ──────────────────────────
  // The scaffold gains an OPTIONAL `String? title` param rendered as a
  // non-tappable center label (fontSize 17, w600, textPrimary). Existing
  // callers that pass title:null must be visually UNCHANGED.

  testWidgets(
    'CupertinoPickerScaffold: title=null renders no center title text',
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

      // Default toolbar labels still resolve correctly.
      expect(find.text('Ripristina'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // No additional text node should appear between the toolbar buttons.
      // All visible Text widgets in the toolbar are the button labels only.
      final allTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      // The only non-empty Text widgets in a default scaffold are the two
      // button labels. Extra text would indicate a phantom title.
      expect(
        allTexts.toSet(),
        equals({'Ripristina', 'OK'}),
        reason: 'title:null must not render any extra Text node',
      );
    },
  );

  testWidgets(
    'CupertinoPickerScaffold: title renders in center, is non-tappable, w600, textPrimary',
    (tester) async {
      const testTitle = 'Choose a provider';
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () {},
            onConfirm: () {},
            title: testTitle,
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();

      // Title text is visible.
      final titleFinder = find.text(testTitle);
      expect(
        titleFinder,
        findsOneWidget,
        reason: 'Center title must be rendered when title is non-null',
      );

      // Title is positioned between the two buttons (center).
      final resetDx = tester.getCenter(find.text('Ripristina')).dx;
      final confirmDx = tester.getCenter(find.text('OK')).dx;
      final titleDx = tester.getCenter(titleFinder).dx;
      expect(
        titleDx,
        greaterThan(resetDx),
        reason: 'Center title must be to the right of the reset button',
      );
      expect(
        titleDx,
        lessThan(confirmDx),
        reason: 'Center title must be to the left of the confirm button',
      );

      // Title is NOT inside a GestureDetector (non-tappable).
      final gdAncestors = find.ancestor(
        of: titleFinder,
        matching: find.byType(GestureDetector),
      );
      expect(
        gdAncestors,
        findsNothing,
        reason:
            'Center title must have NO GestureDetector ancestor (non-tappable)',
      );

      // Title text style: Inter 17 / w600 / textPrimary.
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(
        titleWidget.style?.fontWeight,
        FontWeight.w600,
        reason: 'Center title must use fontWeight w600 per §18.10.2',
      );
      expect(
        titleWidget.style?.fontSize,
        17.0,
        reason: 'Center title must use fontSize 17 per §18.10.2',
      );
      expect(
        titleWidget.style?.color,
        MetraColors.light.textPrimary,
        reason: 'Center title must use textPrimary (inchiostro) per §18.10.2',
      );

      // Existing buttons still fire (no regression from layout change).
      var resetFired = false;
      var confirmFired = false;
      await tester.pumpWidget(
        _wrap(
          CupertinoPickerScaffold(
            onReset: () => resetFired = true,
            onConfirm: () => confirmFired = true,
            title: testTitle,
            child: const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Ripristina'));
      await tester.pump();
      expect(resetFired, isTrue);
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(confirmFired, isTrue);
    },
  );
}
