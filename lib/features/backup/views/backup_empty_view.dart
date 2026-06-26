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

// TASK-17 — BackupEmptyView
//
// Shown when BackupState == BackupNotConnected. Provides:
//   • Inline AppBar (no separate widget — matches backup_screen.dart pattern).
//   • Centered empty-state column: 64×64 cloud icon, DM Serif 22 heading,
//     Inter 14 body capped at 240dp.
//   • Full-width terracotta CTA anchored 24dp from bottom safe-area.
//   • HC-2 gate (EC-10): CTA disabled during BackupRunning state.
//
// TASK-07 (M4) — handleConnectViaPicker
//
// Rewires the CTA to open BackupProviderPickerSheet (FR-07 / EC-01 / EC-02 / EC-10).
//   (1) Open BackupProviderPickerSheet → picker returns SyncProvider? or null.
//   (2) null → no-op (EC-01: user cancelled).
//   (3) Non-null → await notifier.switchProvider(picked). No MetraConfirmDialog
//       because this is a first connect — the forget step is an idempotent
//       no-op on a never-connected state (EC-02).
//
// Follows the handleRestore discipline from backup_connected_view_handlers.dart:
//   • notifier reference captured before first await.
//   • mounted-guard after each await boundary.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';
import '../../../core/widgets/button_primary.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/backup_providers.dart';
import '../state/backup_notifier.dart';
import '../state/backup_state.dart';
import '../widgets/backup_provider_picker_sheet.dart';

class BackupEmptyView extends ConsumerStatefulWidget {
  const BackupEmptyView({super.key});

  @override
  ConsumerState<BackupEmptyView> createState() => _BackupEmptyViewState();
}

class _BackupEmptyViewState extends ConsumerState<BackupEmptyView> {
  // ---------------------------------------------------------------------------
  // handleConnectViaPicker — FR-07 / EC-01 / EC-02 / EC-10
  // ---------------------------------------------------------------------------

  /// Opens the provider picker and, if the user confirms, calls
  /// [BackupNotifier.switchProvider] with the selected provider.
  ///
  /// No [MetraConfirmDialog] is shown: this is a first-connect flow where
  /// there is nothing to lose (EC-02). The forget step inside [switchProvider]
  /// is an idempotent no-op when no provider has ever been connected.
  ///
  /// Caller must ensure the CTA is not tapped while [isRunning] (EC-10);
  /// the [onPressed:null] gate in [build] enforces this.
  Future<void> handleConnectViaPicker() async {
    // Capture notifier before any await (avoid stale ref if widget disposes).
    final notifier = ref.read(backupNotifierProvider.notifier);

    // Step 1: present the provider picker (null → user cancelled, EC-01).
    final picked = await BackupProviderPickerSheet.show(
      context,
      providers: availableProviders(defaultTargetPlatform),
      initialIndex: 0,
    );
    if (picked == null) return; // user cancelled — EC-01
    if (!mounted) return; // mounted-guard after first await

    // Step 2: switch to the chosen provider — no confirm dialog (EC-02).
    await notifier.switchProvider(picked);
    if (!mounted) return; // mounted-guard after second await
  }

  // ---------------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);
    final bg = colors.bgPrimary;
    final textPrimary = colors.textPrimary;

    final asyncState = ref.watch(backupNotifierProvider);
    final backupState = asyncState.valueOrNull;
    final isRunning = backupState is BackupRunning;

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
        child: Column(
          children: [
            // ── Empty-state content (centered in remaining space) ──────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cloud icon 64×64 at textPrimary.withAlpha(0x0D) (ink-at-5%)
                    SizedBox(
                      key: const Key('backup_empty_cloud_icon'),
                      width: 64,
                      height: 64,
                      child: Icon(
                        Icons.cloud_outlined,
                        size: 64,
                        color: textPrimary.withAlpha(0x0D),
                      ),
                    ),
                    const SizedBox(height: MetraSpacing.s4),

                    // DM Serif 22 heading
                    Text(
                      key: const Key('backup_empty_heading'),
                      l10n.backupEmptyHeading,
                      style: MetraTypography.titleMd.copyWith(
                        color: textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: MetraSpacing.s2),

                    // Inter 14 body, max 240dp wide, ink-at-50%
                    ConstrainedBox(
                      key: const Key('backup_empty_body_constrained'),
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        l10n.backupEmptyBody,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          color: textPrimary.withAlpha(0x7F),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── CTA anchored 24dp from bottom ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s6,
                0,
                MetraSpacing.s6,
                MetraSpacing.s6,
              ),
              child: SizedBox(
                key: const Key('backup_empty_cta'),
                width: double.infinity,
                child: ButtonPrimary(
                  label: l10n.backupConnectAction,
                  semanticsLabel: l10n.backupConnectAction,
                  // EC-10: disabled while BackupRunning; otherwise opens picker.
                  onPressed: isRunning ? null : handleConnectViaPicker,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
