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
import '../../../domain/entities/flow_intensity.dart';
import '../../../l10n/app_localizations.dart';

/// Three selectable dots representing menstrual flow intensity levels.
///
/// Maps [FlowIntensity.light], [FlowIntensity.medium], and
/// [FlowIntensity.heavy] to dots of increasing terracotta fill opacity.
/// [FlowIntensity.veryHeavy] is not shown — new entries use only three levels.
/// Tapping the currently selected dot deselects it (calls onChanged with null).
class FlowIntensityDots extends StatelessWidget {
  const FlowIntensityDots({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final FlowIntensity? selected;
  final ValueChanged<FlowIntensity?> onChanged;

  static const List<(FlowIntensity, double)> _levels = [
    (FlowIntensity.light, 0.30),
    (FlowIntensity.medium, 0.65),
    (FlowIntensity.heavy, 0.94),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;

    final labels = [
      l10n.daily_entry_flow_intensity_light,
      l10n.daily_entry_flow_intensity_medium,
      l10n.daily_entry_flow_intensity_heavy,
    ];

    return Row(
      children: [
        for (var i = 0; i < _levels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _IntensityDot(
              label: labels[i],
              intensity: _levels[i].$1,
              fillOpacity: _levels[i].$2,
              selected: selected == _levels[i].$1,
              accent: accent,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => onChanged(
                selected == _levels[i].$1 ? null : _levels[i].$1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IntensityDot extends StatelessWidget {
  const _IntensityDot({
    required this.label,
    required this.intensity,
    required this.fillOpacity,
    required this.selected,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final String label;
  final FlowIntensity intensity;
  final double fillOpacity;
  final bool selected;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: selected,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: selected ? 48 : 36,
                  height: selected ? 48 : 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: fillOpacity),
                    border: selected
                        ? Border.all(color: accent, width: 2)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: MetraTypography.tiny.copyWith(
                color: selected ? textPrimary : textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
