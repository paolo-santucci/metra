---
domain: notifications
last-updated: 2026-07-06
last-verified: 2026-07-06
applied-deltas:
  - 75d5afec8c20be7cfc1b9a6a34e4acb9637079bfd7f45b056f5b0bae4a330547
  - e792ddd990ee9093cdb5145a81ad0b3098d8ee4827806b22246f0eece0747401
  - a50c93a3b3f4ae86842a7216f15645b6ed1c116d3ba0201929bb73f15df5798f
  - 315d12843214e86e512e9801e59b614d9ae2e4939f2921602299014b9d5838a9
  - 11745e67c790398cbd20581eeb96aff0c36d8d27683082040fe0bbfa500e534c
  - ab02121783b5f3f74b1990770cb8eb560a1e6fd90c82291f75b411932c7ce2bf
  - 5b375f1ea5ace9d7e748a8155abdb24568f44f4a1952c57724a97c4274eb3302
  - 4755431575b843ad412cd04bc800f65ac9227ecc3c415fef12f58a29ae7a3556
  - 4dc48b366825db47ad6cd17dc0f8951a6887186d5006f7c97f817651781a7860
applied-feature-ids:
  - notifications-failure-surfaced-to-user
  - notifications-ios-permission-honest
  - notifications-structured-result-consumed
  - notifications-open-settings-method
  - notifications-permission-result-type
  - notifications-localised-channel-name
---

## Overview

The notifications domain delivers a single, configurable local reminder ahead of the user's predicted next cycle. It is reactive: whenever the prediction value changes (via `cyclePredictionProvider`) or the user toggles/edits her preferences (via `settingsNotifierProvider`), a fresh `schedulePredictionNotification` call is composed and dispatched, replacing any previously scheduled alarm under a single stable ID. The domain is platform-only — `flutter_local_notifications` + a private Kotlin method channel for battery-optimisation status. There is no motivational push, no streak, no marketing. The user is asked for OS permission exactly once per explicit enable, never on cold-start. Battery-optimisation whitelisting is surfaced as an informational settings row, not a forced flow.

## Current behaviour

1. `FlutterNotificationService.initialize()` initialises the `timezone` package's IANA DB, queries the device's local IANA name via `FlutterTimezone.getLocalTimezone()`, and calls `tz.setLocalLocation(...)`. If detection throws an `Exception` (unsupported platform, unknown name, no method-channel binding in tests), it falls back to `tz.UTC` and emits a `debugPrint` line — non-fatal (`notification_service.dart:60-73`).
2. `initialize()` then registers the Android `AndroidInitializationSettings('@mipmap/ic_launcher')` and iOS `DarwinInitializationSettings` with `requestAlertPermission: true`, `requestBadgePermission: true`, `requestSoundPermission: true` — iOS permission is therefore requested transitively at init time, not via `requestPermission()` (`notification_service.dart:75-86`).
3. **`initialize(String channelName)`** (localised since 2026-07-06, #34) creates the Android notification channel `metra_cycle` (`Importance.high`) via `createNotificationChannel`, using the caller-supplied `channelName` as the channel's display name — the channel ID (`_kChannelId = 'metra_cycle'`) stays fixed, only the display NAME varies. `FlutterNotificationService` holds an instance field `_channelName` (default `'Mētra'`, the brand-neutral fallback) that's overwritten on every `initialize()` call and reused by both `AndroidNotificationDetails` sites (immediate-show and `zonedSchedule`). `initialize()` **unconditionally re-creates the channel on every call** — no dedup/rename branching — because Android cannot rename an already-created channel post-creation (a display-name change on an existing install is silently a no-op at the OS level; this is intentional, not a bug).
4. `schedulePredictionNotification(notifyAt, title, body)` always computes the scheduled instant via `computeScheduledTz(notifyAt)` — a `TZDateTime` whose calendar day is taken after converting `notifyAt` to `tz.local`, and whose hour/minute are taken **directly from the supplied `notifyAt`** (not from the converted-local value) (`notification_service.dart:109-136`).
5. If the computed `scheduledDate.isBefore(now)`, the service consults `shouldShowImmediately(scheduledDate, now)`. When `scheduledDate` is on the same calendar day as `now` and `now` is at or after `scheduledDate`, the service calls `_plugin.show(...)` (immediate notification) with `kPredictionNotificationId` and the same channel/importance; otherwise it silently returns without scheduling — this is the BUG-005 cold-start guard (`notification_service.dart:144-183`).
6. The normal path calls `_plugin.zonedSchedule(kPredictionNotificationId, title, body, scheduledDate, details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, matchDateTimeComponents: null)`. The inexact mode means the alarm may fire within Doze's ~15-minute window on Android — accepted to avoid the policy-gated `SCHEDULE_EXACT_ALARM` permission on Android 14+ (`notification_service.dart:185-215`).
7. `zonedSchedule` failures are caught at the data layer and wrapped in `NotificationScheduleFailure(error)`. The settings-change listener in `app.dart` consumes the result, reverts `notificationsEnabled` to `false` via `SettingsNotifier`, and dispatches a localised snackbar (IT/EN) through `notificationErrorReporterProvider`. The prediction-change listener consumes the same result but silent-drops on failure (`debugPrint` only, no toggle revert, no snackbar) — the user did not explicitly request this scheduling (`notification_service.dart:210-214`).
8. `cancelPredictionNotifications()` simply calls `_plugin.cancel(kPredictionNotificationId)` — single ID, no group cancel, no per-channel cancel (`notification_service.dart:217-220`).
9. `requestPermission()` resolves the Android plugin first; when present, calls `requestNotificationsPermission()`. When the Android plugin is null, it resolves the iOS plugin and calls `requestPermissions(sound: true, alert: true, badge: true)` — returning the user's choice, or `false` if the call returns `null` (fail-closed for an explicit request). The first call shows the iOS system dialog; subsequent calls return the persisted decision without re-prompting (`notification_service.dart:222-234`).
10. `hasNotificationPermission()` is the read-only counterpart: on Android, it queries `areNotificationsEnabled()` and returns `true` on null plugin result (fail-open). On iOS, it queries `IOSFlutterLocalNotificationsPlugin.checkPermissions()` and returns `options.isEnabled`, treating a null option or null `isEnabled` as `true` (fail-open). Never shows a system dialog on either platform (`notification_service.dart:236-247`).
11. `isIgnoringBatteryOptimizations()` calls `MethodChannel('metra/battery_optimization').invokeMethod<bool>('isIgnoring')`. `null` (Android < 23 — no Doze) is treated as whitelisted (`true`). A `PlatformException` is swallowed and returns `false` (Settings row remains actionable) (`notification_service.dart:249-261`).
12. `openBatteryOptimizationSettings()` calls `invokeMethod<void>('openSettings')`; a `PlatformException` is `debugPrint`-logged with prefix `[NotificationService.openBatteryOpt]` and swallowed (`notification_service.dart:263-270`).
12a. **Cold-start channel-name resolution (`app.dart`, `_initNotificationsAndVerifyPermission`, #34)**. Before calling `initialize()`, `app.dart` resolves the caller-supplied channel name: reads `settingsNotifierProvider.future` → `resolveLocaleFromPlatform(settings.languageCode)` (the same shared resolver the UI locale and the notification-string locale both use — see `settings.md`) → `AppLocalizations.delegate.load(locale)` → `l10n.notification_channel_name` (ARB key, IT "Mētra — Ciclo" / EN "Mētra — Cycle"). If settings or l10n loading throws for any reason, the brand-neutral literal `'Mētra'` is used instead (EC-20) — the whole resolution is wrapped in a try/catch so `initialize()` and the subsequent cold-start permission re-check (item 21) always still run. A later in-session language change does **not** re-invoke `initialize()` — the channel name is resolved exactly once, at cold-start (fresh-installs-only, since Android can't rename an existing channel anyway).
13. The domain use-case `SchedulePredictionNotification.execute(...)` is the **only** caller from app/UI code (`schedule_prediction_notification.dart:23-79`). It unconditionally calls `cancelPredictionNotifications()` first — including when notifications are disabled or `prediction == null` — and then short-circuits (`schedule_prediction_notification.dart:36-37`, verified by tests `EC-08 negative: notificationsEnabled=false → no schedule, cancel called` and `EC-08 negative: null prediction → no schedule, cancel called`). **Cancel-then-schedule order is now regression-tested** (2026-07-06, #33): `FakeNotificationService.callLog` records `'cancel'`/`'schedule'` in invocation order; unit and integration tests assert the exact sequence `['cancel']` (early-return branches) or `['cancel', 'schedule']` (happy path), plus a meta-test proving the assertion actually catches a schedule-before-cancel regression (previously this was verified only by call *counts*, not order).
14. `execute(...)` throws `ArgumentError.value` when `settings.notificationDaysBefore < 1` or `> AppConstants.kMaxAdvanceDays` (= `7`); same for `settings.notificationTimeMinutes` outside `[0, 1439]` (`schedule_prediction_notification.dart:39-54`).
15. The composed `notifyAt` is `DateTime(base.year, base.month, base.day, settings.notificationTimeMinutes ~/ 60, settings.notificationTimeMinutes % 60)` where `base = prediction.windowStart - notificationDaysBefore days`. The result is a **local** `DateTime` (no `.toUtc()`) (`schedule_prediction_notification.dart:56-64`).
16. `execute(...)` accepts a `skipIfPast` flag and an injectable `clock`. When `skipIfPast == true` and `notifyAt.isBefore(now)`, the method returns silently without scheduling — used by the settings-change listener to avoid the service's `shouldShowImmediately` firing a spurious notification after the user adjusts advance days or time. The prediction-data-change listener uses the default `skipIfPast: false` to preserve BUG-005 cold-start immediate-show (`schedule_prediction_notification.dart:65-77`, comment block in same file).
17. Independently of `skipIfPast`, `execute(...)` returns silently when `notifyAt.toLocal()` falls before today's local midnight — preventing scheduling on past calendar days (`schedule_prediction_notification.dart:74-75`).
18. Two listeners in `app.dart` drive the wiring: `cyclePredictionProvider` listener (line 144) for prediction-value changes, and `settingsNotifierProvider` listener (line 180) for preference changes. Both guard `prev is AsyncData<...>` so the `AsyncLoading → AsyncData` cold-start transition does **not** invoke `scheduler.execute(...)` — this is BUG-B02 (`app.dart:147-148`, `app.dart:223`).
19. The settings listener deduplicates redundant emissions: when `prev` and `next` are both `AsyncData` and structurally equal (`AppSettingsData.==`), it returns without scheduling. This collapses the immediate `state =` + Drift-stream-rebuild double-fire from `SettingsNotifier.save()` (`app.dart:186-194`).
20. The settings listener calls `notificationService.requestPermission()` only on the **`AsyncData → AsyncData` transition** where `wasEnabled == false` and `next.notificationsEnabled == true` (BUG-002 fix). If the OS dialog returns `false`, the listener writes `notificationsEnabled: false` back to settings — reverting the toggle so the displayed state matches reality (`app.dart:204-218`). The test `BUG-002 fix: cold-start permission guard` enumerates all five matrix cases.
21. A separate cold-start hook (`_verifyNotificationPermissionOnColdStart`, `app.dart:60-104`) calls `hasNotificationPermission()` (read-only, never shows a dialog) and, if the persisted setting is `notificationsEnabled: true` but the OS permission has been revoked outside the app, writes `notificationsEnabled: false` to settings — keeping the UI honest without ever re-prompting the user (`app.dart:79-104`).
22. The notification's user-visible strings come from `app_localizations`: `notification_prediction_title` and `notification_prediction_body(notificationDaysBefore)` — the days count is interpolated into the body string. The body is set to the empty string `''` when `prediction == null` (`app.dart:161-165`, also covered by the test helper `_simulatePredictionListenerSchedule`).
23. `notificationServiceProvider` is a synchronous `Provider<NotificationService>` returning a single `FlutterNotificationService()` instance per container (no autoDispose). `schedulePredictionNotificationProvider` is a `FutureProvider<SchedulePredictionNotification>` that resolves immediately because `notificationServiceProvider.future` is unused — the use-case constructor is synchronous (`use_case_providers.dart:83-93`).
24. The Android manifest declares exactly one notification-related permission: `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`. `SCHEDULE_EXACT_ALARM` is intentionally **not** declared (`AndroidManifest.xml:2`, also documented in the docstring at `notification_service.dart:30-34`).
25. The Settings screen exposes the notifications section as a `_GroupCard` with three rows (`settings_screen.dart:121-179`): (a) the master `notificationsEnabled` toggle wired to `_MetraToggle` (`settings_screen.dart:125-140`); (b) the **advance-days row** (`settings_screen.dart:142-151`) showing `l10n.settings_advance_value(notificationDaysBefore)`, disabled (greyed and `onTap = null`) when `notificationsEnabled == false`, opening `_showCupertinoDaysPicker` on tap; (c) the **time-of-day row** (`settings_screen.dart:153-172`) showing the time formatted via `MaterialLocalizations.formatTimeOfDay(TimeOfDay(hour: notificationTimeMinutes ~/ 60, minute: notificationTimeMinutes % 60))` (so respects the device 12h/24h format), same `enabled` gate, opening `_showCupertinoTimePicker` on tap.
26. `_showCupertinoDaysPicker` (`settings_screen.dart:585-650`) renders a `CupertinoPicker` wheel inside a shared `_CupertinoPickerScaffold` modal. The wheel has exactly `AppConstants.kMaxAdvanceDays` items (range `1..kMaxAdvanceDays = 1..7`, hard-coded), each labelled via `l10n.settings_advance_value(i)`. `initialItem` is seeded with `(notificationDaysBefore - 1).clamp(0, kMaxAdvanceDays - 1)` (`settings_screen.dart:591-592`). The wheel is themed with `Brightness` matching `Theme.of(ctx)` and `primaryColor: colors.accentFlow`; item height is `44` px with `fontSize: 21` (`settings_screen.dart:600-635`).
27. `_showCupertinoTimePicker` (`settings_screen.dart:530-575`) renders a `CupertinoDatePicker` in `CupertinoDatePickerMode.time` with `minuteInterval: 5` (`settings_screen.dart:553-554`). The seed is `_roundTo5(notificationTimeMinutes)` so the wheel always lands on a 5-minute tick; `_roundTo5` is `((minutes / 5).round() * 5).clamp(0, 1435)` (`settings_screen.dart:347-348`). 24h vs 12h is taken from `MediaQuery.alwaysUse24HourFormatOf(ctx)` (`settings_screen.dart:556`) — i.e. follows the device locale/setting, not an app preference.
28. Both pickers use the **auto-save with debounce** flow implemented in `_CupertinoPickerScaffold` (`settings_screen.dart:925-1090`). Each wheel emission (`onSelectedItemChanged` / `onDateTimeChanged`) calls `scheduleAutoSave()` which (re)arms a `Timer(_kPickerAutoSaveDebounce, ...)` set to `Duration(milliseconds: 250)` (`settings_screen.dart:911`). When the timer fires it invokes `widget.onAutoSave`, which calls `_save(ref, settings.copyWith(notification* : ...))` — i.e. persists via `SettingsNotifier.save()` (`state = AsyncData(settings)` + `repo.updateSettings`), which is exactly the same path that the `settingsNotifierProvider` listener in `app.dart` observes to reschedule the notification.
29. Toolbar buttons on the picker modal (`settings_screen.dart:990-1046`): **Ripristina** (left) cancels the pending debounce, synchronously invokes `onRestore` (which re-saves the original seed), bumps a `UniqueKey` so the wheel rebuilds to the seed, and **keeps the modal open**. **OK** (right) flushes any active debounce by synchronously invoking `onAutoSave` once, then pops the modal. Barrier dismiss without OK lets the last debounced auto-save fire normally (or be cancelled by `dispose()` if still pending — `settings_screen.dart:971-975`).
30. The `notificationDaysBefore` saved by the days picker is `selectedIndex + 1` (so always in `[1, kMaxAdvanceDays]`, matching the `SchedulePredictionNotification.execute` validation range — no UI input can violate it) (`settings_screen.dart:638`). The `notificationTimeMinutes` saved by the time picker is `dt.hour * 60 + dt.minute` (always in `[0, 1439]` by `CupertinoDatePicker` construction, also matching the use-case range) (`settings_screen.dart:558`).
31. Settings writes from these pickers flow through `SettingsNotifier.save(settings)` (`settings_notifier.dart:48-52`), which calls `repo.updateSettings(...)` and then sets `state = AsyncData(settings)`. The Drift `appSettingsStreamProvider` re-emits the same value moments later; the `settingsNotifierProvider` listener in `app.dart:180-218` deduplicates via the structural-equality guard (item 19) so the picker-driven save produces exactly one `scheduler.execute(...)` call. Because the call site uses `skipIfPast: true` (item 16), a wheel-stop that lands on a past instant cancels the existing notification without producing a spurious immediate-show.

## Public contracts

### `NotificationService` (`lib/domain/services/notification_service.dart`)

```dart
abstract class NotificationService {
  Future<void> initialize(String channelName);   // BREAKING (2026-07-06, #34):
                                                  // was initialize() — caller
                                                  // resolves the localised
                                                  // Android channel display
                                                  // name and passes it in.

  Future<NotificationScheduleResult> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  );

  Future<void> cancelPredictionNotifications();

  Future<PermissionRequestOutcome> requestPermission();

// Where:
// sealed class PermissionRequestOutcome { const PermissionRequestOutcome(); }
// final class PermissionGranted extends PermissionRequestOutcome { const PermissionGranted(); }
// final class PermissionDenied  extends PermissionRequestOutcome { const PermissionDenied();  }
// final class PermissionBlocked extends PermissionRequestOutcome { const PermissionBlocked(); }
// (lives in lib/domain/services/notification_service.dart; pure Dart, NFR-07.)
  Future<bool> hasNotificationPermission();

  Future<bool> isIgnoringBatteryOptimizations();
  Future<void> openBatteryOptimizationSettings();
}
```

- `initialize(channelName)` — must be called once before any other method, with the caller-resolved localised Android channel display name (see Current behaviour item 12a for the resolution chain; `app.dart` is the sole caller). Idempotent in the sense of never throwing, but **not** idempotent on channel identity — every call unconditionally re-creates the channel with whatever name is passed (Android silently no-ops a rename on an already-installed channel; this is fresh-installs-only behaviour, by design, not a partial idempotency bug). Never throws (timezone-detection failure is logged + UTC fallback; the caller's own locale-resolution failure is handled by the caller, not this method — see item 12a).
- `schedulePredictionNotification(notifyAt, title, body)` — `notifyAt` may be a local or UTC `DateTime`; the service converts to `tz.local` before extracting the calendar day. Hour/minute are taken from `notifyAt` directly. Replaces any previously scheduled prediction notification (single stable ID). `PlatformException` from the platform scheduler is logged and swallowed; other exceptions propagate.
- `cancelPredictionNotifications()` — cancels exactly the prediction notification (`kPredictionNotificationId = 1001`). No-op if none scheduled.
- `requestPermission()` — only call when the user explicitly enables notifications. Returns `true` if granted/pre-granted (iOS, Android < 13, or null plugin response). Does **not** re-open the system dialog after denial — Android persists the decision.
- `hasNotificationPermission()` — read-only OS-level check; never shows a dialog. Fail-open: returns `true` on platform error or null plugin response. Use for cold-start re-checks.
- `isIgnoringBatteryOptimizations()` — `true` on iOS, Android < 23, and Android ≥ 23 when whitelisted. `false` on `PlatformException` (treat as not-whitelisted so the Settings row remains actionable).
- `openBatteryOptimizationSettings()` — opens `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. No-op on iOS / Android < 23. `PlatformException` (OEM rejection) is logged and swallowed.

### `SchedulePredictionNotification` (`lib/domain/use_cases/schedule_prediction_notification.dart`)

```dart
class SchedulePredictionNotification {
  const SchedulePredictionNotification(this._notifService);

  Future<NotificationScheduleResult> execute({
    required CyclePrediction? prediction,
    required AppSettingsData settings,
    required String title,
    required String body,
    bool skipIfPast = false,
    DateTime Function()? clock,
  }); // returns the result from schedulePredictionNotification verbatim; short-circuits (no prediction, notifications disabled, notifyAt in the past) resolve to NotificationScheduleSuccess.
}
```

- Always cancels any existing scheduled prediction notification first.
- Short-circuits (cancel only, no schedule) when `prediction == null` or `!settings.notificationsEnabled`.
- Throws `ArgumentError.value` if `settings.notificationDaysBefore ∉ [1, kMaxAdvanceDays]` or `settings.notificationTimeMinutes ∉ [0, 1439]`.
- Composes `notifyAt = prediction.windowStart - notificationDaysBefore days @ (notificationTimeMinutes ~/ 60):(notificationTimeMinutes % 60)` in local time.
- Skips scheduling when `notifyAt.toLocal()` is before today's local midnight; additionally skips when `skipIfPast == true` and `notifyAt < now` (settings-change call site).

### `AppSettingsData` notification fields (`lib/domain/entities/app_settings_data.dart`)

```dart
final bool notificationsEnabled;
final int notificationDaysBefore;
final int notificationTimeMinutes; // minutes-since-midnight, default 540 = 09:00
```

- `notificationTimeMinutes` is intentionally omitted from `copyWith` updates from anywhere except the settings save path; the field is constructor-required at the entity level via the `AppConstants.kDefaultNotificationTimeMinutes` default.
- `AppSettingsData.defaults()` returns: `notificationsEnabled: false`, `notificationDaysBefore: 2`, `notificationTimeMinutes: kDefaultNotificationTimeMinutes (540)`.

### `AppSettingsRepository.updateLastDataWriteAt(DateTime)` (cross-domain — not notifications-owned)

Out of scope for this slice; see `cycle-log` / backup spec.

`Future<void> openNotificationSettings();`
Android: dispatches `Settings.ACTION_APP_NOTIFICATION_SETTINGS` via a new method channel `metra/notification_settings`.
iOS: opens `UIApplication.openSettingsURLString` via the iOS plugin where available, else the sibling channel.
`PlatformException` is `debugPrint`-logged and swallowed (same policy as `openBatteryOptimizationSettings`).

## Enumerated providers / limits

- **Android channel ID** — `_kChannelId = 'metra_cycle'` (`notification_service.dart:50`). Must never change post-release (orphans scheduled alarms on un-updated devices).
- **Android channel name** — an instance field `_channelName` (default `'Mētra'`, brand-neutral fallback), set on every `initialize(channelName)` call. Localised via the `notification_channel_name` ARB key (IT `'Mētra — Ciclo'`, EN `'Mētra — Cycle'`), resolved once at cold-start by `app.dart` (item 12a). No longer a hard-coded static constant.
- **Android channel importance** — `Importance.high` (`notification_service.dart:92`). Notification per-call `priority: Priority.high` (`notification_service.dart:189`).
- **Battery-opt method channel** — `MethodChannel('metra/battery_optimization')` (`notification_service.dart:41-42`).
- **Stable notification ID** — `kPredictionNotificationId = 1001` (`notification_service.dart:48`). Single ID for the one prediction reminder; explicitly documented as never-change.
- **Android scheduling mode** — `AndroidScheduleMode.inexactAllowWhileIdle` (`notification_service.dart:204`). Doze window ≈ 15 min. `SCHEDULE_EXACT_ALARM` is **not** declared in the manifest.
- **Max advance days** — `AppConstants.kMaxAdvanceDays = 7` (`app_constants.dart:29`). Enforced in `SchedulePredictionNotification.execute` via `ArgumentError.value`.
- **Min advance days** — `1` (enforced same site as the max; lower bound is hard-coded).
- **Default time-of-day** — `AppConstants.kDefaultNotificationTimeMinutes = 540` = 09:00 local (`app_constants.dart:30`).
- **Time-of-day legal range** — `[0, 1439]` minutes (`schedule_prediction_notification.dart:48`; also stated in the `AppSettingsData.notificationTimeMinutes` doc comment at `app_settings_data.dart:50-53`).
- **Default `notificationDaysBefore`** in defaults — `2` (`app_settings_data.dart:168`).
- **Default `notificationsEnabled`** — `false` (`app_settings_data.dart:169`).
- **Android permissions declared** — `POST_NOTIFICATIONS` and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (`AndroidManifest.xml`). The latter enables the `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` intent dispatched by `openBatteryOptimizationSettings()`.
- **iOS permissions requested** — alert, badge, sound — all at `initialize()` time (`notification_service.dart:77-81`).
- **Advance-days picker widget** — `CupertinoPicker` wheel inside `_CupertinoPickerScaffold` modal (`settings_screen.dart:585-650`). Items: `1..AppConstants.kMaxAdvanceDays` (= `1..7`). Labels: `l10n.settings_advance_value(i)`. Item height `44` px, font size `21`. Used on both Android and iOS.
- **Time-of-day picker widget** — `CupertinoDatePicker` in `mode: CupertinoDatePickerMode.time` inside `_CupertinoPickerScaffold` modal (`settings_screen.dart:530-575`). `minuteInterval: 5`. `use24hFormat` follows `MediaQuery.alwaysUse24HourFormatOf(context)`. Used on both Android and iOS.
- **Time picker seed quantisation** — `_roundTo5(minutes) = ((minutes / 5).round() * 5).clamp(0, 1435)` (`settings_screen.dart:347-348`). Stored value can be any minute (validation accepts `[0, 1439]`); only the wheel seed is quantised so it lands on a tick.
- **Picker auto-save debounce** — `_kPickerAutoSaveDebounce = Duration(milliseconds: 250)` (`settings_screen.dart:911`). Rearmed on every wheel emission; flushed synchronously on OK; cancelled on Ripristina (followed by synchronous resave of seed).
- **Notifications-section row enable gate** — advance-days and time rows have `enabled: settings.notificationsEnabled` (`settings_screen.dart:148`, `:167`). When disabled, `onTap` is set to `null` (`settings_screen.dart:1249`) and label/value text is rendered with `withAlpha(0x80)` (`settings_screen.dart:1221`) — they are visible but non-interactive until the master toggle is on.

## Cross-domain dependencies

- `← cycle-analytics` — the listener in `app.dart` reads `cyclePredictionProvider`; the use case takes a `CyclePrediction?` (its `windowStart` is the anchor for `notifyAt`). When `prediction == null`, the use case cancels and no-ops.
- `← app-settings (preferences)` — reads `settings.notificationsEnabled`, `settings.notificationDaysBefore`, `settings.notificationTimeMinutes`, `settings.languageCode`. The settings-change listener also writes back `notificationsEnabled: false` on permission-denied (revert-toggle path).
- `← i18n (l10n)` — `AppLocalizations.notification_prediction_title` and `notification_prediction_body(daysBefore)` are loaded per emit via `AppLocalizations.delegate.load(Locale(...))`. Body is `''` when `prediction == null`. Since 2026-07-06, `app.dart` also resolves `notification_channel_name` once at cold-start (item 12a) through the same `resolveLocaleFromPlatform` + `delegate.load` seam used for the UI locale (see `settings.md`'s follow-system resolution rule) — one shared resolver, so the channel name and the UI locale can never disagree on which language a given system locale maps to.
- `→ android-platform` — `MethodChannel('metra/battery_optimization')` is implemented in `MainActivity` Kotlin (PowerManager + `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`); the Flutter side only invokes `isIgnoring` and `openSettings`.
- `→ settings UI` — exposes battery-opt status and "enable notifications" toggle; the toggle is the only legitimate trigger for `requestPermission()`.

## Gaps



3. **Prediction changes after a notification is already scheduled — logical order now tested, OS-level race still open**. The listener re-runs `execute()` on every `AsyncData → AsyncData` transition, which cancels then re-schedules under the same stable ID. As of 2026-07-06 (#33), `execute()`'s cancel-before-schedule call order is regression-tested (`FakeNotificationService.callLog`, unit + integration coverage) — a schedule-before-cancel logic regression would now be caught. What remains untested/unaddressed is the **OS-level timing race**: `inexactAllowWhileIdle` gives no atomicity guarantee against a near-fire alarm on the Android side, so the old alarm could in principle still fire mid-rebuild between the app's `cancel` and `schedule` calls reaching the OS. Closing this fully would need a different Android scheduling mechanism or an OS-side transactional primitive, neither of which is in scope of the current fix.
5. **Timezone-change while a notification is scheduled** — `computeScheduledTz` runs only at schedule time; if the device crosses a timezone after scheduling but before fire, the alarm's wall-clock instant is fixed (`absoluteTime` interpretation). No test in scope exercises this.
6. **`kPredictionNotificationId = 1001` collision — partially mitigated**. A guardrail test (2026-07-06, #36) now enumerates all notification-ID constants used in the codebase (currently just the one) into a `const` list and asserts uniqueness, with a failure-path proof confirming the assertion isn't vacuously true. This catches a *future* accidental duplicate the moment a second ID constant is added and appended to the list — it does not (and cannot) enforce that contributors remember to append new IDs; that discipline is documented in a doc-comment on the list, not mechanically enforced.
7. **Battery-optimisation status freshness** — `isIgnoringBatteryOptimizations()` is called on demand by the Settings UI (out of this slice's scope). There is no listener wiring it to permission re-checks; if the user removes the whitelist exemption externally, Métra learns about it only on the next manual Settings open.
