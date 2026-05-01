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
/// null = not logged; 0=Nessuno (transparent fill + malva stroke); 1–3 = increasing fill.
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
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;

    // Spec § 7.3: gap 14 between items, always malva stroke 1.5.
    Widget paincircle(String lbl, Color fill, int v) => _PainCircle(
          label: lbl,
          fillColor: fill,
          value: v,
          selected: selected,
          accent: accent,
          textPrimary: textPrimary,
          onTap: () => onChanged(selected == v ? null : v),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        paincircle(l10n.today_pain_none, Colors.transparent, 0),
        const SizedBox(width: 14),
        paincircle(l10n.daily_entry_pain_mild, accent.withValues(alpha: 0.28), 1),
        const SizedBox(width: 14),
        paincircle(l10n.daily_entry_pain_moderate, accent.withValues(alpha: 0.60), 2),
        const SizedBox(width: 14),
        paincircle(l10n.daily_entry_pain_severe, accent.withValues(alpha: 0.92), 3),
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
  });

  final String label;
  final Color fillColor;
  final int value;
  final int? selected;
  final Color accent;
  final Color textPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;

    // Inner 36dp circle always has malva stroke 1.5 (spec § 7.3).
    // Outer 46dp halo ring only appears when selected.
    Widget dot = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: accent, width: 1.5),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 50,
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
    );
  }
}
