# P-3 Security Review — Prediction + Notifications

**Date:** 2026-04-29
**Reviewer:** appsec-engineer
**Scope:** P-3 additions (prediction service, notification scheduling, calendar wiring)
**Standard:** OWASP Mobile Top 10 (M1/M2/M5/M9)

---

## Summary

**PASS** — No Critical, High, or Medium findings. The P-3 additions are well-scoped for a privacy-first local app: notification content contains zero health data, the three new dependencies add no network surface, and Android backup exclusions correctly cover the SharedPreferences store used by `flutter_local_notifications` for notification persistence. Two Informational items are noted for P-4 and documentation hygiene.

---

## Findings

### Critical
None.

### High
None.

### Medium
None.

### Low
None.

### Informational

**[INFO-1] `notificationDaysBefore` has no bounds validation at domain or DB layer**

**[INFO-2] `NSUserNotificationsUsageDescription` is a non-standard iOS plist key**

---

## Detailed Analysis

### M1 — Improper Credential Usage / Sensitive Data in Notifications

**Verdict: PASS**

The notification body interpolation path was traced end-to-end:

1. `app.dart:82–84` calls `l10n.notification_prediction_body(settings.notificationDaysBefore)`, where `notificationDaysBefore` is an integer count (default 2).
2. The generated localizations produce:
   - EN: `"Your predicted window starts in $days days"` (`app_localizations_en.dart`)
   - IT: `"La finestra stimata inizia tra $days giorni"` (`app_localizations_it.dart`)
3. `notification_prediction_title` is a static string: `"Your cycle is approaching"` / `"Il tuo ciclo si avvicina"`.

Neither title nor body contains a calendar date, a flow measurement, a symptom, or any other health datum. The only dynamic value is a user-configured integer representing how many days before the prediction window the reminder fires. This is non-sensitive by itself (it reveals nothing about the user's cycle data) and is chosen by the user in Settings.

The empty-body fallback on `app.dart:85` (`body: ''`) is technically unreachable: `SchedulePredictionNotification.execute` cancels any existing notification and returns immediately when `prediction == null` (line 34 of `schedule_prediction_notification.dart`). This is not a security issue, but the dead code slightly misleads readers of `app.dart`.

### M2 — Inadequate Supply Chain Security

**Verdict: PASS**

Three new direct dependencies were introduced in P-3:

| Package | Resolved version | sha256 (pubspec.lock) |
|---|---|---|
| `flutter_local_notifications` | 17.2.4 | `674173fd3c9eda9d4c8528da2ce0ea69f161577495a9cc835a2a4ecd7eadeb35` |
| `flutter_timezone` | 3.0.1 | `ea53c61c9152f271a5e30624a624184804947b6a733ff2b64186bb2579446892` |
| `timezone` | 0.9.4 | `2236ec079a174ce07434e89fcd3fcda430025eb7692244139a9cf54fdcf1fc7d` |

No CVEs are recorded against these versions as of the review date. `flutter_local_notifications 17.2.4` is a patch increment above the curated `^17.2.2` baseline and carries no advisory.

The Android `BroadcastReceiver` components added by `flutter_local_notifications` are both declared `android:exported="false"` in `AndroidManifest.xml` (lines 39–47):

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
```

Neither receiver is reachable from external apps. The `RECEIVE_BOOT_COMPLETED` permission is necessary for the boot receiver to reschedule alarms after device restart; it grants read-only access to the boot broadcast and does not expose app data.

### M5 — Insecure Communication

**Verdict: PASS**

`FlutterNotificationService` (`lib/data/services/notification_service.dart`) uses only:
- `FlutterLocalNotificationsPlugin` — schedules OS-level local notifications, no network I/O.
- `FlutterTimezone.getLocalTimezone()` — reads the device IANA timezone string via a platform method channel, no network I/O.
- `tz.initializeTimeZones()` — loads bundled timezone data from the `timezone` package asset, no network I/O.

There are no HTTP calls, no sockets, and no external URL construction anywhere in the P-3 code surface.

### M9 — Insecure Data Storage

**Verdict: PASS**

`flutter_local_notifications` persists pending notification details — including title and body — to app-private SharedPreferences so that `ScheduledNotificationBootReceiver` can reschedule them after a device reboot (this is the explicit purpose of `RECEIVE_BOOT_COMPLETED`). The storage is app-private by Android default and inaccessible without root.

On a rooted or physically-extracted device, the SharedPreferences file is readable in plaintext. The notification body written to that storage is `"Your predicted window starts in 2 days"` (or equivalent in IT). This string contains no health data — no date, no flow intensity, no symptom — so plaintext persistence carries no meaningful privacy risk beyond what is already inherent in having a cycle-tracking app installed.

Defense-in-depth is correctly in place:
- `android:allowBackup="false"` (`AndroidManifest.xml:9`) prevents Google Cloud Backup from capturing the data directory.
- `data_extraction_rules.xml` explicitly excludes `domain="sharedpref"` from both cloud-backup and device-transfer paths (API 31+).
- `backup_rules.xml` (pre-API-31 fallback) likewise excludes `sharedpref`.

The three exclusions together mean the SharedPreferences store cannot travel to a new device or to cloud storage, even on older Android versions.

---

### INFO-1 — `notificationDaysBefore` has no bounds validation at domain or DB layer

**Affected file:** `lib/domain/use_cases/schedule_prediction_notification.dart:35`, `lib/data/database/app_database.dart:85`

The `notificationDaysBefore` integer flows from a Drift `IntColumn` with a default of `2` through `AppSettingsData` directly into `Duration(days: settings.notificationDaysBefore)` with no clamping. In principle, a value of `0`, a negative number, or a very large number (e.g. 365) could cause the notification to fire at an unexpected time. In practice the current vector is not attacker-controlled: the DB is encrypted (SQLCipher + user's Keystore-backed key), the Settings UI is a P-4 stub that does not yet write this field, and the isBefore-now guard in `execute` discards notifications scheduled in the past.

Recommendation for P-4: when the Settings UI wires up the stepper or picker for `notificationDaysBefore`, clamp the value at the domain boundary before persisting (e.g., `notificationDaysBefore.clamp(1, 14)`). Adding a `CHECK` constraint in Drift at the DB column definition also provides database-level enforcement.

**Severity rationale:** Informational only — no current exploitable path, local-only data, encrypted DB.

---

### INFO-2 — `NSUserNotificationsUsageDescription` is a non-standard iOS plist key

**Affected file:** `ios/Runner/Info.plist:69`

The key `NSUserNotificationsUsageDescription` is not a recognized Apple-documented key. iOS notification authorization is requested at runtime by `UNUserNotificationCenter.requestAuthorization` — which `flutter_local_notifications` handles via `DarwinInitializationSettings(requestAlertPermission: true, ...)` — and the system-generated permission dialog uses Apple's own wording, not a developer-supplied description string.

The common pattern `NSXxxUsageDescription` (camera, microphone, contacts, etc.) does not extend to notifications; there is no plist key that customizes the notification permission prompt text. iOS silently ignores unrecognized plist keys, so this causes no runtime error, but the key provides no user-facing benefit and slightly misleads maintainers into thinking it controls the prompt.

Recommendation: remove `NSUserNotificationsUsageDescription` from `Info.plist`. If a custom explanation is desired, display it in a pre-permission rationale dialog in-app before calling `initialize()`.

**Severity rationale:** Informational — no security impact, iOS ignores the key, no data exposure.

---

## Conclusion

**PASS — v0.1.0-p3 tag is unblocked.**

No blocking findings. Both Informational items are follow-up work:
- INFO-1 must be addressed in P-4 when the Settings notification-days picker is implemented (add a `clamp(1, 14)` guard at the domain boundary and optionally a Drift `CHECK` constraint).
- INFO-2 can be cleaned up in any upcoming iOS pass (remove the non-standard plist key).
