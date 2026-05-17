# Consolidated Assessment — M3 Configurable Cycle Reminder Implementation

**Date:** 2026-05-08  
**Source reports:** domain-review.md, data-review.md, ui-review.md, tests-review.md  
**Modules assessed:** domain entities/use-cases, data layer (Drift+repository+service), settings UI/l10n, test infrastructure

---

## Deduplicated Findings by Severity

### Critical (block acceptance — must be resolved before M3 tests are meaningful)

| ID | Finding | Files | Source |
|----|---------|-------|--------|
| CF-01 | `FakeNotificationService:63` — `final pastNine = nowTime.hour >= 9` hardcodes 09:00. Any new test at a non-09:00 `notificationTimeMinutes` routes to the wrong list. **Must be fixed first — before any other new test is written.** Fix: compare `notifyAt.toLocal()` (hour + minute) against `_now()` using same-day semantics. | `test/helpers/fake_notification_service.dart:63` | domain, data, tests (consensus) |
| CF-02 | `schedule_prediction_notification.dart:35–40` — `assert(<= 7)` throws `AssertionError` in debug mode for any value 8–14. Must be widened to `<= kMaxAdvanceDays` before boundary tests can run. | `lib/domain/use_cases/schedule_prediction_notification.dart:35-40` | tests, data |
| CF-03 | `AppConstants.kMaxAdvanceDays` does not exist anywhere. Constant is referenced in spec FR-18 as the single source of truth (= 14) for the assert, picker loop, DB migration, and plural metadata. Must be created as the first domain-layer task. | `lib/core/constants/app_constants.dart` | tests, domain, data (consensus) |
| CF-04 | `schedule_prediction_notification.dart:41–57` — BUG-003 day-stripping guard becomes incorrect once the use case composes a fully-resolved `notifyAt`. The 5-line day-extraction block must be replaced with `if (notifyAt.toLocal().isBefore(DateTime.now())) return;` in the same commit as the time-injection change. Leaving it silently suppresses same-day notifications until the user-chosen time. | `lib/domain/use_cases/schedule_prediction_notification.dart:41-57` | domain |
| CF-05 | `DriftAppSettingsRepository._toCompanion` — if `notificationTimeMinutes` is added to the entity but not to `_toCompanion`, every `updateSettings` call silently reverts it to the DB default (540). Must add `notificationTimeMinutes: Value(data.notificationTimeMinutes)`. | `lib/data/repositories/drift_app_settings_repository.dart:45-53` | data, ui |
| CF-06 | Schema migration — `schemaVersion` is 6. Adding the new column requires a v6→v7 `onUpgrade` block: `await m.addColumn(appSettings, appSettings.notificationTimeMinutes)` with `withDefault(Constant(540))`. Without it, existing installs crash on open. | `lib/data/database/app_database.dart:141,206-234` | data, ui |
| CF-07 | Two `findsNothing` invariants at `settings_screen_test.dart:402` and `:519` assert no `Scrollable` inside the advance picker. With 14 `ListTile`s (~784 dp) on a 640-dp device, a `SingleChildScrollView` is required — introducing a `Scrollable`. Both guards must flip to `findsWidgets` (with updated reason strings citing the OQ-A resolution) in the same commit as the range widening. | `test/features/settings/settings_screen_test.dart:401-407,519-522` | ui, tests (consensus) |

### Important

| ID | Finding | Files |
|----|---------|-------|
| IF-01 | `notification_service.dart (domain)` — docstring says "fires at 09:00 local time on the date given by notifyAt". Must be corrected to "fires at the local time encoded in notifyAt" before implementing the service change. | `lib/domain/services/notification_service.dart:28-32` |
| IF-02 | `notificationTimeMinutes` has 6 silent edit sites in `AppSettingsData`: constructor, field, `copyWith`, `==`, `hashCode`, `_AppSettingsDataDefaults`. Only `_AppSettingsDataDefaults` and `hashCode` silently break without a compile error. All 6 must be updated atomically with default = 540. | `lib/domain/entities/app_settings_data.dart` |
| IF-03 | `notification_prediction_body` ARB key is a plain `{days}` placeholder — not ICU plural. Renders "1 days" (EN) and "1 giorni" (IT) at daysBefore=1. Must be converted to ICU plural in both `.arb` files and `flutter gen-l10n` re-run before the PR. | `lib/l10n/app_it.arb:253`, `lib/l10n/app_en.arb:80` |
| IF-04 | `_showAdvancePicker` loop bound `i < 7` is a magic number. After extracting `kMaxAdvanceDays`, the loop and all test label lists (7 items → 14 items) must be updated in the same commit. | `lib/features/settings/settings_screen.dart:425` |
| IF-05 | No `test/data/repositories/app_settings_repository_test.dart` exists. `_fromRow`, `_toCompanion`, and stream re-emit contract (NFR-14) are entirely untested. Must be created in this sprint. | `test/data/repositories/` |
| IF-06 | Migration test pattern bypasses `onUpgrade` — every test uses `NativeDatabase.memory()` which always runs `onCreate`. A snapshot-based v6→v7 round-trip test is required for NFR-08. | `test/data/database/app_database_migration_test.dart` |
| IF-07 | No boundary tests for `daysBefore=8, 14, 15`. The test named `given_notificationDaysBefore_7_when...` has a misleading `// upper bound` comment after widening. | `test/domain/use_cases/schedule_prediction_notification_test.dart:223-255` |
| IF-08 | No wiring test threads `notificationTimeMinutes` through the pipeline. All wiring tests use `notificationDaysBefore: 1` only. | `test/app_notification_wiring_test.dart:298,340,371` |
| IF-09 | DST regression tests cover 09:00 only. Two gap-edge cases unguarded: user picks 02:30 on spring-forward day (2026-03-29) and fall-back day (2026-10-25). | `test/data/services/notification_service_test.dart:129-152` |
| IF-10 | `assert` for `notificationDaysBefore` range should be upgraded to `ArgumentError.value` for both fields (daysBefore and timeMinutes) — CSV import or buggy migration can land out-of-range values silently in release builds. | `lib/domain/use_cases/schedule_prediction_notification.dart:35-40` |

### Suggestions (low priority / nice-to-have)

- `S-01`: Add `AppConstants.kDefaultNotificationTimeMinutes = 540` alongside `kMaxAdvanceDays` — single source of truth for DB column default, entity default, migration default.
- `S-02`: Add `debugPrint` at the UTC fallback (`notification_service.dart:55–58`) in the same commit as hardcode removal (FR-20).
- `S-03`: `_StreamingFakeAppSettingsRepository.updateSettings` in settings_notifier_test.dart — must forward the new field when it's added, or reactivity tests silently drop it.
- `S-04`: Annotate the wide-viewport `800×2000` advance-picker test as "full-visibility sanity" to clarify the narrow-viewport test is the overflow guard.

---

## Cross-Module Concerns

| Concern | Modules involved |
|---------|-----------------|
| `kMaxAdvanceDays` constant is used in domain (use case assert), data (DB schema default), UI (picker loop), and tests (boundary values) — must be introduced before anything else | domain, data, ui, tests |
| `notificationTimeMinutes` field must be added atomically across: entity (6 sites), repository `_fromRow`+`_toCompanion`, DB table definition, DB migration, UI persistence path, UI display/picker | domain, data, ui |
| BUG-003 day-comparison removal must be co-ordinated with the use-case receiving `notificationTimeMinutes` from settings and composing `notifyAt` before the service call | domain |
| `FakeNotificationService` time-awareness is a prerequisite for all new time-routing tests — must be completed in Wave 1 | tests |
| The two `findsNothing` invariant flips must be committed together with the loop-bound widening — otherwise the CI test suite breaks mid-wave | ui, tests |
| `flutter gen-l10n` must be re-run and generated files committed alongside `.arb` edits — stale generated files cause `flutter analyze` failure | ui |

---

## Spec Inputs (unified)

### Components and files affected

| File | Change |
|------|--------|
| `lib/core/constants/app_constants.dart` | Add `kMaxAdvanceDays = 14`, `kDefaultNotificationTimeMinutes = 540` |
| `lib/domain/entities/app_settings_data.dart` | Add `notificationTimeMinutes` (non-nullable `int`, default 540); update copyWith, ==, hashCode, _AppSettingsDataDefaults |
| `lib/domain/services/notification_service.dart` | Correct docstring contract (no time default) |
| `lib/domain/use_cases/schedule_prediction_notification.dart` | Widen assert to kMaxAdvanceDays; replace BUG-003 day-comparison with instant-comparison; compose fully-resolved notifyAt from notificationTimeMinutes |
| `lib/data/database/app_database.dart` | Add `notificationTimeMinutes` column; bump schemaVersion to 7; add v6→v7 migration block |
| `lib/data/database/app_database.g.dart` | Re-generated by build_runner — do not edit by hand |
| `lib/data/repositories/drift_app_settings_repository.dart` | Add notificationTimeMinutes to _fromRow and _toCompanion |
| `lib/data/services/notification_service.dart` | Remove hardcoded `, 9)` in computeScheduledTz; accept resolved time from notifyAt parameter; add debugPrint at UTC fallback |
| `lib/features/settings/settings_screen.dart` | Add "Orario notifica" _SettingsRow + _showTimePicker; change loop bound to kMaxAdvanceDays |
| `lib/l10n/app_it.arb` + `lib/l10n/app_en.arb` | ICU plural for notification_prediction_body; add settings_notification_time_label and settings_notification_time_value keys |
| `lib/l10n/app_localizations*.dart` | Re-generated by flutter gen-l10n |
| `lib/app.dart` | Forward notificationTimeMinutes to SchedulePredictionNotification use case (two call sites at :121 and :175) |
| `test/helpers/fake_notification_service.dart` | Replace pastNine >= 9 with notifyAt-driven same-day comparison |
| `test/domain/entities/app_settings_data_test.dart` | Add notificationTimeMinutes coverage (construction, equality, hashCode, copyWith, defaults) |
| `test/domain/use_cases/schedule_prediction_notification_test.dart` | Add boundary tests daysBefore=8,14,15; add notificationTimeMinutes time routing tests; update upper-bound comment |
| `test/data/services/notification_service_test.dart` | Add DST spring-forward 02:30 and fall-back 02:30 tests; add non-09:00 computeScheduledTz tests |
| `test/features/settings/settings_screen_test.dart` | Flip findsNothing invariants at :402 and :519; extend 7-item label list to 14; add time-picker test group |
| `test/app_notification_wiring_test.dart` | Add wiring test with non-default notificationTimeMinutes |
| `test/data/repositories/app_settings_repository_test.dart` | Create: _fromRow/_toCompanion round-trip, stream re-emit, new field survives persist/reload |
| `test/data/database/app_database_migration_test.dart` | Add snapshot-based v6→v7 round-trip test (onUpgrade path) |

### Patterns to follow

- **Adding a defaulted AppSettings column:** `addColumn` in `onUpgrade` with `withDefault(Constant(...))`. No `customStatement`. Precedent: v5 block at `app_database.dart:198–205`.
- **Field inclusion in `_toCompanion`:** general user-toggle fields go in as `Value(data.field)`. Fields with dedicated lifecycle writers (`dropboxEmail`, `lastBackupAt`, `onboardingCompleted`, `declaredCycleLength`) stay out.
- **New settings row:** copy `_SettingsRow` pattern; include `semanticsLabel` = label + value; use `_SettingsDivider()` before it.
- **New picker helper:** `showTimePicker` returns `TimeOfDay?`; convert to minutes-from-midnight as `tod.hour * 60 + tod.minute`.
- **Deterministic time tests:** use far-future local dates with `nowOverride`; never `DateTime.now()` in test bodies.
- **`_StreamingFakeAppSettingsRepository`** pattern for reactivity tests requiring multiple emissions.
- **Named test descriptions:** `given_X_when_Y_then_Z` form for boundary-value tests.
- **`setUpAll(tz_data.initializeTimeZones)`** before any timezone test group; `tz.setLocalLocation(tz.getLocation('Europe/Rome'))` as primary guard.
- `showTimePicker` renders a `Dialog`, not a `BottomSheet` — use `find.byType(TimePickerDialog)` in tests, not `find.byType(BottomSheet)`.

### Anti-patterns present — avoid

- Do **not** add `notificationTimeMinutes` to `_toCompanion` as `Value.absent()` — silently reverts to DB default on every general save.
- Do **not** leave the BUG-003 day-comparison block in place after making `notifyAt` time-precise — silently suppresses same-day notifications.
- Do **not** use `TimeOfDay` in the domain entity — domain must remain Flutter-free (CLAUDE.md §4). Store as `int` minutes-from-midnight.
- Do **not** widen advance range without updating the two no-Scrollable test guards simultaneously.
- Do **not** edit `.arb` files without re-running `flutter gen-l10n` and committing generated files.

### Tech debt ordering (Wave 1 prerequisites from LP plan §input_from_previous)

1. **kMaxAdvanceDays constant** — domain + test prerequisite (CF-02, CF-03)
2. **FakeNotificationService time-aware** — test prerequisite for all new tests (CF-01)
3. **Use case composes fully-resolved DateTime** — domain contract change (CF-04); includes BUG-003 guard replacement
4. **Domain dartdoc correction** (IF-01)

All four are Wave 1. Everything else is Wave 2+.

### Integration constraints

- `lib/app.dart:121,175` — both `scheduler.execute()` call sites must forward `notificationTimeMinutes` once the use case signature changes.
- `lib/app.dart:147` — BUG-002 guard (`if (prev is AsyncData<AppSettingsData>)`) is load-bearing; the new field changing value must trigger rescheduling via the existing `ref.listen` path — no new listener needed.
- `BackupSnapshot` does not carry `AppSettingsData` — new field is never serialised into a backup; `BackupSnapshot.currentVersion` is unchanged.
- `showTimePicker` is Flutter; must stay in the features layer. Conversion to `int` minutes-from-midnight happens at the UI boundary before `copyWith`.
