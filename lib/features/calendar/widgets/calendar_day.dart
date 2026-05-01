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

/// Single calendar day cell — 48×48 dp rounded square (borderRadius 12).
///
/// State precedence (highest wins): selected > flow > spotting > prediction
/// > today > default. States are mutually exclusive in decoration; only one
/// visual treatment is applied at a time.
///
/// [hasNote] is accepted for interface compatibility but has no visual output
/// in this design; note indicators are rendered at the parent grid level.
///
/// Accessibility: caller provides the full [semanticsLabel] string
/// (e.g. "Flusso medio, 15 aprile 2026"). Widget never constructs it.
class CalendarDay extends StatelessWidget {
  const CalendarDay({
    super.key,
    required this.date,
    required this.semanticsLabel,
    this.isFlow = false,
    this.isSpotting = false,
    this.hasPrediction = false,
    this.hasNote = false,
    this.isToday = false,
    this.isSelected = false,
    this.onTap,
  });

  final DateTime date;
  final bool isFlow;
  final bool isSpotting;
  final bool hasPrediction;
  final bool hasNote;
  final bool isToday;
  final bool isSelected;
  final VoidCallback? onTap;
  final String semanticsLabel;

  static const double _cellSize = 48.0;
  static const double _borderRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final Color textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final Color bgPrimary =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final Color accentPrediction = isDark
        ? MetraColors.dark.accentPrediction
        : MetraColors.light.accentPrediction;

    final (Color bg, Border? border, Color textColor, FontWeight fontWeight) =
        _resolveState(
      accentFlow: accentFlow,
      textPrimary: textPrimary,
      bgPrimary: bgPrimary,
      accentPrediction: accentPrediction,
    );

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      enabled: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _cellSize,
          height: _cellSize,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_borderRadius),
            border: border,
          ),
          alignment: Alignment.center,
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  (Color, Border?, Color, FontWeight) _resolveState({
    required Color accentFlow,
    required Color textPrimary,
    required Color bgPrimary,
    required Color accentPrediction,
  }) {

    if (isSelected) {
      return (
        textPrimary,
        null,
        bgPrimary,
        FontWeight.w600,
      );
    }

    if (isFlow) {
      return (
        accentFlow.withValues(alpha: 0.13),
        Border.all(
          color: accentFlow.withValues(alpha: 0.27),
          width: 1.0,
        ),
        textPrimary,
        FontWeight.w500,
      );
    }

    if (isSpotting) {
      return (
        accentFlow.withValues(alpha: 0.07),
        Border.all(
          color: accentFlow.withValues(alpha: 0.22),
          width: 1.0,
        ),
        textPrimary,
        FontWeight.w400,
      );
    }

    if (hasPrediction) {
      return (
        Colors.transparent,
        Border.all(
          color: accentPrediction.withValues(alpha: 0.40),
          width: 1.5,
        ),
        textPrimary.withValues(alpha: 0.60),
        FontWeight.w400,
      );
    }

    if (isToday) {
      return (
        Colors.transparent,
        Border.all(
          color: textPrimary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        textPrimary,
        FontWeight.w500,
      );
    }

    // Default
    return (
      Colors.transparent,
      null,
      textPrimary.withValues(alpha: 0.60),
      FontWeight.w400,
    );
  }
}
