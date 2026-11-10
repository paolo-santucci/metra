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

import '../entities/cycle_summary.dart';
import '../entities/pain_symptom_data.dart';
import 'cycle_date_range.dart';
import 'search_folding.dart';

/// Immutable filter description. Empty symptoms plus empty or
/// whitespace-only [noteText] is the identity query (no filtering).
class CycleFilterQuery {
  const CycleFilterQuery({
    this.symptoms = const <PainSymptomData>{},
    this.noteText = '',
  });

  /// Selected chips. [PainSymptomData] value equality includes
  /// [PainSymptomData.customLabel] (case-sensitive), so a selected custom
  /// chip matches only cycles carrying that exact recorded label.
  final Set<PainSymptomData> symptoms;

  /// Raw committed query text; the matcher trims and folds it.
  final String noteText;

  bool get isActive => symptoms.isNotEmpty || noteText.trim().isNotEmpty;
}

/// Pure matcher — no repository, no Flutter imports, injectable clock.
///
/// A cycle is returned iff it satisfies the symptom condition AND the text
/// condition, in the order the summaries were supplied. Inputs are never
/// mutated.
class CycleFilterMatcher {
  const CycleFilterMatcher();

  /// Returns the subset of [summaries] satisfying all active filters of
  /// [query], preserving input order.
  ///
  /// [notesByDate] maps a note's date to its text; entries dated outside
  /// every cycle's [CycleDateRange] are unreachable by the text condition.
  /// [now] feeds `CycleDateRange.todayNorm` for the trailing-cycle range.
  List<CycleSummary> apply({
    required List<CycleSummary> summaries,
    required Map<DateTime, String> notesByDate,
    required CycleFilterQuery query,
    DateTime? now,
  }) {
    if (summaries.isEmpty) return const <CycleSummary>[];

    final foldedQuery = foldForSearch(query.noteText);
    if (foldedQuery.isEmpty) {
      return _matchingSymptoms(summaries, query.symptoms);
    }

    return _matchingText(
      summaries: summaries,
      notesByDate: notesByDate,
      symptoms: query.symptoms,
      foldedQuery: foldedQuery,
      now: now,
    );
  }

  List<CycleSummary> _matchingSymptoms(
    List<CycleSummary> summaries,
    Set<PainSymptomData> symptoms,
  ) {
    return summaries
        .where((summary) => _symptomsMatch(summary, symptoms))
        .toList();
  }

  List<CycleSummary> _matchingText({
    required List<CycleSummary> summaries,
    required Map<DateTime, String> notesByDate,
    required Set<PainSymptomData> symptoms,
    required String foldedQuery,
    required DateTime? now,
  }) {
    final todayNorm = CycleDateRange.todayNorm(now);
    final trailingStart = CycleDateRange.trailingStartOf(
      summaries.map((summary) => summary.cycle).toList(),
    );
    final foldedNotes = notesByDate.map(
      (date, note) => MapEntry(date, foldForSearch(note)),
    );

    return summaries
        .where(
          (summary) =>
              _symptomsMatch(summary, symptoms) &&
              _hasMatchingNote(
                summary,
                trailingStart,
                todayNorm,
                foldedNotes,
                foldedQuery,
              ),
        )
        .toList();
  }

  bool _symptomsMatch(
    CycleSummary summary,
    Set<PainSymptomData> symptoms,
  ) {
    return symptoms.every(summary.symptoms.contains);
  }

  bool _hasMatchingNote(
    CycleSummary summary,
    DateTime trailingStart,
    DateTime todayNorm,
    Map<DateTime, String> foldedNotes,
    String foldedQuery,
  ) {
    final range = CycleDateRange.resolve(
      cycle: summary.cycle,
      trailingStart: trailingStart,
      todayNorm: todayNorm,
    );
    return foldedNotes.entries.any(
      (entry) => range.contains(entry.key) && entry.value.contains(foldedQuery),
    );
  }
}
