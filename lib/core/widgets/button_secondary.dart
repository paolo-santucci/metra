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

/// Outlined secondary button with a terracotta border.
///
/// Distinguishable from [ButtonPrimary] by shape (outline vs fill),
/// not just color — satisfies color-blind safety requirement.
class ButtonSecondary extends StatelessWidget {
  const ButtonSecondary({
    super.key,
    required this.label,
    required this.onPressed,
    required this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MetraColors.dark.accentFlowStrong
        : MetraColors.light.accentFlowStrong;
    final fgColor = isDark
        ? MetraColors.dark.accentFlowStrong
        : MetraColors.light.accentFlowStrong;

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fgColor,
            disabledForegroundColor: fgColor.withValues(alpha: 0.5),
            minimumSize: const Size(120, 48),
            padding: const EdgeInsets.symmetric(
              horizontal: MetraSpacing.s6,
              vertical: MetraSpacing.s3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetraRadius.md),
            ),
            side: BorderSide(
              color: onPressed != null
                  ? borderColor
                  : borderColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: MetraTypography.body.copyWith(
              color:
                  onPressed != null ? fgColor : fgColor.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
