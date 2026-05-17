# Cluster C — Dropbox OAuth: Real-Device Failure Analysis

**Date:** 2026-05-09
**Analyst:** bug-hunter agent
**Scope:** Phases 1, 2, 3, 5, 6, 7
**Bug description:** Dropbox OAuth works on the Android emulator but fails on a real phone (regression still present after rc14 fix attempt).

---

## Executive Summary

Two independent defects explain the real-device failure. The **primary** cause is that `KeepAliveService` is declared `android:exported="false"` in `AndroidManifest.xml`, which prevents Chrome (a separate process) from binding to it — the mechanism that prevents the system from killing the app while the Custom Tab is open. On real phones with aggressive OOM killers, the app process dies during the OAuth flow; on return, the static `callbacks` map is empty and the `authorize()` Future never resolves, leaving the UI in a permanent `BackupRunning` spinner. A **secondary**, currently latent defect is the absence of `INTERNET` from the main manifest, which would prevent all Dropbox API network calls on release builds. Both bugs must be fixed before release.

---

## Findings

---

[HIGH] BUG-C01: KeepAliveService declared non-exported — Chrome cannot bind to keep process alive
File: `android/app/src/main/AndroidManifest.xml:62`
Category: state-corruption / integration
CWE: CWE-670 (Always-Incorrect Control Flow Implementation)

Evidence:
```xml
<service android:name="com.linusu.flutter_web_auth_2.KeepAliveService"
         android:exported="false"/>
```

Analysis:
`flutter_web_auth_2` uses the Chrome Custom Tabs Keep-Alive mechanism. After opening the Custom Tab it puts a `KeepAliveService` intent as an extra on the Chrome intent:
```kotlin
// FlutterWebAuth2Plugin.kt:53
intent.intent.putExtra("android.support.customtabs.extra.KEEP_ALIVE", keepAliveIntent)
```
Chrome then calls `bindService` on this intent from its own UID to signal to the OS that the app is in use and should not be killed. Because `android:exported="false"`, Android denies Chrome's `bindService` call. The service is invisible to any package other than the host app itself. Chrome's bind attempt silently fails.

Consequence: on real phones with memory pressure (Samsung, Xiaomi, OnePlus, etc.) the app is a candidate for being killed while Chrome is in the foreground. When the process is killed, the static `FlutterWebAuth2Plugin.callbacks` map (in-process, not persisted) is cleared. When the OAuth redirect fires (`metra://oauth-callback?code=...`), Android starts a fresh process and calls `MainActivity.onCreate()`. `consumeOAuthCallback()` runs, but `callbacks.remove("metra")` returns `null` because the map is empty. The pending `FlutterWebAuth2.authenticate()` `Future` in `authorize()` never completes. `BackupNotifier.connect()` awaits forever. The UI is stuck at `BackupRunning(connecting)`.

On the emulator, the Android emulator does not pressure memory aggressively; the process survives without Chrome's keep-alive, so `onNewIntent` fires into the live process and the map lookup succeeds.

Trigger:
1. User taps "Authorize Dropbox" on a real phone.
2. Chrome Custom Tab opens Dropbox consent page.
3. Android OOM killer terminates the Metra process (background, no visible window).
4. User grants consent; Chrome redirects to `metra://oauth-callback?code=X&state=Y`.
5. Android starts a fresh Metra process, calls `MainActivity.onCreate(intent)`.
6. `consumeOAuthCallback` finds an empty `callbacks` map, returns without resolving.
7. Emulator: step 3 does not occur; the map lookup succeeds.

Impact: OAuth is silently broken on all real phones that kill background processes. The user sees an infinite spinner with no error and no way to recover except restarting the app and retrying.

---

[HIGH] BUG-C02: INTERNET permission absent from main manifest — release APK cannot perform network I/O
File: `android/app/src/main/AndroidManifest.xml:1-83`
Category: missing-validation / integration
CWE: CWE-276 (Incorrect Default Permissions)

Evidence:
```xml
<!-- android/app/src/main/AndroidManifest.xml — permissions block -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<!-- android.permission.INTERNET is absent -->
```
```xml
<!-- android/app/src/debug/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>
```

Analysis:
`INTERNET` appears only in `src/debug/AndroidManifest.xml`. Android Gradle merges overlay manifests: debug builds receive `INTERNET`; release builds do not. All Dropbox API calls (`authorize()` token exchange, `upload()`, `download()`, `listFiles()`) go through `http.Client` which requires `INTERNET`. On a release APK without this permission, `http.Client.post()` throws `SocketException: Failed host lookup` before returning any status code. The call falls into the outer catch in `BackupNotifier.connect()` and emits the generic `'Something went wrong. Please try again.'` error.

**Status: latent.** Current test builds are debug APKs (per STATUS.md test plan: "install fresh debug build"). The debug manifest grants `INTERNET`. This defect will manifest immediately on first release APK install.

Trigger: Install the CI release APK (`*-release.apk` artifact from `android.yml`), tap "Authorize Dropbox". Custom Tab opens normally (Chrome's own process), user authorizes. On return, `_client.post(Uri.https('api.dropbox.com', '/oauth2/token'), ...)` throws `SocketException`.

Impact: Dropbox OAuth, backup, and restore all fail silently on every release build.

---

[MEDIUM] BUG-C03: No timeout on `authorize()` Future — UI permanently stuck on process-death
File: `lib/data/services/backup/dropbox_provider.dart:102-103`
Category: resource-leak / error-handling-gap

Evidence:
```dart
final result =
    await _webAuth(authUrl.toString(), callbackUrlScheme: 'metra');
```
`_webAuth` delegates to `FlutterWebAuth2.authenticate()`. If the process was killed (BUG-C01 scenario) the Future returned by `authenticate()` never completes and no exception is thrown. There is no `Future.timeout()` guard anywhere in the call chain from `BackupNotifier.connect()`.

Analysis: The UI transitions to `BackupRunning(connecting)` at the start of `connect()`. If the Future hangs, the state never progresses. The user cannot navigate away from the BackupRunning screen (no cancel button), and restarting the screen would require killing and restarting the app. Even after BUG-C01 is fixed, OEM-specific battery optimisers (Xiaomi MIUI, Samsung's "App battery usage: Restricted") can kill services even when exported=true. A timeout is the correct defence-in-depth.

Trigger: Any scenario where `FlutterWebAuth2.authenticate()` never resolves (process death, user closing Chrome tab without a redirect, Custom Tab crash).

Impact: App UI locked in loading state with no recovery path short of killing the process.

---

[LOW] BUG-C04: Generic error swallows the actual exception class — root cause invisible to developer
File: `lib/features/backup/state/backup_notifier.dart:54-62`
Category: error-swallow

Evidence:
```dart
} catch (e) {
  state = AsyncData(
    BackupErrorState(
      e is MetraException
          ? e.message
          : 'Something went wrong. Please try again.',
    ),
  );
}
```

Analysis: Non-`MetraException` errors (e.g., `SocketException` from BUG-C02, `PlatformException` from Custom Tab dismissal) are coerced to the generic UI string. The actual exception type and message are discarded. No `debugPrint`, no structured log. This makes the emulator-vs-real-phone debugging entirely dependent on the user being able to run `adb logcat` — which they were not, explaining why the rc14 fix did not detect the INTERNET permission gap.

Impact: Future real-device bugs in the OAuth path will be equally opaque.

---

## Latent Concern (not a bug, design note)

The `consumeOAuthCallback` in `MainActivity.kt` calls `intent.action = null` before `super.onCreate()`. This strips the intent action from the instance the Flutter engine receives. No crash has been observed, but `FlutterActivity.onCreate()` uses `getInitialRoute()` which reads `intent.getData()` (already nulled) not `intent.getAction()`, so this is benign for the current Flutter version. Flagging for awareness — if a future Flutter version reads intent action in `onCreate`, this could regress.

---

## SUMMARY: 4 findings (0 critical, 2 high, 1 medium, 1 low)

Highest-risk area: `android/app/src/main/AndroidManifest.xml`
Recommended next action: Fix BUG-C01 (`exported="true"`) and BUG-C02 (add `INTERNET`) in the same manifest commit; add a `Future.timeout` in BUG-C03 as defence-in-depth.

---

## Spec Inputs

### ROOT CAUSE — ranked by confidence

**RC-1 (HIGH confidence): KeepAliveService `android:exported="false"` (BUG-C01)**
Chrome's Custom Tabs keep-alive protocol requires binding to the service from an external process. Android denies this for `exported="false"` services. Without the keep-alive, aggressive OOM killers on Samsung/Xiaomi/OnePlus/etc. terminate the Metra process. Static callbacks map is empty after restart; `authorize()` Future hangs. This is the discriminator between emulator (lenient OOM) and real phone (aggressive OOM).

**RC-2 (HIGH confidence, latent): Missing `INTERNET` permission in main manifest (BUG-C02)**
Currently masked by debug builds. Will manifest on first release APK. Certain to bite.

**RC-3 (LOW confidence, excluded): PKCE / client_secret issue**
PKCE is fully implemented (code_verifier + S256 challenge, no client_secret in token exchange body). Not a factor.

**RC-4 (LOW confidence, excluded): Intent-filter misconfiguration**
The `<intent-filter>` on `MainActivity` with `BROWSABLE + DEFAULT + scheme=metra, host=oauth-callback` is correctly formed. The `singleTop` launch mode is correct for receiving `onNewIntent`. Not a factor.

### Affected components and files

| File | Lines | Bug |
|------|-------|-----|
| `android/app/src/main/AndroidManifest.xml` | 62 | BUG-C01: `exported="false"` |
| `android/app/src/main/AndroidManifest.xml` | 1–4 | BUG-C02: no `INTERNET` |
| `lib/data/services/backup/dropbox_provider.dart` | 102–103 | BUG-C03: no timeout |
| `lib/features/backup/state/backup_notifier.dart` | 54–62 | BUG-C04: error swallow |

### Constraints the fix must respect

1. **Privacy — Dropbox token in secure storage.** `_storage.write(key: _accessTokenKey)` and `_storage.write(key: _refreshTokenKey)` must remain exclusively in `DropboxProvider`. No token may transit through insecure channels.
2. **No telemetry.** The `debugPrint` improvement in BUG-C04 must use the existing `debugPrint` / local-log pattern only — no remote reporting.
3. **Must not break emulator flow.** The emulator OAuth path is working. Changes must be additive to the manifest (not structural).
4. **Android 11+ package visibility.** The existing `<queries>` block for `https/http` and `PROCESS_TEXT` must be preserved. The plugin's own manifest already provides the `CustomTabsService` query via manifest merge.
5. **PKCE flow is correct — do not touch.** `_generateCodeVerifier()`, `_codeChallenge()`, and the token exchange body are correct.

### Proposed fix per hypothesis

**Fix for BUG-C01 (KeepAliveService export):**
Change `android:exported="false"` to `android:exported="true"` on the `KeepAliveService` declaration in `AndroidManifest.xml`. This allows Chrome to call `bindService` against the service from its own UID, activating the keep-alive mechanism. Note: `exported="true"` is necessary but not sufficient on OEMs with system-level app-kill policies (MIUI "Battery Saver — Restricted"). A timeout (BUG-C03 fix) is the complementary defence. No other component or code change is needed for this fix.

**Fix for BUG-C02 (INTERNET permission):**
Add `<uses-permission android:name="android.permission.INTERNET"/>` to the root `<manifest>` block of `android/app/src/main/AndroidManifest.xml` (not inside `<application>`). This restores the permission for release builds. Without it, all `http.Client` calls in `DropboxProvider` fail with `SocketException` on any signed/release APK.

**Fix for BUG-C03 (no timeout):**
Wrap the `_webAuth(...)` call in `authorize()` with a `Future.timeout(const Duration(minutes: 5))`. On timeout, throw a `SyncException('OAuth timed out — please try again')` which will propagate up to `BackupNotifier.connect()` and display a recoverable error state. Five minutes is generous enough for a human to complete the Dropbox consent flow.

**Fix for BUG-C04 (error swallow):**
In `BackupNotifier.connect()` catch block, add `debugPrint('[BackupNotifier.connect] error: $e')` before the state transition. This makes the actual exception visible in `adb logcat` without exposing it to the user UI.

### What manual testing is needed to confirm the fix on a real phone

Run with a **debug build** on the real phone and observe exactly which failure mode occurs before the fix. The user should report one of three scenarios:

1. **Chrome Custom Tab opens, user authorizes, Chrome closes, but the app stays on the connecting spinner indefinitely.** → This confirms BUG-C01 (process death, Future never resolves). Fix: `exported="true"` + timeout.

2. **Chrome Custom Tab opens, user authorizes, Chrome returns the user to Metra, a generic error "Something went wrong" appears immediately.** → This confirms BUG-C02 (SocketException on token exchange). Fix: add `INTERNET`. To disambiguate, check `adb logcat | grep SocketException`.

3. **Chrome Custom Tab does not open at all, or the app crashes immediately.** → Configuration or launch-mode issue; re-investigate.

After applying fixes, the acceptance test is:
- Install fresh **debug** build. Tap "Authorize Dropbox". Chrome Custom Tab opens. Authorize on Dropbox. Custom Tab closes. App transitions from spinner to `BackupConnected(email: ...)` state. No restart required.
- Install fresh **release** APK (or CI `*-release.apk` artifact). Repeat above. Same expected result.
