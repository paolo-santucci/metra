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
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/services/cycle_filter_matcher.dart';

void main() {
  const headache = PainSymptomData(symptomType: PainSymptomType.headache);
  const fatigue = PainSymptomData(symptomType: PainSymptomType.fatigue);
  const bloating = PainSymptomData(symptomType: PainSymptomType.bloating);
  const matcher = CycleFilterMatcher();

  PainSymptomData customSymptom(String label) => PainSymptomData(
        symptomType: PainSymptomType.custom,
        customLabel: label,
      );

  CycleSummary summary({
    int id = 1,
    required DateTime startDate,
    DateTime? endDate,
    List<PainSymptomData> symptoms = const <PainSymptomData>[],
  }) {
    return CycleSummary(
      cycle: CycleEntryEntity(id: id, startDate: startDate, endDate: endDate),
      symptoms: symptoms,
      dominantPainIntensity: null,
    );
  }

  final olderStart = DateTime.utc(2026, 9, 1);
  final olderEnd = DateTime.utc(2026, 9, 6);
  final trailingStart = DateTime.utc(2026, 10, 20);
  final trailingEnd = DateTime.utc(2026, 10, 25);
  final now = DateTime.utc(2026, 11, 10, 15, 30);

  CycleSummary olderCycle({List<PainSymptomData> symptoms = const []}) =>
      summary(
        id: 1,
        startDate: olderStart,
        endDate: olderEnd,
        symptoms: symptoms,
      );

  CycleSummary trailingCycle({List<PainSymptomData> symptoms = const []}) =>
      summary(
        id: 2,
        startDate: trailingStart,
        endDate: trailingEnd,
        symptoms: symptoms,
      );

  group('CycleFilterQuery.isActive', () {
    test('given_defaultQuery_when_isActive_then_false', () {
      const query = CycleFilterQuery();

      expect(query.isActive, isFalse);
    });

    test('given_whitespaceOnlyNoteText_when_isActive_then_false', () {
      const query = CycleFilterQuery(noteText: '   ');

      expect(query.isActive, isFalse);
    });

    test('given_symptomsOnly_when_isActive_then_true', () {
      final query = CycleFilterQuery(
        symptoms: <PainSymptomData>{headache},
      );

      expect(query.isActive, isTrue);
    });

    test('given_textOnly_when_isActive_then_true', () {
      const query = CycleFilterQuery(noteText: 'perche');

      expect(query.isActive, isTrue);
    });

    test('given_symptomsAndText_when_isActive_then_true', () {
      final query = CycleFilterQuery(
        symptoms: <PainSymptomData>{headache},
        noteText: 'perche',
      );

      expect(query.isActive, isTrue);
    });
  });

  group('CycleFilterMatcher.apply identity', () {
    test('given_defaultQuery_when_apply_then_allSummariesInInputOrder', () {
      final summaries = [trailingCycle(), olderCycle()];

      final result = matcher.apply(
        summaries: summaries,
        notesByDate: const <DateTime, String>{},
        query: const CycleFilterQuery(),
      );

      expect(result, summaries);
    });

    test('given_whitespaceOnlyNoteText_when_apply_then_allSummaries', () {
      final summaries = [trailingCycle(), olderCycle()];

      final result = matcher.apply(
        summaries: summaries,
        notesByDate: <DateTime, String>{DateTime.utc(2026, 10, 22): 'x'},
        query: const CycleFilterQuery(noteText: '   '),
      );

      expect(result, summaries);
    });

    test('given_activeQuery_when_apply_then_summariesNotMutated', () {
      final summaries = [trailingCycle(), olderCycle()];
      final snapshot = List<CycleSummary>.of(summaries);

      matcher.apply(
        summaries: summaries,
        notesByDate: <DateTime, String>{DateTime.utc(2026, 10, 22): 'x'},
        query: const CycleFilterQuery(noteText: 'x'),
        now: now,
      );

      expect(summaries, snapshot);
    });

    test('given_activeQuery_when_apply_then_notesByDateNotMutated', () {
      final notesByDate = <DateTime, String>{
        DateTime.utc(2026, 10, 22): 'x',
        DateTime.utc(2026, 9, 2): 'y',
      };
      final snapshot = Map<DateTime, String>.of(notesByDate);

      matcher.apply(
        summaries: [trailingCycle(), olderCycle()],
        notesByDate: notesByDate,
        query: const CycleFilterQuery(noteText: 'x'),
        now: now,
      );

      expect(notesByDate, snapshot);
    });
  });

  group('CycleFilterMatcher.apply symptom condition', () {
    test('given_bothSymptomsSelected_when_apply_then_onlyCycleWithBoth', () {
      final both = trailingCycle(symptoms: const [headache, fatigue]);
      final headacheOnly = olderCycle(symptoms: const [headache]);

      final result = matcher.apply(
        summaries: [both, headacheOnly],
        notesByDate: const <DateTime, String>{},
        query: CycleFilterQuery(
          symptoms: <PainSymptomData>{headache, fatigue},
        ),
      );

      expect(result, [both]);
    });

    test('given_emptySymptomSelection_when_apply_then_everyCyclePasses', () {
      final summaries = [
        trailingCycle(symptoms: const [headache]),
        olderCycle(),
      ];

      final result = matcher.apply(
        summaries: summaries,
        notesByDate: const <DateTime, String>{},
        query: const CycleFilterQuery(),
      );

      expect(result, summaries);
    });

    test('given_supersetSymptoms_when_apply_then_cyclePasses', () {
      final superset = trailingCycle(
        symptoms: const [headache, fatigue, bloating],
      );

      final result = matcher.apply(
        summaries: [superset],
        notesByDate: const <DateTime, String>{},
        query: CycleFilterQuery(
          symptoms: <PainSymptomData>{headache, fatigue},
        ),
      );

      expect(result, [superset]);
    });
  });

  group('CycleFilterMatcher.apply custom-label value equality', () {
    test('given_exactCustomLabelSelected_when_apply_then_onlyThatCycle', () {
      final vertigini = trailingCycle(symptoms: [customSymptom('Vertigini')]);
      final other = olderCycle(symptoms: [customSymptom('Nausea')]);

      final result = matcher.apply(
        summaries: [vertigini, other],
        notesByDate: const <DateTime, String>{},
        query: CycleFilterQuery(symptoms: {customSymptom('Vertigini')}),
      );

      expect(result, [vertigini]);
    });

    test('given_lowercaseCustomLabelSelected_when_apply_then_noMatch', () {
      final vertigini = trailingCycle(symptoms: [customSymptom('Vertigini')]);

      final result = matcher.apply(
        summaries: [vertigini],
        notesByDate: const <DateTime, String>{},
        query: CycleFilterQuery(symptoms: {customSymptom('vertigini')}),
      );

      expect(result, isEmpty);
    });
  });

  group('CycleFilterMatcher.apply text condition', () {
    test('given_noteInsideResolvedRange_when_apply_then_cyclePasses', () {
      final summaries = [trailingCycle(), olderCycle()];
      final result = matcher.apply(
        summaries: summaries,
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 10, 22): 'Perché è stato dura',
        },
        query: const CycleFilterQuery(noteText: 'perche'),
        now: now,
      );

      expect(result, [summaries.first]);
    });

    test('given_noteBeforeFirstCycleStart_when_apply_then_unreachable', () {
      final result = matcher.apply(
        summaries: [trailingCycle(), olderCycle()],
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 8, 15): 'Perché è stato dura',
        },
        query: const CycleFilterQuery(noteText: 'perche'),
        now: now,
      );

      expect(result, isEmpty);
    });

    test('given_queryButNoNotes_when_apply_then_everyCycleFails', () {
      final result = matcher.apply(
        summaries: [trailingCycle(), olderCycle()],
        notesByDate: const <DateTime, String>{},
        query: const CycleFilterQuery(noteText: 'perche'),
        now: now,
      );

      expect(result, isEmpty);
    });
  });

  group('CycleFilterMatcher.apply range-rule identity', () {
    test('given_noteDatedToday_when_apply_then_onlyTrailingCycleMatches', () {
      final result = matcher.apply(
        summaries: [trailingCycle(), olderCycle()],
        notesByDate: <DateTime, String>{DateTime.utc(2026, 11, 10): 'nota'},
        query: const CycleFilterQuery(noteText: 'nota'),
        now: now,
      );

      expect(result.map((s) => s.cycle.id), [2]);
    });

    test('given_noteAfterNonTrailingEndDate_when_apply_then_noMatch', () {
      final result = matcher.apply(
        summaries: [trailingCycle(), olderCycle()],
        notesByDate: <DateTime, String>{DateTime.utc(2026, 9, 10): 'nota'},
        query: const CycleFilterQuery(noteText: 'nota'),
        now: now,
      );

      expect(result, isEmpty);
    });
  });

  group('CycleFilterMatcher.apply AND between conditions', () {
    test('given_symptomPassTextFail_when_apply_then_cycleExcluded', () {
      final withSymptom = trailingCycle(symptoms: const [headache]);
      final withoutSymptom = olderCycle();

      final result = matcher.apply(
        summaries: [withSymptom, withoutSymptom],
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 9, 2): 'nota',
        },
        query: CycleFilterQuery(
          symptoms: <PainSymptomData>{headache},
          noteText: 'nota',
        ),
        now: now,
      );

      expect(result, isEmpty);
    });

    test('given_textPassSymptomFail_when_apply_then_cycleExcluded', () {
      final withoutSymptom = trailingCycle();
      final withSymptom = olderCycle(symptoms: const [headache]);

      final result = matcher.apply(
        summaries: [withoutSymptom, withSymptom],
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 10, 22): 'nota',
        },
        query: CycleFilterQuery(
          symptoms: <PainSymptomData>{headache},
          noteText: 'nota',
        ),
        now: now,
      );

      expect(result, isEmpty);
    });

    test('given_bothConditionsPass_when_apply_then_cyclePasses', () {
      final matching = trailingCycle(symptoms: const [headache]);

      final result = matcher.apply(
        summaries: [matching],
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 10, 22): 'nota',
        },
        query: CycleFilterQuery(
          symptoms: <PainSymptomData>{headache},
          noteText: 'nota',
        ),
        now: now,
      );

      expect(result, [matching]);
    });

    test('given_whitespaceNoteText_when_apply_then_onlySymptomsApply', () {
      final withSymptom = trailingCycle(symptoms: const [headache]);
      final withoutSymptom = olderCycle();

      final result = matcher.apply(
        summaries: [withSymptom, withoutSymptom],
        notesByDate: const <DateTime, String>{},
        query: CycleFilterQuery(
          symptoms: <PainSymptomData>{headache},
          noteText: '   ',
        ),
        now: now,
      );

      expect(result, [withSymptom]);
    });
  });

  group('CycleFilterMatcher.apply folding on both sides', () {
    test('given_uppercaseQuery_when_apply_then_accentedNoteMatches', () {
      final result = matcher.apply(
        summaries: [trailingCycle()],
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 10, 22): 'Perché è stato dura',
        },
        query: const CycleFilterQuery(noteText: 'PERCHE'),
        now: now,
      );

      expect(result, hasLength(1));
    });

    test('given_graveAccentQuery_when_apply_then_accentedNoteMatches', () {
      final result = matcher.apply(
        summaries: [trailingCycle()],
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 10, 22): 'Perché è stato dura',
        },
        query: const CycleFilterQuery(noteText: 'perchè'),
        now: now,
      );

      expect(result, hasLength(1));
    });

    test('given_accentedSubstringQuery_when_apply_then_noteMatches', () {
      final result = matcher.apply(
        summaries: [trailingCycle()],
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 10, 22): 'Perché è stato dura',
        },
        query: const CycleFilterQuery(noteText: 'ché'),
        now: now,
      );

      expect(result, hasLength(1));
    });

    test('given_regexMetacharacterQuery_when_apply_then_literalOnly', () {
      final literal = trailingCycle();
      final plain = olderCycle();

      final result = matcher.apply(
        summaries: [literal, plain],
        notesByDate: <DateTime, String>{
          DateTime.utc(2026, 10, 22): 'ha .* nel testo',
          DateTime.utc(2026, 9, 2): 'niente punti asterischi',
        },
        query: const CycleFilterQuery(noteText: '.*'),
        now: now,
      );

      expect(result, [literal]);
    });
  });

  group('CycleFilterMatcher.apply degradation', () {
    test('given_noSummaries_when_apply_then_emptyOutput', () {
      final result = matcher.apply(
        summaries: const <CycleSummary>[],
        notesByDate: const <DateTime, String>{},
        query: CycleFilterQuery(
          symptoms: <PainSymptomData>{headache},
          noteText: 'nota',
        ),
        now: now,
      );

      expect(result, isEmpty);
    });

    test('given_activeTextQueryAndNoNotes_when_apply_then_emptyOutput', () {
      final result = matcher.apply(
        summaries: [trailingCycle(), olderCycle()],
        notesByDate: const <DateTime, String>{},
        query: const CycleFilterQuery(noteText: 'nota'),
        now: now,
      );

      expect(result, isEmpty);
    });

    test('given_allMatch_when_apply_then_inputOrderPreserved', () {
      final summaries = [
        trailingCycle(),
        olderCycle(),
        summary(id: 3, startDate: DateTime.utc(2026, 8, 1)),
      ];

      final result = matcher.apply(
        summaries: summaries,
        notesByDate: const <DateTime, String>{},
        query: const CycleFilterQuery(),
      );

      expect(result.map((s) => s.cycle.id), [2, 1, 3]);
    });
  });
}
