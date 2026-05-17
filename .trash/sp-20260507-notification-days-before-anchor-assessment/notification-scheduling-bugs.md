# Notification Scheduling — Bug Assessment
**Date:** 2026-05-07  
**Sprint context:** post BUG-001–004 fix (2026-05-06)

---

## Executive Summary

Two distinct issues explain the user's report. Issue 1 is a **product-semantic gap**: the notification anchor is `windowStart`, but the user mentally models it as `expectedStart`, so "5 days before" fires 7 days before the expected start date. Whether this is a bug depends on a product decision (see § Spec Inputs). Issue 2 is a **confirmed latent bug**: a cold-start that occurs on or after the notification day (09:00 already passed) unconditionally cancels any pending OS alarm and does not reschedule, silently dropping the notification.

---

## BUG-01 (Medium): Anchor mismatch between setting label and computed offset

**File:** `lib/domain/use_cases/schedule_prediction_notification.dart:41–42`  
**Category:** logic-error  
**CWE:** CWE-682 (Incorrect Calculation)

**Evidence:**
```dart
final notifyAt = prediction.windowStart
    .subtract(Duration(days: settings.notificationDaysBefore));
```

**Analysis:**  
`windowStart = expectedStart - 2d` (see `cycle_prediction.dart:30`). So:

```
notifyAt = windowStart - N = (expectedStart - 2d) - Nd = expectedStart - (N+2)d
```

With the user's concrete values:
- `expectedStart = 2026-05-14`
- `windowStart   = 2026-05-12`
- `notificationDaysBefore = 5`
- `notifyAt      = 2026-05-07` (today) = **7 days before expectedStart**

The localization strings (authoritative source of the user's mental model):
- EN: `"Your predicted window starts in {days} days"`
- IT: `"La finestra stimata inizia tra {days} giorni"`

Both explicitly name the **window**, not the cycle start. So the anchor `windowStart` is **consistent with the localization contract**. However, the setting is surfaced in the UI under a label whose exact wording is not verified here. If the UI label says "N days before your period" (referencing the cycle start, not the window), the label contradicts the notification body and the anchor — producing a confusing user experience even if the code is internally consistent.

**Trigger:** Any user who reads the setting as "N days before my expected period start" will receive the notification N+2 days before that start.

**Impact:** User receives notification earlier than expected. Not a data-loss or security issue, but a UX regression that undermines trust in the prediction feature.

---

## BUG-02 (High): Cold-start on notification day silently drops the alarm

**Files:**  
- `lib/app.dart:104–129` (prediction `ref.listen`)  
- `lib/app.dart:133–183` (settings `ref.listen`)  
- `lib/domain/use_cases/schedule_prediction_notification.dart:33`  
- `lib/data/services/notification_service.dart:122`  

**Category:** logic-error, error-swallow  
**CWE:** CWE-362 (TOCTOU / Race — time-sensitive conditional)

**Evidence:**
```dart
// use_case line 33 — runs unconditionally:
await _notifService.cancelPredictionNotifications();
// ...
// service line 122 — silent guard after cancel:
if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;
```

**Analysis — full control-flow trace:**

1. App cold-starts at 09:29 on 2026-05-07 (Europe/Rome, UTC+2). Prediction is unchanged (May 12–16, `notifyAt = 2026-05-07`).

2. **Prediction listener** (`app.dart:104`): fires on `AsyncLoading → AsyncData` transition (no `prev is AsyncData` guard — that guard only exists on the settings listener at line 147). Calls `cancelPredictionNotifications()` unconditionally. Then `notifyDay = 2026-05-07`, `todayDay = 2026-05-07` → guard passes (not before today). Calls `schedulePredictionNotification(notifyAt)`.

3. **Service guard** (`notification_service.dart:122`): `computeScheduledTz` returns `2026-05-07T09:00:00 Europe/Rome`. `isBefore(now = 09:29)` → `true` → silent `return`.

4. Result: the existing OS alarm for today 09:00 is **canceled**. No new alarm is registered. If the OS had not yet delivered the notification (device was off, Doze mode, or alarm was set but not yet fired), it is now lost permanently.

5. **Settings listener** (`app.dart:133`): also fires `AsyncLoading → AsyncData` on cold start (the `prev is AsyncData` guard gates only `requestPermission()`; the scheduler call at lines 163-178 runs unconditionally). This issues a second independent `cancel + attempt-to-schedule` cycle, doubling the cancellation without adding a reschedule.

**Trigger:** User powers off device at 08:55 on 2026-05-07 (notification not yet delivered). Powers on at 09:29. App cold-starts. Both listeners cancel the pending OS alarm. The service 09:00 guard prevents reschedule. Notification is lost.

**Impact:** Notification silently never fires. User is not warned before cycle window. This is the most likely explanation for the user's report that "the fix doesn't seem to work."

---

## BUG-03 (Low): Cancel runs before guard — unnecessary side effect when no schedule follows

**File:** `lib/domain/use_cases/schedule_prediction_notification.dart:33–34`  
**Category:** logic-error

**Evidence:**
```dart
await _notifService.cancelPredictionNotifications();
if (prediction == null || !settings.notificationsEnabled) return;
```

**Analysis:** Cancel is unconditional. If `prediction == null` or notifications are disabled, the alarm is wiped and the function returns without rescheduling. On a cold start where notifications are disabled, this cancel is harmless but also unnecessary. More importantly, it means the "cancel before deciding" pattern is what enables BUG-02: by the time the service 09:00 guard fires, the prior alarm is already gone.

**Trigger:** Any call to `execute()` with `prediction == null` or `notificationsEnabled: false` on a day where an alarm was already registered.

**Impact:** Silent alarm loss. Subsumes into BUG-02 for the specific cold-start scenario, but also applies to a settings-disable action that occurs before the alarm fires.

---

## BUG-04 (Low): Test hard-codes `windowStart` anchor — locks in the decision

**File:** `test/domain/use_cases/schedule_prediction_notification_test.dart:144–152, 184–186, 217–220, 251–254`  
**Category:** logic-error (test-level coupling)

**Evidence (representative):**
```dart
expect(
  entry.notifyAt,
  equals(prediction.windowStart.subtract(const Duration(days: 2))),
);
// and three named tests asserting notifyAt == windowStart - N
```

**Analysis:** All four test assertions explicitly validate `windowStart - N` as the correct offset. This is not a runtime bug, but it means any product decision to change the anchor to `expectedStart` requires simultaneous test updates — the tests will not reveal the intent change, they will reject it.

---

## Summary

4 findings (0 critical, 1 high, 2 medium, 1 low)

Highest-risk area: `lib/domain/use_cases/schedule_prediction_notification.dart` + cold-start listener wiring in `lib/app.dart`

---

## Spec Inputs

### Root cause analysis

| Issue | Status | Root cause |
|---|---|---|
| BUG-01: anchor offset | Product decision required | `windowStart` is the anchor; localization body text says "window starts in N days" — internally consistent, but if the UI label says "N days before your period", label and behavior diverge. |
| BUG-02: cold-start drops alarm | Confirmed code bug | `cancelPredictionNotifications()` runs unconditionally before the 09:00 guard in the service. Any cold-start after 09:00 on notification day permanently loses the alarm. |
| BUG-03: cancel before guard | Confirmed minor | Design issue: cancel should move inside the scheduling branch, not before it. |
| BUG-04: test coupling | Confirmed | Tests lock in the anchor decision; they must be updated in lockstep with any anchor change. |

### Files that would need to change per fix

**Fix for BUG-02 (cold-start drop):**  
Move `cancelPredictionNotifications()` to after all guards, or restructure so cancel only happens when a valid reschedule follows:
- `lib/domain/use_cases/schedule_prediction_notification.dart` — restructure cancel to be conditional on the guard passing
- `lib/app.dart` — optionally add `prev is AsyncData` guard to the prediction listener (line 104) to suppress cold-start re-runs, matching the pattern already used by the settings listener at line 147

**Fix for BUG-01 (anchor semantics) — if product decides `expectedStart` is the right anchor:**
- `lib/domain/use_cases/schedule_prediction_notification.dart:41` — change `windowStart` to `expectedStart`
- `lib/l10n/app_en.arb:80` — update body text from "window starts" to "period expected"
- `lib/l10n/app_it.arb:253` — update body text from "finestra stimata inizia" to "ciclo previsto"
- `test/domain/use_cases/schedule_prediction_notification_test.dart` — update all four `notifyAt` assertions

**Fix for BUG-03 (cancel before guard):**
- `lib/domain/use_cases/schedule_prediction_notification.dart` — move cancel inside the branch that proceeds to schedule

### Constraints the fix must respect

1. **Localization contract:** `notification_prediction_body` wording is the user-visible anchor. The code anchor and the UI label must agree. Change both or neither.
2. **Test assertions:** four tests in `schedule_prediction_notification_test.dart` hard-code `windowStart - N`. Any anchor change requires updating these tests first (TDD direction: update test, then fix implementation).
3. **09:00 same-day guard must not be removed:** it was introduced to fix BUG-003 (UTC midnight vs local 09:00 mismatch). The correct fix for BUG-02 is to avoid canceling an alarm the service cannot reschedule, not to move the cutoff later.
4. **`prev is AsyncData` guard semantics:** the settings listener already uses this guard correctly for `requestPermission()`. Extending it to the full scheduler call would suppress cold-start reschedules entirely — this is valid only if app startup on notification day always arrives before 09:00, which cannot be guaranteed.
5. **`notificationDaysBefore` range [1, 7]:** the assert at use-case line 36 enforces this. Any anchor change that alters effective lead time must be revalidated against this range (e.g. with `expectedStart` anchor and `N=7`, notification fires 7 days before expected start, which is 9 days before window end — reasonable).
