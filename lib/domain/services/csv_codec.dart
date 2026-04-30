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

import 'package:csv/csv.dart';

import '../entities/daily_log_entity.dart';
import '../entities/flow_intensity.dart';
import '../entities/flow_type.dart';
import '../entities/pain_symptom_data.dart';
import '../entities/pain_symptom_type.dart';

class DailyLogRow {
  const DailyLogRow({
    required this.log,
    required this.symptoms,
    this.cycleStart = false,
  });

  final DailyLogEntity log;
  final List<PainSymptomData> symptoms;

  /// Populated on encode from CycleEntry.startDate; always false on decode
  /// (cycle_start column is export-only).
  final bool cycleStart;
}

class CsvParseError {
  const CsvParseError({
    required this.rowNumber,
    required this.column,
    required this.rawValue,
    required this.reason,
  });

  final int rowNumber;
  final String column;
  final String rawValue;
  final String reason;
}

class CsvDecodeResult {
  const CsvDecodeResult({required this.rows, required this.errors});

  final List<DailyLogRow> rows;
  final List<CsvParseError> errors;
}

// New format (schema v4): flow_type is FlowType index (0-2); flow is
// FlowIntensity index (0-3), only meaningful when flowType==mestruazioni.
const _kHeaders = [
  'date',
  'flow_type',
  'flow',
  'other_discharge',
  'pain_intensity',
  'symptoms',
  'notes',
  'cycle_start',
];

// flow_type and flow are excluded from required headers so legacy CSVs
// (which have a `spotting` column instead) still decode without error.
const _kRequiredHeaders = [
  'date',
  'other_discharge',
  'pain_intensity',
  'symptoms',
  'notes',
];

class CsvCodec {
  const CsvCodec();

  // ── Encode ──────────────────────────────────────────────────────────────────

  String encode(List<DailyLogRow> rows) {
    final data = <List<dynamic>>[
      _kHeaders,
      for (final r in rows)
        [
          _fmtDate(r.log.date),
          r.log.flowType?.index ?? '',      // flow_type column
          r.log.flowIntensity?.index ?? '', // flow column
          r.log.otherDischarge ? 1 : 0,
          r.log.painIntensity ?? '',
          _encodeSymptoms(r.symptoms),
          r.log.notes ?? '',
          r.cycleStart ? 1 : 0,
        ],
    ];
    return const ListToCsvConverter().convert(data);
  }

  static String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _encodeSymptoms(List<PainSymptomData> symptoms) {
    if (symptoms.isEmpty) return '';
    return symptoms.map((s) {
      if (s.symptomType == PainSymptomType.custom) {
        return 'custom:${s.customLabel ?? ''}';
      }
      return s.symptomType.name;
    }).join(';');
  }

  // ── Decode ──────────────────────────────────────────────────────────────────

  CsvDecodeResult decode(String csv) {
    final normalized =
        csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trimRight();
    if (normalized.isEmpty) {
      return const CsvDecodeResult(rows: [], errors: []);
    }

    List<List<dynamic>> rawRows;
    try {
      rawRows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(normalized);
    } catch (_) {
      return const CsvDecodeResult(rows: [], errors: []);
    }

    if (rawRows.isEmpty) {
      return const CsvDecodeResult(rows: [], errors: []);
    }

    final header =
        rawRows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    // Check all required columns are present.
    final missing =
        _kRequiredHeaders.where((h) => !header.contains(h)).toList();
    if (missing.isNotEmpty) {
      final dataCount = rawRows.length - 1;
      final errors = <CsvParseError>[];
      for (var i = 1; i <= dataCount; i++) {
        for (final col in missing) {
          errors.add(
            CsvParseError(
              rowNumber: i + 1,
              column: col,
              rawValue: '',
              reason: 'Required column "$col" missing from header',
            ),
          );
        }
      }
      return CsvDecodeResult(rows: const [], errors: errors);
    }

    // Determine which flow format this CSV uses.
    // Prefer new format (flow_type) over legacy (spotting).
    final hasFlowType = header.contains('flow_type');
    final hasSpotting = header.contains('spotting');

    String cell(List<dynamic> rawRow, String col) {
      final idx = header.indexOf(col);
      if (idx < 0 || idx >= rawRow.length) return '';
      return rawRow[idx].toString().trim();
    }

    final rows = <DailyLogRow>[];
    final errors = <CsvParseError>[];

    for (var i = 1; i < rawRows.length; i++) {
      final rowNum = i + 1;
      final rawRow = rawRows[i];

      // Skip zero-length trailing rows the csv package may produce after a
      // final newline; do NOT skip rows where the date column is just empty —
      // those must produce a CsvParseError.
      if (rawRow.isEmpty) continue;

      // date
      final dateStr = cell(rawRow, 'date');
      if (dateStr.isEmpty) {
        errors.add(
          CsvParseError(
            rowNumber: rowNum,
            column: 'date',
            rawValue: dateStr,
            reason: 'Date is required',
          ),
        );
        continue;
      }
      final parsed = DateTime.tryParse(dateStr);
      DateTime? utcDate;
      if (parsed != null) {
        utcDate = DateTime.utc(parsed.year, parsed.month, parsed.day);
        if (_fmtDate(utcDate) != dateStr) utcDate = null;
      }
      if (utcDate == null) {
        errors.add(
          CsvParseError(
            rowNumber: rowNum,
            column: 'date',
            rawValue: dateStr,
            reason: 'Expected YYYY-MM-DD',
          ),
        );
        continue;
      }

      // flow_type / spotting + flow — branch on CSV format.
      FlowType? flowType;
      FlowIntensity? flowIntensity;

      if (hasFlowType) {
        // New format: flow_type is FlowType index (0-2).
        final ftStr = cell(rawRow, 'flow_type');
        if (ftStr.isNotEmpty) {
          final idx = int.tryParse(ftStr);
          if (idx == null || idx < 0 || idx >= FlowType.values.length) {
            errors.add(
              CsvParseError(
                rowNumber: rowNum,
                column: 'flow_type',
                rawValue: ftStr,
                reason: 'Expected 0–${FlowType.values.length - 1} or empty',
              ),
            );
            continue;
          }
          flowType = FlowType.values[idx];
        }

        // flow is FlowIntensity v4 index (0-3).
        final flowStr = cell(rawRow, 'flow');
        if (flowStr.isNotEmpty) {
          final idx = int.tryParse(flowStr);
          if (idx == null || idx < 0 || idx >= FlowIntensity.values.length) {
            errors.add(
              CsvParseError(
                rowNumber: rowNum,
                column: 'flow',
                rawValue: flowStr,
                reason: 'Expected 0–${FlowIntensity.values.length - 1} or empty',
              ),
            );
            continue;
          }
          flowIntensity = FlowIntensity.values[idx];
        }
      } else if (hasSpotting) {
        // Legacy format: spotting is 0/1; flow is v3 index (0-4 where 0=none).
        final spStr = cell(rawRow, 'spotting');
        final spVal = int.tryParse(spStr);
        if (spVal == null || (spVal != 0 && spVal != 1)) {
          errors.add(
            CsvParseError(
              rowNumber: rowNum,
              column: 'spotting',
              rawValue: spStr,
              reason: 'Expected 0 or 1',
            ),
          );
          continue;
        }

        // v3 flow: 0=none, 1=light, 2=medium, 3=heavy, 4=veryHeavy.
        final flowStr = cell(rawRow, 'flow');
        int flowV3 = 0;
        if (flowStr.isNotEmpty) {
          final idx = int.tryParse(flowStr);
          if (idx == null || idx < 0 || idx > 4) {
            errors.add(
              CsvParseError(
                rowNumber: rowNum,
                column: 'flow',
                rawValue: flowStr,
                reason: 'Expected 0–4 or empty',
              ),
            );
            continue;
          }
          flowV3 = idx;
        }

        // Derive flowType and flowIntensity from legacy values.
        if (spVal == 1) {
          flowType = FlowType.spotting;
        } else if (flowV3 == 0) {
          flowType = FlowType.assente;
        } else {
          flowType = FlowType.mestruazioni;
          // v3 index 1-4 → v4 index 0-3 (subtract 1).
          flowIntensity = FlowIntensity.values[flowV3 - 1];
        }
      } else {
        // Neither flow_type nor spotting column present — critical data missing.
        errors.add(
          CsvParseError(
            rowNumber: rowNum,
            column: 'flow_type',
            rawValue: '',
            reason: 'Required column "flow_type" or legacy "spotting" missing from header',
          ),
        );
        continue;
      }

      // other_discharge
      final odStr = cell(rawRow, 'other_discharge');
      final odVal = int.tryParse(odStr);
      if (odVal == null || (odVal != 0 && odVal != 1)) {
        errors.add(
          CsvParseError(
            rowNumber: rowNum,
            column: 'other_discharge',
            rawValue: odStr,
            reason: 'Expected 0 or 1',
          ),
        );
        continue;
      }

      // pain_intensity
      int? painIntensity;
      var painEnabled = false;
      final painStr = cell(rawRow, 'pain_intensity');
      if (painStr.isNotEmpty) {
        final pv = int.tryParse(painStr);
        if (pv == null || pv < 1 || pv > 3) {
          errors.add(
            CsvParseError(
              rowNumber: rowNum,
              column: 'pain_intensity',
              rawValue: painStr,
              reason: 'Expected 1–3 or empty',
            ),
          );
          continue;
        }
        painIntensity = pv;
        painEnabled = true;
      }

      // symptoms
      final symptoms = <PainSymptomData>[];
      final sympStr = cell(rawRow, 'symptoms');
      if (sympStr.isNotEmpty) {
        painEnabled = true;
        for (final part in sympStr.split(';')) {
          final t = part.trim();
          if (t.isEmpty) continue;
          if (t.startsWith('custom:')) {
            symptoms.add(
              PainSymptomData(
                symptomType: PainSymptomType.custom,
                customLabel: t.substring('custom:'.length),
              ),
            );
          } else {
            try {
              final type =
                  PainSymptomType.values.firstWhere((v) => v.name == t);
              symptoms.add(PainSymptomData(symptomType: type));
            } catch (_) {
              // Unknown symptom name: silently skip for forward-compatibility.
            }
          }
        }
      }

      // notes
      var notesEnabled = false;
      String? notes;
      final notesStr = cell(rawRow, 'notes');
      if (notesStr.isNotEmpty) {
        notes = notesStr;
        notesEnabled = true;
      }

      // cycle_start is ignored on decode.

      rows.add(
        DailyLogRow(
          log: DailyLogEntity(
            date: utcDate,
            flowType: flowType,
            flowIntensity: flowIntensity,
            otherDischarge: odVal == 1,
            painEnabled: painEnabled,
            painIntensity: painIntensity,
            notesEnabled: notesEnabled,
            notes: notes,
          ),
          symptoms: symptoms,
        ),
      );
    }

    return CsvDecodeResult(rows: rows, errors: errors);
  }
}
