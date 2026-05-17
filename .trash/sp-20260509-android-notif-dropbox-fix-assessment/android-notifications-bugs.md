# Android Notifications — Bug Assessment
**Date:** 2026-05-09  
**Scope:** Notifications subsystem, Android-only failure ("notifications not working on Android; iOS fine")

---

## Findings

---

[HIGH] BUG-AN-01: `SCHEDULE_EXACT_ALARM` never granted on fresh Android 12+ install — scheduling silently fails
File: `lib/data/services/notification_service.dart:188–205`, `android/app/src/main/AndroidManifest.xml:4`
Category: missing-validation / logic-error
CWE: CWE-754 (Improper Check for Unusual or Exceptional Conditions)

**Evidence:**
```dart
// notification_service.dart:188–205
try {
  await _plugin.zonedSchedule(
    kPredictionNotificationId, title, body, scheduledDate, details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    ...
  );
} on PlatformException {
  // BUG-002: SCHEDULE_EXACT_ALARM was revoked by the user …
  // swallow so the caller receives a clean void return.
}
```
```xml
<!-- AndroidManifest.xml:4 -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

**Analysis:**

The comment on lines 30–35 of `notification_service.dart` states:
> "On Android 13+ (API 33+) a user-visible permission prompt is shown once; on earlier versions the permission is pre-granted."

Both halves are incorrect for `SCHEDULE_EXACT_ALARM` with `targetSdk = 36` (Flutter default, confirmed via `FlutterExtension.kt`):

- **API 31–32 with targetSdk ≥ 31:** `SCHEDULE_EXACT_ALARM` is **not** pre-granted. The user must manually enable it in Settings → Apps → Special app access → Alarms & reminders.
- **API 33+ with targetSdk ≥ 33:** Same; there is **no automatic OS permission prompt** for `SCHEDULE_EXACT_ALARM`. The app would need to call `requestExactAlarmsPermission()` (via `AndroidFlutterLocalNotificationsPlugin`) or open the Settings Intent.

The plugin correctly guards this: in `FlutterLocalNotificationsPlugin.java:759`, `checkCanScheduleExactAlarms()` calls `alarmManager.canScheduleExactAlarms()` and throws `ExactAlarmPermissionException` (mapped to `PlatformException("exact_alarms_not_permitted")`) when the permission is absent. The Dart catch block at line 201 swallows this exception with no user feedback, no log, no fallback.

**Result:** On every fresh Android 12+ (API 31+) install, `zonedSchedule()` throws immediately on the first scheduling attempt. The exception is silently discarded. The user enables notifications in the app, sees the toggle ON, but no notification ever fires. iOS is unaffected because it uses APNs/UNUserNotificationCenter — the `AlarmManager` and exact-alarm path are Android-only.

**Trigger:** Enable notifications in Métra settings on an Android 12+ device (fresh install, never visited Settings → Special app access). The `PlatformException` is swallowed. No notification is delivered.

**Impact:** 100% notification failure on Android 12+ (API 31+) for all users who never manually granted Alarms & reminders in Settings — which is every new user, since there is no UI guiding them there.

**iOS no-regression proof:** The catch block is in `schedulePredictionNotification()`, which on iOS never calls `zonedSchedule` via the Android code path. `AndroidScheduleMode` is an Android-only enum. The iOS path uses `DarwinNotificationDetails` exclusively.

---

[LOW] BUG-AN-02: `ScheduledNotificationBootReceiver` missing `com.htc.intent.action.QUICKBOOT_POWERON` action
File: `android/app/src/main/AndroidManifest.xml:55–62`
Category: missing-validation
CWE: N/A

**Evidence:**
App manifest boot receiver only lists: `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`.  
Plugin example (the canonical reference) adds: `com.htc.intent.action.QUICKBOOT_POWERON`.  
App manifest also adds `<category android:name="android.intent.category.DEFAULT"/>` — not present in plugin example.

**Analysis:** Missing HTC QUICKBOOT_POWERON prevents scheduled notification recovery after device reboot on HTC devices. The spurious `DEFAULT` category on the intent-filter is harmless but deviates from the plugin spec. HTC market share is negligible; severity is Low. The `DEFAULT` category does not break the receiver.

**Trigger:** Device reboot on an HTC device with QUICKBOOT_POWERON as the boot broadcast action.

---

[INFO] BUG-AN-03: Misleading doc comment on `SCHEDULE_EXACT_ALARM` behavior
File: `lib/data/services/notification_service.dart:30–35`

The comment states the permission is "pre-granted on earlier versions" and "a user-visible prompt is shown once" on Android 13+. Both claims are false (see BUG-AN-01). The comment should be rewritten as part of the fix.

---

[INFO] BUG-AN-04: Silent catch blocks produce no diagnostic output
Files: `lib/data/services/notification_service.dart:201–205`, `lib/app.dart:125–127`, `lib/app.dart:179–181`

Three `on PlatformException` catch blocks swallow exceptions with no `debugPrint` or logging. After BUG-AN-01 is fixed, these are still valid guards for post-grant revocation — but they should at minimum emit a `debugPrint` so future regressions are not invisible.

---

## SUMMARY: 2 findings (0 critical, 1 high, 0 medium, 1 low), 2 info
Highest-risk area: `lib/data/services/notification_service.dart` + `AndroidManifest.xml` interaction
Recommended next action: Fix BUG-AN-01 (exact-alarm permission path); update manifest boot receiver (BUG-AN-02); rewrite misleading comment (BUG-AN-03); add debugPrint to catch blocks (BUG-AN-04).

---

## Spec Inputs

### Root Cause Analysis (ranked by likelihood)

**1. PRIMARY (confirmed): `SCHEDULE_EXACT_ALARM` not granted + silent catch (BUG-AN-01)**
`targetSdk = 36` means the OS does not pre-grant `SCHEDULE_EXACT_ALARM`. The app never checks `canScheduleExactAlarms()` before calling `zonedSchedule()`, never calls `requestExactAlarmsPermission()`, and never directs the user to the Settings screen. The plugin throws `PlatformException("exact_alarms_not_permitted")` on the very first scheduling call. This exception is caught and discarded silently. Reproduced deterministically: on any fresh Android 12+ (API ≥ 31) device, `alarmManager.canScheduleExactAlarms()` returns `false` until the user manually grants in Settings → Alarms & reminders.

**2. NON-ISSUE (ruled out): `POST_NOTIFICATIONS` permission**
`notificationsEnabled` DB default is `false`. Onboarding writes it to `true`, triggering the `false → true` transition that calls `requestNotificationsPermission()` in `requestPermission()`. The BUG-002 guard is correct. POST_NOTIFICATIONS is properly handled.

**3. NON-ISSUE (ruled out): Desugaring**
`isCoreLibraryDesugaringEnabled = true` and `desugar_jdk_libs:2.1.4` are present in `android/app/build.gradle.kts`. No desugaring-related `NoClassDefFoundError` on `java.time.*` is possible.

**4. NON-ISSUE (ruled out): Notification channel**
Channel `metra_cycle` is created in `initialize()` with `Importance.high`. Channel ID matches the one passed to `zonedSchedule()` and `show()`. No mismatch.

**5. NON-ISSUE (ruled out): Timezone init**
`tz.initializeTimeZones()` runs in `initialize()` before any `zonedSchedule()` call. UTC fallback is in place if platform detection fails. The `computeScheduledTz()` fix uses `tz.TZDateTime.from()` correctly.

**6. NON-ISSUE (ruled out): Battery optimization / Doze**
`AndroidScheduleMode.exactAllowWhileIdle` already opts out of Doze. No `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is needed for this mode. OEM battery management could still kill the alarm on Xiaomi/Huawei, but this is an orthogonal user-education issue, not a code defect.

**7. NON-ISSUE (ruled out): Receivers missing**
Both `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` are declared in the manifest. The plugin's own lib-level manifest does not declare them (only permissions), so the app manifest must include them — which it does.

---

### Affected Components and Files

| File | Lines | Role |
|---|---|---|
| `lib/data/services/notification_service.dart` | 30–35 (misleading comment), 188–205 (silent catch) | Primary fix site |
| `android/app/src/main/AndroidManifest.xml` | 4 (`SCHEDULE_EXACT_ALARM`), 55–62 (boot receiver) | Permission declaration; receiver intent-filter |
| `lib/app.dart` | 125–127, 179–181 (two more silent PlatformException catches) | Secondary fix sites (add debugPrint) |
| `lib/domain/services/notification_service.dart` | 44–49 (`requestPermission()` docstring) | Docstring should mention exact-alarm check |

---

### Related Latent Bugs (fix in same change)

1. **Silent exact-alarm catch in `notification_service.dart:201–205`** — add `debugPrint` so the failure is visible during development/debugging. The guard itself is correct for post-grant revocation.
2. **Two silent `PlatformException` catches in `app.dart:125–127` and `179–181`** — same treatment: add `debugPrint`.
3. **Misleading doc comment `notification_service.dart:30–35`** — rewrite to accurately state that `SCHEDULE_EXACT_ALARM` requires an explicit user grant on API 31+ (no auto-prompt), and note the `USE_EXACT_ALARM` vs `SCHEDULE_EXACT_ALARM` policy trade-off.
4. **Missing HTC boot action in `ScheduledNotificationBootReceiver`** — add `com.htc.intent.action.QUICKBOOT_POWERON` to the intent-filter (copy from plugin example).

---

### Constraints the Fix Must Respect

**Must NOT regress iOS (currently working):**

- iOS never touches `AndroidFlutterLocalNotificationsPlugin`. `requestPermission()` already short-circuits with `if (androidPlugin == null) return true` — that guard must be preserved.
- Any new "check exact-alarm permission" call must be wrapped in `Platform.isAndroid` or use the `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()` null-guard pattern (same pattern already used in `requestPermission()`).
- `AndroidScheduleMode` and `AndroidNotificationDetails` are Android-only types — they are already guarded by their position inside `zonedSchedule()` / `show()` calls that iOS never reaches.
- `requestExactAlarmsPermission()` (if called) is also Android-only; it must be accessed exclusively via `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission()`.

**Fix-direction decision (product/policy choice — must be resolved before coding):**

The fix has three mutually exclusive approaches for exact-alarm scheduling:

| Option | Permission | Grant mechanism | Notes |
|---|---|---|---|
| A. `USE_EXACT_ALARM` | Pre-granted, no user action | None | Play Store policy restricts to alarm-clock/calendar/task apps; a cycle reminder may be acceptable, but approval is not guaranteed. Risk of rejection. |
| B. Keep `SCHEDULE_EXACT_ALARM` + guide user | Requires user grant | Direct user to Settings Intent at notification enable time | UX friction; most robust long-term. |
| C. Switch to `AndroidScheduleMode.inexactAllowWhileIdle` | None required | None | Notification fires within ~15 min of scheduled time; acceptable for a daily reminder. No permission friction. |

The spec phase must choose one option before implementation begins.

---

### Test Coverage Gaps

1. **No test for `canScheduleExactAlarms() = false` path.** The `FakeNotificationService` records calls but does not simulate a `PlatformException("exact_alarms_not_permitted")` throw. A unit test should be added where `schedulePredictionNotification()` throws `PlatformException` and the catch block behavior (log, no crash, no schedule) is asserted.

2. **No instrumented test on Android API 31+ emulator.** The entire exact-alarm path is invisible to the Dart-only test suite because `zonedSchedule()` is a platform channel call. The bug was undetectable without a real or emulated Android 12+ device.

3. **No test for `requestExactAlarmsPermission()` (whichever option is chosen).** If Option B is selected, a unit test should verify that the `false → true` notification toggle on Android calls the exact-alarm request flow in addition to `requestNotificationsPermission()`.
