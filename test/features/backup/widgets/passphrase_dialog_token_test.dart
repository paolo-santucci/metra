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

// TASK-16 — PassphraseDialog token regression tests
//
// Verifies that the mismatch error text in `setNew` mode uses the
// `MetraColors.of(context).accentFlowStrong` design token instead of the
// previously hardcoded `Colors.red`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/widgets/passphrase_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

Widget _harness(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: MetraTheme.light(),
    darkTheme: MetraTheme.dark(),
    themeMode: themeMode,
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps [PassphraseDialog] in [setNew] mode, enters two non-matching
/// passphrases (both ≥ 8 chars to skip the length check), and pumps again
/// so the mismatch error is rendered.
Future<void> _triggerMismatch(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    _harness(
      PassphraseDialog(
        mode: PassphraseDialogMode.setNew,
        onConfirmed: (_) {},
      ),
      themeMode: themeMode,
    ),
  );

  // Enter 8+ chars in the first (passphrase) field.
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Passphrase1');
  await tester.pump();

  // Enter a different 8+ chars in the second (confirm) field.
  await tester.enterText(fields.at(1), 'Passphrase2');
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Grep test ────────────────────────────────────────────────────────────

  test('passphrase_dialog.dart contains no Colors.red occurrence', () {
    final src = File(
      'lib/features/backup/widgets/passphrase_dialog.dart',
    ).readAsStringSync();
    expect(
      RegExp(r'Colors\.red').hasMatch(src),
      isFalse,
      reason:
          'Colors.red must be replaced with MetraColors.of(context).accentFlowStrong',
    );
  });

  // ── Widget tests — light mode ─────────────────────────────────────────

  testWidgets(
    'PassphraseDialog mismatch error text uses accentFlowStrong (light)',
    (tester) async {
      await _triggerMismatch(tester);

      // Locate the mismatch error Text widget — it is the only Text outside the
      // dialog title/body/buttons that appears only when _error is set.
      final errorTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data?.contains('corrispondono') == true)
          .toList();
      expect(
        errorTexts,
        hasLength(1),
        reason: 'Expected exactly one mismatch error Text',
      );

      final errorText = errorTexts.first;
      final resolvedColor = errorText.style?.color;

      expect(
        resolvedColor,
        isNotNull,
        reason: 'Error text style color must not be null',
      );
      expect(
        resolvedColor,
        equals(MetraColors.light.accentFlowStrong),
        reason:
            'Error text color must equal MetraColors.light.accentFlowStrong',
      );
    },
  );

  testWidgets(
    'PassphraseDialog mismatch error text uses accentFlowStrong (dark)',
    (tester) async {
      await _triggerMismatch(tester, themeMode: ThemeMode.dark);

      final errorTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data?.contains('corrispondono') == true)
          .toList();
      expect(
        errorTexts,
        hasLength(1),
        reason: 'Expected exactly one mismatch error Text',
      );

      final errorText = errorTexts.first;
      final resolvedColor = errorText.style?.color;

      expect(
        resolvedColor,
        isNotNull,
        reason: 'Error text style color must not be null',
      );
      expect(
        resolvedColor,
        equals(MetraColors.dark.accentFlowStrong),
        reason: 'Error text color must equal MetraColors.dark.accentFlowStrong',
      );
    },
  );
}
