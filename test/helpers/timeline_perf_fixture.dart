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

import 'dart:math';

import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';

/// Deterministic ten-year fixture behind the Archivio NFR-01 filter-performance
/// check (sp-20261109-timeline-filter-symptoms-note-search, TASK-18).
///
/// Nothing is checked in: every value is derived from a [Random] seeded with
/// [defaultSeed], so two `generate()` calls with the same seed produce
/// element-wise identical cycle, log and note sets on every machine and every
/// run. That keeps CI's `git diff --exit-code` codegen/diff gates blind to the
/// fixture — there is no file to drift.
///
/// Shape (matching the spec's NFR-01 dataset):
/// * [expectedCycleCount] cycles of 26–31 days, covering exactly
///   [historyDays] daily logs (ten years from [firstDay]);
/// * ~35 % of the logs carry a free note, so the note-substring path has a
///   realistic (non-trivial, non-exhaustive) cost;
/// * six predefined symptoms plus legacy `migraine` and three custom labels,
///   which is what the screen derives its chip row from (FR-03/FR-04);
/// * [textQueries] mixes plain, diacritic-folded (`caffe` → `Caffè`) and
///   no-match queries so the perf loop exercises every text branch.
class TimelinePerfFixture {
  const TimelinePerfFixture._({
    required this.cycles,
    required this.dailyLogs,
    required this.notesByDate,
  });

  /// Seed behind every fixture the perf suite uses.
  static const int defaultSeed = 20261109;

  /// Emulated history length in days (ten years) — the daily-log count.
  static const int historyDays = 3650;

  /// Cycles the generator always produces for [historyDays] days.
  static const int expectedCycleCount = 130;

  /// First day of the emulated history (a past window, so the screen's
  /// trailing-cycle rule — which ends the last cycle at "today" — never
  /// reaches a future note).
  static final DateTime firstDay = DateTime.utc(2015, 1, 1);

  /// Query text used by the perf loop: plain tokens, one diacritic-folded
  /// token (`caffe` must still match `Caffè`, FR-07) and one token that
  /// matches nothing (the no-match state, FR-10).
  static const List<String> textQueries = <String>[
    'stress',
    'caffe',
    'sonno',
    'viaggio',
    'yoga',
    'mal di testa',
    'cioccolato',
    'nessuna-corrispondenza',
  ];

  /// One summary per cycle, in chronological order.
  final List<CycleSummary> cycles;

  /// One log per day, consecutive and chronological from [firstDay].
  final List<DailyLogEntity> dailyLogs;

  /// `{normalizedDate: noteText}` for every note-bearing log — the exact map
  /// `GetCycleNotes` projects, consumed by [CycleFilterMatcher].
  final Map<DateTime, String> notesByDate;

  /// Number of logs that carry a non-empty note.
  int get noteBearingLogCount => notesByDate.length;

  /// Generates the fixture. Same [seed] (and [start]) ⇒ same data, always.
  factory TimelinePerfFixture.generate({
    int seed = defaultSeed,
    DateTime? start,
  }) {
    final random = Random(seed);
    final first = _normalize(start ?? firstDay);

    // Cycle lengths: 26–30 days, nudged until they fill the ten-year window
    // with exactly [expectedCycleCount] cycles (≈130 × 28 = 3 640 days).
    final lengths = <int>[
      for (var i = 0; i < expectedCycleCount; i++) 26 + random.nextInt(5),
    ];
    var totalDays = lengths.fold<int>(0, (sum, days) => sum + days);
    while (totalDays < historyDays) {
      lengths[random.nextInt(expectedCycleCount)] += 1;
      totalDays += 1;
    }
    while (totalDays > historyDays) {
      final index = random.nextInt(expectedCycleCount);
      if (lengths[index] > 26) {
        lengths[index] -= 1;
        totalDays -= 1;
      }
    }

    final cycleStarts = <DateTime>[];
    var offset = 0;
    for (final length in lengths) {
      cycleStarts.add(_addDays(first, offset));
      offset += length;
    }

    final cycles = <CycleSummary>[];
    final logs = <DailyLogEntity>[];
    final notes = <DateTime, String>{};

    for (var c = 0; c < expectedCycleCount; c++) {
      final start = cycleStarts[c];
      final length = lengths[c];
      final periodLength = 3 + random.nextInt(4);
      final flowCounts = <FlowIntensity, int>{};
      var hasNote = false;
      var dominantPain = 0;

      for (var dayInCycle = 0; dayInCycle < length; dayInCycle++) {
        final date = _addDays(start, dayInCycle);
        final flowType = _flowTypeFor(random, dayInCycle, periodLength);
        final flowIntensity =
            flowType == FlowType.mestruazioni ? _intensityFor(random) : null;
        if (flowIntensity != null) {
          flowCounts.update(
            flowIntensity,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }

        final painEnabled = random.nextInt(100) < 55;
        final painIntensity = painEnabled ? 1 + random.nextInt(3) : null;
        if (painIntensity != null && painIntensity > dominantPain) {
          dominantPain = painIntensity;
        }

        final note = random.nextInt(100) < 35 ? _noteFor(random) : null;
        if (note != null) {
          hasNote = true;
          notes[date] = note;
        }

        logs.add(
          DailyLogEntity(
            date: date,
            flowType: flowType,
            flowIntensity: flowIntensity,
            otherDischarge: random.nextInt(100) < 3,
            painEnabled: painEnabled,
            painIntensity: painIntensity,
            notesEnabled: note != null,
            notes: note,
          ),
        );
      }

      cycles.add(
        CycleSummary(
          cycle: CycleEntryEntity(
            id: c + 1,
            startDate: start,
            endDate: _addDays(start, length - 1),
            cycleLength: length,
            periodLength: periodLength,
          ),
          symptoms: _symptomsFor(random),
          dominantFlow: _dominantFlow(flowCounts),
          dominantPainIntensity: dominantPain == 0 ? null : dominantPain,
          hasNote: hasNote,
        ),
      );
    }

    return TimelinePerfFixture._(
      cycles: cycles,
      dailyLogs: logs,
      notesByDate: notes,
    );
  }

  /// Predefined symptoms weighted by how often the fixture records them; keeps
  /// the chip row populated on the first chips the perf loop toggles.
  static const List<(PainSymptomType, int)> _predefinedSymptomWeights =
      <(PainSymptomType, int)>[
    (PainSymptomType.headache, 70),
    (PainSymptomType.fatigue, 55),
    (PainSymptomType.backPain, 45),
    (PainSymptomType.breastTenderness, 40),
    (PainSymptomType.bloating, 35),
    (PainSymptomType.nausea, 30),
  ];

  /// Custom labels the fixture records on a fraction of the cycles.
  static const List<String> _customSymptomLabels = <String>[
    'Acne',
    'Vertigini',
    'Gambe pesanti',
  ];

  /// Free-note vocabulary. Every [textQueries] token except the deliberate
  /// no-match one appears in at least one phrase.
  static const List<String> _notePhrases = <String>[
    'Giornata di stress al lavoro',
    'Caffè doppio a colazione',
    'Dormito male, poco sonno',
    'Viaggio in treno, gambe pesanti',
    'Crampi forti nel pomeriggio',
    'Yoga a casa, mi sento meglio',
    'Mal di testa dopo pranzo',
    'Tanta acqua e riposo',
    'Voglia di cioccolato',
    'Passeggiata lunga, umore alto',
    'Serata tranquilla con amiche',
    'Stanchezza già dal mattino',
  ];
}

/// Distinct symptom set for one cycle, in a stable order.
List<PainSymptomData> _symptomsFor(Random random) {
  final symptoms = <PainSymptomData>[];
  for (final (type, weight) in TimelinePerfFixture._predefinedSymptomWeights) {
    if (random.nextInt(100) < weight) {
      symptoms.add(PainSymptomData(symptomType: type));
    }
  }
  for (final label in TimelinePerfFixture._customSymptomLabels) {
    if (random.nextInt(100) < 12) {
      symptoms.add(
        PainSymptomData(
          symptomType: PainSymptomType.custom,
          customLabel: label,
        ),
      );
    }
  }
  if (random.nextInt(100) < 8) {
    symptoms.add(
      const PainSymptomData(symptomType: PainSymptomType.migraine),
    );
  }
  return symptoms;
}

/// Flow type for one day: bleeding inside the period window, the occasional
/// spotting/absent day outside it, nothing otherwise.
FlowType? _flowTypeFor(Random random, int dayInCycle, int periodLength) {
  if (dayInCycle < periodLength) return FlowType.mestruazioni;
  final roll = random.nextInt(100);
  if (roll < 4) return FlowType.spotting;
  if (roll < 6) return FlowType.assente;
  return null;
}

/// Ordinal intensity for a bleeding day.
FlowIntensity _intensityFor(Random random) {
  final roll = random.nextInt(100);
  if (roll < 45) return FlowIntensity.light;
  if (roll < 80) return FlowIntensity.medium;
  if (roll < 95) return FlowIntensity.heavy;
  return FlowIntensity.veryHeavy;
}

/// Most-frequent flow intensity; the highest ordinal wins on ties
/// (`CycleSummary.dominantFlow` contract).
FlowIntensity? _dominantFlow(Map<FlowIntensity, int> counts) {
  if (counts.isEmpty) return null;
  var best = FlowIntensity.light;
  var bestCount = 0;
  for (final intensity in FlowIntensity.values) {
    final count = counts[intensity] ?? 0;
    if (count >= bestCount) {
      best = intensity;
      bestCount = count;
    }
  }
  return best;
}

String _noteFor(Random random) =>
    TimelinePerfFixture._notePhrases[random.nextInt(
      TimelinePerfFixture._notePhrases.length,
    )];

DateTime _addDays(DateTime date, int days) =>
    DateTime.utc(date.year, date.month, date.day + days);

DateTime _normalize(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
