# P-5a AppSec Review

**Date:** 2026-04-29
**Reviewer:** appsec-engineer (automated)
**Sprint:** P-5a — CSV Export / Import

## Summary

The P-5a CSV export/import surface is well-structured: input validation happens
entirely in `CsvCodec.decode` before any write occurs, the privacy warning gate
is correctly enforced before share, and the database write is wrapped in a Drift
transaction. Two low/info-level findings are noted and do not block release.

## Threat Model (sintesi)

- **Asset**: user health data (flow, symptoms, pain, notes) serialised to CSV.
- **Trust boundary**: device filesystem → OS share sheet → recipient app.
  The export is intentionally cleartext (user action, warned in UI); the import
  reads from a file the user explicitly selects.
- **Attaccanti considerati**: malicious CSV file crafted to corrupt or replace
  data; passive observers of temp storage; spreadsheet formula injection via
  notes content.

## Findings

| # | Severity | Area | Description | Status |
|---|---|---|---|---|
| 1 | Low | Export – temp file lifecycle | Temp CSV is not deleted after `Share.shareXFiles` returns. The file persists in `getTemporaryDirectory()` until OS GC. On Android the path is app-private (`/data/data/<pkg>/cache`), on iOS it is `NSTemporaryDirectory()` — both inaccessible to other apps without root. Risk is low but violates the principle of least exposure for sensitive health data. **Remediation**: wrap `Share.shareXFiles` + `file.delete()` in a `try/finally` block in `_handleExport`. | OPEN |
| 2 | Info | Export – CSV formula injection | Notes content is written verbatim. A note beginning with `=`, `+`, `-`, `@`, TAB, or CR will be interpreted as a spreadsheet formula if the exported file is opened in Excel / Google Sheets / Numbers. Data is the user's own and export is an explicit action; however CLAUDE.md §16 anticipates "share with gynecologist" in v1.1, which introduces a distinct receiving identity. **Remediation** (deferred to v1.1): prefix any cell in the `notes` column whose first character is one of the above with a `'` quote before calling `ListToCsvConverter`, or sanitise in `CsvCodec.encode`. | DEFERRED |

### Verified checks (all pass)

1. **No health data in snackbar messages** — `_handleImport` snackbars show only
   `result.imported` and `result.skipped` counts via localised strings
   (`csv_import_success`, `csv_import_success_skipped`). No dates, symptoms,
   notes, or flow values are ever surfaced. **PASS**

2. **Privacy warning mandatory before export share** — `_handleExport` calls
   `showModalBottomSheet` and gates on `confirmed == true` before executing the
   use case or calling `Share.shareXFiles`. The early-return `if (confirmed != true) return;`
   is present at line 496. **PASS**

3. **deleteAndImport write failure propagates** — In `ImportDailyLogs`, the
   `deleteAndImport` branch `await`s `_logRepo.deleteAllAndReplace(...)` without
   a try/catch. Any exception thrown by the repository (including Drift
   transaction rollback) propagates to the caller in `settings_screen.dart`,
   which catches it and shows the generic error snackbar. No silent swallow.
   **PASS**

4. **notificationDaysBefore clamp** — `schedule_prediction_notification.dart`
   line 35: `final clampedDays = settings.notificationDaysBefore.clamp(1, 7);`
   is present and used for all subsequent date arithmetic. **PASS**

5. **CSV input validation before write** — `settings_screen.dart` calls
   `const CsvCodec().decode(csvString)` at line 556, before any call to the
   import use case. All field validation (date format, flow index bounds,
   spotting/other_discharge 0|1, pain_intensity 1–3, required-column check)
   occurs inside `decode()`. The use case receives only already-validated
   `DailyLogRow` objects. **PASS**

6. **No health data logging** — grep over all seven P-5a files found zero
   `print` or `debugPrint` calls. **PASS**

7. **Temp file path** — `getTemporaryDirectory()` is used (not
   `getApplicationDocumentsDirectory()` or a world-readable external path).
   Correct for ephemeral share on both Android and iOS. **PASS**

8. **Atomic write guarantee** — `DriftDailyLogRepository.deleteAllAndReplace`
   wraps `_dao.deleteAll()` + all inserts inside `_dao.transaction(...)` (Drift's
   `DatabaseAccessor.transaction`). A failure mid-insert rolls back the whole
   operation; the DB is never left in a partially-written state. **PASS**

## Verdict

**PASS_WITH_NOTES**

Finding #1 (Low) should be fixed before the v1.0 public release. Finding #2
(Info) is deferred to v1.1 alongside the "share with gynecologist" feature that
raises its risk profile.
