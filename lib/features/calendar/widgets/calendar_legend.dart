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
import '../../../core/widgets/metra_icon.dart';
import '../../../l10n/app_localizations.dart';

/// Four-item legend row shown below the calendar grid.
/// Items (left→right): Mestruazioni (dropFilled), Sintomi (starSmallFilled),
/// Dolore (zapFilled), Previsione (dropOutline). All icons are MetraIcons SVG.
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
    final accentWarmth =
        isDark ? MetraColors.dark.accentWarmth : MetraColors.light.accentWarmth;
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
          // Wrap prevents overflow on narrow screens; items reflow to a second line.
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            // Bible CL-01: Previsione must be last.
            children: [
              _MetraLegendItem(
                svgBody: MetraIcons.dropFilled,
                color: accentFlow,
                label: l10n.calendar_legend_mestruazioni,
                textColor: textSecondary,
              ),
              _MetraLegendItem(
                svgBody: MetraIcons.starSmallFilled,
                color: accentWarmth,
                label: l10n.calendar_legend_sintomi,
                textColor: textSecondary,
              ),
              _MetraLegendItem(
                svgBody: MetraIcons.zapFilled,
                color: accentPain,
                label: l10n.calendar_legend_dolore,
                textColor: textSecondary,
              ),
              _MetraLegendItem(
                svgBody: MetraIcons.dropOutline,
                color: accentPrediction,
                label: l10n.calendar_legend_prediction,
                textColor: textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetraLegendItem extends StatelessWidget {
  const _MetraLegendItem({
    required this.svgBody,
    required this.color,
    required this.label,
    required this.textColor,
  });

  final String svgBody;
  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MetraIcon(svgBody: svgBody, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: MetraTypography.tiny.copyWith(color: textColor),
        ),
      ],
    );
  }
}
