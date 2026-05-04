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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';

void main() {
  final cycle = CycleEntryEntity(
    id: 1,
    startDate: DateTime.utc(2026, 4, 1),
    endDate: DateTime.utc(2026, 4, 28),
    cycleLength: 28,
    periodLength: 5,
  );

  const symptom = PainSymptomData(symptomType: PainSymptomType.headache);
  const symptomB = PainSymptomData(
    symptomType: PainSymptomType.custom,
    customLabel: 'jaw',
  );

  CycleSummary makeSummary({
    CycleEntryEntity? cycleEntry,
    List<PainSymptomData> symptoms = const [],
    FlowIntensity? dominantFlow = FlowIntensity.medium,
    int? dominantPainIntensity = 2,
  }) => CycleSummary(
    cycle: cycleEntry ?? cycle,
    symptoms: symptoms,
    dominantFlow: dominantFlow,
    dominantPainIntensity: dominantPainIntensity,
  );

  group('CycleSummary construction', () {
    test('stores all fields', () {
      final summary = CycleSummary(
        cycle: cycle,
        symptoms: [symptom],
        dominantFlow: FlowIntensity.heavy,
        dominantPainIntensity: 3,
      );

      expect(summary.cycle, cycle);
      expect(summary.symptoms, [symptom]);
      expect(summary.dominantFlow, FlowIntensity.heavy);
      expect(summary.dominantPainIntensity, 3);
    });

    test('accepts null dominantFlow', () {
      final summary = makeSummary(dominantFlow: null);

      expect(summary.dominantFlow, isNull);
    });

    test('accepts null dominantPainIntensity', () {
      final summary = makeSummary(dominantPainIntensity: null);

      expect(summary.dominantPainIntensity, isNull);
    });

    test('accepts empty symptoms list', () {
      final summary = makeSummary();

      expect(summary.symptoms, isEmpty);
    });
  });

  group('CycleSummary equality', () {
    test('identical instance equals itself', () {
      final summary = makeSummary(symptoms: [symptom]);
      expect(summary == summary, isTrue);
    });

    test('two instances with equal field values are equal', () {
      final a = makeSummary(symptoms: [symptom]);
      final b = makeSummary(symptoms: [symptom]);

      expect(a, equals(b));
    });

    test('two instances with same-content symptoms lists are equal', () {
      final a = makeSummary(symptoms: [symptom, symptomB]);
      final b = makeSummary(symptoms: [symptom, symptomB]);

      expect(a, equals(b));
    });

    test('instances with different cycles are not equal', () {
      final otherCycle = CycleEntryEntity(
        id: 99,
        startDate: DateTime.utc(2026, 3, 1),
      );
      final a = makeSummary();
      final b = makeSummary(cycleEntry: otherCycle);

      expect(a, isNot(equals(b)));
    });

    test('instances with different symptoms are not equal', () {
      final a = makeSummary(symptoms: [symptom]);
      final b = makeSummary(symptoms: [symptomB]);

      expect(a, isNot(equals(b)));
    });

    test('instances with different symptoms list length are not equal', () {
      final a = makeSummary(symptoms: [symptom]);
      final b = makeSummary(symptoms: [symptom, symptomB]);

      expect(a, isNot(equals(b)));
    });

    test('instances with different dominantFlow are not equal', () {
      final a = makeSummary(dominantFlow: FlowIntensity.light);
      final b = makeSummary(dominantFlow: FlowIntensity.heavy);

      expect(a, isNot(equals(b)));
    });

    test('instances with different dominantPainIntensity are not equal', () {
      final a = makeSummary(dominantPainIntensity: 1);
      final b = makeSummary(dominantPainIntensity: 3);

      expect(a, isNot(equals(b)));
    });

    test('instance does not equal object of different type', () {
      final summary = makeSummary();

      // ignore: unrelated_type_equality_checks
      expect(summary == 'not a summary', isFalse);
    });
  });

  group('CycleSummary hashCode', () {
    test('equal objects have the same hashCode', () {
      final a = makeSummary(symptoms: [symptom]);
      final b = makeSummary(symptoms: [symptom]);

      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
