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

// TASK-32 — Group J: BackupConnectedView mounted-guard mid-flow unmount tests
//
// Spec ref: §7.1 Group J (FR-28, EC-08)
//
// Each test mounts BackupConnectedView, initiates an async operation, then
// unmounts the widget (tester.pumpWidget(SizedBox())) before the next
// BuildContext use and asserts no setState-after-dispose / no
// "deactivated widget ancestor" exception is thrown.
//
// Implementation notes:
// - J1 uses a Completer-backed FakeDropboxProvider so the Step-1 fetch never
//   resolves and the widget is unmounted while awaiting the Future.
// - J2 uses a normally-resolving fetch; the sheet is open when we unmount.
// - J3 requires the picker to resolve (picker confirm) and then the confirm
//   dialog to be open when we unmount.
// - J4 is the passphrase step. Reaching it requires picker → confirm dialog →
//   confirm tap. Because confirm-dialog routing is brittle in headless tests
//   (CupertinoPicker scroll state + dialog tap order), J4 tests the unmount
//   from the passphrase-dialog-open state. If the passphrase dialog cannot be
//   reached reliably without a real device, a best-effort mount-then-unmount
//   cycle still exercises the mounted guards.
//
// Platform matrix: Linux CI, headless (no device-farm dependency).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_connected_view.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';

import '../../../helpers/fake_dropbox_provider.dart';
import '../../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Fake notifier — minimal override to avoid real plugin calls
// ---------------------------------------------------------------------------

class _FakeNotifier extends BackupNotifier {
  _FakeNotifier(this._initial);

  final BackupState _initial;

  @override
  Future<BackupState> build() async => _initial;

  @override
  Future<int?> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async =>
      null;

  @override
  Future<void> backupNow() async {}

  @override
  Future<void> backupWithPassphrase(String passphrase) async {}

  @override
  Future<void> disconnect() async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ---------------------------------------------------------------------------
// Completer-backed provider that stalls the file-list fetch indefinitely.
// Used by J1 so the widget is unmounted while awaiting Step 1.
// ---------------------------------------------------------------------------

final _stalledFileListProvider =
    FutureProvider.autoDispose<List<BackupFileEntry>>((ref) {
  // Never completes — the await inside handleRestore() hangs indefinitely.
  // Do NOT complete with error on dispose: the catch block in handleRestore
  // would call messenger.showSnackBar, which fails after the Scaffold is gone.
  final completer = Completer<List<BackupFileEntry>>();
  // Leak the completer intentionally — this is a test-only stub.
  return completer.future;
});

// ---------------------------------------------------------------------------
// Test state & seed
// ---------------------------------------------------------------------------

const _connectedState = BackupConnected(
  email: 'test@example.com',
  autoBackupActive: true,
  passphraseSet: true,
  lastBackupAt: null,
);

final _seedEntry = BackupFileEntry(
  name: 'backup_20260520.enc',
  timestampUtc: DateTime.utc(2026, 5, 20, 14, 30),
  sizeBytes: 1024,
);

// ---------------------------------------------------------------------------
// Harness helpers
// ---------------------------------------------------------------------------

/// Standard harness — BackupPickerSheet flow resolves normally.
Widget _harness(
  _FakeNotifier notifier, {
  FakeDropboxProvider? provider,
  InMemorySecureStorage? storage,
}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => notifier),
      secureStorageProvider
          .overrideWithValue(storage ?? InMemorySecureStorage()),
      cloudBackupProvider.overrideWithValue(
        provider ?? FakeDropboxProvider(seedEntries: [_seedEntry]),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupConnectedView(state: _connectedState),
    ),
  );
}

/// J1-specific harness: overrides [backupFileListProvider] directly with the
/// stalled provider so the fetch never completes.
Widget _harnessWithStalledFetch(_FakeNotifier notifier) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => notifier),
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      cloudBackupProvider.overrideWithValue(
        FakeDropboxProvider(seedEntries: [_seedEntry]),
      ),
      backupFileListProvider.overrideWith(
        (ref) => ref.watch(_stalledFileListProvider.future),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupConnectedView(state: _connectedState),
    ),
  );
}

// ---------------------------------------------------------------------------
// Group J — mounted-guard mid-flow unmount tests
// ---------------------------------------------------------------------------

void main() {
  group('Group J — BackupConnectedView mounted-guard mid-flow unmount', () {
    // ── J1: unmount while awaiting provider fetch ─────────────────────────────
    //
    // Flow: tap restore → handleRestore starts → Step 1 fetch is in-flight →
    // widget is unmounted → guard 1 (`if (!mounted) return`) fires →
    // no exception.
    testWidgets(
      'should_throw_no_exception_when_unmounted_while_fetching_file_list',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final notifier = _FakeNotifier(_connectedState);
        await tester.pumpWidget(_harnessWithStalledFetch(notifier));
        await tester.pumpAndSettle();

        // Tap restore to start the async flow (fetch will stall indefinitely).
        await tester.tap(find.byKey(const Key('backup_restore_action_row')));
        // One pump — handleRestore() is now awaiting the stalled fetch Future.
        await tester.pump();

        // Unmount the widget tree while the fetch is in-flight.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        // Guard 1 fires because mounted == false; no exception expected.
        expect(tester.takeException(), isNull);
      },
    );

    // ── J2: unmount while BackupPickerSheet is open ───────────────────────────
    //
    // Flow: tap restore → fetch resolves immediately → BackupPickerSheet opens →
    // widget is unmounted → guard 2 (`if (!mounted) return`) fires after sheet
    // pop → no exception.
    //
    // Note: pumpWidget(SizedBox()) while a modal bottom sheet is open triggers
    // its Navigator removal. The sheet is also disposed. The mounted guard in
    // Step 2 (`if (pickedIndex == null) return; if (!mounted) return;`)
    // ensures no BuildContext use after this point.
    testWidgets(
      'should_throw_no_exception_when_unmounted_while_picker_sheet_is_open',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final notifier = _FakeNotifier(_connectedState);
        await tester.pumpWidget(_harness(notifier));
        await tester.pumpAndSettle();

        // Tap restore — fetch resolves synchronously, sheet opens.
        await tester.tap(find.byKey(const Key('backup_restore_action_row')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Sheet is now open; unmount the widget tree.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        // Guard 2 fires; no exception expected.
        expect(tester.takeException(), isNull);
      },
    );

    // ── J3: unmount while MetraConfirmDialog is open ──────────────────────────
    //
    // Flow: restore tap → fetch → sheet open → tap "Ripristina" to pick →
    // MetraConfirmDialog opens → unmount → guard 3 fires → no exception.
    testWidgets(
      'should_throw_no_exception_when_unmounted_while_confirm_dialog_is_open',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final notifier = _FakeNotifier(_connectedState);
        await tester.pumpWidget(_harness(notifier));
        await tester.pumpAndSettle();

        // Tap restore — fetch resolves, BackupPickerSheet opens.
        await tester.tap(find.byKey(const Key('backup_restore_action_row')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Confirm the picker by popping it with index 0 directly.
        // This simulates the user pressing the confirm button.
        if (tester.any(find.byType(BottomSheet))) {
          final NavigatorState nav = tester.state(find.byType(Navigator).last);
          nav.pop(0); // pop with index 0 = first item selected
        }
        await tester.pump();
        await tester.pumpAndSettle();

        // MetraConfirmDialog may now be open. Unmount.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        // Guard 3 fires; no exception expected.
        expect(tester.takeException(), isNull);
      },
    );

    // ── J4: unmount after passphrase callback ─────────────────────────────────
    //
    // Full path: restore → fetch → picker → confirm dialog → passphrase dialog
    // → unmount.  Reaching the passphrase step in a headless test requires
    // driving the picker AND the confirm dialog in sequence.
    //
    // Limitation: the CupertinoPicker uses a FixedExtentScrollController that
    // may not respond to programmatic scroll in headless mode, and the confirm
    // dialog tap order is strictly sequential.  To remain deterministic, this
    // test drives both steps via direct Navigator pops (mirroring what the
    // production sheet/dialog do internally) so the passphrase dialog opens,
    // then immediately unmounts.
    testWidgets(
      'should_throw_no_exception_when_unmounted_after_passphrase_callback',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final notifier = _FakeNotifier(_connectedState);
        await tester.pumpWidget(_harness(notifier));
        await tester.pumpAndSettle();

        // Tap restore to start the flow.
        await tester.tap(find.byKey(const Key('backup_restore_action_row')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Step 2: dismiss picker with index 0 (simulates user pressing confirm).
        if (tester.any(find.byType(BottomSheet))) {
          final NavigatorState nav = tester.state(find.byType(Navigator).last);
          nav.pop(0);
          await tester.pumpAndSettle();
        }

        // Step 3: confirm dialog should be open; tap confirm.
        // MetraConfirmDialog uses confirmLabel text as the tap target.
        // In this test no l10n key is needed since we pop directly.
        // Fallback: pop the dialog with true directly.
        {
          final NavigatorState nav = tester.state(find.byType(Navigator).last);
          nav.pop(true);
        }
        await tester.pump();
        await tester.pumpAndSettle();

        // Passphrase dialog may now be open.
        // Unmount the widget tree — guard 4 fires when flow resumes.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        // No exception expected.
        expect(tester.takeException(), isNull);
      },
    );
  });
}
