# Android Dropbox OAuth — Bug Assessment
**Date:** 2026-05-09 | **Analyst:** bug-hunter | **Status:** Final

---

## Executive Summary

Three concrete defects in the Android OAuth flow account for the reported breakage. The root cause
is missing manifest infrastructure that the `flutter_web_auth_2` v4.x plugin requires but cannot
self-register. iOS is unaffected because it uses `ASWebAuthenticationSession` (a system API with no
manifest requirements). The `<queries>` gap (BUG-01) is the highest-likelihood trigger on Android
11+; the missing `KeepAliveService` declaration (BUG-02) causes intermittent process-death failures;
the stale `callbacks` map access pattern (BUG-03) is a latent correctness hazard. The PKCE/CSRF
security baseline is sound.

---

## Findings

### [HIGH] BUG-01: Missing `<queries>` entry for http/https browser lookup — Custom Tab may not open on Android 11+

**File:** `android/app/src/main/AndroidManifest.xml` — `<queries>` block (lines 69–74)
**Category:** missing-validation (platform configuration gap)
**CWE:** CWE-693 (Protection Mechanism Failure)
**OWASP MASVS:** MSTG-PLATFORM-1

**Evidence:**

```xml
<!-- current <queries> block — only PROCESS_TEXT, no browser intent -->
<queries>
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
</queries>
```

Plugin source (`FlutterWebAuth2Plugin.kt` lines 111–117):
```kotlin
val activityIntent = Intent(Intent.ACTION_VIEW, Uri.parse("http://"))
val viewIntentHandlers = packageManager.queryIntentActivities(activityIntent, PackageManager.MATCH_ALL)
```

And (`FlutterWebAuth2Plugin.kt` line 93):
```kotlin
val defaultBrowserSupported = CustomTabsClient.getPackageName(context!!, emptyList<String>()) != null
```

**Analysis:** On Android 11+ (API 30+, which this app targets — `targetSdk = 36`), `packageManager.queryIntentActivities` and `CustomTabsClient.getPackageName` are subject to package visibility filtering. Without a `<queries>` entry for `ACTION_VIEW` with scheme `http`/`https`, both calls return empty/null. The plugin then calls `intent.launchUrl(context!!, authUrl)` with no package set. `CustomTabsIntent.launchUrl` falls back to a generic `startActivity`; on devices where no browser has BROWSABLE/DEFAULT registered for `http://` in the package visibility graph, this can throw `ActivityNotFoundException` or silently open nothing. Even when it does open a browser, the absence of a Custom Tab binding means the browser runs in a separate process, increasing the probability of app-process reclamation (see BUG-02).

The plugin's own `AndroidManifest.xml` only declares a `<queries>` entry for `CustomTabsService` action — it intentionally delegates the `ACTION_VIEW` query to the host app.

**Trigger:** Any Android 11+ device running Métra. Attempts to authorize with Dropbox either open a generic browser (not a Custom Tab) or throw `ActivityNotFoundException`.

**Impact:** OAuth browser does not launch, or launches without Custom Tab binding. Auth flow hangs forever or crashes immediately.

---

### [HIGH] BUG-02: `KeepAliveService` not declared in AndroidManifest — Custom Tab can kill app process, wiping `callbacks` map

**File:** `android/app/src/main/AndroidManifest.xml` — no `<service>` element present for `com.linusu.flutter_web_auth_2.KeepAliveService`
**Category:** resource-leak / state-corruption
**CWE:** CWE-404 (Improper Resource Shutdown)

**Evidence:**

Plugin (`FlutterWebAuth2Plugin.kt` lines 50–53):
```kotlin
val keepAliveIntent = Intent(context, KeepAliveService::class.java)
intent.intent.putExtra("android.support.customtabs.extra.KEEP_ALIVE", keepAliveIntent)
```

App manifest: no `<service android:name="com.linusu.flutter_web_auth_2.KeepAliveService"/>` present.

**Analysis:** Chrome Custom Tabs' keep-alive mechanism works by binding to a `Service` advertised via the `EXTRA_KEEP_ALIVE` intent extra. If the service is not declared in AndroidManifest, Chrome cannot bind to it. Without the keep-alive binding, Chrome treats the host app as eligible for reclamation while the tab is showing. If Android kills the Métra process during the auth flow, `FlutterWebAuth2Plugin.callbacks` (a JVM-static `mutableMapOf`) is wiped. When the user completes consent and the `metra://oauth-callback` redirect fires, `consumeOAuthCallback` calls `callbacks.remove("metra")` — which returns `null` (no-op). The `Future<String>` in Dart never completes. The UI is stuck at `BackupRunning(connecting)` indefinitely with no error surfaced to the user.

This is intermittent: it only manifests when Android happens to reclaim the process during the auth flow (more likely on low-memory devices and Android 12+).

**Trigger:** Low-memory Android device, or Android 12+ background process limits. User taps "Authorize Dropbox", Chrome opens, Android reclaims Métra process, user consents, app is relaunched via `metra://` intent — `callbacks` map is empty, auth never resolves.

**Impact:** Silent hang — `BackupRunning` state persists indefinitely. User cannot connect Dropbox without force-quitting and retrying.

---

### [MEDIUM] BUG-03: `onNewIntent` not called when `singleTop` activity is relaunched from a dead process — cold-start path delivers intent via `onCreate` only

**File:** `android/app/src/main/kotlin/com/paolosantucci/metra/MainActivity.kt` (lines 20–23 vs 25–28)
**Category:** logic-error / state-corruption

**Evidence:**

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    consumeOAuthCallback(intent)   // handles cold-start redirect
    super.onCreate(savedInstanceState)
}

override fun onNewIntent(intent: Intent) {
    consumeOAuthCallback(intent)   // handles warm-start redirect
    super.onNewIntent(intent)
}
```

`consumeOAuthCallback` (line 35):
```kotlin
FlutterWebAuth2Plugin.callbacks.remove(url.scheme)?.success(url.toString())
```

**Analysis:** `consumeOAuthCallback` is called correctly in both `onCreate` and `onNewIntent`. However, if the process was killed (BUG-02 scenario), `onCreate` runs but the `callbacks` map is empty — the `?.success(...)` call is a no-op. The Flutter engine then boots, and the `FlutterWebAuth2.authenticate()` call that populated `callbacks` no longer exists — its `Future` was abandoned. The auth result URL is consumed (`intent.data = null`) but never delivered to Dart. There is no timeout, no error state, and no retry signal.

This is not an independent root cause — it is the downstream consequence of BUG-02 — but it surfaces as a distinct symptom: the app appears to have handled the redirect (no crash, go_router doesn't fire) but the `connect()` in `BackupNotifier` is permanently suspended.

**Trigger:** Same as BUG-02 trigger.

**Impact:** `BackupNotifier.connect()` awaits `_webAuth(...)` forever with no escape path.

---

### [LOW] BUG-04: `tokens['refresh_token'] as String` — TypeError on Dropbox re-authorization without `token_access_type=offline`

**File:** `lib/data/services/backup/dropbox_provider.dart` line 133
**Category:** type-confusion / unhandled-error

**Evidence:**
```dart
await _storage.write(
  key: _refreshTokenKey,
  value: tokens['refresh_token'] as String,  // line 133
);
```

**Analysis:** `token_access_type: 'offline'` is passed in the auth URL (line 99), which should always cause Dropbox to include `refresh_token`. However, if the Dropbox app console is configured as "implicit" grant type or if Dropbox changes API behavior, the field may be absent. A `null as String` cast throws a `TypeError` at runtime, which propagates through `BackupNotifier.connect()` as an unhandled error and renders as the generic "Something went wrong" message — unhelpfully hiding the root cause. This is iOS-shared code but is listed as a latent risk.

**Trigger:** Dropbox API returns a token response without `refresh_token` (misconfigured app console or API change).

---

## OAuth Security Baseline

PKCE: S256, 64-char verifier from `Random.secure()` — correct. CSRF state: 16-byte random hex, compared before code exchange — correct. Tokens stored via `flutter_secure_storage` — correct. No tokens in logs. Baseline satisfied.

---

## SUMMARY: 4 findings (0 critical, 2 high, 1 medium, 1 low)

**Highest-risk area:** `android/app/src/main/AndroidManifest.xml`
**Recommended next action:** fix manifest (BUG-01 + BUG-02 together), then verify with a low-memory Android device

---

## Spec Inputs

### Root Cause Analysis (ranked by likelihood)

**Rank 1 — BUG-01: Missing `<queries>` for browser visibility (HIGH, very likely)**
Code evidence: `AndroidManifest.xml` lines 69–74 — only `PROCESS_TEXT` query present. Plugin source `FlutterWebAuth2Plugin.kt` lines 111–117 queries `ACTION_VIEW http://` to enumerate browsers. On targetSdk=36 / Android 11+ (API 30+) this returns empty without a matching `<queries>` entry. The auth URL may open a generic browser or throw. Fix: add `<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>` to the `<queries>` block.

**Rank 2 — BUG-02: Missing `KeepAliveService` declaration (HIGH, likely on low-memory / Android 12+)**
Code evidence: `FlutterWebAuth2Plugin.kt` line 50–53 — `keepAliveIntent` is constructed and set as `EXTRA_KEEP_ALIVE` extra on the Custom Tab intent. No `<service>` for `com.linusu.flutter_web_auth_2.KeepAliveService` in `AndroidManifest.xml`. Without this, Chrome can reclaim the process, wiping the static `callbacks` map. Fix: add `<service android:name="com.linusu.flutter_web_auth_2.KeepAliveService" android:exported="false"/>` inside `<application>`.

**Rank 3 — BUG-03: Silent hang after cold-start process-death (MEDIUM, consequence of BUG-02)**
`consumeOAuthCallback` on `onCreate` correctly calls `callbacks.remove("metra")` but the map is empty after process death. `Future` in Dart never resolves. No user-visible error. This is fully resolved by fixing BUG-02 (process death no longer occurs).

**Rank 4 — External: Dropbox app console redirect URI**
`_redirectUri = 'metra://oauth-callback'` (line 63) and `callbackUrlScheme: 'metra'` (line 103) are consistent. The Dropbox developer console must have `metra://oauth-callback` registered exactly. This cannot be verified statically — the fix spec should note it as a precondition to verify manually.

### Affected Components and Files

| File | Role |
|------|------|
| `android/app/src/main/AndroidManifest.xml` | Missing `<queries>` for browser, missing `KeepAliveService` declaration |
| `android/app/src/main/kotlin/com/paolosantucci/metra/MainActivity.kt` | Downstream victim of process-death; no independent fix needed |
| `lib/data/services/backup/dropbox_provider.dart` | OAuth flow correct; line 133 has LOW-risk cast |

### Related Latent Bugs to Fix in Same Change

- **Future OAuth providers** (Google Drive, OneDrive): the `<queries>` fix should include both `http` and `https` schemes. Absent this, any future OAuth provider using Custom Tabs will hit the same failure on Android 11+.
- **`url_launcher`**: any `launchUrl` call to `https://` URLs from within the app may also silently fail on Android 11+ without a `https` scheme query. Adding the query now prevents a class of future defects.

### Constraints the Fix Must Respect

1. **Must not regress iOS.** iOS uses `ASWebAuthenticationSession` (Swift path: `ios/Classes/SwiftFlutterWebAuth2Plugin.swift`) and is completely unaffected by Android manifest changes. The `Info.plist` already registers the `metra` URL scheme. No iOS file should be touched.
2. **Additive-only on Android manifest.** Add entries to `<queries>` and `<application>`. Do not remove or modify existing intent-filters or the `singleTop` / `consumeOAuthCallback` architecture established in commit `f5f4115`.
3. **`android:exported="false"` on KeepAliveService.** The service is an internal process-keep-alive mechanism; it must not be accessible to external apps. Android 12+ (targetSdk≥31) requires explicit `exported` attribute when a `<service>` is declared — omitting it causes install-time failure.
4. **Do not re-register `CallbackActivity`.** The routing through `MainActivity.onNewIntent` (commit `f5f4115`) replaced the plugin's `CallbackActivity`. Re-registering it would resurrect the "Custom Tab stays foreground" regression.

### Test Coverage Gaps

1. **No platform-channel-level test for the redirect routing.** `dropbox_provider_test.dart` stubs `_webAuth` entirely — it never exercises `FlutterWebAuth2Plugin.callbacks` or `MainActivity.consumeOAuthCallback`. A robo/integration test that drives the actual intent delivery path does not exist.
2. **No CI check that validates AndroidManifest.xml against a required-elements checklist** (queries block, required services, exported attributes). A `xmllint` or `grep`-based step in `android.yml` would catch regressions like the missing `<queries>`.
3. **No process-death smoke test.** The BUG-02/BUG-03 failure mode (app killed during auth, cold-start resume) can only be exercised on a real device with `adb shell am kill com.paolosantucci.metra` during the auth flow. It cannot be unit-tested. The spec should include a manual verification step.
