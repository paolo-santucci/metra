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

/// Text-only ghost button. No border, no fill.
///
/// Used for low-emphasis actions such as "Annulla".
class ButtonGhost extends StatelessWidget {
  const ButtonGhost({
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
    final fgColor =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
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
