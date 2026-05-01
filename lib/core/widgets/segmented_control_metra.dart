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
    // § 5.4: idle label = inchiostro (textPrimary) at 50% alpha.
    final inactiveText = isDark
        ? MetraColors.dark.textPrimary.withValues(alpha: 0.5)
        : MetraColors.light.textPrimary.withValues(alpha: 0.5);

    final List<Widget> segmentWidgets = [];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) segmentWidgets.add(const SizedBox(width: 2));
      final isActive = i == selectedIndex;
      segmentWidgets.add(
        Semantics(
          label: segments[i],
          selected: isActive,
          button: true,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onChanged(i),
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
                borderRadius: BorderRadius.circular(MetraRadius.sm),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x661A1410)
                              : const Color(0x1F2B2521),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                segments[i],
                style: MetraTypography.caption.copyWith(
                  color: isActive ? activeText : inactiveText,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Vista',
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(MetraRadius.smm),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: segmentWidgets,
        ),
      ),
    );
  }
}
