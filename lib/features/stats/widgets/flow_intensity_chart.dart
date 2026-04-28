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
import '../../../domain/entities/cycle_stats_data.dart';
import '../../../domain/entities/flow_intensity.dart';
import '../../../l10n/app_localizations.dart';

class FlowIntensityChart extends StatelessWidget {
  const FlowIntensityChart({super.key, required this.points});

  final List<CycleDataPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final textColor = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final barGroups = points.asMap().entries.map((e) {
      final ordinal = (e.value.dominantFlow?.index ?? 0).toDouble();
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: ordinal,
            color: barColor,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final semanticsLabel = points
        .map(
          (p) =>
              '${intl.DateFormat.MMM('it').format(p.startDate)}: ${_flowLabel(l10n, p.dominantFlow)}',
        )
        .join(', ');

    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            maxY: (FlowIntensity.values.length - 1).toDouble(),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
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
                      intl.DateFormat.MMM('it').format(points[idx].startDate),
                      style: TextStyle(color: textColor, fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            barTouchData: BarTouchData(enabled: false),
          ),
          swapAnimationDuration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
        ),
      ),
    );
  }

  String _flowLabel(AppLocalizations l10n, FlowIntensity? fi) {
    switch (fi) {
      case FlowIntensity.none:
        return l10n.daily_entry_flow_none;
      case FlowIntensity.light:
        return l10n.daily_entry_flow_light;
      case FlowIntensity.medium:
        return l10n.daily_entry_flow_medium;
      case FlowIntensity.heavy:
        return l10n.daily_entry_flow_heavy;
      case FlowIntensity.veryHeavy:
        return l10n.daily_entry_flow_veryHeavy;
      case null:
        return '—';
    }
  }
}
