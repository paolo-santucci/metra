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

/// Month/year navigation header for the calendar screen.
///
/// Spec § 8.1: left column = month name (DM Serif Display 26) + optional
/// cycle-day caption row; right column = prev/next chevrons.
class MonthNavigator extends StatelessWidget {
  const MonthNavigator({
    super.key,
    required this.title,
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
    this.canGoNext = true,
    this.cycleDay,
  });

  final String title;
  final String prevLabel;
  final String nextLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// When false, the next-month button is hidden (already at current month).
  final bool canGoNext;

  /// Optional current cycle day number shown below the month name.
  final int? cycleDay;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final chevronActive = textPrimary;
    final chevronInactive = textPrimary.withValues(alpha: 0.40);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MetraSpacing.s4,
        MetraSpacing.s3,
        MetraSpacing.s2,
        MetraSpacing.s2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: month name + optional cycle-day caption.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: MetraTypography.screenTitle.copyWith(color: textPrimary),
                ),
                if (cycleDay != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.brightness_2_rounded,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Giorno $cycleDay',
                        style: MetraTypography.caption.copyWith(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Right: prev / next buttons.
          Semantics(
            label: prevLabel,
            button: true,
            child: IconButton(
              onPressed: onPrev,
              icon: Icon(Icons.chevron_left, color: chevronInactive),
              tooltip: prevLabel,
              iconSize: 24,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
            ),
          ),
          Semantics(
            label: nextLabel,
            button: true,
            child: Opacity(
              opacity: canGoNext ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !canGoNext,
                child: IconButton(
                  onPressed: canGoNext ? onNext : null,
                  icon: Icon(Icons.chevron_right, color: chevronActive),
                  tooltip: nextLabel,
                  iconSize: 24,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
