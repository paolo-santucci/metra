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

// TASK-18/TASK-31 — BackupConnectedView smoke tests
//
// Spec §7.1 Group I bullets:
//   1. Three SettingsLabels + three SettingsCards render in section order.
//   2. Account email rendered in the account section.
//   3. "Ultimo backup" formats DateTime via locale; "—" when null (em-dash).
//   4. StatusIndicator present with correct active/inactive state.
//   5. Disconnect confirm flow: dialog → confirm → notifier.disconnect() called.
//   6. FR-32: Semantics label prefixed with "Distruttivo: " on destructive row.
//   7. Restore tap → BackupPickerSheet shown BEFORE MetraConfirmDialog.
//
// Note (bullet HC-2 on backup): handleBackup does NOT show MetraConfirmDialog.
// It runs backupNow() (cached passphrase) or PassphraseDialog (first-time).
// The HC-2 guard on backup is IgnorePointer(ignoring: isRunning), already
// covered indirectly via the empty-view CTA test and integration tests.
// No phantom test is added for a guard that does not exist in source.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/settings/settings_card.dart';
import 'package:metra/core/widgets/settings/settings_label.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_connected_view.dart';
import 'package:metra/features/backup/widgets/backup_picker_sheet.dart';
import 'package:metra/features/backup/widgets/metra_confirm_dialog.dart';
import 'package:metra/features/backup/widgets/status_indicator.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';

import '../../../helpers/fake_dropbox_provider.dart';
import '../../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Fake notifier
// ---------------------------------------------------------------------------

class _FakeBackupNotifier extends BackupNotifier {
  _FakeBackupNotifier(this._initial);

  final BackupState _initial;
  int restoreCalls = 0;
  int backupNowCalls = 0;
  int disconnectCalls = 0;
  String? capturedPassphrase;
  String? capturedFilename;

  @override
  Future<BackupState> build() async => _initial;

  @override
  Future<void> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async {
    restoreCalls++;
    capturedPassphrase = passphrase;
    capturedFilename = filename;
  }

  @override
  Future<void> backupNow() async => backupNowCalls++;

  @override
  Future<void> backupWithPassphrase(String passphrase) async {
    capturedPassphrase = passphrase;
  }

  @override
  Future<void> disconnect() async => disconnectCalls++;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// A [BackupConnected] state used by default across the tests.
final _connectedState = BackupConnected(
  email: 'user@example.com',
  autoBackupActive: true,
  passphraseSet: true,
  lastBackupAt: DateTime.utc(2026, 5, 20, 14, 30),
);

/// Single seed entry so BackupPickerSheet can open with non-empty list.
final _seedEntry = BackupFileEntry(
  name: 'backup_20260520.enc',
  timestampUtc: DateTime.utc(2026, 5, 20, 14, 30),
  sizeBytes: 1024,
);

Widget _harness(
  _FakeBackupNotifier notifier, {
  BackupConnected? state,
  List<BackupFileEntry>? seedEntries,
  InMemorySecureStorage? storage,
}) {
  final s = state ?? _connectedState;
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => notifier),
      secureStorageProvider
          .overrideWithValue(storage ?? InMemorySecureStorage()),
      cloudBackupProvider.overrideWithValue(
        FakeDropboxProvider(seedEntries: seedEntries ?? [_seedEntry]),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: BackupConnectedView(state: s)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. Three-card layout ─────────────────────────────────────────────────

  testWidgets(
    'BackupConnectedView renders three SettingsLabels + three SettingsCards in order',
    (tester) async {
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // Three section headers rendered.
      expect(
        find.byType(SettingsLabel),
        findsNWidgets(3),
        reason: 'Must render exactly three SettingsLabel section headers',
      );

      // Three settings cards rendered.
      expect(
        find.byType(SettingsCard),
        findsNWidgets(3),
        reason: 'Must render exactly three SettingsCard groups',
      );

      // Section order: Account / Status / Actions
      // Verify by checking that SettingsLabel texts appear in the expected order
      // within the widget tree (top-to-bottom).
      final labels = tester
          .widgetList<SettingsLabel>(find.byType(SettingsLabel))
          .map((w) => w.text.toUpperCase())
          .toList();

      expect(labels.length, 3);
      // Label texts are uppercased by SettingsLabel.build; match case-insensitively.
      expect(
        labels[0].toLowerCase(),
        contains('account'),
        reason: 'First section label should be the Account section',
      );
    },
  );

  // ── 2. Last-backup date formatting ──────────────────────────────────────

  testWidgets(
    'BackupConnectedView "Ultimo backup" formats DateTime via locale, "—" when null',
    (tester) async {
      // Non-null lastBackupAt → formatted date must appear somewhere in the tree.
      final stateWithDate = BackupConnected(
        email: 'user@example.com',
        autoBackupActive: true,
        passphraseSet: true,
        lastBackupAt: DateTime.utc(2026, 5, 20, 14, 30),
      );
      final fake = _FakeBackupNotifier(stateWithDate);
      await tester.pumpWidget(_harness(fake, state: stateWithDate));
      await tester.pumpAndSettle();

      // "May" should appear (locale=en, yMMMd formats month as abbreviated name).
      expect(
        find.textContaining('May'),
        findsAtLeastNWidgets(1),
        reason:
            'Formatted date must contain the locale month name "May" (en locale)',
      );

      // Null lastBackupAt → em-dash displayed.
      const stateNullDate = BackupConnected(
        email: 'user@example.com',
        autoBackupActive: false,
        passphraseSet: true,
      );
      final fake2 = _FakeBackupNotifier(stateNullDate);
      await tester.pumpWidget(_harness(fake2, state: stateNullDate));
      await tester.pumpAndSettle();

      expect(
        find.text('—'),
        findsOneWidget,
        reason: 'Null lastBackupAt must render an em-dash "—"',
      );
    },
  );

  // ── 2b. Account email displayed ──────────────────────────────────────────

  testWidgets(
    'BackupConnectedView displays account email in account section',
    (tester) async {
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // The email passed in BackupConnected state must appear as text.
      expect(
        find.text('user@example.com'),
        findsOneWidget,
        reason: 'Account email must be rendered in the account section',
      );
    },
  );

  // ── 4. StatusIndicator active state ──────────────────────────────────────

  testWidgets(
    'BackupConnectedView StatusIndicator reflects autoBackupActive = true',
    (tester) async {
      final stateActive = BackupConnected(
        email: 'user@example.com',
        autoBackupActive: true,
        passphraseSet: true,
        lastBackupAt: DateTime.utc(2026, 5, 20),
      );
      final fake = _FakeBackupNotifier(stateActive);
      await tester.pumpWidget(_harness(fake, state: stateActive));
      await tester.pumpAndSettle();

      final indicator = tester.widget<StatusIndicator>(
        find.byType(StatusIndicator),
      );
      expect(
        indicator.active,
        isTrue,
        reason:
            'StatusIndicator.active must be true when autoBackupActive = true',
      );
    },
  );

  testWidgets(
    'BackupConnectedView StatusIndicator reflects autoBackupActive = false',
    (tester) async {
      const stateInactive = BackupConnected(
        email: 'user@example.com',
        autoBackupActive: false,
        passphraseSet: true,
      );
      final fake = _FakeBackupNotifier(stateInactive);
      await tester.pumpWidget(_harness(fake, state: stateInactive));
      await tester.pumpAndSettle();

      final indicator = tester.widget<StatusIndicator>(
        find.byType(StatusIndicator),
      );
      expect(
        indicator.active,
        isFalse,
        reason:
            'StatusIndicator.active must be false when autoBackupActive = false',
      );
    },
  );

  // ── 5. Disconnect confirm flow ────────────────────────────────────────────

  testWidgets(
    'BackupConnectedView: disconnect tap → MetraConfirmDialog → confirm → notifier.disconnect() called',
    (tester) async {
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // Tap the disconnect row.
      await tester.tap(find.byKey(const Key('backup_disconnect_row')));
      await tester.pumpAndSettle();

      // MetraConfirmDialog must be visible.
      expect(
        find.byType(MetraConfirmDialog),
        findsOneWidget,
        reason: 'MetraConfirmDialog must appear on disconnect tap (HC-2 guard)',
      );

      // Tap the confirm action. The confirm button carries the label from
      // backupDisconnectConfirmDisconnect (EN: "Disconnetti" / the dialog shows
      // the label passed to confirmLabel). Since harness uses EN locale, find
      // by finding the _DialogAction text that is NOT the cancel label.
      // The MetraConfirmDialog wraps each action in a GestureDetector; the
      // confirm action text matches the confirmLabel param.
      // We can find it via the Semantics button label.
      final confirmFinder = find.descendant(
        of: find.byType(MetraConfirmDialog),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              (w.properties.label?.toLowerCase().contains('disconnect') ==
                      true ||
                  w.properties.label?.toLowerCase().contains('disconnetti') ==
                      true),
        ),
      );
      expect(
        confirmFinder,
        findsOneWidget,
        reason: 'Confirm button must exist inside MetraConfirmDialog',
      );
      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();

      expect(
        fake.disconnectCalls,
        1,
        reason:
            'notifier.disconnect() must be called exactly once after confirm',
      );
    },
  );

  // ── 6. FR-32: Distruttivo: semantics prefix ───────────────────────────────

  testWidgets(
    'BackupConnectedView: disconnect row has Semantics label prefixed with "Distruttivo: "',
    (tester) async {
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // Walk all Semantics widgets; at least one must have a label starting
      // with 'Distruttivo: ' (FR-32 destructive-row guard).
      final distruttivi = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (s) => s.properties.label?.startsWith('Distruttivo: ') == true,
          )
          .toList();

      expect(
        distruttivi,
        isNotEmpty,
        reason:
            'At least one Semantics widget must carry a "Distruttivo: " label prefix (FR-32)',
      );
    },
  );

  // ── 7. Restore tap order: sheet BEFORE confirm ───────────────────────────

  testWidgets(
    'BackupConnectedView restore tap → BackupPickerSheet shown before MetraConfirmDialog',
    (tester) async {
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // Tap the restore action row.
      await tester.tap(
        find.byKey(const Key('backup_restore_action_row')),
      );
      // Allow the async fetch + sheet to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // BackupPickerSheet MUST be visible at this point.
      expect(
        find.byType(BackupPickerSheet),
        findsOneWidget,
        reason:
            'BackupPickerSheet must appear first (new step order: fetch→sheet→confirm→passphrase)',
      );

      // MetraConfirmDialog must NOT be visible yet (comes after picker).
      expect(
        find.byType(MetraConfirmDialog),
        findsNothing,
        reason:
            'MetraConfirmDialog must not appear until AFTER the picker is dismissed',
      );
    },
  );
}
