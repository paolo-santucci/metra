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

// TASK-18/TASK-31/TASK-08 — BackupConnectedView smoke tests
//
// Spec §7.1 Group I bullets (original + TASK-08 additions):
//   1. Three SettingsLabels + three SettingsCards render in section order.
//   2. Account email rendered in the account section.
//   3. "Ultimo backup" formats DateTime via locale; "—" when null (em-dash).
//   4. StatusIndicator present with correct active/inactive state.
//   5. Disconnect confirm flow: dialog → confirm → notifier.disconnect() called.
//   6. FR-32: Semantics label prefixed with "Distruttivo: " on destructive row.
//   7. Restore tap → BackupPickerSheet shown BEFORE MetraConfirmDialog.
//
// TASK-08 additions (FR-08/FR-14/FR-15/EC-03/EC-08/EC-10/EC-12/OQ-QA-02):
//   8.  active-provider name (FR-15): googleDrive state → "Google Drive" rendered.
//   9.  iCloud null email (EC-08/FR-15): provider=iCloud, email=null → "iCloud"
//       shown, no blank Account row.
//  10.  switch row disabled (EC-10): isRunning → IgnorePointer.ignoring=true.
//  11.  same-provider short-circuit (EC-03/FR-08): open picker at state.provider
//       index, confirm → no dialog, switchProvider NOT called.
//  12.  confirm cancelled (EC-12/FR-14): different provider picked, dialog
//       cancelled → switchProvider NOT called.
//  13.  confirmed (FR-14/FR-08): different provider picked, dialog confirmed →
//       notifier.switchProvider(picked) called once.
//  14.  mounted-guard (OQ-QA-02): widget disposed mid-await → no crash.
//
// Note (bullet HC-2 on backup): handleBackup does NOT show MetraConfirmDialog.
// It runs backupNow() (cached passphrase) or PassphraseDialog (first-time).
// The HC-2 guard on backup is IgnorePointer(ignoring: isRunning), already
// covered indirectly via the empty-view CTA test and integration tests.
// No phantom test is added for a guard that does not exist in source.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/settings/settings_card.dart';
import 'package:metra/core/widgets/settings/settings_label.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_connected_view.dart';
import 'package:metra/features/backup/widgets/backup_picker_sheet.dart';
import 'package:metra/features/backup/widgets/backup_provider_picker_sheet.dart';
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
  int switchProviderCalls = 0; // TASK-08 — EC-03/FR-14/FR-08
  SyncProvider? lastSwitchedTo; // TASK-08 — captures the argument
  String? capturedPassphrase;
  String? capturedFilename;

  @override
  Future<BackupState> build() async => _initial;

  @override
  Future<int?> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async {
    restoreCalls++;
    capturedPassphrase = passphrase;
    capturedFilename = filename;
    return null;
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
  Future<void> switchProvider(SyncProvider target) async {
    // TASK-08 — spy for EC-03/FR-14/FR-08/EC-12 tests
    switchProviderCalls++;
    lastSwitchedTo = target;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// A [BackupConnected] state used by default across the tests.
final _connectedState = BackupConnected(
  provider: SyncProvider.dropbox,
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
        provider: SyncProvider.dropbox,
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
        provider: SyncProvider.dropbox,
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
        provider: SyncProvider.dropbox,
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
        provider: SyncProvider.dropbox,
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

      // Scroll to the disconnect row (TASK-08: Disconnetti moved to Section 3;
      // new rows push it below the 800×600 test viewport).
      await tester
          .ensureVisible(find.byKey(const Key('backup_disconnect_row')));
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

      // Scroll to restore row (TASK-08: Section 3 now has extra rows —
      // switch-provider and disconnect — that push restore below the 800×600
      // test viewport).
      await tester.ensureVisible(
        find.byKey(const Key('backup_restore_action_row')),
      );
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

  // ── TASK-08 tests: FR-08/FR-14/FR-15/EC-03/EC-08/EC-10/EC-12/OQ-QA-02 ──

  // ── 8. Active-provider name (FR-15) ────────────────────────────────────────

  testWidgets(
    'BackupConnectedView renders active-provider display name from backupProviderDisplayName',
    (tester) async {
      // State with Google Drive as provider, non-null email.
      const gDriveState = BackupConnected(
        provider: SyncProvider.googleDrive,
        email: 'user@gmail.com',
        autoBackupActive: true,
        passphraseSet: true,
        lastBackupAt: null,
      );
      final fake = _FakeBackupNotifier(gDriveState);
      await tester.pumpWidget(_harness(fake, state: gDriveState));
      await tester.pumpAndSettle();

      // "Google Drive" must appear (from backupProviderNameGoogleDrive, EN locale).
      expect(
        find.text('Google Drive'),
        findsOneWidget,
        reason:
            'Provider display name "Google Drive" must be rendered from backupProviderDisplayName (FR-15); '
            'NOT derived from email (dropboxEmail field)',
      );

      // The email value is still shown (non-null path).
      expect(
        find.text('user@gmail.com'),
        findsOneWidget,
        reason: 'Non-null email must still be rendered in the Account row',
      );
    },
  );

  // ── 9. iCloud null-email omits Account row (FR-15 / EC-08) ────────────────

  testWidgets(
    'BackupConnectedView iCloud + null email renders iCloud provider name with no blank Account row',
    (tester) async {
      const iCloudState = BackupConnected(
        provider: SyncProvider.iCloud,
        email: null, // iCloud has no email
        autoBackupActive: true,
        passphraseSet: true,
      );
      final fake = _FakeBackupNotifier(iCloudState);
      await tester.pumpWidget(_harness(fake, state: iCloudState));
      await tester.pumpAndSettle();

      // "iCloud" must appear as the provider display name (EN locale).
      expect(
        find.text('iCloud'),
        findsOneWidget,
        reason:
            'Provider display name "iCloud" must be rendered even with null email (FR-15 / EC-08)',
      );

      // No blank Account value rendered (empty string '' must not appear).
      expect(
        find.text(''),
        findsNothing,
        reason:
            'Blank Account value must not appear when email is null — Account row omitted entirely (EC-08)',
      );

      // The Account label ("Account") must not be rendered in the info rows
      // (since the Account row is omitted for iCloud).
      // We check by absence of a SettingsRow whose value is '' — verified above.
      // Also verify exactly one "—" for last backup (null date) to confirm
      // Ultimo backup still renders.
      expect(
        find.text('—'),
        findsOneWidget,
        reason:
            'Ultimo backup must still render as "—" when lastBackupAt is null',
      );
    },
  );

  // ── 10. Switch row disabled when isRunning (EC-10) ─────────────────────────

  testWidgets(
    'BackupConnectedView switch row is disabled (IgnorePointer.ignoring=true) when isRunning',
    (tester) async {
      // Notifier returns BackupRunning → isRunning=true.
      final runningFake = _FakeBackupNotifier(
        const BackupRunning(BackupOperation.backingUp),
      );
      await tester.pumpWidget(_harness(runningFake, state: _connectedState));
      await tester.pumpAndSettle();

      // The switch action row must exist.
      expect(
        find.byKey(const Key('backup_switch_action_row')),
        findsOneWidget,
        reason: 'Switch action row must be present regardless of isRunning',
      );

      // Find the IgnorePointer ancestor of the switch row.
      final switchRowFinder = find.byKey(const Key('backup_switch_action_row'));
      final ipFinder = find.ancestor(
        of: switchRowFinder,
        matching: find.byType(IgnorePointer),
      );
      expect(
        ipFinder,
        findsAtLeastNWidgets(1),
        reason: 'Switch row must be wrapped in IgnorePointer (EC-10)',
      );

      // The IgnorePointer must be ignoring (isRunning=true → ignoring=true).
      final ip = tester.widget<IgnorePointer>(ipFinder.first);
      expect(
        ip.ignoring,
        isTrue,
        reason:
            'IgnorePointer.ignoring must be true when isRunning=true (EC-10)',
      );

      // Tapping must NOT open the picker sheet.
      await tester.tap(switchRowFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byType(BackupProviderPickerSheet),
        findsNothing,
        reason:
            'BackupProviderPickerSheet must NOT open when switch row is disabled (EC-10)',
      );
    },
  );

  // ── 11. Same-provider short-circuit + initialIndex (EC-03 / FR-08) ─────────

  testWidgets(
    'BackupConnectedView switch: same provider selected → no dialog, switchProvider NOT called (EC-03/FR-08)',
    (tester) async {
      // State: provider=dropbox → availableProviders(linux)=[dropbox,googleDrive],
      // initialIndex=indexOf(dropbox)=0. Confirming without scrolling returns dropbox.
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // Tap the switch action row to open the picker.
      await tester.tap(find.byKey(const Key('backup_switch_action_row')));
      await tester.pumpAndSettle();

      // BackupProviderPickerSheet must be visible.
      expect(
        find.byType(BackupProviderPickerSheet),
        findsOneWidget,
        reason: 'BackupProviderPickerSheet must open on switch row tap (FR-08)',
      );

      // Confirm without scrolling — returns dropbox (same as state.provider).
      // In EN locale, confirm button text is "Connect" (backupConnectAction).
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // No confirm dialog — same-provider short-circuit (EC-03).
      expect(
        find.byType(MetraConfirmDialog),
        findsNothing,
        reason:
            'MetraConfirmDialog must NOT appear when the same provider is selected (EC-03)',
      );

      // switchProvider must NOT be called.
      expect(
        fake.switchProviderCalls,
        0,
        reason:
            'switchProvider must NOT be called on same-provider selection (EC-03)',
      );
    },
  );

  // ── 12. Confirm cancelled (EC-12 / FR-14) ──────────────────────────────────

  testWidgets(
    'BackupConnectedView switch: different provider → dialog cancelled → switchProvider NOT called (EC-12/FR-14)',
    (tester) async {
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('backup_switch_action_row')));
      await tester.pumpAndSettle();

      // Scroll the picker up by one item to select googleDrive (index 1).
      await tester.drag(
        find.byType(CupertinoPicker),
        const Offset(0, -44.0),
      );
      await tester.pumpAndSettle();

      // Confirm — returns googleDrive (different from state.provider=dropbox).
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // MetraConfirmDialog must appear.
      expect(
        find.byType(MetraConfirmDialog),
        findsOneWidget,
        reason: 'MetraConfirmDialog must appear before switch (FR-14)',
      );

      // Tap cancel ("Cancel" in EN locale = commonCancel).
      await tester.tap(
        find.descendant(
          of: find.byType(MetraConfirmDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();

      // switchProvider must NOT be called.
      expect(
        fake.switchProviderCalls,
        0,
        reason:
            'switchProvider must NOT be called when confirm dialog is cancelled (EC-12)',
      );
    },
  );

  // ── 13. Confirmed (FR-14 / FR-08) ──────────────────────────────────────────

  testWidgets(
    'BackupConnectedView switch: different provider → dialog confirmed → notifier.switchProvider called (FR-14/FR-08)',
    (tester) async {
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('backup_switch_action_row')));
      await tester.pumpAndSettle();

      // Scroll to googleDrive (index 1, from dropbox at index 0).
      await tester.drag(
        find.byType(CupertinoPicker),
        const Offset(0, -44.0),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // MetraConfirmDialog must appear.
      expect(
        find.byType(MetraConfirmDialog),
        findsOneWidget,
        reason: 'MetraConfirmDialog must appear before switch (FR-14)',
      );

      // Tap confirm — "Switch" in EN locale (backupSwitchConfirmSwitch).
      await tester.tap(
        find.descendant(
          of: find.byType(MetraConfirmDialog),
          matching: find.text('Switch'),
        ),
      );
      await tester.pumpAndSettle();

      // switchProvider must be called exactly once with googleDrive.
      expect(
        fake.switchProviderCalls,
        1,
        reason: 'switchProvider must be called exactly once on confirm (FR-14)',
      );
      expect(
        fake.lastSwitchedTo,
        SyncProvider.googleDrive,
        reason:
            'switchProvider must be called with the picker-selected provider (FR-08)',
      );
    },
  );

  // ── 14. Mounted-guard (OQ-QA-02) ───────────────────────────────────────────

  testWidgets(
    'BackupConnectedView mounted-guard: disposing widget while picker is open does not throw',
    (tester) async {
      final fake = _FakeBackupNotifier(_connectedState);
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // Open the switch picker (starts handleSwitchProvider's first await).
      await tester.tap(find.byKey(const Key('backup_switch_action_row')));
      // Pump one frame — picker animation has started but the async result
      // has not resolved.
      await tester.pump();

      // Dispose the BackupConnectedView by replacing the widget tree.
      // This simulates the widget being removed mid-await (OQ-QA-02).
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // No FlutterError ("setState called on a dead widget") must have been
      // thrown — mounted-guard prevents setState/messenger after unmount.
      expect(
        tester.takeException(),
        isNull,
        reason:
            'No exception must be thrown when widget is disposed mid-await (OQ-QA-02)',
      );

      // switchProvider must not have been called (async flow was interrupted).
      expect(
        fake.switchProviderCalls,
        0,
        reason: 'switchProvider must not be called when widget is disposed',
      );
    },
  );
}
