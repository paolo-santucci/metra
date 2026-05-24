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
//
// Split per NFR-08 (≤ 150 LoC per file). Applied to _BackupConnectedViewState.
//
// Provides:
//   handleBackup()    — FR-25
//   handleRestore()   — FR-26 / FR-28 (new step order + four mounted guards)
//   handleDisconnect() — FR-27

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/backup/backup_file_entry.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/backup_providers.dart';
import '../../../providers/encryption_provider.dart';
import '../state/backup_notifier.dart';
import '../widgets/backup_picker_sheet.dart';
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
      if (!mounted) return; // guard 5 — C-05
      if (count != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.restoreSuccessToast(count))),
        );
      }
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
}
