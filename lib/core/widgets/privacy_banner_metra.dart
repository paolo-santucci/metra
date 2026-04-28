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

import 'package:flutter/material.dart';
import '../theme/metra_colors.dart';
import '../theme/metra_typography.dart';
import '../theme/metra_spacing.dart';

/// Informational privacy banner (sand background, lavender border).
///
/// Non-interactive. Tone is reassuring, never alarmist per CLAUDE.md §9.
/// Uses a line-icon lock shape (no emoji, no filled icons) per §8.4.
/// Semantics wraps the full message as a combined label so screen readers
/// announce it as a single informational block.
class PrivacyBannerMetra extends StatelessWidget {
  const PrivacyBannerMetra({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? MetraColors.dark.bgSunken : MetraColors.light.bgSunken;
    final borderColor = isDark
        ? MetraColors.dark.accentPrediction
        : MetraColors.light.accentPrediction;
    final iconColor = isDark
        ? MetraColors.dark.accentPrediction
        : MetraColors.light.accentPrediction;
    final textColor =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;

    return Semantics(
      label: message,
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(MetraSpacing.s4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(MetraRadius.md),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line-icon: lock outline, 1.5–2pt stroke, rounded (Material outlined icon
            // is the closest available without a custom SVG at this stage).
            Icon(
              Icons.lock_outline,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: MetraSpacing.s3),
            Expanded(
              child: Text(
                message,
                style: MetraTypography.body.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
