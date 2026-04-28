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

/// Filled terracotta primary action button.
///
/// Uses [accentFlowStrong] (#9B4E32) as background — AA-compliant (5.6:1)
/// on sand background, per tokens.json contrastChecks.
/// Caller must supply [semanticsLabel] with verb+object form,
/// e.g. "Salva la giornata".
class ButtonPrimary extends StatelessWidget {
  const ButtonPrimary({
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
    final bgColor = isDark
        ? MetraColors.dark.accentFlowStrong
        : MetraColors.light.accentFlowStrong;
    final fgColor =
        isDark ? MetraColors.dark.textOnAccent : MetraColors.light.textOnAccent;
    final disabledBg = bgColor.withValues(alpha: 0.5);

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            disabledBackgroundColor: disabledBg,
            disabledForegroundColor: fgColor.withValues(alpha: 0.5),
            minimumSize: const Size(120, 48),
            padding: const EdgeInsets.symmetric(
              horizontal: MetraSpacing.s6,
              vertical: MetraSpacing.s3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetraRadius.md),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: Text(
            label,
            style: MetraTypography.body.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
