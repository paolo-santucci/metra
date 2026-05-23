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

// TASK-23 — Group A token tests (FR-01, FR-02)
//
// Covers:
//  • MetraSpacing.sp44 == 44.0 static const double
//  • MetraRadius.xxl == 24.0 static const double
//  • StatusIndicator and BackupPickerSheet reference MetraSpacing.sp44 by name
//  • MetraConfirmDialog renders BorderRadius.circular(MetraRadius.xxl) — not a
//    literal 24 — verified via the widget tree's Dialog.shape

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_spacing.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/widgets/metra_confirm_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _harness(Widget child) {
  return MaterialApp(
    theme: MetraTheme.light(),
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Group A / FR-01: MetraSpacing.sp44 ──────────────────────────────────

  group('MetraSpacing', () {
    test('MetraSpacing.sp44 equals 44.0 and is static const double', () {
      expect(MetraSpacing.sp44, 44.0);
      expect(MetraSpacing.sp44, isA<double>());
      // Compile-time const-correctness:
      const _ = MetraSpacing.sp44;
    });

    test('StatusIndicator references MetraSpacing.sp44 (not a literal 44)', () {
      final src = File(
        'lib/features/backup/widgets/status_indicator.dart',
      ).readAsStringSync();
      expect(
        src.contains('MetraSpacing.sp44'),
        isTrue,
        reason:
            'StatusIndicator must reference MetraSpacing.sp44 as its sizing source',
      );
    });

    test(
      'BackupPickerSheet (including internals) references MetraSpacing.sp44 '
      'for itemExtent and selection-overlay height',
      () {
        // BackupPickerSheet delegates layout to backup_picker_sheet_internals.dart —
        // the CupertinoPicker itemExtent and the selection overlay height live there.
        final internals = File(
          'lib/features/backup/widgets/backup_picker_sheet_internals.dart',
        ).readAsStringSync();
        expect(
          internals.contains('MetraSpacing.sp44'),
          isTrue,
          reason:
              'backup_picker_sheet_internals.dart must reference MetraSpacing.sp44 '
              'for CupertinoPicker itemExtent and row heights',
        );
      },
    );
  });

  // ── Group A / FR-02: MetraRadius.xxl ────────────────────────────────────

  group('MetraRadius', () {
    test('MetraRadius.xxl equals 24.0 and is static const double', () {
      expect(MetraRadius.xxl, 24.0);
      expect(MetraRadius.xxl, isA<double>());
      // Compile-time const-correctness:
      const _ = MetraRadius.xxl;
    });
  });

  group('MetraConfirmDialog — MetraRadius.xxl border radius (FR-02)', () {
    testWidgets(
      'MetraConfirmDialog Dialog shape has corner radius == MetraRadius.xxl',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    MetraConfirmDialog.show(context, title: 'Test'),
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The dialog must be in the tree.
        final dialog = tester.widget<Dialog>(find.byType(Dialog));

        // shape must be RoundedRectangleBorder with BorderRadius.circular(xxl)
        final shape = dialog.shape as RoundedRectangleBorder;
        final br = shape.borderRadius as BorderRadius;

        expect(
          br.topLeft.x,
          MetraRadius.xxl,
          reason: 'Dialog corner radius must equal MetraRadius.xxl '
              '(${MetraRadius.xxl} dp). '
              'The token check (no literal 24 in source) is in '
              'test/static/token_discipline_test.dart.',
        );
      },
    );
  });
}
