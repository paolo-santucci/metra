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
import '../../../core/widgets/metra_icon.dart';

/// Single calendar day cell — 48×48 dp rounded square (borderRadius 12).
///
/// State precedence (highest wins): selected > flow > spotting > prediction
/// > today > future > default. States are mutually exclusive in decoration;
/// only one visual treatment is applied at a time.
///
/// When [isFuture] is true the cell renders as faded plain text (0.35 alpha)
/// and ignores any [onTap] — future dates are read-only. The exception: a
/// future cell with [hasPrediction] still renders with the prediction outline
/// (predictions are inherently future).
///
/// Indicator icons (spec § 8.3.2) are rendered below the day number:
/// - flow/spotting → dropFilled (terracotta)
/// - prediction   → dropOutline (nightLavender) — shown independently, not
///   suppressed when flow is also present (CL-01 fix)
/// - symptom      → starSmallFilled (dustyOchre)
/// - pain         → zapFilled / lightning (malva)
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
    this.hasPain = false,
    this.hasSymptom = false,
    this.isToday = false,
    this.isSelected = false,
    this.isFuture = false,
    this.onTap,
  });

  final DateTime date;
  final bool isFlow;
  final bool isSpotting;
  final bool hasPrediction;
  final bool hasNote;
  final bool hasPain;
  final bool hasSymptom;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback? onTap;
  final String semanticsLabel;

  static const double _cellSize = 48.0;
  static const double _borderRadius = 12.0;
  static const double _indicatorSize = 11.0;

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
    final Color accentWarmth =
        isDark ? MetraColors.dark.accentWarmth : MetraColors.light.accentWarmth;
    final Color accentPain =
        isDark ? MetraColors.dark.accentPain : MetraColors.light.accentPain;

    final (Color bg, Border? border, Color textColor, FontWeight fontWeight) =
        _resolveState(
      accentFlow: accentFlow,
      textPrimary: textPrimary,
      bgPrimary: bgPrimary,
      accentPrediction: accentPrediction,
    );

    // Future cells are read-only — suppress tap regardless of what the caller passes.
    final effectiveOnTap = isFuture ? null : onTap;

    // On a selected cell, indicators use the cell background color (inverted).
    final indicatorFlow = isSelected ? bgPrimary : accentFlow;
    final indicatorPrediction = isSelected ? bgPrimary : accentPrediction;
    final indicatorSymptom = isSelected ? bgPrimary : accentWarmth;
    final indicatorPain = isSelected ? bgPrimary : accentPain;

    // Indicator order: flow, prediction, symptom, pain (Bible § 8.3.2).
    // Each indicator is independent — prediction is NOT suppressed when flow
    // is also present (CL-01 fix).
    final indicators = <Widget>[];
    if (isFlow || isSpotting) {
      indicators.add(
        MetraIcon(
          svgBody: MetraIcons.dropFilled,
          size: _indicatorSize,
          color: indicatorFlow,
        ),
      );
    }
    if (hasPrediction) {
      indicators.add(
        MetraIcon(
          svgBody: MetraIcons.dropOutline,
          size: _indicatorSize,
          color: indicatorPrediction,
        ),
      );
    }
    if (hasSymptom) {
      indicators.add(
        MetraIcon(
          svgBody: MetraIcons.starSmallFilled,
          size: _indicatorSize,
          color: indicatorSymptom,
        ),
      );
    }
    if (hasPain) {
      indicators.add(
        MetraIcon(
          svgBody: MetraIcons.zapFilled,
          size: _indicatorSize,
          color: indicatorPain,
        ),
      );
    }

    return Semantics(
      label: semanticsLabel,
      button: effectiveOnTap != null,
      enabled: effectiveOnTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: effectiveOnTap,
        behavior: HitTestBehavior.opaque,
        // Center the 48×48 decorated box within the grid slot so the rounded
        // background has breathing room, matching the HTML spec's fixed
        // width:48/height:48 cell inside 1fr columns.
        child: Center(
          child: SizedBox(
            width: _cellSize,
            height: _cellSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(_borderRadius),
                border: border,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: fontWeight,
                      color: textColor,
                    ),
                  ),
                  if (indicators.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < indicators.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          indicators[i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
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

    // Future dates (date > today) render faded — opacity table 0.35 (Bible § opacity table).
    if (isFuture) {
      return (
        Colors.transparent,
        null,
        textPrimary.withValues(alpha: 0.35),
        FontWeight.w400,
      );
    }

    // Default — Bible § 8.3: day number is inchiostro at full opacity.
    return (
      Colors.transparent,
      null,
      textPrimary,
      FontWeight.w400,
    );
  }
}

