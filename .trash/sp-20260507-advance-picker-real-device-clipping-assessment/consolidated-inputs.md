# Consolidated Assessment — advance-picker-real-device-clipping

## Findings

**[HIGH] BUG-033 — `_showAdvancePicker` clips bottom tiles on real Android**
`lib/features/settings/settings_screen.dart:413`

Root cause confirmed: `showModalBottomSheet(isScrollControlled: false)` (default) caps sheet maxHeight at `viewport × 9/16`. On a real phone (~726 dp app height) cap ≈ 408 dp. 7 × ListTile (56 dp) + SafeArea bottom (≈34 dp) ≈ 426 dp — overflows silently. Test uses 800×2000 viewport; cap = 1125 dp — never reached.

**[MEDIUM] TEST-001 — Advance-picker tests use unrealistically large viewport**
`test/features/settings/settings_screen_test.dart`
800×2000 never exercises the 9/16 cap. A 360×640 viewport test would reproduce the regression immediately.

**[LOW] BUG-034 — Latent same-class risk in sibling pickers** (lines 309, 356)
`_showLanguagePicker` (3 tiles ≈ 168 dp) and `_showThemePicker` (3 tiles) are safe today but structurally identical omission.

## Spec Inputs

**Root cause:** Missing `isScrollControlled: true` in `_showAdvancePicker`'s `showModalBottomSheet` call at line 413.

**Affected files:**
- `lib/features/settings/settings_screen.dart` — fix `_showAdvancePicker` (mandatory), optionally fix siblings
- `test/features/settings/settings_screen_test.dart` — add 360×640 viewport regression test

**Minimal fix:** Add `isScrollControlled: true,` to the `showModalBottomSheet` call at line 413. Does not introduce a `Scrollable`; existing `findsNothing` assertion still passes.

**Constraints:**
1. No `Scrollable` inside the sheet — `isScrollControlled` is a sheet flag, not a widget
2. GPL-3.0 header unchanged
3. `dart format` and `flutter analyze` compatible

**Test updates:**
- Add a compact-viewport variant (`tester.view.physicalSize = const Size(360, 640)`) to the advance-picker group; fails before fix, passes after
- Keep existing 800×2000 tests unchanged
- New test also asserts `find.byType(Scrollable) findsNothing` inside the sheet
