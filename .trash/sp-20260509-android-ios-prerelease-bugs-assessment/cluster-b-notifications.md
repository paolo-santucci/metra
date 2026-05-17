# Cluster B — Android Notifications: Bug Hunter Assessment

**Scope:** commit `e0fe29b` (v0.1.0-rc14). Symptom: notifications work on the Android
emulator but do NOT fire on the tester's real phone.

---

## Diagnostic-First Protocol

The emulator vs. real-phone discriminant is consistent with **multiple independent causes**.
Run the following adb commands BEFORE applying any fix — the output matrix identifies the
actual cause on this specific device.

```bash
# 1. Is the alarm registered?
adb shell dumpsys alarm | grep -i metra

# 2. Is the app exempt from Doze battery restrictions?
adb shell dumpsys deviceidle whitelist | grep metra

# 3. Is POST_NOTIFICATIONS permission granted at OS level?
adb shell cmd appops get com.paolosantucci.metra POST_NOTIFICATIONS

# 4. Is the notification channel enabled and not silenced?
adb shell dumpsys notification | grep -A 10 metra_cycle

# 5. Is the app in a restricted standby bucket?
adb shell am get-standby-bucket com.paolosantucci.metra

# 6. Capture runtime logs around scheduling
adb logcat | grep -E "FlutterNotif|AlarmManager|metra_cycle|zonedSchedule"
```

Interpretation matrix:

| Diagnostic 1 output  | Diagnostic 2 output     | Cause                    |
|----------------------|-------------------------|--------------------------|
| No alarm entry       | App not in whitelist    | OEM/Doze battery block   |
| No alarm entry       | —                       | POST_NOTIFICATIONS denied (check #3) or channel muted (#4) |
| Alarm registered     | —                       | Doze fires alarm but delivery blocked by channel (#4) |
| Standby bucket=RARE  | —                       | Standby-bucket quota exhausted by double-schedule (#5) |

---

## Ranked Bug Findings

### [HIGH] BUG-B01: OEM Battery Optimization Blocks Inexact Alarms

**File:** `lib/data/services/notification_service.dart:190-207`  
**Category:** logic-error (platform interaction)  
**CWE:** CWE-778 (Insufficient Logging)

**Evidence:**
```dart
await _plugin.zonedSchedule(
  kPredictionNotificationId, title, body, scheduledDate, details,
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  ...
);
```

**Analysis:** `inexactAllowWhileIdle` maps to `AlarmManagerCompat.setAndAllowWhileIdle()`.
On stock AOSP this fires within Doze's ~15-min maintenance window. On Samsung One UI
(DeepSleep / Adaptive Battery), Xiaomi MIUI (battery saver autostart), Huawei EMUI
(Power Genius), and OnePlus OxygenOS, the OEM overrides Doze maintenance scheduling for
apps that are not whitelisted by the user. The alarm is silently dropped with no
PlatformException — the `debugPrint` path at line 203 is never reached.  
Emulators run AOSP without OEM layers; this is why the emulator succeeds and the real
phone does not.

**Trigger:** User installs on Samsung/Xiaomi/Huawei without granting "Unrestricted battery"
or disabling "Deep Sleep" for the app. Alarm is scheduled, no error thrown, notification
never fires.

**Impact:** Notification silently dropped on the majority of Android market devices. The
app has no mechanism to detect this or surface it to the user.

**Fix shape (conditional on diagnostic #2 showing app excluded from whitelist):**  
Add a one-time `requestIgnoreBatteryOptimizations` intent-flow, displayed on the
notification toggle activation or on a dedicated Settings row. Intent action:
`Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. Cannot be auto-granted; requires
explicit user action in system Settings. Add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
permission to `AndroidManifest.xml`. Gate the prompt so it fires at most once (persist
`hasShownBatteryPrompt` flag in SharedPreferences).

---

### [HIGH] BUG-B02: Double Cancel+Reschedule on Every Cold-Start Depletes Standby Quota

**File:** `lib/app.dart:104-183`  
**Category:** logic-error / concurrency  
**CWE:** CWE-400 (Uncontrolled Resource Consumption)

**Evidence:**
```dart
// Prediction listener (line 104) — no prev-AsyncData guard
ref.listen<AsyncValue<CyclePrediction?>>(cyclePredictionProvider, (_, next) async {
  // ...
  await scheduler.execute(...); // fires on cold-start AsyncLoading→AsyncData
});

// Settings listener (line 133) — no prev-AsyncData guard on the execute() call
ref.listen<AsyncValue<AppSettingsData>>(settingsNotifierProvider, (prev, next) async {
  // permission guard is only around requestPermission(), NOT around execute()
  await scheduler.execute(...); // also fires on cold-start
});
```

**Analysis:** Both listeners fire on the `AsyncLoading → AsyncData` transition at every
cold-start. `scheduler.execute()` calls `cancelPredictionNotifications()` unconditionally
before rescheduling. Two listeners × one cold-start = two full cancel+reschedule cycles,
each consuming one App Standby alarm slot. On Android 11+ the App Standby Bucket system
caps background alarm frequency for apps in the RARE or RESTRICTED bucket (~1/day limit).
If both cycles fire and the device moves the app to RESTRICTED (used less than once per
week), the second reschedule may exhaust the day's alarm quota — or the first schedule
is cancelled by the second before it fires.

**Trigger:** Cold-start on any Android 11+ device after the app is placed in RESTRICTED
standby bucket. Both listeners race; one cancel+reschedule pair happens, then a second
cancel+reschedule pair runs concurrently or immediately after. Alarm quota consumed;
notification does not fire.

**Impact:** Intermittent notification loss on lightly-used installs. Compounds with
BUG-B01 on OEM devices.

**Fix shape:** Add `prev is AsyncData` guard around `scheduler.execute()` in the settings
listener (mirrors the existing `requestPermission()` guard pattern at line 147). For the
prediction listener: gate on `prev != null && prev is AsyncData` before calling execute.
This eliminates the cold-start double-fire.

---

### [HIGH] BUG-B03: POST_NOTIFICATIONS Not Re-Checked on Cold-Start When Already Enabled

**File:** `lib/app.dart:147-161`, `lib/data/services/notification_service.dart:215-226`  
**Category:** missing-validation  
**CWE:** CWE-862 (Missing Authorization)

**Evidence:**
```dart
if (prev is AsyncData<AppSettingsData>) { // only runs on toggle transitions
  if (currentSettings.notificationsEnabled && !wasEnabled) {
    final granted = await ref.read(notificationServiceProvider).requestPermission();
```

**Analysis:** `requestPermission()` is only called on the `false → true` toggle
transition. On cold-start with `notificationsEnabled: true` in the DB, permission is never
checked. If the user revoked POST_NOTIFICATIONS via System Settings after the initial grant
(possible on Android 13+), the permission is silently absent. `NotificationManagerCompat
.notify()` silently drops the notification — no error, no PlatformException.  
Emulators prompt anew on each fresh install; real phones retain the revocation.

**Trigger:** User enables notifications, later revokes via system notification settings,
then cold-starts the app. `notificationsEnabled` remains true in DB; no permission check
fires; all scheduling proceeds without error; notification is never delivered.

**Impact:** Silent notification drop. User believes the feature is configured; nothing
appears.

**Fix shape (conditional on diagnostic #3 showing `POST_NOTIFICATIONS` = `ignored`):**  
Add a cold-start check: after `initialize()` completes and before the first `execute()`
call, read `notificationsEnabled` from settings; if true, call
`requestNotificationsPermission()` (returns immediately if already granted, shows dialog
if newly revoked). Alternatively surface a Settings tile that detects and shows OS
notification permission state with a deep-link to system notification settings
(`Settings.ACTION_APP_NOTIFICATION_SETTINGS`).

---

### [MEDIUM] BUG-B04: Notification Channel May Be Muted by User Without App Awareness

**File:** `lib/data/services/notification_service.dart:81-89`  
**Category:** missing-validation

**Evidence:**
```dart
const channel = AndroidNotificationChannel(
  _kChannelId, _kChannelName, importance: Importance.high,
);
await _plugin.resolvePlatformSpecificImplementation<...>()
    ?.createNotificationChannel(channel);
```

**Analysis:** `createNotificationChannel` is a no-op if the channel already exists.
Importance is set at creation time and cannot be downgraded by the app. However, the user
can silence or disable the channel via System Settings → App → Notifications. When
disabled, `zonedSchedule` succeeds (alarm is registered), the alarm fires at the correct
time, but `NotificationManagerCompat.notify()` silently drops delivery. No exception
thrown. Emulators: channel is fresh on every reinstall; real phones: channel state
persists.

**Trigger:** User opens System Notifications settings for Métra and toggles off the
"Mētra — Ciclo" channel, then re-enables notifications in app settings.

**Fix shape (conditional on diagnostic #4 showing channel disabled):**  
Add a channel-status check after `initialize()`: read
`NotificationManagerCompat.getNotificationChannel(_kChannelId)` and check `.importance !=
NotificationManager.IMPORTANCE_NONE`. If muted, surface a Settings deep-link.

---

### [LOW] BUG-B05: tz.local Race Window in Fire-and-Forget initialize()

**File:** `lib/app.dart:65-68`, `lib/data/services/notification_service.dart:53-65`  
**Category:** race-condition

**Evidence:**
```dart
ref.read(notificationServiceProvider).initialize().catchError((Object _) {});
// initState returns; build() runs immediately; listeners may fire before
// tz.setLocalLocation() completes the async gap
```

**Analysis:** `tz.initializeTimeZones()` is synchronous; `tz.setLocalLocation()` happens
after the first `await` in `initialize()`. The two `ref.listen` callbacks in `build()` can
fire before `tz.setLocalLocation()` completes, causing `computeScheduledTz` to use UTC as
`tz.local`. For Italian users (UTC+1/+2) this shifts the alarm earlier by 1-2 hours —
tolerable, not silent loss. Low-impact for EU timezone; higher risk for UTC−5 and beyond.

**Fix shape:** Await `initialize()` before registering listeners, or pass the timezone as
an explicit parameter instead of relying on `tz.local` global state.

---

### [LOW] BUG-B06: Spurious DEFAULT Category on ScheduledNotificationBootReceiver

**File:** `android/app/src/main/AndroidManifest.xml:54-61`  
**Category:** logic-error (manifest)

**Evidence:**
```xml
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        ...
        <category android:name="android.intent.category.DEFAULT"/>  <!-- NOT in plugin example -->
    </intent-filter>
</receiver>
```

**Analysis:** The plugin's own example manifest does not include this category. While
`BOOT_COMPLETED` intents are not category-filtered by the system dispatcher, the extraneous
category is an anomaly. Low severity — no known delivery impact on any tested Android
version.

---

## Spec Inputs

### Root Cause Analysis

| Rank | Hypothesis | Confidence | Discriminator |
|------|-----------|------------|---------------|
| 1 | OEM battery optimization blocks `setAndAllowWhileIdle` | HIGH | Diagnostic #2 (not in whitelist) |
| 2 | Double cold-start cancel+reschedule depletes App Standby quota | HIGH | Diagnostic #5 (RESTRICTED/RARE bucket) |
| 3 | POST_NOTIFICATIONS revoked post-grant, not re-checked | HIGH | Diagnostic #3 (ignored) |
| 4 | Channel muted in system notification settings | MEDIUM | Diagnostic #4 (channel disabled) |
| 5 | tz.local race gives wrong fire time, not missed notification | LOW | Indirect (alarm fires but at wrong time) |

**Primary hypothesis:** BUG-B01 (OEM battery) is most likely given the emulator/phone
discriminant; emulators run stock AOSP without OEM battery layers. BUG-B02
(double-reschedule) is a confirmed code defect regardless of the primary cause.
BUG-B03 (cold-start permission gap) is a confirmed latent bug independent of the
specific device failure.

### Affected Components

- `lib/data/services/notification_service.dart` — scheduling, permission, channel init
- `lib/app.dart` — cold-start listener wiring (BUG-B02, BUG-B03)
- `lib/domain/use_cases/schedule_prediction_notification.dart` — unconditional cancel
- `android/app/src/main/AndroidManifest.xml` — BUG-B06

### Fix Constraints

1. `requestIgnoreBatteryOptimizations` intent: can only be triggered by explicit user
   action. Cannot be auto-granted. Must be gated to avoid Play Store policy issues
   (no blanket "disable battery optimization" prompts without explaining the use case).
2. Standby bucket fix (BUG-B02): a pure Dart change — no manifest or permission changes.
3. POST_NOTIFICATIONS cold-start check: must not show the OS permission dialog on every
   cold-start; use `checkSelfPermission` first, show dialog only if actually revoked.
4. Channel-muted fix: requires Android API 26+; `getNotificationChannel` unavailable below.

### Manual Testing Plan (Device-Class Specific)

**Samsung (One UI) — primary target:**
1. Install fresh APK on a Samsung device with Adaptive Battery enabled.
2. Run diagnostic #1–5 before enabling notification.
3. Enable notification toggle in app. Grant POST_NOTIFICATIONS dialog.
4. Without granting "Unrestricted battery" in Settings, set notification for +2 min
   from now. Confirm notification does NOT fire (verifies OEM block is real).
5. Grant "Unrestricted battery" for Métra via Settings → Battery → Background usage limits.
6. Repeat step 4. Confirm notification fires within 15 min.
7. Revoke POST_NOTIFICATIONS in System Settings. Cold-start app. Confirm BUG-B03 behavior.

**Stock Android (Pixel / emulator):**
1. Verify alarm registered: `adb shell dumpsys alarm | grep metra`.
2. Move app to RESTRICTED bucket: `adb shell am set-standby-bucket com.paolosantucci.metra restricted`.
3. Cold-start app twice in 30 s. Verify double-reschedule via logcat (BUG-B02).
4. Set notification 1 min ahead. Confirm it does NOT fire in RESTRICTED bucket when
   double-reschedule has exhausted the day's quota.

**Channel mute test (any device):**
1. Open System Settings → Apps → Métra → Notifications. Disable "Mētra — Ciclo".
2. Cold-start app. Verify alarm is registered (diagnostic #1) but notification never fires.
3. Verify diagnostic #4 shows importance = IMPORTANCE_NONE.
