# Module: Settings
**Path**: lib/domain/entities/, lib/features/settings/, lib/data/repositories/
**Agent**: bug-hunter

---

## Issue #13 — Theme → System resets notificationTimeMinutes, firstDayOfWeek; corrupts Backup row display until stream re-emits

### Root cause

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

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | 418–429 | Bug site: bare constructor call omitting fields |
| `lib/domain/entities/app_settings_data.dart` | 89–123 | Root enabler: `copyWith` cannot pass `null` for `darkMode` (Issue #16) |
| `lib/features/settings/state/settings_notifier.dart` | 48–52 | Propagates the malformed state immediately via `state = AsyncData(settings)` |
| `lib/data/repositories/drift_app_settings_repository.dart` | 62–78 | `_toCompanion` limits DB damage but cannot prevent in-memory corruption |

### Fix sketch

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

## Issue #16 — `darkMode` cannot be reset to null (system theme) via `copyWith`

### Root cause

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

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/domain/entities/app_settings_data.dart` | 89–123 | Bug site: `copyWith` implementation |
| `lib/features/settings/settings_screen.dart` | 418–429 | Downstream: workaround that triggers #13 |

### Fix sketch

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

## Issue #21 — Re-opening notification time picker silently rounds stored value to nearest 5 minutes

### Root cause

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

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | 543–546 | Bug site: `currentMinutes` initialised to rounded seed |
| `lib/features/settings/settings_screen.dart` | 566–572 | Second instance: `onRestore` saves rounded seed |
| `lib/features/settings/settings_screen.dart` | 347–348 | `_roundTo5` helper — correct as a display helper, misused as save baseline |

### Fix sketch

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

## Issue #22 — `notificationDaysBefore` has no lower-bound validation at entity level

### Root cause

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

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/domain/entities/app_settings_data.dart` | 21–36 | Bug site: constructor accepts unconstrained int |
| `lib/data/repositories/drift_app_settings_repository.dart` | 51 | Clamp at read-time — symptom suppressor, not a fix |
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 39–45 | Late guard — use-case level, not entity level |
| `lib/features/settings/settings_screen.dart` | 591–592 | UI-level guard — invisible to non-UI callers |

### Fix sketch

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

## Risks

1. **Fix ordering dependency:** Issues #13 and #16 must be fixed together. Fixing #13 independently with a bare constructor workaround is fragile; fixing #16 first enables a clean #13 fix via `copyWith`. Any patch sequence that fixes #13 without #16 creates a maintenance trap: every future nullable field addition will repeat the pattern.

2. **`_toCompanion` exclusion list is implicit policy:** The set of fields excluded from `updateSettings` (dropboxEmail, lastBackupAt, declaredCycleLength, lastLogOrSymptomWriteAt) is enforced only by a comment at lines 62–67 of `drift_app_settings_repository.dart`. When Issue #16 is fixed and `copyWith` becomes sentinel-aware, callers may start passing `dropboxEmail`/`lastBackupAt` through the general settings save path. If those fields ever reach `_toCompanion`, they will be silently dropped (current behaviour) or — worse — if `_toCompanion` is updated to include them, future saves will overwrite values set by `updateBackupState`. The exclusion policy needs either a machine-enforced boundary (split the entity into a preferences-only DTO and a full-state DTO) or at minimum an integration test asserting that `updateSettings` never writes those columns.

3. **In-memory corruption window in #13:** Even after the fix, the `state = AsyncData(settings)` call in `SettingsNotifier.save` (line 51) creates a window where the notifier state and the DB differ by one Drift stream tick (~0 to tens of ms). This is by design (optimistic UI update), but it relies on the Drift stream firing promptly. If the stream is delayed (DB busy, test mock), the in-memory state is stale. This is not a new risk introduced by the fix, but it is worth noting that the fix does not eliminate the in-memory/DB divergence window — it only ensures the divergence carries the correct values.

4. **`onRestore` semantics after #21 fix:** After the fix, "Ripristina" restores the original stored value (including any off-grid value). If the stored value is off-grid, the wheel will remain at the rounded display position even after "Ripristina" writes the original. The visual inconsistency (wheel shows 09:05, stored value is 09:07) is acceptable because the wheel cannot represent off-grid values, but it should be documented in a code comment.

---

## Tech debt

1. **`copyWith` sentinel pattern should be applied uniformly.** The `Nullable<T>` wrapper introduced for `darkMode` (Issue #16 fix) should be documented as the project-standard pattern for nullable preference fields. Without this, the next developer adding a nullable field will likely reproduce the same bug.

2. **`AppSettingsData` should be split into two types.** The current entity carries both user-controlled preferences (languageCode, darkMode, notificationDaysBefore, etc.) and system-managed state (dropboxEmail, lastBackupAt, declaredCycleLength, lastLogOrSymptomWriteAt). The comment-only exclusion in `_toCompanion` is the only mechanism preventing the general settings save path from touching system-managed fields. A `AppPreferencesData` / `AppSystemStateData` split — or a `freezed`-generated union — would make the boundary compiler-enforced.

3. **`notificationTimeMinutes` has no entity-level validation.** Issue #22 requests entity-level validation for `notificationDaysBefore`; the same gap exists for `notificationTimeMinutes` (legal range [0, 1439]). The use-case guard at `schedule_prediction_notification.dart:47-53` provides late protection, but the entity constructor accepts any int. These two validations should be added in the same commit to avoid a partial fix.

4. **`SchedulePredictionNotification` validation is duplicated at the entity level once the fix lands.** After fixing #22, the entity-level `assert` for `notificationDaysBefore` and the use-case `ArgumentError` check are redundant. The use-case check can be removed or downgraded to a debug-only `assert` once the entity invariant is trusted.
