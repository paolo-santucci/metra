# P-5a CSV Export / Import — Design Spec

**Goal:** Allow users to export all daily logs (including symptoms) to a single UTF-8 CSV file via the OS share sheet, and import a previously exported (or hand-edited) CSV with three conflict-resolution modes.

**Architecture:** Pure `CsvCodec` in `data/services/` handles serialization only. `ExportDailyLogs` and `ImportDailyLogs` use cases in `domain/use_cases/` orchestrate data access and write-back. The settings screen handles `share_plus`, `file_picker`, privacy warning, validation dialog, and mode picker. No new screen or route.

**Tech:** `share_plus: ^10.0.2`, `file_picker: ^8.1.2`, `csv: ^6.0.0` (all commented out in `pubspec.yaml`, enabled in P-5a).

---

## CSV Format

One file, one row per day logged, RFC 4180 (handled by the `csv` package). Header row always present.

| Column | Type | Values | Notes |
|---|---|---|---|
| `date` | string | `YYYY-MM-DD` | Required. Parse error if missing or malformed. |
| `flow` | int or empty | `0`–`4` or empty | Ordinal of `FlowIntensity` (`none=0, light=1, medium=2, heavy=3, veryHeavy=4`). Empty = null (not logged). |
| `spotting` | int | `1` / `0` | |
| `other_discharge` | int | `1` / `0` | |
| `pain_intensity` | int or empty | `1` / `2` / `3` or empty | Empty = no pain logged. On import: `painEnabled = true` if non-empty. |
| `symptoms` | quoted string or empty | Semicolon-separated enum names, e.g. `"cramps;backPain"`. Custom: `"custom:Nausea"`. Empty = none. | On import: `painEnabled = true` if non-empty. |
| `notes` | quoted string or empty | Free text, may contain commas and newlines. Empty = not logged. On import: `notesEnabled = true` if non-empty. |
| `cycle_start` | int | `1` / `0` | Denormalized from `CycleEntry.startDate`. **Export-only context for spreadsheet users; ignored on import.** Cycle boundaries are always recomputed via `RecomputeCycleEntries` after every import. |

Valid `PainSymptomType` enum names: `cramps`, `backPain`, `headache`, `migraine`, `bloating`, `custom`. Custom symptoms serialized as `custom:Label`.

---

## Architecture

### New files

| Path | Responsibility |
|---|---|
| `lib/data/services/csv_codec.dart` | `CsvCodec` — pure Dart. `encode(List<DailyLogRow>)→String`; `decode(String)→CsvDecodeResult`. No Flutter/IO imports. Also defines `DailyLogRow`, `CsvParseError`, `CsvDecodeResult`. |
| `lib/domain/use_cases/export_daily_logs.dart` | `ExportDailyLogs` — fetches all `DailyLogEntity` + symptoms, builds `List<DailyLogRow>`, calls `CsvCodec.encode`, returns CSV string. |
| `lib/domain/use_cases/import_daily_logs.dart` | `ImportDailyLogs` — accepts CSV string + `ImportMode`, calls `CsvCodec.decode`, applies mode logic, calls `replacePainSymptoms` per row, then `RecomputeCycleEntries`. Returns `ImportResult`. |

### Modified files

| Path | Change |
|---|---|
| `pubspec.yaml` | Uncomment `file_picker`, `share_plus`, `csv`. |
| `lib/l10n/app_en.arb` + `app_it.arb` | Add CSV l10n keys (see below). |
| `lib/providers/use_case_providers.dart` | Add `exportDailyLogsProvider`, `importDailyLogsProvider`. |
| `lib/features/settings/settings_screen.dart` | Wire Export and Import buttons; add privacy warning, validation dialog, mode picker. |

### Value objects (in `csv_codec.dart`)

```dart
class DailyLogRow {
  final DailyLogEntity log;
  final List<PainSymptomData> symptoms;
}

class CsvParseError {
  final int rowNumber;
  final String column;
  final String rawValue;
  final String reason;
}

class CsvDecodeResult {
  final List<DailyLogRow> rows;
  final List<CsvParseError> errors;
}
```

### `ImportMode` enum (in `import_daily_logs.dart`)

```dart
enum ImportMode { deleteAndImport, overwrite, keepExisting }
```

### `ImportResult` (in `import_daily_logs.dart`)

```dart
class ImportResult {
  final int imported;
  final int skipped;   // rows skipped due to keepExisting mode or parse errors
}
```

---

## Export Flow

1. User taps **Export CSV** in Settings.
2. Privacy warning bottom sheet: "This file contains your health data in plain text. Only share with apps or people you trust." → **Cancel** / **Continue**.
3. On Continue: `ExportDailyLogs` runs; result written to a temp file (`path_provider` → `getTemporaryDirectory()`), named `metra_export_YYYY-MM-DD.csv`.
4. `share_plus` opens the OS share sheet with the temp file.
5. Empty DB (no logs) → valid export of header-only CSV.
6. Error during encode or file write → `common_error_generic` snackbar.

---

## Import Flow

1. User taps **Import CSV** in Settings.
2. `file_picker` opens, filtered to `.csv`.
3. User cancels → nothing happens.
4. File read into string. `CsvCodec.decode` scans the entire file → `CsvDecodeResult`.
5. **If `errors` non-empty:** dialog — "Found {count} rows with invalid data." → **Abort** (nothing written) / **Skip & Continue** (proceed with valid rows only).
6. **Mode picker dialog** (always shown before any write):
   - **Delete all data and import** — `DeleteAllData.execute()`, then insert all valid rows.
   - **Import and overwrite** — upsert: CSV rows replace matching DB dates; DB-only dates untouched.
   - **Import, keep existing** — insert only dates absent from DB; existing rows untouched.
   - **Cancel** → nothing written.
7. Use case writes `DailyLogEntity` rows + `replacePainSymptoms` per row → `RecomputeCycleEntries`.
8. Success snackbar: "Imported {count} rows" or "Imported {count} rows, skipped {skipped}".
9. Write error → `common_error_generic` snackbar. For **deleteAndImport** mode: delete+insert run in a single Drift transaction to avoid partial state.

---

## L10n Keys

| Key | EN | IT |
|---|---|---|
| `csv_export_privacy_warning` | "This file contains your health data in plain text. Only share with apps or people you trust." | "Questo file contiene dati sanitari in chiaro. Condividilo solo con app o persone di cui ti fidi." |
| `csv_export_privacy_confirm` | "Continue" | "Continua" |
| `csv_import_errors_dialog` | "Found {count} rows with invalid data." | "Trovate {count} righe con dati non validi." |
| `csv_import_abort` | "Abort" | "Annulla importazione" |
| `csv_import_skip_continue` | "Skip & Continue" | "Salta e continua" |
| `csv_import_mode_title` | "Import mode" | "Modalità importazione" |
| `csv_import_mode_delete` | "Delete all data and import" | "Elimina tutto e importa" |
| `csv_import_mode_overwrite` | "Import and overwrite" | "Importa e sovrascrivi" |
| `csv_import_mode_keep` | "Import, keep existing" | "Importa, mantieni esistenti" |
| `csv_import_success` | "Imported {count} rows" | "Importate {count} righe" |
| `csv_import_success_skipped` | "Imported {count} rows, skipped {skipped}" | "Importate {count} righe, saltate {skipped}" |

---

## Testing

### `CsvCodec` unit tests
- Round-trip: `encode(rows)` → `decode(result)` → same rows.
- All column types present: flow 0–4, spotting, other_discharge, pain 1–3, symptoms (built-in + custom), notes with commas and newlines, `cycle_start`.
- `cycle_start` column is written on encode but ignored (not mapped) on decode.
- Empty export (header only) → decode returns empty `rows`, zero `errors`.
- Malformed date → `CsvParseError` with `column: "date"`.
- Unknown flow value → `CsvParseError` with `column: "flow"`.
- Pain value out of range (e.g. `5`) → `CsvParseError`.
- Unknown symptom name → skipped silently (forward-compatibility).
- Missing required column → `CsvParseError` for every affected row.

### `ExportDailyLogs` unit tests
- Fake repository with 3 logs + symptoms → `CsvCodec.encode` called with correct `DailyLogRow` list → string contains expected header and 3 data rows.
- Empty repository → header-only string.

### `ImportDailyLogs` unit tests
- `deleteAndImport` mode: `DeleteAllData` called, all valid rows written, `RecomputeCycleEntries` called.
- `overwrite` mode: existing date replaced, non-CSV date untouched, `RecomputeCycleEntries` called.
- `keepExisting` mode: existing date not touched, new date inserted, `RecomputeCycleEntries` called.
- Errors-skipped path: only valid rows written.
- `deleteAndImport` write failure: assert exception propagates (transaction rollback tested at DB layer).

### `SettingsScreen` widget tests
- Export button visible and tappable.
- Import button visible and tappable.
- Tapping Export shows privacy warning bottom sheet.
- Tapping Cancel on privacy warning dismisses without calling use case.

---

## Security

- Privacy warning is mandatory before the share sheet opens (CLAUDE.md §11.6).
- CSV is cleartext by design — this is explicitly user-requested data portability.
- No health data in snackbar messages: success strings contain only row counts.
- `deleteAndImport` uses a Drift transaction so a failed insert cannot leave the DB in a deleted-but-not-replaced state.
- `notificationDaysBefore` clamp (1–7) deferred from P-4 appsec review — address in this sprint at the `SchedulePredictionNotification` domain boundary.

---

## Out of scope

- Importing `CycleEntry` rows directly (always recomputed).
- Exporting `AppSettings` (settings are device-local preferences, not data).
- Scheduled / automatic export.
- iCloud or cloud-provider upload (P-6).
