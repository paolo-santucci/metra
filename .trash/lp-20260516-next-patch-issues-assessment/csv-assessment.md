# Module: CSV Import/Export

**Path**: `lib/domain/services/csv_codec.dart`, `lib/features/settings/settings_screen.dart`
**Agent**: bug-hunter

---

## Issue #18 — CSV import (deleteAndImport mode) shows no destructive-action warning before wiping user data

### Root cause

The `_handleImport` method in `settings_screen.dart` presents a `SimpleDialog` that lists three import modes as equal-weight options with no visual or textual differentiation between their destructiveness. The `deleteAndImport` option — which calls `deleteAllAndReplace()` and permanently erases every existing log and symptom record — is presented as a plain `SimpleDialogOption` with the label `"Delete all data and import"` (from `l10n.csv_import_mode_delete`). There is no secondary confirmation step, no warning body text, no destructive styling (red color, bold, separator, icon), and no count of records that will be deleted.

The user selects the mode in a single tap and the deletion executes immediately on the next `Navigator.of(dialogCtx).pop(ImportMode.deleteAndImport)`. The entire irreversible destructive path is:

```
SimpleDialogOption.onPressed
  → Navigator.pop(ImportMode.deleteAndImport)   // dialog closes
  → importUc.execute(rows, mode)
  → _logRepo.deleteAllAndReplace(...)            // ALL data gone, no undo
```

No confirmation dialog, no "are you sure?", no record count, no undo affordance.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | 859–880 | `showDialog` presenting mode choices; `deleteAndImport` path has no guard |
| `lib/domain/use_cases/import_daily_logs.dart` | 46–55 | `deleteAndImport` case calls `_logRepo.deleteAllAndReplace(...)` without precondition |
| `lib/l10n/app_localizations_en.dart` | 491 | String `"Delete all data and import"` — only warning the user ever sees, inside the mode list itself |
| `lib/l10n/app_localizations_it.dart` | same key | Italian mirror |

### Fix sketch

1. After the user taps the `deleteAndImport` option (or before presenting the mode dialog), pop the mode dialog and immediately show a second `AlertDialog` that:
   - States in explicit language that ALL existing data will be permanently erased.
   - Shows the count of records currently in the DB (query `_logRepo.getAllOrderedByDate()` — the count is already fetched in `keepExisting` mode; it can be pre-fetched here too, or the use case can return it).
   - Has a `Cancel` action (safe default) and a destructive `Delete and import` action styled in red or equivalent destructive color from `MetraColors`.
2. Only on explicit confirmation does `importUc.execute(rows, mode: ImportMode.deleteAndImport)` proceed.
3. The `l10n` strings for the confirmation body and confirm button must be added to both `.arb` files.

No domain logic change is required; the fix is entirely in the UI layer (`settings_screen.dart` and `.arb` strings).

---

## Issue #20 — CSV import rejects `pain_intensity=0` despite being a valid in-app value — data loss on round-trip

### Root cause

There is a misalignment between the valid range for `pain_intensity` on encode and the valid range enforced on decode.

**Encode path** (`csv_codec.dart`, line 91):

```dart
r.log.painIntensity ?? '',
```

When `painIntensity = 0`, this writes `"0"` to the CSV. This is correct: the in-app slider (`PainIntensitySlider`) and the circle picker (`CirclePainPicker`) both expose 0 ("none/nessuno") as a selectable and saveable value. `SaveDailyLog` validates `pv < 0 || pv > 3` (line 58), so `0` is permitted by the domain.

**Decode path** (`csv_codec.dart`, lines 334–349):

```dart
final painStr = cell(rawRow, 'pain_intensity');
if (painStr.isNotEmpty) {
  final pv = int.tryParse(painStr);
  if (pv == null || pv < 1 || pv > 3) {   // ← BUG: rejects 0
    errors.add(
      CsvParseError(
        rowNumber: rowNum,
        column: 'pain_intensity',
        rawValue: painStr,
        reason: 'Expected 1–3 or empty',    // ← error message itself is wrong
      ),
    );
    continue;
  }
  painIntensity = pv;
  painEnabled = true;
}
```

The lower bound is `pv < 1`, which silently rejects `0` as invalid. The error message text `'Expected 1–3 or empty'` confirms the coder believed 0 was not a valid encoded value — but the encoder emits it, so this assumption is wrong.

**Full round-trip failure scenario**:

1. User opens pain section on today's entry, slider is at 0 ("Nessuno"), leaves it at 0 and saves. `painIntensity=0`, `painEnabled=true` is persisted in the DB.
2. User exports CSV. Row contains `pain_intensity,0`.
3. User imports the CSV (any mode). Decoder hits `pv < 1` → adds `CsvParseError` for that row → the row is skipped or (if user chooses "skip errors and continue") the row is written with `painIntensity=null`, `painEnabled=false`.
4. Data loss: the record that had pain enabled at level 0 is either excluded entirely or imported without pain data.

**Additional consequence**: because the erroneous decode path calls `continue`, a row with `pain_intensity=0` also drops all subsequently parsed fields for that row (symptoms, notes) — so notes and symptoms are lost alongside the pain data.

**Test coverage gap**: the test suite (`test/domain/services/csv_codec_test.dart`) has no test case for `pain_intensity=0`. The existing test `'empty pain_intensity → null painIntensity, painEnabled false'` (line 277) covers the empty-string case but not the integer-zero case. A round-trip test with `painIntensity: 0` would have caught this immediately.

### Affected files

| File | Lines | Defect |
|---|---|---|
| `lib/domain/services/csv_codec.dart` | 336 | `pv < 1` should be `pv < 0` |
| `lib/domain/services/csv_codec.dart` | 344 | Error reason string `'Expected 1–3 or empty'` should read `'Expected 0–3 or empty'` |
| `test/domain/services/csv_codec_test.dart` | — | Missing test: `pain_intensity=0` round-trip must produce `painIntensity=0, painEnabled=true` |

### Fix sketch

**`lib/domain/services/csv_codec.dart`, line 336**: change lower bound from `1` to `0`:

```dart
// Before
if (pv == null || pv < 1 || pv > 3) {

// After
if (pv == null || pv < 0 || pv > 3) {
```

**`lib/domain/services/csv_codec.dart`, line 344**: update the error reason string to match the corrected valid range:

```dart
// Before
reason: 'Expected 1–3 or empty',

// After
reason: 'Expected 0–3 or empty',
```

No UI change, no entity change, no repository change. A single comparison operator change in the codec is the complete fix.

A complementary test must be added to `csv_codec_test.dart`:

```dart
test('pain_intensity=0 round-trips correctly (painEnabled=true, painIntensity=0)', () {
  // 0 is a valid in-app value (slider: "Nessuno" / circle: transparent)
  final r = row(
    date: DateTime.utc(2026, 5, 1),
    flowType: FlowType.assente,
    painIntensity: 0,
  );
  // Manually construct a DailyLogRow with painEnabled set, as the test helper
  // does not wire painEnabled from painIntensity.
  final withPain = DailyLogRow(
    log: DailyLogEntity(
      date: DateTime.utc(2026, 5, 1),
      flowType: FlowType.assente,
      painEnabled: true,
      painIntensity: 0,
    ),
    symptoms: const [],
  );
  final result = codec.decode(codec.encode([withPain]));
  expect(result.errors, isEmpty);
  expect(result.rows.first.log.painIntensity, 0);
  expect(result.rows.first.log.painEnabled, isTrue);
});
```

---

## Risks

1. **Issue #20 fix is trivially testable** — the one-character change (`< 1` → `< 0`) is low risk. The surrounding logic is not touched. Existing tests continue to pass because no test currently asserts on `pain_intensity=0`.

2. **Issue #20 interaction with `painEnabled` inference**: after the fix, a row with `pain_intensity=0` will parse `painIntensity=0` and set `painEnabled=true` (line 348). This is correct and consistent with the in-app behavior (the user explicitly chose pain level 0 with the panel open). The `SaveDailyLog` domain validator already accepts `painIntensity=0` alongside `painEnabled=true`.

3. **Issue #18 — UX contract**: the fix adds a second dialog step for `deleteAndImport`. This changes the import flow for all existing users. The additional dialog must be dismissible without triggering the delete (Cancel = safe default) to meet the WCAG 2.2 AA criterion for error prevention (SC 3.3.4). The `overwrite` and `keepExisting` modes are not affected; they must not get a secondary confirmation.

4. **Issue #18 — data count query**: pre-fetching the record count to display in the confirmation dialog requires an async call before the dialog is shown, which extends the `_handleImport` function. The call is a cheap `getAllOrderedByDate()` (already used in `keepExisting` mode) so it is unlikely to introduce latency issues, but it must be guarded with a `context.mounted` check after the await.

5. **No interaction between Issue #18 and Issue #20**: they are independent. A row that fails parse due to the `pain_intensity=0` bug (Issue #20) contributes to `decodeResult.errors`. When `deleteAndImport` mode is subsequently chosen, the already-rejected row is not in `rowsToImport` — meaning fixing Issue #20 increases the rows that survive into `rowsToImport`, which makes Issue #18's missing warning even more consequential (more data gets successfully parsed and thus replaced).

---

## Tech debt

1. **`CsvCodec` range constants are not shared with `SaveDailyLog`**: `SaveDailyLog` defines `_maxPainIntensity = 3` at line 30, and the codec hardcodes `pv > 3` at decode time. There is no shared constant. If the domain pain range ever changes, both places must be updated independently. A shared `const int kPainIntensityMin = 0; const int kPainIntensityMax = 3;` in a domain-level file would eliminate this duplication.

2. **`_handleImport` is a 110-line static method** (`settings_screen.dart`, lines 788–899). It mixes file I/O, CSV decode, two dialogs, mode dispatch, and snackbar handling. It would benefit from extraction into a dedicated controller or use case. This is pre-existing debt; the issues above do not require refactoring it to be fixed, but any touch to this method is an opportunity to split it.

3. **`catch (_) {}` on import execute** (`settings_screen.dart`, line 892): the import exception handler swallows all errors with no logging, making it impossible to diagnose failures in production. At minimum a `debugPrint` should be added, consistent with `_handleExport` at line 779.

4. **No test covers `deleteAndImport` mode end-to-end**: the existing `csv_codec_test.dart` only tests the codec in isolation. The `ImportDailyLogs` use case is not tested for the `deleteAndImport` path at all. A unit test using a fake repository that verifies `deleteAllAndReplace` is called (and called only once, before the recompute) would close this gap.
