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
    required this.onToday,
    required this.todayLabel,
    this.canGoNext = true,
  });

  final String title;
  final String prevLabel;
  final String nextLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final String todayLabel;

  /// When false, the next-month button is non-interactive (already at current month).
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final textPrimary = colors.textPrimary;
    // Bible § 8.1: inchiostro when enabled, faded (alpha 0.40) when disabled.
    final chevronPrev = textPrimary;
    final chevronNext =
        canGoNext ? textPrimary : textPrimary.withValues(alpha: 0.40);

    return Padding(
      // Bible § 8.1: padding 12 / 24 / 0 → top 12, sides 24, bottom 0.
      padding: const EdgeInsets.fromLTRB(
        MetraSpacing.s6,
        MetraSpacing.s3,
        MetraSpacing.s6,
        MetraSpacing.s0,
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
                  style:
                      MetraTypography.screenTitle.copyWith(color: textPrimary),
                ),
              ],
            ),
          ),
          // Right: prev / today / next buttons.
          Semantics(
            label: prevLabel,
            button: true,
            child: IconButton(
              onPressed: onPrev,
              icon: Icon(Icons.chevron_left, color: chevronPrev),
              tooltip: prevLabel,
              iconSize: 22,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
            ),
          ),
          TextButton(
            onPressed: onToday,
            style: TextButton.styleFrom(
              foregroundColor: textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              todayLabel,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Semantics(
            label: nextLabel,
            button: true,
            child: IgnorePointer(
              ignoring: !canGoNext,
              child: IconButton(
                onPressed: canGoNext ? onNext : null,
                icon: Icon(Icons.chevron_right, color: chevronNext),
                tooltip: nextLabel,
                iconSize: 22,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
