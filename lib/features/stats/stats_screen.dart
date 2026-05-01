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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/theme/metra_typography.dart';
import '../../domain/entities/cycle_stats_data.dart';
import '../../domain/entities/pain_trend.dart';
import '../../l10n/app_localizations.dart';
import 'state/stats_controller.dart';
import 'widgets/chart_card.dart';
import 'widgets/mini_bar_chart.dart';
import 'widgets/stat_card.dart';
import 'widgets/symptom_frequency_chart.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: MetraColors.light.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.stats_title,
                    style: MetraTypography.screenTitle.copyWith(
                      color: MetraColors.light.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.stats_subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: MetraColors.light.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MetraSpacing.s4,
                  0,
                  MetraSpacing.s4,
                  MetraSpacing.sp90,
                ),
                child: statsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      l10n.common_error_generic,
                      style: TextStyle(
                        color: MetraColors.light.textSecondary,
                      ),
                    ),
                  ),
                  data: (statsData) => statsData == null
                      ? Center(
                          child: Text(
                            l10n.stats_insufficient_data,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: MetraColors.light.textSecondary,
                            ),
                          ),
                        )
                      : _StatsBody(statsData: statsData),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.statsData});

  final CycleStatsData statsData;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    final cycleLengthPoints = statsData.points
        .reversed
        .take(6)
        .toList()
        .reversed
        .map((p) => (
              label: intl.DateFormat.MMM(locale).format(p.startDate),
              value: p.cycleLength.toDouble(),
            ),)
        .toList();

    final painPoints = statsData.points
        .reversed
        .take(6)
        .toList()
        .reversed
        .map((p) => (
              label: intl.DateFormat.MMM(locale).format(p.startDate),
              value: (p.dominantPainIntensity ?? 0).toDouble(),
            ),)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryGrid(statsData: statsData),
        ChartCard(
          title: l10n.stats_chart_cycle_length_title,
          child: MiniBarChart(
            points: cycleLengthPoints,
            color: MetraColors.light.terracotta,
            maxValue: 35,
          ),
        ),
        ChartCard(
          title: l10n.stats_chart_pain_title,
          child: MiniBarChart(
            points: painPoints,
            color: MetraColors.light.accentPain,
            maxValue: 3,
          ),
        ),
        ChartCard(
          title: l10n.stats_symptom_card_title,
          child: SymptomFrequencyChart(
            counts: statsData.symptomCounts,
            totalCycles: statsData.cyclesTrackedCount,
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.statsData});

  final CycleStatsData statsData;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final periodSub = statsData.periodLengthMin != null &&
            statsData.periodLengthMax != null
        ? l10n.stats_card_period_length_sub(
            statsData.periodLengthMin!,
            statsData.periodLengthMax!,
          )
        : null;

    final periodValue = statsData.periodLengthAvg != null
        ? statsData.periodLengthAvg!.toStringAsFixed(1)
        : '—';

    final painValue = statsData.painIntensityAvg != null
        ? statsData.painIntensityAvg!.toStringAsFixed(1)
        : '—';

    final painSub = _painTrendLabel(l10n, statsData.painTrend);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - MetraSpacing.sp10) / 2;
        return Wrap(
          spacing: MetraSpacing.sp10,
          runSpacing: MetraSpacing.sp10,
          children: [
            SizedBox(
              width: cardWidth,
              child: StatSummaryCard(
                title: l10n.stats_card_cycle_length_title,
                value: statsData.cycleLengthAvg.toString(),
                unit: l10n.stats_card_cycle_length_unit,
                sub: l10n.stats_card_cycle_length_sub(
                  statsData.cycleLengthMin,
                  statsData.cycleLengthMax,
                ),
                isAccent: true,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatSummaryCard(
                title: l10n.stats_card_period_length_title,
                value: periodValue,
                unit: l10n.stats_card_period_length_unit,
                sub: periodSub,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatSummaryCard(
                title: l10n.stats_card_pain_title,
                value: painValue,
                unit: l10n.stats_card_pain_unit,
                sub: painSub,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatSummaryCard(
                title: l10n.stats_card_cycles_title,
                value: statsData.cyclesTrackedCount.toString(),
                unit: l10n.stats_card_cycles_unit,
              ),
            ),
          ],
        );
      },
    );
  }

  String? _painTrendLabel(AppLocalizations l10n, PainTrend? trend) {
    if (trend == null) return null;
    switch (trend) {
      case PainTrend.increasing:
        return l10n.stats_card_pain_trend_increasing;
      case PainTrend.stable:
        return l10n.stats_card_pain_trend_stable;
      case PainTrend.decreasing:
        return l10n.stats_card_pain_trend_decreasing;
    }
  }
}
