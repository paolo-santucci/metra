# [LP-ASSESS] Next Patch Issues — Métra

```yaml
project: metra
request_type: bug-fix
assessed_modules: 5
```

**Date**: 2026-05-16
**Author**: bug-hunter (merged by orchestrator)
**Initiative**: "Implement all issues currently in the Next Patch column of the Métra project"

---

## Module: Settings

**Path**: lib/domain/entities/, lib/features/settings/, lib/data/repositories/
**Agent**: bug-hunter

---

### Issue #13 — Theme → System resets notificationTimeMinutes, firstDayOfWeek; corrupts Backup row display until stream re-emits

#### Root cause

`_showThemePicker` in `settings_screen.dart` (lines 418–429) must set `darkMode` to `null` to activate the System theme. Because `copyWith` cannot express a `null` override for a nullable field (see Issue #16 below), the developer worked around it by constructing a bare `AppSettingsData(...)` literal with only the fields they remembered to forward:

```dart
// settings_screen.dart:420-429
_save(
  ref,
  AppSettingsData(
    languageCode: settings.languageCode,
    darkMode: null,
    painEnabled: settings.painEnabled,
    notesEnabled: settings.notesEnabled,
    notificationDaysBefore: settings.notificationDaysBefore,
    notificationsEnabled: settings.notificationsEnabled,
    onboardingCompleted: settings.onboardingCompleted,
  ),
);
```

This constructor call omits:
- `notificationTimeMinutes` — falls back to the default parameter value `AppConstants.kDefaultNotificationTimeMinutes` (540), overwriting the user's stored value.
- `firstDayOfWeek` — falls back to `FirstDayOfWeekSetting.system`, overwriting any non-default user choice.
- `dropboxEmail` and `lastBackupAt` — both default to `null`.

**DB-level impact (partial):** `SettingsNotifier.save` calls `repo.updateSettings(settings)` which goes through `_toCompanion`. The `_toCompanion` method (lines 68–78 of `drift_app_settings_repository.dart`) intentionally **excludes** `dropboxEmail` and `lastBackupAt` from the companion — so those two fields are NOT written to the database and the DB row retains their correct values.

**In-memory impact (full):** `SettingsNotifier.save` at line 51 immediately executes `state = AsyncData(settings)`, which puts the malformed object (with `dropboxEmail: null`, `lastBackupAt: null`) into the reactive state. Every widget watching `settingsNotifierProvider` — including the Backup row that reads `dropboxEmail` via `backupNotifierProvider` — will see the erased values until the Drift `watchSettings()` stream fires and `build()` re-hydrates from the DB.

**DB-level impact (real writes):** `notificationTimeMinutes` and `firstDayOfWeek` **are** included in `_toCompanion`, so they are durably reset to 540 / 0 in the database when the user switches to System theme.

**Call chain:**
1. User taps "Sistema" in the theme bottom sheet.
2. `_showThemePicker` → `_save(ref, AppSettingsData(...))` — bare constructor, missing fields.
3. `SettingsNotifier.save(settings)` → `state = AsyncData(settings)` — in-memory corruption.
4. `repo.updateSettings(settings)` → `_toCompanion(settings)` → DB write — persists wrong `notificationTimeMinutes`/`firstDayOfWeek`, silently skips `dropboxEmail`/`lastBackupAt`.
5. Drift stream re-emits → `SettingsNotifier.build()` re-reads DB → in-memory `dropboxEmail`/`lastBackupAt` restored; `notificationTimeMinutes`/`firstDayOfWeek` now reflect the (corrupted) DB values.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | 418–429 | Bug site: bare constructor call omitting fields |
| `lib/domain/entities/app_settings_data.dart` | 89–123 | Root enabler: `copyWith` cannot pass `null` for `darkMode` (Issue #16) |
| `lib/features/settings/state/settings_notifier.dart` | 48–52 | Propagates the malformed state immediately via `state = AsyncData(settings)` |
| `lib/data/repositories/drift_app_settings_repository.dart` | 62–78 | `_toCompanion` limits DB damage but cannot prevent in-memory corruption |

#### Fix sketch

The correct fix requires Issue #16 to be resolved first (sentinel-aware `copyWith`). Once `copyWith` can express a `null` override for `darkMode`, replace the bare constructor at line 419 with:

```dart
_save(ref, settings.copyWith(darkMode: const Nullable(null)));
```

where `Nullable<T>` is the sentinel wrapper introduced by the #16 fix. This preserves all other fields (including `notificationTimeMinutes`, `firstDayOfWeek`) from the live `settings` object and eliminates the in-memory corruption window.

If a quick patch is needed before #16 is resolved, the minimum safe change is to forward all non-null fields explicitly:

```dart
AppSettingsData(
  languageCode: settings.languageCode,
  darkMode: null,
  painEnabled: settings.painEnabled,
  notesEnabled: settings.notesEnabled,
  notificationDaysBefore: settings.notificationDaysBefore,
  notificationsEnabled: settings.notificationsEnabled,
  onboardingCompleted: settings.onboardingCompleted,
  notificationTimeMinutes: settings.notificationTimeMinutes,  // ADD
  firstDayOfWeek: settings.firstDayOfWeek,                    // ADD
  // dropboxEmail and lastBackupAt intentionally omitted;
  // they are excluded from _toCompanion and will be
  // restored by the next stream emission.
)
```

Add a comment explaining why `dropboxEmail`/`lastBackupAt` are omitted (consistent with `_toCompanion` policy) so the next developer does not re-add them.

---

### Issue #16 — `darkMode` cannot be reset to null (system theme) via `copyWith`

#### Root cause

`AppSettingsData.copyWith` (lines 89–123 of `app_settings_data.dart`) uses the standard Dart nullable-override pattern for `darkMode`:

```dart
// app_settings_data.dart:104
darkMode: darkMode ?? this.darkMode,
```

When a caller passes `darkMode: null`, the `??` operator treats `null` as "not provided" and falls through to `this.darkMode`. There is no way to distinguish "I want to set this to null" from "I'm omitting this field". This is the root enabler of Issue #13: the only way to set `darkMode` to `null` is the full-constructor workaround that omits other fields.

The same structural defect exists for `dropboxEmail` and `lastBackupAt`, though those fields are intentionally excluded from `copyWith` (they are managed by dedicated writers `updateBackupState` / `saveDeclaredCycleLength` / `updateLastDataWriteAt`) — so the defect is latent there but harmless today.

**Call chain (failure):**
1. `settings.copyWith(darkMode: null)` — caller intends to set system theme.
2. Dart evaluates `null ?? settings.darkMode` → returns `settings.darkMode` (e.g. `true`).
3. The returned `AppSettingsData` still has `darkMode == true`; system theme is never applied.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/domain/entities/app_settings_data.dart` | 89–123 | Bug site: `copyWith` implementation |
| `lib/features/settings/settings_screen.dart` | 418–429 | Downstream: workaround that triggers #13 |

#### Fix sketch

Introduce a typed sentinel wrapper in the entity file (or a shared `core/` utility):

```dart
/// Sentinel wrapper to express "set this nullable field to null" in copyWith.
///
/// Usage: settings.copyWith(darkMode: const Nullable(null))
class Nullable<T> {
  const Nullable(this.value);
  final T? value;
}
```

Update `copyWith` signature and body:

```dart
AppSettingsData copyWith({
  String? languageCode,
  Nullable<bool>? darkMode,    // changed from bool?
  bool? painEnabled,
  bool? notesEnabled,
  int? notificationDaysBefore,
  bool? notificationsEnabled,
  int? notificationTimeMinutes,
  FirstDayOfWeekSetting? firstDayOfWeek,
  // dropboxEmail / lastBackupAt intentionally absent — dedicated writers only
  bool? onboardingCompleted,
}) {
  return AppSettingsData(
    languageCode: languageCode ?? this.languageCode,
    darkMode: darkMode != null ? darkMode.value : this.darkMode,  // sentinel-aware
    painEnabled: painEnabled ?? this.painEnabled,
    notesEnabled: notesEnabled ?? this.notesEnabled,
    notificationDaysBefore: notificationDaysBefore ?? this.notificationDaysBefore,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    declaredCycleLength: declaredCycleLength,
    notificationTimeMinutes: notificationTimeMinutes ?? this.notificationTimeMinutes,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    lastLogOrSymptomWriteAt: lastLogOrSymptomWriteAt,
  );
}
```

All callers that pass a non-null `bool` for `darkMode` (light/dark selection) continue to work without change — `Nullable(false)` and `Nullable(true)` are valid. Callers that currently use the bare constructor workaround (Issue #13) must be updated to `copyWith(darkMode: const Nullable(null))`.

---

### Issue #21 — Re-opening notification time picker silently rounds stored value to nearest 5 minutes

#### Root cause

`_showCupertinoTimePicker` (lines 538–575 of `settings_screen.dart`) rounds the stored value to the nearest 5-minute tick **before** using it as the save baseline:

```dart
// settings_screen.dart:543-546
final seedMinutes = _roundTo5(settings.notificationTimeMinutes);
final initial = DateTime(2000, 1, 1, seedMinutes ~/ 60, seedMinutes % 60);

int currentMinutes = seedMinutes;   // ← save baseline is the ROUNDED value
```

If the stored value is off-grid (e.g. 547 minutes = 09:07, rounded to 545 = 09:05), then:

1. The picker opens with `initial = 09:05` and `currentMinutes = 545`.
2. The user does not move the wheel at all.
3. The user taps "OK".
4. The OK handler fires `onAutoSave` (lines 1029–1033) which calls `_save(ref, settings.copyWith(notificationTimeMinutes: currentMinutes))` — persisting 545, not 547.

A second instance of the same bug lives in `onRestore` (lines 566–572): it resets `currentMinutes = seedMinutes` (the rounded value) and immediately saves it, permanently overwriting the stored off-grid value.

**Practical risk today:** The default value (540 = 09:00) is on-grid. The only current writer of `notificationTimeMinutes` outside migrations is the picker itself, which emits only on-grid values via `CupertinoDatePicker` with `minuteInterval: 5`. However, the `_fromRow` clamp (repository line 57) will preserve any off-grid value that arrives via a future migration or CSV-based import. Once persisted, re-opening the picker will silently round and overwrite it. The `onRestore` path is unconditionally destructive regardless of origin.

Additionally, `onRestore` (line 570) writes `seedMinutes` (rounded) even if the user immediately taps "Ripristina" without moving the wheel — the "restore" changes the stored value to the rounded variant, which is unintuitive.

**Call chain (failure):**
1. User has stored `notificationTimeMinutes = 547` (e.g. from a migration).
2. User opens time picker: `seedMinutes = _roundTo5(547) = 545`, `currentMinutes = 545`.
3. User does not scroll. Taps "OK".
4. `onAutoSave` fires: saves 545 to DB.
5. Stored value silently changed from 547 to 545.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | 543–546 | Bug site: `currentMinutes` initialised to rounded seed |
| `lib/features/settings/settings_screen.dart` | 566–572 | Second instance: `onRestore` saves rounded seed |
| `lib/features/settings/settings_screen.dart` | 347–348 | `_roundTo5` helper — correct as a display helper, misused as save baseline |

#### Fix sketch

Separate the display seed (rounded for the wheel) from the save baseline (original value):

```dart
static Future<void> _showCupertinoTimePicker(
  BuildContext context,
  WidgetRef ref,
  AppSettingsData settings,
) async {
  // Round only for display — keep the original as the save baseline.
  final originalMinutes = settings.notificationTimeMinutes;
  final seedMinutes = _roundTo5(originalMinutes);
  final initial = DateTime(2000, 1, 1, seedMinutes ~/ 60, seedMinutes % 60);

  int currentMinutes = originalMinutes;  // ← save baseline is ORIGINAL, not rounded

  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _CupertinoPickerScaffold(
      wheelBuilder: (resetKey, scheduleAutoSave) => CupertinoDatePicker(
        key: resetKey,
        mode: CupertinoDatePickerMode.time,
        minuteInterval: 5,
        initialDateTime: initial,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(ctx),
        onDateTimeChanged: (dt) {
          currentMinutes = dt.hour * 60 + dt.minute;
          scheduleAutoSave();
        },
      ),
      onAutoSave: () => _save(
        ref,
        settings.copyWith(notificationTimeMinutes: currentMinutes),
      ),
      onRestore: () {
        currentMinutes = originalMinutes;  // ← restore to ORIGINAL, not rounded
        _save(
          ref,
          settings.copyWith(notificationTimeMinutes: originalMinutes),
        );
      },
    ),
  );
}
```

The `CupertinoDatePicker` wheel display will show 09:05 for a stored 09:07 (the wheel cannot represent 09:07 at minuteInterval 5). The first wheel movement will snap to the nearest grid position and update `currentMinutes` via `onDateTimeChanged`, which is correct — the user explicitly selected a new value. Tapping "OK" without moving preserves the original value.

---

### Issue #22 — `notificationDaysBefore` has no lower-bound validation at entity level

#### Root cause

`AppSettingsData` accepts any `int` for `notificationDaysBefore` without range enforcement:

```dart
// app_settings_data.dart:27-28
const AppSettingsData({
  ...
  required this.notificationDaysBefore,
  ...
```

Range enforcement exists only at two downstream sites:

1. `DriftAppSettingsRepository._fromRow` (line 51): `row.notificationDaysBefore.clamp(1, AppConstants.kMaxAdvanceDays)` — read-time clamp silences corrupt DB values but cannot prevent them from being written.
2. `SchedulePredictionNotification.execute` (lines 39–45): throws `ArgumentError` at scheduling time if the value is out of range — this is a use-case guard, not an entity invariant.

**Gap:** Any path that creates or mutates an `AppSettingsData` in memory bypasses both guards. Concretely:

- `AppSettingsData.defaults()` sets `notificationDaysBefore: 2` (valid).
- `copyWith(notificationDaysBefore: 0)` — no guard — produces an entity with an invalid field.
- The days picker in `_showCupertinoDaysPicker` correctly constrains its index to `[0, kMaxAdvanceDays-1]` (lines 591–592), translating to `[1, kMaxAdvanceDays]`. But this UI guard is invisible to all other callers (tests, future CSV import, onboarding).
- A test or migration that passes `notificationDaysBefore: 0` creates an entity that will crash `SchedulePredictionNotification` at runtime without any indication of where the bad value originated.

**Lower-bound specificity:** The existing constraint is `[1, 7]`. The lower bound (1) is violated by 0 or negative values. There is no upper-bound check at entity level either, but `kMaxAdvanceDays = 7` is a small constant and the UI picker enforces it; the lower bound is more dangerous because 0 days before the predicted date means the notification fires on the prediction date itself, which is semantically invalid and causes the `ArgumentError` in the use case.

**Call chain (failure):**
1. Any caller invokes `settings.copyWith(notificationDaysBefore: 0)`.
2. `AppSettingsData` stores the value without protest.
3. `SettingsNotifier.save` → `repo.updateSettings` → DB write → 0 persisted.
4. `_fromRow.clamp(1, 7)` silently returns 1 on next read, masking the corruption.
5. OR: `SchedulePredictionNotification.execute` throws `ArgumentError` with no traceable origin.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/domain/entities/app_settings_data.dart` | 21–36 | Bug site: constructor accepts unconstrained int |
| `lib/data/repositories/drift_app_settings_repository.dart` | 51 | Clamp at read-time — symptom suppressor, not a fix |
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 39–45 | Late guard — use-case level, not entity level |
| `lib/features/settings/settings_screen.dart` | 591–592 | UI-level guard — invisible to non-UI callers |

#### Fix sketch

Add an `assert` in the entity constructor and a matching `assert` in `copyWith`:

```dart
const AppSettingsData({
  ...
  required this.notificationDaysBefore,
  ...
}) : assert(
       notificationDaysBefore >= 1 &&
           notificationDaysBefore <= AppConstants.kMaxAdvanceDays,
       'notificationDaysBefore must be in [1, $kMaxAdvanceDays]',
     );
```

For `copyWith`, the guard propagates automatically because it delegates to the constructor. No separate assert is needed there.

Remove the `clamp` from `_fromRow` (or replace it with an `assert`/explicit throw so that DB corruption surfaces loudly instead of being silently masked):

```dart
// Before (masks corruption silently):
notificationDaysBefore: row.notificationDaysBefore.clamp(1, AppConstants.kMaxAdvanceDays),

// After (surfaces corruption at the data layer):
notificationDaysBefore: () {
  final v = row.notificationDaysBefore;
  assert(v >= 1 && v <= AppConstants.kMaxAdvanceDays,
      'DB row has invalid notificationDaysBefore: $v');
  return v.clamp(1, AppConstants.kMaxAdvanceDays); // clamp kept for release builds
}(),
```

The use-case guard at `schedule_prediction_notification.dart:39-45` can be retained as a defence-in-depth check.

---

### Settings — Risks

1. **Fix ordering dependency:** Issues #13 and #16 must be fixed together. Fixing #13 independently with a bare constructor workaround is fragile; fixing #16 first enables a clean #13 fix via `copyWith`. Any patch sequence that fixes #13 without #16 creates a maintenance trap: every future nullable field addition will repeat the pattern.

2. **`_toCompanion` exclusion list is implicit policy:** The set of fields excluded from `updateSettings` (dropboxEmail, lastBackupAt, declaredCycleLength, lastLogOrSymptomWriteAt) is enforced only by a comment at lines 62–67 of `drift_app_settings_repository.dart`. When Issue #16 is fixed and `copyWith` becomes sentinel-aware, callers may start passing `dropboxEmail`/`lastBackupAt` through the general settings save path. If those fields ever reach `_toCompanion`, they will be silently dropped (current behaviour) or — worse — if `_toCompanion` is updated to include them, future saves will overwrite values set by `updateBackupState`. The exclusion policy needs either a machine-enforced boundary (split the entity into a preferences-only DTO and a full-state DTO) or at minimum an integration test asserting that `updateSettings` never writes those columns.

3. **In-memory corruption window in #13:** Even after the fix, the `state = AsyncData(settings)` call in `SettingsNotifier.save` (line 51) creates a window where the notifier state and the DB differ by one Drift stream tick (~0 to tens of ms). This is by design (optimistic UI update), but it relies on the Drift stream firing promptly. If the stream is delayed (DB busy, test mock), the in-memory state is stale. This is not a new risk introduced by the fix, but it is worth noting that the fix does not eliminate the in-memory/DB divergence window — it only ensures the divergence carries the correct values.

4. **`onRestore` semantics after #21 fix:** After the fix, "Ripristina" restores the original stored value (including any off-grid value). If the stored value is off-grid, the wheel will remain at the rounded display position even after "Ripristina" writes the original. The visual inconsistency (wheel shows 09:05, stored value is 09:07) is acceptable because the wheel cannot represent off-grid values, but it should be documented in a code comment.

---

### Settings — Tech debt

1. **`copyWith` sentinel pattern should be applied uniformly.** The `Nullable<T>` wrapper introduced for `darkMode` (Issue #16 fix) should be documented as the project-standard pattern for nullable preference fields. Without this, the next developer adding a nullable field will likely reproduce the same bug.

2. **`AppSettingsData` should be split into two types.** The current entity carries both user-controlled preferences (languageCode, darkMode, notificationDaysBefore, etc.) and system-managed state (dropboxEmail, lastBackupAt, declaredCycleLength, lastLogOrSymptomWriteAt). The comment-only exclusion in `_toCompanion` is the only mechanism preventing the general settings save path from touching system-managed fields. A `AppPreferencesData` / `AppSystemStateData` split — or a `freezed`-generated union — would make the boundary compiler-enforced.

3. **`notificationTimeMinutes` has no entity-level validation.** Issue #22 requests entity-level validation for `notificationDaysBefore`; the same gap exists for `notificationTimeMinutes` (legal range [0, 1439]). The use-case guard at `schedule_prediction_notification.dart:47-53` provides late protection, but the entity constructor accepts any int. These two validations should be added in the same commit to avoid a partial fix.

4. **`SchedulePredictionNotification` validation is duplicated at the entity level once the fix lands.** After fixing #22, the entity-level `assert` for `notificationDaysBefore` and the use-case `ArgumentError` check are redundant. The use-case check can be removed or downgraded to a debug-only `assert` once the entity invariant is trusted.

---

## Module: CSV Import/Export

**Path**: `lib/domain/services/csv_codec.dart`, `lib/features/settings/settings_screen.dart`
**Agent**: bug-hunter

---

### Issue #18 — CSV import (deleteAndImport mode) shows no destructive-action warning before wiping user data

#### Root cause

The `_handleImport` method in `settings_screen.dart` presents a `SimpleDialog` that lists three import modes as equal-weight options with no visual or textual differentiation between their destructiveness. The `deleteAndImport` option — which calls `deleteAllAndReplace()` and permanently erases every existing log and symptom record — is presented as a plain `SimpleDialogOption` with the label `"Delete all data and import"` (from `l10n.csv_import_mode_delete`). There is no secondary confirmation step, no warning body text, no destructive styling (red color, bold, separator, icon), and no count of records that will be deleted.

The user selects the mode in a single tap and the deletion executes immediately on the next `Navigator.of(dialogCtx).pop(ImportMode.deleteAndImport)`. The entire irreversible destructive path is:

```
SimpleDialogOption.onPressed
  → Navigator.pop(ImportMode.deleteAndImport)   // dialog closes
  → importUc.execute(rows, mode)
  → _logRepo.deleteAllAndReplace(...)            // ALL data gone, no undo
```

No confirmation dialog, no "are you sure?", no record count, no undo affordance.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | 859–880 | `showDialog` presenting mode choices; `deleteAndImport` path has no guard |
| `lib/domain/use_cases/import_daily_logs.dart` | 46–55 | `deleteAndImport` case calls `_logRepo.deleteAllAndReplace(...)` without precondition |
| `lib/l10n/app_localizations_en.dart` | 491 | String `"Delete all data and import"` — only warning the user ever sees, inside the mode list itself |
| `lib/l10n/app_localizations_it.dart` | same key | Italian mirror |

#### Fix sketch

1. After the user taps the `deleteAndImport` option (or before presenting the mode dialog), pop the mode dialog and immediately show a second `AlertDialog` that:
   - States in explicit language that ALL existing data will be permanently erased.
   - Shows the count of records currently in the DB (query `_logRepo.getAllOrderedByDate()` — the count is already fetched in `keepExisting` mode; it can be pre-fetched here too, or the use case can return it).
   - Has a `Cancel` action (safe default) and a destructive `Delete and import` action styled in red or equivalent destructive color from `MetraColors`.
2. Only on explicit confirmation does `importUc.execute(rows, mode: ImportMode.deleteAndImport)` proceed.
3. The `l10n` strings for the confirmation body and confirm button must be added to both `.arb` files.

No domain logic change is required; the fix is entirely in the UI layer (`settings_screen.dart` and `.arb` strings).

---

### Issue #20 — CSV import rejects `pain_intensity=0` despite being a valid in-app value — data loss on round-trip

#### Root cause

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

#### Affected files

| File | Lines | Defect |
|---|---|---|
| `lib/domain/services/csv_codec.dart` | 336 | `pv < 1` should be `pv < 0` |
| `lib/domain/services/csv_codec.dart` | 344 | Error reason string `'Expected 1–3 or empty'` should read `'Expected 0–3 or empty'` |
| `test/domain/services/csv_codec_test.dart` | — | Missing test: `pain_intensity=0` round-trip must produce `painIntensity=0, painEnabled=true` |

#### Fix sketch

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

### CSV — Risks

1. **Issue #20 fix is trivially testable** — the one-character change (`< 1` → `< 0`) is low risk. The surrounding logic is not touched. Existing tests continue to pass because no test currently asserts on `pain_intensity=0`.

2. **Issue #20 interaction with `painEnabled` inference**: after the fix, a row with `pain_intensity=0` will parse `painIntensity=0` and set `painEnabled=true` (line 348). This is correct and consistent with the in-app behavior (the user explicitly chose pain level 0 with the panel open). The `SaveDailyLog` domain validator already accepts `painIntensity=0` alongside `painEnabled=true`.

3. **Issue #18 — UX contract**: the fix adds a second dialog step for `deleteAndImport`. This changes the import flow for all existing users. The additional dialog must be dismissible without triggering the delete (Cancel = safe default) to meet the WCAG 2.2 AA criterion for error prevention (SC 3.3.4). The `overwrite` and `keepExisting` modes are not affected; they must not get a secondary confirmation.

4. **Issue #18 — data count query**: pre-fetching the record count to display in the confirmation dialog requires an async call before the dialog is shown, which extends the `_handleImport` function. The call is a cheap `getAllOrderedByDate()` (already used in `keepExisting` mode) so it is unlikely to introduce latency issues, but it must be guarded with a `context.mounted` check after the await.

5. **No interaction between Issue #18 and Issue #20**: they are independent. A row that fails parse due to the `pain_intensity=0` bug (Issue #20) contributes to `decodeResult.errors`. When `deleteAndImport` mode is subsequently chosen, the already-rejected row is not in `rowsToImport` — meaning fixing Issue #20 increases the rows that survive into `rowsToImport`, which makes Issue #18's missing warning even more consequential (more data gets successfully parsed and thus replaced).

---

### CSV — Tech debt

1. **`CsvCodec` range constants are not shared with `SaveDailyLog`**: `SaveDailyLog` defines `_maxPainIntensity = 3` at line 30, and the codec hardcodes `pv > 3` at decode time. There is no shared constant. If the domain pain range ever changes, both places must be updated independently. A shared `const int kPainIntensityMin = 0; const int kPainIntensityMax = 3;` in a domain-level file would eliminate this duplication.

2. **`_handleImport` is a 110-line static method** (`settings_screen.dart`, lines 788–899). It mixes file I/O, CSV decode, two dialogs, mode dispatch, and snackbar handling. It would benefit from extraction into a dedicated controller or use case. This is pre-existing debt; the issues above do not require refactoring it to be fixed, but any touch to this method is an opportunity to split it.

3. **`catch (_) {}` on import execute** (`settings_screen.dart`, line 892): the import exception handler swallows all errors with no logging, making it impossible to diagnose failures in production. At minimum a `debugPrint` should be added, consistent with `_handleExport` at line 779.

4. **No test covers `deleteAndImport` mode end-to-end**: the existing `csv_codec_test.dart` only tests the codec in isolation. The `ImportDailyLogs` use case is not tested for the `deleteAndImport` path at all. A unit test using a fake repository that verifies `deleteAllAndReplace` is called (and called only once, before the recompute) would close this gap.

---

## Module: Backup / Cloud Sync

**Path**: `lib/data/services/`, `lib/features/settings/`, `lib/features/backup/`, `lib/domain/use_cases/`, `lib/providers/`
**Agent**: bug-hunter

---

### Issue #11 — Auto backup must be suppressed after "Delete all data"

#### Current behavior

When the user taps "Delete all data" → confirms the dialog, `settings_screen.dart:652–699` fires `deleteAllDataProvider.future` which calls `DeleteAllData.execute()` (`lib/domain/use_cases/delete_all_data.dart:27–30`). That calls `_logRepo.deleteAll()` → `DriftDailyLogRepository.deleteAll()` (`lib/data/repositories/drift_daily_log_repository.dart:195–198`):

```dart
@override
Future<void> deleteAll() async {
  await _dao.deleteAll();
  await _settingsRepo.updateLastDataWriteAt(_now());  // line 197 — bumps the skip-guard signal
}
```

`_settingsRepo.updateLastDataWriteAt(_now())` sets `lastLogOrSymptomWriteAt = now()`.

On the next cold-start, `app.dart:113–122` calls `backupSilent()`. The skip guard in `BackupNotifier.backupSilent()` (`lib/features/backup/state/backup_notifier.dart:129–151`) reads:

```dart
final lastBackupAt = settings.lastBackupAt;          // line 129 — e.g. 2026-05-10T08:00Z
final lastWriteAt  = settings.lastLogOrSymptomWriteAt; // line 130 — now() from delete, e.g. 2026-05-16T14:30Z

if (lastBackupAt != null) {
  if (lastWriteAt == null || !lastWriteAt.isAfter(lastBackupAt)) {  // line 136
    // skip
  }
}
```

After delete-all, `lastWriteAt` (the deletion timestamp) is always after `lastBackupAt`, so `!lastWriteAt.isAfter(lastBackupAt)` is `false` → guard does **not** skip → `_runBackup()` is called → an empty encrypted snapshot is uploaded to Dropbox, **overwriting the user's real backup with an empty blob**.

#### Root cause / missing piece

`DriftDailyLogRepository.deleteAll()` (line 197) calls `updateLastDataWriteAt(_now())` — it treats deletion as a write event indistinguishable from logging new data. The skip guard at `backupSilent():136` cannot distinguish "fresh data was written" from "all data was deleted". After deletion, `lastLogOrSymptomWriteAt > lastBackupAt` is always true, so the guard proceeds and uploads an empty snapshot.

The `SyncOrchestrator.restore()` method already solves an analogous problem: after restore it re-aligns `lastLogOrSymptomWriteAt` to `lastBackupAt` (lines 139–142 of `sync_orchestrator.dart`) to prevent the skip guard from seeing "new data" from `deleteAllAndReplace`. The same alignment must happen after delete-all.

`DriftCycleEntryRepository.deleteAll()` (`lib/data/repositories/drift_cycle_entry_repository.dart:89`) does **not** bump `lastLogOrSymptomWriteAt`, so the partial fix of removing the bump from the daily-log path alone would be insufficient: future symptom deletions (if any) must be audited too.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/repositories/drift_daily_log_repository.dart` | 195–198 | Root cause: bumps `lastLogOrSymptomWriteAt` on `deleteAll()` |
| `lib/domain/use_cases/delete_all_data.dart` | 21–31 | Fix site: add post-delete alignment |
| `lib/providers/use_case_providers.dart` | 95–99 | Wires `DeleteAllData`; needs `settingsRepo` injection if fix is here |
| `lib/features/backup/state/backup_notifier.dart` | 116–158 | Skip guard — correct, but tricked by stale timestamp |
| `lib/app.dart` | 113–122 | Cold-start trigger for `backupSilent()` |
| `lib/domain/repositories/app_settings_repository.dart` | 35, 62 | `updateBackupState` / `updateLastDataWriteAt` contracts |
| `test/features/backup/state/backup_notifier_test.dart` | 656–1009 | Skip-guard tests — no coverage for delete-all-then-backupSilent |

#### Fix sketch

**Option A (recommended) — align in `DeleteAllData`**, mirroring the restore pattern:

1. Add `AppSettingsRepository _settingsRepo` parameter to `DeleteAllData` (`delete_all_data.dart:21`).
2. After `await _cycleRepo.deleteAll()`, read `settings.lastBackupAt`. If non-null, call `_settingsRepo.updateLastDataWriteAt(settings.lastBackupAt!)`. If null (no prior backup), call `_settingsRepo.updateLastDataWriteAt(DateTime.utc(1970))` or leave `lastLogOrSymptomWriteAt` unchanged — either way the guard will see `lastBackupAt == null` and proceed only if this is the first backup, which is correct (there is nothing to protect).
3. Inject `settingsRepo` in `deleteAllDataProvider` (`use_case_providers.dart:95`).
4. Add a test to `backup_notifier_test.dart`: `deleteAll()` followed by `backupSilent()` → `backupSilent()` appends a `backupSkipped` log and does **not** upload.

This mirrors `sync_orchestrator.dart:139–142` exactly and does not change any domain invariants.

**Option B — remove the bump from `DriftDailyLogRepository.deleteAll()`** (line 197):

Do not call `updateLastDataWriteAt` on deletion. The bump exists because deletion is a valid data-state change; removing it silently ignores that signal. If `lastLogOrSymptomWriteAt` was set before the delete, it stays at its old value, and the guard behaves correctly. However, this leaves `lastLogOrSymptomWriteAt` pointing to a timestamp when data *did* exist, which is semantically stale. Option A is safer.

**Option B is not recommended on its own.** It would fix the cold-start path but leave an in-session manual backup call after delete-all still able to upload (because `backupSilent()` isn't called in-session — only cold-start — so this is actually safe, but it is a latent trap if the caller ever changes).

---

### Issue #12 — Keep more than one backup on cloud storage

#### Current behavior

`SyncOrchestrator.backup()` (`lib/data/services/backup/sync_orchestrator.dart:78–86`) prunes every file except the just-uploaded one:

```dart
for (final f in files) {
  if (f != filename) {
    try {
      await _provider.deleteFile(f);
    } catch (_) {}
  }
}
```

`files` comes from `_provider.listFiles()` which returns all `metra_backup_*.enc` files sorted descending (newest first). After upload + verification, all older backups are deleted. The user is left with exactly one backup at all times. If that single backup becomes corrupt or the upload fails mid-session, there is no fallback.

#### Root cause / missing piece

The prune loop has no retention policy. It treats "not the current filename" as "delete". The `BackupFilename.parseTimestamp()` utility (`lib/data/services/backup/backup_filename.dart:37–48`) already extracts a UTC `DateTime` from any filename and returns `null` for non-conforming names, making it safe to call on any entry.

The proposed retention policy is:

1. **Always keep**: the file just uploaded (current backup).
2. **Keep**: the most recent file among those present before the current upload (i.e., at most one previous backup — second-newest overall).
3. **Keep**: the most recent backup from the calendar month prior to `ts.month / ts.year` (so the user retains at least one cross-month recovery point).
4. **Delete**: everything else.

`_now()` is already injectable (constructor param `now`, used for `ts`), so the month boundary is deterministic in tests.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/backup/sync_orchestrator.dart` | 73–86 | Prune loop — fix location |
| `lib/data/services/backup/backup_filename.dart` | 37–48 | `parseTimestamp()` already available |
| `lib/data/services/backup/dropbox_provider.dart` | 209–247, 250–259 | `listFiles()` / `deleteFile()` contracts |
| `test/data/services/backup/sync_orchestrator_test.dart` | 107–128 | "deletes older files after uploading new one" — **will break** |

#### Fix sketch

Replace the prune loop in `SyncOrchestrator.backup()` (lines 78–86) with a helper:

```dart
// After upload + verification, files is already fetched (line 74).
// files is sorted descending (newest first) per DropboxProvider contract.
final prevMonth = DateTime.utc(ts.year, ts.month - 1); // Dart handles month=0 → December prior year
final toKeep = _retentionSet(filename, files, prevMonth);
for (final f in files) {
  if (!toKeep.contains(f)) {
    try {
      await _provider.deleteFile(f);
    } catch (_) {}
  }
}
```

```dart
/// Returns the set of filenames to retain under the 3-slot retention policy:
/// 1. [current]   — the file just uploaded.
/// 2. [previous]  — the most recent file that existed before this upload.
/// 3. [monthly]   — the most recent file from [prevMonth] (year/month pair).
static Set<String> _retentionSet(
  String current,
  List<String> files,     // sorted descending, includes current
  DateTime prevMonth,
) {
  final keep = <String>{current};
  String? previous;
  String? monthly;
  for (final f in files) {
    if (f == current) continue;
    final ts = BackupFilename.parseTimestamp(f);
    if (ts == null) continue;
    // Slot 2: most recent prior backup.
    previous ??= f;
    // Slot 3: most recent backup in prevMonth (year+month match).
    if (monthly == null &&
        ts.year == prevMonth.year &&
        ts.month == prevMonth.month) {
      monthly = f;
    }
    if (previous != null && monthly != null) break;
  }
  if (previous != null) keep.add(previous);
  if (monthly != null) keep.add(monthly);
  return keep;
}
```

Notes:
- `DateTime.utc(ts.year, ts.month - 1)` when `ts.month == 1` produces `DateTime.utc(ts.year, 0)` which Dart normalises to `DateTime.utc(ts.year - 1, 12)` — correct December of prior year.
- Files that do not parse (null from `parseTimestamp`) are excluded from the keep set and thus pruned — safe, as they are not canonical backups.
- The helper is `static` and pure, so it can be unit-tested independently.
- `sync_orchestrator_test.dart:107–128` ("deletes older files after uploading new one") asserts exactly 1 file after backup. It must be rewritten to assert the new retention semantics: current + at most 1 previous + optional monthly.

---

### Backup — Risks

1. **Issue #11 — silent data loss in production.** If a user deletes all data and the app cold-starts before the fix is deployed, the Dropbox backup is overwritten with an empty snapshot. Recovery requires the user to still have the previous backup locally (they don't — it was replaced). This is the highest-severity risk in the module.

2. **Issue #11 — `lastBackupAt == null` edge case.** If the user has never backed up but has a passphrase configured (e.g., configured passphrase, never ran first backup), delete-all sets `lastLogOrSymptomWriteAt = now()`. On next cold-start, `backupSilent()` enters the `lastBackupAt == null` branch (case c — first-ever backup) and uploads an empty snapshot. Fix option A must also handle this edge: if `lastBackupAt` is null, set `lastLogOrSymptomWriteAt` to a sentinel (epoch or null) so the guard skips on empty DB.

3. **Issue #12 — `listFiles()` ordering contract.** The prune logic assumes `listFiles()` returns filenames sorted descending. `DropboxProvider.listFiles()` (lines 209–247) sorts descending via `sort((a, b) => b.compareTo(a))`. The fake `FakeDropboxProvider` used in tests must replicate this sort; verify it does before shipping.

4. **Issue #12 — prevMonth boundary at year rollover.** `DateTime.utc(ts.year, ts.month - 1)` when `ts.month == 1` evaluates to `DateTime.utc(year, 0)`. Dart normalises month 0 to December of the prior year. Verify with a unit test at the January boundary (ts = 2026-01-15 → prevMonth = 2025-12).

5. **Partial prune failure leaves extra files.** Both current and new prune loops use `catch (_) {}` (best-effort delete). If deletion fails, the next backup cycle will attempt deletion again (idempotent). The retention set being a superset of the previous state means no data is lost; at worst, more than 3 files accumulate temporarily.

---

### Backup — Tech debt

1. **`deleteAll()` semantics are overloaded.** `DriftDailyLogRepository.deleteAll()` bumps `lastLogOrSymptomWriteAt` for good reasons on the restore path (`deleteAllAndReplace` calls it indirectly), but for the delete-all-data path it is harmful. The interface does not distinguish "delete as part of a restore" from "delete as a user action". Splitting into `deleteAllForRestore()` (no bump) and `deleteAll()` (no bump) with alignment at the call site would make intent explicit.

2. **`DeleteAllData` does not inject `AppSettingsRepository`.** The use case is minimal by design, but the fix for Issue #11 requires it. The provider wiring at `use_case_providers.dart:95–99` is a 3-line change; document the reason for the addition (alignment post-delete).

3. **`_retentionSet` is a private static.** Once Issue #12 is fixed, the retention logic should have its own unit test file (e.g., `test/data/services/backup/backup_retention_test.dart`) rather than being tested only through the orchestrator integration test.

4. **No integration test for delete-all → cold-start backup path.** The existing `backup_notifier_test.dart` integration group covers backup → restore → re-backup but not delete-all → backupSilent. This gap is what allowed Issue #11 to ship undetected.

5. **`FakeDropboxProvider` sort order.** If `FakeDropboxProvider.listFiles()` returns files in insertion order rather than descending-sorted order, Issue #12's retention logic will compute the wrong `previous` and `monthly` slots. Audit and fix the fake before writing Issue #12 tests.

---

## Module: Onboarding

**Path**: `lib/domain/use_cases/complete_onboarding.dart`, `lib/features/onboarding/`
**Agent**: bug-hunter

---

### Issue #28 — `CompleteOnboarding.execute` lacks a transactional wrapper — crash mid-execution produces duplicate anchor cycle entries

#### Root cause

`CompleteOnboarding.execute` performs four sequential `await` calls with no rollback boundary:

```dart
// lib/domain/use_cases/complete_onboarding.dart:46–59
await _cycleRepo.insert(anchor);          // 1. writes CycleEntry
final logs = await _logRepo.getAllOrderedByDate();
final hasFlowLogs = logs.any((l) => ...);
if (hasFlowLogs) await _recompute();      // 2. optionally replaces CycleEntries
await _settingsRepo.saveDeclaredCycleLength(cycleLength); // 3. settings write
await _settingsRepo.markOnboardingComplete();             // 4. guard write
```

Step 1 inserts the anchor cycle entry unconditionally. Steps 3 and 4 are the only persistent markers that onboarding has completed. If the app crashes or is force-killed at any point between step 1 and step 4 (inclusive of step 4 failing), the next cold-start re-evaluates `onboardingCompleted == false` and re-displays the onboarding flow. The user can re-submit, producing a second anchor insert with the same `startDate`. After N forced-kill cycles, N anchor entries accumulate in `CycleEntries`.

**Crash window**: steps 1 → 4 run on the Dart UI isolate while `NativeDatabase.createInBackground` owns a background SQLite worker. The app can be killed by the OS during a background I/O flush at any await point.

**No-log branch is worse**: when `hasFlowLogs` is false (the common new-user case), `_recompute()` is skipped, so `CycleEntryRepository.replaceAll` never runs. The duplicate anchor is never cleaned up by a subsequent recompute. Each re-submission appends another entry; `WatchCyclePrediction` will then see multiple anchors on the same date and behave incorrectly (non-deterministic prediction start date).

**When `hasFlowLogs` is true**: `_recompute()` calls `_cycleRepo.replaceAll(entries)` which deletes all cycle entries and re-inserts only log-derived entries. So the anchor inserted at step 1 is wiped in the same recompute call — duplicates do not accumulate in this branch. The hazard is confined to the no-log branch.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/domain/use_cases/complete_onboarding.dart` | 38–60 | Defective `execute` method — no transaction |
| `lib/data/database/daos/cycle_entry_dao.dart` | 38–39 | `insertCycleEntry` — no uniqueness guard on `startDate` |
| `lib/domain/repositories/cycle_entry_repository.dart` | 26 | `insert` interface — no upsert variant |
| `test/domain/use_cases/complete_onboarding_test.dart` | 29–153 | No crash/retry test; does not cover duplicate anchor scenario |

#### Fix sketch

Two viable approaches under this codebase's strict `domain/ → data/` layering rule (domain must not import Drift):

**Option A — domain `TransactionRunner` interface (canonical for a "transactional wrapper" fix)**

Add `lib/domain/repositories/transaction_runner.dart`:
```dart
abstract class TransactionRunner {
  Future<T> run<T>(Future<T> Function() body);
}
```

Add `lib/data/repositories/drift_transaction_runner.dart`:
```dart
class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._db);
  final AppDatabase _db;
  @override
  Future<T> run<T>(Future<T> Function() body) => _db.transaction(body);
}
```

Inject into `CompleteOnboarding` as a 5th constructor argument and wrap steps 1+3+4 (or 1–4) inside `_txRunner.run(...)`. Wire in `use_case_providers.dart`. This is the minimal invasive fix and keeps the domain layer clean.

**Option B — idempotent insert (no new abstraction required)**

Add a `insertOrIgnoreByStartDate` method (or upsert-on-conflict) to `CycleEntryRepository` and its Drift implementation. Before inserting the anchor, check if a null-`cycleLength` entry already exists for `lastPeriodDate` and skip if so. This makes re-submission safe without a transaction but does not atomically bind the settings writes.

Option A is preferred because Option B does not prevent the settings calls from failing independently — a crash between a successful idempotent insert and `markOnboardingComplete` still leaves the user in a retry loop (though without accumulating extra entries after the first).

**Mandatory regression test**: add a test to `complete_onboarding_test.dart` that calls `execute` twice and asserts `cycleRepo.entries` has length 1 (not 2), simulating a re-entry after a partial failure.

---

### Issue #29 — `OnboardingNotifier.setDate` does not validate against future dates

#### Root cause

`setDate` accepts any `DateTime` without validation:

```dart
// lib/features/onboarding/state/onboarding_notifier.dart:49
void setDate(DateTime date) => state = state.copyWith(lastPeriodDate: date);
```

The only guard in the flow is the date-picker's `lastDate: now` parameter set in `_DatePickerField._pickDate`:

```dart
// lib/features/onboarding/onboarding_screen.dart:476–484
final picked = await showDatePicker(
  context: context,
  firstDate: DateTime(2000),
  lastDate: now,                 // UI-only guard — bypassed if setDate called directly
  ...
);
if (picked != null) {
  onDateSelected(DateTime.utc(picked.year, picked.month, picked.day));
}
```

`lastDate: now` is a local `DateTime`. The value passed to `onDateSelected` (and thus `setDate`) is `DateTime.utc(picked.year, picked.month, picked.day)` — UTC midnight of the picked day. The picker prevents selecting a day after today, but the conversion to UTC midnight can produce a value marginally in the future relative to `DateTime.now().toUtc()` for users in UTC+ time zones near midnight.

More importantly, `setDate` is a public method on the notifier and is completely unguarded. Any caller — including tests or future screen code — can pass a tomorrow or next-year date. If called that way, a future `lastPeriodDate` is stored in state, `canSubmit` returns true (no additional check), and `CompleteOnboarding.execute` is invoked with a future `startDate`. That anchor date flows into `CyclePredictionService` as the reference point, producing a predicted "next period" that is in the past or malformed.

**UTC-midnight subtlety**: the naive fix `if (date.isAfter(DateTime.now().toUtc())) return;` would reject legitimate same-day picks by users in UTC+1 and later during the first hour of the local day, because the stored UTC midnight of "today" is up to UTC+offset hours ahead of the current UTC instant. The validation must compare calendar days in UTC, not instants:

```dart
void setDate(DateTime date) {
  final now = DateTime.now();
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  if (date.isAfter(todayUtc)) return;   // reject future calendar day (UTC)
  state = state.copyWith(lastPeriodDate: date);
}
```

This is identical in structure to the known `save_daily_log_test.dart` intermittent (see `STATUS.yaml` known-issues), which is caused by the same UTC-midnight pattern.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/features/onboarding/state/onboarding_notifier.dart` | 49 | `setDate` — missing future-date guard |
| `lib/features/onboarding/onboarding_screen.dart` | 476–484 | `_pickDate` — `lastDate: now` is local, not UTC; relies on picker UI only |
| `test/features/onboarding/state/onboarding_notifier_test.dart` | 39–46 | `setDate` test does not include a future-date rejection case |

#### Fix sketch

In `onboarding_notifier.dart`, guard `setDate` at the notifier boundary (defence in depth: the UI picker already constrains to today, but the notifier must not depend on the UI for correctness):

```dart
void setDate(DateTime date) {
  final now = DateTime.now();
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  if (date.isAfter(todayUtc)) return;   // silently ignore; UI cannot produce this
  state = state.copyWith(lastPeriodDate: date);
}
```

Add two test cases to `onboarding_notifier_test.dart`:
1. `setDate` with tomorrow → `lastPeriodDate` remains null.
2. `setDate` with today UTC midnight → `lastPeriodDate` is set (regression for the UTC+N near-midnight edge case).

---

### Onboarding — Risks

1. **Duplicate anchor corruption (Issue #28)** is a data-integrity risk affecting all new users on their first install if they encounter any crash or process kill between onboarding submit and the `markOnboardingComplete` write. On Android, OOM kills during DB flush on low-memory devices make this non-theoretical. On the no-log path (all new users), duplicate anchors are permanent and affect cycle prediction correctness indefinitely.

2. **Future-date anchor (Issue #29)** is a logic-correctness risk. The UI picker does constrain to today, so the exposure surface in production is: (a) the UTC+N near-midnight window where UTC midnight of the picked day is marginally ahead of the current UTC instant, or (b) a future caller of the public `setDate` API. Risk (a) is low-frequency but real; risk (b) is a maintenance risk that grows as the codebase evolves.

3. **Transaction option A** requires adding a new provider binding in `use_case_providers.dart` and wiring `DriftTransactionRunner`. This touches the provider graph at a point that is shared across features — test coverage of the wiring is mandatory.

---

### Onboarding — Tech debt

1. **Dead anchor insert on the `hasFlowLogs` branch** (`complete_onboarding.dart:46–54`): when `hasFlowLogs` is true, `_recompute()` immediately calls `_cycleRepo.replaceAll(entries)` which deletes the anchor just inserted. The insert is wasted work. The anchor should only be inserted when `!hasFlowLogs`, or the branch structure should be reorganised so the insert is conditional.

2. **`periodLength` from onboarding is discarded on the `hasFlowLogs` branch**: when `_recompute()` runs, it derives `periodLength` from `flowDayCount` of each log-derived group and calls `replaceAll`, wiping the user's declared `periodLength`. The onboarding answer is silently ignored. This is a product-level correctness question but is technically a silent data drop.

3. **No use-case boundary validation on `cycleLength`/`periodLength`**: only the UI clamps `cycleLength` to `[21, 45]` and `periodLength` to `[1, 8]`. `CompleteOnboarding.execute` passes these values unchecked to the DB. A non-UI caller (future automation, restore path, test) can write out-of-range values. A guard at the use-case boundary would close this.

4. **Test coverage gap**: `complete_onboarding_test.dart` has no test for the transaction/idempotency contract (double-execute should produce one anchor, not two). `onboarding_notifier_test.dart` has no future-date rejection test. Both are regressions waiting to be introduced.

---

## Module: Notifications

**Path**: `lib/data/services/notification_service.dart`, `lib/domain/use_cases/schedule_prediction_notification.dart`, `lib/app.dart`, `lib/providers/use_case_providers.dart`
**Agent**: bug-hunter

---

### Issue #31 — iOS permission-denied on first launch does not revert `notificationsEnabled` to false

#### Root cause

Both `requestPermission()` and `hasNotificationPermission()` in `FlutterNotificationService` resolve the platform plugin via `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()`. When this returns `null` (which it always does on iOS), both methods short-circuit with `return true`, unconditionally reporting that permission is granted regardless of the OS reality.

`requestPermission()` (`lib/data/services/notification_service.dart:223–234`):

```dart
final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>();
if (androidPlugin == null) return true;   // iOS always hits this branch
return await androidPlugin.requestNotificationsPermission() ?? true;
```

`hasNotificationPermission()` (`lib/data/services/notification_service.dart:237–247`): identical structure — `androidPlugin == null` → `return true`.

These two methods are the only permission signals used by two separate code paths in `app.dart`:

1. **Settings listener** (lines 204–217): calls `requestPermission()` when the user flips the toggle on. On iOS the call returns `true` (grant reported) without ever showing the OS dialog or checking OS reality. The OS dialog is never triggered; the flag is never reverted when the user denies the system prompt.

2. **Cold-start revert** (`_verifyNotificationPermissionOnColdStart()`, lines 91–105): calls `hasNotificationPermission()`. On iOS returns `true` regardless of OS grant state. A user who revoked Notifications in iOS Settings will see `notificationsEnabled: true` in the DB persist forever — the revert branch (`if (!granted)`) never fires.

The root trigger is that `DarwinInitializationSettings(requestAlertPermission: true, requestSoundPermission: true, requestBadgePermission: true)` in `FlutterNotificationService._init()` auto-requests iOS permission at `initialize()` time. This makes the app trigger the iOS system dialog on cold-start rather than on the user's explicit toggle — contrary to FR-07 and the "no nag" voice — while the explicit-toggle path (`requestPermission()`) silently becomes a no-op on iOS.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/notification_service.dart` | 67–78 (`DarwinInitializationSettings`) | Auto-request on init — wrong trigger point |
| `lib/data/services/notification_service.dart` | 223–234 (`requestPermission`) | iOS blind spot — always returns true |
| `lib/data/services/notification_service.dart` | 237–247 (`hasNotificationPermission`) | iOS blind spot — always returns true |
| `lib/app.dart` | 91–105 (`_verifyNotificationPermissionOnColdStart`) | Consumes broken `hasNotificationPermission` |
| `lib/app.dart` | 204–217 (settings listener permission block) | Consumes broken `requestPermission` |
| `test/app_notification_wiring_test.dart` | — | No iOS permission-denied scenario tested |

#### Fix sketch

1. Remove `requestAlertPermission: true`, `requestSoundPermission: true`, `requestBadgePermission: true` from `DarwinInitializationSettings` so `initialize()` no longer auto-requests the iOS system dialog.

2. In `requestPermission()`, after the Android branch, add an iOS branch:
   ```dart
   final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
       IOSFlutterLocalNotificationsPlugin>();
   if (iosPlugin != null) {
     return await iosPlugin.requestPermissions(
       alert: true, badge: true, sound: true,
     ) ?? false;
   }
   return false; // unknown platform — fail safe
   ```

3. In `hasNotificationPermission()`, add an iOS branch using `checkPermissions()`:
   ```dart
   final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
       IOSFlutterLocalNotificationsPlugin>();
   if (iosPlugin != null) {
     final perms = await iosPlugin.checkPermissions();
     return perms?.isEnabled ?? false;
   }
   return false;
   ```

4. Add a widget test in `test/app_notification_wiring_test.dart`: FakeNotificationService returns `false` from `requestPermission()`, user toggles notifications on → expect `save()` called with `notificationsEnabled: false`.

---

### Issue #32 — `PlatformException` from `zonedSchedule` swallowed silently

#### Root cause

`FlutterNotificationService.schedulePredictionNotification()` catches `PlatformException` at lines 210–214:

```dart
} on PlatformException catch (e) {
  debugPrint(
    'FlutterNotificationService: zonedSchedule failed (${e.code}): ${e.message}',
  );
}
```

The exception is logged to the debug console but the method returns normally (no rethrow, no return value change). The call sites in `SchedulePredictionNotification.execute()` (`lib/domain/use_cases/schedule_prediction_notification.dart:61`) receive no signal that scheduling failed. The user's notification toggle remains `true` in the DB; no UI feedback is shown.

Additionally, `app.dart` has two dead `PlatformException` catches — lines 167–169 (prediction listener) and lines 247–249 (settings listener) — that can never fire because `FlutterNotificationService` already swallows the exception before it propagates. These dead catches create the false impression that the call site handles failures when it does not.

The primary scenario is Android: `SCHEDULE_EXACT_ALARM` permission revoked by the user after grant. `zonedSchedule()` throws `PlatformException(error, Cannot schedule exact alarm, ...)`. The user sees no indication that their next cycle notification is silently lost.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/notification_service.dart` | 210–214 | Swallows PlatformException, returns void |
| `lib/app.dart` | 167–169 | Dead catch — never reached |
| `lib/app.dart` | 247–249 | Dead catch — never reached |
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 61 | Call site receives no failure signal |
| `test/data/services/notification_service_test.dart` | BUG-006 group | Tests that exception is logged, not surfaced — documents current broken behavior |

#### Fix sketch

Decision required: the fix strategy depends on desired UX severity.

**Option A — propagate as return value** (recommended for "no nag" voice):
Change `schedulePredictionNotification()` signature to `Future<bool>` (returns `false` on `PlatformException`). `SchedulePredictionNotification.execute()` propagates the bool. The settings listener in `app.dart` receives the bool and shows a `SnackBar` explaining that scheduling failed (without reverting the toggle — the user's intent is preserved, and they can retry later).

**Option B — rethrow** (simpler, breaks existing callers):
Rethrow the `PlatformException` from the service. Remove the dead catches in `app.dart` and replace them with substantive handlers that surface a SnackBar.

Either way, remove the two dead `PlatformException` catches from `app.dart:167-169` and `247-249` and replace with real handlers or delete them if the service now surfaces failure another way.

Update `test/data/services/notification_service_test.dart` BUG-006 group to assert the new propagation contract (not just `debugPrint`).

---

### Issue #33 — Notification cancel-then-reschedule has no atomicity test — old alarm may fire mid-rebuild

#### Root cause

`SchedulePredictionNotification.execute()` at `lib/domain/use_cases/schedule_prediction_notification.dart:36`:

```dart
await _notifService.cancelPredictionNotifications();
```

This unconditional pre-cancel fires before every scheduling path, including the normal "reschedule because prediction changed" path. Between the `cancel` completing and the new `zonedSchedule` completing, there is a window where no notification is registered. If the device fires a previously-scheduled alarm during this window, the system has already been told to cancel — the alarm fires but the plugin discards it. More critically: if `zonedSchedule` fails (Issue #32) after the cancel, the notification is permanently lost with no registered future alarm.

The atomicity risk is an implementation artifact, not a fundamental requirement. `flutter_local_notifications` `zonedSchedule()` called with the same stable notification ID (`kPredictionNotificationId = 1001`) replaces the existing notification atomically at the plugin level without requiring an explicit prior cancel. The cancel-first pattern provides no correctness benefit on the replace path and introduces the gap for free.

The existing EC-15 test in `test/domain/use_cases/schedule_prediction_notification_test.dart` ("two execute() calls → cancelCount==2, scheduled length==1") asserts idempotency of the end state but does not test the intermediate state (i.e., "no notification registered between cancel and reschedule"). The absence of this test means the gap is not contractually guarded.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 36 | Unconditional pre-cancel |
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 47–75 | Scheduling paths — cancel not needed before line 61 |
| `test/domain/use_cases/schedule_prediction_notification_test.dart` | EC-15 group | Tests end-state idempotency but not intermediate state |
| `test/helpers/fake_notification_service.dart` | `cancelCount` field | Available for atomicity assertions |

#### Fix sketch

1. Remove the unconditional `await _notifService.cancelPredictionNotifications()` at line 36.

2. On the two early-return paths where no notification should remain, add explicit cancel:
   - `prediction == null` path (line ~47): cancel after the null check.
   - `settings.notificationsEnabled == false` path (line ~53): cancel after the disabled check.

3. On the normal scheduling path (line 61 forward), call `zonedSchedule()` directly without prior cancel. The stable ID 1001 provides replace semantics.

4. Add a test to `schedule_prediction_notification_test.dart` asserting that when `execute()` is called with a valid prediction, `cancelCount == 0` (no spurious cancel) and `scheduled.length == 1`. This makes the atomicity contract explicit and detectable.

5. Separately, add a test for the "cancel + schedule fails" scenario: if `zonedSchedule` throws, verify that a notification cancel was not issued before the failure (i.e., that the original alarm is still registered). This test is only possible after Issue #32 is fixed (the failure must propagate to be observable).

---

### Issue #35 — Notification alarm wall-clock instant is fixed at schedule time — timezone change not reflected at fire time

#### Root cause

`FlutterNotificationService.schedulePredictionNotification()` at `lib/data/services/notification_service.dart:206–207`:

```dart
uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
```

`absoluteTime` tells the iOS notification system to fire the alarm at the exact UTC instant computed at schedule time. When the device moves to a different timezone, the alarm still fires at the original UTC instant — which now corresponds to a different local time. A user who schedules a 09:00 notification before flying from Rome (UTC+2) to Tokyo (UTC+9) will receive the notification at 16:00 Tokyo local time instead of 09:00.

`UILocalNotificationDateInterpretation.wallClockTime` would cause iOS to fire the alarm at the same wall-clock time (09:00) in whatever timezone the device is in at fire time, which is the correct behavior for a "daily reminder at 09:00."

On Android the behavior is different: `AlarmManager` in RTC mode fires at an absolute UTC timestamp. Timezone changes do not recompute pending alarms. The fix on Android requires listening for `Intent.ACTION_TIMEZONE_CHANGED` at the platform layer and triggering a Dart-side reschedule. This is substantially more complex than the iOS fix and has a different root mechanism.

#### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/notification_service.dart` | 206–207 | `absoluteTime` — wrong interpretation for timezone resilience on iOS |
| `lib/data/services/notification_service.dart` | 193–209 (`schedulePredictionNotification`) | Full `zonedSchedule` call site |
| `android/app/src/main/kotlin/` | — | No `TIMEZONE_CHANGED` broadcast receiver exists |
| `test/data/services/notification_service_test.dart` | `computeScheduledTz` group | Tests correct tz computation at schedule time, not at fire time after device move |

#### Fix sketch

**iOS (lower risk, self-contained):**

Change line 206–207:
```dart
// Before:
uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,

// After:
uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.wallClockTime,
```

Verify that `computeScheduledTz()` still passes its existing tests — the computation is unaffected; only the iOS scheduler interpretation changes.

**Android (higher risk, requires platform code):**

Add a Kotlin `BroadcastReceiver` in `android/app/src/main/kotlin/` listening for `Intent.ACTION_TIMEZONE_CHANGED`. On receipt, invoke a `MethodChannel` call to Dart. On the Dart side, add a `MethodChannel` handler in `main.dart` or `app.dart` that calls `ref.read(schedulePredictionNotificationProvider.future)` and re-executes with current state from `ref.read(settingsNotifierProvider).valueOrNull` and `ref.read(cyclePredictionProvider).valueOrNull`.

This Android fix requires:
1. `AndroidManifest.xml` addition: `<receiver android:name=".TimezoneChangeReceiver">` with `<intent-filter><action android:name="android.intent.action.TIMEZONE_CHANGED"/></intent-filter>`
2. New Kotlin file `TimezoneChangeReceiver.kt`
3. New `MethodChannel` handler on the Dart side

The Android fix crosses two layers (native + Dart) and should be treated as a separate sub-task from the iOS fix.

---

### Notifications — Risks

**R1 — iOS auto-request removal (Issue #31 fix) breaks first-launch UX.**
Removing `requestAlertPermission: true` from `DarwinInitializationSettings` means the iOS permission dialog will no longer appear on first cold-start. It will appear only when the user explicitly enables notifications in the Settings screen. This is the correct behavior per FR-07 and the "no nag" voice, but it requires verifying on a physical iOS device via TestFlight (no iOS simulator locally). If the first-launch toggle-to-enable path in `IOSFlutterLocalNotificationsPlugin.requestPermissions()` is called before `initialize()` completes, behavior is undefined. Confirm initialization order.

**R2 — Removing unconditional pre-cancel (Issue #33 fix) depends on stable-ID replace semantics being guaranteed.**
The fix assumes `zonedSchedule(id, ...)` with the same ID atomically replaces any existing notification. This is documented behavior in `flutter_local_notifications` but should be verified against v17.2.4 changelog before the unconditional cancel is removed. A regression here would result in duplicate notifications silently accumulating.

**R3 — `wallClockTime` on iOS (Issue #35 fix) changes fire semantics for all existing scheduled alarms.**
Alarms scheduled with `absoluteTime` will be replaced by alarms scheduled with `wallClockTime` after the next `zonedSchedule()` call. For users who have not changed timezone, the fire time is identical. For users mid-timezone-change the transition behavior depends on iOS scheduling internals. This is low-risk in practice but should be noted in the commit message.

**R4 — Android `TIMEZONE_CHANGED` receiver (Issue #35 partial fix) adds platform code with no local test path.**
Because development is on Fedora Linux with no iOS simulator, the Android receiver can be tested on the Android emulator. However the interaction between the Kotlin receiver → MethodChannel → Dart reschedule is an integration that has no existing test pattern in this codebase. Plan for a manual smoke test on a physical Android device with timezone changed mid-cycle.

**R5 — Issue #32 fix (surfacing PlatformException) changes the public contract of `NotificationService`.**
If `schedulePredictionNotification()` becomes `Future<bool>`, all mock and fake implementations must be updated. `FakeNotificationService` and any test doubles must be updated in the same commit. The `SchedulePredictionNotification` use case return type may also need to change if callers need the signal.

---

### Notifications — Tech debt

**TD1 — `notificationServiceProvider` is a plain `Provider`, not `FutureProvider`.**
`FlutterNotificationService` calls `initialize()` in its constructor via `_init()`. This is a fire-and-forget async call — the plugin may not be initialized when the first scheduling call arrives, leading to undefined behavior. `notificationServiceProvider` should become a `FutureProvider` (or the initialization should be awaited before the provider is considered ready). The current `schedulePredictionNotificationProvider` already uses `FutureProvider` to await initialization, which partially mitigates this, but `requestPermission()` and `hasNotificationPermission()` are called directly on `notificationServiceProvider` without waiting for initialization.

**TD2 — iOS `IOSFlutterLocalNotificationsPlugin` vs `DarwinFlutterLocalNotificationsPlugin` naming.**
In `flutter_local_notifications` v17+, the iOS plugin implementation class is `IOSFlutterLocalNotificationsPlugin`. A future major version may rename it to `DarwinFlutterLocalNotificationsPlugin` (to unify iOS and macOS). When upgrading past v18, verify the class name in the pub cache at `$PUB_CACHE/hosted/pub.dev/flutter_local_notifications-*/lib/src/platform_specifics/darwin/`.

**TD3 — Dead `PlatformException` catches in `app.dart` obscure the real error boundary.**
Lines 167–169 and 247–249 are unreachable. Even after Issue #32 is fixed, if the chosen fix is "return bool" rather than "rethrow," these catches remain dead. Either route the failure signal through return values and remove the catches, or rethrow and make the catches substantive. Dead catches are a maintenance hazard: future developers will assume they handle something.

**TD4 — No test for the iOS `DarwinInitializationSettings` auto-request path.**
The existing `FakeNotificationService` does not simulate the `initialize()`-triggers-permission-dialog behavior. A test that verifies "no permission dialog on cold-start when `notificationsEnabled: false`" does not exist. This test would have caught Issue #31 before it reached production.

**TD5 — `computeScheduledTz()` is tested for correctness at schedule time but not for timezone-shift resilience.**
The existing tests in `notification_service_test.dart` fix `tz.local` to a static timezone. There is no test that calls `computeScheduledTz()` with one timezone, then simulates the device moving to another timezone, and verifies the rescheduled time is correct. Adding such a test would provide a regression guard for Issue #35 at the unit level.

---

## Spec Inputs

### Affected files (consolidated)

| Module | File | Relevance |
|---|---|---|
| Settings | `lib/domain/entities/app_settings_data.dart` | `copyWith` sentinel bug (#16), missing entity validation (#22) |
| Settings | `lib/features/settings/settings_screen.dart` | Theme picker bare constructor (#13), time picker rounding (#21), days picker UI guard (#22) |
| Settings | `lib/features/settings/state/settings_notifier.dart` | In-memory corruption on save (#13) |
| Settings | `lib/data/repositories/drift_app_settings_repository.dart` | `_toCompanion` exclusion policy (#13), read-time clamp (#22) |
| Settings | `lib/domain/use_cases/schedule_prediction_notification.dart` | Late `ArgumentError` guard (#22); also owned by Notifications module |
| CSV | `lib/domain/services/csv_codec.dart` | `pain_intensity=0` off-by-one in decode (#20) |
| CSV | `lib/domain/use_cases/import_daily_logs.dart` | `deleteAndImport` no precondition (#18) |
| CSV | `lib/l10n/app_localizations_en.dart` | Missing confirmation strings (#18) |
| CSV | `lib/l10n/app_localizations_it.dart` | Missing confirmation strings (#18) |
| CSV | `test/domain/services/csv_codec_test.dart` | Missing `pain_intensity=0` round-trip test (#20) |
| Backup | `lib/data/repositories/drift_daily_log_repository.dart` | `deleteAll()` bumps write timestamp (#11) |
| Backup | `lib/domain/use_cases/delete_all_data.dart` | Fix site: post-delete alignment (#11) |
| Backup | `lib/providers/use_case_providers.dart` | `DeleteAllData` wiring; also Onboarding `TransactionRunner` wiring (#11, #28) |
| Backup | `lib/data/services/backup/sync_orchestrator.dart` | Prune loop, retention policy (#12) |
| Backup | `lib/data/services/backup/backup_filename.dart` | `parseTimestamp()` utility (#12) |
| Backup | `lib/data/services/backup/dropbox_provider.dart` | `listFiles()` / `deleteFile()` contracts (#12) |
| Backup | `lib/features/backup/state/backup_notifier.dart` | Skip guard logic (#11) |
| Backup | `lib/app.dart` | Cold-start `backupSilent()` trigger (#11); dead `PlatformException` catches (#32); notification wiring (#31) |
| Backup | `test/features/backup/state/backup_notifier_test.dart` | Missing delete-all → backupSilent test (#11) |
| Backup | `test/data/services/backup/sync_orchestrator_test.dart` | "deletes older files" assertion will break (#12) |
| Onboarding | `lib/domain/use_cases/complete_onboarding.dart` | No transaction wrapper (#28) |
| Onboarding | `lib/data/database/daos/cycle_entry_dao.dart` | No uniqueness guard on `startDate` (#28) |
| Onboarding | `lib/domain/repositories/cycle_entry_repository.dart` | No upsert variant (#28) |
| Onboarding | `lib/features/onboarding/state/onboarding_notifier.dart` | `setDate` unguarded (#29) |
| Onboarding | `lib/features/onboarding/onboarding_screen.dart` | `_pickDate` local-time guard (#29) |
| Onboarding | `test/domain/use_cases/complete_onboarding_test.dart` | No duplicate-anchor / crash-retry test (#28) |
| Onboarding | `test/features/onboarding/state/onboarding_notifier_test.dart` | No future-date rejection test (#29) |
| Notifications | `lib/data/services/notification_service.dart` | iOS permission blind spot (#31), swallowed PlatformException (#32), `absoluteTime` (#35) |
| Notifications | `lib/domain/use_cases/schedule_prediction_notification.dart` | Unconditional pre-cancel (#33); also late guard (#22 from Settings) |
| Notifications | `test/app_notification_wiring_test.dart` | No iOS permission-denied scenario (#31) |
| Notifications | `test/data/services/notification_service_test.dart` | BUG-006 group documents broken behavior (#32) |
| Notifications | `test/domain/use_cases/schedule_prediction_notification_test.dart` | EC-15 tests end-state only, not intermediate state (#33) |
| Notifications | `test/helpers/fake_notification_service.dart` | `cancelCount` field; must be updated if #32 changes signature |
| Notifications | `android/app/src/main/kotlin/` | No `TIMEZONE_CHANGED` receiver (#35) |
| Notifications | `android/app/src/main/AndroidManifest.xml` | Receiver registration needed (#35) |

---

### Key risks (consolidated)

| ID | Risk | Source module | Severity |
|---|---|---|---|
| R-CRIT-1 | Issue #11: delete-all followed by cold-start uploads empty encrypted blob to Dropbox, **silently destroying the user's only backup**. No recovery path exists once overwritten. | Backup | Critical |
| R-CRIT-2 | Issue #28: crash between onboarding step 1 and step 4 produces duplicate anchor entries that corrupt cycle prediction permanently (no-log path). Affects all new installs on low-memory Android devices. | Onboarding | Critical |
| R-HIGH-1 | Issue #13: switching to System theme durably overwrites `notificationTimeMinutes` and `firstDayOfWeek` in the DB. User loses configured notification time silently. | Settings | High |
| R-HIGH-2 | Issue #18: `deleteAndImport` mode irrevocably erases all user data with a single tap and no confirmation. WCAG SC 3.3.4 violation. | CSV | High |
| R-HIGH-3 | Issue #31: iOS notification permission is never correctly requested or checked. Toggle stays `true` even after OS denial. Auto-requests on cold-start (wrong trigger). Blocks #35 testing on iOS. | Notifications | High |
| R-HIGH-4 | Issue #32: `PlatformException` from `zonedSchedule` (e.g., `SCHEDULE_EXACT_ALARM` revoked on Android) is silently swallowed. User loses scheduled notification with no feedback. Dead catches in `app.dart` mask the gap. | Notifications | High |
| R-MED-1 | Issue #16 blocks Issue #13 clean fix. Any patch of #13 without #16 creates a recurring maintenance trap for every future nullable field. | Settings | Medium |
| R-MED-2 | Issue #20: `pain_intensity=0` round-trip data loss. On import, entire row (symptoms + notes) is silently dropped due to `continue` after parse error. | CSV | Medium |
| R-MED-3 | Issue #12: single-backup retention means one corrupt upload leaves user with no fallback. | Backup | Medium |
| R-MED-4 | Issue #33: unconditional pre-cancel creates a gap where no notification is registered. If #32 is also present, a scheduling failure after cancel permanently loses the alarm. | Notifications | Medium |
| R-MED-5 | Issue #11 edge: `lastBackupAt == null` + delete-all → cold-start uploads empty snapshot as if it were a first-ever backup. | Backup | Medium |
| R-MED-6 | Issue #12: `FakeDropboxProvider` may return files in insertion order (not descending), producing wrong retention slots. Must be audited before shipping the retention fix. | Backup | Medium |
| R-LOW-1 | Issue #21: off-grid `notificationTimeMinutes` (from future migration or CSV import) silently rounded on picker re-open. Low frequency today; grows as data paths multiply. | Settings | Low |
| R-LOW-2 | Issue #22: `notificationDaysBefore = 0` crashes `SchedulePredictionNotification` at runtime with no traceable origin. Only reachable via non-UI callers today. | Settings | Low |
| R-LOW-3 | Issue #29: future-date anchor in `setDate` corrupts prediction. Primarily a maintenance risk; UI guard exists but notifier is unguarded. | Onboarding | Low |
| R-LOW-4 | Issue #35 iOS: `absoluteTime` fires at wrong local time after timezone change. Low-frequency for typical users. | Notifications | Low |
| R-LOW-5 | Issue #35 Android: no `TIMEZONE_CHANGED` receiver exists. Fix requires native Kotlin + MethodChannel — no existing test pattern. | Notifications | Low |

---

### Tech debt (prioritized)

Items listed where earlier resolution unblocks or simplifies multiple bug fixes.

| Priority | Item | Module | Rationale |
|---|---|---|---|
| 1 | **`Nullable<T>` sentinel in `AppSettingsData.copyWith`** (Issue #16 fix) | Settings | Unblocks clean fix for #13. Without it, every nullable-field workaround will repeat the bare-constructor pattern. Document as project-wide standard for nullable preference fields. |
| 2 | **`AppSettingsData` split into `AppPreferencesData` / `AppSystemStateData`** | Settings | Removes comment-only enforcement of `_toCompanion` exclusion list. Prevents future saves from accidentally overwriting `dropboxEmail`, `lastBackupAt`, etc. Compiler-enforced boundary. |
| 3 | **`NotificationService.schedulePredictionNotification()` return type `Future<bool>`** (Option A for #32) | Notifications | Unblocks #33 "cancel + schedule fails" atomicity test. Required before dead `app.dart` catches (TD3) can be meaningfully removed. Requires updating `FakeNotificationService` and test doubles. |
| 4 | **`deleteAll()` semantics split: `deleteAllForRestore()` vs `deleteAll()`** | Backup | Makes intent explicit at call site. Eliminates overloaded semantics that caused #11. Pairs with #11 fix in `DeleteAllData`. |
| 5 | **`_retentionSet` extracted to separate test file** (`backup_retention_test.dart`) | Backup | Required companion to #12 fix. The pure static helper must be unit-tested independently before the orchestrator integration test is updated. |
| 6 | **Shared pain-intensity range constants** (`kPainIntensityMin`, `kPainIntensityMax`) | CSV | Eliminates duplication between `csv_codec.dart` and `SaveDailyLog`. Prevents future drift if pain range ever expands. |
| 7 | **`_handleImport` extraction into dedicated controller** | CSV | 110-line static method mixing I/O, dialogs, and mode dispatch. Any touch to this method (required for #18 fix) is an opportunity to split. |
| 8 | **`notificationsServiceProvider` → `FutureProvider`** (TD1) | Notifications | `initialize()` is fire-and-forget. `requestPermission()` and `hasNotificationPermission()` called before initialization completes risk undefined behavior. |
| 9 | **`notificationTimeMinutes` entity-level validation** | Settings | Same gap as #22 for `notificationDaysBefore`; both should land in the same commit. Legal range [0, 1439]. |
| 10 | **`catch (_) {}` on import execute → at minimum `debugPrint`** | CSV | Silent swallow makes production failures undiagnosable. Trivial one-line fix. |

---

### Integration points

Cross-module boundaries and external system touches identified across all five assessments:

1. **Settings entity → Notifications use case** (`app_settings_data.dart` → `schedule_prediction_notification.dart`): `notificationDaysBefore` and `notificationTimeMinutes` flow from the Settings entity into the scheduling use case. Entity-level validation fixes (#22) directly affect the notification scheduling path. Fix ordering: validate at entity first, then remove redundant use-case guard.

2. **Settings notifier → Backup notifier** (`settings_notifier.dart` → `backup_notifier.dart`): `SettingsNotifier.save` puts a malformed object into reactive state (#13). `backupNotifierProvider` reads `dropboxEmail` from that state. Backup row display corrupts transiently until the Drift stream re-emits. Both notifiers watch the same `settingsNotifierProvider`.

3. **Delete-all use case → Backup skip guard** (`delete_all_data.dart` → `backup_notifier.dart` via `lastLogOrSymptomWriteAt`): the root of Issue #11. The timestamp written by `deleteAll()` is indistinguishable from a real data write, tricking the skip guard into uploading an empty snapshot.

4. **CSV `deleteAndImport` → Backup consistency** (Issue #18 + Issue #20 interaction): fixing #20 increases the number of rows that parse successfully, making the unguarded `deleteAndImport` path in #18 more destructive. Both must be fixed together or #18 first.

5. **Onboarding `CompleteOnboarding` → provider graph** (`use_case_providers.dart`): adding `DriftTransactionRunner` for #28 requires a new binding in `use_case_providers.dart` — the same file that needs `AppSettingsRepository` injected into `DeleteAllData` for #11. Both provider graph changes should land in the same commit to avoid double-touch of a shared wiring file.

6. **Notification service → iOS platform layer** (Issue #31 + #35): the `DarwinInitializationSettings` change (#31 fix) and the `wallClockTime` change (#35 fix) both modify `FlutterNotificationService._init()` / `schedulePredictionNotification()`. They must be coordinated so that `initialize()` does not auto-request permission AND the scheduler uses the correct interpretation. Both require TestFlight verification (no iOS simulator locally).

7. **Notification `PlatformException` propagation → atomicity contract** (Issue #32 → #33 dependency): the atomicity test for #33 ("cancel + schedule fails → original alarm preserved") can only be written after #32 is fixed and the failure propagates out of the service layer. Fix #32 before writing the #33 regression test.

8. **`settings_screen.dart` as shared UI host**: this single file is the bug site or secondary site for Issues #13, #18, #21, #22. Concurrent edits risk conflicts. Coordinate all Settings-module fixes into a single wave or serialize them clearly.

9. **External system: Dropbox API** (`dropbox_provider.dart`): Issues #11 and #12 both modify how and when files are uploaded/deleted. `listFiles()` sort order is a contract assumption shared by both fixes. Verify `FakeDropboxProvider` sort order before testing either fix.

---

### Proposed scope boundaries

**In scope**:
- Issue #11: suppress auto-backup after delete-all (align `lastLogOrSymptomWriteAt` post-delete in `DeleteAllData`)
- Issue #12: implement 3-slot backup retention policy (current + previous + monthly)
- Issue #13: fix theme→System bare constructor overwriting `notificationTimeMinutes` / `firstDayOfWeek`
- Issue #16: implement `Nullable<T>` sentinel in `AppSettingsData.copyWith` to enable #13 clean fix
- Issue #18: add secondary confirmation dialog before `deleteAndImport` execution
- Issue #20: fix `pain_intensity=0` off-by-one in CSV decode (`pv < 1` → `pv < 0`) + update error string
- Issue #21: separate display seed from save baseline in `_showCupertinoTimePicker`
- Issue #22: add entity-level assert for `notificationDaysBefore` range; surface DB corruption instead of masking it
- Issue #28: add transaction wrapper (or idempotent insert) to `CompleteOnboarding.execute`; add regression test
- Issue #29: guard `OnboardingNotifier.setDate` against future dates using UTC calendar-day comparison
- Issue #31: fix iOS permission methods (`requestPermission`, `hasNotificationPermission`); remove auto-request from `DarwinInitializationSettings`
- Issue #32: surface `PlatformException` from `zonedSchedule` as `Future<bool>` return value; remove dead catches from `app.dart`
- Issue #33: remove unconditional pre-cancel; add explicit cancel only on null-prediction and disabled-notifications paths
- Issue #35 iOS: change `absoluteTime` → `wallClockTime` (self-contained, verified via TestFlight)
- Companion tests for every fix (as specified per-issue above)

**Out of scope**:
- Issue #35 Android: `TIMEZONE_CHANGED` BroadcastReceiver + MethodChannel + Dart reschedule handler — crosses native layer, no existing test pattern, treat as a separate sub-task after the initiative closes
- `AppSettingsData` entity split into `AppPreferencesData` / `AppSystemStateData` — architectural refactor, not a bug fix; tracked as tech debt but deferred
- `_handleImport` extraction into dedicated controller — pre-existing structural debt; fix #18 in-place without the refactor
- `notificationsServiceProvider` → `FutureProvider` migration — requires broader provider graph audit; tracked as tech debt
- Dropbox provider or OneDrive/Google Drive parity — only Dropbox is in scope for this initiative
- Any new backup provider integration
- UI redesign of the settings screen or onboarding flow (fixes must preserve existing visual design; only add the confirmation dialog for #18)
