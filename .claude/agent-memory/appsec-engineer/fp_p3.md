---
name: False positives and known patterns from P-3
description: Patterns confirmed benign in P-3 notification review — suppress or downgrade in future sprints
type: feedback
---

**SharedPreferences persistence by flutter_local_notifications** — The plugin stores pending notification title/body to app-private SharedPreferences so the ScheduledNotificationBootReceiver can reschedule after reboot. This is intentional, not a data-leakage bug. Android backup exclusions (allowBackup=false, data_extraction_rules.xml, backup_rules.xml) all exclude `sharedpref`, so the data cannot travel to cloud or a new device. Only raise as a finding if the notification body ever contains health data.

**Why:** Surfaced during P-3 M9 review. Will recur every sprint that touches notifications.

**How to apply:** When reviewing notification-related M9, confirm notification body content first; if generic (count/label only), mark persistence as Informational and note the backup exclusions as mitigating.

---

**`notificationDaysBefore` lacks domain-layer bounds validation** — P-4 ships a picker bounded 1–7 in the UI, but `DriftAppSettingsRepository.updateSettings` and `SchedulePredictionNotification.execute` accept any integer. No attacker-controlled path exists currently. Raised as LOW in P-4 review; remediation (`clamp(1, 7)` at the domain boundary) deferred to P-5.

**Why:** UI picker prevents out-of-bounds in normal use; domain-layer clamp is a defense-in-depth measure.

**How to apply:** If P-5 touches settings or notification scheduling, re-evaluate and escalate if still absent. If picker bounds are widened, update the clamp constant accordingly.
