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

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.points,
    required this.color,
    required this.maxValue,
  });

  final List<({String label, double value})> points;
  final Color color;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = points
        .map((p) => '${p.label}: ${_formatValue(p.value)}')
        .join(', ');

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points
            .map(
              (p) => _BarColumn(
                point: p,
                color: color,
                maxValue: maxValue,
              ),
            )
            .toList(),
      ),
    );
  }

  static String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.point,
    required this.color,
    required this.maxValue,
  });

  final ({String label, double value}) point;
  final Color color;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final barHeight = maxValue > 0
        ? (point.value / maxValue * 80).clamp(0.0, 80.0)
        : 0.0;
    final displayValue = _formatValue(point.value);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 80,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: MetraSpacing.sp28,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MetraSpacing.sp5),
          Text(
            point.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: MetraColors.light.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MetraSpacing.sp2),
          Text(
            displayValue,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: MetraColors.light.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
