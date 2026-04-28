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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_typography.dart';

/// Single calendar day circle.
///
/// Visual size of the circle: 36×36 logical pixels.
/// Total widget minimum tap target: 44×44 (GestureDetector + SizedBox).
///
/// States can coexist. Z-order (bottom to top):
/// 1. Transparent background.
/// 2. Prediction dashed lavender outline.
/// 3. Flow solid terracotta fill.
/// 4. Spotting semi-transparent terracotta fill (if !isFlow).
/// 5. Today thin Ink ring (1.5pt).
/// 6. Selected thick terracotta ring (2.5pt).
/// 7. Day number (DM Serif Display, white on flow, ink otherwise).
/// 8. Note dot: 4pt ochre circle, ~20pt below circle center.
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

  // Visual circle diameter.
  static const double _circleDiameter = 36.0;

  // Full tap-target size (circle + margin for outer rings + hit area).
  static const double _tapTargetSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final flowFill =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final spottingFill = flowFill.withValues(alpha: 0.4);
    final predictionOutline = isDark
        ? MetraColors.dark.accentPrediction
        : MetraColors.light.accentPrediction;
    final todayRing = isDark
        ? MetraColors.dark.textPrimary // ivory
        : MetraColors.light.ink;
    final selectedRing =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final noteColor =
        isDark ? MetraColors.dark.accentWarmth : MetraColors.light.accentWarmth;
    final dayNumberColor = isFlow
        ? Colors.white
        : (isDark ? MetraColors.dark.textPrimary : MetraColors.light.ink);

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      enabled: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _tapTargetSize,
          height: _tapTargetSize,
          child: CustomPaint(
            painter: _CalendarDayPainter(
              dayNumber: date.day,
              isFlow: isFlow,
              isSpotting: isSpotting,
              hasPrediction: hasPrediction,
              hasNote: hasNote,
              isToday: isToday,
              isSelected: isSelected,
              flowFill: flowFill,
              spottingFill: spottingFill,
              predictionOutline: predictionOutline,
              todayRing: todayRing,
              selectedRing: selectedRing,
              noteColor: noteColor,
              dayNumberColor: dayNumberColor,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDayPainter extends CustomPainter {
  const _CalendarDayPainter({
    required this.dayNumber,
    required this.isFlow,
    required this.isSpotting,
    required this.hasPrediction,
    required this.hasNote,
    required this.isToday,
    required this.isSelected,
    required this.flowFill,
    required this.spottingFill,
    required this.predictionOutline,
    required this.todayRing,
    required this.selectedRing,
    required this.noteColor,
    required this.dayNumberColor,
    required this.isDark,
  });

  final int dayNumber;
  final bool isFlow;
  final bool isSpotting;
  final bool hasPrediction;
  final bool hasNote;
  final bool isToday;
  final bool isSelected;
  final Color flowFill;
  final Color spottingFill;
  final Color predictionOutline;
  final Color todayRing;
  final Color selectedRing;
  final Color noteColor;
  final Color dayNumberColor;
  final bool isDark;

  static const double _circleDiameter = CalendarDay._circleDiameter;
  static const double _circleRadius = _circleDiameter / 2;

  // Outer ring radii — rings sit outside the 36pt circle, within the 44pt tap area.
  static const double _todayRingRadius = _circleRadius + 2.5;
  static const double _selectedRingRadius = _circleRadius + 3.0;

  // Dot metrics
  static const double _dotRadius = 2.0; // 4pt diameter
  static const double _dotOffsetY = 20.0; // below circle center

  // Dashed prediction outline
  static const int _dashCount = 14;
  static const double _dashAngle = (2 * math.pi) / (_dashCount * 2);

  @override
  void paint(Canvas canvas, Size size) {
    // Center of the widget — the circle lives here.
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Prediction dashed lavender outline (drawn first, behind everything).
    if (hasPrediction) {
      final paint = Paint()
        ..color = predictionOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      // Draw arc segments to simulate dashed circle.
      for (int i = 0; i < _dashCount; i++) {
        final startAngle = i * 2 * _dashAngle - math.pi / 2;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: _circleRadius - 1),
          startAngle,
          _dashAngle,
          false,
          paint,
        );
      }
    }

    // 2. Flow: solid terracotta fill.
    if (isFlow) {
      canvas.drawCircle(
        center,
        _circleRadius,
        Paint()
          ..color = flowFill
          ..style = PaintingStyle.fill,
      );
    }

    // 3. Spotting: semi-transparent terracotta fill (only when not flow).
    if (isSpotting && !isFlow) {
      canvas.drawCircle(
        center,
        _circleRadius,
        Paint()
          ..color = spottingFill
          ..style = PaintingStyle.fill,
      );
    }

    // 4. Today: thin Ink/Ivory ring (1.5pt stroke) outside the 36pt circle.
    if (isToday) {
      canvas.drawCircle(
        center,
        _todayRingRadius,
        Paint()
          ..color = todayRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 5. Selected: thick terracotta ring (2.5pt stroke) outside the circle.
    if (isSelected) {
      canvas.drawCircle(
        center,
        _selectedRingRadius,
        Paint()
          ..color = selectedRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // 6. Day number (DM Serif Display, tabular nums).
    final textPainter = TextPainter(
      text: TextSpan(
        text: dayNumber.toString(),
        style: MetraTypography.titleSm.copyWith(
          color: dayNumberColor,
          // titleSm uses Inter — for the number we use DM Serif Display per spec.
          fontFamily: 'DM Serif Display',
          fontSize: 18,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // 7. Note dot: 4pt ochre circle below the circle.
    if (hasNote) {
      canvas.drawCircle(
        Offset(center.dx, center.dy + _dotOffsetY),
        _dotRadius,
        Paint()
          ..color = noteColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_CalendarDayPainter oldDelegate) =>
      oldDelegate.dayNumber != dayNumber ||
      oldDelegate.isFlow != isFlow ||
      oldDelegate.isSpotting != isSpotting ||
      oldDelegate.hasPrediction != hasPrediction ||
      oldDelegate.hasNote != hasNote ||
      oldDelegate.isToday != isToday ||
      oldDelegate.isSelected != isSelected ||
      oldDelegate.flowFill != flowFill ||
      oldDelegate.spottingFill != spottingFill ||
      oldDelegate.predictionOutline != predictionOutline ||
      oldDelegate.todayRing != todayRing ||
      oldDelegate.selectedRing != selectedRing ||
      oldDelegate.noteColor != noteColor ||
      oldDelegate.dayNumberColor != dayNumberColor;
}
