# Module: Notifications
**Path**: `lib/data/services/notification_service.dart`, `lib/domain/use_cases/schedule_prediction_notification.dart`, `lib/app.dart`, `lib/providers/use_case_providers.dart`
**Agent**: bug-hunter

---

## Issue #31 — iOS permission-denied on first launch does not revert `notificationsEnabled` to false

### Root cause

Both `requestPermission()` and `hasNotificationPermission()` in `FlutterNotificationService` resolve the platform plugin via `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()`. When this returns `null` (which it always does on iOS), both methods short-circuit with `return true`, unconditionally reporting that permission is granted regardless of the OS reality.

`requestPermission()` (`lib/data/services/notification_service.dart:223–234`):

```dart
final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>();
if (androidPlugin == null) return true;   // iOS always hits this branch
return await androidPlugin.requestNotificationsPermission() ?? true;
```

`hasNotificationPermission()` (`lib/data/services/notification_service.dart:237–247`): identical structure — `androidPlugin == null` → `return true`.

These two methods are the only permission signals used by two separate code paths in `app.dart`:

1. **Settings listener** (lines 204–217): calls `requestPermission()` when the user flips the toggle on. On iOS the call returns `true` (grant reported) without ever showing the OS dialog or checking OS reality. The OS dialog is never triggered; the flag is never reverted when the user denies the system prompt.

2. **Cold-start revert** (`_verifyNotificationPermissionOnColdStart()`, lines 91–105): calls `hasNotificationPermission()`. On iOS returns `true` regardless of OS grant state. A user who revoked Notifications in iOS Settings will see `notificationsEnabled: true` in the DB persist forever — the revert branch (`if (!granted)`) never fires.

The root trigger is that `DarwinInitializationSettings(requestAlertPermission: true, requestSoundPermission: true, requestBadgePermission: true)` in `FlutterNotificationService._init()` auto-requests iOS permission at `initialize()` time. This makes the app trigger the iOS system dialog on cold-start rather than on the user's explicit toggle — contrary to FR-07 and the "no nag" voice — while the explicit-toggle path (`requestPermission()`) silently becomes a no-op on iOS.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/notification_service.dart` | 67–78 (`DarwinInitializationSettings`) | Auto-request on init — wrong trigger point |
| `lib/data/services/notification_service.dart` | 223–234 (`requestPermission`) | iOS blind spot — always returns true |
| `lib/data/services/notification_service.dart` | 237–247 (`hasNotificationPermission`) | iOS blind spot — always returns true |
| `lib/app.dart` | 91–105 (`_verifyNotificationPermissionOnColdStart`) | Consumes broken `hasNotificationPermission` |
| `lib/app.dart` | 204–217 (settings listener permission block) | Consumes broken `requestPermission` |
| `test/app_notification_wiring_test.dart` | — | No iOS permission-denied scenario tested |

### Fix sketch

1. Remove `requestAlertPermission: true`, `requestSoundPermission: true`, `requestBadgePermission: true` from `DarwinInitializationSettings` so `initialize()` no longer auto-requests the iOS system dialog.

2. In `requestPermission()`, after the Android branch, add an iOS branch:
   ```dart
   final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
       IOSFlutterLocalNotificationsPlugin>();
   if (iosPlugin != null) {
     return await iosPlugin.requestPermissions(
       alert: true, badge: true, sound: true,
     ) ?? false;
   }
   return false; // unknown platform — fail safe
   ```

3. In `hasNotificationPermission()`, add an iOS branch using `checkPermissions()`:
   ```dart
   final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
       IOSFlutterLocalNotificationsPlugin>();
   if (iosPlugin != null) {
     final perms = await iosPlugin.checkPermissions();
     return perms?.isEnabled ?? false;
   }
   return false;
   ```

4. Add a widget test in `test/app_notification_wiring_test.dart`: FakeNotificationService returns `false` from `requestPermission()`, user toggles notifications on → expect `save()` called with `notificationsEnabled: false`.

---

## Issue #32 — `PlatformException` from `zonedSchedule` swallowed silently

### Root cause

`FlutterNotificationService.schedulePredictionNotification()` catches `PlatformException` at lines 210–214:

```dart
} on PlatformException catch (e) {
  debugPrint(
    'FlutterNotificationService: zonedSchedule failed (${e.code}): ${e.message}',
  );
}
```

The exception is logged to the debug console but the method returns normally (no rethrow, no return value change). The call sites in `SchedulePredictionNotification.execute()` (`lib/domain/use_cases/schedule_prediction_notification.dart:61`) receive no signal that scheduling failed. The user's notification toggle remains `true` in the DB; no UI feedback is shown.

Additionally, `app.dart` has two dead `PlatformException` catches — lines 167–169 (prediction listener) and lines 247–249 (settings listener) — that can never fire because `FlutterNotificationService` already swallows the exception before it propagates. These dead catches create the false impression that the call site handles failures when it does not.

The primary scenario is Android: `SCHEDULE_EXACT_ALARM` permission revoked by the user after grant. `zonedSchedule()` throws `PlatformException(error, Cannot schedule exact alarm, ...)`. The user sees no indication that their next cycle notification is silently lost.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/notification_service.dart` | 210–214 | Swallows PlatformException, returns void |
| `lib/app.dart` | 167–169 | Dead catch — never reached |
| `lib/app.dart` | 247–249 | Dead catch — never reached |
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 61 | Call site receives no failure signal |
| `test/data/services/notification_service_test.dart` | BUG-006 group | Tests that exception is logged, not surfaced — documents current broken behavior |

### Fix sketch

Decision required: the fix strategy depends on desired UX severity.

**Option A — propagate as return value** (recommended for "no nag" voice):
Change `schedulePredictionNotification()` signature to `Future<bool>` (returns `false` on `PlatformException`). `SchedulePredictionNotification.execute()` propagates the bool. The settings listener in `app.dart` receives the bool and shows a `SnackBar` explaining that scheduling failed (without reverting the toggle — the user's intent is preserved, and they can retry later).

**Option B — rethrow** (simpler, breaks existing callers):
Rethrow the `PlatformException` from the service. Remove the dead catches in `app.dart` and replace them with substantive handlers that surface a SnackBar.

Either way, remove the two dead `PlatformException` catches from `app.dart:167-169` and `247-249` and replace with real handlers or delete them if the service now surfaces failure another way.

Update `test/data/services/notification_service_test.dart` BUG-006 group to assert the new propagation contract (not just `debugPrint`).

---

## Issue #33 — Notification cancel-then-reschedule has no atomicity test — old alarm may fire mid-rebuild

### Root cause

`SchedulePredictionNotification.execute()` at `lib/domain/use_cases/schedule_prediction_notification.dart:36`:

```dart
await _notifService.cancelPredictionNotifications();
```

This unconditional pre-cancel fires before every scheduling path, including the normal "reschedule because prediction changed" path. Between the `cancel` completing and the new `zonedSchedule` completing, there is a window where no notification is registered. If the device fires a previously-scheduled alarm during this window, the system has already been told to cancel — the alarm fires but the plugin discards it. More critically: if `zonedSchedule` fails (Issue #32) after the cancel, the notification is permanently lost with no registered future alarm.

The atomicity risk is an implementation artifact, not a fundamental requirement. `flutter_local_notifications` `zonedSchedule()` called with the same stable notification ID (`kPredictionNotificationId = 1001`) replaces the existing notification atomically at the plugin level without requiring an explicit prior cancel. The cancel-first pattern provides no correctness benefit on the replace path and introduces the gap for free.

The existing EC-15 test in `test/domain/use_cases/schedule_prediction_notification_test.dart` ("two execute() calls → cancelCount==2, scheduled length==1") asserts idempotency of the end state but does not test the intermediate state (i.e., "no notification registered between cancel and reschedule"). The absence of this test means the gap is not contractually guarded.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 36 | Unconditional pre-cancel |
| `lib/domain/use_cases/schedule_prediction_notification.dart` | 47–75 | Scheduling paths — cancel not needed before line 61 |
| `test/domain/use_cases/schedule_prediction_notification_test.dart` | EC-15 group | Tests end-state idempotency but not intermediate state |
| `test/helpers/fake_notification_service.dart` | `cancelCount` field | Available for atomicity assertions |

### Fix sketch

1. Remove the unconditional `await _notifService.cancelPredictionNotifications()` at line 36.

2. On the two early-return paths where no notification should remain, add explicit cancel:
   - `prediction == null` path (line ~47): cancel after the null check.
   - `settings.notificationsEnabled == false` path (line ~53): cancel after the disabled check.

3. On the normal scheduling path (line 61 forward), call `zonedSchedule()` directly without prior cancel. The stable ID 1001 provides replace semantics.

4. Add a test to `schedule_prediction_notification_test.dart` asserting that when `execute()` is called with a valid prediction, `cancelCount == 0` (no spurious cancel) and `scheduled.length == 1`. This makes the atomicity contract explicit and detectable.

5. Separately, add a test for the "cancel + schedule fails" scenario: if `zonedSchedule` throws, verify that a notification cancel was not issued before the failure (i.e., that the original alarm is still registered). This test is only possible after Issue #32 is fixed (the failure must propagate to be observable).

---

## Issue #35 — Notification alarm wall-clock instant is fixed at schedule time — timezone change not reflected at fire time

### Root cause

`FlutterNotificationService.schedulePredictionNotification()` at `lib/data/services/notification_service.dart:206–207`:

```dart
uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
```

`absoluteTime` tells the iOS notification system to fire the alarm at the exact UTC instant computed at schedule time. When the device moves to a different timezone, the alarm still fires at the original UTC instant — which now corresponds to a different local time. A user who schedules a 09:00 notification before flying from Rome (UTC+2) to Tokyo (UTC+9) will receive the notification at 16:00 Tokyo local time instead of 09:00.

`UILocalNotificationDateInterpretation.wallClockTime` would cause iOS to fire the alarm at the same wall-clock time (09:00) in whatever timezone the device is in at fire time, which is the correct behavior for a "daily reminder at 09:00."

On Android the behavior is different: `AlarmManager` in RTC mode fires at an absolute UTC timestamp. Timezone changes do not recompute pending alarms. The fix on Android requires listening for `Intent.ACTION_TIMEZONE_CHANGED` at the platform layer and triggering a Dart-side reschedule. This is substantially more complex than the iOS fix and has a different root mechanism.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/notification_service.dart` | 206–207 | `absoluteTime` — wrong interpretation for timezone resilience on iOS |
| `lib/data/services/notification_service.dart` | 193–209 (`schedulePredictionNotification`) | Full `zonedSchedule` call site |
| `android/app/src/main/kotlin/` | — | No `TIMEZONE_CHANGED` broadcast receiver exists |
| `test/data/services/notification_service_test.dart` | `computeScheduledTz` group | Tests correct tz computation at schedule time, not at fire time after device move |

### Fix sketch

**iOS (lower risk, self-contained):**

Change line 206–207:
```dart
// Before:
uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,

// After:
uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.wallClockTime,
```

Verify that `computeScheduledTz()` still passes its existing tests — the computation is unaffected; only the iOS scheduler interpretation changes.

**Android (higher risk, requires platform code):**

Add a Kotlin `BroadcastReceiver` in `android/app/src/main/kotlin/` listening for `Intent.ACTION_TIMEZONE_CHANGED`. On receipt, invoke a `MethodChannel` call to Dart. On the Dart side, add a `MethodChannel` handler in `main.dart` or `app.dart` that calls `ref.read(backupNotifierProvider.notifier)` — wait, wrong notifier. It should call `ref.read(schedulePredictionNotificationProvider.future)` and re-execute with current state from `ref.read(settingsNotifierProvider).valueOrNull` and `ref.read(cyclePredictionProvider).valueOrNull`.

This Android fix requires:
1. `AndroidManifest.xml` addition: `<receiver android:name=".TimezoneChangeReceiver">` with `<intent-filter><action android:name="android.intent.action.TIMEZONE_CHANGED"/></intent-filter>`
2. New Kotlin file `TimezoneChangeReceiver.kt`
3. New `MethodChannel` handler on the Dart side

The Android fix crosses two layers (native + Dart) and should be treated as a separate sub-task from the iOS fix.

---

## Risks

**R1 — iOS auto-request removal (Issue #31 fix) breaks first-launch UX.**
Removing `requestAlertPermission: true` from `DarwinInitializationSettings` means the iOS permission dialog will no longer appear on first cold-start. It will appear only when the user explicitly enables notifications in the Settings screen. This is the correct behavior per FR-07 and the "no nag" voice, but it requires verifying on a physical iOS device via TestFlight (no iOS simulator locally). If the first-launch toggle-to-enable path in `IOSFlutterLocalNotificationsPlugin.requestPermissions()` is called before `initialize()` completes, behavior is undefined. Confirm initialization order.

**R2 — Removing unconditional pre-cancel (Issue #33 fix) depends on stable-ID replace semantics being guaranteed.**
The fix assumes `zonedSchedule(id, ...)` with the same ID atomically replaces any existing notification. This is documented behavior in `flutter_local_notifications` but should be verified against v17.2.4 changelog before the unconditional cancel is removed. A regression here would result in duplicate notifications silently accumulating.

**R3 — `wallClockTime` on iOS (Issue #35 fix) changes fire semantics for all existing scheduled alarms.**
Alarms scheduled with `absoluteTime` will be replaced by alarms scheduled with `wallClockTime` after the next `zonedSchedule()` call. For users who have not changed timezone, the fire time is identical. For users mid-timezone-change the transition behavior depends on iOS scheduling internals. This is low-risk in practice but should be noted in the commit message.

**R4 — Android `TIMEZONE_CHANGED` receiver (Issue #35 partial fix) adds platform code with no local test path.**
Because development is on Fedora Linux with no iOS simulator, the Android receiver can be tested on the Android emulator. However the interaction between the Kotlin receiver → MethodChannel → Dart reschedule is an integration that has no existing test pattern in this codebase. Plan for a manual smoke test on a physical Android device with timezone changed mid-cycle.

**R5 — Issue #32 fix (surfacing PlatformException) changes the public contract of `NotificationService`.**
If `schedulePredictionNotification()` becomes `Future<bool>`, all mock and fake implementations must be updated. `FakeNotificationService` and any test doubles must be updated in the same commit. The `SchedulePredictionNotification` use case return type may also need to change if callers need the signal.

---

## Tech debt

**TD1 — `notificationServiceProvider` is a plain `Provider`, not `FutureProvider`.**
`FlutterNotificationService` calls `initialize()` in its constructor via `_init()`. This is a fire-and-forget async call — the plugin may not be initialized when the first scheduling call arrives, leading to undefined behavior. `notificationServiceProvider` should become a `FutureProvider` (or the initialization should be awaited before the provider is considered ready). The current `schedulePredictionNotificationProvider` already uses `FutureProvider` to await initialization, which partially mitigates this, but `requestPermission()` and `hasNotificationPermission()` are called directly on `notificationServiceProvider` without waiting for initialization.

**TD2 — iOS `IOSFlutterLocalNotificationsPlugin` vs `DarwinFlutterLocalNotificationsPlugin` naming.**
In `flutter_local_notifications` v17+, the iOS plugin implementation class is `IOSFlutterLocalNotificationsPlugin`. A future major version may rename it to `DarwinFlutterLocalNotificationsPlugin` (to unify iOS and macOS). When upgrading past v18, verify the class name in the pub cache at `$PUB_CACHE/hosted/pub.dev/flutter_local_notifications-*/lib/src/platform_specifics/darwin/`.

**TD3 — Dead `PlatformException` catches in `app.dart` obscure the real error boundary.**
Lines 167–169 and 247–249 are unreachable. Even after Issue #32 is fixed, if the chosen fix is "return bool" rather than "rethrow," these catches remain dead. Either route the failure signal through return values and remove the catches, or rethrow and make the catches substantive. Dead catches are a maintenance hazard: future developers will assume they handle something.

**TD4 — No test for the iOS `DarwinInitializationSettings` auto-request path.**
The existing `FakeNotificationService` does not simulate the `initialize()`-triggers-permission-dialog behavior. A test that verifies "no permission dialog on cold-start when `notificationsEnabled: false`" does not exist. This test would have caught Issue #31 before it reached production.

**TD5 — `computeScheduledTz()` is tested for correctness at schedule time but not for timezone-shift resilience.**
The existing tests in `notification_service_test.dart` fix `tz.local` to a static timezone. There is no test that calls `computeScheduledTz()` with one timezone, then simulates the device moving to another timezone, and verifies the rescheduled time is correct. Adding such a test would provide a regression guard for Issue #35 at the unit level.
