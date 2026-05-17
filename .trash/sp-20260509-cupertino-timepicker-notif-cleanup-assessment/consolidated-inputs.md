# Consolidated Assessment — cupertino-timepicker-notif-cleanup

**Date**: 2026-05-09
**Type**: Bug-fix / Enhancement (mixed)
**Modules assessed**: `lib/features/settings/` · `android/app/src/main/` · `lib/data/services/`

---

## Module: lib/features/settings/settings_screen.dart

### Findings

**HIGH** — `_showTimePicker` dispatches on `TargetPlatform.iOS` → Cupertino, Android → Material
`showTimePicker`. The Material dialog is now the only path left using the M3
`TimePickerDialog`; fixing it unifies both platforms on the existing
`_showTimePickerIOS` implementation (CupertinoDatePicker, `minuteInterval: 5`,
`use24hFormat` respects locale, auto-save + Ripristina scaffold).

**HIGH** — Battery-opt row (`if (defaultTargetPlatform == TargetPlatform.android)` block,
lines 165–178) renders "Pianificazione in background" with a chevron that
opens the system dialog via `openBatteryOptimizationSettings()`. The user
wants this row removed for now.

**LOW** — `_showTimePicker` body (lines 507–527) uses `TimeOfDay` which must not
leak into domain (NFR-08, already documented). Removing the Material path
eliminates this risk entirely.

### Tests to change (settings_screen_test.dart)

| Test / group | Action |
|---|---|
| Group `SettingsScreen — Android time-picker theme (FR-01, FR-02)` (~line 795) | **Remove** — tests `TimePickerDialog` theming; widget won't exist after this change |
| `should_not_write_when_cancel_given_open_time_picker` | **Update** — currently taps `'Annulla'` which is the Material cancel button. Cupertino scaffold has no cancel button; dismissal is by tapping the barrier outside the sheet. Change to `tester.tapAt(Offset(10, 10))` on Android too. |
| Keyboard-mode test (taps `Icons.keyboard_outlined`, enters text into `TextField`) | **Replace** — Material-specific; replace with a Cupertino wheel-scroll + OK-tap test verifying the save |
| Group `SettingsScreen — FR-03 battery-opt row (TASK-07)` (lines ~1902–2066, 5 tests) | **Remove** — row is being removed |

---

## Module: android/app/src/main/AndroidManifest.xml

### Findings

**MEDIUM** — `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission (line 4) will have no
in-app caller once the battery-opt row is removed. Manifest permission must be
removed to avoid Play Console policy flag (this permission requires justification).

**LOW (notification investigation — no action)** — `ScheduledNotificationBootReceiver`
intent filter is missing `com.htc.intent.action.QUICKBOOT_POWERON` present in
the plugin's own example manifest (HTC-specific, minor).

---

## Module: lib/data/services/notification_service.dart

### Findings (investigation only — no changes)

**INVESTIGATION** — Real-device notification failure while emulator works is almost
certainly OEM battery management. The battery-opt row WAS the in-app path to
request the system whitelist dialog (`Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).
Removing it means the user must navigate manually (Settings → Apps → Métra →
Battery → Unrestricted) on OEM devices. No code bug found in the notification
implementation:
- `inexactAllowWhileIdle` is correct — avoids SCHEDULE_EXACT_ALARM
- `PlatformException` is caught and logged at line 210
- `computeScheduledTz` / `shouldShowImmediately` logic is correct
- Cold-start guard in `app.dart` (prev `AsyncData` check) is correct

**NOTE**: If notifications remain unreliable after testing on a different device,
the recommended fix is to programmatically invoke
`Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` on first
notification enable (without a persistent Settings row), or switch to
`AndroidScheduleMode.alarmClock` (highest-priority alarm, visible in status bar).
No code change is warranted now.

---

## Spec Inputs

### Components and files affected

| File | Change type |
|---|---|
| `lib/features/settings/settings_screen.dart` | Modify `_showTimePicker` + remove battery-opt block |
| `test/features/settings/settings_screen_test.dart` | Remove Material picker tests + battery-opt group; update/add Cupertino tests |
| `android/app/src/main/AndroidManifest.xml` | Remove `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` |

### Patterns to follow

- `_showTimePickerIOS` is the canonical Cupertino time-picker pattern — reuse it unchanged
- `_CupertinoPickerScaffold` auto-save (250ms debounce) + Ripristina + OK is the established UX contract
- `use24hFormat: MediaQuery.alwaysUse24HourFormatOf(ctx)` must be preserved for Android 24h locale support
- Test: open picker → wheel scroll → verify `stub.savedSettings` updates (or OK tap flushes debounce)

### Integration constraints

- `_showTimePicker` is called from a `Builder`/`GestureDetector.onTap` — signature unchanged
- `_showTimePickerIOS` private static method — no public API change
- `FakeNotificationService` in test helpers: `isIgnoringBatteryOptimizations` and
  `openBatteryOptimizationSettings` methods remain (keep domain interface intact for
  potential future re-addition of the row)

### Tech debt resolved

- Removes the last use of `showTimePicker` (Material) in the codebase — no more dual-path
- Removes `TimeOfDay` local variable that must not leak into domain (NFR-08)

### Test coverage baseline

- 58 `testWidgets` / `test` calls in settings_screen_test.dart
- ~5 tests to remove (FR-01, FR-02 theme tests + keyboard test in Android group + 5 battery-opt tests ≈ 8 total)
- 1 new test to add: Cupertino time-picker save via OK on Android
