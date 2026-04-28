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
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';

class TableView extends StatelessWidget {
  const TableView({super.key, required this.summaries});

  final List<CycleSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const _TableEmptyState();
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headerStyle = MetraTypography.caption.copyWith(
      color: isDark
          ? MetraColors.dark.textSecondary
          : MetraColors.light.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final cellStyle = MetraTypography.body.copyWith(
      color:
          isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary,
      fontSize: 14,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MetraSpacing.s4),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            children: [
              l10n.table_col_start,
              l10n.table_col_cycle,
              l10n.table_col_period,
              l10n.table_col_symptoms,
            ]
                .map(
                  (label) => Semantics(
                    header: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: MetraSpacing.s2,
                      ),
                      child: Text(label, style: headerStyle),
                    ),
                  ),
                )
                .toList(),
          ),
          ...summaries.map((s) {
            final dateStr = intl.DateFormat('d MMM', 'it').format(
              s.cycle.startDate,
            );
            final cycleLenStr = s.cycle.cycleLength != null
                ? '${s.cycle.cycleLength} g'
                : l10n.table_cycle_dash;
            final periodLenStr = s.cycle.periodLength != null
                ? '${s.cycle.periodLength} g'
                : l10n.table_cycle_dash;
            final symptomsStr = _formatSymptoms(s.symptoms, l10n);

            return TableRow(
              children: [dateStr, cycleLenStr, periodLenStr, symptomsStr]
                  .map(
                    (text) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: MetraSpacing.s3,
                      ),
                      child: Text(text, style: cellStyle),
                    ),
                  )
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  String _formatSymptoms(
    List<PainSymptomType> symptoms,
    AppLocalizations l10n,
  ) {
    if (symptoms.isEmpty) return '—';
    final labels = symptoms
        .map((s) => _symptomLabel(l10n, s))
        .where((s) => s.isNotEmpty)
        .toList();
    if (labels.isEmpty) return '—';
    if (labels.length <= 2) return labels.join(', ');
    return '${labels.take(2).join(', ')}…';
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

class _TableEmptyState extends StatelessWidget {
  const _TableEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MetraSpacing.s8),
        child: Text(
          l10n.timeline_empty_hint,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark
                ? MetraColors.dark.textSecondary
                : MetraColors.light.textSecondary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
