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

// StatusIndicator — FR-11, FR-12
//
// A 44 dp row showing a circular status dot and a text label.
// active: true  → dot = accentFlow (terracotta), label = textPrimary
// active: false → dot + label = textPrimary.withAlpha(0x61) (ink-at-38%)
//
// The label is wrapped in Semantics(liveRegion: true) so screen readers
// announce a runtime transition between states exactly once.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_spacing.dart';

/// Backup status indicator atom.
///
/// Renders a 44 dp ([MetraSpacing.sp44]) row: 8 dp circular dot, 8 dp gap,
/// Inter 14 / w400 label. Colour switches on [active]:
/// - `true`  → dot = `accentFlow`, label = `textPrimary`
/// - `false` → dot + label = `textPrimary.withAlpha(0x61)` (38 %)
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    required this.label,
    required this.active,
    super.key,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = MetraColors.of(context);

    final Color dotColor;
    final Color labelColor;

    if (active) {
      dotColor = palette.accentFlow;
      labelColor = palette.textPrimary;
    } else {
      final dimmed = palette.textPrimary.withAlpha(0x61);
      dotColor = dimmed;
      labelColor = dimmed;
    }

    return SizedBox(
      height: MetraSpacing.sp44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 8 dp circular dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // Label with liveRegion semantics — announced once on active flip.
            // excludeSemantics: true prevents the child Text from contributing
            // a duplicate label to the semantics tree.
            Semantics(
              liveRegion: true,
              label: label,
              excludeSemantics: true,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
