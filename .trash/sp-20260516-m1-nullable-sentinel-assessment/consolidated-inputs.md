# [SP-ASSESS] M1 — Nullable<T> sentinel — Consolidated Inputs

**Date**: 2026-05-16
**Source**: Synthesized from LP assessment (lp-20260516-next-patch-issues-assessment.md) §Module:Settings, Issue #16
**Scope**: FR-01 only — introducing `Nullable<T>` sentinel + updating `AppSettingsData.copyWith`

---

## Root Cause

`AppSettingsData.copyWith` (lines 89–123 of `lib/domain/entities/app_settings_data.dart`) uses the standard Dart nullable-override pattern for `darkMode`:

```dart
darkMode: darkMode ?? this.darkMode,
```

When a caller passes `darkMode: null`, the `??` operator treats `null` as "not provided" and falls back to `this.darkMode`. There is no way to distinguish "set this to null" from "omit this field." This is the root enabler of Issue #13.

---

## Affected Components and Files

| File | Lines | Role |
|------|-------|------|
| `lib/domain/entities/app_settings_data.dart` | 89–123 | Bug site: `copyWith` implementation — the only file in scope for M1 |
| `test/domain/entities/app_settings_data_test.dart` | 453–544 | Existing copyWith tests — extend, do NOT rewrite |

**No other files are in scope for M1.** The `settings_screen.dart` call-site fix is M2.

---

## Fix Contract (from LP assessment §Issue #16 Fix sketch)

### New class `Nullable<T>`

Location: inline in `lib/domain/entities/app_settings_data.dart` (above the `AppSettingsData` class) OR in a new `lib/core/utils/nullable.dart` file imported by the entity.

**Preference**: a standalone `lib/core/utils/nullable.dart` keeps the entity file focused. The LP plan describes `Nullable<T>` as a "project-wide pattern for nullable preference fields" — it belongs in `core/`, not embedded in one entity.

```dart
// GPL-3.0 header required
/// Sentinel wrapper to express "set this nullable field to null" in copyWith.
///
/// Usage: settings.copyWith(darkMode: const Nullable(null))
///
/// This is the project-standard pattern for nullable preference fields.
/// See: AppSettingsData.copyWith for the canonical consumer.
class Nullable<T> {
  const Nullable(this.value);
  final T? value;
}
```

### Updated `copyWith` signature (darkMode only — other fields unchanged)

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

**All existing callers that pass `Nullable(true)` or `Nullable(false)` for light/dark continue to work.**

---

## Constraints the Fix Must Respect

1. **Domain stays pure**: `Nullable<T>` must NOT import Flutter, Drift, or HTTP types. It is a pure Dart value object.
2. **No new runtime dependency**: `pubspec.yaml` unchanged.
3. **GPL-3.0 header** on any new source file.
4. **`dart format` + `flutter analyze` clean** before commit.
5. **M1 does NOT fix `settings_screen.dart`** — that is M2 scope.
6. **All existing `copyWith` tests must still pass** — the signature change must not break callers that use named `bool` parameters for non-darkMode fields.

---

## Test Coverage Baseline

`test/domain/entities/app_settings_data_test.dart` already tests `copyWith` at lines 453–544:
- Sets non-null fields (languageCode, painEnabled, notesEnabled, etc.)
- Does NOT include tests for setting `darkMode` to `null` (impossible with current API)

**Required new tests** (MC-02 from LP plan):
1. `copyWith(darkMode: const Nullable(false))` → `darkMode == false` (non-null set)
2. `copyWith(darkMode: const Nullable(null))` → `darkMode == null` (null sentinel)
3. `copyWith()` with darkMode omitted → `darkMode` unchanged from source (unchanged)

Test 2 ("set to null") must **fail** on pre-fix code and **pass** on post-fix code (FR-15 regression requirement).

---

## ## Spec Inputs

**Root cause**: `AppSettingsData.copyWith` cannot express `null` for `darkMode` — `??` conflates null-as-omit with null-as-value.

**Affected components and files**:
- `lib/domain/entities/app_settings_data.dart` (lines 89–123) — copyWith bug site and fix target
- `lib/core/utils/nullable.dart` (new) — `Nullable<T>` sentinel class
- `test/domain/entities/app_settings_data_test.dart` (lines 453–544) — extend with 3 new test cases

**Related latent bugs that should NOT be fixed in M1**:
- `dropboxEmail` / `lastBackupAt` have the same structural defect but are intentionally absent from `copyWith` (managed by dedicated writers). They are latent but harmless — do not extend `Nullable<T>` to them in M1.

**Constraints the fix must respect**:
- No Flutter/Drift/HTTP imports in `nullable.dart`
- No `pubspec.yaml` changes
- GPL-3.0 header on new file
- `settings_screen.dart` call-site update deferred to M2

**Test coverage baseline**:
- `app_settings_data_test.dart` lines 453–544 — existing copyWith tests pass; adding 3 darkMode cases
