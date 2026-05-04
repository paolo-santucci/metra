// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License,
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
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/metra_colors.dart';
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
    final colors = MetraColors.of(context);
    final accentFlow = colors.accentFlow;
    final accentFlowStrong = colors.accentFlowStrong;
    final textPrimary = colors.textPrimary;

    final labels = [
      l10n.daily_entry_flow_intensity_light,
      l10n.daily_entry_flow_intensity_medium,
      l10n.daily_entry_flow_intensity_heavy,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          for (var i = 0; i < _levels.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _IntensityDot(
              label: labels[i],
              intensity: _levels[i].$1,
              fillOpacity: _levels[i].$2,
              selected: selected == _levels[i].$1,
              accentFlow: accentFlow,
              accentFlowStrong: accentFlowStrong,
              textPrimary: textPrimary,
              onTap: () => onChanged(
                selected == _levels[i].$1 ? null : _levels[i].$1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntensityDot extends StatelessWidget {
  const _IntensityDot({
    required this.label,
    required this.intensity,
    required this.fillOpacity,
    required this.selected,
    required this.accentFlow,
    required this.accentFlowStrong,
    required this.textPrimary,
    required this.onTap,
  });

  final String label;
  final FlowIntensity intensity;
  final double fillOpacity;
  final bool selected;
  final Color accentFlow;
  final Color accentFlowStrong;
  final Color textPrimary;
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
              width: 50,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (selected)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentFlow.withValues(alpha: 0.30),
                          width: 1.2,
                        ),
                      ),
                    ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentFlow.withValues(alpha: fillOpacity),
                      border: Border.all(
                        color: accentFlow,
                        width: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                height: 1.4,
                color: selected
                    ? accentFlowStrong
                    : textPrimary.withValues(alpha: 0.40),
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
