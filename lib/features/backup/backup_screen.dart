// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/metra_colors.dart';
import '../../data/services/backup/backup_file_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/backup_providers.dart';
import '../../providers/encryption_provider.dart';
import 'state/backup_notifier.dart';
import 'state/backup_state.dart';
import 'widgets/passphrase_dialog.dart';
import 'widgets/restore_picker_dialog.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);
    final bg = colors.bgPrimary;
    final textPrimary = colors.textPrimary;

    final asyncState = ref.watch(backupNotifierProvider);
    final backupState = asyncState.valueOrNull;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          l10n.backup_screen_title,
          style: TextStyle(color: textPrimary),
        ),
        iconTheme: IconThemeData(color: textPrimary),
        elevation: 0,
      ),
      body: switch (backupState) {
        null => const Center(child: CircularProgressIndicator()),
        BackupNotConnected() => _NotConnectedBody(l10n: l10n),
        BackupRunning(:final operation) =>
          _RunningBody(l10n: l10n, operation: operation),
        BackupConnected(
          :final email,
          :final lastBackupAt,
          :final autoBackupActive,
        ) =>
          _ConnectedBody(
            l10n: l10n,
            email: email,
            lastBackupAt: lastBackupAt,
            autoBackupActive: autoBackupActive,
          ),
        BackupErrorState(:final message) =>
          _ErrorBody(l10n: l10n, message: message),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _NotConnectedBody
// ---------------------------------------------------------------------------

class _NotConnectedBody extends ConsumerWidget {
  const _NotConnectedBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = MetraColors.of(context).textPrimary;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.backup_not_connected_body,
            style: TextStyle(color: textPrimary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                ref.read(backupNotifierProvider.notifier).connect(),
            child: Text(l10n.backup_connect_dropbox),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RunningBody
// ---------------------------------------------------------------------------

class _RunningBody extends StatelessWidget {
  const _RunningBody({required this.l10n, required this.operation});

  final AppLocalizations l10n;
  final BackupOperation operation;

  @override
  Widget build(BuildContext context) {
    final label = switch (operation) {
      BackupOperation.restoring => l10n.backup_restore_in_progress,
      _ => l10n.backup_in_progress,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ConnectedBody
// ---------------------------------------------------------------------------

class _ConnectedBody extends ConsumerStatefulWidget {
  const _ConnectedBody({
    required this.l10n,
    required this.email,
    required this.lastBackupAt,
    required this.autoBackupActive,
  });

  final AppLocalizations l10n;
  final String email;
  final DateTime? lastBackupAt;
  final bool autoBackupActive;

  @override
  ConsumerState<_ConnectedBody> createState() => _ConnectedBodyState();
}

class _ConnectedBodyState extends ConsumerState<_ConnectedBody> {
  Future<void> _handleBackup() async {
    // FR-12 / FR-13: read the cached passphrase BEFORE showing any dialog.
    final cached = await ref
        .read(secureStorageProvider)
        .read(key: BackupNotifier.kPassphraseKey);

    if (!mounted) return;

    if (cached != null && cached.isNotEmpty) {
      // FR-12 Nth-time path: passphrase is cached — run silently, no dialog.
      unawaited(ref.read(backupNotifierProvider.notifier).backupNow());
    } else {
      // FR-13 first-time path: no cached passphrase — prompt with setNew dialog.
      await PassphraseDialog.show(
        context,
        onConfirmed: (passphrase) {
          unawaited(
            ref
                .read(backupNotifierProvider.notifier)
                .backupWithPassphrase(passphrase),
          );
        },
      );
    }
  }

  Future<void> _handleRestore() async {
    // Step 1: destructive confirmation — CTA uses error colour (FR-14d).
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(widget.l10n.backup_restore_confirm_title),
        content: Text(widget.l10n.backup_restore_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(widget.l10n.common_cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(widget.l10n.backup_restore_confirm_button),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // Capture messenger before any async gap (recommended pattern).
    final messenger = ScaffoldMessenger.of(context);

    // Step 2: fetch backup listing; abort + snackbar on error.
    List<BackupFileEntry> entries;
    try {
      entries = await ref.read(backupFileListProvider.future);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(widget.l10n.restorePickerError)),
      );
      return;
    }
    if (!mounted) return;

    // Step 3: version picker.
    final outcome = await RestorePickerDialog.show(context, entries: entries);
    if (outcome == null) return;
    if (!mounted) return;

    // Step 4: resolve filename from outcome.
    final String? filename = switch (outcome) {
      RestorePickNewest() => null,
      RestorePickFilename(:final filename) => filename,
    };

    // Step 5: passphrase unlock dialog — capture value via callback.
    String? enteredPassphrase;
    await PassphraseDialog.show(
      context,
      mode: PassphraseDialogMode.unlock,
      onConfirmed: (passphrase) => enteredPassphrase = passphrase,
    );
    if (enteredPassphrase == null) return;
    if (!mounted) return;

    // Step 6: execute restore and bind snackbar to the actual outcome (FR-14e).
    await ref
        .read(backupNotifierProvider.notifier)
        .restoreWithPassphrase(enteredPassphrase!, filename: filename);
    if (!mounted) return;
    // State was set inside restoreWithPassphrase before the future resolved.
    // Rebuild fires on the next frame; mounted is still true here.
    final currentState = ref.read(backupNotifierProvider).valueOrNull;
    if (currentState is BackupErrorState) {
      messenger.showSnackBar(
        SnackBar(content: Text(currentState.message)),
      );
    }
  }

  Future<void> _handleDisconnect() async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(widget.l10n.backup_disconnect_confirm_title),
        content: Text(widget.l10n.backup_disconnect_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(widget.l10n.common_cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(widget.l10n.backup_disconnect_confirm_button),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    unawaited(ref.read(backupNotifierProvider.notifier).disconnect());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final textPrimary = MetraColors.of(context).textPrimary;

    final lastBackupText = widget.lastBackupAt != null
        ? l10n.backup_last_backup_at(
            DateFormat.yMMMd().add_jm().format(
                  widget.lastBackupAt!.toLocal(),
                ),
          )
        : l10n.backup_last_backup_never;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.backup_connected_as(widget.email),
            style: TextStyle(color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            lastBackupText,
            style: TextStyle(color: textPrimary),
          ),
          // CANON GAP: §18.11.6 places this row inside a SettingsCard between
          // SettingsDividers; _ConnectedBody is not yet refactored to the
          // SettingsCard/SettingsRow pattern — indicator sits directly in the
          // existing Column. The §18.11.2 20 px left-inset is also omitted here
          // because the outer Padding(24) already provides horizontal inset that
          // is flush with the sibling Text/Button widgets.
          const SizedBox(height: 8),
          _AutoBackupIndicatorRow(
            autoBackupActive: widget.autoBackupActive,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleBackup,
            child: Text(l10n.backup_now),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _handleRestore,
            child: Text(l10n.backup_restore),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _handleDisconnect,
            child: Text(l10n.backup_disconnect),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AutoBackupIndicatorRow — §18.11
// ---------------------------------------------------------------------------

/// Read-only status row indicating whether automatic backup is active or
/// suspended.  Anatomy per bible §18.11.2: 8 px filled dot + label text,
/// 8 px gap, 40 px row height.  Non-interactive (no tap handler).
///
/// Tokens per §18.11.3:
///   Active:    dot = colorScheme.primary, label = colorScheme.onSurface
///   Suspended: dot = colorScheme.onSurface × 0.38, label = same
class _AutoBackupIndicatorRow extends StatelessWidget {
  const _AutoBackupIndicatorRow({required this.autoBackupActive});

  final bool autoBackupActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final String label = autoBackupActive
        ? l10n.backupAutoActiveLabel
        : l10n.backupAutoSuspendedLabel;

    // §18.11.3 token map
    final Color dotColor = autoBackupActive
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.38);
    final Color labelColor = autoBackupActive
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      label: label,
      // State communicated to screen readers via value ('active' / 'suspended').
      value: autoBackupActive ? 'active' : 'suspended',
      readOnly: true,
      liveRegion: true,
      child: SizedBox(
        key: const Key('auto-backup-indicator-row'),
        height: 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 8 px filled circle dot — no icon glyph (§18.11.7 forbidden: icon glyphs)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: labelColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorBody
// ---------------------------------------------------------------------------

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({required this.l10n, required this.message});

  final AppLocalizations l10n;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(message),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.invalidate(backupNotifierProvider),
            child: Text(l10n.common_error_generic),
          ),
        ],
      ),
    );
  }
}
