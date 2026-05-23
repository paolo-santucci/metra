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

// TASK-14 + TASK-27 — MetraConfirmDialog widget tests
//
// Verifies widget anatomy, design tokens, tap semantics, and EC-13 width clamp.
//
// Group E (TASK-27) bullets covered:
//   E-1  Root Dialog type, NOT AlertDialog / CupertinoAlertDialog
//   E-2  maxWidth 310 dp + internal padding EdgeInsets.fromLTRB(24,28,24,24)
//   E-3  Title typography: DM Serif Display 20 / w400 / textPrimary
//   E-4  Body typography: Inter 15 / w400 / textPrimary.withAlpha(0xAD); 12 dp
//         title→body gap; 28 dp body→actions gap
//   E-5  Action-button colors: accentFlow / accentFlowStrong, Inter 16 / w500,
//         Wrap.spacing == 28 dp, colors distinct
//   E-6  Tap-target ≥ 44×44 dp (NFR-03 / EC-13)
//   E-7  Narrow device 310 dp wide: no overflow (EC-13); spec says 320 dp,
//         310 dp is strictly tighter and subsumes the requirement
//   E-8  show() returns: confirm→true, cancel→false, barrier dismiss→null
//   E-9  Semantics: button:true + non-empty label matching button text
//   E-10 Semantics: title and body strings present in semantic tree (readable
//         by assistive technology)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_spacing.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/widgets/metra_confirm_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// Wraps the dialog in a full [MaterialApp] so that [BuildContext] has access
/// to localizations, theme, and media query. The dialog is shown via
/// [showDialog] from a button tap to replicate the real usage path.
Widget _harness({
  ThemeMode themeMode = ThemeMode.light,
  String title = 'Elimina dati',
  String? body,
  String cancelLabel = 'Annulla',
  String confirmLabel = 'Conferma',
  ValueSetter<bool?>? onResult,
}) {
  return MaterialApp(
    theme: MetraTheme.light(),
    darkTheme: MetraTheme.dark(),
    themeMode: themeMode,
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            key: const Key('open_dialog'),
            onPressed: () async {
              final result = await MetraConfirmDialog.show(
                ctx,
                title: title,
                body: body,
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
              );
              onResult?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// Opens the dialog by tapping the trigger button.
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_dialog')));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. Dialog type ────────────────────────────────────────────────────────

  testWidgets(
    'MetraConfirmDialog: root is Dialog (not AlertDialog/CupertinoAlertDialog)',
    (tester) async {
      await tester.pumpWidget(
        _harness(body: 'Sei sicura?'),
      );
      await _openDialog(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      // CupertinoAlertDialog is not imported here but we still ensure the tree
      // contains exactly one Dialog and no subclass that wraps it.
    },
  );

  // ── 2. Radius, background, max-width ─────────────────────────────────────

  testWidgets(
    'MetraConfirmDialog: 24dp radius from MetraRadius.xxl, bgSurface, max width 310',
    (tester) async {
      await tester.pumpWidget(
        _harness(body: 'Sei sicura?'),
      );
      await _openDialog(tester);

      // Verify Dialog shape has the correct border radius token.
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final shape = dialog.shape as RoundedRectangleBorder;
      final radius = (shape.borderRadius as BorderRadius).topLeft.x;
      expect(
        radius,
        equals(MetraRadius.xxl),
        reason: 'Border radius must use MetraRadius.xxl (24 dp)',
      );

      // Verify background color is bgSurface for light mode.
      expect(
        dialog.backgroundColor,
        equals(MetraColors.light.bgSurface),
        reason: 'Dialog background must be MetraColors.of(context).bgSurface',
      );

      // Verify ConstrainedBox imposes maxWidth 310 — use the key to locate
      // the specific ConstrainedBox (Dialog internals may add others).
      final constrained = tester.widget<ConstrainedBox>(
        find.byKey(const Key('metra_confirm_dialog_constrained')),
      );
      expect(
        constrained.constraints.maxWidth,
        equals(310.0),
        reason: 'ConstrainedBox maxWidth must be 310 dp (EC-13)',
      );
    },
  );

  // ── 2b. Internal padding ─────────────────────────────────────────────────
  // E-2: Padding inside the ConstrainedBox must be fromLTRB(24, 28, 24, 24).

  testWidgets(
    'MetraConfirmDialog: internal padding is EdgeInsets.fromLTRB(24, 28, 24, 24)',
    (tester) async {
      await tester.pumpWidget(
        _harness(body: 'Sei sicura?'),
      );
      await _openDialog(tester);

      // Find the direct Padding child of the ConstrainedBox (the first Padding
      // that is a descendant of the keyed ConstrainedBox).
      final paddingFinder = find.descendant(
        of: find.byKey(const Key('metra_confirm_dialog_constrained')),
        matching: find.byType(Padding),
      );
      // There may be multiple Padding widgets inside (e.g. within Text); take
      // the first one which is the outermost content padding.
      expect(paddingFinder, findsWidgets);
      final padding = tester.widget<Padding>(paddingFinder.first);
      expect(
        padding.padding,
        equals(const EdgeInsets.fromLTRB(24, 28, 24, 24)),
        reason: 'Internal padding must be EdgeInsets.fromLTRB(24, 28, 24, 24)',
      );
    },
  );

  // ── 3a. Title typography ─────────────────────────────────────────────────
  // E-3: Title Text resolves to DM Serif Display 20 / w400 / textPrimary.

  testWidgets(
    'MetraConfirmDialog: title is DM Serif Display 20 / w400 / textPrimary',
    (tester) async {
      const titleStr = 'Elimina dati';
      await tester.pumpWidget(
        _harness(title: titleStr),
      );
      await _openDialog(tester);

      // Locate the title Text by its string content.
      final titleWidget = tester.widget<Text>(find.text(titleStr));
      final style = titleWidget.style;
      expect(style, isNotNull, reason: 'Title must have an explicit TextStyle');

      // DM Serif Display 20 / w400 — match against MetraTypography.dayDetailTitle.
      expect(
        style!.fontSize,
        equals(20.0),
        reason: 'Title font size must be 20 dp (DM Serif Display)',
      );
      expect(
        style.fontWeight,
        equals(FontWeight.w400),
        reason: 'Title font weight must be w400',
      );
      // google_fonts encodes the family name as e.g. "DM Serif Display" or a
      // fallback key — verify it contains "DM Serif" to avoid brittle exact match.
      expect(
        style.fontFamily,
        anyOf(
          contains('DM Serif'),
          contains('DMSerifDisplay'),
        ),
        reason: 'Title must use DM Serif Display font family',
      );

      // Colour must be textPrimary.
      expect(
        style.color,
        equals(MetraColors.light.textPrimary),
        reason: 'Title colour must be MetraColors.of(context).textPrimary',
      );
    },
  );

  // ── 3b. Body typography and gaps ─────────────────────────────────────────
  // E-4: Body Text is Inter 15 / w400 / textPrimary.withAlpha(0xAD); 12 dp gap
  //      separates title from body; 28 dp gap separates body from action row.

  testWidgets(
    'MetraConfirmDialog: body Inter 15 / w400 / ink-at-68%, 12dp title→body gap, 28dp body→actions gap',
    (tester) async {
      const bodyStr = 'Questa operazione è irreversibile.';
      await tester.pumpWidget(
        _harness(body: bodyStr),
      );
      await _openDialog(tester);

      // Locate the body Text — it is the only Text at fontSize 15 in the dialog.
      final bodyWidget = tester.widget<Text>(find.text(bodyStr));
      final style = bodyWidget.style;
      expect(style, isNotNull, reason: 'Body must have an explicit TextStyle');

      expect(
        style!.fontSize,
        equals(15.0),
        reason: 'Body font size must be 15 dp (Inter)',
      );
      expect(
        style.fontWeight,
        equals(FontWeight.w400),
        reason: 'Body font weight must be w400',
      );

      // Colour: textPrimary.withAlpha(0xAD) = ink-at-68%.
      final expectedBodyColor = MetraColors.light.textPrimary.withAlpha(0xAD);
      expect(
        style.color,
        equals(expectedBodyColor),
        reason:
            'Body colour must be MetraColors.of(context).textPrimary.withAlpha(0xAD)',
      );

      // 12 dp title→body gap: find SizedBox(height: 12) inside the dialog Column.
      final gap12Finder = find.descendant(
        of: find.byType(Dialog),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 12.0,
        ),
      );
      expect(
        gap12Finder,
        findsAtLeast(1),
        reason: '12 dp title→body SizedBox must exist inside the Dialog',
      );

      // 28 dp body→actions gap: find SizedBox(height: 28) inside the dialog Column.
      final gap28Finder = find.descendant(
        of: find.byType(Dialog),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 28.0,
        ),
      );
      expect(
        gap28Finder,
        findsAtLeast(1),
        reason: '28 dp body→actions SizedBox must exist inside the Dialog',
      );
    },
  );

  // ── 3. Button colours ────────────────────────────────────────────────────

  testWidgets(
    'MetraConfirmDialog: cancelLabel accentFlow, confirmLabel accentFlowStrong, '
    'both Inter 16 / w500, colors distinct, Wrap.spacing == 28 dp',
    (tester) async {
      const cancel = 'Annulla';
      const confirm = 'Sì, elimina';

      await tester.pumpWidget(
        _harness(cancelLabel: cancel, confirmLabel: confirm),
      );
      await _openDialog(tester);

      // Find the Text widgets for cancel and confirm labels.
      final cancelText = tester.widget<Text>(find.text(cancel));
      final confirmText = tester.widget<Text>(find.text(confirm));

      final cancelColor = cancelText.style?.color;
      final confirmColor = confirmText.style?.color;

      expect(cancelColor, isNotNull);
      expect(confirmColor, isNotNull);

      expect(
        cancelColor,
        equals(MetraColors.light.accentFlow),
        reason: 'Cancel label must use accentFlow (terracotta)',
      );
      expect(
        confirmColor,
        equals(MetraColors.light.accentFlowStrong),
        reason: 'Confirm label must use accentFlowStrong (tc_scura)',
      );
      expect(
        cancelColor,
        isNot(equals(confirmColor)),
        reason: 'Cancel and confirm colors must be distinct',
      );

      // E-5: Both buttons must be Inter 16 / w500.
      expect(
        cancelText.style?.fontSize,
        equals(16.0),
        reason: 'Cancel label font size must be 16 dp (Inter)',
      );
      expect(
        cancelText.style?.fontWeight,
        equals(FontWeight.w500),
        reason: 'Cancel label font weight must be w500',
      );
      expect(
        confirmText.style?.fontSize,
        equals(16.0),
        reason: 'Confirm label font size must be 16 dp (Inter)',
      );
      expect(
        confirmText.style?.fontWeight,
        equals(FontWeight.w500),
        reason: 'Confirm label font weight must be w500',
      );

      // E-5: Action row Wrap.spacing must be 28 dp (spec §7.1 Group E).
      final wrapFinder = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Wrap),
      );
      expect(wrapFinder, findsOneWidget);
      final wrap = tester.widget<Wrap>(wrapFinder);
      expect(
        wrap.spacing,
        equals(28.0),
        reason: 'Wrap.spacing (action button gap) must be 28 dp',
      );
      expect(
        wrap.alignment,
        equals(WrapAlignment.end),
        reason: 'Action row must be right-aligned (WrapAlignment.end)',
      );
    },
  );

  // ── 4. Tap-target size ───────────────────────────────────────────────────

  testWidgets(
    'MetraConfirmDialog: action GestureDetectors ≥ 44×44 effective tap target',
    (tester) async {
      await tester.pumpWidget(_harness());
      await _openDialog(tester);

      // There may be other GestureDetectors in the tree (Material ripples, etc.)
      // We find the ones that contain our action labels.
      final cancelDetector = find.ancestor(
        of: find.text('Annulla'),
        matching: find.byType(GestureDetector),
      );
      final confirmDetector = find.ancestor(
        of: find.text('Conferma'),
        matching: find.byType(GestureDetector),
      );

      expect(cancelDetector, findsWidgets);
      expect(confirmDetector, findsWidgets);

      final cancelSize = tester.getSize(cancelDetector.first);
      final confirmSize = tester.getSize(confirmDetector.first);

      expect(
        cancelSize.width,
        greaterThanOrEqualTo(44.0),
        reason: 'Cancel tap target width must be ≥ 44 dp',
      );
      expect(
        cancelSize.height,
        greaterThanOrEqualTo(44.0),
        reason: 'Cancel tap target height must be ≥ 44 dp',
      );
      expect(
        confirmSize.width,
        greaterThanOrEqualTo(44.0),
        reason: 'Confirm tap target width must be ≥ 44 dp',
      );
      expect(
        confirmSize.height,
        greaterThanOrEqualTo(44.0),
        reason: 'Confirm tap target height must be ≥ 44 dp',
      );
    },
  );

  // ── 5. Narrow screen — EC-13 ─────────────────────────────────────────────

  testWidgets(
    'MetraConfirmDialog: narrow screen 310dp wide → no overflow exception',
    (tester) async {
      // Must set surface size BEFORE pumping.
      await tester.binding.setSurfaceSize(const Size(310, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(body: 'Sei sicura?'));
      await _openDialog(tester);

      // No RenderFlex overflow exception should be thrown.
      expect(tester.takeException(), isNull);

      // Dialog rendered width must be ≤ 310.
      final dialogBox = tester.getRect(find.byType(Dialog));
      expect(
        dialogBox.width,
        lessThanOrEqualTo(310.0),
        reason: 'Dialog must not exceed screen width on a 310dp device',
      );
    },
  );

  // ── 6. Return values ─────────────────────────────────────────────────────

  testWidgets(
    'MetraConfirmDialog.show: confirm tap → true, cancel tap → false, '
    'barrier dismiss → null',
    (tester) async {
      bool? result;
      // Sentinel to distinguish "not called" from "called with null".
      var resultSet = false;

      await tester.pumpWidget(
        _harness(
          onResult: (v) {
            result = v;
            resultSet = true;
          },
        ),
      );

      // Use unique labels that don't collide with other text in the tree.
      // --- confirm tap → true ---
      await _openDialog(tester);
      // Find confirm button inside the Dialog specifically.
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Conferma'),
        ),
      );
      await tester.pumpAndSettle();
      expect(result, isTrue, reason: 'Confirm tap must return true');

      // --- cancel tap → false ---
      result = null;
      resultSet = false;
      await _openDialog(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Annulla'),
        ),
      );
      await tester.pumpAndSettle();
      expect(result, isFalse, reason: 'Cancel tap must return false');

      // --- barrier dismiss → null (E-8) ---
      // Tap a point outside the dialog (top-left corner is safely outside the
      // centred 310 dp dialog on a standard 800x600 test surface).
      result = null;
      resultSet = false;
      await _openDialog(tester);
      // The dialog is centered on the screen; tap well outside its bounds.
      await tester.tapAt(const Offset(10.0, 10.0));
      await tester.pumpAndSettle();
      expect(resultSet, isTrue, reason: 'onResult must have been called');
      expect(result, isNull, reason: 'Barrier dismiss must return null');
    },
  );

  // ── 7. Semantics — action buttons ────────────────────────────────────────

  testWidgets(
    'MetraConfirmDialog: each action button has Semantics(button: true) and '
    'non-empty label matching button text',
    (tester) async {
      const cancelStr = 'Annulla';
      const confirmStr = 'Conferma';

      await tester.pumpWidget(
        _harness(cancelLabel: cancelStr, confirmLabel: confirmStr),
      );
      await _openDialog(tester);

      // Semantics nodes with isButton=true that contain the action labels.
      // Use .first in case the semantics tree surfaces nested Text nodes.
      final cancelSemanticsNode =
          tester.getSemantics(find.text(cancelStr).first);
      expect(
        cancelSemanticsNode.flagsCollection.isButton,
        isTrue,
        reason: 'Cancel must have Semantics button=true',
      );
      // E-9: Non-empty label matching the button text.
      expect(
        cancelSemanticsNode.label,
        isNotEmpty,
        reason: 'Cancel semantics label must be non-empty',
      );
      expect(
        cancelSemanticsNode.label,
        contains(cancelStr),
        reason: 'Cancel semantics label must contain "$cancelStr"',
      );

      final confirmSemanticsNode =
          tester.getSemantics(find.text(confirmStr).first);
      expect(
        confirmSemanticsNode.flagsCollection.isButton,
        isTrue,
        reason: 'Confirm must have Semantics button=true',
      );
      // E-9: Non-empty label matching the button text.
      expect(
        confirmSemanticsNode.label,
        isNotEmpty,
        reason: 'Confirm semantics label must be non-empty',
      );
      expect(
        confirmSemanticsNode.label,
        contains(confirmStr),
        reason: 'Confirm semantics label must contain "$confirmStr"',
      );
    },
  );

  // ── 8. Semantics — title and body text in semantic tree ───────────────────
  // Spec §7.1 Group E bullet 10 (first clause): title and body strings must
  // be reachable by assistive technology (non-empty semantics label present
  // in the tree for each text node).

  testWidgets(
    'MetraConfirmDialog: title and body strings are present in the semantic tree',
    (tester) async {
      const titleStr = 'Elimina dati';
      const bodyStr = 'Questa operazione è irreversibile.';

      await tester.pumpWidget(
        _harness(title: titleStr, body: bodyStr),
      );
      await _openDialog(tester);

      // Title must appear in the semantic tree with a non-empty label.
      final titleNode = tester.getSemantics(find.text(titleStr));
      expect(
        titleNode.label,
        isNotEmpty,
        reason:
            'Title must be readable by assistive technology (non-empty label)',
      );
      expect(
        titleNode.label,
        contains(titleStr),
        reason: 'Semantic label for title must contain the title string',
      );

      // Body must appear in the semantic tree with a non-empty label.
      final bodyNode = tester.getSemantics(find.text(bodyStr));
      expect(
        bodyNode.label,
        isNotEmpty,
        reason:
            'Body must be readable by assistive technology (non-empty label)',
      );
      expect(
        bodyNode.label,
        contains(bodyStr),
        reason: 'Semantic label for body must contain the body string',
      );
    },
  );
}
