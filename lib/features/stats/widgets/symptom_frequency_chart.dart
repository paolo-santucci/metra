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
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';

class SymptomFrequencyChart extends StatelessWidget {
  const SymptomFrequencyChart({
    super.key,
    required this.counts,
    required this.totalCycles,
  });

  final Map<PainSymptomType, int> counts;
  final int totalCycles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final nonZero =
        counts.entries
            .where((e) => e.key != PainSymptomType.custom && e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (nonZero.isEmpty || totalCycles == 0) {
      return Text(
        l10n.stats_insufficient_data,
        style: TextStyle(
          color: MetraColors.light.textSecondary,
          fontSize: 14,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < nonZero.length; i++)
          _SymptomRow(
            label: _symptomLabel(l10n, nonZero[i].key),
            count: nonZero[i].value,
            totalCycles: totalCycles,
            isLast: i == nonZero.length - 1,
          ),
      ],
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
      case PainSymptomType.fatigue:
        return l10n.daily_entry_symptom_fatigue;
      case PainSymptomType.nausea:
        return l10n.daily_entry_symptom_nausea;
      case PainSymptomType.breastTenderness:
        return l10n.daily_entry_symptom_breastTenderness;
      case PainSymptomType.custom:
        return '';
    }
  }
}

class _SymptomRow extends StatelessWidget {
  const _SymptomRow({
    required this.label,
    required this.count,
    required this.totalCycles,
    required this.isLast,
  });

  final String label;
  final int count;
  final int totalCycles;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final widthFactor = (count / totalCycles).clamp(0.0, 1.0);

    return Semantics(
      label: '$label, $count di $totalCycles',
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: MetraColors.light.textPrimary,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  '$count/$totalCycles',
                  style: TextStyle(
                    color: MetraColors.light.textSecondary,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: MetraColors.light.ink.withAlpha(0x14),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: MetraColors.light.dustyOchre,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
