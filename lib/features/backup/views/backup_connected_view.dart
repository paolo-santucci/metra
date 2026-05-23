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

// TASK-18 — BackupConnectedView
//
// Three-card layout shown when BackupState == BackupConnected.
//
// Sections:
//   1. "Account connesso" — email, last-backup date, disconnect row.
//   2. "Stato"            — StatusIndicator (auto-backup active/suspended).
//   3. "Azioni"           — backup-now row, restore row.
//
// Async handlers (_handleBackup, _handleRestore, _handleDisconnect) live in
// backup_connected_view_handlers.dart (mixin applied here) per NFR-08.
//
// HC-2 view-side gate (EC-05): each interactive row is wrapped in
// IgnorePointer(ignoring: isRunning) so it becomes inert during BackupRunning.
//
// FR-28 / FR-32: _handleRestore has exactly four if(!mounted) guards;
// every destructive row carries Semantics(label: 'Distruttivo: …').

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/widgets/settings/settings_card.dart';
import '../../../core/widgets/settings/settings_label.dart';
import '../../../core/widgets/settings/settings_row.dart';
import '../../../l10n/app_localizations.dart';
import '../state/backup_notifier.dart';
import '../state/backup_state.dart';
import '../../../core/widgets/settings/settings_divider.dart';
import '../widgets/status_indicator.dart';
import 'backup_connected_view_handlers.dart';

/// Connected-account backup view (FR-22..FR-27, FR-28, FR-32).
///
/// Receives [state] from the dispatcher (TASK-21). HC-2 guard reads the
/// _provider_ value (not [state]) to detect [BackupRunning] in real-time
/// (EC-05 — the constructor arg is always [BackupConnected] by invariant,
/// so `state is BackupRunning` would be dead code).
class BackupConnectedView extends ConsumerStatefulWidget {
  const BackupConnectedView({required this.state, super.key});

  final BackupConnected state;

  @override
  ConsumerState<BackupConnectedView> createState() =>
      _BackupConnectedViewState();
}

class _BackupConnectedViewState extends ConsumerState<BackupConnectedView>
    with BackupConnectedHandlers {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);
    final bg = colors.bgPrimary;
    final textPrimary = colors.textPrimary;

    // HC-2: read the live provider state (not widget.state which is always
    // BackupConnected).
    final isRunning =
        ref.watch(backupNotifierProvider).valueOrNull is BackupRunning;

    // FR-24: format lastBackupAt with locale; em-dash when null.
    final String lastBackupText;
    if (widget.state.lastBackupAt != null) {
      lastBackupText = DateFormat.yMMMd(l10n.localeName)
          .add_jm()
          .format(widget.state.lastBackupAt!.toLocal());
    } else {
      lastBackupText = '—';
    }

    // FR-23: StatusIndicator label switches per autoBackupActive.
    final statusLabel = widget.state.autoBackupActive
        ? l10n.backupAutoActiveLabel
        : l10n.backupAutoSuspendedLabel;

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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Section 1: Account connesso ─────────────────────────────
              SettingsLabel(l10n.backupAccountConnesso, first: true),
              SettingsCard(
                children: [
                  SettingsRow.staticInfo(
                    label: l10n.backupAccountLabel,
                    valueText: widget.state.email,
                  ),
                  const SettingsDivider(),
                  SettingsRow.staticInfo(
                    label: l10n.backupLastBackupLabel,
                    valueText: lastBackupText,
                  ),
                  const SettingsDivider(),
                  // FR-32: destructive row carries 'Distruttivo: …' semantics.
                  Semantics(
                    label: 'Distruttivo: ${l10n.backupDisconnectLabel}',
                    excludeSemantics: true,
                    child: IgnorePointer(
                      ignoring: isRunning,
                      child: SettingsRow.destructive(
                        key: const Key('backup_disconnect_row'),
                        label: l10n.backupDisconnectLabel,
                        onTap: handleDisconnect,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Section 2: Stato ─────────────────────────────────────────
              SettingsLabel(l10n.backupStato),
              SettingsCard(
                children: [
                  StatusIndicator(
                    label: statusLabel,
                    active: widget.state.autoBackupActive,
                  ),
                ],
              ),

              // ── Section 3: Azioni ────────────────────────────────────────
              SettingsLabel(l10n.backupAzioni),
              SettingsCard(
                children: [
                  IgnorePointer(
                    ignoring: isRunning,
                    child: SettingsRow.action(
                      label: l10n.backupNowAction,
                      onTap: handleBackup,
                    ),
                  ),
                  const SettingsDivider(),
                  IgnorePointer(
                    ignoring: isRunning,
                    child: SettingsRow.action(
                      key: const Key('backup_restore_action_row'),
                      label: l10n.backupRestoreAction,
                      onTap: handleRestore,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
