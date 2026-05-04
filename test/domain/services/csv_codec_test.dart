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
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/services/csv_codec.dart';

void main() {
  const codec = CsvCodec();

  // Current header (7 columns).
  const kHeader =
      'date,flow_type,flow,pain_intensity,symptoms,notes,cycle_start';

  DailyLogRow row({
    required DateTime date,
    FlowType? flowType,
    FlowIntensity? flow,
    int? painIntensity,
    String? notes,
    List<PainSymptomData> symptoms = const [],
    bool cycleStart = false,
  }) =>
      DailyLogRow(
        log: DailyLogEntity(
          date: date,
          flowType: flowType,
          flowIntensity: flow,
          painIntensity: painIntensity,
          notes: notes,
        ),
        symptoms: symptoms,
        cycleStart: cycleStart,
      );

  String dataLine(String csv, {int lineIndex = 1}) =>
      csv.replaceAll('\r\n', '\n').split('\n')[lineIndex];

  // ── Encode — header ─────────────────────────────────────────────────────────

  group('encode — header', () {
    test('empty rows produces correct 7-column header', () {
      final csv = codec.encode([]);
      expect(csv.replaceAll('\r\n', '\n').split('\n').first, kHeader);
    });
  });

  // ── Encode — field values ───────────────────────────────────────────────────

  group('encode — field values', () {
    test('null flowType encodes flow_type as empty', () {
      final csv = codec.encode([row(date: DateTime.utc(2026, 3, 1))]);
      expect(dataLine(csv).split(',')[1], '');
    });

    test('FlowType.assente encodes flow_type as 0, flow as empty', () {
      final csv = codec.encode(
        [row(date: DateTime.utc(2026, 3, 1), flowType: FlowType.assente)],
      );
      final cols = dataLine(csv).split(',');
      expect(cols[1], '0'); // flow_type
      expect(cols[2], ''); // flow — not mestruazioni
    });

    test('FlowType.spotting encodes flow_type as 2', () {
      final csv = codec.encode(
        [row(date: DateTime.utc(2026, 3, 1), flowType: FlowType.spotting)],
      );
      expect(dataLine(csv).split(',')[1], '2');
    });

    test('FlowIntensity.veryHeavy encodes flow as 3', () {
      final csv = codec.encode([
        row(
          date: DateTime.utc(2026, 3, 1),
          flowType: FlowType.mestruazioni,
          flow: FlowIntensity.veryHeavy,
        ),
      ]);
      expect(dataLine(csv).split(',')[2], '3');
    });

    test('cycleStart=true encodes as 1 in cycle_start column (index 6)', () {
      final csv =
          codec.encode([row(date: DateTime.utc(2026, 3, 1), cycleStart: true)]);
      expect(dataLine(csv).split(',')[6], '1');
    });

    test('cycleStart=false encodes as 0 in cycle_start column (index 6)', () {
      final csv = codec
          .encode([row(date: DateTime.utc(2026, 3, 1), cycleStart: false)]);
      expect(dataLine(csv).split(',')[6], '0');
    });
  });

  // ── Encode — symptoms ───────────────────────────────────────────────────────

  group('encode — symptoms', () {
    test('built-in symptoms encoded as semicolon-joined names', () {
      final csv = codec.encode([
        row(
          date: DateTime.utc(2026, 3, 1),
          symptoms: [
            const PainSymptomData(symptomType: PainSymptomType.headache),
            const PainSymptomData(symptomType: PainSymptomType.backPain),
          ],
        ),
      ]);
      expect(csv, contains('headache;backPain'));
    });

    test('custom symptom encoded as custom:Label', () {
      final csv = codec.encode([
        row(
          date: DateTime.utc(2026, 3, 1),
          symptoms: [
            const PainSymptomData(
              symptomType: PainSymptomType.custom,
              customLabel: 'Nausea',
            ),
          ],
        ),
      ]);
      expect(csv, contains('custom:Nausea'));
    });
  });

  // ── Decode — header-only ────────────────────────────────────────────────────

  group('decode — header-only (empty export)', () {
    test('header-only CSV → zero rows, zero errors', () {
      final result = codec.decode(codec.encode([]));
      expect(result.rows, isEmpty);
      expect(result.errors, isEmpty);
    });
  });

  // ── Round-trip ──────────────────────────────────────────────────────────────

  group('round-trip', () {
    test('full row with all fields survives encode → decode', () {
      final original = row(
        date: DateTime.utc(2026, 3, 15),
        flowType: FlowType.mestruazioni,
        flow: FlowIntensity.medium,
        painIntensity: 2,
        notes: 'some note with, a comma',
        symptoms: [
          const PainSymptomData(symptomType: PainSymptomType.headache),
          const PainSymptomData(
            symptomType: PainSymptomType.custom,
            customLabel: 'Nausea',
          ),
        ],
        cycleStart: true,
      );

      final result = codec.decode(codec.encode([original]));

      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      final decoded = result.rows.first;
      expect(decoded.log.date, DateTime.utc(2026, 3, 15));
      expect(decoded.log.flowType, FlowType.mestruazioni);
      expect(decoded.log.flowIntensity, FlowIntensity.medium);
      expect(decoded.log.painIntensity, 2);
      expect(decoded.log.painEnabled, isTrue);
      expect(decoded.log.notes, 'some note with, a comma');
      expect(decoded.log.notesEnabled, isTrue);
      expect(decoded.symptoms, hasLength(2));
      expect(decoded.symptoms.first.symptomType, PainSymptomType.headache);
      expect(decoded.symptoms.last.symptomType, PainSymptomType.custom);
      expect(decoded.symptoms.last.customLabel, 'Nausea');
    });

    test('cycle_start column is ignored on decode', () {
      final r = row(
        date: DateTime.utc(2026, 4, 1),
        flowType: FlowType.assente,
        cycleStart: true,
      );
      final result = codec.decode(codec.encode([r]));
      expect(result.errors, isEmpty);
      expect(result.rows.first.cycleStart, isFalse);
    });

    test('multiple rows survive round-trip', () {
      final rows = [
        row(
          date: DateTime.utc(2026, 1, 1),
          flowType: FlowType.mestruazioni,
          flow: FlowIntensity.light,
        ),
        row(
          date: DateTime.utc(2026, 1, 2),
          flowType: FlowType.mestruazioni,
          flow: FlowIntensity.heavy,
        ),
        row(date: DateTime.utc(2026, 1, 3), flowType: FlowType.assente),
      ];
      final result = codec.decode(codec.encode(rows));
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(3));
    });

    test('notes with newlines survive round-trip', () {
      final r = row(
        date: DateTime.utc(2026, 5, 1),
        flowType: FlowType.assente,
        notes: 'line one\nline two',
      );
      final result = codec.decode(codec.encode([r]));
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.notes, 'line one\nline two');
    });

    test(
        'painEnabled and notesEnabled are not preserved across CSV round-trip '
        'when pain/notes sections were opened but left empty', () {
      // pain_enabled and notes_enabled are no longer CSV columns; they are
      // inferred from whether painIntensity/symptoms/notes carry data.
      final r = row(
        date: DateTime.utc(2026, 5, 10),
        flowType: FlowType.assente,
        // no painIntensity, no symptoms, no notes
      );
      final result = codec.decode(codec.encode([r]));
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.painEnabled, isFalse);
      expect(result.rows.first.log.notesEnabled, isFalse);
    });
  });

  // ── Decode — field parsing ──────────────────────────────────────────────────

  group('decode — field parsing', () {
    test(
        'flow_type=1 with empty flow column → defaults to FlowIntensity.medium',
        () {
      const csv = '$kHeader\r\n'
          '2026-03-01,1,,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.flowType, FlowType.mestruazioni);
      expect(result.rows.first.log.flowIntensity, FlowIntensity.medium);
    });

    test(
        'flow_type=0 (assente) → flowIntensity is null regardless of flow column',
        () {
      const csv = '$kHeader\r\n'
          '2026-03-01,0,1,,,, 0\r\n'; // flow=1 present but irrelevant
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.flowType, FlowType.assente);
      expect(result.rows.first.log.flowIntensity, isNull);
    });

    test('empty pain_intensity → null painIntensity, painEnabled false', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,0,,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows.first.log.painIntensity, isNull);
      expect(result.rows.first.log.painEnabled, isFalse);
    });

    test('non-empty pain_intensity → painEnabled true', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,0,,2,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.painIntensity, 2);
      expect(result.rows.first.log.painEnabled, isTrue);
    });

    test('non-empty symptoms → painEnabled true', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,0,,,headache,,0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.painEnabled, isTrue);
    });

    test('non-empty notes → notesEnabled true', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,0,,,,hello,0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.notesEnabled, isTrue);
      expect(result.rows.first.log.notes, 'hello');
    });

    test('unknown symptom name silently skipped (forward-compat)', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,0,,,unknownFutureSymptom,,0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.symptoms, isEmpty);
      // BUG-010: all tokens unknown → painEnabled must NOT be forced true.
      expect(result.rows.first.log.painEnabled, isFalse);
    });
  });

  // ── Decode — parse errors ───────────────────────────────────────────────────

  group('decode — parse errors', () {
    test('missing date → CsvParseError with column: date', () {
      const csv = '$kHeader\r\n'
          ',0,,,,, \r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.column, 'date');
      expect(result.errors.first.rowNumber, 2);
    });

    test('malformed date → CsvParseError with column: date', () {
      const csv = '$kHeader\r\n'
          'not-a-date,0,,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'date');
    });

    test('overflow date 2026-02-30 → CsvParseError', () {
      const csv = '$kHeader\r\n'
          '2026-02-30,0,,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'date');
    });

    test('empty flow_type when flow_type column is present → CsvParseError',
        () {
      const csv = '$kHeader\r\n'
          '2026-03-01,,,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'flow_type');
    });

    test('unknown flow_type value → CsvParseError with column: flow_type', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,9,,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'flow_type');
    });

    test('unknown flow value → CsvParseError with column: flow', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,1,9,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'flow');
    });

    test('pain_intensity out of range → CsvParseError', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,0,,5,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'pain_intensity');
    });

    test('CSV missing both flow_type and spotting → error per data row', () {
      const csv = 'date,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,,0\r\n'
          '2026-03-02,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.length, greaterThanOrEqualTo(2));
      for (final e in result.errors) {
        expect(e.column, 'flow_type');
      }
    });

    test('valid and invalid rows: valid rows included, invalid excluded', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,0,,,,,0\r\n' // valid
          'bad-date,0,,,,,0\r\n' // invalid date
          '2026-03-03,0,,,,,0\r\n'; // valid
      final result = codec.decode(csv);
      expect(result.rows, hasLength(2));
      expect(result.errors, hasLength(1));
    });
  });

  // ── Decode — legacy CSV backward-compatibility ──────────────────────────────

  group('decode — legacy CSV backward-compatibility', () {
    test('legacy spotting column derives flowType correctly', () {
      // spotting=1 → FlowType.spotting
      // spotting=0, flow v3=0 → FlowType.assente
      // spotting=0, flow v3=2 → FlowType.mestruazioni + FlowIntensity.medium
      const csv =
          'date,flow,spotting,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-01-01,0,1,,,, 0\r\n'
          '2026-01-02,0,0,,,, 0\r\n'
          '2026-01-03,2,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(3));

      expect(result.rows[0].log.flowType, FlowType.spotting);
      expect(result.rows[0].log.flowIntensity, isNull);

      expect(result.rows[1].log.flowType, FlowType.assente);
      expect(result.rows[1].log.flowIntensity, isNull);

      expect(result.rows[2].log.flowType, FlowType.mestruazioni);
      expect(result.rows[2].log.flowIntensity, FlowIntensity.medium);
    });

    test('legacy veryHeavy v3 index 4 maps to FlowIntensity.veryHeavy', () {
      const csv =
          'date,flow,spotting,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-01-01,4,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.flowType, FlowType.mestruazioni);
      expect(result.rows.first.log.flowIntensity, FlowIntensity.veryHeavy);
    });

    test(
        'old CSV with other_discharge, pain_enabled, notes_enabled columns '
        'decodes without errors (extra columns silently ignored)', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,'
          'cycle_start,pain_enabled,notes_enabled\r\n'
          '2026-03-01,0,,0,,,, 0,0,0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      expect(result.rows.first.log.flowType, FlowType.assente);
    });

    test(
        'legacy `cramps` symptom token decodes as custom-label "Crampi" '
        '(v0.1 enum was removed in v0.2)', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,1,1,,cramps,,0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      expect(result.rows.first.symptoms, hasLength(1));
      final s = result.rows.first.symptoms.first;
      expect(s.symptomType, PainSymptomType.custom);
      expect(s.customLabel, 'Crampi');
    });

    test(
        'legacy `cramps` mixed with current symptom names: cramps becomes '
        'custom, others decode normally', () {
      const csv = '$kHeader\r\n'
          '2026-03-01,1,1,,cramps;backPain;headache,,0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      expect(result.rows.first.symptoms, hasLength(3));
      final types = result.rows.first.symptoms.map((s) => s.symptomType);
      expect(
        types,
        containsAll([
          PainSymptomType.custom,
          PainSymptomType.backPain,
          PainSymptomType.headache,
        ]),
      );
      // The custom one carries the legacy label.
      final custom = result.rows.first.symptoms
          .firstWhere((s) => s.symptomType == PainSymptomType.custom);
      expect(custom.customLabel, 'Crampi');
    });
  });
}
