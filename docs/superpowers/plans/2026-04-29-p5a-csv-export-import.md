# P-5a CSV Export / Import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full CSV export (share sheet) and import (three conflict-resolution modes) of daily logs with symptoms, wired into the Settings screen.

**Architecture:** Pure `CsvCodec` in `domain/services/` handles encode/decode. `ExportDailyLogs` and `ImportDailyLogs` use cases in `domain/use_cases/` orchestrate data. Settings screen handles `share_plus`, `file_picker`, privacy warning, error dialog, and mode picker. A new `deleteAllAndReplace` transactional method is added to `DailyLogRepository` to guarantee atomic delete+re-insert in `deleteAndImport` mode.

**Tech Stack:** `csv: ^6.0.0`, `share_plus: ^10.0.2`, `file_picker: ^8.1.2`, `path_provider` (already in project), Drift transactions, Riverpod FutureProvider.

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Create | `lib/domain/services/csv_codec.dart` | `CsvCodec`, `DailyLogRow`, `CsvParseError`, `CsvDecodeResult` |
| Create | `lib/domain/use_cases/export_daily_logs.dart` | `ExportDailyLogs` — fetches logs + symptoms, returns CSV string |
| Create | `lib/domain/use_cases/import_daily_logs.dart` | `ImportDailyLogs`, `ImportMode`, `ImportResult` |
| Create | `test/domain/services/csv_codec_test.dart` | Unit tests for CsvCodec |
| Create | `test/domain/use_cases/export_daily_logs_test.dart` | Unit tests for ExportDailyLogs |
| Create | `test/domain/use_cases/import_daily_logs_test.dart` | Unit tests for ImportDailyLogs |
| Modify | `pubspec.yaml` | Uncomment 3 packages |
| Modify | `lib/l10n/app_en.arb` + `app_it.arb` | 12 new CSV l10n keys |
| Modify | `lib/domain/repositories/daily_log_repository.dart` | Add `deleteAllAndReplace` |
| Modify | `lib/data/repositories/drift_daily_log_repository.dart` | Implement `deleteAllAndReplace` with Drift transaction |
| Modify | `test/helpers/fake_daily_log_repository.dart` | Implement `deleteAllAndReplace` |
| Modify | `lib/providers/use_case_providers.dart` | Add `exportDailyLogsProvider`, `importDailyLogsProvider` |
| Modify | `lib/domain/use_cases/schedule_prediction_notification.dart` | Clamp `notificationDaysBefore` to 1–7 (P-4 appsec LOW) |
| Modify | `lib/features/settings/settings_screen.dart` | Wire Export + Import buttons |
| Modify | `test/features/settings/settings_screen_test.dart` | Add CSV button widget tests |

> **Note on placement:** `CsvCodec` is placed in `domain/services/` (not `data/services/` as the spec suggests) because it is pure Dart with no platform/IO imports, and `domain/use_cases/` cannot import from `data/`. This follows the same pattern as `CyclePredictionService`.

---

## T1: Enable dependencies

**Files:** `pubspec.yaml`

- [ ] In `pubspec.yaml`, uncomment the three lines under `# Export/share (added in P-5)`:

```yaml
  # Export/share (added in P-5)
  file_picker: ^8.1.2
  share_plus: ^10.0.2
  csv: ^6.0.0
```

- [ ] Run `flutter pub get` and confirm it exits 0.

- [ ] Run `flutter analyze` — must exit 0.

- [ ] Commit:
```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): enable file_picker, share_plus, csv for P-5a"
```

---

## T2: L10n keys

**Files:** `lib/l10n/app_en.arb`, `lib/l10n/app_it.arb`

- [ ] In `app_en.arb`, add these entries **before the closing `}`** (after the last existing key):

```json
  "settings_import_csv": "Import CSV",
  "@settings_import_csv": {
    "description": "Settings action to import data from a CSV file"
  },

  "csv_export_privacy_warning": "This file contains your health data in plain text. Only share with apps or people you trust.",
  "@csv_export_privacy_warning": {
    "description": "Privacy warning shown before sharing the CSV export"
  },

  "csv_export_privacy_confirm": "Continue",
  "@csv_export_privacy_confirm": {
    "description": "Confirm button on the CSV export privacy warning"
  },

  "csv_import_errors_dialog": "Found {count} rows with invalid data.",
  "@csv_import_errors_dialog": {
    "description": "Body of the dialog shown when the CSV has parse errors",
    "placeholders": {
      "count": { "type": "int" }
    }
  },

  "csv_import_abort": "Abort",
  "@csv_import_abort": {
    "description": "Button to abort the import when parse errors are found"
  },

  "csv_import_skip_continue": "Skip & Continue",
  "@csv_import_skip_continue": {
    "description": "Button to skip invalid rows and continue the import"
  },

  "csv_import_mode_title": "Import mode",
  "@csv_import_mode_title": {
    "description": "Title of the import mode picker dialog"
  },

  "csv_import_mode_delete": "Delete all data and import",
  "@csv_import_mode_delete": {
    "description": "Import mode: delete all existing data, then import"
  },

  "csv_import_mode_overwrite": "Import and overwrite",
  "@csv_import_mode_overwrite": {
    "description": "Import mode: upsert CSV rows, DB-only rows untouched"
  },

  "csv_import_mode_keep": "Import, keep existing",
  "@csv_import_mode_keep": {
    "description": "Import mode: insert only dates absent from DB"
  },

  "csv_import_success": "Imported {count} rows",
  "@csv_import_success": {
    "description": "Snackbar shown after a successful import with no skips",
    "placeholders": {
      "count": { "type": "int" }
    }
  },

  "csv_import_success_skipped": "Imported {count} rows, skipped {skipped}",
  "@csv_import_success_skipped": {
    "description": "Snackbar shown after a successful import where some rows were skipped",
    "placeholders": {
      "count": { "type": "int" },
      "skipped": { "type": "int" }
    }
  }
```

- [ ] In `app_it.arb`, add these entries **before the closing `}`**:

```json
  "settings_import_csv": "Importa CSV",
  "@settings_import_csv": {
    "description": "Settings action to import data from a CSV file"
  },

  "csv_export_privacy_warning": "Questo file contiene dati sanitari in chiaro. Condividilo solo con app o persone di cui ti fidi.",
  "@csv_export_privacy_warning": {
    "description": "Privacy warning shown before sharing the CSV export"
  },

  "csv_export_privacy_confirm": "Continua",
  "@csv_export_privacy_confirm": {
    "description": "Confirm button on the CSV export privacy warning"
  },

  "csv_import_errors_dialog": "Trovate {count} righe con dati non validi.",
  "@csv_import_errors_dialog": {
    "description": "Body of the dialog shown when the CSV has parse errors",
    "placeholders": {
      "count": { "type": "int" }
    }
  },

  "csv_import_abort": "Annulla importazione",
  "@csv_import_abort": {
    "description": "Button to abort the import when parse errors are found"
  },

  "csv_import_skip_continue": "Salta e continua",
  "@csv_import_skip_continue": {
    "description": "Button to skip invalid rows and continue the import"
  },

  "csv_import_mode_title": "Modalità importazione",
  "@csv_import_mode_title": {
    "description": "Title of the import mode picker dialog"
  },

  "csv_import_mode_delete": "Elimina tutto e importa",
  "@csv_import_mode_delete": {
    "description": "Import mode: delete all existing data, then import"
  },

  "csv_import_mode_overwrite": "Importa e sovrascrivi",
  "@csv_import_mode_overwrite": {
    "description": "Import mode: upsert CSV rows, DB-only rows untouched"
  },

  "csv_import_mode_keep": "Importa, mantieni esistenti",
  "@csv_import_mode_keep": {
    "description": "Import mode: insert only dates absent from DB"
  },

  "csv_import_success": "Importate {count} righe",
  "@csv_import_success": {
    "description": "Snackbar shown after a successful import with no skips",
    "placeholders": {
      "count": { "type": "int" }
    }
  },

  "csv_import_success_skipped": "Importate {count} righe, saltate {skipped}",
  "@csv_import_success_skipped": {
    "description": "Snackbar shown after a successful import where some rows were skipped",
    "placeholders": {
      "count": { "type": "int" },
      "skipped": { "type": "int" }
    }
  }
```

- [ ] Run `flutter gen-l10n`. Confirm it exits 0 and regenerates `lib/l10n/app_localizations*.dart`.

- [ ] Run `flutter analyze` — must exit 0.

- [ ] Commit:
```bash
git add lib/l10n/
git commit -m "feat(l10n): add CSV export/import string keys"
```

---

## T3: CsvCodec (TDD)

**Files:**
- Create: `lib/domain/services/csv_codec.dart`
- Create: `test/domain/services/csv_codec_test.dart`

### Step 1 — Write the tests first

- [ ] Create `test/domain/services/csv_codec_test.dart` with the full content below:

```dart
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
```

- [ ] Run `flutter test test/domain/services/csv_codec_test.dart` — should **FAIL** (file not found).

### Step 2 — Implement CsvCodec

- [ ] Create `lib/domain/services/csv_codec.dart`:

```dart
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

const _kHeaders = [
  'date',
  'flow',
  'spotting',
  'other_discharge',
  'pain_intensity',
  'symptoms',
  'notes',
  'cycle_start',
];

const _kRequiredHeaders = [
  'date',
  'flow',
  'spotting',
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
          r.log.flowIntensity != null ? r.log.flowIntensity!.index : '',
          r.log.spotting ? 1 : 0,
          r.log.otherDischarge ? 1 : 0,
          r.log.painIntensity ?? '',
          _encodeSymptoms(r.symptoms),
          r.log.notes ?? '',
          r.cycleStart ? 1 : 0,
        ],
    ];
    return const ListToCsvConverter().convert(data);
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
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
          errors.add(CsvParseError(
            rowNumber: i + 1,
            column: col,
            rawValue: '',
            reason: 'Required column "$col" missing from header',
          ));
        }
      }
      return CsvDecodeResult(rows: const [], errors: errors);
    }

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

      // Skip fully-empty trailing rows the csv package may produce.
      if (rawRow.every((c) => c.toString().trim().isEmpty)) continue;

      // date
      final dateStr = cell(rawRow, 'date');
      if (dateStr.isEmpty) {
        errors.add(CsvParseError(
          rowNumber: rowNum,
          column: 'date',
          rawValue: dateStr,
          reason: 'Date is required',
        ));
        continue;
      }
      final parsed = DateTime.tryParse(dateStr);
      DateTime? utcDate;
      if (parsed != null) {
        utcDate = DateTime.utc(parsed.year, parsed.month, parsed.day);
        if (_fmtDate(utcDate) != dateStr) utcDate = null;
      }
      if (utcDate == null) {
        errors.add(CsvParseError(
          rowNumber: rowNum,
          column: 'date',
          rawValue: dateStr,
          reason: 'Expected YYYY-MM-DD',
        ));
        continue;
      }

      // flow
      FlowIntensity? flowIntensity;
      final flowStr = cell(rawRow, 'flow');
      if (flowStr.isNotEmpty) {
        final idx = int.tryParse(flowStr);
        if (idx == null || idx < 0 || idx >= FlowIntensity.values.length) {
          errors.add(CsvParseError(
            rowNumber: rowNum,
            column: 'flow',
            rawValue: flowStr,
            reason: 'Expected 0–${FlowIntensity.values.length - 1} or empty',
          ));
          continue;
        }
        flowIntensity = FlowIntensity.values[idx];
      }

      // spotting
      final spStr = cell(rawRow, 'spotting');
      final spVal = int.tryParse(spStr);
      if (spVal == null || (spVal != 0 && spVal != 1)) {
        errors.add(CsvParseError(
          rowNumber: rowNum,
          column: 'spotting',
          rawValue: spStr,
          reason: 'Expected 0 or 1',
        ));
        continue;
      }

      // other_discharge
      final odStr = cell(rawRow, 'other_discharge');
      final odVal = int.tryParse(odStr);
      if (odVal == null || (odVal != 0 && odVal != 1)) {
        errors.add(CsvParseError(
          rowNumber: rowNum,
          column: 'other_discharge',
          rawValue: odStr,
          reason: 'Expected 0 or 1',
        ));
        continue;
      }

      // pain_intensity
      int? painIntensity;
      bool painEnabled = false;
      final painStr = cell(rawRow, 'pain_intensity');
      if (painStr.isNotEmpty) {
        final pv = int.tryParse(painStr);
        if (pv == null || pv < 1 || pv > 3) {
          errors.add(CsvParseError(
            rowNumber: rowNum,
            column: 'pain_intensity',
            rawValue: painStr,
            reason: 'Expected 1–3 or empty',
          ));
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
            symptoms.add(PainSymptomData(
              symptomType: PainSymptomType.custom,
              customLabel: t.substring('custom:'.length),
            ));
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
      bool notesEnabled = false;
      String? notes;
      final notesStr = cell(rawRow, 'notes');
      if (notesStr.isNotEmpty) {
        notes = notesStr;
        notesEnabled = true;
      }

      // cycle_start is ignored on decode.

      rows.add(DailyLogRow(
        log: DailyLogEntity(
          date: utcDate,
          flowIntensity: flowIntensity,
          spotting: spVal == 1,
          otherDischarge: odVal == 1,
          painEnabled: painEnabled,
          painIntensity: painIntensity,
          notesEnabled: notesEnabled,
          notes: notes,
        ),
        symptoms: symptoms,
      ));
    }

    return CsvDecodeResult(rows: rows, errors: errors);
  }
}
```

- [ ] Run `flutter test test/domain/services/csv_codec_test.dart` — must **PASS** (all green).

- [ ] Run `flutter analyze` — must exit 0.

- [ ] Commit:
```bash
git add lib/domain/services/csv_codec.dart test/domain/services/csv_codec_test.dart
git commit -m "feat(domain): add CsvCodec with DailyLogRow, CsvParseError, CsvDecodeResult (TDD)"
```

---

## T4: DailyLogRepository — deleteAllAndReplace

**Files:**
- Modify: `lib/domain/repositories/daily_log_repository.dart`
- Modify: `test/helpers/fake_daily_log_repository.dart`

This task adds the transactional delete+replace method that `ImportDailyLogs` (deleteAndImport mode) needs. The Drift implementation comes in T7 — for now, only the interface and the fake are updated so use-case tests can run.

- [ ] In `lib/domain/repositories/daily_log_repository.dart`, add after `deleteAll()`:

```dart
  /// Atomically deletes all daily logs (cascade-deletes pain_symptoms via FK)
  /// and inserts [logs] with their [symptoms]. Used by ImportDailyLogs in
  /// deleteAndImport mode to guarantee no partial-state on write failure.
  Future<void> deleteAllAndReplace(
    List<DailyLogEntity> logs,
    Map<DateTime, List<PainSymptomData>> symptoms,
  );
```

- [ ] In `test/helpers/fake_daily_log_repository.dart`, add after the `deleteAll` implementation:

```dart
  List<DailyLogEntity>? deleteAllAndReplaceCalledWithLogs;

  @override
  Future<void> deleteAllAndReplace(
    List<DailyLogEntity> logs,
    Map<DateTime, List<PainSymptomData>> newSymptoms,
  ) async {
    deleteAllAndReplaceCalledWithLogs = List.from(logs);
    savedLogs
      ..clear()
      ..addAll(logs);
    symptoms
      ..clear()
      ..addAll(newSymptoms);
  }
```

- [ ] Run `flutter analyze` — will show an error in `DriftDailyLogRepository` (missing override). That is expected and will be fixed in T7. The fake and the interface are done.

- [ ] Run `flutter test` — existing tests must still pass (only the Drift impl is broken, not test code).

- [ ] Commit:
```bash
git add lib/domain/repositories/daily_log_repository.dart test/helpers/fake_daily_log_repository.dart
git commit -m "feat(domain): add deleteAllAndReplace to DailyLogRepository interface and fake"
```

---

## T5: ExportDailyLogs use case (TDD)

**Files:**
- Create: `lib/domain/use_cases/export_daily_logs.dart`
- Create: `test/domain/use_cases/export_daily_logs_test.dart`

### Step 1 — Write tests first

- [ ] Create `test/domain/use_cases/export_daily_logs_test.dart`:

```dart
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
import 'package:metra/domain/use_cases/export_daily_logs.dart';

import '../../helpers/fake_daily_log_repository.dart';

void main() {
  late FakeDailyLogRepository fakeRepo;
  late ExportDailyLogs useCase;

  setUp(() {
    fakeRepo = FakeDailyLogRepository();
    useCase = ExportDailyLogs(fakeRepo);
  });

  test('empty repository → header-only CSV string', () async {
    final csv = await useCase.execute();
    final lines =
        csv.replaceAll('\r\n', '\n').trim().split('\n');
    expect(lines, hasLength(1));
    expect(
      lines.first,
      'date,flow,spotting,other_discharge,pain_intensity,symptoms,notes,cycle_start',
    );
  });

  test('3 logs with symptoms → CSV contains header + 3 data rows', () async {
    await fakeRepo.saveDailyLog(
      DailyLogEntity(
        date: DateTime.utc(2026, 1, 1),
        flowIntensity: FlowIntensity.heavy,
      ),
    );
    await fakeRepo.saveDailyLog(
      DailyLogEntity(
        date: DateTime.utc(2026, 2, 1),
        flowIntensity: FlowIntensity.light,
      ),
    );
    await fakeRepo.saveDailyLog(
      DailyLogEntity(date: DateTime.utc(2026, 3, 1)),
    );
    await fakeRepo.replacePainSymptoms(
      DateTime.utc(2026, 1, 1),
      [PainSymptomData(symptomType: PainSymptomType.cramps)],
    );

    final csv = await useCase.execute();
    final lines =
        csv.replaceAll('\r\n', '\n').trim().split('\n');
    // header + 3 data rows
    expect(lines, hasLength(4));
  });

  test('first flow day in a new cycle group has cycle_start = 1', () async {
    // Two cycles: first starts 2026-01-01, second starts 2026-02-05
    // (gap > 21 days so they form separate cycle groups).
    await fakeRepo.saveDailyLog(
      DailyLogEntity(
        date: DateTime.utc(2026, 1, 1),
        flowIntensity: FlowIntensity.medium,
      ),
    );
    await fakeRepo.saveDailyLog(
      DailyLogEntity(
        date: DateTime.utc(2026, 2, 5),
        flowIntensity: FlowIntensity.medium,
      ),
    );

    final csv = await useCase.execute();
    final lines = csv.replaceAll('\r\n', '\n').trim().split('\n');
    // Both flow days are cycle starts.
    expect(lines[1].split(',').last, '1'); // 2026-01-01
    expect(lines[2].split(',').last, '1'); // 2026-02-05
  });

  test('non-cycle-start day has cycle_start = 0', () async {
    // Only one log with no flow — not a cycle start.
    await fakeRepo
        .saveDailyLog(DailyLogEntity(date: DateTime.utc(2026, 1, 1)));

    final csv = await useCase.execute();
    final lines = csv.replaceAll('\r\n', '\n').trim().split('\n');
    expect(lines[1].split(',').last, '0');
  });
}
```

- [ ] Run `flutter test test/domain/use_cases/export_daily_logs_test.dart` — should **FAIL** (file not found).

### Step 2 — Implement ExportDailyLogs

- [ ] Create `lib/domain/use_cases/export_daily_logs.dart`:

```dart
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

import '../repositories/daily_log_repository.dart';
import '../services/csv_codec.dart';
import 'recompute_cycle_entries.dart';

class ExportDailyLogs {
  const ExportDailyLogs(this._logRepo);

  final DailyLogRepository _logRepo;

  Future<String> execute() async {
    final logs = await _logRepo.getAllOrderedByDate();

    // Derive cycle start dates from logs using the pure static computation,
    // avoiding a separate CycleEntryRepository dependency.
    final cycleEntries = RecomputeCycleEntries.compute(logs);
    final startDates = {for (final e in cycleEntries) e.startDate};

    final rows = <DailyLogRow>[];
    for (final log in logs) {
      final symptoms = await _logRepo.getPainSymptoms(log.date);
      rows.add(DailyLogRow(
        log: log,
        symptoms: symptoms,
        cycleStart: startDates.contains(log.date),
      ));
    }

    return const CsvCodec().encode(rows);
  }
}
```

- [ ] Run `flutter test test/domain/use_cases/export_daily_logs_test.dart` — must **PASS**.

- [ ] Run `flutter analyze` — must exit 0.

- [ ] Commit:
```bash
git add lib/domain/use_cases/export_daily_logs.dart test/domain/use_cases/export_daily_logs_test.dart
git commit -m "feat(domain): add ExportDailyLogs use case (TDD)"
```

---

## T6: ImportDailyLogs use case (TDD)

**Files:**
- Create: `lib/domain/use_cases/import_daily_logs.dart`
- Create: `test/domain/use_cases/import_daily_logs_test.dart`

### Step 1 — Write tests first

- [ ] Create `test/domain/use_cases/import_daily_logs_test.dart`:

```dart
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
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/services/csv_codec.dart';
import 'package:metra/domain/use_cases/import_daily_logs.dart';
import 'package:metra/domain/use_cases/recompute_cycle_entries.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

void main() {
  late FakeDailyLogRepository fakeLogRepo;
  late FakeCycleEntryRepository fakeCycleRepo;
  late RecomputeCycleEntries recompute;
  late ImportDailyLogs useCase;

  final date1 = DateTime.utc(2026, 1, 1);
  final date2 = DateTime.utc(2026, 2, 1);
  final date3 = DateTime.utc(2026, 3, 1);

  DailyLogRow makeRow(DateTime date) => DailyLogRow(
        log: DailyLogEntity(date: date),
        symptoms: const [],
      );

  DailyLogRow makeRowWithSymptom(DateTime date) => DailyLogRow(
        log: DailyLogEntity(date: date, painEnabled: true),
        symptoms: [PainSymptomData(symptomType: PainSymptomType.cramps)],
      );

  setUp(() {
    fakeLogRepo = FakeDailyLogRepository();
    fakeCycleRepo = FakeCycleEntryRepository();
    recompute = RecomputeCycleEntries(fakeLogRepo, fakeCycleRepo);
    useCase = ImportDailyLogs(fakeLogRepo, recompute);
  });

  group('deleteAndImport mode', () {
    test('calls deleteAllAndReplace with correct logs', () async {
      final rows = [makeRow(date1), makeRow(date2)];
      await useCase.execute(rows: rows, mode: ImportMode.deleteAndImport);

      expect(
        fakeLogRepo.deleteAllAndReplaceCalledWithLogs,
        isNotNull,
      );
      expect(
        fakeLogRepo.deleteAllAndReplaceCalledWithLogs!.map((l) => l.date),
        containsAll([date1, date2]),
      );
    });

    test('returns imported = rows.length, skipped = 0', () async {
      final result = await useCase.execute(
        rows: [makeRow(date1), makeRow(date2)],
        mode: ImportMode.deleteAndImport,
      );
      expect(result.imported, 2);
      expect(result.skipped, 0);
    });

    test('symptoms are stored via deleteAllAndReplace', () async {
      final rows = [makeRowWithSymptom(date1)];
      await useCase.execute(rows: rows, mode: ImportMode.deleteAndImport);

      final storedSymptoms = await fakeLogRepo.getPainSymptoms(date1);
      expect(storedSymptoms, hasLength(1));
      expect(storedSymptoms.first.symptomType, PainSymptomType.cramps);
    });
  });

  group('overwrite mode', () {
    test('existing date is replaced by CSV row', () async {
      await fakeLogRepo.saveDailyLog(
        DailyLogEntity(date: date1, notes: 'old note', notesEnabled: true),
      );

      final csvRow = DailyLogRow(
        log: DailyLogEntity(date: date1, notes: 'new note', notesEnabled: true),
        symptoms: const [],
      );
      await useCase.execute(rows: [csvRow], mode: ImportMode.overwrite);

      final saved = fakeLogRepo.savedLogs
          .firstWhere((l) => l.date == date1);
      expect(saved.notes, 'new note');
    });

    test('date not in CSV is left untouched', () async {
      await fakeLogRepo.saveDailyLog(DailyLogEntity(date: date3));

      await useCase.execute(
        rows: [makeRow(date1)],
        mode: ImportMode.overwrite,
      );

      expect(
        fakeLogRepo.savedLogs.any((l) => l.date == date3),
        isTrue,
      );
    });

    test('returns imported = rows.length, skipped = 0', () async {
      final result = await useCase.execute(
        rows: [makeRow(date1), makeRow(date2)],
        mode: ImportMode.overwrite,
      );
      expect(result.imported, 2);
      expect(result.skipped, 0);
    });
  });

  group('keepExisting mode', () {
    test('existing date is NOT overwritten', () async {
      await fakeLogRepo.saveDailyLog(
        DailyLogEntity(date: date1, notes: 'original', notesEnabled: true),
      );

      await useCase.execute(
        rows: [
          DailyLogRow(
            log: DailyLogEntity(date: date1, notes: 'csv', notesEnabled: true),
            symptoms: const [],
          ),
        ],
        mode: ImportMode.keepExisting,
      );

      final saved =
          fakeLogRepo.savedLogs.firstWhere((l) => l.date == date1);
      expect(saved.notes, 'original');
    });

    test('new date IS inserted', () async {
      await useCase.execute(
        rows: [makeRow(date2)],
        mode: ImportMode.keepExisting,
      );
      expect(
        fakeLogRepo.savedLogs.any((l) => l.date == date2),
        isTrue,
      );
    });

    test('skipped count matches existing-date rows', () async {
      await fakeLogRepo.saveDailyLog(DailyLogEntity(date: date1));

      final result = await useCase.execute(
        rows: [makeRow(date1), makeRow(date2)],
        mode: ImportMode.keepExisting,
      );
      expect(result.imported, 1);
      expect(result.skipped, 1);
    });
  });

  group('recompute called after all modes', () {
    test('deleteAndImport: cycle entries recomputed', () async {
      await useCase.execute(rows: [], mode: ImportMode.deleteAndImport);
      // replaceAll called with empty list (no flow days)
      expect(fakeCycleRepo.entries, isEmpty);
    });

    test('overwrite: cycle entries recomputed', () async {
      await useCase.execute(rows: [], mode: ImportMode.overwrite);
      expect(fakeCycleRepo.entries, isEmpty);
    });

    test('keepExisting: cycle entries recomputed', () async {
      await useCase.execute(rows: [], mode: ImportMode.keepExisting);
      expect(fakeCycleRepo.entries, isEmpty);
    });
  });
}
```

- [ ] Run `flutter test test/domain/use_cases/import_daily_logs_test.dart` — should **FAIL** (file not found).

### Step 2 — Implement ImportDailyLogs

- [ ] Create `lib/domain/use_cases/import_daily_logs.dart`:

```dart
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

import '../repositories/daily_log_repository.dart';
import '../services/csv_codec.dart';
import 'recompute_cycle_entries.dart';

enum ImportMode { deleteAndImport, overwrite, keepExisting }

class ImportResult {
  const ImportResult({required this.imported, required this.skipped});

  final int imported;

  /// Rows skipped because they already existed (keepExisting mode) or
  /// were excluded due to parse errors before this use case was called.
  final int skipped;
}

class ImportDailyLogs {
  const ImportDailyLogs(this._logRepo, this._recompute);

  final DailyLogRepository _logRepo;
  final RecomputeCycleEntries _recompute;

  Future<ImportResult> execute({
    required List<DailyLogRow> rows,
    required ImportMode mode,
  }) async {
    switch (mode) {
      case ImportMode.deleteAndImport:
        final symptomsMap = {
          for (final r in rows) r.log.date: r.symptoms,
        };
        await _logRepo.deleteAllAndReplace(
          rows.map((r) => r.log).toList(),
          symptomsMap,
        );
        await _recompute();
        return ImportResult(imported: rows.length, skipped: 0);

      case ImportMode.overwrite:
        for (final r in rows) {
          await _logRepo.saveDailyLog(r.log);
          await _logRepo.replacePainSymptoms(r.log.date, r.symptoms);
        }
        await _recompute();
        return ImportResult(imported: rows.length, skipped: 0);

      case ImportMode.keepExisting:
        final existing = await _logRepo.getAllOrderedByDate();
        final existingDates = {for (final l in existing) l.date};
        var imported = 0;
        var skipped = 0;
        for (final r in rows) {
          if (existingDates.contains(r.log.date)) {
            skipped++;
          } else {
            await _logRepo.saveDailyLog(r.log);
            await _logRepo.replacePainSymptoms(r.log.date, r.symptoms);
            imported++;
          }
        }
        await _recompute();
        return ImportResult(imported: imported, skipped: skipped);
    }
  }
}
```

- [ ] Run `flutter test test/domain/use_cases/import_daily_logs_test.dart` — must **PASS**.

- [ ] Run `flutter analyze` — must exit 0.

- [ ] Commit:
```bash
git add lib/domain/use_cases/import_daily_logs.dart test/domain/use_cases/import_daily_logs_test.dart
git commit -m "feat(domain): add ImportDailyLogs use case with three modes (TDD)"
```

---

## T7: DriftDailyLogRepository — deleteAllAndReplace

**Files:** `lib/data/repositories/drift_daily_log_repository.dart`

- [ ] In `drift_daily_log_repository.dart`, add after the `deleteAll` implementation (line 146):

```dart
  @override
  Future<void> deleteAllAndReplace(
    List<DailyLogEntity> logs,
    Map<DateTime, List<PainSymptomData>> symptomsMap,
  ) =>
      _dao.transaction(() async {
        // Deletes all daily_logs rows; PainSymptoms cascade-deleted via FK.
        await _dao.deleteAll();
        for (final log in logs) {
          await _dao.upsertDailyLog(_toCompanion(log));
        }
        for (final entry in symptomsMap.entries) {
          final companions = entry.value
              .map((s) => _symptomToCompanion(entry.key, s))
              .toList();
          if (companions.isNotEmpty) {
            await _dao.replacePainSymptoms(entry.key, companions);
          }
        }
      });
```

- [ ] Run `flutter analyze` — must exit 0 (the missing-override error from T4 is now resolved).

- [ ] Run `flutter test` — full suite must pass.

- [ ] Commit:
```bash
git add lib/data/repositories/drift_daily_log_repository.dart
git commit -m "feat(data): implement deleteAllAndReplace with Drift transaction in DriftDailyLogRepository"
```

---

## T8: notificationDaysBefore clamp (P-4 appsec LOW)

**Files:** `lib/domain/use_cases/schedule_prediction_notification.dart`, `test/domain/use_cases/schedule_prediction_notification_test.dart`

This fixes the P-4 appsec LOW finding: `notificationDaysBefore` was used without range clamping, allowing values outside 1–7 to reach the scheduling logic.

- [ ] In `schedule_prediction_notification.dart`, change the `notifyAt` computation from:

```dart
    final notifyAt = prediction.windowStart
        .subtract(Duration(days: settings.notificationDaysBefore));
```

to:

```dart
    final clampedDays = settings.notificationDaysBefore.clamp(1, 7);
    final notifyAt =
        prediction.windowStart.subtract(Duration(days: clampedDays));
```

- [ ] Open `test/domain/use_cases/schedule_prediction_notification_test.dart` and add a new test that verifies the clamp (add inside the existing `void main()` body):

```dart
    test('notificationDaysBefore=0 is clamped to 1 — notification still scheduled',
        () async {
      final notifService = FakeNotificationService();
      final uc = SchedulePredictionNotification(notifService);
      final prediction = CyclePrediction(
        expectedStart: DateTime.utc(2026, 6, 1),
        windowStart: DateTime.utc(2026, 5, 30),
        windowEnd: DateTime.utc(2026, 6, 3),
        cyclesUsed: 3,
      );
      final settings = const AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationsEnabled: true,
        notificationDaysBefore: 0, // invalid: below 1
      );

      await uc.execute(
        prediction: prediction,
        settings: settings,
        title: 't',
        body: 'b',
      );

      // Clamped to 1: notifyAt = windowStart - 1 day = 2026-05-29
      expect(notifService.scheduledAt, DateTime.utc(2026, 5, 29));
    });
```

- [ ] Run `flutter test test/domain/use_cases/schedule_prediction_notification_test.dart` — must pass.

- [ ] Run `flutter test` — full suite must pass.

- [ ] Commit:
```bash
git add lib/domain/use_cases/schedule_prediction_notification.dart \
        test/domain/use_cases/schedule_prediction_notification_test.dart
git commit -m "fix(domain): clamp notificationDaysBefore to 1–7 in SchedulePredictionNotification"
```

---

## T9: Provider wiring

**Files:** `lib/providers/use_case_providers.dart`

- [ ] In `use_case_providers.dart`, add these imports at the top (after the existing imports):

```dart
import '../domain/use_cases/export_daily_logs.dart';
import '../domain/use_cases/import_daily_logs.dart';
```

- [ ] Add these two providers at the end of the file (after `deleteAllDataProvider`):

```dart
// ── P-5a CSV export / import ──

final exportDailyLogsProvider = FutureProvider<ExportDailyLogs>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  return ExportDailyLogs(logRepo);
});

final importDailyLogsProvider = FutureProvider<ImportDailyLogs>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final recompute = await ref.watch(recomputeCycleEntriesProvider.future);
  return ImportDailyLogs(logRepo, recompute);
});
```

- [ ] Run `flutter analyze` — must exit 0.

- [ ] Run `flutter test` — full suite must pass.

- [ ] Commit:
```bash
git add lib/providers/use_case_providers.dart
git commit -m "feat(providers): register exportDailyLogsProvider and importDailyLogsProvider"
```

---

## T10: Settings screen wiring

**Files:** `lib/features/settings/settings_screen.dart`

### Step 1 — Add imports

- [ ] At the top of `settings_screen.dart`, add these imports after the existing `import` block:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/services/csv_codec.dart';
import '../../domain/use_cases/import_daily_logs.dart';
```

### Step 2 — Add Import CSV button to the ListView

- [ ] Find the existing `// ── CSV export` comment and the `ButtonGhost` for export in the `ListView`. Replace that entire `Padding` block:

```dart
            // ── CSV export ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MetraSpacing.s4,
                vertical: MetraSpacing.s3,
              ),
              child: ButtonGhost(
                label: l10n.settings_export_csv,
                semanticsLabel: l10n.settings_export_csv,
                onPressed: () => _showComingSoon(context, l10n),
              ),
            ),
```

with:

```dart
            // ── CSV export / import ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MetraSpacing.s4,
                vertical: MetraSpacing.s2,
              ),
              child: ButtonGhost(
                label: l10n.settings_export_csv,
                semanticsLabel: l10n.settings_export_csv,
                onPressed: () => _handleExport(context, ref, l10n),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MetraSpacing.s4,
                vertical: MetraSpacing.s2,
              ),
              child: ButtonGhost(
                label: l10n.settings_import_csv,
                semanticsLabel: l10n.settings_import_csv,
                onPressed: () => _handleImport(context, ref, l10n),
              ),
            ),
```

### Step 3 — Add _handleExport static method

- [ ] Add this method to `SettingsScreen` (after `_showDeleteConfirmation`):

```dart
  static Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    // Capture messenger before any async gap (lessons.jsonl p4-004).
    final messenger = ScaffoldMessenger.of(context);

    // Privacy warning bottom sheet — mandatory before share sheet (CLAUDE.md §11.6).
    if (!context.mounted) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s4,
                MetraSpacing.s5,
                MetraSpacing.s4,
                MetraSpacing.s3,
              ),
              child: Text(l10n.csv_export_privacy_warning),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                  child: Text(l10n.common_cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                  child: Text(l10n.csv_export_privacy_confirm),
                ),
                const SizedBox(width: MetraSpacing.s2),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final exportUc = await ref.read(exportDailyLogsProvider.future);
      final csvString = await exportUc.execute();

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filename =
          'metra_export_${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}.csv';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(csvString, encoding: utf8);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
    }
  }
```

### Step 4 — Add _handleImport static method

- [ ] Add this method after `_handleExport`:

```dart
  static Future<void> _handleImport(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    // Step 1: pick file.
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    // Step 2: read file content.
    String csvString;
    try {
      final path = picked.files.first.path;
      final bytes = picked.files.first.bytes;
      csvString = path != null
          ? await File(path).readAsString(encoding: utf8)
          : utf8.decode(bytes!);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
      return;
    }

    // Step 3: decode CSV (full-file scan before any write).
    final decodeResult = const CsvCodec().decode(csvString);

    // Step 4: if parse errors, ask user to abort or skip invalid rows.
    List<DailyLogRow> rowsToImport = decodeResult.rows;
    if (decodeResult.errors.isNotEmpty) {
      if (!context.mounted) return;
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          content: Text(
            l10n.csv_import_errors_dialog(count: decodeResult.errors.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.csv_import_abort),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.csv_import_skip_continue),
            ),
          ],
        ),
      );
      if (choice != true) return;
    }

    if (rowsToImport.isEmpty) return;

    // Step 5: mode picker (always before any write).
    if (!context.mounted) return;
    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        title: Text(l10n.csv_import_mode_title),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(ImportMode.deleteAndImport),
            child: Text(l10n.csv_import_mode_delete),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(ImportMode.overwrite),
            child: Text(l10n.csv_import_mode_overwrite),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(ImportMode.keepExisting),
            child: Text(l10n.csv_import_mode_keep),
          ),
        ],
      ),
    );
    if (mode == null) return;

    // Step 6: execute import and show result snackbar.
    try {
      final importUc = await ref.read(importDailyLogsProvider.future);
      final result =
          await importUc.execute(rows: rowsToImport, mode: mode);
      if (messenger.mounted) {
        final msg = result.skipped > 0
            ? l10n.csv_import_success_skipped(
                count: result.imported,
                skipped: result.skipped,
              )
            : l10n.csv_import_success(count: result.imported);
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.common_error_generic)),
        );
      }
    }
  }
```

- [ ] Run `dart format lib/features/settings/settings_screen.dart` — exits 0.

- [ ] Run `flutter analyze` — must exit 0.

- [ ] Commit:
```bash
git add lib/features/settings/settings_screen.dart
git commit -m "feat(settings): wire Export CSV and Import CSV with privacy warning, error dialog, and mode picker"
```

---

## T11: Settings screen widget tests

**Files:** `test/features/settings/settings_screen_test.dart`

- [ ] Add these test groups to the existing `void main()` in `settings_screen_test.dart` (after the existing `'SettingsScreen — delete execution'` group):

```dart
  group('SettingsScreen — CSV export button', () {
    testWidgets('Export CSV button is visible', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Esporta CSV'), findsOneWidget);
    });

    testWidgets('tapping Export CSV shows privacy warning bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esporta CSV'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Questo file contiene dati sanitari'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Cancel on privacy warning dismisses sheet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esporta CSV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Questo file contiene dati sanitari'),
        findsNothing,
      );
    });
  });

  group('SettingsScreen — CSV import button', () {
    testWidgets('Import CSV button is visible', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Importa CSV'), findsOneWidget);
    });

    testWidgets('Import CSV button is tappable (does not throw)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      // Tap does not throw even though FilePicker returns null in test env.
      await tester.tap(find.text('Importa CSV'));
      await tester.pump();
    });
  });
```

- [ ] Run `flutter test test/features/settings/settings_screen_test.dart` — must pass.

- [ ] Run `flutter test` — full suite must pass.

- [ ] Run `flutter analyze` — must exit 0.

- [ ] Commit:
```bash
git add test/features/settings/settings_screen_test.dart
git commit -m "test(settings): add widget tests for CSV export privacy warning and import button"
```

---

## T12: Security gate + version bump

**Files:** `pubspec.yaml`, `docs/security/p5a-appsec-review.md` (new)

- [ ] Run `dart format --set-exit-if-changed .` — must exit 0.
- [ ] Run `flutter test` — all green.
- [ ] Run `flutter analyze` — exit 0.
- [ ] Dispatch **appsec-engineer** review. Key checks:
  - No health data in snackbar messages (only row counts).
  - Privacy warning bottom sheet is mandatory before share sheet opens.
  - `deleteAndImport` write failure propagates exception (no silent data loss).
  - `notificationDaysBefore` clamp is in place.
- [ ] Write the appsec review findings to `docs/security/p5a-appsec-review.md`.
- [ ] In `pubspec.yaml`, bump `version: 0.1.0-p4+4` → `version: 0.1.0-p5a+5`.
- [ ] Commit:
```bash
git add pubspec.yaml docs/security/p5a-appsec-review.md
git commit -m "chore(release): appsec review P-5a, bump version to 0.1.0-p5a+5"
```
- [ ] Tag the release:
```bash
git tag v0.1.0-p5a
```

---

## Definition of Done

- [ ] `flutter analyze` exits 0.
- [ ] `dart format --set-exit-if-changed .` exits 0.
- [ ] All tests pass (`flutter test`).
- [ ] `CsvCodec` round-trip test covers all column types (flow 0–4, all booleans, pain 1–3, built-in + custom symptoms, notes with commas/newlines, cycle_start).
- [ ] `ImportDailyLogs` tests cover all three modes plus recompute.
- [ ] `deleteAllAndReplace` Drift implementation wraps delete+insert in a single transaction.
- [ ] Privacy warning bottom sheet shown before every export share.
- [ ] No health data in any snackbar message (counts only).
- [ ] `notificationDaysBefore` clamped to 1–7.
- [ ] Version bumped to `0.1.0-p5a+5`, tagged `v0.1.0-p5a`.
