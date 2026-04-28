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

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'state/stats_controller.dart';
import 'widgets/cycle_length_chart.dart';
import 'widgets/flow_intensity_chart.dart';
import 'widgets/period_length_chart.dart';
import 'widgets/stat_card.dart';
import 'widgets/symptom_frequency_chart.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary,
      body: SafeArea(
        child: statsAsync.when(
          loading: () => Center(
            child: Semantics(
              label: l10n.common_loading,
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Center(
            child: Text(
              l10n.common_error_generic,
              style: TextStyle(
                color: isDark
                    ? MetraColors.dark.textSecondary
                    : MetraColors.light.textSecondary,
              ),
            ),
          ),
          data: (statsData) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: MetraSpacing.s4),
            child: Column(
              children: [
                StatCard(
                  title: l10n.stats_cycle_length_title,
                  child: statsData == null
                      ? _InsufficientData(l10n: l10n)
                      : CycleLengthChart(points: statsData.points),
                ),
                StatCard(
                  title: l10n.stats_period_length_title,
                  child: statsData == null
                      ? _InsufficientData(l10n: l10n)
                      : PeriodLengthChart(points: statsData.points),
                ),
                StatCard(
                  title: l10n.stats_symptoms_title,
                  child: statsData == null
                      ? _InsufficientData(l10n: l10n)
                      : SymptomFrequencyChart(
                          frequencies: statsData.symptomFrequencies,
                        ),
                ),
                StatCard(
                  title: l10n.stats_flow_title,
                  child: statsData == null
                      ? _InsufficientData(l10n: l10n)
                      : FlowIntensityChart(points: statsData.points),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsufficientData extends StatelessWidget {
  const _InsufficientData({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MetraSpacing.s3),
      child: Text(
        l10n.stats_insufficient_data,
        style: TextStyle(
          color: isDark
              ? MetraColors.dark.textSecondary
              : MetraColors.light.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
