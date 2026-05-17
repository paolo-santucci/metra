# M3 Cycle Reminder — Test Infrastructure Pre-Implementation Assessment

**Date:** 2026-05-08
**Reviewer:** code-reviewer agent
**Scope:** test infrastructure and test files for Milestone 3 of the Configurable Cycle Reminder feature.

---

## Summary

The test infrastructure is well-structured and the existing suite faithfully
exercises the current [1,7] contract. Four specific interventions are required
before or during M3 implementation: (1) make `FakeNotificationService`
time-aware; (2) flip two `findsNothing` invariants; (3) update the upper-bound
tests for `daysBefore=7`; (4) introduce `AppConstants.kMaxAdvanceDays`. None of
these require new test patterns — the existing patterns are the templates.

---

## Findings

### Critical (must fix before M3 can be accepted)

**C-01 — `FakeNotificationService` hardcodes `>= 9` (not configurable time)**
`test/helpers/fake_notification_service.dart:63`
```dart
final pastNine = nowTime.hour >= 9;
```
The production `shouldShowImmediately` check at
`lib/data/services/notification_service.dart` already uses a
`@visibleForTesting` method that accepts a fully-resolved `TZDateTime`. The
fake mirrors only the hour-9 threshold instead of comparing against the
user-chosen time. Every new test that sets a non-09:00 `notificationTimeMinutes`
will route to the wrong list (`shown` vs. `scheduled`) and produce a false
result without any error message.

Fix required: replace `final pastNine = nowTime.hour >= 9` with a comparison
against the scheduled time passed in as `notifyAt`. The fake should route to
`shown` when `sameDay && nowTime >= notifyAt.toLocal()`. No settings object
needs to be passed into the fake — `notifyAt` already carries the resolved
delivery time once the use case is updated to resolve wall-clock time before
calling the service (per M3 FR-13 + OQ-I).

**C-02 — Use-case `assert` rejects legal values 8–14 in debug builds**
`lib/domain/use_cases/schedule_prediction_notification.dart:35-40`
```dart
assert(
  settings.notificationDaysBefore >= 1 &&
      settings.notificationDaysBefore <= 7,
  ...
);
```
Any M3 test that passes `notificationDaysBefore: 8` (or higher) in debug mode
will `AssertionError`-fail before the use case logic runs. This is a
production-code constraint that must be widened to `<= kMaxAdvanceDays` in the
same commit as the new tests. Document under R-04 in the spec.

**C-03 — No `AppConstants.kMaxAdvanceDays` constant exists anywhere**
`grep -rn "kMaxAdvanceDays" lib/ test/` returns empty. The constant is
referenced in spec FR-18 as the single source of truth for the upper bound (=
14) used by the use-case assert, the picker `for` loop, ARB plural metadata, and
tests. Until it is introduced:
- the use-case assert upper bound is the literal `7` (must change in two places
  by hand)
- the picker loop `for (int i = 0; i < 7; i++)` at
  `settings_screen.dart:425` must change separately
- tests that assert daysBefore=7 as the upper bound will become stale without a
  compilation-time linkage

M3 must introduce `AppConstants.kMaxAdvanceDays = 14` before any test that
targets boundary values can be meaningful.

### Important (should fix in M3)

**I-01 — `settings_screen_test.dart:402` — `findsNothing` invariant on Scrollable**
```dart
// settings_screen_test.dart:402-407
expect(
  find.descendant(of: sheet, matching: find.byType(Scrollable)),
  findsNothing,
  reason: 'Column picker must not contain a Scrollable (regression guard)',
);
```
OQ-A resolved (M1): scrollable bottom sheet is the chosen UX for 14 options.
This assertion *must* be flipped. The qp-combobox-glitch regression net guarded
against `ListView.builder` producing a false scroll affordance in a fixed-height
sheet. With `isScrollControlled: true`, a real `Scrollable` wrapping 14
ListTiles is intentional, not a defect.

Required change: replace `findsNothing` with `findsWidgets` (or `findsAtLeast(1)`)
and update the `reason` string to document the OQ-A resolution and the 14-option
overflow arithmetic. Do not silently delete the assertion — the reason string is
the regression narrative.

**I-02 — `settings_screen_test.dart:519` — same invariant on narrow viewport**
```dart
// settings_screen_test.dart:519-522
expect(
  find.descendant(of: sheet, matching: find.byType(Scrollable)),
  findsNothing,
);
```
Same fix as I-01 but in the `advance picker (narrow viewport)` group. The
narrow-viewport test (360×640 + `FakeViewPadding(bottom: 48)`) is the *more
important* of the two because it was added specifically after real-device
clipping. After the flip, it should be updated to verify that all 14 options are
reachable by scrolling — not just visible without scrolling.

**I-03 — Tests that assert `daysBefore=7` as upper bound become stale when range widens**
`test/domain/use_cases/schedule_prediction_notification_test.dart:223-255`
The test named `given_notificationDaysBefore_7_when_execute_then_...` currently
documents `7` as the upper bound in a comment: `// upper bound`. Once the range
is 1–14, `7` is a mid-range value and the comment becomes misleading. Additionally,
no test currently asserts `daysBefore=14` or the boundary behaviour at 8, 10,
and 14. New tests required: `daysBefore=8` (first value that currently fires the
assert), `daysBefore=14` (new upper bound), and a test that `daysBefore=15`
triggers the assert (or is rejected at the domain boundary if M3 adds runtime
validation).

**I-04 — `app_notification_wiring_test.dart` uses `notificationDaysBefore: 1` — partial but adequate**
`test/app_notification_wiring_test.dart:298,340,371`
The wiring tests all use `notificationDaysBefore: 1`. This is fine for wiring
verification but there is no wiring test that verifies the time-of-day field
(`notificationTimeMinutes`) is threaded through the pipeline. M3 must add at
least one wiring test with a non-default time to confirm the new field is not
silently dropped between the settings notifier and the scheduler.

**I-05 — DST regression tests cover 09:00 only**
`test/data/services/notification_service_test.dart:129-152`
The existing spring-forward test picks `DateTime.utc(2026, 3, 29, 0, 0, 0)` which
resolves to 01:00 CET — unambiguously before the 02:00→03:00 switch, and the
delivery at 09:00 is unambiguously after. Two gap-edge cases are unguarded:
(a) user picks 02:30 on 2026-03-29 (spring-forward) → timezone package shifts to
    03:30. No test. Required: verify result is 03:30 (correct silent shift), not
    an exception.
(b) user picks 02:30 on 2026-10-25 (fall-back, 03:00→02:00) → first occurrence
    fires. No test. Required: verify result is the first unambiguous 02:30 on that
    date, not an exception.
Named tests (even `returnsNormally` level) are sufficient to lock the DST
contract.

### Suggestion

**S-01 — `settings_screen_test.dart` — picker group uses `800×2000` viewport**
`test/features/settings/settings_screen_test.dart:371-373`
The wide picker tests use an `800×2000` viewport. This is fine today with 7
options (~392 dp). After M3 the options grow to 14 (~784 dp). The test will
still pass visually on an 800×2000 viewport (all 14 fit), but it no longer
exercises whether the sheet *handles overflow correctly* — only the narrow
`360×640` test does that. Consider annotating the wide test as "full-visibility
sanity; overflow behaviour tested in narrow-viewport group" to prevent future
confusion.

**S-02 — `app_settings_data_test.dart` has no `notificationTimeMinutes` tests**
`test/domain/entities/app_settings_data_test.dart`
The entity test file is thorough for existing fields (construction, equality,
hashCode, copyWith). When M3 adds `notificationTimeMinutes`, the same four test
groups need one row each for the new field. The `makeSettings` helper at line
22 is the right extension point. The `AppSettingsData.defaults()` test at line
88 must verify `notificationTimeMinutes = 540` (09:00 default).

---

## What Was Done Well

1. `FakeNotificationService` already has `nowOverride`, `shown`, and `showCount`
   fields — the time-aware fix in C-01 is a surgical one-liner, not a structural
   rewrite.
2. The cold-start BUG-005 regression test (schedule_prediction_notification_test.dart:
   258-317) uses deterministic far-future dates with local constructors and a
   clear comment explaining the UTC-offset rationale. This is the template for
   all new deterministic time tests.
3. `settings_notifier_test.dart` uses a `_StreamingFakeAppSettingsRepository`
   backed by a `StreamController` — the correct pattern for reactivity tests that
   need to push multiple emissions. The `notificationTimeMinutes` stream tests
   should follow this pattern verbatim.

---

## Verdict

**REQUEST CHANGES** — three Critical findings (C-01, C-02, C-03) must be resolved
before any M3 tests can produce meaningful results.

---

## Spec Inputs

### Components and files affected

| File | Change type | Reason |
|------|-------------|--------|
| `test/helpers/fake_notification_service.dart:63` | Modify — routing condition | C-01: replace `>= 9` with time-aware comparison |
| `lib/domain/use_cases/schedule_prediction_notification.dart:35-40` | Modify — assert upper bound | C-02: widen to `kMaxAdvanceDays` |
| `lib/core/constants/app_constants.dart` (new or existing) | Create/extend | C-03: introduce `kMaxAdvanceDays = 14` |
| `lib/features/settings/settings_screen.dart:425` | Modify — picker loop | `for (int i = 0; i < 7; i++)` → `for (int i = 0; i < AppConstants.kMaxAdvanceDays; i++)` |
| `test/features/settings/settings_screen_test.dart:386-407` | Modify — invariant flip | I-01: `findsNothing` → `findsWidgets` |
| `test/features/settings/settings_screen_test.dart:519-522` | Modify — invariant flip | I-02: same |
| `test/domain/use_cases/schedule_prediction_notification_test.dart:223-255` | Modify comment + add tests | I-03: daysBefore=8,14,15 boundary tests |
| `test/app_notification_wiring_test.dart` | Extend | I-04: add one wiring test with non-default time |
| `test/data/services/notification_service_test.dart` | Extend | I-05: DST spring-forward 02:30 and fall-back 02:30 tests |
| `test/domain/entities/app_settings_data_test.dart` | Extend | S-02: `notificationTimeMinutes` field coverage |

### Patterns to follow

- **Deterministic far-future dates** with local constructors (not UTC) for time-routing
  tests. See `schedule_prediction_notification_test.dart:265`.
- **`nowOverride` injection** for all fake time-dependent routing: pass at
  construction, never mutate after. See `FakeNotificationService:42-45`.
- **`_StreamingFakeAppSettingsRepository`** pattern for reactivity tests that need
  multiple emissions. See `settings_notifier_test.dart:32-115`.
- **Named test descriptions** in `given_X_when_Y_then_Z` form for boundary-value
  tests. See `schedule_prediction_notification_test.dart:155-255`.
- **`setUpAll(tz_data.initializeTimeZones)`** before any timezone test group.
  See `notification_service_test.dart:81`.
- `tz.setLocalLocation(tz.getLocation('Europe/Rome'))` as the primary Italy
  regression guard locale; `America/New_York` as the UTC-behind guard.

Anti-patterns present (do not copy):
- Do not add a `showTimePicker` test that uses `find.byType(BottomSheet)` to
  locate the time picker — Material `showTimePicker` renders a `Dialog`, not a
  `BottomSheet`. Use `find.byType(Dialog)` or `find.byType(TimePickerDialog)`.
- Do not use `DateTime.now()` inside test bodies without a `nowOverride` — it
  ties test result to wall-clock time and will fail on CI in non-09:00 timezone
  windows after M3.

### Integration constraints

1. **`notifyAt` must be fully resolved before the service call.** The current use
   case computes only the calendar day and delegates time to the service
   (hardcoded 09:00 at `notification_service.dart:108`). M3 must shift this:
   the use case receives `settings.notificationTimeMinutes`, resolves the full
   wall-clock `DateTime`, and passes a fully-resolved `notifyAt` to the service.
   Once this is done, `FakeNotificationService` can compare `nowTime >= notifyAt`
   directly (C-01 fix) without needing settings injected into the fake.

2. **OQ-A resolution requires `showModalBottomSheet` not `showBottomSheet`.**
   The spec mentions `showBottomSheet`; the current code uses
   `showModalBottomSheet` (settings_screen.dart:419). `find.byType(BottomSheet)`
   in the widget tests matches *both* (both produce a `BottomSheet` widget), but
   `showBottomSheet` produces a persistent (non-modal) sheet which breaks the
   Navigator.of(sheetCtx).pop() dismiss pattern used in the picker. Keep
   `showModalBottomSheet` for the day-picker.

3. **`AppSettingsData.copyWith` must include `notificationTimeMinutes`.** The
   field follows the general-user-toggle pattern (not out-of-band like
   `declaredCycleLength`), so it must appear in both `_toCompanion` in the
   repository and `copyWith` in the entity. See lesson at
   `experiences/code-reviewer/lessons.jsonl` entry #12.

4. **`_StreamingFakeAppSettingsRepository.updateSettings` does not forward
   `notificationTimeMinutes`.** When M3 adds the field, the streaming fake at
   `settings_notifier_test.dart:56-58` must be updated to thread the new field
   through — otherwise the reactivity tests will silently drop it.

### Tech debt that blocks or complicates the feature

| Debt | Blocks | Location |
|------|--------|----------|
| `[1,7]` range encoded in 4 places (no `kMaxAdvanceDays` constant) | C-02, C-03 | use case:35-40, settings_screen:425, entity (no validation), DB (no CHECK) |
| `FakeNotificationService` routing locked to 09:00 | C-01 | fake:63 |
| `notification_prediction_body` is not ICU plural (EN/IT grammatically wrong at days=1) | Surfaces as wrong string in any `daysBefore=1` test body assertion | app_it.arb:253, app_en.arb:80 |

### Test coverage baseline

| Area | Current state |
|------|--------------|
| `daysBefore` boundary 1 (lower) | Covered — `schedule_prediction_notification_test.dart:155-187` |
| `daysBefore` boundary 7 (current upper) | Covered — `schedule_prediction_notification_test.dart:223-255` |
| `daysBefore` 8–14 (M3 new range) | Not covered — no tests |
| Time-of-day routing in fake | Partially covered — only 09:00 boundary (`notification_service_test.dart:160-185`) |
| DST spring-forward at non-09:00 time | Not covered |
| DST fall-back at any time | Not covered |
| `notificationTimeMinutes` field (entity, copyWith, equality) | Not covered — field does not exist yet |
| `notificationTimeMinutes` wiring through pipeline | Not covered |
| `FakeNotificationService` implements `NotificationService` | Covered — `notification_service_test.dart:35-38` |
| BUG-005 cold-start same-day show path | Covered — `schedule_prediction_notification_test.dart:258-317` |
| BUG-002 permission guard | Covered — `app_notification_wiring_test.dart:111-267` |
| `shouldShowImmediately` predicate | Covered — `notification_service_test.dart:194-228` |
