# Cluster A — UI Bug Assessment
**Sprint:** sp-20260509-android-ios-prerelease-bugs  
**Date:** 2026-05-09  
**Scope:** Issue #1 (Android Material time picker dial + header font), Issue #4 (iOS Cupertino Ripristina font weight)

---

## Findings

### [LOW] BUG-A1A: Material dial outer-ring overlap — inherent framework constraint, not fixable via theme

**File:** `lib/features/settings/settings_screen.dart:493–510`  
**Category:** boundary-violation (UI rendering)

**Evidence:**
```dart
// settings_screen.dart:498–505
timePickerTheme: TimePickerThemeData(
  dialTextStyle: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  ),
  hourMinuteTextStyle: Theme.of(ctx).textTheme.displaySmall?.copyWith(
    fontSize: 52,
  ),
),
```

**Analysis:**  
The selector circle for the outer-ring hour visually overlaps inner-ring minute numbers. The geometry is hardcoded in the Flutter framework:

- `_kTimePickerInnerDialOffset = 28` (flutter/src/material/time_picker.dart:49) — spacing from outer to inner label ring.
- M3 `dotRadius = 24` (time_picker.dart:3757–3759) — radius of the selector circle.
- With `dialSize = 280` (M3, time_picker.dart:3747–3749) and `_kTimePickerDialPadding = 28`, the selector circle (radius 24) extends 24 px inward from the outer label centerline, but the inner label ring is only 28 px inward. Net overlap: ~20 px.
- Metra uses `useMaterial3: true` (metra_theme.dart:97, 170), so M3 constants apply.

**`TimePickerThemeData` complete property set** (time_picker_theme.dart:49–80): `backgroundColor`, `cancelButtonStyle`, `confirmButtonStyle`, `dayPeriodBorderSide`, `dayPeriodColor`, `dayPeriodShape`, `dayPeriodTextColor`, `dayPeriodTextStyle`, `dialBackgroundColor`, `dialHandColor`, `dialTextColor`, `dialTextStyle`, `elevation`, `entryModeIconColor`, `helpTextStyle`, `hourMinuteColor`, `hourMinuteShape`, `hourMinuteTextColor`, `hourMinuteTextStyle`, `inputDecorationTheme`, `padding`, `shape`, `timeSelectorSeparatorColor`, `timeSelectorSeparatorTextStyle`.  
**None exposes:** `dialSize`, `dotRadius`, `innerDialOffset`, or any geometric spacing between rings.

`TimePickerThemeData.padding` wraps the outer dialog container; it does not scale the dial. The dial is rendered as `SizedBox.fromSize(size: defaultTheme.dialSize)` (time_picker.dart:3044–3046) using a hardcoded size from `_TimePickerDefaultsM3`, not from `TimePickerThemeData`. Increasing `padding` makes the dialog container bigger but the dial stays 280×280 — the ring geometry is unchanged.

**Three viable fix paths** (spec author must choose):  
(a) **Accept the artefact** — no code change.  
(b) **Switch to input mode** — pass `initialEntryMode: TimePickerEntryMode.input` to `showTimePicker`; no dial is rendered. Instant fix, changes UX.  
(c) **Custom dial widget** — replace `showTimePicker` with a bespoke `showDialog` containing a hand-drawn dial. High effort, full control.

**Trigger:** visible in any app using the M3 Material time picker in dial mode when 24-hour mode is active (outer ring shows 13–24).  
**Impact:** cosmetic visual overlap only; no data loss or incorrect behaviour.

---

### [LOW] BUG-A1B: `hourMinuteTextStyle` font size 52 — potentially too large per Issue #1

**File:** `lib/features/settings/settings_screen.dart:503–505`  
**Category:** logic-error (style value)

**Evidence:**
```dart
hourMinuteTextStyle: Theme.of(ctx).textTheme.displaySmall?.copyWith(
  fontSize: 52,
),
```

**Analysis:**  
`displaySmall` maps to `statCard` in `MetraTypography.toTextTheme` (metra_typography.dart:225): DM Serif Display, 32 pt. The `copyWith(fontSize: 52)` override lifts it to 52 pt. The design system's largest display role is `displayHero` at 56 pt (metra_typography.dart:30). A 52 pt hourMinute header is near the top of the scale for a compact dialog element.

The issue asks for "a little smaller." The `statCard` base (32 pt) would be the nearest named role below it. Any target between 32 and 52 is a designer/spec call; the code change is a single integer on line 504.

**Impact:** purely cosmetic — the hourMinute digits are rendered slightly larger than intended.

---

### [LOW] BUG-A4: `_CupertinoPickerScaffold` Ripristina TextStyle missing `fontWeight: FontWeight.w600`

**File:** `lib/features/settings/settings_screen.dart:958–964` (Ripristina) vs. `979–986` (OK)  
**Category:** logic-error (style inconsistency)

**Evidence:**
```dart
// Ripristina button (lines 958–964):
child: Text(
  l10n.common_restore,
  style: TextStyle(
    color: colors.accentFlow,
    fontSize: 17,
    // fontWeight absent → defaults to w400
  ),
),

// OK button (lines 979–986):
child: Text(
  l10n.common_ok,
  style: TextStyle(
    color: colors.accentFlow,
    fontWeight: FontWeight.w600,  // ← present
    fontSize: 17,
  ),
),
```

**Analysis:**  
Commit `742529c` corrected the color of Ripristina to `accentFlow` (matching OK) but did not add `fontWeight: FontWeight.w600`. The missing field means Ripristina renders at the default w400 while OK renders at w600. Both buttons are semantically peers (one resets, one confirms). The STATUS.md entry for rc16 explicitly notes "OK keeps `accentFlow + w600`", making the asymmetry an unresolved half-fix.

The existing BUG-008 test (settings_screen_test.dart:1204–1238) asserts only `style?.color == accentFlow`. It does not assert `fontWeight`. Regression coverage for this property is therefore absent.

**Trigger:** Open either iOS picker modal. Both toolbar buttons appear; Ripristina text is visibly thinner than OK.  
**Impact:** visual inconsistency; the button reads as less active/prominent than OK, contrary to design intent.

---

## Test Coverage Baseline

| Area | Existing tests | Covers fontWeight? |
|---|---|---|
| BUG-008 Ripristina color | settings_screen_test.dart:1204–1238 | No — color only |
| Cupertino picker Ripristina tap | settings_screen_test.dart:1089–1165, 1274–1336 | No style assertions |
| Time picker theme (Android) | settings_screen_test.dart:636–855 | No style assertions on dialog widgets |
| iOS time picker autosave/debounce | settings_screen_test.dart:1424–1600 | No style assertions |

**Zero existing tests** validate `hourMinuteTextStyle` font size or Ripristina `fontWeight`.

---

## Spec Inputs

### Issue #1A — Dial ring overlap

**Root cause:** Framework-private geometry. `dotRadius = 24` (M3) exceeds half of `_kTimePickerInnerDialOffset = 28`, making the selector circle overlap the inner label ring by ~20 px. No property in `TimePickerThemeData` exposes dial geometry.

**Affected file:** `lib/features/settings/settings_screen.dart:493–510` (the `showTimePicker` builder that wraps `TimePickerThemeData`).

**Constraints:** `TimePickerThemeData` has no dimensional property to widen ring spacing or shrink the dot. Any layout-level override requires bypassing `showTimePicker` entirely.

**Fix shape:** The spec must choose one:  
(a) **No change** — accept the artefact as a Flutter M3 limitation.  
(b) **Input mode** — add `initialEntryMode: TimePickerEntryMode.input` to the `showTimePicker` call at line 493; removes the dial, shows text fields instead. Single-line change, testable immediately.  
(c) **Custom dial** — replace with a bespoke `showDialog` widget. Weeks of work.

**New tests needed:** None for (a). For (b): one widget test that the modal contains text input fields and no `_Dial` widget when `initialEntryMode` is input.

---

### Issue #1B — hourMinute font size

**Root cause:** `copyWith(fontSize: 52)` on line 504 sets a value that the user perceives as too large. The Métra design system maximum is `displayHero` at 56 pt; 52 pt sits near that ceiling for a dialog header.

**Affected file:** `lib/features/settings/settings_screen.dart:503–505`.

**Constraints:** Must remain visually consistent with DM Serif Display role scale. Nearest named role below 52 is `statCard` at 32 pt or `dayDetailTitle` at 20 pt; any value the designer selects in [32, 50] is achievable.

**Fix shape:** Single value change on line 504: `fontSize: 52` → `fontSize: <designer-chosen value>`.

**New tests needed:** One widget test asserting that the Text widget inside the hourMinute segment of the opened time picker has `style.fontSize <= <target>`. Feasible by pumping the Android branch with a `TargetPlatform.android` override, tapping "Orario notifica", then inspecting the rendered Text widget.

---

### Issue #4 — Ripristina fontWeight

**Root cause:** Commit `742529c` added `color: colors.accentFlow` to Ripristina's `TextStyle` (line 961) but omitted `fontWeight: FontWeight.w600` (present on OK at line 983). The fix was a half-match.

**Affected file:** `lib/features/settings/settings_screen.dart:960–963` (Ripristina `TextStyle`).

**Constraints:** Must match OK exactly: `color: colors.accentFlow`, `fontWeight: FontWeight.w600`, `fontSize: 17`. No design token changes required.

**Fix shape:** Add `fontWeight: FontWeight.w600` on line 963 (after `fontSize: 17`):
```dart
style: TextStyle(
  color: colors.accentFlow,
  fontWeight: FontWeight.w600,
  fontSize: 17,
),
```

**Test coverage baseline + new tests needed:** BUG-008 test (settings_screen_test.dart:1204) currently asserts color only. Extend it (or add a BUG-009 test) to also assert:  
```dart
expect(ripristina.style?.fontWeight, FontWeight.w600,
  reason: 'Ripristina must match OK weight');
```
The same assertion should be added inside the days-picker Ripristina test group (settings_screen_test.dart:1274+).

---

SUMMARY: 3 findings (0 critical, 0 high, 0 medium, 3 low)  
Highest-risk area: `lib/features/settings/settings_screen.dart`  
Recommended next action: Spec author decides fix path for Issue #1A (accept / input-mode / custom dial). Issues #1B and #4 are trivial single-value changes; spec should nominate target font size for #1B before build begins.
