# Domain Layer Review — Milestone 3 Cycle Reminder Pre-Implementation Assessment

**Date:** 2026-05-08  
**Reviewer:** code-reviewer agent  
**Scope:** `lib/domain/entities/app_settings_data.dart`, `lib/domain/repositories/app_settings_repository.dart`, `lib/domain/services/notification_service.dart`, `lib/domain/use_cases/schedule_prediction_notification.dart`, `lib/domain/use_cases/get_or_create_settings.dart`

---

**Summary:** The five in-scope files are clean, layering-compliant, and well-tested in isolation. The feature is structurally feasible with one semantically significant change: the time-of-day responsibility is currently split between use case (calendar day) and service (09:00 hardcode). Flipping to a fully-resolved DateTime in the use case collapses that split correctly — but the use case's BUG-003 day-comparison guard must be updated simultaneously or it becomes incorrect. That is the single load-bearing coupling in this domain layer change. Four out-of-scope cross-module items will block implementation if not coordinated with the right agents.

---

## Findings

### Critical

**`schedule_prediction_notification.dart:41–57` — Day-comparison guard incompatible with fully-resolved DateTime**

When the use case composes the full `notifyAt` instant (day + user-chosen time), the BUG-003 day-stripping comparison on lines 49–57 is no longer correct. BUG-003 was a workaround for the service injecting a fixed 09:00 time _after_ the use case handed off a calendar day: comparing UTC midnight against UTC midnight was safe because both sides were midnight. Once `notifyAt` carries the intended time, the correct past-check is simply:

```dart
if (notifyAt.toLocal().isBefore(DateTime.now())) return;
```

The existing five-line day-extraction block becomes dead code that silently suppresses same-day notifications until the user-chosen time. **Update this guard alongside the time-injection change.**

---

**`notification_service.dart (domain):28–32` — Docstring contracts the wrong behaviour**

The abstract interface docstring reads: _"The notification fires at 09:00 local time on the date given by `notifyAt`."_ Under the rewrite, the service must fire at the time encoded in `notifyAt`, not always 09:00. The contract must be corrected before implementing — the Flutter implementation reads this docstring as its spec.

Replacement:

```dart
/// Schedules a single prediction-reminder notification.
///
/// The notification fires at the local time of day encoded in [notifyAt].
/// Any previously scheduled prediction notification is replaced
/// (same stable ID is reused).
Future<void> schedulePredictionNotification(
  DateTime notifyAt,
  String title,
  String body,
);
```

---

### Important

**`schedule_prediction_notification.dart:35–40` — `assert` for range; consider runtime guard**

The assert covers `notificationDaysBefore in [1, 7]`. Expanding to `[1, 14]` requires updating this assert. However, lesson 16 confirms there is no DB CHECK constraint and the `assert` is debug-only — a CSV import or buggy migration can land an out-of-range value silently in release builds. The spec must decide: keep `assert` or upgrade to a thrown `ArgumentError`. Recommended: upgrade to `ArgumentError.value` for both fields at this validation point, covering both `notificationDaysBefore in [1, kMaxAdvanceDays]` and `notificationTimeMinutes in [0, 1439]`.

---

**`app_settings_data.dart` — Five edit sites; `copyWith` inclusion requires explicit decision**

Adding `notificationTimeMinutes` is a general user-toggle setting and follows the `notificationDaysBefore` precedent: it belongs in both `copyWith` and `_toCompanion` (unlike `declaredCycleLength`, which is excluded from `copyWith` by design). All five edit sites must be updated atomically:

| Site | Action |
|---|---|
| Constructor parameter | Add `required this.notificationTimeMinutes` |
| Field declaration | `final int notificationTimeMinutes;` |
| `copyWith` parameter + body | Add, same pattern as `notificationDaysBefore` |
| `==` operator | Add `&& notificationTimeMinutes == other.notificationTimeMinutes` |
| `hashCode` | Add `^ notificationTimeMinutes.hashCode` |
| `_AppSettingsDataDefaults` | Add `notificationTimeMinutes: 540` (preserves current 09:00 behaviour) |

Default of **540** (minutes since midnight = 9 × 60) is the correct choice to preserve current behaviour on upgrade. This is a design commit the spec must make explicit.

---

**`app_constants.dart` — Placement of `kMaxAdvanceDays`**

`AppConstants` at `lib/core/constants/app_constants.dart` is Flutter-free and currently holds only URL/UI layout constants. The domain use case can import `core/` per the layering rules. Two valid options:

- **Option A (recommended):** Extend `AppConstants` with `static const int kMaxAdvanceDays = 14;` and a `kDefaultNotificationTimeMinutes = 540;`. Single source of truth; no new file.
- **Option B:** Declare a domain-local constants file (`lib/domain/constants.dart`). Stricter, but introduces a file with one constant.

Option A is idiomatic for this codebase (all existing named constants are in `AppConstants`). Spec should commit on one.

---

**`app_settings_data_test.dart` — Tests will fail without a `notificationTimeMinutes` branch**

The existing equality, `hashCode`, `copyWith`, and defaults tests will all compile-error or fail once the constructor gains a required field. The test `makeSettings` helper must add `notificationTimeMinutes = 540` as a default parameter. Every equality pair-test needs a counterpart for the new field. This is boilerplate but not trivial to skip — it enforces the five-edit-sites invariant.

---

### Suggestion

**`get_or_create_settings.dart`** — No changes required. The single-line delegate remains valid.

**`app_settings_repository.dart`** — No interface changes required. The new field flows through the existing `updateSettings(AppSettingsData)` path.

---

## What Was Done Well

1. **Layering discipline is clean.** None of the five files import Flutter or Drift types. `NotificationService` carries the `Lives in the domain layer — no Flutter or platform imports` comment explicitly. The feature can be implemented without violating this invariant.

2. **`copyWith` exclusion pattern is documented.** The `declaredCycleLength` exclusion at lines 83–85 is commented with a clear rationale. The new field can be included by following the same documented decision pattern.

3. **BUG-003 fix is traceable.** The day-comparison workaround at `schedule_prediction_notification.dart:44–57` has a comment block that makes it safe to remove — the fix is named, motivated, and the simpler replacement is obvious once the use case owns the full instant.

---

## Spec Inputs

### Components and files that will be affected

**In-scope (domain layer):**
- `lib/domain/entities/app_settings_data.dart` — 6 edit sites (constructor, field, `copyWith`, `==`, `hashCode`, `_AppSettingsDataDefaults`)
- `lib/domain/use_cases/schedule_prediction_notification.dart` — 3 changes: widen assert to two-field guard, replace day-comparison with instant-comparison, pass `notificationTimeMinutes` into time computation
- `lib/domain/services/notification_service.dart` — docstring only (contract correction)
- `lib/core/constants/app_constants.dart` — add `kMaxAdvanceDays = 14` and `kDefaultNotificationTimeMinutes = 540`

**No changes needed (domain layer):**
- `lib/domain/repositories/app_settings_repository.dart`
- `lib/domain/use_cases/get_or_create_settings.dart`

### Patterns to follow (and anti-patterns to avoid)

**Follow:**
- `declaredCycleLength` in `app_database.dart:107` — new column must declare `withDefault(Constant(540))` or NULL will leak into the singleton row on first launch (migration invariant)
- `notificationDaysBefore` in `_toCompanion` — new field belongs in `DriftAppSettingsRepository._toCompanion` (general user toggle, not out-of-band lifecycle field)
- Store time-of-day as `int` minutes-since-midnight — matches existing `IntColumn` convention; no `TimeOfDay` or `String` in domain or schema (CLAUDE.md §4 / lesson 11)

**Avoid:**
- Do not leave the BUG-003 day-comparison block in place after making `notifyAt` time-precise — it becomes a latent correctness bug, not harmless dead code
- Do not use `assert` alone for runtime validation of values that can arrive from storage (CSV import, migration) — upgrade to `ArgumentError` at the use-case boundary

### Integration constraints

- `lib/app.dart:121,175` — both `scheduler.execute()` call sites pass `notificationDaysBefore` as the `body:` string argument to the l10n key; the wiring must also forward `notificationTimeMinutes` to the use case once the use case signature changes
- `lib/app.dart:147` — BUG-002 guard (`if (prev is AsyncData<AppSettingsData>)`) is load-bearing; the new field changing value must trigger rescheduling via the existing `ref.listen` path — no new listener needed
- `lib/data/services/notification_service.dart:108` — `tz.TZDateTime(tz.local, local.year, local.month, local.day, 9)` is the single literal that must change to use the time extracted from `notifyAt`; `shouldShowImmediately` and the BUG-005 `show()` path are time-agnostic and must not change

### Tech debt that blocks or complicates the feature

1. **`[1,7]` range encoded in 4 places (lesson 16):** `schedule_prediction_notification.dart:37`, `settings_screen.dart:425`, entity (no validation), `app_database.dart:93–94` (no CHECK). All four must be updated; the absence of a DB CHECK means range widening is safe but out-of-range values from older DB rows will still pass through silently.
2. **`FakeNotificationService:63` — `pastNine` hardcode (lesson 14):** The fake's `pastNine = nowTime.hour >= 9` diverges from production once user-configurable time is live. Once the use case passes a fully-resolved `notifyAt`, the fake can be simplified to a timestamp comparison rather than reimplementing the time logic. **This change is mandatory before the new tests are meaningful.**
3. **`notification_prediction_body` — missing ICU plural (lesson 23):** Both `app_it.arb:253` and `app_en.arb:80` use a bare `{days}` placeholder. At `days=1` this renders "in 1 days" (EN) and "tra 1 giorni" (IT). The feature spec says to add an ICU plural fix — this is the correct file location.

### Test coverage baseline

| File | Current coverage | Gap introduced by feature |
|---|---|---|
| `schedule_prediction_notification_test.dart` | Boundary values 1, 4, 7; cold-start BUG-005; past/disabled/null paths | Need: values 8–14 (new range), `notificationTimeMinutes` variations, instant-comparison test replacing day-comparison test |
| `app_settings_data_test.dart` | Full field-by-field equality + `copyWith` | Need: `notificationTimeMinutes` equality pair, `copyWith` update, defaults assertion |
| `notification_service_test.dart` (data) | DST spring-forward at 09:00 (lesson 19) | Need: tests at user-chosen times != 09:00; DST edge cases at 02:30 spring-forward and fall-back |
| `fake_notification_service.dart` | `pastNine` routing | Must become instant-comparison routing to mirror use-case contract |
