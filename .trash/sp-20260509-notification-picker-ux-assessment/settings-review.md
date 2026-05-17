# Pre-implementation Assessment: Notification Picker UX
**Date:** 2026-05-09 | **Scope:** settings_screen.dart · metra_theme.dart · app_constants.dart

---

## Summary

The codebase is cleanly structured for these two changes, but each carries a concrete test cascade that must be planned before coding. The time-picker dial-size feature has an invalid premise: `TimePickerThemeData` in Flutter 3.x does not expose a `constraints` field — the outer ring diameter is a framework internal constant, not a theme knob. The advance-picker change from 14→7 + BottomSheet→Dialog is mechanically straightforward but reverses a prior explicit design decision (OQ-A) and breaks at least six test groups across four files.

---

## Findings

### Critical

**C-1 — `TimePickerThemeData.constraints` does not exist.**
`lib/core/theme/metra_theme.dart` — no time-picker theme section currently.

The feature brief asks whether `TimePickerThemeData.constraints` is the right lever to enlarge the clock dial. It is not — the field does not exist in Flutter 3.x. The dial diameter is laid out internally by Material against the private `_kTimePickerDialSize` constant and cannot be configured via theme. Available knobs are:

- `hourMinuteTextStyle` → controls the `HH:MM` header numbers (smaller = ✓ achievable)
- `dialTextStyle` → controls numbers on the dial face ring (larger = ✓ achievable, but makes numbers bigger, not the ring itself)
- `TimePickerThemeData.padding` → reduces dialog padding, giving the dial more layout space (marginal)

There is no theme API to increase the physical diameter of the outer hour ring. If a larger ring is required, the only path is a fully custom clock widget. The spec must resolve this before implementation begins.

**C-2 — Changing `kMaxAdvanceDays` from 14 to 7 reverses OQ-A and breaks the use-case assertion.**

The advance-picker change triggers an `ArgumentError` in `lib/domain/use_cases/schedule_prediction_notification.dart:37-43` for any stored `notificationDaysBefore` value of 8–14. The guard reads `> AppConstants.kMaxAdvanceDays`, so shrinking the constant narrows the valid domain. Existing users with saved values 8–14 would hit this error on the first reschedule after upgrade. The clamping in `drift_app_settings_repository.dart:39` handles read-time coercion silently to 7, so the DB write path is safe — but the use case must be called after the repo clamp, not before.

**Current call chain:** settings saved → repo reads back (clamps to new max 7) → notification reschedule fires → use case receives clamped value 7 → passes assertion. No runtime error if the repo clamp fires first. However, if any path feeds the stored raw value directly into the use case (bypassing the repo read), it will throw. Verify the call chain in `lib/app.dart` and `lib/providers/`.

### Important

**I-1 — Advance picker is currently a BottomSheet; tests find `BottomSheet`, not `Dialog`.**
`test/features/settings/settings_screen_test.dart` — lines 385, 430, 456, 480, 506, 593, 707, 846, 890, 917.

Every advance-picker test group uses `find.byType(BottomSheet)`. Switching to `showDialog` means all of these must become `find.byType(Dialog)` or `find.byType(AlertDialog)`. This is a mechanical replacement but it is load-bearing; the tests will fail as written.

**I-2 — Seven test groups assert on 14 rows; they break when `kMaxAdvanceDays` becomes 7.**

Groups at `settings_screen_test.dart:577`, `:829`, `:870`, `:901` assert `i <= 14`, `findsOneWidget` for 14 labels, and `Scrollable findsOneWidget` (OQ-A outcome). All must be rewritten:
- The 14-row groups drop entirely or are replaced by 7-row equivalents.
- The FR-17 Scrollable groups (`:874`, `:901`) flip back to `findsNothing` — 7 rows × 56 dp = 392 dp which fits in a 360×640 viewport, restoring the original no-Scrollable invariant.

**I-3 — `app_constants_test.dart:22-23` explicitly asserts `kMaxAdvanceDays == 14`.**

This test must be updated to 7 in the same commit as the constant change.

**I-4 — `app_settings_repository_test.dart:93-99` clamps to `kMaxAdvanceDays` (currently 14).**

The test name and the `expect(result.notificationDaysBefore, AppConstants.kMaxAdvanceDays)` assertion both pass through the constant. The constant change cascades cleanly — but the seed value used (`99`) must still exceed 7, which it does. No test logic change required, only the constant.

**I-5 — `schedule_prediction_notification_test.dart:481` and `:509` use `notificationDaysBefore=8` and `=14` as valid inputs.**

With `kMaxAdvanceDays=7`, both values are out of range. These test cases will trigger `ArgumentError`. They must be updated to within-range values (e.g. 6, 7) or extended to test the ArgumentError path explicitly.

**I-6 — OQ-A reversal must be called out in any plan.**
`lib/features/settings/settings_screen.dart:458-462` contains an inline decision record:
> "isScrollControlled stays: kMaxAdvanceDays (14) ListTiles ≈ 784 dp exceed the 9/16 viewport cap..."

Dropping to 7 and moving to a centered dialog voids this reasoning entirely. The comment block must be replaced or removed to avoid misleading future reviewers.

### Suggestion

**S-1 — `_showTimePicker` passes no `builder` override for `TimePickerThemeData`.**
`lib/features/settings/settings_screen.dart:444` calls `showTimePicker(context: context, initialTime: initial)` with no `builder` parameter. To apply `hourMinuteTextStyle` or `dialTextStyle` overrides without touching `MetraTheme.light()/dark()` globally, wrap via: `builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(timePickerTheme: ...), child: child!)`. This is the least-invasive path and keeps the theme module clean.

**S-2 — `_showAdvancePicker` comment block references OQ-A resolution verbatim.**
If the picker moves to a dialog, the `useSafeArea` ShellRoute concern cited in `_showLanguagePicker` and `_showThemePicker` does not apply to `showDialog` (dialogs are not anchored to the bottom edge). Remove the concern from the advance-picker implementation note.

---

## What Was Done Well

1. `showTimePicker` call is minimal and correct — `context`, `initialTime` only; cancel-returns-null guard at line 445 is clean.
2. `kMaxAdvanceDays` is already a named constant and referenced consistently at all four callsites (loop bound, clamp, assert, test). The constant-extraction work was done in a prior sprint; this change is one-line.
3. `_showDeleteConfirmation` provides a working `showDialog` pattern in the same file (lines 497–536) that `_showAdvancePicker` can mirror exactly — no new API to learn.

---

## Spec Inputs

### Components and files that will be affected

**In scope (primary):**
- `lib/features/settings/settings_screen.dart` — `_showAdvancePicker` (BottomSheet→Dialog, loop bound 14→7), `_showTimePicker` (optional `builder` for theme override)
- `lib/core/theme/metra_theme.dart` — add `timePickerTheme: TimePickerThemeData(hourMinuteTextStyle: ..., dialTextStyle: ...)` to both `light()` and `dark()`, OR apply via local `Theme` override in `_showTimePicker` builder
- `lib/core/constants/app_constants.dart` — `kMaxAdvanceDays: 14 → 7`

**Cross-module (must coordinate):**
- `test/features/settings/settings_screen_test.dart` — six test groups, ~10 `find.byType(BottomSheet)` callsites, FR-12/FR-17 14-row groups, Scrollable invariant flip
- `test/core/constants/app_constants_test.dart:22-23` — literal `== 14` assertion
- `test/data/repositories/app_settings_repository_test.dart:93-99` — clamp test (safe via constant; no logic change)
- `test/domain/use_cases/schedule_prediction_notification_test.dart:481, 509` — out-of-range values become invalid

### Patterns to follow

- Use `showDialog` with `AlertDialog` children (list of `ListTile`) mirroring `_showDeleteConfirmation` at lines 497–536.
- For time-picker visual overrides: `builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(timePickerTheme: TimePickerThemeData(...)), child: child!)` inside `showTimePicker` — do not add a global `timePickerTheme` to `MetraTheme` unless the theme is intended to apply everywhere.

**Anti-patterns present (avoid):**
- Do not attempt to pass `constraints: BoxConstraints(...)` to `TimePickerThemeData` — the field does not exist.
- Do not use `SingleChildScrollView` + `Column` inside the new dialog (dialog has its own scroll semantics). Use `SimpleDialog` with `SimpleDialogOption` children, or `AlertDialog` with `content: Column(mainAxisSize: MainAxisSize.min, ...)`.
- The `useSafeArea` warning (ShellRoute band) applies only to `showModalBottomSheet`. It does not apply to `showDialog`; do not copy the comment.

### Integration constraints

- `drift_app_settings_repository.dart:39` clamps stored `notificationDaysBefore` to `kMaxAdvanceDays` on read. The clamp happens before the use case runs. Reducing the constant to 7 is safe as long as the call chain preserves the read→clamp→use-case order. Verify in `lib/app.dart` settings listener.
- The use-case guard `settings.notificationDaysBefore > AppConstants.kMaxAdvanceDays` at line 38 will update automatically via the constant. No manual change needed there.
- `settings_advance_value(n)` plural form in `app_it.arb` and `app_en.arb` already covers 1..7 correctly; no l10n change required for the range reduction.

### Tech debt that blocks or complicates the feature

- The inline OQ-A decision record at `settings_screen.dart:458-462` will become stale immediately and mislead future reviewers. It must be removed or replaced in the same commit.
- `notification_prediction_body` in `app_it.arb:253` / `app_en.arb:80` is a bare `{days}` placeholder (no ICU plural) — a latent singular-form bug for `days=1`. Unrelated to this feature; defer, but log separately.

### Test coverage baseline

| Area | Current state |
|---|---|
| Advance picker — option count | Tested at 14; tests in `settings_screen_test.dart:577, 829` must be rewritten to 7 |
| Advance picker — save behavior | Tested (tap option 5 → saves 5); no change needed |
| Advance picker — widget type | All `find.byType(BottomSheet)` — must become `find.byType(Dialog)` or `find.byType(SimpleDialog)` |
| Scrollable invariant | FR-17 at `:874/:901` expects `findsOneWidget`; must flip to `findsNothing` at 7 rows |
| Time picker — opens dialog | Tested: `find.byType(TimePickerDialog)` at `:631` — no change |
| Time picker — dial/header styling | Zero coverage; no test for visual theme properties (acceptable for styling) |
| kMaxAdvanceDays constant | Literal `== 14` at `app_constants_test.dart:23` — must update to 7 |
| Use-case out-of-range guard | Tests at `:481, :509` use values 8, 14 — will become invalid; update to 6, 7 |
