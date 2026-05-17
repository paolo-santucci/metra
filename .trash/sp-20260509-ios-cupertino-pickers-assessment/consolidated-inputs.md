# Consolidated Assessment — ios-cupertino-pickers

**Date**: 2026-05-09

---

## Key Findings

### Critical (must resolve before implementation)

1. **Platform branch mechanism**: Use `defaultTargetPlatform == TargetPlatform.iOS` from `package:flutter/foundation.dart`. Do NOT use `Platform.isIOS` from `dart:io` — it returns `false` on the Linux dev box and CI runner, making iOS branches untestable via `debugDefaultTargetPlatformOverride`.

2. **Widget choice for time picker**: Use `CupertinoDatePicker(mode: CupertinoDatePickerMode.time, minuteInterval: 5)` — single widget, handles locale/AM-PM, 5-min step, simpler than two manual `CupertinoPicker` columns.

3. **Minutes coexistence (5-min step with existing stored values)**: Seed the picker with `initial.roundedToNearest5`. If stored value is 9:13 (553 min), the iOS picker opens at 9:15 (555 min). On confirm, the rounded value is written. Android path is unaffected. Resolution: **round-to-nearest-5 on seed, write rounded value on confirm.**

4. **Modal chrome**: `showCupertinoModalPopup` has no built-in Cancel/Done bar. Must add a toolbar row above the picker with "Annulla" (cancel, does not write) and "Fine" (confirm, writes and pops). Cancel path maps to the existing `if (result == null) return;` guard.

### Architecture Decisions

- **Platform branching location**: At the top of `_showTimePicker` and `_showAdvancePicker` in `settings_screen.dart`. No new widget files (avoid premature abstraction — only 2 new private methods in the existing file).
- **Cupertino theming**: Wrap inline with `CupertinoTheme(data: CupertinoThemeData(...), child: ...)` at each callsite. No global Cupertino theme in `MetraTheme` (premature until more Cupertino widgets exist).
- **Modal presentation**: `showCupertinoModalPopup` with a `Container` at fixed height (310dp: 44dp toolbar + 266dp picker).
- **Days picker**: Single `CupertinoPicker` column (not `CupertinoDatePicker`) with items 1–7. `FixedExtentScrollController` seeded to `(notificationDaysBefore - 1)`.

### Test Strategy

- **Platform override**: Use `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` in `setUp` / `tearDown` for new iOS test groups.
- **Existing tests**: No change — Linux test runner defaults to non-iOS platform; existing Material path tests continue working.
- **iOS widget type**: Assert `find.byType(CupertinoDatePicker)` (time) and `find.byType(CupertinoPicker)` (days) within the modal.

---

## Spec Inputs

### Components and files affected

| File | Change |
|------|--------|
| `lib/features/settings/settings_screen.dart` | Add `_showTimePickerIOS()` + `_showDaysPickerIOS()` private methods; add platform branch at top of `_showTimePicker()` and `_showAdvancePicker()` |
| `test/features/settings/settings_screen_test.dart` | Add new iOS test groups using `debugDefaultTargetPlatformOverride` |

### Patterns to follow
- `showCupertinoModalPopup` with `Container` (toolbar + picker) — no `CupertinoActionSheet` (which adds unwanted visual chrome).
- `debugDefaultTargetPlatformOverride` pattern for iOS widget tests.
- Existing `_showTimePicker`'s cancel guard (`if (tod == null) return;`) should mirror in iOS path via `ValueNotifier<TimeOfDay?>` or local variable set on "Fine" tap.

### Integration constraints
- `notificationTimeMinutes` domain range is `[0, 1439]`. Rounded-to-5 values also satisfy this.
- `kMaxAdvanceDays = 7` must drive the days picker item count (already in constants).
- `l10n.settings_advance_value(i)` must be used for days picker labels to maintain i18n.

### Tech debt
- `settings_screen.dart` is ~997 lines. Adding two more methods keeps it under 1100 — acceptable given they are simple modal helpers.

### Test coverage baseline
- Existing: `TimePickerDialog` assertion at line 614, `Dialog` assertions for advance picker throughout.
- New: `CupertinoDatePicker` assertion (iOS time), `CupertinoPicker` assertion (iOS days), confirm path writes correct minutes.
