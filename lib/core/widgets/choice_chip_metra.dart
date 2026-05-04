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

/// Selectable chip matching the Quick Entry design: terracotta fill when
/// selected, light gray fill with ink border when unselected. No checkmark —
/// the design relies on fill color alone. Semantics uses [toggled] to announce
/// selection state to screen readers.
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
    final colors = MetraColors.of(context);
    final bgSelected = colors.accentFlow;
    final fgSelected = colors.bgPrimary;
    final textPrimary = colors.textPrimary;

    // Container without `alignment` stays intrinsic-width under Wrap's loose
    // constraints. Row(mainAxisSize.min) gives horizontal centering for the
    // text without triggering Container's expand-to-fill behavior.
    return Semantics(
      label: semanticsLabel,
      toggled: selected,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onSelected(!selected),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: selected ? bgSelected : textPrimary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(MetraRadius.lgg),
            border: selected
                ? Border.all(color: Colors.transparent)
                : Border.all(
                    color: textPrimary.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: MetraSpacing.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: MetraTypography.caption.copyWith(
                    color: selected ? fgSelected : textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
