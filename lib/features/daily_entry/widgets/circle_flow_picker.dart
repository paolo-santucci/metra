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

/// Four terracotta circles of increasing size and fill for quick flow entry.
/// Spotting (ring, 36 dp) → Lieve (40% fill, 44 dp) → Moderato (65% fill, 56 dp) → Intenso (full, 66 dp).
/// Tapping the selected circle deselects it (sets null / isSpotting=false).
class CircleFlowPicker extends StatelessWidget {
  const CircleFlowPicker({
    super.key,
    required this.selectedFlow,
    required this.isSpotting,
    required this.onFlowChanged,
    required this.onSpottingChanged,
  });

  final FlowIntensity? selectedFlow;
  final bool isSpotting;
  final ValueChanged<FlowIntensity?> onFlowChanged;
  final ValueChanged<bool> onSpottingChanged;

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FlowCircle(
          label: l10n.daily_entry_flow_spotting,
          diameter: 36,
          fillColor: Colors.transparent,
          ringColor: accent,
          selected: isSpotting,
          accent: accent,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () {
            if (isSpotting) {
              onSpottingChanged(false);
            } else {
              onFlowChanged(null);
              onSpottingChanged(true);
            }
          },
        ),
        _FlowCircle(
          label: l10n.today_flow_lieve,
          diameter: 44,
          fillColor: accent.withValues(alpha: 0.35),
          selected: selectedFlow == FlowIntensity.light && !isSpotting,
          accent: accent,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () {
            onSpottingChanged(false);
            onFlowChanged(
              (selectedFlow == FlowIntensity.light)
                  ? null
                  : FlowIntensity.light,
            );
          },
        ),
        _FlowCircle(
          label: l10n.today_flow_moderato,
          diameter: 56,
          fillColor: accent.withValues(alpha: 0.65),
          selected: selectedFlow == FlowIntensity.medium && !isSpotting,
          accent: accent,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () {
            onSpottingChanged(false);
            onFlowChanged(
              (selectedFlow == FlowIntensity.medium)
                  ? null
                  : FlowIntensity.medium,
            );
          },
        ),
        _FlowCircle(
          label: l10n.today_flow_intenso,
          diameter: 66,
          fillColor: accent,
          selected: (selectedFlow == FlowIntensity.heavy ||
                  selectedFlow == FlowIntensity.veryHeavy) &&
              !isSpotting,
          accent: accent,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () {
            onSpottingChanged(false);
            final alreadySelected = selectedFlow == FlowIntensity.heavy ||
                selectedFlow == FlowIntensity.veryHeavy;
            onFlowChanged(alreadySelected ? null : FlowIntensity.heavy);
          },
        ),
      ],
    );
  }
}

class _FlowCircle extends StatelessWidget {
  const _FlowCircle({
    required this.label,
    required this.diameter,
    required this.fillColor,
    required this.selected,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    this.ringColor,
    required this.onTap,
  });

  final String label;
  final double diameter;
  final Color fillColor;
  final Color? ringColor;
  final bool selected;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderSide = selected
        ? BorderSide(color: accent, width: 2.5)
        : (ringColor != null
            ? BorderSide(color: ringColor!, width: 1.5)
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
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fillColor,
                    border: Border.fromBorderSide(borderSide),
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
