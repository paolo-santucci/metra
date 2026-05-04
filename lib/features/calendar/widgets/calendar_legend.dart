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

/// Five-item legend row shown below the calendar grid.
/// Items (left→right): Flusso (dropFilled), Sintomi (starSmallFilled),
/// Dolore (zapFilled), Previsione (dropOutline), Note (pen). All icons are MetraIcons SVG.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);

    final accentFlow = colors.accentFlow;
    final accentPrediction = colors.accentPrediction;
    final accentWarmth = colors.accentWarmth;
    final accentPain = colors.accentPain;
    final textSecondary = colors.textSecondary;
    final textPrimary = colors.textPrimary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(color: dividerColor, thickness: 1, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            // Order: Flusso, Sintomi, Dolore, Previsione, Note (Note is last).
            children: [
              _MetraLegendItem(
                svgBody: MetraIcons.dropFilled,
                color: accentFlow,
                label: l10n.calendar_legend_flow,
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
              _MetraLegendItem(
                svgBody: MetraIcons.pen,
                color: textPrimary.withValues(alpha: 0.68),
                label: l10n.calendar_legend_notes,
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
