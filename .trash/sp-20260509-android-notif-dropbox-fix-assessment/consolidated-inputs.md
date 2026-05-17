# Consolidated Spec Inputs — Android Notifications + Dropbox OAuth Fix

**Date:** 2026-05-09
**Source reports:**
- `android-notifications-bugs.md`
- `android-dropbox-oauth-bugs.md`

Two distinct Android-only defects. iOS path is unaffected by either. Both fixes are surgical and additive on the Android side only.

---

## 1. Defect summary

### Defect A — Notifications never fire on Android 14+

- **Location:** `lib/data/services/notification_service.dart:187-205` + `android/app/src/main/AndroidManifest.xml:4`.
- **Mechanism:** Manifest declares `SCHEDULE_EXACT_ALARM`. On Android 14+ (API 34+), this permission is **not** auto-granted on install. `_plugin.zonedSchedule(..., AndroidScheduleMode.exactAllowWhileIdle)` throws `PlatformException("exact_alarms_not_permitted")`. The catch block at line 201-205 swallows it silently — the notification toggle appears ON but nothing ever fires.
- **iOS unaffected:** uses APNs / `UNUserNotificationCenter`; the exact-alarm code path is gated by the Android plugin's `AndroidScheduleMode`.
- **Misleading doc comment:** `notification_service.dart:30-35` claims the permission is "pre-granted on earlier versions" — incorrect for current Flutter `targetSdk` defaults (≥34).

### Defect B — Dropbox OAuth fails / hangs on Android 11+

- **Location:** `android/app/src/main/AndroidManifest.xml:69-74` (incomplete `<queries>`) + missing `<service>` entry for `KeepAliveService`.
- **Mechanism 1 (HIGH, near-certain):** `flutter_web_auth_2` queries `Intent(ACTION_VIEW, "http://")` to find a Custom Tab-capable browser. On Android 11+ (`targetSdk≥30`), package visibility filtering returns empty without an explicit `<queries>` declaration for `ACTION_VIEW` with `http`/`https`. Result: Custom Tab launch fails or opens a generic browser without a Custom Tab binding.
- **Mechanism 2 (HIGH, intermittent):** `FlutterWebAuth2Plugin` constructs a `keepAliveIntent` pointing to `KeepAliveService` so Chrome can bind and suppress process reclamation. Without `<service android:name="com.linusu.flutter_web_auth_2.KeepAliveService" android:exported="false"/>`, Chrome cannot bind, the process becomes eligible for reclamation, and on memory pressure / Android 12+ the static `callbacks` map is wiped → `Future` from `dropbox_provider.dart:103` never completes → `BackupNotifier.connect()` hangs in `BackupRunning` indefinitely.
- **iOS unaffected:** uses `ASWebAuthenticationSession`; `Info.plist` URL scheme registration is independent.

---

## 2. Affected components and files

| File | Change category |
|------|-----------------|
| `android/app/src/main/AndroidManifest.xml` | Add `<queries>` ACTION_VIEW entries for `https` and `http`. Add `<service KeepAliveService exported=false/>`. Remove `<uses-permission SCHEDULE_EXACT_ALARM/>`. |
| `lib/data/services/notification_service.dart` | Switch `AndroidScheduleMode.exactAllowWhileIdle` → `AndroidScheduleMode.inexactAllowWhileIdle`. Update doc comment lines 30-35. Replace silent `PlatformException` swallow at lines 201-205 with `debugPrint` so future regressions are visible. |
| `lib/data/services/backup/dropbox_provider.dart` | No code change (line 133 `as String` cast on `refresh_token` is LOW-risk; deferred). |

---

## 3. Strategic decision — notifications scheduling mode

The bug-hunter listed three mutually exclusive options. Decision for this fix:

**Choose `AndroidScheduleMode.inexactAllowWhileIdle`** (drop exact-alarm requirement entirely).

Rationale:
- Métra is a **daily cycle reminder** — accuracy within Doze's ~15 min window is acceptable for a notification telling the user "your period is likely tomorrow".
- Avoids Play Store policy risk: `USE_EXACT_ALARM` is reserved for alarm-clock-class apps; Métra is not.
- Avoids permission-grant UX friction: no Settings redirect, no runtime prompt for `SCHEDULE_EXACT_ALARM`.
- Removes `<uses-permission SCHEDULE_EXACT_ALARM/>` from manifest — one fewer permission to justify in the Play listing.
- Doze still allows the alarm to fire (`*allowWhileIdle` variant).

This is the smallest, lowest-risk fix that aligns with the project's "respect the adult user, no friction" principle.

---

## 4. Constraints the fix must respect

| ID | Constraint |
|----|-----------|
| C-01 | **MUST NOT regress iOS.** Both bugs are Android-only. iOS notification path (`DarwinNotificationDetails`, `requestAlertPermission`) and iOS OAuth path (`ASWebAuthenticationSession` via `Info.plist` URL scheme) must remain unchanged. |
| C-02 | **Additive-only on AndroidManifest** for OAuth. Do NOT re-register `flutter_web_auth_2`'s `CallbackActivity` (would resurrect the prior "Custom Tab stays foreground" regression fixed in commit `f5f4115`). Do NOT modify `MainActivity`'s `singleTop`, `taskAffinity`, or the `consumeOAuthCallback` architecture. |
| C-03 | `<service>` for `KeepAliveService` MUST set `android:exported="false"` (Android 12+ install-time requirement). |
| C-04 | `<queries>` additions must include both `https` AND `http` schemes — Dropbox's auth flow is `https` but `flutter_web_auth_2` queries `http://` literally to find any browser; both schemes are needed. |
| C-05 | Notification scheduling mode change must keep the existing `kPredictionNotificationId = 1001` and `metra_cycle` channel ID unchanged so already-scheduled notifications on devices that have updated continue to be addressable. |
| C-06 | Do NOT add new dependencies. Both fixes are configuration + a one-line API change. |

---

## 5. Related latent bugs

1. **Silent PlatformException swallow** (`notification_service.dart:201-205` and 2 in `app.dart`) — replace with `debugPrint` so future regressions are visible. Same-change candidate.
2. **Misleading doc comment** at `notification_service.dart:30-35` — must be rewritten to describe the new (no exact-alarm) behaviour.
3. **`refresh_token` cast at `dropbox_provider.dart:133`** — LOW; deferred.
4. **Future OAuth providers** (Google Drive, OneDrive) and any `url_launcher https://` call will benefit from the `<queries>` fix — preempts a future regression.

---

## 6. Test coverage gaps

- No unit test reproduces the `PlatformException("exact_alarms_not_permitted")` path. Adding one is straightforward: extend `FakeNotificationService` to throw, assert `debugPrint` is called.
- No widget/integration test for the inexact scheduling mode (the existing tests use a fake plugin so they're mode-agnostic). A test asserting the `AndroidScheduleMode.inexactAllowWhileIdle` argument is passed to `zonedSchedule` would lock in the change.
- No CI step validates AndroidManifest content. Out of scope for this fix; note for future work.
- No platform-channel-level test for OAuth callback routing — `dropbox_provider_test.dart` stubs `_webAuth` so it cannot exercise the manifest path. Manual smoke test on a real Android 11+ device is required.

---

## 7. Patterns to follow

- iOS-only checks already use `Platform.isIOS` / `Platform.isAndroid` where needed (e.g. `settings_screen.dart` Cupertino picker branch). The notification service uses `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()` which correctly returns null on iOS; preserve this idiom.
- License header on every Dart source file (GPL-3.0). Files modified here already have it.
- Tests alongside code: any change to `notification_service.dart` MUST update or add a test in `test/data/services/notification_service_test.dart`.
- Commit messages: conventional format, English, scoped — e.g. `fix(android): switch cycle reminder to inexact alarm` and `fix(android): declare browser <queries> + KeepAliveService for OAuth`.

---

## 8. Verification preconditions for the fix

1. After fix, AndroidManifest.xml must:
   - NOT contain `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>`.
   - Contain `<queries><intent><action ACTION_VIEW/><data scheme=https/></intent><intent><action ACTION_VIEW/><data scheme=http/></intent>...</queries>`.
   - Contain `<service android:name="com.linusu.flutter_web_auth_2.KeepAliveService" android:exported="false"/>` inside `<application>`.
2. After fix, `notification_service.dart`:
   - Must use `AndroidScheduleMode.inexactAllowWhileIdle` in `zonedSchedule`.
   - Must `debugPrint` (not silently swallow) any `PlatformException` from `zonedSchedule`.
   - Doc comment must reflect inexact mode.
3. iOS flow tests (`test/features/settings/settings_screen_test.dart` Cupertino branch, all iOS-side notification tests) must continue to pass without modification.
4. Full test suite must pass.
5. Manual smoke checks (post-merge): Android device — enable cycle reminder, advance system clock, confirm notification fires within Doze window. Android device — tap "Authorize Dropbox", confirm Custom Tab opens and redirect lands cleanly.
