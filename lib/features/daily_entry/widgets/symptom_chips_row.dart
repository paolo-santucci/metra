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

import '../../../core/theme/metra_spacing.dart';
import '../../../core/widgets/choice_chip_metra.dart';
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';

/// Multi-select row of chips for fixed pain symptom types.
///
/// Supported types: cramps, backPain, headache, migraine, bloating.
/// The custom type is omitted from this row (handled separately if needed).
class SymptomChipsRow extends StatelessWidget {
  const SymptomChipsRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<PainSymptomType> selected;
  final ValueChanged<Set<PainSymptomType>> onChanged;

  static const List<PainSymptomType> _fixedTypes = [
    PainSymptomType.cramps,
    PainSymptomType.backPain,
    PainSymptomType.headache,
    PainSymptomType.migraine,
    PainSymptomType.bloating,
  ];

  String _label(PainSymptomType type, AppLocalizations l10n) {
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
        return l10n.daily_entry_symptom_custom;
    }
  }

  @override
  Widget build(BuildContext context) {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: MetraSpacing.s2,
      runSpacing: MetraSpacing.s2,
      children: _fixedTypes.map((type) {
        final label = _label(type, l10n);
        return ChoiceChipMetra(
          label: label,
          selected: selected.contains(type),
          semanticsLabel: label,
          onSelected: (isSelected) {
            final updated = Set<PainSymptomType>.from(selected);
            if (isSelected) {
              updated.add(type);
            } else {
              updated.remove(type);
            }
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}
