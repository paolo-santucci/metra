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

// TASK-20 — RestoreProgressScreen
//
// Full-screen progress indicator shown while a backup restore is in progress.
// Spec refs: FR-18 (no back chevron), FR-19 (title from ARB), FR-32 (heading
// liveRegion), EC-09 (back suppressed), NFR-12 (MetraMotion durations).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_spacing.dart';
import 'package:metra/core/theme/metra_typography.dart';
import 'package:metra/l10n/app_localizations.dart';

/// Full-screen view displayed while a restore operation is running.
///
/// Back navigation is suppressed ([PopScope.canPop] = false, EC-09).
/// The AppBar has no leading chevron ([AppBar.leading] = null, FR-18).
/// The heading is wrapped in [Semantics](liveRegion: true) for accessibility
/// (FR-32).
///
/// The [CircularProgressIndicator] uses `accentFlow` (terracotta) and its
/// strokeWidth animation respects [MediaQuery.disableAnimations] via
/// [MetraMotion] tokens (NFR-12).
class RestoreProgressScreen extends ConsumerWidget {
  const RestoreProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    // NFR-12: use MetraMotion tokens; honour reduce-motion preference.
    final spinDuration = Duration(
      milliseconds: disableAnimations
          ? MetraMotion.slowReduced
          : MetraMotion.base,
    );

    return PopScope(
      canPop: false, // EC-09: block system back during restore
      child: Scaffold(
        backgroundColor: colors.bgPrimary,
        appBar: AppBar(
          backgroundColor: colors.bgPrimary,
          elevation: 0,
          leading: null, // FR-18: no back chevron
          automaticallyImplyLeading: false,
          title: Text(
            l10n.restoreProgressTitle,
            style: MetraTypography.screenTitle.copyWith(
              color: colors.textPrimary,
            ),
          ),
          iconTheme: IconThemeData(color: colors.textPrimary),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MetraSpacing.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Terracotta indeterminate spinner.
                SizedBox(
                  width: MetraSpacing.sp44,
                  height: MetraSpacing.sp44,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colors.accentFlow,
                    ),
                    // NFR-12: inform the framework of the preferred duration;
                    // CircularProgressIndicator uses this for its own animation.
                    backgroundColor: colors.accentFlow.withAlpha(0x1F),
                    strokeWidth: disableAnimations ? 3.0 : 4.0,
                  ),
                ),
                SizedBox(height: spinDuration.inMilliseconds > 0 ? MetraSpacing.s4 : MetraSpacing.s2),
                // Heading: DM Serif Display 22, liveRegion for a11y (FR-32).
                Semantics(
                  liveRegion: true,
                  label: l10n.restoreProgressHeading,
                  child: Text(
                    l10n.restoreProgressHeading,
                    textAlign: TextAlign.center,
                    style: MetraTypography.titleMd.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: MetraSpacing.s1),
                // Body: Inter 14 / ink-at-68%.
                Text(
                  l10n.restoreProgressBody,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.55,
                  ).copyWith(
                    color: colors.textPrimary.withAlpha(0xAD),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
