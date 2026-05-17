# [LP-ASSESS] Configurable Cycle Reminder

```yaml
project: metra
request_type: feature
assessed_modules: 4
```

**Date**: 2026-05-08
**Initiative**: "Rewrite cycle reminder notification feature from scratch — let the user choose how many days in advance to be notified (1–14, currently 1–7) AND at what time of day (currently hardcoded 09:00). Design-first workflow: light HTML mockup → dark + design system + UI bible → Flutter implementation."

---

## Module summaries

The full per-module assessments are persisted as standalone files in this directory. The synopses below are pointers; the canonical contract for downstream agents is the **§ Spec Inputs** section at the end of this file.

### Module: Settings UI

**Path**: `lib/features/settings/`
**Full assessment**: [`settings-ui-assessment.md`](settings-ui-assessment.md)

Settings screen is **932 lines** in a single file (settings_screen.dart) — far past the project's 150-line widget rule. All five existing pickers (`_showLanguagePicker`, `_showThemePicker`, `_showAdvancePicker`, `_showDeleteConfirmation`, plus `_showAdvancePicker`) follow the **identical** `showModalBottomSheet(isScrollControlled: true) → Column(mainAxisSize.min) → ListTile` pattern. The advance-day picker today builds 7 ListTiles via a `for (int i = 0; i < 7; i++)` loop at line 425. The same modal pattern **cannot scale to 14 options** on a 360×640 viewport (≈784 px needed, 640 px available) — extending forces a real `Scrollable`, which directly conflicts with the regression guards from `qp-20260507-notification-days-combobox-glitch` and `qp-20260507-advance-picker-real-device-clipping` that explicitly assert `find.byType(Scrollable) findsNothing` inside the sheet.

The time-of-day picker has **no precedent** in the file — neither `showTimePicker` nor a custom wheel exists. Reuse seam for the new "Time" row is straightforward (it's a third value-row inside the existing Notifiche `_GroupCard` at lines 108–138), but the picker invocation needs a fresh design decision.

### Module: Notification Scheduling Pipeline

**Path**: `lib/domain/services/`, `lib/domain/use_cases/`, `lib/data/services/notification_service.dart`, platform manifests
**Full assessment**: [`scheduling-pipeline-assessment.md`](scheduling-pipeline-assessment.md)

**No residual scheduling defect** survived BUG-001..005 (anchor computation, timezone conversion, cold-start same-day path, cancel-first invariant are all sound). The user's "issue not fixed yet" framing is best read as the **rewrite scope itself** (configurable time/days), not a hidden bug.

The behavioural hardcode `09:00` lives in **exactly one** production line: `lib/data/services/notification_service.dart:108` — `tz.TZDateTime(tz.local, local.year, local.month, local.day, 9)`. The `[1, 7]` range is encoded in **four** places: use-case assert (debug-only), settings UI loop bound, Drift column **without** CHECK constraint (CSV import can land out-of-range), and 9 test fixtures.

Three latent issues will silently break the rewrite if not surfaced now:

1. `test/helpers/fake_notification_service.dart:63` hardcodes `pastNine = nowTime.hour >= 9` — new tests at non-09:00 will pass/fail spuriously.
2. Drift column has no CHECK constraint — out-of-range values accepted from CSV import.
3. Silent `tz.UTC` fallback at `lib/data/services/notification_service.dart:55-58` is harder to detect at non-09:00.

**Domain shape recommendation**: two `int` fields (`notificationHour`, `notificationMinute`) on `AppSettingsData`, **NOT** a Flutter `TimeOfDay` (would violate CLAUDE.md §4 layering). Defaults `(9, 0)` to preserve upgrade behaviour. Alternative — preferred by this assessor — move time resolution into the use case so `notifyAt` is a fully-resolved `DateTime` and the fake/service just compares timestamps.

Platform manifests need **NO** changes for arbitrary user-chosen times — `SCHEDULE_EXACT_ALARM` already covers any wall-clock time at minSdk 24. iOS `NSUserNotificationsUsageDescription` is unused at runtime (legacy macOS plural form), but harmless.

### Module: Persistence + Wiring

**Path**: `lib/data/database/`, `lib/data/repositories/`, `lib/domain/repositories/`, `lib/providers/`, `lib/app.dart`
**Full assessment**: [`persistence-wiring-assessment.md`](persistence-wiring-assessment.md)

**Critical correction to the brief**: AppSettings is **NEVER** serialized into the encrypted backup blob. The Métra backup payload is `AES(JSON(daily logs + symptoms))` — `BackupSnapshot` carries no settings. Evidence at `lib/data/services/backup/sync_orchestrator.dart:68-70`. The new column has **zero backup-format impact** — no `BackupSnapshot.currentVersion` bump needed. This is the single biggest risk-reducer for the rewrite.

**Migration is trivial**: single `m.addColumn(appSettings, appSettings.notificationTimeMinutes)` in a new `from < 7` block; bump `schemaVersion` 6→7. Column-level `withDefault(Constant(540))` backfills existing rows automatically — no `customStatement` required. The v5 `declaredCycleLength` migration (`app_database.dart:198-204`) is the canonical precedent. `AppSettingsDao.getOrCreateSettings()` relies on column defaults — no change needed.

**Column type recommendation**: single `IntColumn` of minutes-since-midnight (0–1439, default `540` = 9×60). Justified against the codebase's unambiguous convention of encoding all structured-but-numeric values as `IntColumn` (`flowType.index`, `flowIntensity`, `symptomType`, `notificationDaysBefore`).

**Provider graph**: NO changes needed — the new field flows through the existing `AppSettingsData` → `SettingsNotifier` → app listener → `scheduler.execute(settings: ...)` path unchanged.

**BUG-002 guard at `app.dart:147` (`if (prev is AsyncData<AppSettingsData>)`) MUST survive the rewrite verbatim** — it prevents cold-start from silently overwriting the user's persisted `notificationsEnabled` preference when OS permission is revoked between sessions.

**Listener tech debt opportunistically addressable**: settings listener has no notification-relevance gate at `app.dart:131-183` — every settings change (theme, language, cycle length, etc.) triggers a cancel + zonedSchedule round-trip. 5-line `if (!notifChanged) return;` guard cleanly fits during this rewrite.

### Module: Tests + Localization + Design Canon

**Path**: `test/`, `lib/l10n/`, `docs/design/`, `.claude/docs/canon/ui-design-bible.md`
**Full assessment**: [`tests-l10n-design-assessment.md`](tests-l10n-design-assessment.md)

**Design canon** (priority — the user mandates "design-first" via `feedback_ui_change_protocol.md`):

- The Notifiche group lives at `docs/design/metra-screens-light.html` **lines 1199–1207** and its dark mirror at `metra-screens-dark.html` **lines 1206–1214**. Identical structure: one toggle row + one value row.
- The new "time of day" row needs **no new atom** — it is a third `SettingsRow` value variant. The only mockup edit is appending one row + one divider in both light and dark.
- Bible **§ 18.8** and **§ 15** *explicitly disown* bottom sheets: *"Pickers and confirmations are implementation-side concerns."* Yet the **current Flutter implementation already uses one** (asserted by `test/features/settings/settings_screen_test.dart:384`). The planner must pick an explicit position:
  - **Option A** — keep the gap; add a one-line "implementation-side" note in § 18.8.
  - **Option B** — promote the picker to canon; add a § 19 to the bible + a component to `metra-design-system.html`.
  - This is **the most consequential design decision of the rewrite**.

**Localization**:

- All existing keys quoted in detail in the per-module file. The `settings_advance_value` plural already covers 1–14 — no plural-category work needed.
- **Latent bug to fix in scope**: `notification_prediction_body` is **not** ICU-plural. With `days=1` IT renders `"…tra 1 giorni"`, EN `"in 1 days"`. Cheap fix on the same code path.
- New keys recommended: `settings_notification_time_label`, `settings_notification_time_dialog_title`, optionally body-when-fired-today variant.
- No project-wide 24h override — use `MaterialLocalizations.of(context).formatTimeOfDay(time)` for the row's value text.

**Tests**:

- Two regression nets at risk: **qp-combobox-glitch** (`settings_screen_test.dart:402`) and **qp-real-device-clipping** (`settings_screen_test.dart:519`). Both assert `find.byType(Scrollable) findsNothing` inside the picker. At 56 px × 14 options this is structurally impossible on a 360×640 viewport — **explicit decision required**.
- BUG-002 cold-start permission guard (`app_notification_wiring_test.dart:113-267`) and BUG-005 cold-start show fallback (`schedule_prediction_notification_test.dart:259`) **must keep green**. BUG-005 hard-codes `9` as the boundary and needs to drive that off the user-chosen time.
- `notification_service_test.dart:101, 124, 150` each assert `expect(result.hour, equals(9))` — three concrete coupling points the rewrite must parametrise.
- New test groups required: time-of-day propagation, DST gap/overlap at chosen times (Italy 2026-03-29 spring-forward, 2026-10-25 fall-back), midnight wrap, narrow-viewport rendering of the new row, all 14 day-options reachable.

---

## Spec Inputs

> **Contract for downstream agents.** lp-spec-writer and lp-planner read this section as the primary input. Per-module deep dives are linked above.

### Affected files (consolidated)

| Module | File | Relevance |
|--------|------|-----------|
| Design canon | `docs/design/metra-screens-light.html` | Notifiche group at lines 1199–1207 — appends a new value row for time of day |
| Design canon | `docs/design/metra-screens-dark.html` | Mirror at lines 1206–1214 — must mirror light edit |
| Design canon | `docs/design/metra-design-system.html` | § 14 `S14_Impostazioni` — extend with new row; if Option B, add a new picker component section |
| Design canon | `.claude/docs/canon/ui-design-bible.md` | § 14 lexicon (new label entry), § 18.6 Section structure (third row), § 18.8 picker disposition (Option A/B) |
| Settings UI | `lib/features/settings/settings_screen.dart` | Three rows in Notifiche `_GroupCard`; new picker method; loop bound 7→14; recommended extraction `_NotificationsSection` |
| Settings UI | `lib/features/settings/state/settings_notifier.dart` | No behavioural change; verify stream re-emits after migration |
| Domain entity | `lib/domain/entities/app_settings_data.dart` | New `notificationTimeMinutes` field (or hour+minute pair); constructor / `copyWith` / `==` / `hashCode` / `_AppSettingsDataDefaults` (default `540`) |
| Domain interface | `lib/domain/services/notification_service.dart` | Dartdoc at line 30 says "fires at 09:00 local time" — update; signature may need a parameter or use case carries fully-resolved `DateTime` |
| Domain use case | `lib/domain/use_cases/schedule_prediction_notification.dart` | Range assert lines 35–40 (1–7 → 1–14); compose chosen time into `notifyAt` |
| Domain entity | `lib/domain/entities/cycle_prediction.dart` | No change — anchor unchanged |
| Data service | `lib/data/services/notification_service.dart` | Line 108 literal `9` is the only behavioural hardcode; tz.UTC silent fallback (55–58) flagged for diagnostic logging |
| Drift schema | `lib/data/database/app_database.dart` | New column at AppSettings (87–108); `from < 7` migration step; bump `schemaVersion` 6→7 (line 141) |
| Drift codegen | `lib/data/database/app_database.g.dart` | Auto-regenerated by build_runner — never hand-edit |
| Drift DAO | `lib/data/database/daos/app_settings_dao.dart` | NO change — `getOrCreate` relies on column defaults |
| Repository | `lib/data/repositories/drift_app_settings_repository.dart` | `_fromRow` (32–43), `_toCompanion` (45–53) — add field both directions; goes IN `_toCompanion` (general settings field, no exclusion) |
| Domain repo iface | `lib/domain/repositories/app_settings_repository.dart` | NO change |
| Providers | `lib/providers/use_case_providers.dart` | NO change |
| Providers | `lib/providers/repository_providers.dart` | NO change |
| App listeners | `lib/app.dart` | Preserve BUG-002 guard at line 147 verbatim; opportunistically add notification-relevance gate to settings listener (lines 131–183) |
| Localization | `lib/l10n/app_en.arb` | New keys `settings_notification_time_label`, `settings_notification_time_dialog_title`; convert `notification_prediction_body` to ICU plural |
| Localization | `lib/l10n/app_it.arb` | Same edits in Italian |
| Localization | `lib/l10n/app_localizations.dart` | Auto-regenerated — never hand-edit |
| Platform — Android | `android/app/src/main/AndroidManifest.xml` | NO change required for arbitrary chosen times |
| Platform — iOS | `ios/Runner/Info.plist` | NO change required |
| Tests — fake | `test/helpers/fake_notification_service.dart` | Drop hardcoded `>= 9` (line 63); route based on `notifyAt` time component |
| Tests — service | `test/data/services/notification_service_test.dart` | Parametrise `expect(result.hour, equals(9))` at lines 101, 124, 150; add DST + midnight cases |
| Tests — use case | `test/domain/use_cases/schedule_prediction_notification_test.dart` | Add 14-day upper bound; add time-of-day propagation; update BUG-005 boundary off chosen time (line 259) |
| Tests — wiring | `test/app_notification_wiring_test.dart` | Extend FR-09 happy path with time component; BUG-002 group untouched |
| Tests — settings UI | `test/features/settings/settings_screen_test.dart` | Extend advance picker to 1–14 (lines 368–524); new top-level group for time-of-day row |

### Key risks (consolidated)

| ID | Risk | Source module | Severity |
|----|------|---------------|----------|
| AR-01 | **No-Scrollable picker invariant breaks at 14 options on 360×640.** Existing regression nets (`qp-combobox-glitch`, `qp-real-device-clipping`) explicitly forbid `Scrollable` inside the picker sheet. 14 ListTiles ≈ 784 px do not fit on a 640 px viewport. Forces explicit UX decision. | Settings UI / Tests | **High** |
| AR-02 | **Bible § 18.8 disowns picker patterns** as "implementation-side", but the Flutter code already uses BottomSheet and the rewrite adds another picker. Drift between canon and code widens. Planner must pick Option A (note in § 18.8) or Option B (promote to bible § 19 + design system). | Design canon | **High** |
| AR-03 | **`FakeNotificationService` hardcodes `>= 9`** at line 63 — new tests at non-09:00 will pass/fail spuriously without a fake update. | Scheduling pipeline / Tests | **High** |
| AR-04 | **`SchedulePredictionNotification.execute` `assert(... <= 7)` at lines 35–40** will fire on legal new values 8–14 in debug builds; release builds silently skip the assert's intent. Must be widened in same PR as the schema/UI change. | Scheduling pipeline | **High** |
| AR-05 | **DST gap/overlap at non-09:00 times.** Italy spring-forward 2026-03-29 02:00→03:00 — picking 02:30 → notification fires 03:30 (timezone package shifts forward). Italy fall-back 2026-10-25 03:00→02:00 — picking 02:30 → first occurrence. Must pin policy with regression tests, do not surprise users. | Scheduling pipeline | Medium |
| AR-06 | **Drift column has no CHECK constraint** on `notificationDaysBefore`. CSV import or migration corruption can land out-of-range values; the assert is debug-only. Add CHECK after a one-shot clamp or defensive boundary at the repository. | Persistence | Medium |
| AR-07 | **Silent `tz.UTC` fallback** if `FlutterTimezone.getLocalTimezone()` fails. Today only shifts 09:00 by UTC offset — visible. With user-chosen times the fallback is harder to detect. Add a local-only diagnostic log line. | Scheduling pipeline | Medium |
| AR-08 | **Listener double-fire window at cold-start.** Both `cyclePredictionProvider` and `settingsNotifierProvider` may emit in the same frame; mitigated today by cancel-first invariant. Document in test plan; do not re-engineer. | Persistence | Low |
| AR-09 | **`notification_prediction_body` not ICU-plural.** Pre-existing latent bug — `days=1` renders ungrammatical IT/EN. The new range still has 1 as legal lower bound, so the bug surfaces in the same code path. Fix in scope. | Localization | Low |
| AR-10 | **iOS Focus / DND silently suppresses nighttime notifications.** Pre-existing, surfaces more visibly with user-chosen nighttime times. No `time-sensitive` entitlement requested — by design, do not bypass user OS preferences. | Scheduling pipeline | Low |
| AR-11 | **iOS `NSUserNotificationsUsageDescription`** is the legacy macOS plural form, unused at runtime by `flutter_local_notifications`. Cosmetic only; do not "fix" without verification. | Scheduling pipeline | Low |
| AR-12 | **Listener over-reschedules on unrelated settings changes.** Theme/language/cycle-length saves trigger a full cancel + zonedSchedule. Wasteful, not buggy. Address opportunistically with a relevance gate. | Persistence | Low |
| AR-13 | **`AppSettingsData` construction-site cascade** — full-positional construction at `settings_screen.dart:374-382` and repository mappings must add the new field; missing one is a compile error (acceptable). | Domain | Low |

### Tech debt (prioritized for plan ordering)

| Priority | Item | Module | Rationale |
|----------|------|--------|-----------|
| 1 | Lift the `7`/`14` magic number to `AppConstants.kMaxAdvanceDays` (single source) | Settings UI / Domain | Field being changed; constant is the natural seam — touches all four encoding sites at once (assert, picker loop, ARB plural, tests) |
| 2 | Make `FakeNotificationService` time-aware (drop `>= 9` literal) | Tests | Without this, every new test at non-09:00 is unreliable — pre-condition for new test coverage |
| 3 | Move time-of-day resolution from service into use case (return fully-resolved `DateTime`) | Domain / Data service | Lets fake and service share the same comparison; collapses three test hardcodes into one parameter |
| 4 | Update domain interface dartdoc to drop "09:00 local time" | Domain | Trivial; mandatory once code changes |
| 5 | Add notification-relevance gate to `app.dart` settings listener | App wiring | 5-line `if (!notifChanged) return;` after BUG-002 block — natural moment, removes wasted reschedules |
| 6 | Convert `notification_prediction_body` to ICU plural | Localization | Pre-existing IT/EN grammar bug; surfaces at days=1 (still legal lower bound) |
| 7 | Add `if (state.valueOrNull == settings) return;` guard in `SettingsNotifier.save` | Settings UI | One line; removes a real Drift round-trip + listener reschedule on no-op tap |
| 8 | Extract `_NotificationsSection` widget from `settings_screen.dart` (currently 932 lines) | Settings UI | Gives the new time row a focused home; keeps file under 1000 lines |
| 9 | Add diagnostic log on `tz.UTC` fallback (no telemetry) | Data service | Local-only; trail when users report wrong-time notifications |
| 10 | Optional: add CHECK constraint on `notificationDaysBefore` (post-clamp) | Persistence | Defensive; v6→v7 already migrating |

**Out of scope** (do NOT widen): `_handleExport` / `_handleImport` extraction (~178 lines on the screen widget); `_MetraToggle` 28 dp hit target (pre-existing accessibility gap); `_toCompanion` exclusion explicit-list refactor.

### Integration points

- **Settings UI ↔ Domain entity**: `AppSettingsData` flows through `SettingsNotifier` → `_save` → `repo.updateSettings`. New field travels here unchanged.
- **Domain entity ↔ Use case**: `SchedulePredictionNotification.execute(settings: ...)` already receives the full entity. New time-of-day must compose into `notifyAt`.
- **Use case ↔ Service**: today the service decides hour=9; recommended to flip so the use case emits a fully-resolved `DateTime` and service is policy-free.
- **Service ↔ Platform**: `flutter_local_notifications` + `flutter_timezone` + `tz.TZDateTime`. No platform-manifest change required.
- **App listeners (`lib/app.dart`)**: prediction listener (line 104–129) + settings listener (line 131–183). BUG-002 guard at line 147 — preserve verbatim.
- **Drift schema ↔ Repository**: new column flows through `_fromRow`/`_toCompanion`; goes IN the general path (no exclusion). v6→v7 migration is one-line `addColumn`.
- **Backup blob**: AppSettings is **NOT** in `BackupSnapshot`. No backup-version bump; no restore path change.
- **Tests ↔ all of the above**: `FakeNotificationService` is the central fixture — making it time-aware unlocks every other new test.
- **Design canon ↔ implementation**: HTML mockup → bible → Flutter (per `feedback_ui_change_protocol.md`). The picker UX decision (Option A vs B) gates everything downstream.

### Proposed scope boundaries

**In scope (must ship together)**

- Add a third row "Time of day" / "Orario" to the Notifiche section in **both** `metra-screens-light.html` and `metra-screens-dark.html`, mirroring the existing `SettingsRow` value variant.
- Update `metra-design-system.html` § 14 (`S14_Impostazioni`) to render the third row.
- Update `.claude/docs/canon/ui-design-bible.md` § 14 lexicon (new label) + § 18.6 (Notifiche row count) + § 18.8 (explicit picker disposition: Option A or B).
- Domain: add time-of-day to `AppSettingsData` (recommended: single `int notificationTimeMinutes`, default `540`); widen `notificationDaysBefore` range from 1–7 to 1–14; relax assertion in use case; flip use case to compose fully-resolved `notifyAt` `DateTime`.
- Drift: `from < 7` migration adding `notificationTimeMinutes` IntColumn with `withDefault(Constant(540))`; bump `schemaVersion` 6→7.
- Repository: extend `_fromRow` and `_toCompanion`; new field included in general save path.
- Data service: drop the `9` literal at `notification_service.dart:108`; use TZ from the resolved DateTime; preserve `shouldShowImmediately`, `cancel-first`, `AndroidScheduleMode.exactAllowWhileIdle`, `PlatformException` swallow.
- Settings UI: new "Time" row in the Notifiche `_GroupCard`; **one new picker UX decision** (constraint: 1–14 days picker AND time-of-day picker on 360×640); extract `_NotificationsSection` widget.
- Localization: `settings_notification_time_label`, `settings_notification_time_dialog_title` (EN + IT); convert `notification_prediction_body` to ICU plural for both locales.
- App listener: preserve BUG-002 guard verbatim; add notification-relevance gate to settings listener.
- `FakeNotificationService`: drop hardcoded `9`; route based on `notifyAt` time component.
- Tests: parametrise the three `expect(result.hour, equals(9))` lines; widen the 1–7 picker tests to 1–14; add DST gap / overlap / midnight cases; new group for time-of-day row in settings widget; preserve every BUG-002, BUG-004, BUG-005, qp-combobox-glitch, qp-real-device-clipping regression with updated assertions.

**Out of scope (do NOT touch in this rewrite)**

- `_handleExport` / `_handleImport` extraction off `SettingsScreen` (~178 lines, separate refactor sprint).
- `_MetraToggle` 28 dp hit target (pre-existing accessibility issue; not in this section).
- iOS time-sensitive entitlement (would bypass user DND — violates "respect the adult user").
- Android `USE_EXACT_ALARM` (requires minSdk 33, currently 24).
- Backup format version bump (AppSettings is not in the snapshot).
- New backup or sync code paths.
- Any change to `cyclePredictionProvider` semantics.
- Any change to `kPredictionNotificationId = 1001`.
- Removing `_toCompanion` exclusions for `declaredCycleLength`, `dropboxEmail`, `lastBackupAt`, `onboardingCompleted` — those have dedicated writers for good reason.

**Open questions for the spec phase**

- **OQ-A** Picker UX for 1–14 days: scrollable bottom sheet (relax invariant) vs. wheel picker (`CupertinoPicker`, `NumberPicker`) vs. two-column layout vs. native dialog. **The most consequential decision of the rewrite.** Requires bible disposition (Option A vs B).
- **OQ-B** Time-of-day picker: Material `showTimePicker` vs. custom wheel vs. inline within the same sheet. Locale-aware formatting via `MaterialLocalizations.formatTimeOfDay`.
- **OQ-C** Default time: 09:00 (preserves current behaviour) vs. ask the user during onboarding. Recommended: 09:00 default, no onboarding prompt.
- **OQ-D** Minute granularity: every minute (0–59), every 5 minutes, or hour-only. Flutter's `showTimePicker` defaults to minute granularity; constraint impacts wheel UX.
- **OQ-E** DST policy at non-09:00: silent shift (current behaviour) vs. user disclosure. Recommended: silent — it's a non-medical reminder; once-a-year ±1h is acceptable.
- **OQ-F** Bible disposition: Option A (note picker as implementation-side) vs. Option B (promote picker to canon). **Must be answered before implementation begins.**
- **OQ-G** Body wording for same-day cold-start fallback: keep current `notification_prediction_body` (time-agnostic) or add a `_today` variant. Recommended: keep current; body is already time-agnostic.
- **OQ-H** Are `settings_notifications_on` / `_off` ARB keys still wired? If not, delete to keep canon aligned.
