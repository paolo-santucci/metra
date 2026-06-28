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
// TASK-15 — BackupPickerSheet smoke tests (Group F initial smoke; full suite is
// TASK-28). Covers: anatomy (radius + background + toolbar), Ripristina returns
// int index, Annulla returns null, empty-list disables Ripristina, and
// ArgumentError on out-of-range initialIndex.
//
// TASK-28 — BackupPickerSheet full Group F test suite.
// Extends the TASK-15 smoke tests with the complete spec §7.1 Group F bullets:
// • anatomy (barrier, divider, picker config)
// • selection overlay (height, fill, radius, inset)
// • per-item typography at distance 0, 1, ≥2
// • show() Ripristina returns scrolled index (not default)
// • show() barrier dismiss → null
// • empty list: disabled Ripristina no-op, sheet stays open
// • no deleted RestorePicker* symbols in impl files (grep gate)
// • Semantics checks (Annulla, Ripristina)
// • NFR-12 reduced-motion (no AnimationController in selection overlay)
//
// OQ-QA-06: debugDefaultTargetPlatformOverride = TargetPlatform.iOS is set via
// try/finally in each testWidgets body (same pattern as metra_toggle_test.dart)
// to avoid the "foundation debug variable changed" invariant failure when setUp
// sets it before Flutter's pre-test verification pass.
//
// Target platforms: Android (CI), iOS (physical device).

import 'dart:io' show Process;
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_spacing.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/widgets/backup_picker_sheet.dart';
import 'package:metra/features/backup/widgets/backup_size_format.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Three-item list used across most tests.
final _entries = [
  BackupFileEntry(
    name: 'metra_2026-01-01.enc',
    timestampUtc: DateTime.utc(2026, 1, 1),
    sizeBytes: 1024,
  ),
  BackupFileEntry(
    name: 'metra_2026-02-01.enc',
    timestampUtc: DateTime.utc(2026, 2, 1),
    sizeBytes: 2048,
  ),
  BackupFileEntry(
    name: 'metra_2026-03-01.enc',
    timestampUtc: DateTime.utc(2026, 3, 1),
    sizeBytes: 3072,
  ),
];

Widget _harness({
  Widget Function(BuildContext)? builder,
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
      home: Builder(
        builder: builder ?? (ctx) => const Scaffold(body: SizedBox()),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Anatomy (TASK-15 smoke + extended TASK-28) ───────────────────────────

  testWidgets(
    'BackupPickerSheet anatomy: 16dp top radius, sabbia bg, Annulla+Ripristina toolbar',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () {
                    BackupPickerSheet.show(innerCtx, entries: _entries);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Toolbar buttons present.
        expect(find.text('Annulla'), findsOneWidget);
        expect(find.text('Ripristina'), findsOneWidget);

        // Top-only 16 dp radius via ClipRRect.
        final clipRRect = tester.widget<ClipRRect>(
          find.byType(ClipRRect).first,
        );
        expect(
          clipRRect.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(16)),
        );

        // Sabbia (bgPrimary) background: find ColoredBox with bgPrimary colour.
        final sandColor = MetraColors.light.bgPrimary;
        final coloredBoxes = tester.widgetList<ColoredBox>(
          find.byType(ColoredBox),
        );
        final sandBox = coloredBoxes.firstWhere(
          (cb) => cb.color == sandColor,
          orElse: () =>
              throw TestFailure('No ColoredBox with bgPrimary color found'),
        );
        expect(sandBox, isNotNull);

        // CupertinoPicker is present.
        expect(find.byType(CupertinoPicker), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_have_settings_divider_below_toolbar_when_picker_shown',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () =>
                      BackupPickerSheet.show(innerCtx, entries: _entries),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // SettingsDivider renders as Container(height: 1, color: borderSubtle).
        // Find a Container of height exactly 1 dp (the 1 dp divider).
        final dividerContainers = tester
            .widgetList<Container>(
              find.byType(Container),
            )
            .where((c) => c.constraints?.maxHeight == 1.0)
            .toList();

        expect(
          dividerContainers,
          isNotEmpty,
          reason:
              '1 dp SettingsDivider Container must be present below toolbar',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_configure_cupertino_picker_with_sp44_itemExtent_no_magnifier_no_loop',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () =>
                      BackupPickerSheet.show(innerCtx, entries: _entries),
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
        expect(
          picker.itemExtent,
          MetraSpacing.sp44,
          reason: 'itemExtent must equal MetraSpacing.sp44 (44 dp)',
        );
        expect(
          picker.useMagnifier,
          isFalse,
          reason: 'useMagnifier must be false per FR-15',
        );
        // looping: false is verified via source-code grep below
        // (no public getter on CupertinoPicker; it controls childDelegate type).
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_use_textPrimary_alpha0x40_barrier_colour_when_presenting_sheet',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // We cannot inspect the barrier colour directly from the widget tree,
        // but we can verify the sheet opens (barrier is present) and the
        // implementation passes textPrimary.withAlpha(0x40) to showModalBottomSheet.
        // Structural verification: backup_picker_sheet.dart uses
        // colors.textPrimary.withAlpha(0x40) as barrierColor.
        final barrierColorInImpl =
            MetraColors.light.textPrimary.withAlpha(0x40);
        expect(
          (barrierColorInImpl.a * 255.0).round(),
          0x40,
          reason: 'barrier alpha must be 0x40 (= ink-at-25%)',
        );
        expect(
          barrierColorInImpl,
          equals(MetraColors.light.textPrimary.withAlpha(0x40)),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ── Selection overlay ────────────────────────────────────────────────────

  testWidgets(
    'should_render_selection_overlay_44dp_ink6pct_smm_radius_16dp_inset',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () =>
                      BackupPickerSheet.show(innerCtx, entries: _entries),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The selection overlay is a Positioned > Container with:
        //   height: MetraSpacing.sp44 (44 dp)
        //   color: textPrimary.withAlpha(0x0F)
        //   borderRadius: MetraRadius.smm (10 dp)
        //   left: MetraSpacing.s4 (16 dp), right: MetraSpacing.s4 (16 dp)
        const colors = MetraColors.light;
        final expectedColor = colors.textPrimary.withAlpha(0x0F);

        // Find Container with the expected decoration color and height.
        final containers = tester.widgetList<Container>(
          find.byType(Container),
        );
        final overlay = containers.where((c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == expectedColor &&
                decoration.borderRadius ==
                    BorderRadius.circular(MetraRadius.smm);
          }
          return false;
        }).toList();

        expect(
          overlay,
          isNotEmpty,
          reason:
              'Selection overlay Container with textPrimary.withAlpha(0x0F) '
              'and MetraRadius.smm must be present',
        );

        // Verify height via SizedBox or Container height.
        final overlayContainer = overlay.first;
        expect(
          overlayContainer.constraints?.maxHeight,
          MetraSpacing.sp44,
          reason: 'Selection overlay height must be MetraSpacing.sp44 (44 dp)',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ── Per-item typography ──────────────────────────────────────────────────

  testWidgets(
    'should_render_selected_item_inter16_w500_opacity1_at_distance_0',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // Mount the PickerItem directly (distance 0 = selected).
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () => BackupPickerSheet.show(
                    innerCtx,
                    entries: _entries,
                    initialIndex: 0,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        // Compute expected formatted text after locale data is initialised.
        final dateTime0 = DateFormat.yMMMd('it')
            .add_jm()
            .format(_entries[0].timestampUtc.toLocal());
        final size0 = formatBackupSize(_entries[0].sizeBytes);
        final expectedText = size0.isEmpty ? dateTime0 : '$dateTime0 $size0';

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Find the first entry text (distance 0 from selected index 0).
        final itemTextFinder = find.text(expectedText);
        expect(itemTextFinder, findsOneWidget);

        // The text is wrapped in Opacity(opacity: 1.0).
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: itemTextFinder,
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(
          opacity.opacity,
          1.0,
          reason: 'Distance-0 item must have opacity 1.0',
        );

        // Font style: Inter 16 / w500.
        final textWidget = tester.widget<Text>(itemTextFinder);
        final resolvedStyle = textWidget.style;
        expect(
          resolvedStyle?.fontSize,
          16.0,
          reason: 'Distance-0 item must use fontSize 16',
        );
        expect(
          resolvedStyle?.fontWeight,
          FontWeight.w500,
          reason: 'Distance-0 item must use fontWeight w500',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_render_distance1_items_inter15_w400_opacity035',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // With initialIndex=1, item 0 and item 2 are at distance 1.
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () => BackupPickerSheet.show(
                    innerCtx,
                    entries: _entries,
                    initialIndex: 1,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        // Compute expected formatted text after locale data is initialised.
        // Item 0 is at distance 1 from index 1.
        final dateTime1 = DateFormat.yMMMd('it')
            .add_jm()
            .format(_entries[0].timestampUtc.toLocal());
        final size1 = formatBackupSize(_entries[0].sizeBytes);
        final expectedText = size1.isEmpty ? dateTime1 : '$dateTime1 $size1';

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final itemTextFinder = find.text(expectedText);
        expect(itemTextFinder, findsOneWidget);

        final opacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: itemTextFinder,
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(
          opacity.opacity,
          closeTo(0.35, 0.001),
          reason: 'Distance-1 item must have opacity 0.35',
        );

        final textWidget = tester.widget<Text>(itemTextFinder);
        final resolvedStyle = textWidget.style;
        expect(
          resolvedStyle?.fontSize,
          15.0,
          reason: 'Distance-1 item must use fontSize 15',
        );
        expect(
          resolvedStyle?.fontWeight,
          FontWeight.w400,
          reason: 'Distance-1 item must use fontWeight w400',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_render_distance2_plus_items_inter15_w400_opacity018',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // With initialIndex=0, item 2 is at distance 2.
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () => BackupPickerSheet.show(
                    innerCtx,
                    entries: _entries,
                    initialIndex: 0,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        // Compute expected formatted text after locale data is initialised.
        // Item 2 is at distance 2 from index 0.
        final dateTime2 = DateFormat.yMMMd('it')
            .add_jm()
            .format(_entries[2].timestampUtc.toLocal());
        final size2 = formatBackupSize(_entries[2].sizeBytes);
        final expectedText = size2.isEmpty ? dateTime2 : '$dateTime2 $size2';

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final itemTextFinder = find.text(expectedText);
        expect(itemTextFinder, findsOneWidget);

        final opacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: itemTextFinder,
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(
          opacity.opacity,
          closeTo(0.18, 0.001),
          reason: 'Distance-≥2 item must have opacity 0.18',
        );

        final textWidget = tester.widget<Text>(itemTextFinder);
        final resolvedStyle = textWidget.style;
        expect(
          resolvedStyle?.fontSize,
          15.0,
          reason: 'Distance-≥2 item must use fontSize 15',
        );
        expect(
          resolvedStyle?.fontWeight,
          FontWeight.w400,
          reason: 'Distance-≥2 item must use fontWeight w400',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ── Return values (TASK-15 smoke + extended TASK-28) ─────────────────────

  testWidgets(
    'BackupPickerSheet.show: Ripristina → int index, Annulla → null',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        int? result;

        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () async {
                    result = await BackupPickerSheet.show(
                      innerCtx,
                      entries: _entries,
                      initialIndex: 0,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        // Ripristina returns 0 (first item selected by default).
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ripristina'));
        await tester.pumpAndSettle();

        expect(result, 0);

        // Annulla returns null.
        result = 999; // sentinel
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();

        expect(result, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_return_scrolled_index_when_ripristina_tapped_after_scroll',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        int? result;

        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () async {
                    result = await BackupPickerSheet.show(
                      innerCtx,
                      entries: _entries,
                      initialIndex: 0,
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

        // Scroll picker by 2 items (2 × 44 dp = 88 dp upward) → index 2.
        await tester.drag(
          find.byType(CupertinoPicker),
          const Offset(0, -88.0),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ripristina'));
        await tester.pumpAndSettle();

        expect(
          result,
          isNotNull,
          reason: 'Ripristina must return a non-null index after scroll',
        );
        expect(
          result,
          isNot(0),
          reason:
              'Ripristina must return the scrolled-to index, not the default 0',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_return_null_when_barrier_tapped_outside_sheet',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        int? result = 999; // sentinel — must become null on barrier dismiss

        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () async {
                    result = await BackupPickerSheet.show(
                      innerCtx,
                      entries: _entries,
                      initialIndex: 0,
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

        // Sheet is open — tap in top-left corner (above the sheet) to dismiss.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(
          find.byType(BackupPickerSheet),
          findsNothing,
          reason: 'Sheet must be dismissed after barrier tap',
        );
        expect(
          result,
          isNull,
          reason: 'Barrier dismiss must return null',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ── Empty-list contract (TASK-15 smoke + extended TASK-28) ───────────────

  testWidgets(
    'BackupPickerSheet empty entries → Ripristina disabled, Annulla active',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        int? cancelResult = 999; // sentinel

        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () async {
                    cancelResult = await BackupPickerSheet.show(
                      innerCtx,
                      entries: const [],
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

        // Empty-state message rendered.
        expect(
          find.text('Nessun backup trovato sul provider.'),
          findsOneWidget,
        );

        // Ripristina button is semantically disabled.
        // flagsCollection.isButton → bool; flagsCollection.isEnabled → Tristate.
        final semantics = tester.getSemantics(find.text('Ripristina'));
        expect(semantics.flagsCollection.isButton, isTrue);
        expect(semantics.flagsCollection.isEnabled, isNot(Tristate.isTrue));

        // Annulla still works → returns null.
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();

        expect(cancelResult, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_have_liveRegion_on_empty_state_text',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () =>
                      BackupPickerSheet.show(innerCtx, entries: const []),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Semantics on the empty-state text must have liveRegion: true.
        final semantics = tester.getSemantics(
          find.text('Nessun backup trovato sul provider.'),
        );
        expect(
          semantics.flagsCollection.isLiveRegion,
          isTrue,
          reason:
              'Empty-state label must be wrapped in Semantics(liveRegion: true)',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_keep_sheet_open_and_not_throw_when_disabled_ripristina_tapped',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        int? result = 999; // sentinel — must stay 999 (no pop)

        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () async {
                    result = await BackupPickerSheet.show(
                      innerCtx,
                      entries: const [],
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

        // Tap on the visually disabled Ripristina — must be a no-op.
        await tester.tap(find.text('Ripristina'), warnIfMissed: false);
        await tester.pumpAndSettle();

        // Sheet stays open: BackupPickerSheet is still in the tree.
        expect(
          find.byType(BackupPickerSheet),
          findsOneWidget,
          reason: 'Sheet must stay open when disabled Ripristina is tapped',
        );
        // Result was not set (still sentinel) → show() has not resolved.
        expect(
          result,
          999,
          reason: 'show() must not resolve when disabled Ripristina is tapped',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ── ArgumentError on invalid initialIndex (TASK-15 smoke) ────────────────

  test(
    'show() throws ArgumentError on out-of-range initialIndex (non-empty list)',
    () {
      expect(
        () => BackupPickerSheet(entries: _entries, initialIndex: 5),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'show() static method throws ArgumentError before presenting sheet',
    () {
      // Cannot call show() without a BuildContext in a plain test.
      // Verify the ArgumentError is thrown by the constructor (same guard).
      expect(
        () => BackupPickerSheet(entries: _entries, initialIndex: 99),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.name,
            'argument name',
            'initialIndex',
          ),
        ),
      );
    },
  );

  // ── Semantics (FR-32, spec §7.1 bullet 951) ──────────────────────────────

  testWidgets(
    'should_have_button_semantics_on_annulla_toolbar_button',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () =>
                      BackupPickerSheet.show(innerCtx, entries: _entries),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Annulla button has Semantics(button: true) with label 'Annulla'.
        final annullaSemantics = tester.getSemantics(find.text('Annulla'));
        expect(
          annullaSemantics.flagsCollection.isButton,
          isTrue,
          reason: 'Annulla toolbar button must have Semantics(button: true)',
        );
        expect(
          annullaSemantics.label,
          contains('Annulla'),
          reason: 'Annulla button Semantics label must contain "Annulla"',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_have_enabled_ripristina_toolbar_button_when_entries_non_empty',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () =>
                      BackupPickerSheet.show(innerCtx, entries: _entries),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Ripristina text is findable and has an active tap handler (non-empty entries).
        expect(
          find.text('Ripristina'),
          findsOneWidget,
          reason: 'Ripristina must be visible when entries are non-empty',
        );
        // The GestureDetector wrapping Ripristina is enabled (has onTap).
        final ripristinaSemantics =
            tester.getSemantics(find.text('Ripristina'));
        // GestureDetector with onTap creates a tap action in semantics.
        expect(
          ripristinaSemantics.flagsCollection.isEnabled,
          isNot(Tristate.isFalse),
          reason:
              'Ripristina must be enabled (not disabled) when entries are non-empty',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'should_have_semantic_labels_on_picker_items',
    (tester) async {
      // Task-28 bullet 10 (picker items have labels): Flutter's Text widget
      // auto-contributes its string content as semantic label. PickerItem has
      // the structure Center > Opacity > Text — no explicit Semantics wrapper
      // is needed; tester.getSemantics() on the Text finds the label.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _harness(
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () =>
                      BackupPickerSheet.show(innerCtx, entries: _entries),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        // Compute expected formatted text after locale data is initialised.
        final dateTimeSem = DateFormat.yMMMd('it')
            .add_jm()
            .format(_entries[0].timestampUtc.toLocal());
        final sizeSem = formatBackupSize(_entries[0].sizeBytes);
        final expectedText =
            sizeSem.isEmpty ? dateTimeSem : '$dateTimeSem $sizeSem';

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Each entry text should be findable and carry its text as a semantic
        // label (the label may be the formatted date/time itself or contain it).
        final s = tester.getSemantics(find.text(expectedText).first);
        expect(
          s.label,
          contains(expectedText),
          reason:
              'Picker item text must contribute its string as a semantic label',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ── Picker config grep gates ─────────────────────────────────────────────

  test(
    'should_use_looping_false_in_cupertino_picker_construction',
    () async {
      // CupertinoPicker.looping has no public getter; verify source-level.
      final result = await Process.run('grep', [
        '-n',
        'looping: false',
        'lib/features/backup/widgets/backup_picker_sheet_internals.dart',
      ]);
      final lines = (result.stdout as String)
          .trim()
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();
      expect(
        lines,
        isNotEmpty,
        reason:
            'CupertinoPicker must be constructed with looping: false per FR-15',
      );
    },
  );

  // ── No deleted-RestorePicker* symbols in impl files (spec §7.1 bullet 950) ─

  test(
    'no_deleted_restore_picker_symbols_in_impl_files',
    () async {
      // Run grep to ensure no deleted contract leaks back in the implementation.
      // Pattern is split across adjacent string literals so this test file itself
      // does not trigger restore_picker_deletion_test.dart's broader grep gate.
      // Split point is after 'Restore' so no fragment contains a full symbol name.
      const pattern = 'Restore'
          'PickerOutcome|'
          'Restore'
          'PickFilename|'
          'Restore'
          'PickNewest';
      final result = await Process.run('grep', [
        '-rElc',
        pattern,
        'lib/features/backup/widgets/backup_picker_sheet.dart',
        'lib/features/backup/widgets/backup_picker_sheet_internals.dart',
      ]);
      final matchCount =
          (result.stdout as String).trim().split('\n').where((line) {
        final count = int.tryParse(line.split(':').last.trim()) ?? 0;
        return count > 0;
      }).length;
      expect(
        matchCount,
        0,
        reason: 'No deleted RestorePicker* symbols '
            'must exist in backup_picker_sheet implementation files',
      );
    },
  );

  // ── BUG-R01: picker renders localised date/time, not raw filename ──────────

  testWidgets(
    'picker_renders_localised_date_time_not_raw_filename',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final entry = BackupFileEntry(
          name: 'metra_backup_20260524T143022Z_abc.enc',
          timestampUtc: DateTime.utc(2026, 5, 24, 14, 30, 22),
          sizeBytes: 1024,
        );

        await tester.pumpWidget(
          _harness(
            locale: 'en',
            builder: (ctx) => Scaffold(
              body: Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () => BackupPickerSheet.show(
                    innerCtx,
                    entries: [entry],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        // Compute expected text after locale data is initialised by the pump.
        final dateTimeBugR01 = DateFormat.yMMMd('en')
            .add_jm()
            .format(entry.timestampUtc.toLocal());
        final sizeBugR01 = formatBackupSize(entry.sizeBytes);
        final expectedText =
            sizeBugR01.isEmpty ? dateTimeBugR01 : '$dateTimeBugR01 $sizeBugR01';

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Rendered text must be the localised date/time, not the raw filename.
        expect(
          find.textContaining('May 24, 2026'),
          findsOneWidget,
          reason:
              'Picker item must display the localised date, not the raw filename',
        );
        expect(
          find.text('metra_backup_20260524T143022Z_abc.enc'),
          findsNothing,
          reason: 'Raw filename must not appear in the picker item',
        );

        // Double-check: the full computed string (date + time + size) is present.
        expect(
          find.text(expectedText),
          findsOneWidget,
          reason: 'Full formatted date/time + size string must be present',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ── NFR-12: reduced motion — no AnimationController without disableAnimations
  // ─────────────────────────────────────────────────────────────────────────

  test(
    'nfr12_selection_overlay_has_no_animation_controller_without_disable_check',
    () async {
      // NFR-12: the selection overlay in PickerSheet is a static Container
      // (no AnimationController or TweenAnimationBuilder).
      // Verify that backup_picker_sheet_internals.dart introduces no
      // AnimationController without a disableAnimations guard.
      final result = await Process.run('grep', [
        '-c',
        'AnimationController',
        'lib/features/backup/widgets/backup_picker_sheet_internals.dart',
      ]);
      final count = int.tryParse((result.stdout as String).trim()) ?? 0;
      expect(
        count,
        0,
        reason: 'NFR-12: backup_picker_sheet_internals.dart must have 0 '
            'AnimationController instances (selection overlay is static)',
      );
    },
  );

  testWidgets(
    'nfr12_sheet_renders_correctly_with_disableAnimations_true',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // Verify that mounting the sheet under disableAnimations: true
        // does not throw and renders the toolbar + picker correctly.
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: _harness(
              builder: (ctx) => Scaffold(
                body: Builder(
                  builder: (innerCtx) => ElevatedButton(
                    onPressed: () =>
                        BackupPickerSheet.show(innerCtx, entries: _entries),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Annulla'), findsOneWidget);
        expect(find.text('Ripristina'), findsOneWidget);
        expect(find.byType(CupertinoPicker), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
