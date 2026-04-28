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
/// Accessibility labels are passed in as strings by the caller so this
/// widget has no context dependency on [AppLocalizations].
class MonthNavigator extends StatelessWidget {
  const MonthNavigator({
    super.key,
    required this.title,
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
    this.canGoNext = true,
  });

  final String title;
  final String prevLabel;
  final String nextLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// When false, the next-month button is hidden (already at current month).
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final iconColor =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MetraSpacing.s4,
        vertical: MetraSpacing.s2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            label: prevLabel,
            button: true,
            child: IconButton(
              onPressed: onPrev,
              icon: Icon(Icons.chevron_left, color: iconColor),
              tooltip: prevLabel,
              iconSize: 28,
              // Minimum 44×44 tap target.
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
            ),
          ),
          Text(
            title,
            style: MetraTypography.titleMd.copyWith(color: textColor),
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
                  icon: Icon(Icons.chevron_right, color: iconColor),
                  tooltip: nextLabel,
                  iconSize: 28,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
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
