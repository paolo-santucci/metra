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

import 'pain_symptom_type.dart';

class PainSymptomData {
  const PainSymptomData({
    required this.symptomType,
    this.customLabel,
  });

  final PainSymptomType symptomType;
  final String? customLabel;

  PainSymptomData copyWith({
    PainSymptomType? symptomType,
    String? customLabel,
  }) {
    return PainSymptomData(
      symptomType: symptomType ?? this.symptomType,
      customLabel: customLabel ?? this.customLabel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PainSymptomData &&
          runtimeType == other.runtimeType &&
          symptomType == other.symptomType &&
          customLabel == other.customLabel;

  @override
  int get hashCode => symptomType.hashCode ^ customLabel.hashCode;
}
