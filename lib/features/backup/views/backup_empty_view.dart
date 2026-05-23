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

// TASK-17 — BackupEmptyView
//
// Shown when BackupState == BackupNotConnected. Provides:
//   • Inline AppBar (no separate widget — matches backup_screen.dart pattern).
//   • Centered empty-state column: 64×64 cloud icon, DM Serif 22 heading,
//     Inter 14 body capped at 240dp.
//   • Full-width terracotta CTA anchored 24dp from bottom safe-area.
//   • HC-2 gate (EC-05): CTA disabled during BackupRunning state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';
import '../../../core/widgets/button_primary.dart';
import '../../../l10n/app_localizations.dart';
import '../state/backup_notifier.dart';
import '../state/backup_state.dart';

class BackupEmptyView extends ConsumerWidget {
  const BackupEmptyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  label: l10n.backupConnectDropbox,
                  semanticsLabel: l10n.backupConnectDropbox,
                  onPressed: isRunning
                      ? null
                      : () =>
                          ref.read(backupNotifierProvider.notifier).connect(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
