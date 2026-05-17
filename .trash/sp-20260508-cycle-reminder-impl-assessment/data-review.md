# Data Layer Pre-Implementation Assessment
# Milestone 3 — Configurable Cycle Reminder

**Reviewer:** code-reviewer
**Date:** 2026-05-08
**Scope:** `lib/data/database/app_database.dart`, `lib/data/database/daos/app_settings_dao.dart`,
`lib/data/repositories/drift_app_settings_repository.dart`, `lib/data/services/notification_service.dart`

---

## Summary

The data layer is clean and well-layered. The Drift schema is at v6 with an established, consistent migration
pattern. The `NotificationService` 09:00 hardcode is a single literal at `notification_service.dart:108`.
All structural prerequisites for the v7 migration exist and the implementation path is low-risk, with three
pre-existing tech-debt items that will be touched by this feature and must be resolved in the same window.

---

## Findings

### Critical

**C-01 — `FakeNotificationService` time-blindness will cause spurious test results for any non-09:00 time**
`test/helpers/fake_notification_service.dart:63` — `final pastNine = nowTime.hour >= 9`

The fake's "should-fire-immediately" predicate is a hardcoded `>= 9` literal with no knowledge of the
user-chosen time. Any new test written at a time other than 09:00 will pass or fail based on whether the
wall-clock hour happens to be ≥ 9, not on the actual time-of-day semantics. The production `FlutterNotificationService`
already uses a `notifyAt`-driven comparison via `computeScheduledTz` + `shouldShowImmediately`. The fake must
mirror the same contract before any new test can be written reliably.

Fix: make the fake compare `notifyAt.toLocal()` (hour and minute) against `_now()` using the same calendar-day
+ time-order semantics as the production service, rather than the literal `9`. This is FR-13 — it is a
Must-priority prerequisite for every other test in this sprint.

---

### Important

**I-01 — No `DriftAppSettingsRepository` unit test file**

There is no `test/data/repositories/app_settings_repository_test.dart`. `_fromRow` and `_toCompanion` are
entirely untested. The stream re-emit contract (NFR-14: re-emits within one Drift tick after `updateSettings`)
has no harness. This gap must be filled as part of this sprint — stream behaviour after the new column is added
cannot be verified without it.

**I-02 — Migration test pattern does not test `onUpgrade`**
`test/data/database/app_database_migration_test.dart:23–53`

Every test in this file constructs `AppDatabase(NativeDatabase.memory())` and calls `getOrCreateSettings()`.
This exercises `onCreate` only — `onUpgrade` is never executed in these tests. The v5→v6 "test" at lines
55–183 re-runs the raw SQL manually, bypassing Drift's `MigrationStrategy` entirely. The v6→v7 migration test
required by NFR-08 (upgrade from v6, assert `notificationTimeMinutes` defaults to 540) cannot be written
in this pattern. A proper v6-snapshot test is needed: insert a row into a fresh DB with schema v6 SQL
(`CREATE TABLE app_settings ...` without the new column), bump `schemaVersion` to 7, reopen, verify the row
has `notification_time_minutes = 540`. Alternatively, use `drift_dev`'s
`SchemaVerifier` / `NativeDatabase.memory()` with explicit column-set narrowing.

**I-03 — Range bound encoded in four places with no constant**
`lib/domain/use_cases/schedule_prediction_notification.dart:37` — `<= 7` (assert)
`lib/features/settings/settings_screen.dart:425` — `for (int i = 0; i < 7; i++)`
`lib/data/database/app_database.dart:94` — `withDefault(const Constant(2))` (only default, not constraint)
`app_it.arb:373` / `app_en.arb:149` — plural metadata implies the range

No `AppConstants.kMaxAdvanceDays` constant exists today. The migration that widens from 7 to 14 must touch
all four locations in lockstep. FR-18 addresses this; it is a Should-priority FR but the fragility is real —
a partial update would leave the assert firing on legal new values 8–14 in debug builds while release silently
discards the constraint.

**I-04 — `copyWith` and `==`/`hashCode` must both receive the new field**
`lib/domain/entities/app_settings_data.dart:60–116`

`notificationTimeMinutes` is a general user-toggle field (not an out-of-band lifecycle field like
`declaredCycleLength`, `dropboxEmail`, or `onboardingCompleted`). Per the `_toCompanion` inclusion criterion,
it must appear in: `copyWith` (line 60), `==` (line 90), `hashCode` (line 107), the `_AppSettingsDataDefaults`
constructor (line 119), and both `_fromRow` and `_toCompanion` in the repository (lines 32–53).
The spec's R-13 names this as "compile-time error if missed" — but `hashCode` and `_AppSettingsDataDefaults`
are silently broken (no compile error) if omitted. Flag as a named checklist item for the implementer.

---

### Suggestion

**S-01 — `tz.UTC` silent fallback produces no diagnostic trace**
`lib/data/services/notification_service.dart:55–58`

The `on Exception` block that falls back to UTC logs nothing. At 09:00 fixed, the effect is visible.
At a user-chosen nighttime time the misfire is harder to detect.  FR-20 adds a local-only `debugPrint`
(or equivalent) here — add it at the same time as the hardcode removal, not later.

---

## What Was Done Well

1. **Migration pattern is consistent and well-documented.** The v5 precedent at `app_database.dart:198–205`
   is the exact template for the v7 `notificationTimeMinutes` column: one `addColumn` with `withDefault(Constant(540))`, no
   `customStatement` needed. The pattern is unambiguous.

2. **`getOrCreateSettings` correctly delegates to column defaults.** The DAO inserts only
   `languageCode: Value('')` (line 42) and relies on `withDefault(...)` for every other field.
   This means the new column needs only a column-level `withDefault(Constant(540))` — no DAO change required
   for cold-start correctness.

3. **`shouldShowImmediately` in the service is already time-aware.** The predicate at `notification_service.dart:118–123`
   compares `tz.TZDateTime` objects using `isAfter`, not a literal hour. Moving the time-of-day resolution
   upstream (into the use case as a fully-resolved `notifyAt`) means this method requires no change —
   it already expresses the correct contract.

---

## Spec Inputs

### Affected files

| File | Change |
|------|--------|
| `lib/data/database/app_database.dart:141` | `schemaVersion` 6 → 7 |
| `lib/data/database/app_database.dart:206–234` | Add `if (from < 7)` block with `m.addColumn(appSettings, appSettings.notificationTimeMinutes)` |
| `lib/data/database/app_database.dart:87–108` | Add `IntColumn get notificationTimeMinutes => integer().withDefault(const Constant(540))();` to `AppSettings` table class |
| `lib/data/database/daos/app_settings_dao.dart` | No change required — defaults pattern handles cold-start |
| `lib/data/repositories/drift_app_settings_repository.dart:32–53` | Add `notificationTimeMinutes: row.notificationTimeMinutes` in `_fromRow`; add `notificationTimeMinutes: Value(data.notificationTimeMinutes)` in `_toCompanion` |
| `lib/data/services/notification_service.dart:95–108` | Remove the hardcoded `, 9)` in `computeScheduledTz`; accept `int timeMinutes` parameter; construct `tz.TZDateTime(tz.local, ..., timeMinutes ~/ 60, timeMinutes % 60)` |
| `lib/domain/entities/app_settings_data.dart` | Add `notificationTimeMinutes` field; update `copyWith`, `==`, `hashCode`, `_AppSettingsDataDefaults` |
| `test/helpers/fake_notification_service.dart:63` | Replace `pastNine` with `notifyAt`-driven comparison (FR-13 — prerequisite) |
| `test/data/database/app_database_migration_test.dart` | Add v6→v7 migration round-trip test with snapshot schema |
| `test/data/repositories/app_settings_repository_test.dart` | Create: `_fromRow`/`_toCompanion` round-trip, stream re-emit after update, new field survives persist/reload |

**Cross-module dependencies (outside scope — for orchestrator to dispatch):**
- `lib/domain/use_cases/schedule_prediction_notification.dart:37` — `assert(<= 7)` fires on values 8–14 in debug builds; widens to `kMaxAdvanceDays`
- `lib/features/settings/settings_screen.dart:425` — `for (int i = 0; i < 7; i++)` drives picker; widens to `kMaxAdvanceDays`
- `lib/domain/entities/app_settings_data.dart` (domain, not data layer) — same `notificationTimeMinutes` addition applies here

### Patterns to follow

- **Adding a defaulted AppSettings column:** `addColumn` in `onUpgrade` only, with column-level `withDefault(Constant(...))`. No `customStatement`, no UPDATE. Precedent: v5 block at `app_database.dart:198–205`.
- **Field inclusion in `_toCompanion`:** general user-toggle fields go in; fields with dedicated lifecycle writers (`dropboxEmail`, `lastBackupAt`, `onboardingCompleted`, `declaredCycleLength`) stay out.
- **`getOrCreateSettings` is not a surface to touch** — its minimal insert relies structurally on column defaults; adding the new column at the table level is sufficient.
- **Anti-pattern to avoid:** `customStatement` for a simple defaulted-column add. The only prior `customStatement` usage in migrations is for data reshaping (v4 FlowType index change, v6 PainSymptomType index shift). The new column needs none of that.

### Integration constraints

- **Singleton row at id = 1.** Every update targets `WHERE id = 1`. Preserve this in all new write paths.
- **Schema version bump is a single-site change** — `app_database.dart:141` only.
- **`BackupSnapshot` does not carry `AppSettingsData`** (confirmed: `lib/data/services/backup/sync_orchestrator.dart:68–70`). The new field is never serialised into a backup. `BackupSnapshot.currentVersion` is unchanged.
- **Drift stream contract:** `watchSettings()` uses `watchSingleOrNull()` on the singleton row. The stream re-emits automatically on every `update` call — no additional `ref.invalidate` or manual notification required.
- **`computeScheduledTz` signature change** is the only change to `FlutterNotificationService`'s public-facing helpers. `shouldShowImmediately` is time-aware already and does not change. `schedulePredictionNotification` receives a fully-resolved `notifyAt` from the use case — the service stays policy-free.

### Tech debt that blocks or complicates the feature

| Debt | Blocking? | Action in this sprint |
|------|-----------|----------------------|
| `FakeNotificationService:63` hardcodes `>= 9` | **Blocks** — all new tests at non-09:00 are unreliable | Fix first (FR-13) |
| No `app_settings_repository_test.dart` | **Blocks** NFR-14 stream re-emit verification | Create in this sprint |
| Migration test pattern bypasses `onUpgrade` | Blocks NFR-08 upgrade verification | Write snapshot-based v6→v7 test |
| Range bound in 4 places, no constant | Complicates — partial update leaves assert firing on 8–14 | Extract `kMaxAdvanceDays` simultaneously (FR-18) |
| `notification_prediction_body` not ICU plural | Complicates — surfaces with any `days=1` scenario | Fix in same l10n window (FR-12) |

### Test coverage baseline

| Area | Current coverage | Gap |
|------|-----------------|-----|
| `AppSettingsDao` | Indirect (via `app_database_migration_test.dart`) | No direct DAO test; no `onUpgrade` path tested |
| `DriftAppSettingsRepository` | None — no test file | Full gap; `_fromRow`, `_toCompanion`, stream, dedicated writers all untested |
| `FlutterNotificationService` | `computeScheduledTz` (3 tests), `shouldShowImmediately` (4 tests), `kPredictionNotificationId` (1 test) | DST tests for user-chosen times; `computeScheduledTz` with non-09:00 minutes argument |
| `FakeNotificationService` routing | 2 routing tests (same-day/future), both drive `nowOverride` against literal `09:00` notifyAt | Tests are semantically correct today but will break when `pastNine` logic is removed unless rewritten |
| `SchedulePredictionNotification` | Cancel-first, null, disabled, past, future, boundary at 1/4/7, BUG-005 cold-start | Values 8–14 untestable until assert is widened; `notificationTimeMinutes` path entirely absent |
| Migration | v6 `onUpgrade` SQL exercised as bare SQL (not via `MigrationStrategy`); v5→v4, v3, v2 not tested at all | v6→v7 `onUpgrade` round-trip test required for NFR-08 |
