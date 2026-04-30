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

  // Helper to build a minimal valid DailyLogRow.
  DailyLogRow row({
    required DateTime date,
    FlowType? flowType,
    FlowIntensity? flow,
    bool otherDischarge = false,
    bool painEnabled = false,
    int? painIntensity,
    bool notesEnabled = false,
    String? notes,
    List<PainSymptomData> symptoms = const [],
    bool cycleStart = false,
  }) =>
      DailyLogRow(
        log: DailyLogEntity(
          date: date,
          flowType: flowType,
          flowIntensity: flow,
          otherDischarge: otherDischarge,
          painEnabled: painEnabled,
          painIntensity: painIntensity,
          notesEnabled: notesEnabled,
          notes: notes,
        ),
        symptoms: symptoms,
        cycleStart: cycleStart,
      );

  String normalizedFirstLine(String csv) =>
      csv.replaceAll('\r\n', '\n').split('\n').first;

  group('encode — header', () {
    test('empty rows produces correct header', () {
      final csv = codec.encode([]);
      expect(
        normalizedFirstLine(csv),
        'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start',
      );
    });
  });

  group('encode — field values', () {
    test('null flowType encodes flow_type as empty', () {
      final csv = codec.encode([row(date: DateTime.utc(2026, 3, 1))]);
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      // date,<empty>,<empty>,0,<empty>,<empty>,<empty>,0
      expect(dataLine.split(',')[1], '');
    });

    test('FlowType.assente encodes flow_type as 0, flow as empty', () {
      final csv = codec.encode(
        [row(date: DateTime.utc(2026, 3, 1), flowType: FlowType.assente)],
      );
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',')[1], '0'); // flow_type index
      expect(dataLine.split(',')[2], ''); // flow empty (not mestruazioni)
    });

    test('FlowIntensity.veryHeavy encodes as 3', () {
      final csv = codec.encode(
        [
          row(
            date: DateTime.utc(2026, 3, 1),
            flowType: FlowType.mestruazioni,
            flow: FlowIntensity.veryHeavy,
          ),
        ],
      );
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',')[2], '3'); // flow column, v4 index
    });

    test('FlowType.spotting encodes flow_type as 2', () {
      final csv = codec.encode(
        [row(date: DateTime.utc(2026, 3, 1), flowType: FlowType.spotting)],
      );
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',')[1], '2'); // flow_type index for spotting
    });

    test('cycleStart=true encodes as 1 in last column', () {
      final csv =
          codec.encode([row(date: DateTime.utc(2026, 3, 1), cycleStart: true)]);
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',').last, '1');
    });

    test('cycle_start column is present even when false', () {
      final csv = codec
          .encode([row(date: DateTime.utc(2026, 3, 1), cycleStart: false)]);
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',').last, '0');
    });
  });

  group('encode — symptoms', () {
    test('built-in symptoms encoded as semicolon-joined names', () {
      final csv = codec.encode([
        row(
          date: DateTime.utc(2026, 3, 1),
          symptoms: [
            const PainSymptomData(symptomType: PainSymptomType.cramps),
            const PainSymptomData(symptomType: PainSymptomType.backPain),
          ],
        ),
      ]);
      expect(csv, contains('cramps;backPain'));
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

  group('decode — header-only (empty export)', () {
    test('header-only CSV → zero rows, zero errors', () {
      final csv = codec.encode([]);
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors, isEmpty);
    });
  });

  group('round-trip', () {
    test('full row with all fields survives encode → decode', () {
      final original = row(
        date: DateTime.utc(2026, 3, 15),
        flowType: FlowType.mestruazioni,
        flow: FlowIntensity.medium,
        otherDischarge: true,
        painEnabled: true,
        painIntensity: 2,
        notesEnabled: true,
        notes: 'some note with, a comma',
        symptoms: [
          const PainSymptomData(symptomType: PainSymptomType.cramps),
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
      expect(decoded.log.otherDischarge, isTrue);
      expect(decoded.log.painIntensity, 2);
      expect(decoded.log.painEnabled, isTrue);
      expect(decoded.log.notes, 'some note with, a comma');
      expect(decoded.log.notesEnabled, isTrue);
      expect(decoded.symptoms, hasLength(2));
      expect(decoded.symptoms.first.symptomType, PainSymptomType.cramps);
      expect(decoded.symptoms.last.symptomType, PainSymptomType.custom);
      expect(decoded.symptoms.last.customLabel, 'Nausea');
    });

    test('cycle_start column is ignored on decode (not mapped to DailyLogRow)',
        () {
      final r = row(date: DateTime.utc(2026, 4, 1), cycleStart: true);
      final result = codec.decode(codec.encode([r]));
      expect(result.errors, isEmpty);
      // cycleStart is export-only — decoded rows always have cycleStart==false
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
        row(date: DateTime.utc(2026, 1, 3)),
      ];
      final result = codec.decode(codec.encode(rows));
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(3));
    });

    test('notes with newlines survive round-trip', () {
      final r = row(
        date: DateTime.utc(2026, 5, 1),
        notes: 'line one\nline two',
        notesEnabled: true,
      );
      final result = codec.decode(codec.encode([r]));
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.notes, 'line one\nline two');
    });
  });

  group('decode — field parsing', () {
    test('empty flow_type field → null flowType', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.flowType, isNull);
    });

    test('empty flow field → null flowIntensity', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,1,,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.flowIntensity, isNull);
    });

    test('empty pain_intensity → null painIntensity, painEnabled false', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows.first.log.painIntensity, isNull);
      expect(result.rows.first.log.painEnabled, isFalse);
    });

    test('non-empty pain_intensity → painEnabled true', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,0,2,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.painIntensity, 2);
      expect(result.rows.first.log.painEnabled, isTrue);
    });

    test('non-empty symptoms → painEnabled true', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,0,,cramps,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.painEnabled, isTrue);
    });

    test('non-empty notes → notesEnabled true', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,0,,,hello, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.notesEnabled, isTrue);
      expect(result.rows.first.log.notes, 'hello');
    });

    test('unknown symptom name silently skipped (forward-compat)', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,0,,unknownFutureSymptom,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.symptoms, isEmpty);
    });
  });

  group('decode — parse errors', () {
    test('missing date → CsvParseError with column: date', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          ',,,,,,,\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.column, 'date');
      expect(result.errors.first.rowNumber, 2);
    });

    test('malformed date → CsvParseError with column: date', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          'not-a-date,,,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'date');
    });

    test('overflow date 2026-02-30 → CsvParseError', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-02-30,,,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'date');
    });

    test('unknown flow_type value → CsvParseError with column: flow_type', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,9,,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'flow_type');
    });

    test('unknown flow value → CsvParseError with column: flow', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,1,9,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'flow');
    });

    test('pain_intensity out of range → CsvParseError', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,0,5,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'pain_intensity');
    });

    test(
        'given_header_with_neither_flow_type_nor_spotting_when_decode_then_error_per_data_row',
        () {
      // CSV missing both flow_type and spotting columns.
      const csv =
          'date,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,0,,,,0\r\n'
          '2026-03-02,0,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      // 2 data rows, 1 error each for missing flow_type/spotting
      expect(result.errors.length, greaterThanOrEqualTo(2));
      for (final e in result.errors) {
        expect(e.column, 'flow_type');
      }
    });

    test('valid and invalid rows: valid rows included, invalid excluded', () {
      const csv =
          'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,,0,,,, 0\r\n' // valid
          'bad-date,,,0,,,, 0\r\n' // invalid date
          '2026-03-03,,,0,,,, 0\r\n'; // valid
      final result = codec.decode(csv);
      expect(result.rows, hasLength(2));
      expect(result.errors, hasLength(1));
    });
  });

  group('decode — legacy CSV backward-compatibility', () {
    test(
        'given_legacy_csv_with_spotting_column_when_decode_then_flowType_derived_correctly',
        () {
      // spotting=1 → FlowType.spotting; flow v3=0 → irrelevant when spotting
      // spotting=0, flow v3=0 → FlowType.assente
      // spotting=0, flow v3=2 → FlowType.mestruazioni + FlowIntensity.medium
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-01-01,0,1,0,,,, 0\r\n' // spotting day
          '2026-01-02,0,0,0,,,, 0\r\n' // assente
          '2026-01-03,2,0,0,,,, 0\r\n'; // mestruazioni medium
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(3));

      final spottingRow = result.rows[0];
      expect(spottingRow.log.flowType, FlowType.spotting);
      expect(spottingRow.log.flowIntensity, isNull);

      final assenteRow = result.rows[1];
      expect(assenteRow.log.flowType, FlowType.assente);
      expect(assenteRow.log.flowIntensity, isNull);

      final mestruazioniRow = result.rows[2];
      expect(mestruazioniRow.log.flowType, FlowType.mestruazioni);
      expect(mestruazioniRow.log.flowIntensity, FlowIntensity.medium);
    });

    test(
        'given_legacy_csv_with_spotting_column_when_veryHeavy_v3_index_4_then_maps_to_veryHeavy',
        () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-01-01,4,0,0,,,, 0\r\n'; // v3 index 4 = veryHeavy
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.flowType, FlowType.mestruazioni);
      expect(result.rows.first.log.flowIntensity, FlowIntensity.veryHeavy);
    });
  });
}
