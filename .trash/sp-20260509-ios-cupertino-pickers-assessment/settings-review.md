# Pre-implementation assessment — iOS Cupertino pickers
**Date**: 2026-05-09  
**Scope**: `lib/features/settings/settings_screen.dart` (`_showTimePicker` + `_showAdvancePicker`), `lib/features/settings/` directory, `lib/core/theme/` (`MetraColors`, `MetraTheme`), `test/features/settings/settings_screen_test.dart`

---

## Summary

Both picker methods are clean and well-bounded. The current Material implementations are in `settings_screen.dart:435–495`. No Cupertino code exists anywhere in `lib/` today. `MetraTheme.light()` and `MetraTheme.dark()` do **not** set `platform:` inside `ThemeData`, which removes one potential divergence footgun. Seven test points are catalogued below under **Spec Inputs**.

---

## Findings

### Critical

**C-1: `Platform.isIOS` (dart:io) must NOT be used for platform branching.**  
`lib/features/settings/settings_screen.dart` already imports `dart:io` (line 19) for `File`. `Platform.isIOS` from the same import reads the host OS at runtime — it is always `false` on the Fedora dev box and on the Linux CI runner. The iOS branch would be dead in every widget test.  
**Required**: use `defaultTargetPlatform == TargetPlatform.iOS` from `package:flutter/foundation.dart`. This is overridable via `debugDefaultTargetPlatformOverride` in `setUp`/`tearDown`, which is the only test-injectable mechanism available without an iOS simulator (CLAUDE.md §3 constraint).

### Important

**I-1: CupertinoDatePicker vs two manual CupertinoPickercolumns — decision required.**  
The feature description says "two columns (hours 0–23, minutes 0–55 in 5-min steps)". Flutter provides `CupertinoDatePicker(mode: CupertinoDatePickerMode.time, minuteInterval: 5)`, which renders exactly the described wheel columns natively, handles locale AM/PM, and handles the minutes interval. Building two parallel `CupertinoPicker` widgets achieves the same appearance but requires manual index math, column layout, and `FixedExtentScrollController` lifecycle. Both options are architecturally valid. The spec must commit to one with a stated rationale; leaving this implicit during implementation risks scope creep mid-build.

**I-2: `showCupertinoModalPopup` has no Cancel/Done buttons by default.**  
iOS convention wraps a Cupertino picker in a bottom sheet with a top toolbar (`CupertinoActionBar`-style row of Cancel + Done). A bare `showCupertinoModalPopup(builder: (_) => picker)` has no dismiss affordance beyond dragging. The current Material `showTimePicker` provides Cancel/OK natively. The spec must specify the modal chrome for both pickers (toolbar labels, button behavior, how cancel maps to the existing `if (tod == null) return;` guard at line 462).

**I-3: 5-minute snapping coexistence policy is undefined.**  
`drift_app_settings_repository.dart:45` clamps `notificationTimeMinutes` to `[0, 1439]` only — no divisibility-by-5 enforcement. Material `showTimePicker` can write any minute value (e.g., `09:13 = 553`). When the iOS picker opens with such a seed, `CupertinoDatePicker` displays the nearest 5-min interval visually but the stored value is not changed until the user dismisses with OK. Three policies to choose from:
- (a) **Display-snap only**: show the nearest interval, preserve the stored odd value on cancel, round to nearest 5 only on explicit confirm.
- (b) **Round-on-save**: `_showTimePicker` rounds `tod.minute` to the nearest multiple of 5 before calling `_save`.
- (c) **One-shot migration**: `getOrCreateSettings()` or the v7 migration normalises existing values to multiples of 5 on first open. This is the most disruptive and has no precedent in the codebase.
The spec must pick one. Option (a) is the smallest footprint. Option (b) has a deterministic test vector. Option (c) is a schema-layer concern and should only be chosen if the stored value matters outside the UI (e.g., if `SchedulePredictionNotification` one day validates divisibility).

**I-4: `CupertinoTheme` wrapping is greenfield — no precedent in `lib/`.**  
No Cupertino theming exists in `lib/core/theme/metra_theme.dart`. The approach to apply Métra color tokens to a `CupertinoPicker` or `CupertinoDatePicker` is:
```dart
CupertinoTheme(
  data: CupertinoThemeData(
    brightness: Theme.of(ctx).brightness,
    primaryColor: MetraColors.of(ctx).accentFlow,
    textTheme: CupertinoTextThemeData(
      pickerTextStyle: TextStyle(color: MetraColors.of(ctx).textPrimary),
    ),
  ),
  child: picker,
)
```
The spec must decide whether this wrapping lives inline at the callsite or in a shared utility. Given it is used in two places (`_showTimePicker`, `_showAdvancePicker`) and nowhere else, an inline approach follows the Rule of Three (CLAUDE.md §5) and avoids a premature shared abstraction.

### Suggestions

**S-1: `Theme.of(context).platform` vs `defaultTargetPlatform` — note the divergence risk.**  
Both resolve to `TargetPlatform.android` (or the test override) when `MetraTheme` is in use, because `MetraTheme.light()` and `.dark()` do not set `platform:`. However, any future addition of `platform:` to MetraTheme would silently diverge `Theme.of(context).platform` from `defaultTargetPlatform`. The spec should document the chosen mechanism explicitly.

---

## What was done well

- `_showTimePicker` and `_showAdvancePicker` are exactly as minimal as they should be: no business logic, no state, single-call functions that hand off immediately to the platform picker (lines 435–495).
- `dart:io` is already imported for the CSV export path; any Cupertino-branch PR does not add a new dependency.
- The test file's `_StubSettingsNotifier` pattern enables complete platform-stub replacement with three lines in `setUp`; adding `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` per test group is surgically clean.

---

## Spec Inputs

### Focus 1 — Current implementation of `_showTimePicker` and `_showAdvancePicker`

`_showTimePicker` (`settings_screen.dart:435–465`): async, seeds a `TimeOfDay` from `settings.notificationTimeMinutes`, calls `showTimePicker` with inline `TimePickerThemeData` override in `builder:`, converts `TimeOfDay` back to minutes on confirm. Cancel path: `if (tod == null) return;` at line 462.

`_showAdvancePicker` (`settings_screen.dart:467–496`): async, calls `showDialog<void>` with a `SimpleDialog` whose children are `kMaxAdvanceDays` (7) `SimpleDialogOption` rows. Selection triggers `Navigator.pop` + `_save`. No cancel-specific logic (dialog dismisses on outside-tap).

### Focus 2 — Platform branching import constraint

**Hard constraint**: use `defaultTargetPlatform` from `package:flutter/foundation.dart`. Do NOT use `Platform.isIOS` from `dart:io`. Rationale: `Platform.isIOS` is always `false` on Linux CI and dev, making the iOS branch dead in all widget tests. `defaultTargetPlatform` is overridable via `debugDefaultTargetPlatformOverride` in tests.

### Focus 3 — CupertinoPicker vs CupertinoDatePicker

`CupertinoDatePicker(mode: CupertinoDatePickerMode.time, minuteInterval: 5)`: native wheel, built-in 24h/12h locale handling, single widget for both hour and minute columns, `onDateTimeChanged` callback. Default column-separator character is `:`.

`CupertinoPicker` (manual two-column approach): requires two `FixedExtentScrollController` instances, `ListWheelScrollView`-based children, manual 0–23 and 0/5/10…55 lists, horizontal layout via `Row`. More code, same visual result.

`CupertinoTimerPicker`: shows duration (HH:MM), not time of day — wrong semantic for this feature.

OQ-PICKER-01: which approach? Lean toward `CupertinoDatePicker` for the time picker (one widget, locale-aware). The advance-days picker (1–7) has no `CupertinoDatePicker` mode — a single `CupertinoPicker` column is the only Cupertino option for that one.

### Focus 4 — CupertinoTheme wrapping

No Cupertino theming exists in `MetraTheme` today (verified: zero hits in `lib/core/theme/metra_theme.dart`). Apply inline at each callsite:
```dart
CupertinoTheme(
  data: CupertinoThemeData(
    brightness: Theme.of(ctx).brightness,
    primaryColor: MetraColors.of(ctx).accentFlow,
    textTheme: CupertinoTextThemeData(
      pickerTextStyle: TextStyle(color: MetraColors.of(ctx).textPrimary),
    ),
  ),
  child: picker,
)
```
Wrapping is per-callsite only (not a MetraTheme addition) unless more Cupertino widgets are added later.

### Focus 5 — Existing tests and the platform-conditional code

Tests at `:614` (`find.byType(TimePickerDialog)`) and the advance-picker dialog groups (`:385`, `:421`, `:471`, `:828`, `:862`, `:892`) run with the default `TargetPlatform.linux` (or `.android` — Linux widget-test default). With `defaultTargetPlatform`-based branching:
- The Android/default branch resolves for these tests → all existing assertions remain valid as **Android-path coverage**.
- No existing test breaks.
- **New iOS coverage** requires test groups with:
  ```dart
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  ```
  These must assert `find.byType(CupertinoDatePicker)` or `find.byType(CupertinoPicker)` (not `TimePickerDialog`).
- The keyboard-input test at `:655` (`Icons.keyboard_outlined`, `TextField` entry of `'13'`/`'45'`) has no Cupertino analogue — Cupertino pickers have no input mode. iOS coverage relies on scroll-position inspection or `find.byType` + notifier state assertion.

### Focus 6 — 5-minute step and non-multiple stored values

`drift_app_settings_repository.dart:45` clamps to `[0, 1439]` only. Any minute value written by the Material picker survives as-is. When the iOS Cupertino picker opens with such a seed (e.g., `553` = 09:13), it snaps the visual display to the nearest 5-min mark but does not write until dismiss. Three coexistence policies:
- (a) Display-snap only, no normalization — minimal code, preserves stored values.
- (b) Round-on-save in `_showTimePicker` iOS branch — deterministic, testable without migration.
- (c) Schema-level migration — broadest impact, no precedent, only justified if other code validates divisibility.

OQ-STEP-01: which policy? The spec must decide. Note: `SchedulePredictionNotification.dart:45–46` validates `[0, 1439]` only — no 5-step check — so odd values do not block production today.

### Focus 7 — Test coverage gaps for both paths

Current gaps after the iOS-platform branch is added:
1. **No iOS time picker test**: no group exists that asserts `find.byType(CupertinoDatePicker)` or equivalent.
2. **No iOS advance picker test**: no group exists that asserts `find.byType(CupertinoPicker)` under `TargetPlatform.iOS`.
3. **No cancel-without-write test for iOS**: the Material cancel test at `:712` has no Cupertino counterpart.
4. **No odd-minute coexistence test**: no test seeds a non-multiple-of-5 value (e.g., `notificationTimeMinutes: 553`) and asserts the chosen coexistence policy (whatever OQ-STEP-01 resolves to).
5. **`defaults` constant at `:97` omits `notificationTimeMinutes`** (it predates TASK-17 merge) — each test group that exercises the time row must supply `notificationTimeMinutes: 540` explicitly or rely on `AppSettingsData.defaults()`. Current tests pass because `copyWith(notificationsEnabled: true)` inherits the default. Not a blocker, but worth hardening.
