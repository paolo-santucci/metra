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

// TASK-36 — Integration scenarios I-H..I-O (BackupConnectedView flows)
//
// Each test targets a single user-visible behaviour of BackupConnectedView:
//   I-H  cached passphrase → backup calls backupNow (no dialog)
//   I-I  no cached passphrase → PassphraseDialog shown → passphrase captured
//   I-J  HC-2 guard (restore path): confirm dialog appears BEFORE restoreWithPassphrase
//   I-K  disconnect: (a) cancel = no call; (b) confirm = disconnect called
//   I-L  disconnect failure → BackupErrorView renders with error message
//   I-O  empty backup list → BackupPickerSheet shows EmptySheet, confirm disabled
//
// NOTE: I-H/I-I — handleBackup() has no MetraConfirmDialog gate; it routes
// directly to backupNow (cached path) or PassphraseDialog (first-time path).
// The HC-2 confirm-before-file-op gate lives on handleRestore, covered by I-J.
//
// Target platforms: Linux CI, headless (no device-farm dependency).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/backup_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
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
// Local stub notifier — mirrors _StubBackupNotifier from backup_screen_test.dart
// (private class, must be re-defined per file).
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
  int disconnectCallCount = 0;

  /// When non-null, [restoreWithPassphrase] transitions to [BackupErrorState]
  /// with this message instead of completing silently.
  String? restoreFailMessage;

  /// When non-null, [disconnect] transitions to [BackupErrorState] with this
  /// message instead of completing silently.
  String? disconnectFailMessage;

  @override
  Future<BackupState> build() async => _initial;

  @override
  Future<int?> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async {
    capturedRestorePassphrase = passphrase;
    capturedRestoreFilename = filename;
    if (restoreFailMessage != null) {
      state = AsyncData(BackupErrorState(restoreFailMessage!));
      return null;
    }
    return null;
  }

  @override
  Future<void> backupWithPassphrase(String passphrase) async {
    capturedBackupPassphrase = passphrase;
    backupWithPassphraseCallCount++;
  }

  @override
  Future<void> backupSilent() async {
    backupSilentCallCount++;
  }

  @override
  Future<void> backupNow() async {
    backupNowCallCount++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    if (disconnectFailMessage != null) {
      state = AsyncData(BackupErrorState(disconnectFailMessage!));
    }
    // Happy path: state remains BackupConnected (no-op).
  }
}

// ---------------------------------------------------------------------------
// Shared BackupConnected state
// ---------------------------------------------------------------------------

const _connectedState = BackupConnected(
  email: 'test@example.com',
  autoBackupActive: true,
  passphraseSet: true,
  lastBackupAt: null,
);

final _defaultEntry = BackupFileEntry(
  name: 'metra_2026-05-17T12-00-00Z.enc',
  timestampUtc: DateTime.utc(2026, 5, 17, 12),
  sizeBytes: 2048,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Mounts [BackupScreen] with [_connectedState] + given overrides.
///
/// Uses a tall viewport so all rows render without scrolling (mirrors H-2
/// in backup_screen_test.dart).
Widget _wrap({
  required _StubBackupNotifier stub,
  required InMemorySecureStorage storage,
  FakeDropboxProvider? fakeProvider,
}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => stub),
      secureStorageProvider.overrideWithValue(storage),
      cloudBackupProvider.overrideWithValue(
        fakeProvider ?? FakeDropboxProvider(seedEntries: [_defaultEntry]),
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
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // I-H — Backup with cached passphrase (backupNow path, no dialog)
  // =========================================================================

  group(
    'I-H — backup_with_cached_passphrase_calls_backupNow_without_any_dialog',
    () {
      testWidgets(
        'should_call_backupNow_and_show_no_dialog_given_passphrase_in_storage',
        (tester) async {
          tester.view.physicalSize = const Size(2400, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final storage = InMemorySecureStorage();
          // Seed a cached passphrase so handleBackup takes the silent path.
          storage.values[BackupNotifier.kPassphraseKey] = 'my-secret-phrase';

          final stub = _StubBackupNotifier(_connectedState);

          await tester.pumpWidget(_wrap(stub: stub, storage: storage));
          await tester.pumpAndSettle();

          // Tap "Back up now" row.
          await tester.tap(find.text('Back up now'));
          await tester.pumpAndSettle();

          // No dialog of any kind should appear.
          expect(
            find.byType(MetraConfirmDialog),
            findsNothing,
            reason: 'handleBackup has no confirmation dialog gate',
          );
          expect(
            find.byType(PassphraseDialog),
            findsNothing,
            reason: 'cached passphrase path skips PassphraseDialog',
          );

          // backupNow must have been called exactly once.
          expect(stub.backupNowCallCount, 1);
          expect(stub.backupSilentCallCount, 0);
          expect(stub.backupWithPassphraseCallCount, 0);
        },
      );
    },
  );

  // =========================================================================
  // I-I — Backup first-time (no cached passphrase → PassphraseDialog)
  // =========================================================================

  group(
    'I-I — backup_first_time_no_cache_shows_PassphraseDialog_and_captures_passphrase',
    () {
      testWidgets(
        'should_show_PassphraseDialog_and_capture_passphrase_given_empty_storage',
        (tester) async {
          tester.view.physicalSize = const Size(2400, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // Empty storage → no cached passphrase.
          final storage = InMemorySecureStorage();
          final stub = _StubBackupNotifier(_connectedState);

          await tester.pumpWidget(_wrap(stub: stub, storage: storage));
          await tester.pumpAndSettle();

          // Tap "Back up now".
          await tester.tap(find.text('Back up now'));
          await tester.pumpAndSettle();

          // PassphraseDialog (setNew mode) must appear.
          expect(
            find.byType(PassphraseDialog),
            findsOneWidget,
            reason: 'first-time backup must prompt for a new passphrase',
          );

          // Enter a valid passphrase in both fields (min 8 chars).
          const testPassphrase = 'metra-test-secret';
          final fields = find.byType(TextField);
          await tester.enterText(fields.at(0), testPassphrase);
          await tester.pump();
          await tester.enterText(fields.at(1), testPassphrase);
          await tester.pump();

          // Tap the confirm button.
          await tester.tap(
            find.text('I understand — save and back up'),
          );
          await tester.pumpAndSettle();

          // The passphrase must have reached backupWithPassphrase.
          expect(stub.capturedBackupPassphrase, isNotNull);
          expect(stub.capturedBackupPassphrase, equals(testPassphrase));
        },
      );
    },
  );

  // =========================================================================
  // I-J — HC-2 guard on restore: MetraConfirmDialog appears BEFORE
  //        restoreWithPassphrase is called.
  //
  // The HC-2 confirmation gate lives on handleRestore (step 3), not on
  // handleBackup. This test verifies the ordering contract:
  //   tap restore → picker → confirm dialog fires → only THEN restoreWithPassphrase.
  // =========================================================================

  group(
    'I-J — HC2_guard_order_restore_confirm_dialog_fires_before_restoreWithPassphrase',
    () {
      testWidgets(
        'should_show_MetraConfirmDialog_before_calling_restoreWithPassphrase',
        (tester) async {
          // Platform override required for CupertinoPicker inside BackupPickerSheet.
          // Reset explicitly at the end of the test (mirrors settings_screen_test.dart
          // pattern — more reliable than addTearDown for foundation debug vars).
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          tester.view.physicalSize = const Size(2400, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final storage = InMemorySecureStorage();
          // Seed a passphrase so the restore unlock dialog completes.
          storage.values[BackupNotifier.kPassphraseKey] = 'existing-pass';
          final stub = _StubBackupNotifier(_connectedState);

          await tester.pumpWidget(_wrap(stub: stub, storage: storage));
          await tester.pumpAndSettle();

          // Tap the restore action row.
          await tester.tap(find.byKey(const Key('backup_restore_action_row')));
          await tester.pumpAndSettle();

          // Picker appears (step 2). Tap confirm ("Restore" in picker toolbar).
          expect(find.byType(BackupPickerSheet), findsOneWidget);
          await tester.tap(find.text('Restore').first);
          await tester.pumpAndSettle();

          // Step 3: MetraConfirmDialog must appear now.
          expect(
            find.byType(MetraConfirmDialog),
            findsOneWidget,
            reason: 'HC-2 gate: confirm dialog must appear BEFORE restore',
          );

          // At this point, restoreWithPassphrase has NOT been called yet.
          expect(
            stub.capturedRestorePassphrase,
            isNull,
            reason: 'restoreWithPassphrase must not be called before confirm',
          );

          // Confirm the dialog — tap the confirm label (last occurrence avoids
          // picker's "Restore" text — lesson #017).
          await tester.tap(find.text('Restore').last);
          await tester.pumpAndSettle();

          // Step 4: PassphraseDialog (unlock mode) now appears.
          expect(find.byType(PassphraseDialog), findsOneWidget);

          // Enter unlock passphrase and confirm.
          await tester.enterText(find.byType(TextField).first, 'existing-pass');
          await tester.pump();
          await tester.tap(find.text('Unlock and restore'));
          await tester.pumpAndSettle();

          // restoreWithPassphrase has now been called.
          expect(
            stub.capturedRestorePassphrase,
            isNotNull,
            reason:
                'restoreWithPassphrase must be called after full confirm flow',
          );

          // Explicit reset (must be last statement before test ends).
          debugDefaultTargetPlatformOverride = null;
        },
      );
    },
  );

  // =========================================================================
  // I-K — Disconnect: (a) cancel → no call; (b) confirm → disconnect called
  // =========================================================================

  group(
    'I-K — disconnect_cancel_and_confirm_paths',
    () {
      testWidgets(
        'should_not_call_disconnect_when_confirm_dialog_is_cancelled',
        (tester) async {
          tester.view.physicalSize = const Size(2400, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(_connectedState);

          await tester.pumpWidget(
            _wrap(stub: stub, storage: InMemorySecureStorage()),
          );
          await tester.pumpAndSettle();

          // Tap disconnect row.
          await tester.tap(find.byKey(const Key('backup_disconnect_row')));
          await tester.pumpAndSettle();

          // Confirmation dialog appears.
          expect(find.byType(MetraConfirmDialog), findsOneWidget);

          // Tap cancel.
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();

          // Disconnect must not have been called.
          expect(stub.disconnectCallCount, 0);
        },
      );

      testWidgets(
        'should_call_disconnect_when_confirm_dialog_is_confirmed',
        (tester) async {
          tester.view.physicalSize = const Size(2400, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(_connectedState);

          await tester.pumpWidget(
            _wrap(stub: stub, storage: InMemorySecureStorage()),
          );
          await tester.pumpAndSettle();

          // Tap disconnect row.
          await tester.tap(find.byKey(const Key('backup_disconnect_row')));
          await tester.pumpAndSettle();

          // Confirmation dialog appears.
          expect(find.byType(MetraConfirmDialog), findsOneWidget);

          // Tap confirm ("Disconnect").
          await tester.tap(find.text('Disconnect').last);
          await tester.pumpAndSettle();

          // Disconnect must have been called once.
          expect(stub.disconnectCallCount, 1);
        },
      );
    },
  );

  // =========================================================================
  // I-L — Disconnect failure → BackupErrorView
  // =========================================================================

  group(
    'I-L — disconnect_failure_renders_BackupErrorView',
    () {
      testWidgets(
        'should_render_BackupErrorView_when_disconnect_throws',
        (tester) async {
          tester.view.physicalSize = const Size(2400, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(_connectedState);
          stub.disconnectFailMessage = 'Disconnect failed — provider error';

          await tester.pumpWidget(
            _wrap(stub: stub, storage: InMemorySecureStorage()),
          );
          await tester.pumpAndSettle();

          // Tap disconnect row.
          await tester.tap(find.byKey(const Key('backup_disconnect_row')));
          await tester.pumpAndSettle();

          // Confirm the disconnect dialog.
          await tester.tap(find.text('Disconnect').last);
          await tester.pumpAndSettle();

          // BackupErrorView must appear with the error message.
          expect(find.byType(BackupErrorView), findsOneWidget);
          expect(
            find.text('Disconnect failed — provider error'),
            findsOneWidget,
          );
        },
      );
    },
  );

  // =========================================================================
  // I-O — Empty backup list → BackupPickerSheet EmptySheet variant
  // =========================================================================

  group(
    'I-O — empty_backup_list_shows_EmptySheet_in_BackupPickerSheet',
    () {
      testWidgets(
        'should_open_BackupPickerSheet_with_empty_list_and_disabled_confirm',
        (tester) async {
          // Platform override: CupertinoPicker inside BackupPickerSheet requires
          // Cupertino rendering. Reset explicitly at end of test body.
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          tester.view.physicalSize = const Size(2400, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final stub = _StubBackupNotifier(_connectedState);
          // FakeDropboxProvider with empty seed list → no backup files.
          final emptyProvider = FakeDropboxProvider(seedEntries: []);

          await tester.pumpWidget(
            _wrap(
              stub: stub,
              storage: InMemorySecureStorage(),
              fakeProvider: emptyProvider,
            ),
          );
          await tester.pumpAndSettle();

          // Tap the restore action row.
          await tester.tap(find.byKey(const Key('backup_restore_action_row')));
          await tester.pumpAndSettle();

          // BackupPickerSheet must appear in its empty-list variant.
          expect(find.byType(BackupPickerSheet), findsOneWidget);

          // EmptySheet shows the empty-list label.
          expect(
            find.text('No backups found on the provider.'),
            findsOneWidget,
          );

          // EmptySheet renders the confirm button with Semantics.enabled == false
          // (disabled) — it is visible but not interactive.
          final confirmSemanticsWidget = tester.widget<Semantics>(
            find
                .ancestor(
                  of: find.text('Restore'),
                  matching: find.byType(Semantics),
                )
                .first,
          );
          expect(
            confirmSemanticsWidget.properties.enabled,
            isFalse,
            reason:
                'EmptySheet Restore button must have Semantics.enabled==false',
          );

          // Explicit reset (must be last statement before test ends).
          debugDefaultTargetPlatformOverride = null;
        },
      );
    },
  );
}
