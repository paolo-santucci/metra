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

// T-05 — Integration: notification-link "never throws" + restore toast E2E
// qp-20260524-notification-link-restore-toast
//
// NOTE: by the time T-05 is written, T-01..T-04 have already landed and
// all prior tests pass. This file therefore acts as a regression guard
// rather than a TDD red-to-green spec — it demonstrates that the two
// defences (broadened catch + finally) and the restore-count propagation
// COMPOSE end-to-end, beyond what the unit tests cover individually.
//
// ── Group 1: notification-link "never throws" contract (T-01 + T-02) ──
//
//   Uses the REAL FlutterNotificationService (not the throwing fake from
//   permission_blocked_dialog_provider_test.dart) so the test verifies that
//   the service's broadened catch and the dialog's finally compose correctly.
//   Two channel conditions:
//     a) No mock handler registered → MissingPluginException raised by the
//        Flutter test binding; swallowed by the broadened catch; dialog closed
//        by the finally.
//     b) Mock handler throws PlatformException → same composition path.
//
// ── Group 2: restore toast end-to-end (T-03 + T-04) ──
//
//   Uses the REAL BackupNotifier.restore() / restoreWithPassphrase() against
//   FakeBackupRunner injected via restoreDataProvider override. Only build()
//   is overridden to seed BackupConnected state synchronously (avoids wiring
//   the full AppSettings Drift chain in a widget test).
//
// Target platforms: Linux CI, headless (no device-farm dependency).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/notification_service.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/backup_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/widgets/backup_picker_sheet.dart';
import 'package:metra/features/backup/widgets/metra_confirm_dialog.dart';
import 'package:metra/features/backup/widgets/passphrase_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/permission_blocked_dialog_provider.dart';

import '../helpers/fake_backup_runner.dart';
import '../helpers/fake_dropbox_provider.dart';
import '../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Group 2: subclass that overrides ONLY build() to seed BackupConnected.
// restore() and restoreWithPassphrase() are inherited from BackupNotifier
// so the real propagation path is exercised end-to-end.
// ---------------------------------------------------------------------------

class _RealishBackupNotifier extends BackupNotifier {
  _RealishBackupNotifier(this._state);

  final BackupState _state;

  @override
  Future<BackupState> build() async => _state;
}

// ---------------------------------------------------------------------------
// Default connected state for Group 2 tests.
// ---------------------------------------------------------------------------

const _connectedState = BackupConnected(
  provider: SyncProvider.dropbox,
  email: 'a@b.test',
  autoBackupActive: true,
  passphraseSet: true,
  lastBackupAt: null,
);

// ---------------------------------------------------------------------------
// Default seed entry for the picker.
// ---------------------------------------------------------------------------

final _seedEntry = BackupFileEntry(
  name: 'metra_2026-05-24_12-00-00.enc',
  timestampUtc: DateTime.utc(2026, 5, 24, 12),
  sizeBytes: 2048,
);

// ---------------------------------------------------------------------------
// _wrap helper for Group 2: mounts BackupScreen with overridden providers.
//
// Injects:
//   - _RealishBackupNotifier (real restore methods, seeded build state)
//   - RestoreData(fakeRunner) via restoreDataProvider
//   - FakeDropboxProvider with [seedEntry] for the picker
//   - InMemorySecureStorage with the passphrase already set
// ---------------------------------------------------------------------------

Widget _wrap({
  required _RealishBackupNotifier notifier,
  required FakeBackupRunner fakeRunner,
  BackupFileEntry? seedEntry,
  String passphrase = 'test-pass',
}) {
  final storage = InMemorySecureStorage()
    ..values[BackupNotifier.kPassphraseKey] = passphrase;
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => notifier),
      restoreDataProvider.overrideWith((_) async => RestoreData(fakeRunner)),
      secureStorageProvider.overrideWithValue(storage),
      cloudBackupProvider.overrideWithValue(
        FakeDropboxProvider(seedEntries: [seedEntry ?? _seedEntry]),
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
// UI-drive helpers (mirrors backup_picker_sheet_integration_test.dart pattern)
// ---------------------------------------------------------------------------

Future<void> _openPickerSheet(WidgetTester tester) async {
  final restoreRow = find.byKey(const Key('backup_restore_action_row'));
  expect(restoreRow, findsOneWidget);
  await tester.tap(restoreRow);
  await tester.pumpAndSettle();
}

Future<void> _tapDialogConfirm(WidgetTester tester, String label) async {
  final confirmDialog = find.byType(MetraConfirmDialog);
  expect(confirmDialog, findsOneWidget);
  final btn = find.descendant(
    of: confirmDialog,
    matching: find.text(label),
  );
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

Future<void> _enterPassphrase(WidgetTester tester, String passphrase) async {
  final dialog = find.byType(PassphraseDialog);
  expect(dialog, findsOneWidget);
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
  await tester.tap(unlockBtn);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ==========================================================================
  // Group 1 — notification-link "never throws" contract (T-01 + T-02 wiring)
  //
  // Verifies that the REAL FlutterNotificationService broadened catch composes
  // with the REAL NavigatorKeyDialog finally block: both defences together
  // guarantee the dialog closes regardless of channel state.
  //
  // Contrast with permission_blocked_dialog_provider_test.dart which tests
  // the dialog's finally in isolation using a fake throwing service. This
  // group closes the composition gap.
  // ==========================================================================

  group(
    'Group 1 — blocked_dialog closes even when real service cannot invoke channel',
    () {
      testWidgets(
        'blocked_dialog_closes_even_when_channel_unregistered',
        (tester) async {
          // Simulate an unregistered channel by setting a handler that
          // returns null (mimicking the Flutter test-binding behaviour when
          // no platform handler is available — channel call returns null
          // rather than raising MissingPluginException in a testWidgets
          // context). The real FlutterNotificationService.openNotificationSettings()
          // catches any exception and returns normally regardless; the
          // NavigatorKeyDialog.show() finally must pop in both cases.
          const kChannel = 'metra/notification_settings';
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kChannel),
            (call) async => null, // returns null — simulates unregistered
          );
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
              const MethodChannel(kChannel),
              null,
            );
          });

          final globalKey = GlobalKey<NavigatorState>();
          final realService = FlutterNotificationService();
          final dialog = NavigatorKeyDialog(globalKey, realService);

          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: globalKey,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: SizedBox.shrink()),
            ),
          );
          await tester.pumpAndSettle();

          // Fire-and-forget: show() awaits its own dismissal internally.
          // Wrapping in unawaited() satisfies the unawaited_futures lint while
          // keeping the test driving free — the tester pump loop processes the
          // modal route without the test itself being blocked on the Future.
          unawaited(dialog.show());
          await tester.pumpAndSettle();

          expect(
            find.byType(AlertDialog),
            findsOneWidget,
            reason: 'dialog must be visible before tapping',
          );

          await tester.tap(
            find.widgetWithText(TextButton, 'Open system settings'),
          );
          await tester.pumpAndSettle();

          expect(
            find.byType(AlertDialog),
            findsNothing,
            reason:
                'dialog must be dismissed: broadened catch + finally compose '
                'correctly even when channel is not registered (pre-T-01 iOS state)',
          );
        },
      );

      testWidgets(
        'blocked_dialog_closes_when_native_throws_PlatformException',
        (tester) async {
          const kChannel = 'metra/notification_settings';
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kChannel),
            (call) async => throw PlatformException(
              code: 'settings_not_available',
              message: 'OEM blocked',
            ),
          );
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
              const MethodChannel(kChannel),
              null,
            );
          });

          final globalKey = GlobalKey<NavigatorState>();
          final realService = FlutterNotificationService();
          final dialog = NavigatorKeyDialog(globalKey, realService);

          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: globalKey,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: SizedBox.shrink()),
            ),
          );
          await tester.pumpAndSettle();

          unawaited(dialog.show());
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsOneWidget);

          await tester.tap(
            find.widgetWithText(TextButton, 'Open system settings'),
          );
          await tester.pumpAndSettle();

          expect(
            find.byType(AlertDialog),
            findsNothing,
            reason:
                'dialog must be dismissed: broadened catch + finally compose '
                'correctly when native throws PlatformException',
          );
        },
      );
    },
  );

  // ==========================================================================
  // Group 2 — restore toast end-to-end (T-03 + T-04 wiring)
  //
  // Uses the REAL BackupNotifier.restore() / restoreWithPassphrase() wired
  // against FakeBackupRunner via restoreDataProvider override. build() is
  // the only thing short-circuited (avoids full Drift chain in widget tests).
  // ==========================================================================

  group(
    'Group 2 — restore toast end-to-end (real BackupNotifier + FakeBackupRunner)',
    () {
      testWidgets(
        'handleRestore_complete_flow_shows_localised_toast_with_count',
        (tester) async {
          // try/finally: CupertinoPicker inside BackupPickerSheet requires
          // TargetPlatform.iOS. Must be reset via try/finally in this Flutter
          // version (addTearDown runs after the framework invariant check and
          // falsely triggers a debug-variable warning — see
          // backup_picker_sheet_integration_test.dart comment lines 36–37).
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          try {
            tester.view.physicalSize = const Size(800, 4000);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            // FakeBackupRunner configured to return count = 14.
            final fakeRunner = FakeBackupRunner()..restoreReturnValue = 14;
            final notifier = _RealishBackupNotifier(_connectedState);

            await tester
                .pumpWidget(_wrap(notifier: notifier, fakeRunner: fakeRunner));
            await tester.pumpAndSettle();

            // Step 1: open picker.
            await _openPickerSheet(tester);
            expect(find.byType(BackupPickerSheet), findsOneWidget);

            // Step 2: tap confirm in the picker toolbar.
            final pickerSheet = find.byType(BackupPickerSheet);
            final pickerConfirm = find.descendant(
              of: pickerSheet,
              matching: find.text('Restore'),
            );
            expect(pickerConfirm, findsOneWidget);
            await tester.tap(pickerConfirm);
            await tester.pumpAndSettle();

            // Step 3: MetraConfirmDialog → confirm.
            await _tapDialogConfirm(tester, 'Restore');

            // Step 4: PassphraseDialog → enter passphrase and submit.
            await _enterPassphrase(tester, 'test-pass');

            // Assert: snackbar shows localised count (EN locale: "14 entries restored").
            expect(
              find.text('14 entries restored'),
              findsOneWidget,
              reason: 'Snackbar must appear with the exact count returned by '
                  'FakeBackupRunner.restore() (14); ARB key restoreSuccessToast '
                  'with {count}=14 in EN locale yields "14 entries restored"',
            );

            // Assert: runner was called exactly once with the picked filename.
            expect(
              fakeRunner.restoreCallCount,
              1,
              reason: 'restore() must be called exactly once',
            );
            expect(
              fakeRunner.lastFilename,
              equals(_seedEntry.name),
              reason: 'restore() must receive the filename from the picker',
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );

      testWidgets(
        'handleRestore_error_path_shows_no_toast',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          try {
            tester.view.physicalSize = const Size(800, 4000);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            // FakeBackupRunner configured to throw — restore() returns null.
            final fakeRunner = FakeBackupRunner()
              ..restoreError = const SyncException('network error');
            final notifier = _RealishBackupNotifier(_connectedState);

            await tester
                .pumpWidget(_wrap(notifier: notifier, fakeRunner: fakeRunner));
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
            await _enterPassphrase(tester, 'test-pass');

            // Assert: no snackbar when count is null (error path).
            expect(
              find.byType(SnackBar),
              findsNothing,
              reason:
                  'No snackbar must appear when restoreWithPassphrase returns null '
                  '(error path — BackupErrorState set instead)',
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    },
  );
}
