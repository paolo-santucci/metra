## Module: Notification Scheduling Pipeline

**Path**: `lib/domain/services/`, `lib/domain/use_cases/`, `lib/data/services/notification_service.dart`, platform manifests
**Agent**: code-reviewer
**Initiative**: rewrite cycle reminder — user-configurable advance days (1–14) AND time of day (currently hardcoded to 09:00)

---

### Findings

#### 1. Current scheduling architecture — how the pipeline works today

##### 1.1 Anchor computation (use case → service)

`lib/domain/use_cases/schedule_prediction_notification.dart:33-58` is the only place where the anchor is decided. The flow is, in order:

1. Always cancel: `await _notifService.cancelPredictionNotifications();` (line 33). This is unconditional and runs **before** the early returns — see §1.4 for invariant analysis.
2. Early-return on disabled or null prediction: `if (prediction == null || !settings.notificationsEnabled) return;` (line 34).
3. Range assert: `assert(settings.notificationDaysBefore >= 1 && settings.notificationDaysBefore <= 7, ...)` (lines 35–40). Only fires in debug; production accepts any int silently.
4. Day-only anchor: `notifyAt = prediction.windowStart.subtract(Duration(days: settings.notificationDaysBefore))` (lines 41–42). Note this is a `DateTime`, not a `tz.TZDateTime`. `prediction.windowStart` is whatever `WatchCyclePrediction` produced — typically UTC midnight (see `lib/domain/entities/cycle_prediction.dart:31`).
5. BUG-003 same-day calendar comparison in **local** time (lines 43–57). `notifyAt.toLocal()` then compare year/month/day.
6. Forward to service if not in the past: `await _notifService.schedulePredictionNotification(notifyAt, title, body)` (line 58).

Critical observation: **the use case decides the calendar day; the service decides the wall-clock time**. The use case has no concept of "9 AM"; that lives only in `FlutterNotificationService`. This split is sound and survives the rewrite — `notifyAt` will continue to carry only the date; the new `notificationTimeOfDay` setting must be applied at the service layer (or read in the use case and passed as additional args — see §2 trade-off).

##### 1.2 Hardcoded `09:00` — every production occurrence

The actual literal lives in **one** production code line. All other "09:00" matches are comments or test code.

- `lib/data/services/notification_service.dart:108`
  ```dart
  return tz.TZDateTime(tz.local, local.year, local.month, local.day, 9);
  ```
  This is the only behavioural hardcode. The `9` is the hour positional argument to `TZDateTime` — note the absence of an explicit minute argument (defaults to 0). The rewrite must replace `9` with the user's `notificationHour` and add an explicit minute argument.

- `lib/data/services/notification_service.dart:86, 93, 112, 131, 137` — comments referring to "09:00".
- `lib/domain/services/notification_service.dart:30` — interface dartdoc says "fires at 09:00 local time"; must be updated.
- `lib/domain/use_cases/schedule_prediction_notification.dart:46` — comment about "09:00 local" in BUG-003 explanation; still accurate post-rewrite if "09:00" is replaced with "the user-chosen time".

Test-side hardcodes (out of "Scope" but flagged for completeness):
- `test/data/services/notification_service_test.dart:84,108,130,164,178,200,208,216,217,224` — many TZDateTime constructions use `9, 0`. These are documentation tests of the BUG-004 fix; they can stay literal but should grow parallel cases at non-9 AM times when the rewrite lands.
- `test/helpers/fake_notification_service.dart:63` — `final pastNine = nowTime.hour >= 9;` — see §3.3, this is a contract gap.

##### 1.3 `shouldShowImmediately(...)` — cold-start predicate

`lib/data/services/notification_service.dart:117-123`:

```dart
@visibleForTesting
bool shouldShowImmediately(tz.TZDateTime scheduledDate, tz.TZDateTime now) {
  final sameDay = scheduledDate.year == now.year &&
      scheduledDate.month == now.month &&
      scheduledDate.day == now.day;
  return sameDay && !scheduledDate.isAfter(now);
}
```

The predicate compares calendar days and then checks `now >= scheduledDate`. It is **time-of-day-agnostic**: nothing about it presumes 09:00. When `scheduledDate` becomes `…, hour, minute` instead of `…, 9, 0`, the predicate keeps working unchanged. The rewrite **must not** "fix" this — it is correct as-is. A regression test at e.g. `scheduledDate = (…, 3, 0)` and `now = (…, 4, 0)` should be added to lock the behaviour.

Call site is `lib/data/services/notification_service.dart:135-156`:

```dart
if (scheduledDate.isBefore(now)) {
  if (shouldShowImmediately(scheduledDate, now)) {
    await _plugin.show(...);            // BUG-005 fix
  }
  return;
}
```

Sound for any time-of-day. The `_plugin.show()` payload at line 140-153 is identical to the scheduled payload at line 165-168 except for the missing `priority: Priority.high` on the scheduled iOS branch (which doesn't matter — iOS ignores Android `priority`). Acceptable duplication.

##### 1.4 `cancel()` invariant on every code path

`SchedulePredictionNotification.execute` calls `cancel()` unconditionally on line 33 **before** any guard. So:

- `prediction == null` → cancel, then return. ✅
- `notificationsEnabled == false` → cancel, then return. ✅
- `notifyAt` already in the past → cancel, then return (line 57). ✅
- Permission-denied revert path in `lib/app.dart:147-160` → calls `_save(...)` with `notificationsEnabled: false`, which triggers another listener emission that re-enters `execute()` and cancels again. ✅
- `PlatformException` in service `zonedSchedule` (line 184) → the cancel from line 33 still ran; only the new schedule was lost. This is the correct fail-soft behaviour. ✅

The invariant holds. The rewrite must preserve "cancel-first, then decide whether to schedule" — any reordering would reintroduce orphans on settings changes that disable notifications.

##### 1.5 `[1,7]` range — every encoding site

The range `[1, 7]` is encoded in **four** places. The rewrite to `[1, 14]` must update all four:

| File | Line | Form | Notes |
|------|------|------|-------|
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 35–40 | `assert(... >= 1 && ... <= 7, '...[1, 7]; got ...')` | debug-only; message string also encodes `[1, 7]` |
| `lib/features/settings/settings_screen.dart` | 425 | `for (int i = 0; i < 7; i++)` | builds the bottom-sheet picker; hard cap on UI |
| `lib/data/database/app_database.dart` | 93–94 | `IntColumn get notificationDaysBefore => integer().withDefault(const Constant(2))()` | **No CHECK constraint** — out-of-range values silently accepted from CSV import or migrations. The rewrite should consider adding a CHECK or a defensive clamp at the repository boundary. Schema is already at `schemaVersion = 6` (line 141), so any constraint addition needs migration v6→v7. |
| Tests using literal `notificationDaysBefore: <int>` | `test/app_notification_wiring_test.dart:121,150,158,187,217,247,296,339,371`; `lib/domain/entities/app_settings_data.dart:126` (default factory `2`) | Hardcoded values | All `2` and `1` — no test currently covers `> 7`. |

There is **no** range encoding in `domain/entities/app_settings_data.dart` itself (the field is a plain `int`). All validation is external. The rewrite should consider centralising bounds in either:
- a constant pair `kMinDaysBefore = 1, kMaxDaysBefore = 14` exported from a single place, OR
- a value-object with a `tryFrom(int)` factory that clamps/rejects.

The first is simpler (KISS); the second is more robust if values can arrive from CSV import or v6→v7 schema upgrade of pre-existing rows that contain garbage.

---

#### 2. Domain entity contract — `AppSettingsData` and the new time-of-day field

##### 2.1 Current shape

`lib/domain/entities/app_settings_data.dart:18-130`:
- 10 fields, all in the const constructor (lines 19–30); `darkMode`, `dropboxEmail`, `lastBackupAt`, `declaredCycleLength` nullable.
- Default factory at line 33: `const factory AppSettingsData.defaults() = _AppSettingsDataDefaults;` → `notificationDaysBefore: 2, notificationsEnabled: false` (lines 119–129).
- `copyWith` at line 60 has a known gotcha already documented (line 82): `declaredCycleLength` is excluded; the rewrite must extend `copyWith` to handle the new fields without falling into the same trap.
- `==` and `hashCode` (lines 89–116) enumerate every field — adding new fields requires adding them here too. Riverpod relies on `==` for downstream rebuilds.
- The class is a **plain immutable record**, no Flutter import, no derived state.

##### 2.2 Time-of-day shape — single field vs two fields

Constraint: domain layer must not import Flutter (CLAUDE.md §4). `flutter/material.dart::TimeOfDay` is therefore not usable in `lib/domain/`.

Three options, in order of decreasing preference for this codebase's style:

**Option A — two ints in the entity, no value class.** Add `final int notificationHour;  // 0–23` and `final int notificationMinute;  // 0–59`. Simplest; matches the existing flat-record style of `AppSettingsData`. The downside (loose coupling between the two ints — you can construct `(25, 90)`) is mitigated by a single-source range constant and an `assert` in the use case mirroring the existing `notificationDaysBefore` assert.

**Option B — a small immutable `NotificationTimeOfDay` value class in `lib/domain/entities/`.** Holds two ints with constructor validation, `==`, `hashCode`, `copyWith`. More plumbing (~40 lines) for marginal gain when there is exactly one use site (the notification scheduler). Justified only if a second consumer appears (none planned).

**Option C — minutes-since-midnight `int` (0–1439).** Compact; trivially comparable. Loses readability at every call site (`time / 60` and `time % 60` everywhere). Not recommended.

**Recommendation**: Option A. Two `int` fields, identical pattern to `notificationDaysBefore`. Range validation in the use case via `assert`. Add a `kMinNotificationHour=0, kMaxNotificationHour=23` constant pair if shared across UI picker + use case.

##### 2.3 Construction sites that must be updated

When new fields are added, every full-positional construction must be touched. Currently:
- `lib/features/settings/settings_screen.dart:374-382` — full-constructor call inside theme picker (because `copyWith` cannot set `darkMode` to null). Must add `notificationHour`, `notificationMinute`.
- `lib/data/repositories/drift_app_settings_repository.dart:32-39` — entity construction from DB row (read path).
- `lib/data/repositories/drift_app_settings_repository.dart:46-54` (and surrounding `_toCompanion`) — write path. The exclusion list documented in `app_settings_data.dart:82-86` must be reviewed: should the new fields be excluded from `_toCompanion` like `declaredCycleLength`, or written every save? Recommendation: written every save (they have no dedicated path like `saveDeclaredCycleLength`).
- `lib/domain/entities/app_settings_data.dart:119-129` — `_AppSettingsDataDefaults`. Recommended defaults: `notificationHour: 9, notificationMinute: 0` to preserve current behaviour for users upgrading.

Tests that build `AppSettingsData` literally must also be updated; grep for `AppSettingsData(` and `AppSettingsData.defaults()` finds them all. The literal-`2` audit done in §1.5 is the same set.

---

#### 3. Concrete service impl — `FlutterNotificationService`

##### 3.1 Initialisation and timezone resolution

`lib/data/services/notification_service.dart:50-84`:

- Calls `tz.initializeTimeZones()` then `FlutterTimezone.getLocalTimezone()` and sets `tz.local`. Falls back to `tz.UTC` on `Exception` (line 55–58). This means: if `flutter_timezone` plugin returns an unknown IANA name, **all subsequent scheduling lands in UTC**. With user-chosen time-of-day this becomes a serious silent bug — picking "08:00" in Italy could fire at 10:00 local. There is no telemetry to detect it (project is no-telemetry — §3 of CLAUDE.md). The rewrite should consider:
  - widening the `catch` to log a local-only warning the user can see in a diagnostic screen, OR
  - re-attempting on each `schedulePredictionNotification` call rather than caching the result of `initialize()`.
- iOS init requests alert/badge/sound permissions in `initialize()` (line 63–67). This is the only iOS permission flow; `requestPermission()` returns `true` on iOS unconditionally (line 197–208). That's correct for now but means iOS users who deny in the system prompt will silently lose notifications without any UI feedback. Pre-existing limitation, not introduced by this rewrite.

##### 3.2 `tz.TZDateTime` × DST behaviour

`lib/data/services/notification_service.dart:107-108`:
```dart
final local = tz.TZDateTime.from(notifyAt, tz.local);
return tz.TZDateTime(tz.local, local.year, local.month, local.day, 9);
```

DST cases for Italy (Europe/Rome) and globally:

- **Spring-forward, hour-skipped** (e.g., 2026-03-29, 02:00→03:00 in Italy). If user picks **02:30**, `tz.TZDateTime(tz.local, 2026, 3, 29, 2, 30)` falls in the gap. The `timezone` package's documented behaviour is to normalise to a valid instant (typically by shifting forward 1 hour to 03:30). Result: notification fires 1 hour later than the user picked, on that one day per year. Not a defect to fix, but **a required regression test** to lock behaviour. The user should be informed in the picker copy if they choose a DST-sensitive hour, or — simpler — restrict the picker to 5- or 15-minute increments and accept the once-a-year shift.

- **Fall-back, hour-doubled** (e.g., 2026-10-25, 03:00→02:00 in Italy). If user picks **02:30**, that local time exists twice. `timezone` package picks the first occurrence. The notification fires at the earlier of the two. **Required regression test**.

- 09:00 (current) is unambiguously after the DST switch on both sides → no ambiguity. The existing test at `test/data/services/notification_service_test.dart:130-152` covers this for 09:00 only. The rewrite must add at minimum:
  - DST spring-forward + user-picked time inside the gap (02:30 on `2026-03-29`)
  - DST fall-back + user-picked time inside the doubled hour (02:30 on `2026-10-25`)

##### 3.3 `FakeNotificationService` mirroring rule — **CONTRACT GAP**

`test/helpers/fake_notification_service.dart:60-70`:

```dart
final nowTime = _now();
final nowDay = DateTime(nowTime.year, nowTime.month, nowTime.day);
final sameDay = notifyDay == nowDay;
final pastNine = nowTime.hour >= 9;          // ← hardcoded 9
if (sameDay && pastNine) {
  shown.add(...);
} else {
  scheduled.add(...);
}
```

The fake hardcodes `>= 9` as the cold-start cut-off. When the production service starts using a per-user `notificationHour`, the fake's routing decision will diverge from production for any user-picked time other than 09:00. Symptoms in tests: a fixture with `nowOverride: DateTime(…, 8, 0)` and user-picked time `07:00` would route to `scheduled` in the fake (because `nowTime.hour < 9`) but to `shown` in the real service (because `now > scheduledDate`). Today no such test exists, so it passes — but the rewrite **will** add tests at non-9 AM times, and they will fail spuriously unless the fake is updated.

**Required**: the fake's `schedulePredictionNotification` must take time-of-day into account. Two ways:
- Pass `notifyAt` as a full `DateTime` with hour/minute already set (move time-of-day computation into the use case), and the fake compares `nowTime` to `notifyAt` directly. Simpler.
- Keep the use case date-only and add a separate parameter, or read the time-of-day from the settings via a passed-in `AppSettingsData`. More invasive.

The first option is recommended and aligns with §1.1: shift the wall-clock decision from the service to the use case so the use case emits a fully-resolved `DateTime` to the service. The service then loses the `, 9)` literal entirely and just calls `tz.TZDateTime.from(notifyAt, tz.local)` once. This is also a clean answer to "where does the time-of-day go" — it goes where `notificationDaysBefore` already lives (the use case), keeping the service dumb.

##### 3.4 `AndroidScheduleMode.exactAllowWhileIdle` — appropriate at nighttime?

`lib/data/services/notification_service.dart:178`. The mode survives Doze and battery-saver, which is exactly what we want for a 1-shot reminder. With nighttime hours selected (say 03:00 AM):
- `exactAllowWhileIdle` still fires (that's its purpose).
- `SCHEDULE_EXACT_ALARM` permission may be revoked by user — already handled via the swallowed `PlatformException` at line 184.
- iOS Focus / Do Not Disturb modes will defer the banner regardless; sound/haptic are also suppressed unless `interruptionLevel: timeSensitive` entitlement is requested. Currently no entitlement is requested → at nighttime the user may simply not see the notification until DND lifts. **Document this; do not silently change interruption level** — the project's principles forbid bypassing user OS preferences.

##### 3.5 `getPendingNotifications()` — testability for verification

There is **no** exposed read-back API on the domain interface (`lib/domain/services/notification_service.dart:22-50`). The plugin offers `pendingNotificationRequests()`, but the service doesn't surface it. For the rewrite, this is acceptable — there is one stable ID (`kPredictionNotificationId = 1001`) and tests for the service rely on platform-channel-free pure helpers (`computeScheduledTz`, `shouldShowImmediately`). Adding a `Future<List<PendingNotification>> getPending()` for tests is **not** required and would force a domain DTO for what is already a single-shot channel. Skip.

##### 3.6 Permission revoked → revert path

`lib/app.dart:147-160` is the listener that watches `settingsNotifierProvider`. When the user toggles `notificationsEnabled: false → true` and the OS denies, the code writes `notificationsEnabled: false` back (line 156), which triggers another listener emission. The cancel-first invariant from §1.4 still holds because the use case re-runs with `notificationsEnabled: false` and unconditionally cancels. ✅

The double-`PlatformException` swallow (`lib/app.dart:125,180` AND service line 184) is dead code in the app.dart layer once the service catch returns void cleanly — the service never re-throws. **Tech debt** (see §7); not a defect.

---

#### 4. Platform constraints

##### 4.1 Android

Current state in `android/app/src/main/AndroidManifest.xml`:
- Line 2: `POST_NOTIFICATIONS` — runtime permission on Android 13+. Already wired via `requestNotificationsPermission()` at line 207.
- Line 3: `RECEIVE_BOOT_COMPLETED` — required for the boot receiver at lines 55–62 to re-register pending alarms after reboot. Survives the rewrite.
- Line 4: `SCHEDULE_EXACT_ALARM` — Android 12 (API 31) added user-revocable runtime guard. Already handled via `PlatformException` swallow.
- Lines 54-62: `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` — these are flutter_local_notifications plugin receivers. Boot recovery is wired correctly.

`android/app/build.gradle.kts:28`: `minSdk = flutter.minSdkVersion` — at the time of writing, Flutter's default `minSdkVersion` is **24**. Therefore `USE_EXACT_ALARM` (requires API 33+) **cannot be used as a substitute** for `SCHEDULE_EXACT_ALARM`. The current setup is correct.

**Verdict for the rewrite**: no Android manifest changes required for arbitrary user-chosen times. `SCHEDULE_EXACT_ALARM` covers any wall-clock time; `RECEIVE_BOOT_COMPLETED` covers reboot recovery; `POST_NOTIFICATIONS` covers Android 13+. The rewrite should NOT add `USE_EXACT_ALARM` while minSdk < 33.

##### 4.2 iOS

`ios/Runner/Info.plist:63-64`:
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>Métra uses notifications to remind you when your predicted cycle window is approaching.</string>
```

The string content is fine (Italian translation TBD). Two notes:
- The key `NSUserNotificationsUsageDescription` is the legacy macOS key (note the plural). The modern iOS notification permission flow uses `UNUserNotificationCenter` and does **not** require a usage-description key in `Info.plist`. flutter_local_notifications handles permission via `requestAlertPermission` etc. in `DarwinInitializationSettings`. The string in the plist is therefore unused at runtime. Cosmetic; not blocking the rewrite. Verify against current Apple docs if unsure.
- Time-sensitive interruption for nighttime delivery requires the **`com.apple.developer.usernotifications.time-sensitive`** entitlement and explicit `interruptionLevel: .timeSensitive` on the notification content. We do **not** request this currently; nighttime alarms will be silenced by Focus/DND. Document, do not change without product approval (see CLAUDE.md "respect the adult user").

**Verdict for the rewrite**: no Info.plist changes required for arbitrary user-chosen times. Nighttime delivery quality on iOS is OS-mediated and intentionally not bypassed.

##### 4.3 DST gotcha consolidated

User picks 02:30 on Italy spring-forward day (2026-03-29 02:00→03:00). The hour 02:30 doesn't exist locally. Per §3.2: `timezone` package shifts forward; notification fires at 03:30 that day. Once a year, +1h. The rewrite must add tests for both spring-forward and fall-back; product copy should NOT mention DST (KISS — the once-a-year shift is acceptable for a non-medical reminder).

---

#### 5. What the rewrite must preserve, can reshape, and is broken

##### Preserve (do not change)

1. `kPredictionNotificationId = 1001` — orphan-risk guard.
2. `cancel()` unconditional first call in the use case — see §1.4.
3. `shouldShowImmediately(...)` predicate — already time-of-day-agnostic.
4. `computeScheduledTz(...)` UTC→local conversion via `tz.TZDateTime.from(notifyAt, tz.local)` (the BUG-004 fix).
5. `AndroidScheduleMode.exactAllowWhileIdle` — correct for nighttime hours given current minSdk.
6. `PlatformException` swallow at the service layer — fail-soft.
7. The use-case-decides-day / service-decides-time split, OR cleanly invert it (§3.3 recommendation: move the time decision into the use case so `notifyAt` is a fully-resolved `DateTime`).

##### Can reshape

1. The `[1, 7]` range → `[1, 14]` everywhere (§1.5).
2. The `09:00` literal → `notificationHour, notificationMinute` (§1.2).
3. `AppSettingsData` schema → add two int fields (§2.2 Option A).
4. The `_AppSettingsDataDefaults` → set defaults at `9, 0` to preserve upgrade behaviour (§2.3).
5. Drift schema v6 → v7 with two new columns and an optional CHECK constraint on `notificationDaysBefore` (§1.5).
6. `FakeNotificationService` mirroring rule → time-aware (§3.3).
7. Domain interface dartdoc on `schedulePredictionNotification` → drop "09:00 local time" (§1.2).

##### Broken / latent defects

The user wrote "the issue is not fixed yet". Going through the full pipeline I find **no** residual scheduling defect that survived BUG-001..005. The most plausible read of the user's framing is: the **rewrite scope itself** is the issue (configurable time/days). However, three latent issues will silently break the rewrite if not surfaced now:

1. **`FakeNotificationService` hardcoded `>= 9`** (`test/helpers/fake_notification_service.dart:63`). High severity for the rewrite. Medium severity today (no test currently passes through it at non-9 AM, but new tests will).
2. **Drift column has no CHECK constraint** on `notificationDaysBefore` (`lib/data/database/app_database.dart:93-94`). CSV import or a malformed v6 row could land an out-of-range value; the `assert` in the use case is debug-only. Medium severity; pre-existing.
3. **`tz.UTC` silent fallback** if `FlutterTimezone.getLocalTimezone()` fails (`lib/data/services/notification_service.dart:55-58`). Today this only shifts 09:00 by the local UTC offset — visible to the user. With user-chosen times the fallback becomes harder to detect because users won't know what "right" is. Low severity (no known failures); high impact when it does fire.

---

### Affected files

- `lib/domain/services/notification_service.dart` — interface dartdoc references "09:00 local time" (line 30); update text; no signature change required if the use case carries the resolved time.
- `lib/domain/use_cases/schedule_prediction_notification.dart` — assert range (35–40), `notifyAt` computation (41–42); recommended: extend to compose `(date) + notificationHour:notificationMinute` into a full `DateTime` before forwarding.
- `lib/domain/entities/app_settings_data.dart` — add `notificationHour, notificationMinute`; update constructor, `copyWith`, `==`, `hashCode`, defaults.
- `lib/data/services/notification_service.dart` — only the literal `9` on line 108 changes; if the use case now passes a fully-resolved `DateTime`, this file simplifies (no per-day rewrap to 09:00).
- `lib/data/database/app_database.dart` — schema v6→v7: two new columns; optional CHECK on `notificationDaysBefore`.
- `lib/data/database/app_database.g.dart` — Drift codegen; regenerated, not hand-edited.
- `lib/data/repositories/drift_app_settings_repository.dart:32-39, 46-54` — read/write path for the two new fields; decide `_toCompanion` inclusion.
- `lib/features/settings/settings_screen.dart:425` — change `i < 7` → `i < 14`; add a time picker bottom-sheet (or row) and l10n strings; decide UX for the picker (1-day picker is already a 7-tile sheet — 14 tiles will exceed the 9/16 viewport cap on small phones, see line 417 comment; the rewrite must verify).
- `lib/l10n/app_it.arb`, `lib/l10n/app_en.arb` — `settings_advance_value` already uses ICU plural and works for any `n` (no change). New keys: `settings_time_label`, `settings_time_picker_title` (or similar). `settings_advance_label` text may stay.
- `lib/app.dart:121, 175` — the listener body reads `notificationDaysBefore` to format the body text; the new time-of-day field does not feed the body text and so the listener body itself does not change.
- `android/app/src/main/AndroidManifest.xml` — **no change required** for the rewrite (§4.1).
- `ios/Runner/Info.plist` — **no change required** for the rewrite (§4.2). The `NSUserNotificationsUsageDescription` key is unused but cosmetic.
- `test/helpers/fake_notification_service.dart` — must drop `>= 9` and become time-aware (§3.3).
- `test/data/services/notification_service_test.dart` — extend `computeScheduledTz` and `shouldShowImmediately` tests to non-09:00 times; add the two DST-edge tests (§3.2).
- `test/domain/use_cases/schedule_prediction_notification_test.dart` — add tests for new range upper bound (14), and for time-of-day forwarding.
- `test/app_notification_wiring_test.dart` — update fixture defaults (`notificationDaysBefore: 2` already; add `notificationHour, notificationMinute`).

---

### Risks

1. **`FakeNotificationService` mirroring divergence (test infra)** — high. Without updating the fake's `>= 9` (`test/helpers/fake_notification_service.dart:63`) the new tests at non-9 AM times will pass spuriously or fail spuriously and nobody will know which.
2. **Drift schema migration** — medium. v6→v7 adds two columns. Pure additive migration is safe; risk is if the rewrite also adds a CHECK constraint (`notificationDaysBefore IN (1..14)`) on a table that may carry legacy out-of-range values from CSV import or buggy intermediate states. Recommend adding the CHECK only after a one-shot `UPDATE … SET notificationDaysBefore = 2 WHERE notificationDaysBefore < 1 OR notificationDaysBefore > 14` in the v6→v7 migration.
3. **DST edge cases at user-picked times** — medium. The 02:30-on-spring-forward case will silently fire at 03:30. A regression test must lock behaviour; product copy must not promise minute-accuracy on DST days.
4. **Silent UTC fallback** if `FlutterTimezone.getLocalTimezone()` fails — low probability, high impact at non-09:00 (§3.5 / §3.1). Logging a local diagnostic improves recoverability without violating no-telemetry.
5. **iOS Focus/DND silently suppressing nighttime notifications** — pre-existing, surfaces more visibly with user-chosen nighttime times. Document; do not add `time-sensitive` entitlement without product approval.
6. **Picker overflow for 14 days** — low/UI. The existing comment at `lib/features/settings/settings_screen.dart:417` notes 7 tiles already need `isScrollControlled: true`. 14 will push more content; verify on the smallest target device.
7. **Construction-site cascade when adding two new fields to `AppSettingsData`** — low/mechanical. Every full-positional construction (`settings_screen.dart:374-382`, repository `_toCompanion` etc.) must be updated; missing one = compile error (good).
8. **Localised body string `notification_prediction_body(days)` for `days = 1..14`** — low. The ICU plural rule already covers this; English and Italian both have `=1` / `other` only. Verify Italian copy still reads naturally for `n in {11, 12, 13, 14}`.

---

### Tech debt

The following items are not in the rewrite scope but the rewrite passes through them; clean while you're there only if the diff stays small.

1. **Domain interface dartdoc says "09:00 local time"** (`lib/domain/services/notification_service.dart:30`) — must be updated regardless; trivial.
2. **Double `PlatformException` swallow** (`lib/app.dart:125,180` AND `lib/data/services/notification_service.dart:184`). Service-level catch returns void cleanly; the app-level catches are dead. Pick one layer (service is the right one — closer to the source) and delete the other two.
3. **`AppSettingsData.copyWith` excludes `declaredCycleLength`** with an explanation comment (`lib/domain/entities/app_settings_data.dart:82-86`). This is a pattern that's easy to repeat by accident with the new fields; a unit test asserting `defaults().copyWith(notificationHour: 7).notificationHour == 7` would lock the new fields in.
4. **No CHECK constraint on `notificationDaysBefore`** at the DB layer (`lib/data/database/app_database.dart:93-94`). Add via a defensive clamp in `DriftAppSettingsRepository._toCompanion` if a v7 CHECK is too risky.
5. **`tz.UTC` silent fallback** at `lib/data/services/notification_service.dart:55-58`. Add a local-only diagnostic log line (no telemetry); leaves a trail when a user reports a wrong-time notification.
6. **The `prev is AsyncData<...>` guard pattern** in `lib/app.dart:147` is the only example of "a cold-start AsyncLoading→AsyncData transition is not a user action" — the rewrite touches the same listener and must preserve the guard verbatim. This is BUG-002's territory; do not regress.
7. **Tests with literal `notificationDaysBefore: 2`** (`test/app_notification_wiring_test.dart:121,150,158,187,217,247,296,339,371`). Any time the field count grows on `AppSettingsData`, all of these constructor calls compile-error. Consider a `_buildTestSettings({...})` helper. Out of scope for this rewrite if the diff is already large; flag for next sprint.
