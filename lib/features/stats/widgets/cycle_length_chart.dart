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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/cycle_stats_data.dart';
import '../../../l10n/app_localizations.dart';

class CycleLengthChart extends StatelessWidget {
  const CycleLengthChart({super.key, required this.points});

  final List<CycleDataPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final lineColor =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final textColor = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;

    final spots = points
        .asMap()
        .entries
        .map(
          (e) => FlSpot(e.key.toDouble(), e.value.cycleLength.toDouble()),
        )
        .toList();

    final lengths = points.map((p) => p.cycleLength);
    final avg = lengths.isEmpty
        ? 0
        : (lengths.reduce((a, b) => a + b) / lengths.length).round();
    final minY =
        (lengths.isEmpty ? 20 : lengths.reduce((a, b) => a < b ? a : b)) - 5.0;
    final maxY =
        (lengths.isEmpty ? 35 : lengths.reduce((a, b) => a > b ? a : b)) + 5.0;

    final semanticsLabel = points
        .map(
          (p) =>
              '${intl.DateFormat.MMM('it').format(p.startDate)}: ${p.cycleLength} g',
        )
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: semanticsLabel,
          child: SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: lineColor,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: lineColor,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: TextStyle(color: textColor, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          intl.DateFormat.MMM(
                            'it',
                          ).format(points[idx].startDate),
                          style: TextStyle(color: textColor, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                minY: minY,
                maxY: maxY,
                lineTouchData: const LineTouchData(enabled: false),
              ),
              duration: Duration(milliseconds: reduceMotion ? 0 : 240),
            ),
          ),
        ),
        const SizedBox(height: MetraSpacing.s2),
        Text(
          l10n.stats_cycle_length_avg(avg),
          style: TextStyle(color: textColor, fontSize: 13),
        ),
      ],
    );
  }
}
