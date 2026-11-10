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
///
/// Anatomy is canon `docs/canon/ui-design-bible.md` §6.1: radius 18 (= ½ × the
/// 36 dp chip body), terracotta fill with sabbia text and a transparent border
/// when selected, colour-only selection, no checkmark (§15.2). The 44 dp
/// minimum hit area (NFR-03) wraps that body. The label takes the §1.2
/// "Filter / chip label" row (Inter 13).
///
/// [idleFontWeight] is the opt-in for the Archivio filter row, which passes
/// [FontWeight.w400] per canon §1.2 ("Filter / chip label": 400 idle / 500
/// selected). `null` — the default — keeps the daily-entry rendering at `w500`
/// so existing call sites and goldens are unchanged. The selected label always
/// renders `w500`, whatever this value is.
///
/// <!-- CANON GAP: filter-chip visual surface — OQ-02 -->
class ChoiceChipMetra extends StatelessWidget {
  const ChoiceChipMetra({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.semanticsLabel,
    this.idleFontWeight,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String semanticsLabel;

  /// Weight applied to the label while unselected. `null` (default) keeps
  /// `FontWeight.w500` — the daily-entry rendering. The Archivio filter row
  /// passes [FontWeight.w400] per canon §1.2 "Filter / chip label".
  final FontWeight? idleFontWeight;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final bgSelected = colors.accentFlow;
    final fgSelected = colors.bgPrimary;
    final textPrimary = colors.textPrimary;
    final idleWeight = idleFontWeight ?? FontWeight.w500;

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
                    fontWeight: selected ? FontWeight.w500 : idleWeight,
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
