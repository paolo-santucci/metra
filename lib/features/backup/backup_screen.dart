// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/metra_colors.dart';
import '../../l10n/app_localizations.dart';
import 'state/backup_notifier.dart';
import 'state/backup_state.dart';
import 'widgets/passphrase_dialog.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;

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
        BackupNotConnected() => _NotConnectedBody(l10n: l10n, isDark: isDark),
        BackupRunning(:final operation) =>
          _RunningBody(l10n: l10n, operation: operation),
        BackupConnected(:final email, :final lastBackupAt) => _ConnectedBody(
            l10n: l10n,
            email: email,
            lastBackupAt: lastBackupAt,
            isDark: isDark,
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
  const _NotConnectedBody({required this.l10n, required this.isDark});

  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
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
    required this.isDark,
  });

  final AppLocalizations l10n;
  final String email;
  final DateTime? lastBackupAt;
  final bool isDark;

  @override
  ConsumerState<_ConnectedBody> createState() => _ConnectedBodyState();
}

class _ConnectedBodyState extends ConsumerState<_ConnectedBody> {
  Future<void> _handleBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    await PassphraseDialog.show(
      context,
      onConfirmed: (passphrase) {
        unawaited(
          ref
              .read(backupNotifierProvider.notifier)
              .backupWithPassphrase(passphrase),
        );
        messenger.showSnackBar(
          SnackBar(content: Text(widget.l10n.backup_in_progress)),
        );
      },
    );
  }

  Future<void> _handleRestore() async {
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
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(widget.l10n.backup_restore_confirm_button),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await PassphraseDialog.show(
      context,
      mode: PassphraseDialogMode.unlock,
      onConfirmed: (passphrase) {
        unawaited(
          ref
              .read(backupNotifierProvider.notifier)
              .restoreWithPassphrase(passphrase),
        );
        messenger.showSnackBar(
          SnackBar(content: Text(widget.l10n.backup_restore_in_progress)),
        );
      },
    );
  }

  Future<void> _handleDisconnect() async {
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
    final textPrimary = widget.isDark
        ? MetraColors.dark.textPrimary
        : MetraColors.light.textPrimary;

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
          const SizedBox(height: 24),
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
