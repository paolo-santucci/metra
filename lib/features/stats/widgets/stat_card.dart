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
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: MetraSpacing.s4,
        vertical: MetraSpacing.s2,
      ),
      padding: const EdgeInsets.all(MetraSpacing.s4),
      decoration: BoxDecoration(
        color:
            isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface,
        borderRadius: BorderRadius.circular(MetraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MetraTypography.titleSm.copyWith(
              color: isDark
                  ? MetraColors.dark.textPrimary
                  : MetraColors.light.textPrimary,
            ),
          ),
          const SizedBox(height: MetraSpacing.s3),
          child,
        ],
      ),
    );
  }
}
