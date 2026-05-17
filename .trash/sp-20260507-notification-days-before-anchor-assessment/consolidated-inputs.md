# Consolidated Assessment — Notification Cold-Start Drop

**Date**: 2026-05-07
**Feature**: notification cold-start drops alarm on notification day

---

## Findings

### [HIGH] Cold-start on notification day permanently drops the alarm

**Files:** `lib/domain/use_cases/schedule_prediction_notification.dart:33`,
`lib/data/services/notification_service.dart:122`,
`lib/app.dart:104–129, 163–178`

**Confirmed cause of the user's report.**

Full trace for 2026-05-07 09:29 Europe/Rome:

1. App cold-starts. `cyclePredictionProvider` emits `AsyncLoading → AsyncData(prediction unchanged)`. The prediction `ref.listen` at `app.dart:104` fires. It has **no** `prev is AsyncData` guard (unlike the settings listener).
2. `scheduler.execute()` is called. Line 33: `cancelPredictionNotifications()` runs **unconditionally before any guard** — the OS alarm is wiped here.
3. Use-case date guard: `notifyDay = 2026-05-07`, `todayDay = 2026-05-07` → not before today → passes.
4. `schedulePredictionNotification(notifyAt)` called. Service computes `scheduledDate = 2026-05-07T09:00 Europe/Rome`. Guard: `isBefore(now = 09:29)` → **true → silent return, nothing scheduled.**
5. The settings listener also fires on cold start. A **second** cancel+attempt cycle executes with the same silent-skip result.

**Net effect:** Any pending OS alarm for today 09:00 is canceled. No replacement is registered. If the alarm had not yet fired (device in Doze, off at 09:00, app killed overnight), the notification is permanently lost.

### [Medium] Anchor question — consistent with notification text (not a bug)

**File:** `lib/domain/use_cases/schedule_prediction_notification.dart:41–42`

`notifyAt = windowStart.subtract(notificationDaysBefore)`. With `windowStart = expectedStart − 2d`:
- `expectedStart = 2026-05-14`, `windowStart = 2026-05-12`, `notificationDaysBefore = 5`
- `notifyAt = 2026-05-07` (today) = expectedStart − 7d

The **localized notification body** says: `"La finestra stimata inizia tra {days} giorni"` / `"Your predicted window starts in {days} days"`. This uses `notificationDaysBefore` directly, and the message fires exactly `notificationDaysBefore` days before `windowStart`. **The anchor is internally consistent with the notification text.** This is NOT a bug; the behavior is correct. (The user who sets "5 days before" will receive a message saying "the window starts in 5 days" — which is true.)

### [Low] Cancel runs before guard (structural enabler of HIGH bug)

**File:** `lib/domain/use_cases/schedule_prediction_notification.dart:33`

`cancelPredictionNotifications()` precedes all guards. When the service's own guard prevents rescheduling, an existing alarm is silently wiped. Moving cancel to AFTER the guard decision would prevent the cold-start scenario.

---

## Spec Inputs

**Root cause (confirmed):**
`cancelPredictionNotifications()` is called unconditionally before the service's same-day time guard, so on cold-start after 09:00 on the notification day the alarm is cancelled and not replaced.

**Affected files for the fix:**
- `lib/domain/use_cases/schedule_prediction_notification.dart` — restructure: cancel only when we know a rescheduling will succeed OR when we definitely don't want any alarm
- `lib/data/services/notification_service.dart` — `schedulePredictionNotification`: when `scheduledDate.isBefore(now)` AND `scheduledDate` is on today's calendar day, show the notification immediately instead of silently returning
- `test/domain/use_cases/schedule_prediction_notification_test.dart` — add cold-start regression test
- `test/data/services/notification_service_test.dart` — add same-day-past-09:00 test

**Fix options (ranked by correctness):**
1. **Service-level**: in `schedulePredictionNotification`, if 09:00 has already passed on the notification day, call `_plugin.show()` instead of returning silently. This delivers the notification immediately when the user opens the app on notification day after 09:00. Cleanest UX.
2. **Use-case-level**: restructure `execute()` so `cancel` is deferred until we confirm a successful reschedule path. Harder to reason about atomicity.

**Constraints:**
- `kPredictionNotificationId = 1001` must not change (existing tests + NFR-09).
- `FlutterNotificationService` domain interface (`NotificationService`) must not gain new public methods unless strictly necessary.
- `schedule_prediction_notification_test.dart` currently asserts `windowStart` as anchor — tests need a cold-start case added, not changed.
- GPL-3.0 header on all modified files.
