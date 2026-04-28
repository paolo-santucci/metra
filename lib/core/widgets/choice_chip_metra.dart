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
import '../theme/metra_colors.dart';
import '../theme/metra_typography.dart';
import '../theme/metra_spacing.dart';

/// Selectable chip with ochre fill when selected.
///
/// Color-blind safe: selected state shows both fill AND an inline check icon
/// (shape cue independent of color), per COMPONENTS_SPEC §2 and CLAUDE.md §10.
/// Semantics uses [toggled] to announce selection state to screen readers.
class ChoiceChipMetra extends StatelessWidget {
  const ChoiceChipMetra({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.semanticsLabel,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bgSelected =
        isDark ? MetraColors.dark.accentWarmth : MetraColors.light.accentWarmth;
    final bgDefault =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    final borderSelected = isDark
        ? MetraColors.dark.accentWarmthStrong
        : MetraColors.light.accentWarmthStrong;
    final borderDefault =
        isDark ? MetraColors.dark.borderSubtle : MetraColors.light.borderSubtle;
    // Selected text on ochre warm bg needs sufficient contrast.
    // accentWarmthStrong (dustyOchreDeep #8A6332) → on ochre: check below.
    // For better contrast: use textOnAccent (sand) on warm ochre bg.
    final fgSelected =
        isDark ? MetraColors.dark.textOnAccent : MetraColors.light.textOnAccent;
    final fgDefault =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;

    return Semantics(
      label: semanticsLabel,
      toggled: selected,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onSelected(!selected),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MetraSpacing.s4,
                vertical: MetraSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: selected ? bgSelected : bgDefault,
                borderRadius: BorderRadius.circular(MetraRadius.pill),
                border: Border.all(
                  color: selected ? borderSelected : borderDefault,
                  width: selected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(
                      Icons.check,
                      size: 12,
                      color: fgSelected,
                    ),
                    const SizedBox(width: MetraSpacing.s1),
                  ],
                  Text(
                    label,
                    style: MetraTypography.caption.copyWith(
                      color: selected ? fgSelected : fgDefault,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
