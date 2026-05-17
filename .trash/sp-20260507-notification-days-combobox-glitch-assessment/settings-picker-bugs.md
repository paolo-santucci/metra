# Settings Picker — Bug Assessment

**File:** `lib/features/settings/settings_screen.dart`
**Scope:** `_showAdvancePicker` (lines 407–438)
**Date:** 2026-05-07

---

## Findings

---

[MEDIUM] BUG-001: `ListView.builder` inside uncontrolled bottom sheet causes false scroll affordance and potential clipping

**File:** `lib/features/settings/settings_screen.dart:407–438`
**Category:** logic-error (UI layout contract violation)

**Evidence:**
```dart
showModalBottomSheet<void>(                 // no isScrollControlled
  context: context,
  builder: (sheetCtx) => SafeArea(
    child: ListView.builder(
      shrinkWrap: true,
      itemCount: 7,
      itemBuilder: ...
    ),
  ),
);
```

**Analysis — two compounding factors:**

1. **Height cap without `isScrollControlled`.** `showModalBottomSheet` without `isScrollControlled: true` clamps the sheet to `9/16 × screen height`. On a typical phone (say 780 dp logical height after status + nav bars, e.g. Pixel 6 in portrait), 9/16 ≈ 438 dp. Seven `ListTile`s at the Material default 56 dp minimum height = 392 dp, plus `SafeArea` bottom inset (≈34 dp on many Android devices) = 426 dp — already near the cap. On smaller devices or larger font scales (Dynamic Type), this threshold is crossed and the sheet shows only 6.x tiles, rendering the last item partially clipped. The `ListView.builder` will be scrollable and the overscroll glow indicator appears, falsely signalling that more items exist beyond the visible area.

2. **Default scroll physics on `ListView.builder`.** Even when all 7 items fit within the sheet height, `ListView.builder` defaults to `AlwaysScrollableScrollPhysics` (or the platform scroll physics). On Android, an attempted swipe past item 7 triggers a `GlowingOverscrollIndicator`; on iOS, bounce physics pull the list and snap back. Both create the exact perceptual signal the user reports: "there's more content below."

**Contrast with sibling pickers in the same file:** `_showLanguagePicker` (lines 309–348) and `_showThemePicker` (lines 356–404) both use `Column(mainAxisSize: MainAxisSize.min, children: [...])` — the correct pattern for a fixed, short, non-scrolling option list in a bottom sheet. The advance picker is structurally inconsistent with these two.

**Trigger:**
- Open Settings → tap "Anticipo notifica" row → advance picker opens.
- On any device where 7 × 56 dp + SafeArea inset > 9/16 × screen height: last tile is clipped and list is scrollable.
- On taller devices: swipe up inside the sheet triggers overscroll glow/bounce, implying phantom items below item 7.

**Impact:** User perceives more options than exist; attempting to scroll to "see more" finds nothing — erodes trust in the control and creates confusion about the picker's upper bound.

---

[LOW] BUG-002: No widget test covers the advance picker

**File:** `test/features/settings/settings_screen_test.dart`
**Category:** missing-validation (test gap)

**Evidence:** `settings_screen_test.dart` tests the language picker, theme picker, delete confirmation, CSV export/import, and backup row — but contains no test that opens the advance-picker bottom sheet, asserts it renders 7 items, or verifies that tapping an item calls `save` with the correct `notificationDaysBefore` value.

**Analysis:** Without a regression test, a fix to `_showAdvancePicker` has no safety net. Any future refactor that accidentally changes `itemCount` or the `days = i + 1` computation will go undetected.

**Impact:** Silent regressions in the picker's count or save logic are undetectable by the test suite.

---

## SUMMARY: 2 findings (0 critical, 0 high, 1 medium, 1 low)

**Highest-risk area:** `lib/features/settings/settings_screen.dart:407–438` (`_showAdvancePicker`)

---

## Spec Inputs

### Root cause (confirmed)
`_showAdvancePicker` uses `ListView.builder` (scrollable, glow/bounce physics) where the two sibling pickers in the same file use `Column(mainAxisSize: MainAxisSize.min)` (non-scrolling, intrinsic height). This is the structural mismatch that produces the scroll affordance. A secondary contributor is the absence of `isScrollControlled: true`, which can clip the list on smaller screens or at larger text scales.

### Affected files
- `lib/features/settings/settings_screen.dart` — lines 407–438 (`_showAdvancePicker`)
- `test/features/settings/settings_screen_test.dart` — no test group for the advance picker

### Recommended fix (widget change)
Replace `ListView.builder(shrinkWrap: true, itemCount: 7, ...)` with `Column(mainAxisSize: MainAxisSize.min, children: List.generate(7, ...))`, matching the structure used by `_showLanguagePicker` (lines 309–348) and `_showThemePicker` (lines 356–404). No change to `showModalBottomSheet` parameters is needed with this fix — `Column` + `MainAxisSize.min` intrinsically sizes to its children, never scrolls, and never shows overscroll affordances. A new widget test group should be added that opens the picker, asserts 7 `ListTile`s are rendered, and verifies save is called with the correct value on tap.

### Constraints
- **Design system:** No design-system constraint is violated by the change; `Column` + `ListTile` matches the established pattern in the same file.
- **Existing tests:** No existing test covers this picker, so the fix has no test to break — but a new test group must be added as part of the fix.
- **Localization:** `l10n.settings_advance_value(days)` is already exercised elsewhere; no l10n changes needed.
- **AppSettingsData:** `notificationDaysBefore` is an `int` with no enforced upper bound in the entity — the picker is the sole enforcement point for the 1–7 range. The fix must preserve `itemCount: 7` and `days = i + 1`.
