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
import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_typography.dart';
import '../../../l10n/app_localizations.dart';

enum PainLevel { none, mild, moderate, intense }

/// Four equal lavender circles (56 dp each) for quick pain level selection.
/// none=white-outlined, mild/moderate/intense=increasing lavender fill.
class CirclePainPicker extends StatelessWidget {
  const CirclePainPicker({
    super.key,
    required this.level,
    required this.onChanged,
  });

  final PainLevel level;
  final ValueChanged<PainLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? MetraColors.dark.accentPrediction
        : MetraColors.light.accentPrediction;
    final bgPrimary =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PainCircle(
          label: l10n.today_pain_none,
          fillColor: bgPrimary,
          showBorder: true,
          borderColor: borderColor,
          selected: level == PainLevel.none,
          accent: accent,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () => onChanged(PainLevel.none),
        ),
        _PainCircle(
          label: l10n.daily_entry_pain_mild,
          fillColor: accent.withValues(alpha: 0.25),
          selected: level == PainLevel.mild,
          accent: accent,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () => onChanged(PainLevel.mild),
        ),
        _PainCircle(
          label: l10n.daily_entry_pain_moderate,
          fillColor: accent.withValues(alpha: 0.55),
          selected: level == PainLevel.moderate,
          accent: accent,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () => onChanged(PainLevel.moderate),
        ),
        _PainCircle(
          label: l10n.daily_entry_pain_severe,
          fillColor: accent.withValues(alpha: 0.90),
          selected: level == PainLevel.intense,
          accent: accent,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () => onChanged(PainLevel.intense),
        ),
      ],
    );
  }
}

class _PainCircle extends StatelessWidget {
  const _PainCircle({
    required this.label,
    required this.fillColor,
    required this.selected,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    this.showBorder = false,
    this.borderColor,
  });

  final String label;
  final Color fillColor;
  final bool selected;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final bool showBorder;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final BorderSide side = selected
        ? BorderSide(color: accent, width: 2.5)
        : (showBorder && borderColor != null
            ? BorderSide(color: borderColor!, width: 1.5)
            : BorderSide.none);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fillColor,
                    border: Border.fromBorderSide(side),
                  ),
                ),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: MetraTypography.tiny.copyWith(
                color: selected ? textPrimary : textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
