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

/// Four-item legend row shown below the calendar grid.
/// Items: Mestruazioni (drop), Previsione (drop_outline), Sintomi (star), Dolore (bolt).
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final accentPrediction = isDark
        ? MetraColors.dark.accentPrediction
        : MetraColors.light.accentPrediction;
    final accentWarmth = isDark
        ? MetraColors.dark.accentWarmth
        : MetraColors.light.accentWarmth;
    final accentPain =
        isDark ? MetraColors.dark.accentPain : MetraColors.light.accentPain;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(color: dividerColor, thickness: 1, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _LegendItem(
                icon: Icons.water_drop,
                color: accentFlow,
                label: l10n.calendar_legend_mestruazioni,
                textColor: textSecondary,
              ),
              const SizedBox(width: 16),
              _LegendItem(
                icon: Icons.water_drop_outlined,
                color: accentPrediction,
                label: l10n.calendar_legend_prediction,
                textColor: textSecondary,
              ),
              const SizedBox(width: 16),
              _LegendItem(
                icon: Icons.star_border,
                color: accentWarmth,
                label: l10n.calendar_legend_sintomi,
                textColor: textSecondary,
              ),
              const SizedBox(width: 16),
              _LegendItem(
                icon: Icons.bolt,
                color: accentPain,
                label: l10n.calendar_legend_dolore,
                textColor: textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.textColor,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: MetraTypography.tiny.copyWith(color: textColor),
        ),
      ],
    );
  }
}
