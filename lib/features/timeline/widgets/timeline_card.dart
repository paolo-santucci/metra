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
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key, required this.summary});

  final CycleSummary summary;

  // Maximum cycle length used to normalise the proportional bar width.
  static const int _kBarMaxDays = 35;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cycle = summary.cycle;

    // A cycle is in-progress when it has no recorded length yet.
    final bool inProgress = cycle.cycleLength == null;

    final fmt = intl.DateFormat('d MMM', 'it');
    final startStr = fmt.format(cycle.startDate);
    final endStr = cycle.endDate != null ? fmt.format(cycle.endDate!) : '';

    final String semanticsLabel = inProgress
        ? l10n.timeline_card_a11y_in_progress(startStr)
        : l10n.timeline_card_a11y(startStr, endStr, cycle.cycleLength!);

    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);

    // Number of elapsed days in the current in-progress cycle (inclusive of start day).
    final int elapsedDays = todayNorm.difference(cycle.startDate).inDays + 1;

    final double barFraction =
        ((cycle.cycleLength ?? elapsedDays) / _kBarMaxDays).clamp(0.0, 1.0);

    // Terracotta-tinted badge background for in-progress cycles, sunken for complete.
    final Color badgeBg = inProgress
        ? (isDark
            ? MetraColors.dark.accentFlow.withValues(alpha: 0.18)
            : MetraColors.light.accentFlow.withValues(alpha: 0.18))
        : (isDark ? MetraColors.dark.bgSunken : MetraColors.light.bgSunken);
    final Color badgeFg = inProgress
        ? (isDark
            ? MetraColors.dark.accentFlowStrong
            : MetraColors.light.accentFlowStrong)
        : (isDark
            ? MetraColors.dark.textSecondary
            : MetraColors.light.textSecondary);

    final String badgeText = inProgress
        ? l10n.timeline_cycle_in_progress
        : l10n.timeline_cycle_length_days(cycle.cycleLength!);

    final String dateRangeText = inProgress ? startStr : '$startStr – $endStr';

    // Comma-joined symptom labels; custom is intentionally skipped (returns '').
    final List<String> symptomLabels = summary.symptoms
        .map((t) => _symptomLabel(l10n, t))
        .where((s) => s.isNotEmpty)
        .toList();
    final String symptomsText = symptomLabels.join(', ');

    final Color cardColor =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    final Color borderColor =
        isDark ? MetraColors.dark.borderSubtle : MetraColors.light.borderSubtle;
    final Color textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final Color textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final Color barBg =
        isDark ? MetraColors.dark.bgSunken : MetraColors.light.bgSunken;
    final Color barFill =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Card(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetraRadius.md),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(MetraRadius.md),
          onTap: () {
            final dateKey = cycle.startDate.toIso8601String().substring(0, 10);
            context.push('/daily-entry/$dateKey');
          },
          child: Padding(
            padding: const EdgeInsets.all(MetraSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row: date range + badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateRangeText,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: MetraSpacing.s2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MetraSpacing.s3,
                        vertical: MetraSpacing.s1,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(MetraRadius.pill),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MetraSpacing.s3),
                // Proportional bar: full-width track with terracotta fill.
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: barBg,
                        borderRadius: BorderRadius.circular(MetraRadius.pill),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: barFraction,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barFill,
                              borderRadius:
                                  BorderRadius.circular(MetraRadius.pill),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Symptom row (only rendered when there are symptoms to show).
                if (symptomsText.isNotEmpty) ...[
                  const SizedBox(height: MetraSpacing.s2),
                  Text(
                    symptomsText,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _symptomLabel(AppLocalizations l10n, PainSymptomType type) {
    switch (type) {
      case PainSymptomType.cramps:
        return l10n.daily_entry_symptom_cramps;
      case PainSymptomType.backPain:
        return l10n.daily_entry_symptom_backPain;
      case PainSymptomType.headache:
        return l10n.daily_entry_symptom_headache;
      case PainSymptomType.migraine:
        return l10n.daily_entry_symptom_migraine;
      case PainSymptomType.bloating:
        return l10n.daily_entry_symptom_bloating;
      case PainSymptomType.custom:
        // custom symptoms carry no fixed label; caller filters empty strings.
        return '';
    }
  }
}
