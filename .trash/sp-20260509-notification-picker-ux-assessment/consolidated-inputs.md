# Consolidated Assessment — notification-picker-ux

**Date**: 2026-05-09
**Source**: settings-review.md

---

## Key Findings

### Critical (must resolve before implementation)

1. **`TimePickerThemeData.constraints` does not exist in Flutter 3.x.**
   The clock dial diameter is fixed internally (`_kTimePickerDialSize`). Available levers:
   - `dialTextStyle` — font size/weight of all clock-face numbers (achievable, makes outer ring numbers more prominent)
   - `hourMinuteTextStyle` — font size of the "11:15" header (making it smaller is achievable)
   - `padding` — marginal
   - **Best approach**: use `showTimePicker(builder: ...)` to wrap with a local `Theme` override (not a global `timePickerTheme` in `MetraTheme`) so other dialogs are unaffected.
   - **"Outer ring bigger" = larger `dialTextStyle` font → outer ring numbers more prominent/readable.** This is the achievable interpretation; a physically wider ring requires a custom clock widget (out of scope).

2. **`kMaxAdvanceDays` 14→7 test cascade** (must be fixed in same commit):
   - `test/core/constants/app_constants_test.dart`: literal `expect(AppConstants.kMaxAdvanceDays, 14)` → update to 7.
   - `test/domain/use_cases/schedule_prediction_notification_test.dart:481,509`: test values 8 and 14 become invalid — update to ≤7.
   - `test/features/settings/settings_screen_test.dart`: ~6 groups assert 14 rows → update to 7; FR-17 Scrollable invariant flips from `findsOneWidget` to `findsNothing` (7×56dp = 392dp fits on 360×640).

3. **`showModalBottomSheet` → `showDialog` test cascade**:
   - ~10 `find.byType(BottomSheet)` callsites in `settings_screen_test.dart` → `find.byType(Dialog)`.

### Important

- The inline OQ-A comment at `settings_screen.dart:458-462` (justifying scroll for 14 rows) becomes stale. Must remove/replace.
- `useSafeArea=false` / ShellRoute dim-band comment is irrelevant to `showDialog` — do not carry it over.

### What's available (anti-patterns to avoid)

- Do NOT add `timePickerTheme` to `MetraTheme.light()/.dark()` — use `builder` parameter on `showTimePicker` for local override.
- A working `showDialog` pattern already exists at `settings_screen.dart:497-536` (`_showDeleteConfirmation`) — mirror it for the advance picker.

---

## Spec Inputs

### Components and files affected
| File | Change |
|------|--------|
| `lib/core/constants/app_constants.dart` | `kMaxAdvanceDays`: 14 → 7 |
| `lib/features/settings/settings_screen.dart` | `_showTimePicker`: add `builder` with local `TimePickerThemeData`; `_showAdvancePicker`: `showModalBottomSheet` → `showDialog`, 14→7 rows, remove OQ-A comment |
| `test/core/constants/app_constants_test.dart` | Update literal 14 → 7 |
| `test/features/settings/settings_screen_test.dart` | ~10 BottomSheet → Dialog finders; 6 groups: 14-row → 7-row; FR-17 Scrollable flip |
| `test/domain/use_cases/schedule_prediction_notification_test.dart` | Values 8 and 14 → values ≤7 |

### Patterns to follow
- `_showDeleteConfirmation` for the dialog pattern (lines 497-536).
- `builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(timePickerTheme: TimePickerThemeData(...)), child: child!)` for time picker local override.

### Integration constraints
- `drift_app_settings_repository.dart` clamp-on-read mitigates the 8-14 stored-value problem for normal call paths — verify no raw DB values bypass the clamp.
- The `kMaxAdvanceDays` constant is used at 4 callsites; all go through the same constant so one edit propagates everywhere.

### Tech debt
- OQ-A inline comment at `settings_screen.dart:458-462` must be cleaned up.
- `kMaxAdvanceDays` in `drift_app_settings_repository.dart` may still need a note about the clamp behavior post-change.

### Test coverage baseline
- constants test: 1 line
- settings screen test: ~10 BottomSheet finders + 6 row-count / scroll groups
- use-case test: 2 test cases with out-of-range values (8, 14)
