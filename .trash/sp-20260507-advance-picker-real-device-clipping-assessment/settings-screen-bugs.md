# Settings Screen — Advance Picker Real-Device Clipping Assessment

**Module:** `lib/features/settings/settings_screen.dart`  
**Test:** `test/features/settings/settings_screen_test.dart`  
**Date:** 2026-05-07  
**Status:** Analysis complete

---

## Phase 1 — Structural Reconnaissance

### Change surface

The "advance picker" sheet was introduced by the recent `fix: replace ListView.builder with Column` commit. Four `showModalBottomSheet` calls exist in the file (lines 309, 356, 413, 496). None passes `isScrollControlled:`.

### Prior experience

Lesson bh-032 (session 2026-05-07) already classified the structural mismatch (`ListView.builder` in a fixed-list picker vs `Column(mainAxisSize.min)`). This report extends that finding to the residual geometry bug left by the fix.

---

## Phase 2 — Control Flow

`_showAdvancePicker` (line 407) calls `showModalBottomSheet<void>(context, builder: ...)` with:

- No `isScrollControlled:` argument (defaults to `false`)
- `builder` returns `SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [for i in 0..6: ListTile(...)]))`

Flutter's `_BottomSheetRenderObject._getConstraintsForChild` (flutter/src/material/bottom_sheet.dart line 617–623) computes:

```
maxHeight = isScrollControlled
  ? constraints.maxHeight          // full viewport
  : constraints.maxHeight * scrollControlDisabledMaxHeightRatio
```

`scrollControlDisabledMaxHeightRatio` defaults to `_defaultScrollControlDisabledMaxHeightRatio = 9.0 / 16.0` (line 32).

### Geometry on a real phone

Typical Android mid-range (e.g. Pixel 4a): ~750 dp logical height. After status bar (~24 dp) the app height is ~726 dp.

```
Cap height = 726 × (9/16) ≈ 408 dp
```

Content with gesture nav (`SafeArea` bottom ≈ 34 dp):

```
7 × ListTile(height 56 dp) = 392 dp
+ SafeArea bottom inset ≈ 34 dp
= 426 dp
```

`426 dp > 408 dp`: the `Column` exceeds the cap. Flutter clips overflow from the bottom — one or two bottom tiles are cut off (not just "last tile only," the exact count depends on nav bar height). The user report of "visually clipped" is confirmed; "only last item visible" likely refers to the sheet appearing as a sliver near the bottom.

### Geometry in the test

Test viewport: 800 × 2000 dp (logical).

```
Cap height = 2000 × (9/16) = 1125 dp
Content ≈ 426 dp
```

`426 dp << 1125 dp`. The cap never bites. All seven tiles render. The test passes on an artificially large viewport while real-device clipping remains undetected.

### Sibling pickers: `_showLanguagePicker` (line 309), `_showThemePicker` (line 356)

Both also omit `isScrollControlled:`. Their content is 3 × `ListTile` ≈ 168 dp — well under the ~408 dp cap. They do not clip today but carry the same latent risk class (e.g. if a custom bottom inset is large or system font scaling is enabled).

---

## Phase 3 — Data Flow

No mutable data flows through the picker beyond the `settings` snapshot captured at `_showAdvancePicker` call time. The `notificationDaysBefore` write goes through `_save → ref.read(settingsNotifierProvider.notifier).save(...)` immediately on `ListTile.onTap`. No data-flow bug.

---

## Phase 5 — Error & Edge Cases

### Boundary: large system font scale

Android accessibility "Font size = Largest" scales text ~1.3× — `ListTile` intrinsic height grows beyond the default 56 dp. On a phone with cap ≈ 408 dp and 7 tiles at ~73 dp each (392 → 511 dp), even more tiles are clipped. This is a compounded variant of the same root cause.

### SafeArea absent on `_showLanguagePicker` / `_showThemePicker`

Both sibling pickers wrap their `Column` in `SafeArea`. The picker subtree is consistent; no missing-guard edge case here.

---

## Findings

```
[HIGH] BUG-033: _showAdvancePicker sheet clips bottom tiles on real Android devices
File: lib/features/settings/settings_screen.dart:413-437
Category: boundary-violation / logic-error
Evidence:
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (int i = 0; i < 7; i++) ListTile(...)],
      ),
    ),
  );
  // Flutter default: isScrollControlled = false
  // Cap = viewport_height × 9/16 ≈ 408 dp on a 726-dp phone
  // Content = 7×56 + 34 (SafeArea bottom) ≈ 426 dp > 408 dp

Analysis: Flutter's bottom-sheet layout engine clamps maxHeight to 9/16 of the
viewport when isScrollControlled is false. A Column(mainAxisSize.min) respects
this cap by clipping — it cannot scroll, so the tiles that exceed the cap are
invisible. The test viewport (800×2000) produces a 1125 dp cap, which is never
exceeded, hiding the regression.
Trigger: Open Settings > "Preavviso" on any Android device with <~750 dp app
height (virtually all physical phones). The sheet renders with the bottom 1–2
tiles clipped and no scroll affordance.
Impact: Users cannot select certain advance-notice values (e.g. "6 giorni
prima", "7 giorni prima"). Tap targets are silently inaccessible.
```

```
[LOW] BUG-034: Sibling pickers _showLanguagePicker and _showThemePicker carry
the same latent isScrollControlled omission
File: lib/features/settings/settings_screen.dart:309, 356
Category: boundary-violation (latent)
Evidence: showModalBottomSheet<void>( context: context, builder: ... )
  // No isScrollControlled — same omission as BUG-033
Analysis: 3-tile content (~168 dp) is well under the typical ~408 dp cap today.
However at font scale 1.3× the height grows to ~219 dp (still safe). The risk
becomes real if a system theme or device has a smaller viewport or a large
SafeArea bottom inset (foldables, notched phones). Not currently broken, but
the same fix should be applied for consistency.
Trigger: Non-standard device with very small viewport OR future expansion of
the language/theme option list.
Impact: Would mirror BUG-033 — clipped picker options with no scroll affordance.
```

---

## Test Gap

```
[MEDIUM] TEST-001: Advance-picker tests use an unrealistically large viewport
File: test/features/settings/settings_screen_test.dart:371-483
Category: logic-error (in test)
Evidence:
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
Analysis: The 2000 dp height prevents the 9/16 cap from ever binding.
All seven ListTiles pass "findsOneWidget" regardless of the cap bug. A test
at (360, 640) dp — representative of a mid-range phone — would reproduce
the real-device regression: the "7 giorni prima" and "6 giorni prima" tiles
would be clipped and the assertion would fail.
```

---

## Summary

```
SUMMARY: 2 bugs, 1 test gap (1 high, 1 low, 1 medium test gap)
Highest-risk area: lib/features/settings/settings_screen.dart:413 (_showAdvancePicker)
Recommended next action: see ## Spec Inputs
```

---

## Spec Inputs

### Root Cause (confirmed)

`showModalBottomSheet` defaults to `isScrollControlled: false`, which caps the sheet height at `viewport_height × 9/16` (Flutter source constant `_defaultScrollControlDisabledMaxHeightRatio = 9.0/16.0`, `bottom_sheet.dart:32`). A `Column(mainAxisSize.min)` clips at that cap without scrolling. The 7-tile picker content (~426 dp including SafeArea bottom) exceeds the cap (~408 dp) on phones with ~726 dp app height. The test viewport (800×2000) produces a 1125 dp cap that never binds — the regression is invisible in tests.

### Affected Components and Files

| File | Location | Severity |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | `_showAdvancePicker` line 413 | HIGH — broken now |
| `lib/features/settings/settings_screen.dart` | `_showLanguagePicker` line 309, `_showThemePicker` line 356 | LOW — latent risk |
| `test/features/settings/settings_screen_test.dart` | advance-picker group lines 368–483 | MEDIUM — test gap |

### Minimal Fix Description

Add `isScrollControlled: true` to the `showModalBottomSheet` call in `_showAdvancePicker` (line 413). This removes the 9/16 cap; the `Column(mainAxisSize.min)` sizes to its intrinsic ~426 dp, which fits any modern phone. Apply the same flag to `_showLanguagePicker` (line 309) and `_showThemePicker` (line 356) for consistency and to eliminate the latent risk.

No changes are needed to the `Column`, `SafeArea`, or `ListTile` structure.

### Constraints the Fix Must Respect

1. **No `Scrollable` inside the sheet** — the existing test assertion `find.byType(Scrollable) findsNothing` must continue to pass. `isScrollControlled: true` is a sheet-level flag; it does not introduce a `Scrollable`. `SingleChildScrollView` must NOT be used.
2. **GPL-3.0 header** — `settings_screen.dart` already carries the correct header (lines 1–16). No modification needed.
3. **`dart format`** — `isScrollControlled: true,` must be placed as a named argument before the `builder:` argument on its own line. `dart format` will accept this.
4. **`flutter analyze`** — no new lint violations; `isScrollControlled` is a standard `showModalBottomSheet` parameter.

### Whether Existing Tests Need Updating (and How)

Yes. Two changes are needed:

1. **Add a phone-realistic viewport test** to the advance-picker group in `settings_screen_test.dart`. Use `tester.view.physicalSize = const Size(360, 640)` with `devicePixelRatio = 1.0`. Without the fix, the "all 7 options visible" assertion fails, reproducing the device regression. After the fix, it passes. This test is the regression guard.

2. **Keep the existing 800×2000 tests** unchanged. They verify behavior at scale; the new narrow-viewport test is additive. The `find.byType(Scrollable) findsNothing` assertion must appear in both test contexts (it already does in the 800×2000 suite) to guard against a `SingleChildScrollView` "fix" being applied.
