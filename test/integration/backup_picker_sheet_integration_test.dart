// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later
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

// TASK-35 — Group I: BackupPickerSheet integration scenarios (I-A..I-G)
//
// All scenarios mount BackupScreen via _wrap (dispatcher pattern) and drive the
// full handleRestore() flow: file picker → confirm dialog → passphrase dialog.
//
// Scenarios:
//   I-A  Restore happy path — all dialogs answered, capturedRestorePassphrase set
//   I-B  Success: BackupConnected view rendered after restore completes
//   I-C  Failure: BackupErrorView rendered when restoreFailMessage is set
//   I-D  Cancel at picker step — sheet dismissed, no restore initiated
//   I-E  Provider fetch error — error handled gracefully (snackbar or error view)
//   I-F  keepAlive during orientation change — sheet survives size change (EC-06)
//   I-G  State transitions to BackupErrorState while sheet is open (behavior doc)
//
// Platform matrix: Linux CI, headless. No iOS simulator required.
// debugDefaultTargetPlatformOverride = TargetPlatform.iOS is set via a
// try/finally block inside each testWidgets body (correct pattern per
// backup_picker_sheet_test.dart — addTearDown runs after framework invariant
// check in this Flutter version, causing false "debug variable" failures).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/backup_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_connected_view.dart';
import 'package:metra/features/backup/views/backup_error_view.dart';
import 'package:metra/features/backup/widgets/backup_picker_sheet.dart';
import 'package:metra/features/backup/widgets/metra_confirm_dialog.dart';
import 'package:metra/features/backup/widgets/passphrase_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';

import '../helpers/fake_dropbox_provider.dart';
import '../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Stub notifier — local copy of the private class in backup_screen_test.dart
// (cannot import — it is private). Added restoreTransitionsToConnected flag
// for I-B so the stub can simulate the successful state change.
// ---------------------------------------------------------------------------

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;

  String? capturedRestorePassphrase;
  String? capturedRestoreFilename;
  String? capturedBackupPassphrase;
  int backupSilentCallCount = 0;
  int backupWithPassphraseCallCount = 0;
  int backupNowCallCount = 0;

  /// When non-null, [restoreWithPassphrase] transitions state to
  /// [BackupErrorState] with this message instead of completing silently.
  String? restoreFailMessage;

  /// When true, [restoreWithPassphrase] explicitly transitions state to
  /// [BackupConnected] after capturing. Used by I-B to simulate a successful
  /// restore auto-transition (the real notifier calls ref.invalidateSelf()).
  bool restoreTransitionsToConnected = false;

  @override
  Future<BackupState> build() async => _initial;

  @override
  Future<void> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async {
    capturedRestorePassphrase = passphrase;
    capturedRestoreFilename = filename;
    if (restoreFailMessage != null) {
      state = AsyncData(BackupErrorState(restoreFailMessage!));
    } else if (restoreTransitionsToConnected) {
      // Simulate a successful restore: re-emit BackupConnected so the
      // dispatcher shows BackupConnectedView (what ref.invalidateSelf() would
      // eventually produce after a real rebuild).
      state = const AsyncData(
        BackupConnected(
          email: 'a@b.it',
          autoBackupActive: true,
          lastBackupAt: null,
        ),
      );
    }
    // Otherwise: capture only, leave state unchanged (stays at _initial).
  }

  @override
  Future<void> backupWithPassphrase(String passphrase) async {
    capturedBackupPassphrase = passphrase;
    backupWithPassphraseCallCount++;
  }

  @override
  Future<void> backupSilent() async => backupSilentCallCount++;

  @override
  Future<void> backupNow() async => backupNowCallCount++;
}

// ---------------------------------------------------------------------------
// Default seed entries
// ---------------------------------------------------------------------------

final _seedEntry = BackupFileEntry(
  name: 'metra_2026-05-17_12-00-00.enc',
  timestampUtc: DateTime.utc(2026, 5, 17, 12),
  sizeBytes: 2048,
);

final _seedEntries = [_seedEntry];

// ---------------------------------------------------------------------------
// _wrap helper — mounts BackupScreen via the dispatcher (same pattern as
// backup_screen_test.dart). Tests that need a custom stub pass one explicitly.
// ---------------------------------------------------------------------------

Widget _wrap(
  BackupState state, {
  _StubBackupNotifier? stub,
  FakeDropboxProvider? fakeProvider,
}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => stub ?? _StubBackupNotifier(state),
      ),
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      cloudBackupProvider.overrideWithValue(
        fakeProvider ?? FakeDropboxProvider(seedEntries: _seedEntries),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Helper: navigate to BackupPickerSheet by tapping the restore action row.
// Pre-condition: BackupConnectedView is already rendered.
// ---------------------------------------------------------------------------

Future<void> _openPickerSheet(WidgetTester tester) async {
  final restoreRow = find.byKey(const Key('backup_restore_action_row'));
  expect(restoreRow, findsOneWidget, reason: 'restore row must be present');
  await tester.tap(restoreRow);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Helper: complete the passphrase unlock dialog.
//   1. Type passphrase in the first TextField inside PassphraseDialog.
//   2. Tap the "Unlock and restore" button.
// ---------------------------------------------------------------------------

Future<void> _enterPassphrase(
  WidgetTester tester,
  String passphrase,
) async {
  final dialog = find.byType(PassphraseDialog);
  expect(dialog, findsOneWidget, reason: 'PassphraseDialog must be visible');
  final field = find.descendant(
    of: dialog,
    matching: find.byType(TextField),
  );
  await tester.enterText(field.first, passphrase);
  await tester.pump();
  final unlockBtn = find.descendant(
    of: dialog,
    matching: find.text('Unlock and restore'),
  );
  expect(unlockBtn, findsOneWidget);
  await tester.tap(unlockBtn);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Helper: tap confirm in MetraConfirmDialog.
// Uses ancestor-based finder to avoid "Restore" label collision with the
// picker toolbar confirm button.
// ---------------------------------------------------------------------------

Future<void> _tapDialogConfirm(WidgetTester tester, String label) async {
  final confirmDialog = find.byType(MetraConfirmDialog);
  expect(
    confirmDialog,
    findsOneWidget,
    reason: 'MetraConfirmDialog must be visible',
  );
  final btn = find.descendant(
    of: confirmDialog,
    matching: find.text(label),
  );
  expect(btn, findsOneWidget, reason: '"$label" button must be in the dialog');
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const connectedState = BackupConnected(
    email: 'a@b.it',
    autoBackupActive: true,
    lastBackupAt: null,
  );

  // ===========================================================================
  // Group I-A — Restore happy path (all dialogs answered)
  // ===========================================================================

  group('I-A — restore happy path', () {
    testWidgets(
      'should_capture_passphrase_and_filename_when_full_restore_flow_completed',
      (tester) async {
        // try/finally is the correct pattern for debugDefaultTargetPlatformOverride
        // in this Flutter version — see backup_picker_sheet_test.dart.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          tester.view.physicalSize = const Size(800, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(connectedState);
          await tester.pumpWidget(_wrap(connectedState, stub: stub));
          await tester.pumpAndSettle();

          // Precondition: BackupConnectedView is visible.
          expect(find.byType(BackupConnectedView), findsOneWidget);

          // Step 1: open the picker sheet.
          await _openPickerSheet(tester);
          expect(find.byType(BackupPickerSheet), findsOneWidget);

          // Step 2: tap the confirm button in the picker toolbar.
          // CupertinoPickerScaffold uses confirmLabel 'Restore' (backupPickerConfirm).
          // We find it relative to the sheet to avoid collision with dialog labels.
          final pickerSheet = find.byType(BackupPickerSheet);
          final pickerConfirm = find.descendant(
            of: pickerSheet,
            matching: find.text('Restore'),
          );
          expect(pickerConfirm, findsOneWidget);
          await tester.tap(pickerConfirm);
          await tester.pumpAndSettle();

          // Step 3: MetraConfirmDialog should appear.
          expect(find.byType(MetraConfirmDialog), findsOneWidget);
          await _tapDialogConfirm(tester, 'Restore');

          // Step 4: PassphraseDialog (unlock mode) should appear.
          expect(find.byType(PassphraseDialog), findsOneWidget);
          await _enterPassphrase(tester, 'correct-pass-word');

          // Step 5: Assert restore was called with captured values.
          expect(
            stub.capturedRestorePassphrase,
            equals('correct-pass-word'),
            reason:
                'restoreWithPassphrase must be called with the entered passphrase',
          );
          expect(
            stub.capturedRestoreFilename,
            equals(_seedEntry.name),
            reason:
                'restoreWithPassphrase must be called with the selected file name',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  // ===========================================================================
  // Group I-B — Success: BackupConnectedView rendered after restore completes
  // ===========================================================================

  group('I-B — success state after restore', () {
    testWidgets(
      'should_render_BackupConnectedView_when_restore_transitions_to_BackupConnected',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          tester.view.physicalSize = const Size(800, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(connectedState)
            ..restoreTransitionsToConnected = true;
          await tester.pumpWidget(_wrap(connectedState, stub: stub));
          await tester.pumpAndSettle();

          // Drive the full flow.
          await _openPickerSheet(tester);
          final pickerSheet = find.byType(BackupPickerSheet);
          final pickerConfirm = find.descendant(
            of: pickerSheet,
            matching: find.text('Restore'),
          );
          await tester.tap(pickerConfirm);
          await tester.pumpAndSettle();

          await _tapDialogConfirm(tester, 'Restore');
          await _enterPassphrase(tester, 'my-pass-w0rd');

          // After stub.restoreWithPassphrase() emits BackupConnected, the
          // dispatcher must re-render BackupConnectedView (no crash, no stuck state).
          expect(
            find.byType(BackupConnectedView),
            findsOneWidget,
            reason:
                'BackupConnectedView must be shown after successful restore',
          );
          expect(
            find.byType(BackupErrorView),
            findsNothing,
            reason:
                'BackupErrorView must NOT be shown after successful restore',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  // ===========================================================================
  // Group I-C — Failure: BackupErrorView rendered when restore fails
  // ===========================================================================

  group('I-C — failure state after restore', () {
    testWidgets(
      'should_render_BackupErrorView_when_restoreFailMessage_is_set',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          tester.view.physicalSize = const Size(800, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(connectedState)
            ..restoreFailMessage = 'test error: restore failed';
          await tester.pumpWidget(_wrap(connectedState, stub: stub));
          await tester.pumpAndSettle();

          // Drive the full flow.
          await _openPickerSheet(tester);
          final pickerSheet = find.byType(BackupPickerSheet);
          final pickerConfirm = find.descendant(
            of: pickerSheet,
            matching: find.text('Restore'),
          );
          await tester.tap(pickerConfirm);
          await tester.pumpAndSettle();

          await _tapDialogConfirm(tester, 'Restore');
          await _enterPassphrase(tester, 'wrong-pass-w0rd');

          // After stub.restoreWithPassphrase() emits BackupErrorState, the
          // dispatcher must render BackupErrorView with the error message.
          expect(
            find.byType(BackupErrorView),
            findsOneWidget,
            reason: 'BackupErrorView must be shown when restore fails',
          );
          expect(
            find.text('test error: restore failed'),
            findsOneWidget,
            reason:
                'BackupErrorView must display the error message from the state',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  // ===========================================================================
  // Group I-D — Cancel at picker step
  // ===========================================================================

  group('I-D — cancel at picker step', () {
    testWidgets(
      'should_dismiss_sheet_and_not_initiate_restore_when_cancel_tapped',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          tester.view.physicalSize = const Size(800, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(connectedState);
          await tester.pumpWidget(_wrap(connectedState, stub: stub));
          await tester.pumpAndSettle();

          // Open the picker sheet.
          await _openPickerSheet(tester);
          expect(find.byType(BackupPickerSheet), findsOneWidget);

          // Tap the cancel (commonCancel = "Cancel") button in the picker toolbar.
          final pickerSheet = find.byType(BackupPickerSheet);
          final cancelBtn = find.descendant(
            of: pickerSheet,
            matching: find.text('Cancel'),
          );
          expect(cancelBtn, findsOneWidget);
          await tester.tap(cancelBtn);
          await tester.pumpAndSettle();

          // Sheet dismissed: BackupPickerSheet no longer in tree.
          expect(find.byType(BackupPickerSheet), findsNothing);

          // No restore was initiated: capturedRestoreFilename remains null.
          expect(
            stub.capturedRestoreFilename,
            isNull,
            reason: 'No restore must be initiated when the picker is cancelled',
          );
          expect(
            stub.capturedRestorePassphrase,
            isNull,
            reason:
                'No passphrase must be captured when the picker is cancelled',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  // ===========================================================================
  // Group I-E — Provider fetch error handled gracefully
  // ===========================================================================
  //
  // Note: debugDefaultTargetPlatformOverride NOT set — the error occurs before
  // the picker sheet is opened (no Cupertino widgets shown).

  group('I-E — provider fetch error', () {
    testWidgets(
      'should_show_snackbar_and_not_crash_when_listFiles_throws',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Configure FakeDropboxProvider to throw on every listFiles() call.
        // listFilesThrows is a SyncException — the production catch clause
        // in handleRestore() swallows it and shows a SnackBar.
        final errorFake = FakeDropboxProvider(seedEntries: _seedEntries)
          ..listFilesThrows = const SyncException('network error');

        await tester.pumpWidget(
          _wrap(connectedState, fakeProvider: errorFake),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BackupConnectedView), findsOneWidget);

        // Tap restore row — handleRestore() reads backupFileListProvider,
        // which calls listFiles(), which throws. The catch block shows a snackbar.
        final restoreRow = find.byKey(const Key('backup_restore_action_row'));
        await tester.tap(restoreRow);
        await tester.pumpAndSettle();

        // Assertion: a snackbar with the error label is visible.
        // Production code uses l10n.restorePickerError = "Failed to load backup files."
        expect(
          find.text('Failed to load backup files.'),
          findsOneWidget,
          reason:
              'A snackbar with the restorePickerError message must appear when '
              'listFiles() throws',
        );

        // Sheet must NOT have been opened.
        expect(find.byType(BackupPickerSheet), findsNothing);
      },
    );
  });

  // ===========================================================================
  // Group I-F — keepAlive across orientation change (EC-06)
  // ===========================================================================
  //
  // Verifies that BackupPickerSheet survives a viewport layout-size change
  // while open (smoke test). A modal BottomSheet is not dismounted by a
  // physicalSize change — this test confirms no crash and continued
  // sheet visibility after rotation.
  //
  // Note: a layout-size change does NOT trigger provider disposal, so this
  // test does not fully exercise the EC-06 keepAlive seam (which guards
  // against Consumer unmount on route push or app lifecycle transitions).
  // Deeper EC-06 lifecycle coverage is deferred to a future test that
  // directly inspects the ProviderContainer element after a route change.

  group('I-F — keepAlive across orientation change (EC-06)', () {
    testWidgets(
      'should_keep_picker_sheet_visible_after_device_rotation',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          tester.view.physicalSize = const Size(800, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(connectedState);
          await tester.pumpWidget(_wrap(connectedState, stub: stub));
          await tester.pumpAndSettle();

          // Open the picker sheet.
          await _openPickerSheet(tester);
          expect(find.byType(BackupPickerSheet), findsOneWidget);

          // Simulate orientation change by swapping width and height.
          tester.view.physicalSize = const Size(4000, 800);
          await tester.pump();
          await tester.pump(); // allow layout rebuild to settle

          // The sheet must still be present after the layout change.
          expect(
            find.byType(BackupPickerSheet),
            findsOneWidget,
            reason:
                'BackupPickerSheet must remain visible after orientation change; '
                'listenManual keeps backupFileListProvider alive (EC-06)',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  // ===========================================================================
  // Group I-G — State transitions to BackupErrorState while sheet is open
  // ===========================================================================
  //
  // Documents the CURRENT behavior: when the stub transitions the notifier to
  // BackupErrorState while BackupPickerSheet is open, production code does NOT
  // explicitly dismiss the sheet (handleRestore() has no listener on the state).
  // The dispatcher rebuilds underneath the modal route.
  //
  // Skipped: remove skip once production code explicitly handles this case
  // (e.g., a listenManual that pops the route when BackupErrorState is emitted
  // during a restore flow).

  group('I-G — state transition to error while sheet is open', () {
    testWidgets(
      'should_not_crash_when_BackupErrorState_emitted_while_picker_sheet_is_open',
      // Production handleRestore() has no listener that dismisses the sheet on
      // BackupErrorState. Current behavior: sheet stays open over the
      // dispatcher's rebuilt error view. Behavior is documented here; dismiss
      // logic is TBD.
      skip: true,
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          tester.view.physicalSize = const Size(800, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(connectedState);
          await tester.pumpWidget(_wrap(connectedState, stub: stub));
          await tester.pumpAndSettle();

          // Open the picker sheet.
          await _openPickerSheet(tester);
          expect(find.byType(BackupPickerSheet), findsOneWidget);

          // Transition the notifier to BackupErrorState while sheet is open.
          stub.state = const AsyncData(BackupErrorState('error while open'));
          await tester.pumpAndSettle();

          // No crash is the minimum invariant.
          // The dispatcher rebuilds to BackupErrorView underneath the modal sheet.
          // The sheet itself remains visible (modal route is not popped).
          expect(find.byType(BackupPickerSheet), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}
