> **⚠ ARCHIVED — NOT current truth.** This document captured state at planning time. Current behavior may have diverged. Consult the current codebase or active spec docs.

# Android Play Store — Pre-Release Audit & Publishing Guide

**App:** Métra 1.0.0+2  
**Audited:** 2026-05-10  
**Last updated:** 2026-05-10 (A7, A8, C18, G49 resolved; version bumped to 1.0.0+2)  
**Resolved SDK values:** minSdk 24 · targetSdk 36 · compileSdk 36 · versionCode 2 · versionName 1.0.0

---

## Pre-Release Audit

### A — Project Structure & Build

| # | Item | Result |
|---|------|--------|
| A1 | Single-module Gradle project, no circular dependencies | ✅ PASS |
| A2 | Release build: `isMinifyEnabled=true`, `isShrinkResources=true`, `debuggable` not set (defaults false in release) | ✅ PASS |
| A3 | ProGuard rules present and tested (Gson/TypeToken fix verified on-device) | ✅ PASS |
| A4 | `applicationId = "com.paolosantucci.metra"` | ✅ PASS |
| A5 | versionCode=2, versionName=1.0.0 — bumped 2026-05-10 for first public release | ✅ PASS |
| A6 | All pubspec.yaml dependencies use stable `^x.y.z` ranges, no SNAPSHOTs | ✅ PASS |
| A7 | TODO comment removed from `build.gradle.kts:32` | ✅ FIXED 2026-05-10 |
| A8 | `flutter analyze` → 0 issues; `dart format` → 0 changes (auto-fixed `settings_screen_test.dart`); `flutter test` → 883/883 | ✅ FIXED 2026-05-10 |

### B — AndroidManifest & Permissions

| # | Item | Result |
|---|------|--------|
| B9 | 3 permissions declared: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `INTERNET` — all actually used | ✅ PASS |
| B10 | `POST_NOTIFICATIONS` has runtime request flow; `inexactAllowWhileIdle` avoids `SCHEDULE_EXACT_ALARM` entirely | ✅ PASS |
| B11 | No `<uses-feature>` entries needed — no camera/GPS/Bluetooth | ✅ N/A |
| B12 | All components have explicit `android:exported`: `MainActivity=true`, both receivers=false, KeepAliveService=true | ✅ PASS |
| B13 | `metra://oauth-callback` intent filter is specific (scheme+host), not broadly implicit | ✅ PASS |
| B14 | `allowBackup=false`, `dataExtractionRules` + `fullBackupContent` both explicitly exclude all domains | ✅ PASS |
| B15 | `<queries>` block declares `PROCESS_TEXT`, `https`, `http` intents | ✅ PASS |

### C — Signing & Security

| # | Item | Result |
|---|------|--------|
| C16 | Signing credentials read from `key.properties` — no plaintext passwords in `.kts` | ✅ PASS |
| C17 | `key.properties` + `*.keystore` + `*.jks` in `.gitignore` | ✅ PASS |
| C18 | `network_security_config.xml` created (`cleartextTrafficPermitted=false`, system CAs only); wired into `AndroidManifest.xml` via `android:networkSecurityConfig` | ✅ FIXED 2026-05-10 |
| C19 | No `android:debuggable="true"` in manifest (release build type inherits false) | ✅ PASS |
| C20 | No `Log.*`/`println` in Android Kotlin source files | ✅ PASS |

### D — Resources & UI Quality

| # | Item | Result |
|---|------|--------|
| D21 | Adaptive icon: `ic_launcher.xml` with background color + foreground PNG + monochrome layer; legacy PNGs in mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi | ✅ PASS |
| D22 | All drawables in full density range | ✅ PASS |
| D23 | Flutter app — all user-facing strings via `l10n` / `AppLocalizations` | ✅ PASS |
| D24–D26 | Flutter handles theming, insets, and config changes — delegated to Flutter audit | ✅ PASS (Flutter layer) |

### E — Accessibility & Material Design

Delegated to Flutter layer. Confirmed from CLAUDE.md: WCAG 2.2 AA minimum is a project principle.

### F — Performance & Stability

| # | Item | Result |
|---|------|--------|
| F36 | No main-thread disk/network I/O in Kotlin native code — MainActivity is thin, no blocking ops | ✅ PASS |
| F40 | No `!!` force-unwrap operators in Android Kotlin source | ✅ PASS |

**Dead code risk (not blocking, but must be resolved before next release):**  
`openBatteryOptimizationSettings()` exists in domain + data interfaces and in `MainActivity.openSettings` handler, but has **zero callers in feature code**. The `openSettings` path calls `startActivity(ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)` without the matching `uses-permission` declared — this would throw a `SecurityException` if ever invoked. Since the UI row was removed it is unreachable today, but it is a landmine. Recommend removing the dead method and the MethodChannel handler.

### G — Google Play Policy

| # | Item | Result |
|---|------|--------|
| G41 | Data safety: app stores menstrual cycle data **locally only**, optional E2E-encrypted cloud backup | ⚠️ MUST CONFIGURE in Play Console — see below |
| G42 | No ads present | ✅ N/A |
| G43 | targetSdk 36 — exceeds current Play Store minimum (34) | ✅ PASS |
| G44 | No restricted APIs — `inexactAllowWhileIdle` vs exact alarms is correct design | ✅ PASS |
| G45 | No background location | ✅ N/A |
| G46 | No digital goods / billing | ✅ N/A |
| G47 | Content rating — must be completed in Play Console | ⚠️ MUST COMPLETE |
| G48 | No placeholder content, test data, or debug features visible in release APK | ✅ PASS |
| G49 | Privacy policy URL `https://paolo-santucci.github.io/metra/privacy` → HTTP 200 (follows 301 trailing-slash redirect) | ✅ VERIFIED 2026-05-10 |
| G50 | App does not target children | ✅ N/A |

### Audit Summary

| | Count |
|---|---|
| ✅ PASS | 32 |
| ⚠️ Advisory / Must-do before upload | 2 |
| ❌ BLOCKING FAIL | 0 |

**No hard blockers.** A7, A8, C18, G49 resolved 2026-05-10. Two items remain as Play Console configuration steps (G41 data safety form, G47 content rating questionnaire) — these cannot be done from code, only in the Play Console web UI.

---

## Step-by-Step: Publishing to Google Play

### Step 0 — Pre-submission checklist (do these first)

~~**0a. Strip the TODO comment**~~ ✅ Done 2026-05-10 — removed from `android/app/build.gradle.kts`.

~~**0b. Run quality gates**~~ ✅ Done 2026-05-10:
- `flutter analyze` → No issues found
- `dart format` → 0 changed files (auto-fixed `test/features/settings/settings_screen_test.dart`)
- `flutter test` → 883/883 passed

~~**0c. Verify the privacy policy page is live**~~ ✅ Done 2026-05-10 — `https://paolo-santucci.github.io/metra/privacy` returns HTTP 200.

**0d. Create `android/key.properties` locally** (still a TODO per STATUS.md):
```properties
storeFile=/home/paolo/.android/metra-release.keystore
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```
This file is already in `.gitignore`. Never commit it.

---

### Step 1 — Build the Android App Bundle (AAB)

Google Play requires an **AAB** (`.aab`), not an APK, for new app submissions since August 2021.

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

> **Why AAB?** Play generates optimized APKs per device configuration (screen density, ABI, language). Smaller download for users.

---

### Step 2 — Create your Google Play Developer account (one-time)

1. Go to [play.google.com/console](https://play.google.com/console)
2. Pay the **$25 one-time registration fee**
3. Complete identity verification (can take 24–48 hours)

---

### Step 3 — Create the app in Play Console

1. Click **"Create app"**
2. Fill in:
   - **App name**: `Métra` (use the typographic ē)
   - **Default language**: Italian
   - **App or game**: App
   - **Free or paid**: Free
3. Accept the declarations
4. Click **"Create app"**

---

### Step 4 — Complete the Store Listing

Go to **"Store presence → Main store listing"**:

| Field                          | Content                                                                                 |
| ------------------------------ | --------------------------------------------------------------------------------------- |
| Short description (≤80 chars)  | `Diario del ciclo mestruale — privato, locale, libero.`                                 |
| Full description (≤4000 chars) | Italian + English; emphasize local-first, no cloud, no telemetry                        |
| Screenshots                    | Minimum 2 phone screenshots (1080×1920px or similar). Use your physical Android device. |
| Feature graphic                | 1024×500px banner                                                                       |
| App icon                       | 512×512px PNG (use your existing adaptive icon design)                                  |
| Privacy policy URL             | `https://paolo-santucci.github.io/metra/privacy`                                        |

---

### Step 5 — Data Safety section (critical for health apps)

Go to **"Policy → Data safety"**. This is the most important form for Métra. Fill it precisely:

**Data collection:**
- "Does your app collect or share any of the required user data types?" → **Yes** (menstrual cycle is health data)

**Data types — select:**
- **Health and fitness → Health info** ✅ (menstrual cycle dates, symptoms, flow data)

**For each data type, declare:**

| Question | Answer |
|----------|--------|
| Is this data collected? | **No** (it never leaves the device to your servers) |
| Is this data shared? | **No** |
| Is data encrypted in transit? | N/A (not transmitted to you) |
| Can users request deletion? | **Yes** (app has full data delete in Settings) |

**Data processed ephemerally:** Optional E2E-encrypted Dropbox/OneDrive backup — this is user-initiated, encrypted on-device before upload, and you never have access to the key. Declare: data is transmitted to third-party cloud storage by user choice, encrypted end-to-end.

> ⚠️ **Important**: Health data (menstrual cycle) falls under sensitive data categories. Play Console will likely require you to certify that you handle it per their [Sensitive Data policy](https://support.google.com/googleplay/android-developer/answer/9888076). Answer honestly — the app's local-first design makes this straightforward.

---

### Step 6 — Content Rating Questionnaire

Go to **"Policy → App content → Content rating"**:

1. Click **"Start questionnaire"**
2. Category: **Utility**
3. Answer all questions (no violence, no sexual content, no user-generated content, no location sharing, no ads)
4. Expected rating: **PEGI 3 / Everyone** — correct for a utility app

---

### Step 7 — Target Audience & Content

Go to **"Policy → App content → Target audience and content"**:

- Target age group: **18 and over** (menstrual health — adult users)
- Does the app appeal to children? **No**

---

### Step 8 — Upload the AAB to Internal Testing

Start with **Internal Testing** (instant publish, no Google review required):

1. Go to **"Testing → Internal testing"**
2. Click **"Create new release"**
3. Upload `app-release.aab`
4. Release name: `1.0.0 (build 2)`
5. Release notes (IT): `Prima versione pubblica.`
6. Click **"Save"** → **"Review release"** → **"Start rollout to Internal testing"**

Add yourself as an internal tester: **"Testers"** tab → add your Google account → save.

---

### Step 9 — Smoke test on physical device via Internal Testing

1. On your Android device, open the Google Play Store
2. Go to the Internal Test link (Play Console provides a shareable link)
3. Opt in to testing
4. Install and verify:
   - App launches without crash
   - Dropbox OAuth works (validates BUG-C01)
   - Notifications fire (validates ProGuard fix)
   - Encrypted DB — try opening the `.db` file with DB Browser for SQLite: should fail without the key

---

### Step 10 — Promote to Production

Once internal testing passes:

1. **"Testing → Closed testing (Alpha)"** → validate with a wider circle
2. **"Production"** → **"Create new release"** → upload the same AAB → set rollout % (start at 10–20%)
3. Google review takes **2–7 business days** for new apps

---

### Version bumping rule

Every future upload must increment the versionCode in `pubspec.yaml`:

```yaml
# format: versionName+versionCode
version: 1.0.0+2    # current — first public release (2026-05-10)
version: 1.0.1+3    # next patch
version: 1.1.0+4    # next minor
```

The number after `+` is the versionCode. It must be strictly incremented for every AAB uploaded to Play Console, including test tracks.

---

### GitHub Actions Secrets still needed

Before CI can produce a properly signed AAB:

| Secret name               | Status          |
| ------------------------- | --------------- |
| `KEYSTORE_BASE64`         | ✅ Already added |
| `KEYSTORE_STORE_PASSWORD` | ✅ Already added |
| `KEYSTORE_KEY_PASSWORD`   | ✅ Already added |
| `KEYSTORE_KEY_ALIAS`      | ✅ Already added |

Go to: **GitHub → metra repo → Settings → Secrets and variables → Actions → New repository secret**

---

### Final checklist before hitting "Submit to Production"

- [x] `flutter analyze` → 0 issues _(2026-05-10)_
- [x] `flutter test` → 883/883 passed _(2026-05-10)_
- [x] `dart format` → 0 changes _(2026-05-10)_
- [x] Privacy policy page live — HTTP 200 _(2026-05-10)_
- [x] `network_security_config.xml` created and wired _(2026-05-10)_
- [ ] `android/key.properties` created locally with correct keystore path
- [ ] GitHub Actions secrets: add the 3 missing password/alias secrets
- [ ] `flutter build appbundle --release` succeeds locally
- [ ] Play Console developer account created ($25)
- [ ] Store listing filled (screenshots, description, icon 512×512, feature graphic 1024×500)
- [ ] Data safety section completed (health data = local only, optional E2E encrypted backup)
- [ ] Content rating questionnaire completed (Utility → PEGI 3/Everyone)
- [ ] Target audience set to 18+ (adult users)
- [ ] AAB uploaded to Internal Testing and smoke-tested on physical device
- [ ] Dead code cleaned up: `openBatteryOptimizationSettings()` + MainActivity `openSettings` handler (before next release)
- [ ] Promote to Production when ready
