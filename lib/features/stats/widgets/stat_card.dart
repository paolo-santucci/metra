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
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';

class StatSummaryCard extends StatelessWidget {
  const StatSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.sub,
    this.isAccent = false,
  });

  final String title;
  final String value;
  final String unit;
  final String? sub;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final borderColor = isAccent
        ? colors.terracotta.withAlpha(0x44)
        : colors.borderSubtle;
    final valueColor =
        isAccent ? colors.terracotta : colors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(MetraRadius.lg),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: MetraSpacing.s4,
        horizontal: MetraSpacing.sp18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: MetraTypography.statCard.copyWith(
                  color: valueColor,
                  // Browser renders DM Serif with 'normal' line-height (~1.2).
                  // The token uses 1.0 (tight) which reduces vertical breathing
                  // room by ~6px vs the HTML mockup. Matching browser default here.
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
