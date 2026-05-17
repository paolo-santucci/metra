# Consolidated Assessment — Notification Days Picker Visual Glitch

**Date**: 2026-05-07
**Feature**: notification days combo-box visual glitch suggests items beyond 7

---

## Findings

### [Medium] BUG-001: ListView.builder causes false scroll affordance in bottom sheet

**File:** `lib/features/settings/settings_screen.dart:407–438` — `_showAdvancePicker`

**Root cause (confirmed):** `_showAdvancePicker` uses `ListView.builder(shrinkWrap: true, itemCount: 7)` without a `physics:` override inside an unconstrained `showModalBottomSheet`. Two compounding factors:

1. **Height cap**: `showModalBottomSheet` without `isScrollControlled: true` caps the sheet at 9/16 × screen height. On smaller/shorter devices or at increased text scale, 7 × 56 dp + SafeArea inset can overflow the cap, making the list genuinely scrollable and clipping the last item.
2. **Default scroll physics**: Even on tall devices where all 7 items fit, `ListView.builder` defaults to `AlwaysScrollableScrollPhysics`. A swipe past item 7 triggers Android's `GlowingOverscrollIndicator` (or iOS bounce), creating exactly the "there's more content below" signal the user reported.

**Structural outlier:** Both sibling pickers (`_showLanguagePicker` lines 309–348, `_showThemePicker` lines 356–404) use `Column(mainAxisSize: MainAxisSize.min, children: [...])` — the correct Flutter pattern for a fixed short list in a bottom sheet. `_showAdvancePicker` is the only one that diverged to `ListView.builder`.

**Fix:** Replace with `Column(mainAxisSize: MainAxisSize.min, children: [ListTile(...) × 7])` — identical to sibling pattern.

### [Low] BUG-002: No widget test for the advance picker

**File:** `test/features/settings/settings_screen_test.dart`

Test file covers language picker, theme picker, delete confirmation, CSV, backup — but has no group for `_showAdvancePicker`. Regression in `itemCount`, the `days = i + 1` offset, or save call goes undetected.

---

## Spec Inputs

**Root cause:** `ListView.builder` with default physics in unconstrained `showModalBottomSheet`; sibling pickers correctly use `Column(mainAxisSize: MainAxisSize.min)`.

**Files affected:**
- `lib/features/settings/settings_screen.dart` — replace `ListView.builder` with `Column` in `_showAdvancePicker`
- `test/features/settings/settings_screen_test.dart` — add advance picker widget test group

**Recommended fix:** Structural: match sibling pattern exactly. The Column approach eliminates both the height-cap issue and the scroll physics issue in one change. No `physics:` workaround needed.

**Constraints:**
- GPL-3.0 header preserved.
- Design system: the ListTile content (title, trailing check icon, onTap) is unchanged — only the container changes.
- `dart format` and `flutter analyze` must pass.
- No changes to `notificationDaysBefore` domain logic, `AppSettingsData`, or database layer.
