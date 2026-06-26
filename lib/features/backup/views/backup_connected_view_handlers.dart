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

// TASK-18 — BackupConnectedView: async handler mixin
// TASK-08 (M4) — handleSwitchProvider added
//
// Split per NFR-08 (≤ 150 LoC per file). Applied to _BackupConnectedViewState.
//
// Provides:
//   handleBackup()         — FR-25
//   handleRestore()        — FR-26 / FR-28 (new step order + four mounted guards)
//   handleDisconnect()     — FR-27
//   handleSwitchProvider() — FR-08 / FR-14 / EC-03 / EC-10 / EC-12 / OQ-QA-02

import 'package:flutter/foundation.dart'; // defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/backup/backup_file_entry.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/backup_providers.dart';
import '../../../providers/encryption_provider.dart';
import '../state/backup_notifier.dart';
import '../widgets/backup_picker_sheet.dart';
import '../widgets/backup_provider_labels.dart';
import '../widgets/backup_provider_picker_sheet.dart';
import '../widgets/metra_confirm_dialog.dart';
import '../widgets/passphrase_dialog.dart';
import 'backup_connected_view.dart';

/// Async handlers for [BackupConnectedView].
///
/// Applied as a mixin on [_BackupConnectedViewState]. The mixin accesses
/// [context], [mounted], [widget], and [ref] through the [ConsumerState] base.
mixin BackupConnectedHandlers on ConsumerState<BackupConnectedView> {
  // ---------------------------------------------------------------------------
  // handleBackup — FR-25
  // ---------------------------------------------------------------------------

  Future<void> handleBackup() async {
    final notifier = ref.read(backupNotifierProvider.notifier);

    final cached = await ref
        .read(secureStorageProvider)
        .read(key: BackupNotifier.kPassphraseKey);

    if (!mounted) return;

    if (cached != null && cached.isNotEmpty) {
      // Nth-time path: passphrase already cached — run silently.
      await notifier.backupNow();
    } else {
      // First-time path: prompt with setNew dialog.
      await PassphraseDialog.show(
        context,
        onConfirmed: (passphrase) async {
          await notifier.backupWithPassphrase(passphrase);
        },
      );
    }
  }

  // ---------------------------------------------------------------------------
  // handleRestore — FR-26 / FR-28
  //
  // New step order (inverted from old _ConnectedBody):
  //   (1) fetch file list       — SnackBar on error, return
  //   (2) BackupPickerSheet     — null → return
  //   (3) MetraConfirmDialog    — != true → return
  //   (4) PassphraseDialog      — null passphrase → return
  //   (5) restoreWithPassphrase
  //
  // Exactly four if (!mounted) return guards (one after each async boundary in
  // steps 1–4). The listenManual subscription is captured pre-step-1 and closed
  // in the finally block (EC-06).
  // ---------------------------------------------------------------------------

  Future<void> handleRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(backupNotifierProvider.notifier);
    // Capture messenger before any await (avoids stale BuildContext).
    final messenger = ScaffoldMessenger.of(context);

    // Pin the autoDispose backupFileListProvider for the duration of the flow.
    // WidgetRef has no keepAlive(); listenManual serves as the pinning seam
    // (validated pattern from today_screen.dart / historical_entry_screen.dart).
    final sub = ref.listenManual<AsyncValue<List<BackupFileEntry>>>(
      backupFileListProvider,
      (_, __) {},
    );

    try {
      // ── Step 1: fetch backup list ──────────────────────────────────────────
      List<BackupFileEntry> entries;
      try {
        entries = await ref.read(backupFileListProvider.future);
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.restorePickerError)),
        );
        return;
      }
      if (!mounted) return; // guard 1

      // ── Step 2: file picker ───────────────────────────────────────────────
      final pickedIndex = await BackupPickerSheet.show(
        context,
        entries: entries,
      );
      if (pickedIndex == null) return;
      if (!mounted) return; // guard 2

      // ── Step 3: confirmation dialog ────────────────────────────────────────
      final confirmed = await MetraConfirmDialog.show(
        context,
        title: l10n.backupRestoreConfirmTitle,
        body: l10n.backupRestoreConfirmBody,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.backupRestoreConfirmRestore,
      );
      if (confirmed != true) return;
      if (!mounted) return; // guard 3

      // ── Step 4: passphrase unlock ─────────────────────────────────────────
      String? enteredPassphrase;
      await PassphraseDialog.show(
        context,
        mode: PassphraseDialogMode.unlock,
        onConfirmed: (p) => enteredPassphrase = p,
      );
      if (enteredPassphrase == null) return;
      if (!mounted) return; // guard 4

      // ── Step 5: execute restore ───────────────────────────────────────────
      final count = await notifier.restoreWithPassphrase(
        enteredPassphrase!, // safe: null-checked on line above
        filename: entries[pickedIndex].name,
      );
      if (count != null && messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.restoreSuccessToast(count))),
        );
      }
      if (!mounted) return; // guard 5 — C-05
    } finally {
      sub.close();
    }
  }

  // ---------------------------------------------------------------------------
  // handleDisconnect — FR-27
  // ---------------------------------------------------------------------------

  Future<void> handleDisconnect() async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(backupNotifierProvider.notifier);

    final confirmed = await MetraConfirmDialog.show(
      context,
      title: l10n.backupDisconnectConfirmTitle,
      body: l10n.backupDisconnectConfirmBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.backupDisconnectConfirmDisconnect,
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await notifier.disconnect();
  }

  // ---------------------------------------------------------------------------
  // handleSwitchProvider — FR-08 / FR-14 / EC-03 / EC-10 / EC-12 / OQ-QA-02
  //
  // Flow (spec §5.1 view-handler contract):
  //   1. Open BackupProviderPickerSheet, pre-selected at the active provider's
  //      index in availableProviders(defaultTargetPlatform).
  //   2. picker == null → return (EC-01 cancel).
  //   3. picker == connected.provider → return (EC-03 same-provider no-op,
  //      NO confirm dialog).
  //   4. MetraConfirmDialog (switch-confirm): cancelled → return (EC-12).
  //   5. await notifier.switchProvider(picked) (FR-14).
  //
  // mounted-guard after each await (OQ-QA-02).
  // messenger captured pre-await (handleRestore discipline).
  // EC-10 gate (IgnorePointer) is applied in the view, not here.
  // ---------------------------------------------------------------------------

  Future<void> handleSwitchProvider() async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(backupNotifierProvider.notifier);
    // Capture messenger before first await (avoids stale BuildContext).
    // Unused in the current happy-path but kept per handleRestore discipline so
    // future snack-bar additions don't miss the capture.
    // ignore: unused_local_variable
    final messenger = ScaffoldMessenger.of(context);

    final connected = widget.state; // BackupConnected, always valid here

    // Resolve the platform-filtered provider list (single source — FR-02).
    final providers = availableProviders(defaultTargetPlatform);
    // Clamp to 0 defensively: if state.provider is iCloud and we're on
    // non-iOS (e.g. tests on Linux), indexOf returns -1.
    final rawIndex = providers.indexOf(connected.provider);
    final initialIndex = rawIndex < 0 ? 0 : rawIndex;

    // ── Step 1: open provider picker ─────────────────────────────────────────
    final picked = await BackupProviderPickerSheet.show(
      context,
      providers: providers,
      initialIndex: initialIndex,
    );
    if (!mounted) return; // guard 1

    // ── Step 2: cancel (picker dismissed) ────────────────────────────────────
    if (picked == null) return;

    // ── Step 3: same-provider short-circuit (EC-03) ───────────────────────────
    // No dialog, no switchProvider call — selecting the already-active provider
    // is a no-op per spec §6.1 EC-03 and bible §18.6.2.
    if (picked == connected.provider) return;

    // ── Step 4: switch-confirm dialog (FR-14 / EC-12) ─────────────────────────
    final displayName = backupProviderDisplayName(l10n, picked);
    final confirmed = await MetraConfirmDialog.show(
      context,
      title: l10n.backupSwitchConfirmTitle,
      body: l10n.backupSwitchConfirmBody(displayName),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.backupSwitchConfirmSwitch,
    );
    if (!mounted) return; // guard 2
    if (confirmed != true) return; // EC-12 cancel

    // ── Step 5: execute switch ────────────────────────────────────────────────
    await notifier.switchProvider(picked); // FR-14 / FR-08
  }
}
