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

// TASK-33 — Group L: a11y semantics walker tests.
//
// Verifies accessibility invariants on new backup-screen widgets:
//   A1 — BackupEmptyView: CTA has non-empty label and is tappable.
//   A2 — BackupConnectedView: disconnect row carries 'Distruttivo: ' prefix.
//   A3 — MetraConfirmDialog: both buttons have SemanticsAction.tap; dialog
//        title/body is present in the semantics tree.
//   A4 — RestoreProgressScreen: heading has liveRegion=true; no back chevron
//        (PopScope.canPop=false). Mirrors canonical assertions in
//        restore_progress_screen_test.dart for discoverability in this file.
//   A5 — BackupPickerSheet toolbar: cancel/confirm buttons size ≥ 44×44 dp.
//        NOTE: A5 is expected to FAIL on the current implementation because
//        the toolbar buttons use MetraSpacing.s2 (8 dp) vertical padding +
//        Inter-16 text (~16 dp) = ~32 dp total height, which is below the
//        44 dp WCAG 2.2 AA tap-target minimum. The test is written honestly
//        per spec; the failure is a bug report for flutter-frontend-engineer.
//
// Target platforms: all (headless widget tests — no device-farm dependency).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/restore_progress_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_connected_view.dart';
import 'package:metra/features/backup/views/backup_empty_view.dart';
import 'package:metra/features/backup/widgets/backup_picker_sheet.dart';
import 'package:metra/features/backup/widgets/metra_confirm_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';

import '../../helpers/fake_dropbox_provider.dart';
import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Stub notifier (mirrors _StubBackupNotifier from backup_screen_test.dart)
// ---------------------------------------------------------------------------

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;

  @override
  Future<BackupState> build() async => _initial;

  @override
  Future<void> connect() async {}

  @override
  Future<void> backupNow() async {}

  @override
  Future<void> backupSilent() async {}

  @override
  Future<void> backupWithPassphrase(String passphrase) async {}

  @override
  Future<int?> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async => null;

  @override
  Future<void> disconnect() async {}
}

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

/// Wraps [child] with the providers BackupEmptyView and BackupConnectedView
/// need. [state] seeds the stub notifier.
Widget _wrap(BackupState state, Widget child) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => _StubBackupNotifier(state),
      ),
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      cloudBackupProvider.overrideWithValue(
        FakeDropboxProvider(seedEntries: const []),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// Minimal harness for widgets that do not need backup providers
/// (RestoreProgressScreen, MetraConfirmDialog, BackupPickerSheet).
Widget _wrapSimple(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // A1 — BackupEmptyView: CTA button has a non-empty semantics label and
  //      SemanticsAction.tap.
  // Spec: §7.1 Group L / TASK-33 a11y A1.
  // =========================================================================
  testWidgets(
    'A1: should_have_tappable_cta_with_non_empty_label_when_BackupEmptyView_rendered',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(const BackupNotConnected(), const BackupEmptyView()),
      );
      await tester.pumpAndSettle();

      // The CTA button is a ButtonPrimary carrying a semanticsLabel.
      // Find the semantics node for the CTA via its Key.
      final ctaFinder = find.byKey(const Key('backup_empty_cta'));
      expect(ctaFinder, findsOneWidget, reason: 'CTA SizedBox must be present');

      // Walk semantics: find Semantics widgets that are descendants of the CTA
      // area, are buttons, and have a non-empty label.
      final tappableWithLabel = tester
          .widgetList<Semantics>(
            find.descendant(
              of: ctaFinder,
              matching: find.byType(Semantics),
            ),
          )
          .where(
            (s) =>
                s.properties.button == true &&
                (s.properties.label ?? '').isNotEmpty,
          )
          .toList();

      expect(
        tappableWithLabel,
        isNotEmpty,
        reason: 'CTA button must have Semantics(button: true) and a non-empty '
            'label (WCAG 2.2 AA)',
      );

      handle.dispose();
    },
  );

  // =========================================================================
  // A2 — BackupConnectedView: the disconnect row carries the 'Distruttivo: '
  //      prefix in its semantics label (FR-32 destructive action labelling).
  //
  // Implementation: the outer Semantics widget in BackupConnectedView has
  //   label: 'Distruttivo: ${l10n.backupDisconnectLabel}'
  //   excludeSemantics: true
  // The 'Distruttivo: ' prefix is a fixed Italian string mandated by FR-32;
  // it does not translate.
  // =========================================================================
  testWidgets(
    'A2: should_have_Distruttivo_prefix_on_disconnect_row_when_BackupConnectedView_rendered',
    (tester) async {
      tester.view.physicalSize = const Size(2400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final handle = tester.ensureSemantics();

      const connectedState = BackupConnected(
        email: 'user@example.com',
        autoBackupActive: true,
        passphraseSet: true,
        lastBackupAt: null,
      );

      await tester.pumpWidget(
        _wrap(
          connectedState,
          const BackupConnectedView(state: connectedState),
        ),
      );
      await tester.pumpAndSettle();

      // Find Semantics widgets whose label starts with 'Distruttivo: '.
      final destructiveSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (s) =>
                (s.properties.label ?? '').startsWith('Distruttivo: ') &&
                s.properties.label!.isNotEmpty,
          )
          .toList();

      expect(
        destructiveSemantics,
        isNotEmpty,
        reason: "Disconnect row must carry a Semantics label starting with "
            "'Distruttivo: ' per FR-32 destructive-action labelling",
      );

      // Also verify the label includes the disconnect action text (non-empty
      // after the prefix).
      for (final node in destructiveSemantics) {
        final label = node.properties.label!;
        expect(
          label.length,
          greaterThan('Distruttivo: '.length),
          reason:
              'Semantics label must include the action text after the prefix',
        );
      }

      handle.dispose();
    },
  );

  // =========================================================================
  // A3 — MetraConfirmDialog: confirm and cancel buttons have
  //      SemanticsAction.tap; dialog content is readable in the semantics tree.
  // =========================================================================
  testWidgets(
    'A3: should_have_tappable_buttons_and_readable_content_when_MetraConfirmDialog_shown',
    (tester) async {
      final handle = tester.ensureSemantics();

      // Mount a Scaffold so showDialog can find a Navigator and Overlay.
      await tester.pumpWidget(
        _wrapSimple(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => MetraConfirmDialog.show(
                  context,
                  title: 'Delete data?',
                  body: 'This action cannot be undone.',
                  cancelLabel: 'Cancel',
                  confirmLabel: 'Confirm',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap the trigger button to show the dialog.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The dialog must be present.
      expect(
        find.byType(MetraConfirmDialog),
        findsOneWidget,
        reason: 'MetraConfirmDialog must be present after show()',
      );

      // ── Assert cancel button has SemanticsAction.tap ──────────────────────
      final cancelSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (s) =>
                s.properties.button == true &&
                (s.properties.label ?? '') == 'Cancel',
          )
          .toList();

      expect(
        cancelSemantics,
        isNotEmpty,
        reason:
            'Cancel button must have Semantics(button: true, label: "Cancel")',
      );

      // ── Assert confirm button has SemanticsAction.tap ─────────────────────
      final confirmSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (s) =>
                s.properties.button == true &&
                (s.properties.label ?? '') == 'Confirm',
          )
          .toList();

      expect(
        confirmSemantics,
        isNotEmpty,
        reason:
            'Confirm button must have Semantics(button: true, label: "Confirm")',
      );

      // ── Assert dialog title/body is readable in the widget tree ──────────
      expect(
        find.text('Delete data?'),
        findsOneWidget,
        reason: 'Dialog title must be present and non-empty',
      );
      expect(
        find.text('This action cannot be undone.'),
        findsOneWidget,
        reason: 'Dialog body must be present and non-empty',
      );

      handle.dispose();
    },
  );

  // =========================================================================
  // A4 — RestoreProgressScreen: heading has liveRegion=true (FR-32); back
  //      chevron is absent / suppressed (PopScope.canPop=false, EC-09).
  //
  // NOTE: This test mirrors the canonical assertions in
  //       restore_progress_screen_test.dart (G-4 + liveRegion test) and is
  //       included here for discoverability in the a11y walker file.
  // =========================================================================
  testWidgets(
    'A4: should_have_liveRegion_heading_and_no_back_chevron_when_RestoreProgressScreen_rendered',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_wrapSimple(const RestoreProgressScreen()));
      await tester.pump();

      // ── Assert heading has liveRegion = true ─────────────────────────────
      final liveRegionNodes = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion == true)
          .toList();

      expect(
        liveRegionNodes,
        isNotEmpty,
        reason:
            'Heading must be wrapped in Semantics(liveRegion: true) per FR-32',
      );

      // ── Assert back chevron is NOT present ────────────────────────────────
      // PopScope.canPop == false suppresses back navigation (EC-09).
      // The AppBar is configured with leading: null and
      // automaticallyImplyLeading: false (FR-18), so no back icon is rendered.
      final backIconFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.arrow_back ||
                w.icon == Icons.arrow_back_ios ||
                w.icon == Icons.arrow_back_ios_new),
      );
      expect(
        backIconFinder,
        findsNothing,
        reason: 'Back chevron must be absent: AppBar.leading=null + '
            'automaticallyImplyLeading=false (FR-18)',
      );

      // ── Assert PopScope.canPop == false ──────────────────────────────────
      final popScopes =
          tester.widgetList<PopScope<dynamic>>(find.byType(PopScope)).toList();

      expect(
        popScopes,
        isNotEmpty,
        reason: 'Screen must contain a PopScope widget (EC-09)',
      );
      expect(
        popScopes.first.canPop,
        isFalse,
        reason:
            'PopScope.canPop must be false to block back navigation (EC-09)',
      );

      handle.dispose();
    },
  );

  // =========================================================================
  // A5 — BackupPickerSheet toolbar: cancel/confirm buttons ≥ 44×44 dp.
  //
  // KNOWN FAILURE: current toolbar buttons use MetraSpacing.s2 (8 dp) vertical
  // padding + Inter-16 text (~16 dp) = ~32 dp effective height, which is below
  // the WCAG 2.2 AA / Apple HIG 44 dp minimum tap target.
  //
  // This test documents the gap. Fix is owned by flutter-frontend-engineer:
  // increase vertical padding in CupertinoPickerScaffold toolbar buttons (and
  // EmptySheet toolbar) to MetraSpacing.sp14 (14 dp) so that
  //   14 + 16 + 14 = 44 dp.
  //
  // The test checks BOTH the non-empty sheet (PickerSheet / CupertinoPickerScaffold
  // toolbar via GestureDetector + Padding) and the empty sheet (EmptySheet toolbar).
  // =========================================================================
  group('A5 — BackupPickerSheet toolbar tap targets', () {
    const minTapTarget = 44.0;

    // A5a — non-empty sheet: cancel button ≥ 44×44 dp.
    testWidgets(
      'A5a: should_have_cancel_button_gte_44dp_when_non_empty_PickerSheet_shown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final entries = [
          BackupFileEntry(
            name: 'backup_2026-05-01.enc',
            timestampUtc: _kTestTimestamp,
            sizeBytes: 1024,
          ),
        ];

        await tester.pumpWidget(
          _wrapSimple(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => BackupPickerSheet.show(
                      context,
                      entries: entries,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Find the cancel button by its semantics label (l10n key commonCancel
        // = "Cancel" in EN locale).
        final cancelFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              (w.properties.label ?? '') == 'Cancel',
        );

        expect(
          cancelFinder,
          findsOneWidget,
          reason:
              'Cancel toolbar button must have Semantics(button, label="Cancel")',
        );

        final cancelSize = tester.getSize(cancelFinder);
        expect(
          cancelSize.height,
          greaterThanOrEqualTo(minTapTarget),
          reason: 'Cancel button height must be ≥ $minTapTarget dp '
              '(WCAG 2.2 AA tap target). '
              'Current: ${cancelSize.height} dp — '
              'increase vertical padding in CupertinoPickerScaffold toolbar '
              'from MetraSpacing.s2 (8 dp) to MetraSpacing.sp14 (14 dp).',
        );
      },
    );

    // A5b — non-empty sheet: confirm button ≥ 44×44 dp.
    //
    // KNOWN FAILURE (second a11y gap): the confirm button in
    // CupertinoPickerScaffold has NO Semantics wrapper at all — it is a bare
    // GestureDetector, making it invisible to assistive technology. This is a
    // more severe gap than the size issue. Bug report for
    // flutter-frontend-engineer: add Semantics(button: true, label: confirmLabel)
    // to the CupertinoPickerScaffold confirm button, mirroring the reset button.
    testWidgets(
      'A5b: should_have_confirm_button_gte_44dp_when_non_empty_PickerSheet_shown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final entries = [
          BackupFileEntry(
            name: 'backup_2026-05-01.enc',
            timestampUtc: _kTestTimestamp,
            sizeBytes: 1024,
          ),
        ];

        await tester.pumpWidget(
          _wrapSimple(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => BackupPickerSheet.show(
                      context,
                      entries: entries,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Find the confirm button by its semantics label (l10n key
        // backupPickerConfirm = "Restore" in EN locale).
        // CURRENTLY FAILS: CupertinoPickerScaffold confirm button has no
        // Semantics wrapper — it is a bare GestureDetector (a11y gap).
        final confirmFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              (w.properties.label ?? '') == 'Restore',
        );

        expect(
          confirmFinder,
          findsOneWidget,
          reason: 'Confirm toolbar button must have Semantics(button: true, '
              'label: "Restore"). CURRENT BUG: CupertinoPickerScaffold confirm '
              'button is a bare GestureDetector with no Semantics wrapper — '
              'add Semantics(button: true, label: confirmLabel) in '
              'lib/core/widgets/settings/cupertino_picker_scaffold.dart',
        );

        final confirmSize = tester.getSize(confirmFinder);
        expect(
          confirmSize.height,
          greaterThanOrEqualTo(minTapTarget),
          reason: 'Confirm button height must be ≥ $minTapTarget dp '
              '(WCAG 2.2 AA tap target). '
              'Current: ${confirmSize.height} dp — '
              'increase vertical padding in CupertinoPickerScaffold toolbar '
              'from MetraSpacing.s2 (8 dp) to MetraSpacing.sp14 (14 dp).',
        );
      },
    );

    // A5c — empty sheet: cancel button ≥ 44×44 dp.
    testWidgets(
      'A5c: should_have_cancel_button_gte_44dp_when_empty_PickerSheet_shown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _wrapSimple(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => BackupPickerSheet.show(
                      context,
                      entries: const [],
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Empty sheet cancel button: Semantics(button: true, label: commonCancel).
        final cancelFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              (w.properties.label ?? '') == 'Cancel',
        );

        expect(
          cancelFinder,
          findsOneWidget,
          reason:
              'Empty sheet cancel button must have Semantics(button, label="Cancel")',
        );

        final cancelSize = tester.getSize(cancelFinder);
        expect(
          cancelSize.height,
          greaterThanOrEqualTo(minTapTarget),
          reason: 'Empty sheet cancel button height must be ≥ $minTapTarget dp '
              '(WCAG 2.2 AA tap target). '
              'Current: ${cancelSize.height} dp — '
              'increase vertical padding in EmptySheet toolbar buttons '
              'from MetraSpacing.s2 (8 dp) to MetraSpacing.sp14 (14 dp).',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

// ignore: non_constant_identifier_names
final _kTestTimestamp = DateTime.utc(2026, 5, 1, 12);
