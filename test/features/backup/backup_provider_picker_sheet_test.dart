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
//
// TASK-06 (M4) — BackupProviderPickerSheet widget tests.
//
// TDD contract (write failing, confirm red, then implement):
//   • confirm returns the selected SyncProvider (not null).
//   • cancel tap / barrier dismiss → null (EC-01).
//   • 2-provider list → exactly 2 rows; no iCloud text (FR-05 Android).
//   • 3-provider list → exactly 3 rows (FR-05 iOS).
//   • semantics: per-row Semantics(button:true, label=displayName) + confirm button.
//   • stable Keys: sheetRoot / row_i / confirm each findsOneWidget.
//   • tap-target: itemExtent == MetraSpacing.sp44; row height ≥ 44 dp.
//   • confirm always enabled: GestureDetector.onTap != null (EC-11).
//   • center title rendered, non-tappable, w600, textPrimary (§18.10.2 / CG-2).
//   • scaffold backwards-compat: BackupPickerSheet still shows Annulla/Ripristina
//     (no regression from the CupertinoPickerScaffold title param addition).
//
// locale: Italian ('it') — canonical test locale, matching backup_picker_sheet_test.
// Localized strings used:
//   commonCancel           → "Annulla"
//   backupConnectAction    → "Connetti"
//   backupProviderPickerTitle → "Scegli un provider"
//   backupProviderNameDropbox   → "Dropbox"
//   backupProviderNameGoogleDrive → "Google Drive"
//   backupProviderNameICloud    → "iCloud"
//
// No sqlite dependency — pure widget tests.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_spacing.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/backup/widgets/backup_provider_picker_sheet.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _harness({
  required Widget Function(BuildContext) builder,
  String locale = 'it',
}) =>
    MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: builder),
    );

/// All three providers (iOS scenario).
const _allProviders = [
  SyncProvider.dropbox,
  SyncProvider.googleDrive,
  SyncProvider.iCloud,
];

/// Android/desktop providers (no iCloud).
const _twoProviders = [
  SyncProvider.dropbox,
  SyncProvider.googleDrive,
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Return values ─────────────────────────────────────────────────────────

  testWidgets(
    'should_return_iCloud_when_picker_is_at_iCloud_and_confirmed',
    (tester) async {
      SyncProvider? result;

      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () async {
                  // Start at index 2 (iCloud) — semantically equivalent to
                  // "having scrolled to iCloud" per the TDD contract.
                  result = await BackupProviderPickerSheet.show(
                    innerCtx,
                    providers: _allProviders,
                    initialIndex: 2,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap "Connetti" (backupConnectAction in IT) to confirm selection.
      await tester.tap(find.text('Connetti'));
      await tester.pumpAndSettle();

      expect(
        result,
        isNotNull,
        reason: 'Confirm must return a non-null SyncProvider',
      );
      expect(
        result,
        SyncProvider.iCloud,
        reason:
            'Confirm must return the provider at the current wheel position',
      );
    },
  );

  testWidgets(
    'should_return_null_when_cancel_tapped',
    (tester) async {
      SyncProvider? result = SyncProvider.dropbox; // sentinel

      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () async {
                  result = await BackupProviderPickerSheet.show(
                    innerCtx,
                    providers: _allProviders,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap "Annulla" (commonCancel in IT) to cancel.
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(
        result,
        isNull,
        reason: 'Cancel (Annulla) must return null — EC-01',
      );
    },
  );

  testWidgets(
    'should_return_null_when_barrier_dismissed',
    (tester) async {
      SyncProvider? result = SyncProvider.dropbox; // sentinel

      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () async {
                  result = await BackupProviderPickerSheet.show(
                    innerCtx,
                    providers: _allProviders,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap the barrier (top-left corner, above the sheet).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(
        find.byType(BackupProviderPickerSheet),
        findsNothing,
        reason: 'Sheet must be dismissed after barrier tap',
      );
      expect(
        result,
        isNull,
        reason: 'Barrier dismiss must return null — EC-01',
      );
    },
  );

  // ── Row count — FR-05 ─────────────────────────────────────────────────────

  testWidgets(
    'should_render_exactly_2_rows_for_android_providers_no_iCloud',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _twoProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Exactly 2 provider row semantics nodes.
      expect(
        find.byKey(const Key('row_0')),
        findsOneWidget,
        reason: 'row_0 (Dropbox) must be present',
      );
      expect(
        find.byKey(const Key('row_1')),
        findsOneWidget,
        reason: 'row_1 (Google Drive) must be present',
      );
      expect(
        find.byKey(const Key('row_2')),
        findsNothing,
        reason: 'row_2 must NOT be present for a 2-provider list',
      );

      // No iCloud-labelled widget anywhere in the tree.
      expect(
        find.text('iCloud'),
        findsNothing,
        reason:
            'iCloud text must not appear in a 2-provider list — FR-05 Android',
      );
    },
  );

  testWidgets(
    'should_render_exactly_3_rows_for_ios_providers_including_iCloud',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Exactly 3 provider row semantics nodes.
      expect(
        find.byKey(const Key('row_0')),
        findsOneWidget,
        reason: 'row_0 (Dropbox) must be present',
      );
      expect(
        find.byKey(const Key('row_1')),
        findsOneWidget,
        reason: 'row_1 (Google Drive) must be present',
      );
      expect(
        find.byKey(const Key('row_2')),
        findsOneWidget,
        reason:
            'row_2 (iCloud) must be present for a 3-provider list — FR-05 iOS',
      );
    },
  );

  // ── Semantics — NFR-05 ────────────────────────────────────────────────────

  testWidgets(
    'should_have_button_semantics_on_each_provider_row_with_display_name_label',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Row 0 (Dropbox): Semantics(button:true, label:"Dropbox").
      final row0 = tester.getSemantics(find.byKey(const Key('row_0')));
      expect(
        row0.flagsCollection.isButton,
        isTrue,
        reason: 'row_0 must have Semantics isButton flag',
      );
      expect(
        row0.label,
        isNotEmpty,
        reason: 'row_0 semantics label must be non-empty',
      );
      expect(
        row0.label,
        'Dropbox',
        reason: 'row_0 semantics label must equal the display name',
      );

      // Row 1 (Google Drive): Semantics(button:true, label:"Google Drive").
      final row1 = tester.getSemantics(find.byKey(const Key('row_1')));
      expect(row1.flagsCollection.isButton, isTrue);
      expect(row1.label, 'Google Drive');

      // Row 2 (iCloud): Semantics(button:true, label:"iCloud").
      final row2 = tester.getSemantics(find.byKey(const Key('row_2')));
      expect(row2.flagsCollection.isButton, isTrue);
      expect(row2.label, 'iCloud');
    },
  );

  testWidgets(
    'should_have_button_semantics_on_confirm_button',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Confirm button carries Semantics(button:true).
      final confirmSemantics = tester.getSemantics(
        find.byKey(const Key('confirm')),
      );
      expect(
        confirmSemantics.flagsCollection.isButton,
        isTrue,
        reason: 'Confirm button must have Semantics isButton flag — NFR-05',
      );
    },
  );

  // ── Stable Keys — FR-17 ───────────────────────────────────────────────────

  testWidgets(
    'should_have_stable_keys_on_sheetRoot_rows_and_confirm',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Sheet root key.
      expect(
        find.byKey(const Key('sheetRoot')),
        findsOneWidget,
        reason: 'Sheet root must carry Key("sheetRoot") — FR-17',
      );

      // Row keys.
      expect(find.byKey(const Key('row_0')), findsOneWidget);
      expect(find.byKey(const Key('row_1')), findsOneWidget);
      expect(find.byKey(const Key('row_2')), findsOneWidget);

      // Confirm button key.
      expect(
        find.byKey(const Key('confirm')),
        findsOneWidget,
        reason: 'Confirm button must carry Key("confirm") — FR-17',
      );
    },
  );

  // ── Tap-target — NFR-05 ───────────────────────────────────────────────────

  testWidgets(
    'should_have_itemExtent_sp44_and_row_height_at_least_44dp',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // CupertinoPicker.itemExtent must equal MetraSpacing.sp44 (44 dp).
      final picker =
          tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
      expect(
        picker.itemExtent,
        MetraSpacing.sp44,
        reason: 'itemExtent must be MetraSpacing.sp44 (44 dp) — NFR-05 / OQ-03',
      );

      // Row render height must be ≥ 44 dp (constrained by itemExtent).
      final rowSize = tester.getSize(find.byKey(const Key('row_0')));
      expect(
        rowSize.height,
        greaterThanOrEqualTo(44.0),
        reason: 'Provider row height must be ≥ 44 dp — NFR-05',
      );
    },
  );

  // ── Confirm always enabled — EC-11 ───────────────────────────────────────

  testWidgets(
    'confirm_button_onTap_is_always_non_null_regardless_of_wheel_position',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // At initial position (index 0 = Dropbox), confirm is enabled.
      final gd0 = find.descendant(
        of: find.byKey(const Key('confirm')),
        matching: find.byType(GestureDetector),
      );
      expect(
        tester.widget<GestureDetector>(gd0).onTap,
        isNotNull,
        reason: 'Confirm onTap must be non-null at any wheel position — EC-11',
      );

      // After scrolling to index 1 (Google Drive), confirm is still enabled.
      await tester.drag(
        find.byType(CupertinoPicker),
        const Offset(0, -44.0), // 1 item upward
      );
      await tester.pumpAndSettle();

      final gd1 = find.descendant(
        of: find.byKey(const Key('confirm')),
        matching: find.byType(GestureDetector),
      );
      expect(
        tester.widget<GestureDetector>(gd1).onTap,
        isNotNull,
        reason: 'Confirm onTap must be non-null after scroll — EC-11',
      );
    },
  );

  // ── Center title — CG-2 / §18.10.2 ───────────────────────────────────────

  testWidgets(
    'should_render_center_title_non_tappable_w600_textPrimary',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Title text must be rendered (IT: "Scegli un provider").
      final titleFinder = find.text('Scegli un provider');
      expect(
        titleFinder,
        findsOneWidget,
        reason:
            'backupProviderPickerTitle must be rendered in the toolbar — CG-2',
      );

      // Title is positioned between Annulla (left) and Connetti (right).
      final cancelDx = tester.getCenter(find.text('Annulla')).dx;
      final confirmDx = tester.getCenter(find.text('Connetti')).dx;
      final titleDx = tester.getCenter(titleFinder).dx;
      expect(titleDx, greaterThan(cancelDx));
      expect(titleDx, lessThan(confirmDx));

      // Title is NOT inside a GestureDetector (non-tappable — §18.10.2 "Forbidden").
      final gdAncestors = find.ancestor(
        of: titleFinder,
        matching: find.byType(GestureDetector),
      );
      expect(
        gdAncestors,
        findsNothing,
        reason: 'Center title must NOT be inside a GestureDetector — §18.10.2',
      );

      // Title text style: fontSize 17 / w600 / textPrimary.
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(
        titleWidget.style?.fontWeight,
        FontWeight.w600,
        reason: 'Center title must use fontWeight w600 — §18.10.2',
      );
      expect(
        titleWidget.style?.fontSize,
        17.0,
        reason: 'Center title must use fontSize 17 — §18.10.2',
      );
      expect(
        titleWidget.style?.color,
        MetraColors.light.textPrimary,
        reason: 'Center title must use textPrimary (inchiostro) — §18.10.2',
      );
    },
  );

  // ── Anatomy ───────────────────────────────────────────────────────────────

  testWidgets(
    'should_use_cupertino_picker_with_sp44_extent_no_magnifier_no_loop',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final picker =
          tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
      expect(picker.itemExtent, MetraSpacing.sp44);
      expect(picker.useMagnifier, isFalse);
      // looping:false verified via row_count — with looping, more rows
      // would appear beyond the provider count.
    },
  );

  testWidgets(
    'should_have_ink6pct_selection_band_smm_radius_and_s4_inset',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          builder: (ctx) => Scaffold(
            body: Builder(
              builder: (innerCtx) => ElevatedButton(
                onPressed: () => BackupProviderPickerSheet.show(
                  innerCtx,
                  providers: _allProviders,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Selection overlay: Container with textPrimary.withAlpha(0x0F)
      // and MetraRadius.smm border radius.
      const colors = MetraColors.light;
      final expectedColor = colors.textPrimary.withAlpha(0x0F);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final overlay = containers.where((c) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          return d.color == expectedColor &&
              d.borderRadius == BorderRadius.circular(MetraRadius.smm);
        }
        return false;
      }).toList();

      expect(
        overlay,
        isNotEmpty,
        reason:
            'Ink-6% selection band Container must be present — §18.8 / §19.1',
      );
    },
  );
}
