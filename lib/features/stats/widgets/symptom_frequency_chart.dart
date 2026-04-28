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
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';

class SymptomFrequencyChart extends StatelessWidget {
  const SymptomFrequencyChart({super.key, required this.frequencies});

  final Map<PainSymptomType, double> frequencies;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final trackColor =
        isDark ? MetraColors.dark.bgSunken : MetraColors.light.bgSunken;
    final textColor = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;

    final nonZero = frequencies.entries
        .where((e) => e.key != PainSymptomType.custom && e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (nonZero.isEmpty) {
      return Text(
        l10n.stats_insufficient_data,
        style: TextStyle(color: textColor, fontSize: 14),
      );
    }

    return Column(
      children: nonZero.map((entry) {
        final pct = (entry.value * 100).round();
        final label = _symptomLabel(l10n, entry.key);
        return Semantics(
          label: '$label, $pct%',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MetraSpacing.s1),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    label,
                    style: TextStyle(color: textColor, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: MetraSpacing.s2),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: trackColor,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: MetraSpacing.s2),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
        return '';
    }
  }
}
