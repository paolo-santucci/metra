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

import '../../../core/theme/metra_spacing.dart';
import '../../../core/widgets/choice_chip_metra.dart';
import '../../../domain/entities/flow_intensity.dart';
import '../../../l10n/app_localizations.dart';

/// Row of chips for selecting spotting or a flow intensity level.
///
/// Spotting and any flow level are mutually exclusive: selecting one clears
/// the other. Selecting an already-selected flow chip deselects it (sets null).
///
/// Each chip cross-fades between selected and unselected states over 240ms
/// (80ms when reduce-motion is active).
class FlowIntensityPicker extends StatelessWidget {
  const FlowIntensityPicker({
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

  /// Wraps a chip in [AnimatedSwitcher] keyed on [selected] so only the
  /// affected chip cross-fades when selection changes.
  Widget _animatedChip({
    required BuildContext context,
    required bool selected,
    required Widget chip,
  }) {
    final duration = MediaQuery.of(context).disableAnimations
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 240);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        // Key changes when selected flips → triggers the cross-fade.
        key: ValueKey<bool>(selected),
        child: chip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: MetraSpacing.s2,
      runSpacing: MetraSpacing.s2,
      children: [
        // Spotting chip — mutually exclusive with flow levels.
        _animatedChip(
          context: context,
          selected: isSpotting,
          chip: ChoiceChipMetra(
            label: l10n.daily_entry_flow_spotting,
            selected: isSpotting,
            semanticsLabel: l10n.daily_entry_flow_spotting,
            onSelected: (selected) {
              if (selected) {
                // Clear any flow selection when enabling spotting.
                onFlowChanged(null);
                onSpottingChanged(true);
              } else {
                onSpottingChanged(false);
              }
            },
          ),
        ),
        // None chip
        _animatedChip(
          context: context,
          selected: selectedFlow == FlowIntensity.none && !isSpotting,
          chip: ChoiceChipMetra(
            label: l10n.daily_entry_flow_none,
            selected: selectedFlow == FlowIntensity.none && !isSpotting,
            semanticsLabel: l10n.daily_entry_flow_none,
            onSelected: (selected) {
              onSpottingChanged(false);
              onFlowChanged(
                (selected && selectedFlow != FlowIntensity.none)
                    ? FlowIntensity.none
                    : null,
              );
            },
          ),
        ),
        // Light chip
        _animatedChip(
          context: context,
          selected: selectedFlow == FlowIntensity.light && !isSpotting,
          chip: ChoiceChipMetra(
            label: l10n.daily_entry_flow_light,
            selected: selectedFlow == FlowIntensity.light && !isSpotting,
            semanticsLabel: l10n.daily_entry_flow_light,
            onSelected: (selected) {
              onSpottingChanged(false);
              onFlowChanged(
                selected ? FlowIntensity.light : null,
              );
            },
          ),
        ),
        // Medium chip
        _animatedChip(
          context: context,
          selected: selectedFlow == FlowIntensity.medium && !isSpotting,
          chip: ChoiceChipMetra(
            label: l10n.daily_entry_flow_medium,
            selected: selectedFlow == FlowIntensity.medium && !isSpotting,
            semanticsLabel: l10n.daily_entry_flow_medium,
            onSelected: (selected) {
              onSpottingChanged(false);
              onFlowChanged(
                selected ? FlowIntensity.medium : null,
              );
            },
          ),
        ),
        // Heavy chip
        _animatedChip(
          context: context,
          selected: selectedFlow == FlowIntensity.heavy && !isSpotting,
          chip: ChoiceChipMetra(
            label: l10n.daily_entry_flow_heavy,
            selected: selectedFlow == FlowIntensity.heavy && !isSpotting,
            semanticsLabel: l10n.daily_entry_flow_heavy,
            onSelected: (selected) {
              onSpottingChanged(false);
              onFlowChanged(
                selected ? FlowIntensity.heavy : null,
              );
            },
          ),
        ),
        // Very heavy chip
        _animatedChip(
          context: context,
          selected: selectedFlow == FlowIntensity.veryHeavy && !isSpotting,
          chip: ChoiceChipMetra(
            label: l10n.daily_entry_flow_veryHeavy,
            selected: selectedFlow == FlowIntensity.veryHeavy && !isSpotting,
            semanticsLabel: l10n.daily_entry_flow_veryHeavy,
            onSelected: (selected) {
              onSpottingChanged(false);
              onFlowChanged(
                selected ? FlowIntensity.veryHeavy : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
