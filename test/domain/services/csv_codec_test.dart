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
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/services/csv_codec.dart';

void main() {
  const codec = CsvCodec();

  // Helper to build a minimal valid DailyLogRow.
  DailyLogRow row({
    required DateTime date,
    FlowIntensity? flow,
    bool spotting = false,
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
          flowIntensity: flow,
          spotting: spotting,
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
        'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start',
      );
    });
  });

  group('encode — field values', () {
    test('null flow encodes as empty', () {
      final csv = codec.encode([row(date: DateTime.utc(2026, 3, 1))]);
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      // date,<empty>,0,0,<empty>,<empty>,<empty>,0
      expect(dataLine.split(',')[1], '');
    });

    test('FlowIntensity.none encodes as 0', () {
      final csv = codec
          .encode([row(date: DateTime.utc(2026, 3, 1), flow: FlowIntensity.none)]);
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',')[1], '0');
    });

    test('FlowIntensity.veryHeavy encodes as 4', () {
      final csv = codec.encode(
          [row(date: DateTime.utc(2026, 3, 1), flow: FlowIntensity.veryHeavy)]);
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',')[1], '4');
    });

    test('spotting=true encodes as 1', () {
      final csv =
          codec.encode([row(date: DateTime.utc(2026, 3, 1), spotting: true)]);
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',')[2], '1');
    });

    test('cycleStart=true encodes as 1 in last column', () {
      final csv = codec
          .encode([row(date: DateTime.utc(2026, 3, 1), cycleStart: true)]);
      final dataLine = csv.replaceAll('\r\n', '\n').split('\n')[1];
      expect(dataLine.split(',').last, '1');
    });

    test('cycle_start column is present even when false', () {
      final csv =
          codec.encode([row(date: DateTime.utc(2026, 3, 1), cycleStart: false)]);
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
            PainSymptomData(symptomType: PainSymptomType.cramps),
            PainSymptomData(symptomType: PainSymptomType.backPain),
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
            PainSymptomData(
                symptomType: PainSymptomType.custom, customLabel: 'Nausea'),
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
        flow: FlowIntensity.medium,
        spotting: false,
        otherDischarge: true,
        painEnabled: true,
        painIntensity: 2,
        notesEnabled: true,
        notes: 'some note with, a comma',
        symptoms: [
          PainSymptomData(symptomType: PainSymptomType.cramps),
          PainSymptomData(
              symptomType: PainSymptomType.custom, customLabel: 'Nausea'),
        ],
        cycleStart: true,
      );

      final result = codec.decode(codec.encode([original]));

      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      final decoded = result.rows.first;
      expect(decoded.log.date, DateTime.utc(2026, 3, 15));
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

    test('cycle_start column is ignored on decode (not mapped to DailyLogRow)', () {
      final r = row(date: DateTime.utc(2026, 4, 1), cycleStart: true);
      final result = codec.decode(codec.encode([r]));
      expect(result.errors, isEmpty);
      // cycleStart is export-only — decoded rows always have cycleStart==false
      expect(result.rows.first.cycleStart, isFalse);
    });

    test('multiple rows survive round-trip', () {
      final rows = [
        row(date: DateTime.utc(2026, 1, 1), flow: FlowIntensity.light),
        row(date: DateTime.utc(2026, 1, 2), flow: FlowIntensity.heavy),
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
    test('empty flow field → null flowIntensity', () {
      // Manually build a CSV with empty flow
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,0,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.flowIntensity, isNull);
    });

    test('empty pain_intensity → null painIntensity, painEnabled false', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,0,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows.first.log.painIntensity, isNull);
      expect(result.rows.first.log.painEnabled, isFalse);
    });

    test('non-empty pain_intensity → painEnabled true', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,0,0,2,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.painIntensity, 2);
      expect(result.rows.first.log.painEnabled, isTrue);
    });

    test('non-empty symptoms → painEnabled true', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,0,0,,cramps,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.painEnabled, isTrue);
    });

    test('non-empty notes → notesEnabled true', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,0,0,,,hello, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.log.notesEnabled, isTrue);
      expect(result.rows.first.log.notes, 'hello');
    });

    test('unknown symptom name silently skipped (forward-compat)', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,0,0,,unknownFutureSymptom,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.errors, isEmpty);
      expect(result.rows.first.symptoms, isEmpty);
    });
  });

  group('decode — parse errors', () {
    test('missing date → CsvParseError with column: date', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          ',,,,,,,\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.column, 'date');
      expect(result.errors.first.rowNumber, 2);
    });

    test('malformed date → CsvParseError with column: date', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          'not-a-date,,0,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'date');
    });

    test('overflow date 2026-02-30 → CsvParseError', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-02-30,,0,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'date');
    });

    test('unknown flow value → CsvParseError with column: flow', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,9,0,0,,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'flow');
    });

    test('pain_intensity out of range → CsvParseError', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,0,0,5,,, 0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      expect(result.errors.first.column, 'pain_intensity');
    });

    test('missing required column → CsvParseError for every data row', () {
      // CSV missing the "flow" column
      const csv =
          'date,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,0,0,,,,0\r\n'
          '2026-03-02,0,0,,,,0\r\n';
      final result = codec.decode(csv);
      expect(result.rows, isEmpty);
      // 2 data rows × 1 missing column = at least 2 errors
      expect(result.errors.length, greaterThanOrEqualTo(2));
      for (final e in result.errors) {
        expect(e.column, 'flow');
      }
    });

    test('valid and invalid rows: valid rows included, invalid excluded', () {
      const csv =
          'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start\r\n'
          '2026-03-01,,0,0,,,, 0\r\n'     // valid
          'bad-date,,0,0,,,, 0\r\n'       // invalid date
          '2026-03-03,,0,0,,,, 0\r\n';    // valid
      final result = codec.decode(csv);
      expect(result.rows, hasLength(2));
      expect(result.errors, hasLength(1));
    });
  });
}
