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

/// Four malva circles (36 dp) for quick pain level selection.
/// null = not logged (no ring); 0=Nessuno (outlined); 1–3 = increasing fill.
/// Tapping the already-selected circle calls onChanged(null) to deselect.
class CirclePainPicker extends StatelessWidget {
  const CirclePainPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? MetraColors.dark.accentPain : MetraColors.light.accentPain;
    final bgPrimary =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
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
          value: 0,
          selected: selected,
          accent: accent,
          textPrimary: textPrimary,
          onTap: () => onChanged(selected == 0 ? null : 0),
        ),
        _PainCircle(
          label: l10n.daily_entry_pain_mild,
          fillColor: accent.withValues(alpha: 0.25),
          value: 1,
          selected: selected,
          accent: accent,
          textPrimary: textPrimary,
          onTap: () => onChanged(selected == 1 ? null : 1),
        ),
        _PainCircle(
          label: l10n.daily_entry_pain_moderate,
          fillColor: accent.withValues(alpha: 0.55),
          value: 2,
          selected: selected,
          accent: accent,
          textPrimary: textPrimary,
          onTap: () => onChanged(selected == 2 ? null : 2),
        ),
        _PainCircle(
          label: l10n.daily_entry_pain_severe,
          fillColor: accent.withValues(alpha: 0.90),
          value: 3,
          selected: selected,
          accent: accent,
          textPrimary: textPrimary,
          onTap: () => onChanged(selected == 3 ? null : 3),
        ),
      ],
    );
  }
}

class _PainCircle extends StatelessWidget {
  const _PainCircle({
    required this.label,
    required this.fillColor,
    required this.value,
    required this.selected,
    required this.accent,
    required this.textPrimary,
    required this.onTap,
    this.showBorder = false,
    this.borderColor,
  });

  final String label;
  final Color fillColor;
  final int value;
  final int? selected;
  final Color accent;
  final Color textPrimary;
  final VoidCallback onTap;
  final bool showBorder;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;

    // Dot with optional soft halo: outer ring (46dp) wraps 36dp filled circle.
    // No hard border on selection — design uses a translucent stroke halo.
    Widget dot = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: (!isSelected && showBorder && borderColor != null)
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
      ),
    );

    if (isSelected) {
      dot = Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: accent.withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: dot,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Center(child: dot),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: MetraTypography.tiny.copyWith(
                color: isSelected ? accent : textPrimary.withValues(alpha: 0.38),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
