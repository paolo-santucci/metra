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

/// 2–3 segment toggle control.
///
/// Implements WAI-ARIA tablist pattern via Semantics:
/// the container has `label` for context, each option announces
/// its selection state via [toggled].
class SegmentedControlMetra extends StatelessWidget {
  const SegmentedControlMetra({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(segments.length >= 2 && segments.length <= 3);

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor =
        isDark ? MetraColors.dark.bgSunken : MetraColors.light.bgSunken;
    final activeColor =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    final activeText =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final inactiveText = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;

    return Semantics(
      label: 'Vista',
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(MetraRadius.pill),
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(segments.length, (index) {
            final isActive = index == selectedIndex;
            return Semantics(
              label: segments[index],
              selected: isActive,
              button: true,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChanged(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  constraints: const BoxConstraints(
                    minHeight: 36,
                    minWidth: 44,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: MetraSpacing.s4,
                    vertical: MetraSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(MetraRadius.pill),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              // single elevation level per CLAUDE.md §8.5
                              color: isDark
                                  ? const Color(0x661A1410)
                                  : const Color(0x142B2521),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    segments[index],
                    style: MetraTypography.caption.copyWith(
                      color: isActive ? activeText : inactiveText,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
