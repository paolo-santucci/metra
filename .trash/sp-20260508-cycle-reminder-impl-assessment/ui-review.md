# Pre-Implementation Assessment — Milestone 3: Configurable Cycle Reminder

**Reviewed:** 2026-05-08  
**Reviewer:** code-reviewer agent  
**Scope:** `lib/features/settings/settings_screen.dart`, `lib/features/settings/state/settings_notifier.dart`, `lib/l10n/app_localizations{,.dart,_en.dart,_it.dart}`, `lib/l10n/app_{en,it}.arb`, `lib/domain/entities/app_settings_data.dart`, `lib/data/repositories/drift_app_settings_repository.dart`, `lib/data/database/app_database.dart`, `test/features/settings/settings_screen_test.dart`

---

## Summary

The settings module is cleanly structured and the persistence pattern is consistent and easy to extend. The three deliverables (new time-of-day row, advance-days range widening 1→14, ICU plural fix) each have a specific blocker or debt item that must be addressed — none is a blocking bug today, but each creates test failures or silent data loss if the implementation skips the prerequisite step.

---

## Findings

### Critical

**C-1 — `_toCompanion` silently drops `notificationTimeMinutes`**  
`lib/data/repositories/drift_app_settings_repository.dart:45-53`  
`_toCompanion` hard-codes only 6 fields and intentionally omits `dropboxEmail`, `lastBackupAt`, `declaredCycleLength` (those have dedicated write paths). When `notificationTimeMinutes` is added to `AppSettingsData`, the same exclusion trap applies. If the new field is added to the entity but not explicitly mapped in `_toCompanion`, every `updateSettings` call will silently leave it at the DB default (09:00), making the picker appear to save while actually losing the value. The fix is straightforward: add `notificationTimeMinutes: Value(data.notificationTimeMinutes)` inside `_toCompanion` alongside the other notification fields, and mirror the pattern in `_fromRow`.

**C-2 — No DB migration for the new column — schema version must be bumped to 7**  
`lib/data/database/app_database.dart:141`  
`schemaVersion` is currently `6`. Adding `notificationTimeMinutes` to `AppSettings` table requires a v6→v7 migration block in `onUpgrade` with `await m.addColumn(appSettings, appSettings.notificationTimeMinutes)`. Without it, existing installs crash on open. The default for the new column in the migration must be `540` (09:00 in minutes) to preserve the current hardcoded behaviour for existing users.

**C-3 — Two no-Scrollable invariants in tests will fail after widening advance range to 14**  
`test/features/settings/settings_screen_test.dart:401-407, 519-522`  
Both guards assert `findsNothing` for `Scrollable` inside the `BottomSheet`. The current picker is a bare `Column` with 7 `ListTile`s. With 14 items (≈784 dp at 56 dp each) the column will overflow on a 640-dp device unless wrapped in a `SingleChildScrollView`, which will introduce a `Scrollable` and break both asserts. Resolution confirmed by OQ-A: the tests must be updated to either (a) drop the no-Scrollable guard entirely and replace it with a min-viewport visible-item check, or (b) accept a `Scrollable` via `findsOneWidget` instead. The test at line 486-523 ("narrow viewport") is the higher-priority guard to update since it tests at `physicalSize: Size(360, 640)`.

### Important

**I-1 — `notification_prediction_body` uses a plain placeholder, not ICU plural**  
`lib/l10n/app_en.arb:80`, `lib/l10n/app_it.arb:253`  
Both ARB files define the key as a simple string `"Your predicted window starts in {days} days"` / `"La finestra stimata inizia tra {days} giorni"` with no `plural` selector. The generated Dart methods (`app_localizations_en.dart:161`, `app_localizations_it.dart:161`) return a flat string for `days=1` — yielding "starts in 1 days" (EN) and "inizia tra 1 giorni" (IT). The fix is to convert the ARB value to ICU plural syntax:  
EN: `"{days, plural, =1{Your predicted window starts tomorrow} other{Your predicted window starts in {days} days}}"`  
IT: `"{days, plural, =1{La finestra stimata inizia domani} other{La finestra stimata inizia tra {days} giorni}}"`  
After editing the `.arb` files, `flutter gen-l10n` must be re-run to regenerate `app_localizations_*.dart`.

**I-2 — `copyWith` cannot clear `darkMode` to `null`; same risk for any nullable field**  
`lib/domain/entities/app_settings_data.dart:60-87`  
The existing `copyWith` uses the `??` fallback pattern, making it impossible to set `darkMode` back to `null` (system theme). The workaround is already present in `_showThemePicker` (full constructor call). The new `notificationTimeMinutes` should **not** be nullable (a sensible default of `540` can always be provided), which avoids this trap. Document this constraint in the field comment.

**I-3 — `_showAdvancePicker` hardcodes `i < 7`; widening requires updating both source and tests**  
`lib/features/settings/settings_screen.dart:425`  
The loop `for (int i = 0; i < 7; i++)` is a magic number. The fix is to introduce `AppConstants.kMaxAdvanceDays = 14` and reference it in both the loop and the test's expected-labels list. The existing 7-item text assertions in the test (`'1 giorno prima' … '7 giorni prima'`) must be extended to 14.

**I-4 — `settings_advance_value` plural in EN does not use `=1` explicitly in ARB source**  
`lib/l10n/app_en.arb:149`  
Current EN ARB: `"{n, plural, =1{1 day before} other{{n} days before}}"`. This is correct ICU. It is included here for contrast: `notification_prediction_body` (I-1) lacks the same treatment. No change needed for `settings_advance_value` beyond the range extension; it already handles the grammar correctly.

### Suggestion

**S-1 — `AppConstants.kDefaultNotificationTimeMinutes = 540` should accompany `kMaxAdvanceDays`**  
`lib/core/constants/app_constants.dart`  
The 09:00 default is currently hardcoded in `NotificationService` as a magic number. Extracting it to `AppConstants` makes it the single source of truth for the DB column default, the entity default, and the migration default.

---

## What Was Done Well

1. **Persistence pattern is uniform and extensible.** The `_fromRow` / `_toCompanion` / `save()` trio is consistent across all settings fields. Adding a new field follows an unambiguous 4-touch pattern (entity → table → mapping pair → migration), which minimises implementation risk.
2. **`_showAdvancePicker` comment is precise.** The `isScrollControlled` rationale explicitly cites the 9/16 viewport cap and the 640-dp threshold — exactly the information needed to reason about the 14-item case.
3. **Semantics coverage.** Every `_SettingsRow` that shows a value text also has an explicit `semanticsLabel` that concatenates label + value. The `_MetraToggle` uses `Semantics(toggled:)`. Adding the new time row must replicate this pattern.

---

## Spec Inputs

### Components and files affected

| File | Change |
|---|---|
| `lib/domain/entities/app_settings_data.dart` | Add `notificationTimeMinutes` field (non-nullable `int`, default `540`); add to `copyWith`, `==`, `hashCode` |
| `lib/data/database/app_database.dart` | Add `notificationTimeMinutes` column to `AppSettings` table; bump `schemaVersion` to `7`; add v6→v7 migration |
| `lib/data/database/app_database.g.dart` | Re-generated by `build_runner` — do not edit by hand |
| `lib/data/repositories/drift_app_settings_repository.dart` | Add to `_fromRow` and `_toCompanion` |
| `lib/features/settings/settings_screen.dart` | Add "Orario notifica" `_SettingsRow` + `_showTimePicker` helper after advance row; change loop bound to `AppConstants.kMaxAdvanceDays` |
| `lib/core/constants/app_constants.dart` | Add `kMaxAdvanceDays = 14`, `kDefaultNotificationTimeMinutes = 540` |
| `lib/l10n/app_it.arb` | Convert `notification_prediction_body` to ICU plural; add `settings_notification_time_label` and `settings_notification_time_value` keys |
| `lib/l10n/app_en.arb` | Same |
| `lib/l10n/app_localizations.dart` | Re-generated; add abstract getter/method declarations |
| `lib/l10n/app_localizations_it.dart` | Re-generated |
| `lib/l10n/app_localizations_en.dart` | Re-generated |
| `test/features/settings/settings_screen_test.dart` | Update no-Scrollable invariants at lines 401-407 and 519-522; extend 7-item label lists to 14; add time-picker group tests |

### Patterns to follow

- **New settings row:** copy `_SettingsRow` call pattern for advance row (label, `semanticsLabel` with label + value, `valueText`, `onTap` → show picker). Use `_SettingsDivider` before it.
- **New picker helper:** copy `_showAdvancePicker` structure. `showTimePicker` (Material) returns `TimeOfDay?`; convert to minutes-from-midnight with `tod.hour * 60 + tod.minute` before saving.
- **Saving:** `_save(ref, settings.copyWith(notificationTimeMinutes: minutes))` — no other path.
- **DB column default:** use `integer().withDefault(const Constant(540))()` in the Drift table definition.
- **Migration guard:** always use `if (from < N)` block; never rely on `schemaVersion` alone.

### Anti-patterns present — avoid

- Do **not** add `notificationTimeMinutes` to `_toCompanion` as `Value.absent()` — that would silently revert the column to its DB default on every general settings save (the same bug as `dropboxEmail`/`lastBackupAt`). It must be `Value(data.notificationTimeMinutes)`.
- Do **not** remove `useSafeArea` from the new time picker call — `showTimePicker` manages its own safe area; the comment on `_showLanguagePicker` applies only to `showModalBottomSheet`.
- Do **not** widen the advance range without updating tests — the no-Scrollable guards at lines 401 and 519 will become false positives once 14 items force a `SingleChildScrollView`.

### Integration constraints

- **`NotificationService`** (not in scope here): currently hardcodes `TimeOfDay(hour: 9, minute: 0)`. After M3 it must read `AppSettingsData.notificationTimeMinutes` and reschedule when the value changes. The `SettingsNotifier.save()` path already fires a Drift stream; the notification service's watch subscription should react automatically if wired to `appSettingsStreamProvider`.
- **`_AppSettingsDataDefaults`:** default value must be `notificationTimeMinutes: 540` to match the DB column default and existing hardcoded 09:00 behaviour.
- **`copyWith` null-safety:** `notificationTimeMinutes` must be non-nullable. The `??` pattern in `copyWith` is safe for non-nullable fields.
- **ARB→Dart generation:** after editing `.arb` files, run `flutter gen-l10n` (or the project's equivalent) before building. The generated `app_localizations_*.dart` files are checked in — they must be regenerated and committed together with the ARB edits.

### Tech debt that blocks or complicates the feature

1. **C-1 / C-2 (blocking):** `_toCompanion` field exclusion trap + schema version bump are required before any runtime test can verify persistence.
2. **C-3 (blocking for tests):** The no-Scrollable guards are regression fences that will flip from green to red the moment the loop bound exceeds 7 on a 640-dp viewport. They must be updated in the same commit as the range widening.
3. **I-1 (ICU plural fix):** Must regenerate `app_localizations_*.dart` — any PR touching `.arb` files without re-running `flutter gen-l10n` will leave the generated files out of sync, failing `flutter analyze` (lint rule `intl_plural_issue` from `flutter_lints`).

### Test coverage baseline

- **Advance picker tests:** 4 test cases (wide viewport: all-items-visible + no-Scrollable, tapping saves, re-tap same option, check-icon selection; narrow viewport: all-items-visible + no-Scrollable). All pass for 7 items today.
- **Notification toggle tests:** covered.
- **Time-of-day picker:** **zero coverage** — no test exists. The new group must cover: row visible; tapping opens `TimePickerDialog`; confirming saves minutes-from-midnight; cancelling does not save.
- **ICU plural:** no existing test validates the "1 day" singular form for `notification_prediction_body`. A unit test or widget test asserting the singular string should be added alongside the ARB change.
