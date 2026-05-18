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

// Group K — RestorePickerDialog §19 compliance tests (TASK-07)
//
// These tests exercise the six bible-compliance changes introduced in TASK-07:
// FR-01..FR-09, NFR-04 (widget anatomy), NFR-05 (single liveRegion), and the
// dialog surface tokens (elevation + borderRadius).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/widgets/restore_picker_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// Wraps [child] in the minimal theme + localisation environment (IT locale)
/// required by [RestorePickerDialog].
Widget _harness(Widget child) {
  return MaterialApp(
    theme: MetraTheme.light(),
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

/// Sets up a wide, tall test viewport (1080×3000 logical px) so dialog
/// content is never clipped.  Call [tearDownViewport] via addTearDown.
void setUpViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
}

void tearDownViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

/// Opens the dialog via [RestorePickerDialog.show] and returns after settle.
Future<void> _openDialog(
  WidgetTester tester,
  List<BackupFileEntry> entries,
) async {
  await tester.pumpWidget(
    _harness(
      Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => RestorePickerDialog.show(ctx, entries: entries),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

final _f1 = BackupFileEntry(
  name: 'newest.enc',
  timestampUtc: DateTime.utc(2026, 5, 17, 12),
  sizeBytes: 4096,
);
final _f2 = BackupFileEntry(
  name: 'mid.enc',
  timestampUtc: DateTime.utc(2026, 5, 16, 12),
  sizeBytes: 4096,
);
final _f3 = BackupFileEntry(
  name: 'oldest.enc',
  timestampUtc: DateTime.utc(2026, 5, 15, 12),
  sizeBytes: 4096,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // --- FR-01 + FR-02 — Title and body text ---------------------------------

  testWidgets('FR-01 — title reads restorePickerTitle (IT)', (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1, _f2]);

    // IT value: "Scegli versione"
    expect(find.text('Scegli versione'), findsOneWidget);
  });

  testWidgets('FR-02 — body text reads restorePickerBody (IT)', (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1, _f2]);

    expect(
      find.textContaining('Seleziona il backup da ripristinare'),
      findsOneWidget,
    );
  });

  // --- FR-03 — maxHeight 160 -----------------------------------------------

  testWidgets('FR-03 — list container maxHeight is 160, not 240',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1, _f2, _f3]);

    // Find the ConstrainedBox that has maxHeight == 160 (list area constraint).
    final boxes =
        tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
    final listBox = boxes.firstWhere(
      (b) => b.constraints.maxHeight == 160,
      orElse: () => throw TestFailure(
        'No ConstrainedBox with maxHeight == 160 found. '
        'Did you update the list container constraint?',
      ),
    );
    expect(listBox.constraints.maxHeight, equals(160.0));
  });

  // --- FR-04 — Badge on index-0 row only ------------------------------------

  testWidgets('FR-04 — badge "più recente" appears exactly once (newest row)',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1, _f2, _f3]);

    // IT value: "più recente"
    expect(find.text('più recente'), findsOneWidget);
  });

  testWidgets('FR-04 neg — badge appears once even with single entry',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1]);

    // With one entry, index 0 still gets the badge — still exactly one badge.
    expect(find.text('più recente'), findsOneWidget);
  });

  // --- FR-05 — Action row has exactly 3 TextButtons -------------------------

  testWidgets(
      'FR-05 — action row has Usa più recente, Annulla, Ripristina '
      'when files present', (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1, _f2]);

    expect(find.widgetWithText(TextButton, 'Usa più recente'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Annulla'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Ripristina'), findsOneWidget);
  });

  testWidgets('FR-09 — label is "Usa più recente" (not "Usa il più recente")',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1]);

    expect(find.text('Usa il più recente'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Usa più recente'), findsOneWidget);
  });

  testWidgets(
      'FR-08 — CTA label is "Ripristina" (not "Ripristina questa versione")',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1]);

    expect(find.text('Ripristina questa versione'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Ripristina'), findsOneWidget);
  });

  // --- FR-06 — semanticLabel ------------------------------------------------

  testWidgets('FR-06 — AlertDialog.semanticLabel == "Scelta versione backup"',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1, _f2]);

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.semanticLabel, equals('Scelta versione backup'));
  });

  // --- FR-07 — Empty state --------------------------------------------------

  testWidgets(
      'FR-07 — empty state: cloud icon + italic text + Chiudi only; '
      'no Ripristina, no Usa più recente', (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, const []);

    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(find.textContaining('Nessun backup'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Chiudi'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Ripristina'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Usa più recente'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Annulla'), findsNothing);
  });

  // --- NFR-05 — Single liveRegion in empty state ----------------------------

  testWidgets(
      'NFR-05 — empty state Semantics(liveRegion: true) present exactly once',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, const []);

    final liveRegions = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.liveRegion == true)
        .toList();
    expect(liveRegions.length, equals(1));
  });

  // --- NFR-04 — Dialog surface tokens (elevation + shape) -------------------

  testWidgets('NFR-04 — AlertDialog elevation == 0', (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1]);

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.elevation, equals(0.0));
  });

  testWidgets('NFR-04 — AlertDialog shape has borderRadius == 12',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1]);

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.shape, isA<RoundedRectangleBorder>());
    final shape = dialog.shape as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      equals(BorderRadius.circular(12)),
    );
  });

  // --- No hardcoded hex check (static) -------------------------------------

  test('no hardcoded hex literals in restore_picker_dialog.dart', () async {
    final src = await File(
      'lib/features/backup/widgets/restore_picker_dialog.dart',
    ).readAsString();
    // Match 0x followed by 6 or more hex digits (Flutter Color constructors)
    final hexPattern = RegExp(r'0x[0-9a-fA-F]{6,8}');
    expect(
      hexPattern.hasMatch(src),
      isFalse,
      reason:
          'Hardcoded hex color literal found. Use MetraColors / Theme instead.',
    );
  });

  // --- Interaction — UseNewest returns RestorePickNewest -------------------

  testWidgets('FR-09 — "Usa più recente" returns RestorePickNewest',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    RestorePickerOutcome? captured;

    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => RestorePickerDialog.show(ctx, entries: [_f1, _f2])
                .then((v) => captured = v),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Usa più recente'));
    await tester.pumpAndSettle();

    expect(captured, isA<RestorePickNewest>());
  });

  // --- Interaction — Annulla returns null -----------------------------------

  testWidgets('FR-07 — Annulla returns null (dialog dismissed)',
      (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    RestorePickerOutcome? captured = const RestorePickNewest(); // sentinel

    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => RestorePickerDialog.show(ctx, entries: [_f1])
                .then((v) => captured = v),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
    await tester.pumpAndSettle();

    expect(captured, isNull);
  });

  // --- Interaction — Chiudi in empty state closes dialog -------------------

  testWidgets('FR-07 — Chiudi in empty state closes dialog', (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, const []);

    await tester.tap(find.widgetWithText(TextButton, 'Chiudi'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  // --- All 5 anatomy elements present with ≥1 file -------------------------

  testWidgets(
      'NFR-04 — all 5 anatomy elements present with ≥1 file '
      '(title, body, list, useNewest, ripristina)', (tester) async {
    setUpViewport(tester);
    addTearDown(() => tearDownViewport(tester));

    await _openDialog(tester, [_f1, _f2, _f3]);

    // Element 1: title
    expect(find.text('Scegli versione'), findsOneWidget);
    // Element 2: body
    expect(
      find.textContaining('Seleziona il backup da ripristinare'),
      findsOneWidget,
    );
    // Element 3: list rows (at least one RadioListTile)
    expect(find.byType(RadioListTile<String>), findsAtLeastNWidgets(1));
    // Element 4: "Usa più recente"
    expect(find.widgetWithText(TextButton, 'Usa più recente'), findsOneWidget);
    // Element 5: "Ripristina"
    expect(find.widgetWithText(TextButton, 'Ripristina'), findsOneWidget);
  });
}
