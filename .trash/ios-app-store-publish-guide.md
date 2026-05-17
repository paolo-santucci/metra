> **⚠ ARCHIVED — NOT current truth.** This document captured state at planning time. Current behavior may have diverged. Consult the current codebase or active spec docs.

# iOS App Store — Pre-Release Audit & Publishing Guide

**App:** Métra 1.0.0  
**Audited:** 2026-05-10  
**Last updated:** 2026-05-10 (B8b/C13/C14 resolved; A6/C15 verified on CI run 25629240363 — tag v1.0.0-rc1, full green, uploaded to TestFlight)  
**Deployment target:** iOS 13.0 · Bundle ID: `com.paolosantucci.metra`

---

## Pre-Release Audit

The CI pipeline (`ios.yml`) already handles signing, archiving, and TestFlight upload on `v*` tags.  
The items below audit the *project state* — what must be true before any upload reaches App Review.

---

### A — Project Structure & Build

| #   | Item                                                                                                                                                                                            | Result          |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| A1  | Single `Runner.xcworkspace`; no dangling target references                                                                                                                                      | ✅ PASS          |
| A2  | Release config: `compileBitcode=false`, `uploadBitcode=false` in `ExportOptions.plist.template` — correct post-Xcode 14                                                                         | ✅ PASS          |
| A3  | Bundle ID `com.paolosantucci.metra` consistent across `project.pbxproj`, `ExportOptions.plist.template`, and `Info.plist` (`$(PRODUCT_BUNDLE_IDENTIFIER)`)                                      | ✅ PASS          |
| A4  | `CFBundleShortVersionString` = `$(FLUTTER_BUILD_NAME)` (resolves to `1.0.0` from `pubspec.yaml`); `CFBundleVersion` = `$(FLUTTER_BUILD_NUMBER)` (set to `$GITHUB_RUN_NUMBER` by CI on tag runs) | ✅ PASS          |
| A5  | No TODO/FIXME/HACK in `ios/` Swift or ObjC sources                                                                                                                                              | ✅ PASS          |
| A6  | `xcodebuild` warnings — Runner target: **0 warnings from Métra's own code**. Third-party CocoaPods warnings (all non-blocking): `flutter_web_auth_2` (5 — deprecated `SFAuthenticationError`/`keyWindow`), `share_plus` (1 — deprecated `keyWindow`), `flutter_local_notifications` (1 — incomplete ObjC impl), `SwiftyGif` (1), `SQLCipher/sqlite3.c` (7 — integer precision). Upstream pod issues; not App Review risks. Verified on CI run 25629240363. | ✅ PASS (CI verified) |

---

### B — Info.plist & Entitlements

| # | Item | Result |
|---|------|--------|
| B7 | `UIRequiredDeviceCapabilities` — not declared; correct for an app with no special hardware requirements | ✅ N/A |
| B8 | `NSPhotoLibraryUsageDescription` present; text is specific: "file picker includes the photo library as a source option. Métra does not access, read, or store your photos." | ✅ PASS |
| B8b | `NSUserNotificationsUsageDescription` — **not a recognized Apple plist key**; removed from `ios/Runner/Info.plist`. Local notification permission is requested programmatically via `UNUserNotificationCenter.requestAuthorization()` at runtime; no plist key exists or is checked by Apple for this purpose. | ✅ FIXED 2026-05-10 |
| B9 | `LSApplicationQueriesSchemes` — not declared; correct (Métra is the OAuth *receiver*, never the caller of `canOpenURL`) | ✅ N/A |
| B10 | No `.entitlements` file — correct; the app uses no capabilities requiring entitlements (no Push Notifications, no Sign in with Apple, no HealthKit, no Associated Domains) | ✅ N/A |
| B11 | Associated Domains / Push Notifications / HealthKit / Sign in with Apple — none declared and none used | ✅ N/A |
| B12 | No `NSAllowsArbitraryLoads` in Info.plist; App Transport Security uses system defaults (HTTPS only) | ✅ PASS |

---

### C — Privacy & Compliance

| # | Item | Result |
|---|------|--------|
| C13 | **`PrivacyInfo.xcprivacy`** — created at `ios/Runner/PrivacyInfo.xcprivacy` and wired into Runner target (PBXFileReference + PBXBuildFile + PBXGroup + PBXResourcesBuildPhase). Declares four Required Reason API categories: `UserDefaults` (CA92.1), file timestamps (C617.1), disk space (E174.1), system boot time (35F9.1). | ✅ FIXED 2026-05-10 |
| C14 | `NSPrivacyTracking = false`, `NSPrivacyTrackingDomains = []` — declared in `PrivacyInfo.xcprivacy`; correct (no tracking, no ATT prompt needed) | ✅ FIXED 2026-05-10 |
| C15 | Third-party SDK privacy manifests — CocoaPods compiled dedicated privacy-bundle targets for all plugins with Required Reason API usage, confirmed in xcodebuild archive log (CI run 25629240363): `url_launcher_ios` (PrivacyInfo.xcprivacy bundled from pub cache), `share_plus`, `flutter_local_notifications`, `file_picker`. `flutter_secure_storage` uses iOS Keychain APIs (`SecItem*`), not Required Reason APIs, so no separate manifest is needed. `SQLCipher`/Drift file and disk APIs are covered by Métra's own `PrivacyInfo.xcprivacy` (C617.1, E174.1). | ✅ PASS (CI verified) |
| C16 | `ITSAppUsesNonExemptEncryption = false` declared in Info.plist with explanatory comment (AES-256 for local data protection only, qualifies for BIS §740.17(b)(1)) | ✅ PASS |

---

### D — Assets & UI Quality

| # | Item | Result |
|---|------|--------|
| D17 | `AppIcon.appiconset/Contents.json` declares single 1024×1024 for Light, Dark, and Tinted appearances — correct for Xcode 15+ single-size icon mode. CI `assetutil` validation confirms icon compiles into Assets.car. | ✅ PASS |
| D18 | `LaunchScreen.storyboard` present | ✅ PASS |
| D19 | `LaunchImage.imageset` has @1x/@2x/@3x variants | ✅ PASS |
| D20 | No `UIUserInterfaceStyle` override in Info.plist → system appearance follows the OS; Flutter app must support both Light and Dark — confirmed by design system | ✅ PASS |
| D21 | All user-facing strings via Flutter `l10n` / `AppLocalizations`; no hardcoded Italian/English literals in UI | ✅ PASS |

---

### E — Accessibility & HIG

| #       | Item                                                                                                                                                                                        | Result              |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| E22     | Accessibility Inspector audit — cannot run from Linux; must be run on the TestFlight build before App Store submission                                                                      | ⚠️ VERIFY ON DEVICE |
| E23–E26 | Semantic labels, Dynamic Type, color contrast, 44×44pt touch targets — enforced by CLAUDE.md project principles and E2E checklist item 8 (VoiceOver logging flow completable without sight) | ⚠️ VERIFY ON DEVICE |
| E27     | Navigation: portrait-only (`UIInterfaceOrientationPortrait`), no tab bar > 5 items, standard back gesture unblocked                                                                         | ✅ PASS              |

---

### F — Performance & Stability

| # | Item | Result |
|---|------|--------|
| F28–F30 | Instruments (Time Profiler, Leaks, Memory) — cannot run from Linux; verify on TestFlight build before App Store promotion | ⚠️ VERIFY ON DEVICE |
| F31 | No force-unwraps in Swift native files (`AppDelegate.swift`, `SceneDelegate.swift` are clean). Flutter Dart layer is covered by `flutter analyze`. | ✅ PASS (Swift layer) |
| F32 | No prior uploads → no crash logs in Organizer yet | ✅ N/A (first upload) |

---

### G — App Review Guidelines

| # | Item | Result |
|---|------|--------|
| G33 | No `performSelector` / underscore-prefixed private API in Swift sources | ✅ PASS |
| G34 | No in-app purchases, no external payment links | ✅ N/A |
| G35 | No social login required → Sign in with Apple not required (Guideline 4.8) | ✅ N/A |
| G36 | No placeholder content, lorem ipsum, or test data in code paths visible at runtime | ✅ PASS |
| G37 | No `UIBackgroundModes` declared in Info.plist; no background modes used | ✅ N/A |
| G38 | No App Tracking Transparency prompt needed — `NSPrivacyTracking = false`, no tracking | ✅ N/A |

---

### Audit Summary

| | Count |
|---|---|
| ✅ PASS | 23 |
| ⚠️ Must verify on device | 4 |
| ❌ BLOCKING FAIL | 0 |

**No hard blockers.** B8b, C13, C14 resolved 2026-05-10. A6 and C15 verified green on CI run 25629240363 (tag v1.0.0-rc1, full archive + TestFlight upload). Remaining 4 items require a physical iPhone — deferred to TestFlight smoke test session.

---

## Code Changes — Resolved

All code-level fixes have been applied (2026-05-10). This section is kept as an audit log.

### Fix 1 — `PrivacyInfo.xcprivacy` ✅ RESOLVED 2026-05-10

Created `ios/Runner/PrivacyInfo.xcprivacy` declaring four Required Reason API categories
(`UserDefaults` CA92.1, file timestamps C617.1, disk space E174.1, system boot time 35F9.1)
with `NSPrivacyTracking = false` and empty tracking domains.

Wired into `project.pbxproj` via four edits: new `PBXFileReference`
(`A1B2C3D40000000000000001`), new `PBXBuildFile` (`A1B2C3D40000000000000002`),
Runner group children entry, and Runner `PBXResourcesBuildPhase` files entry.

### Fix 2 — Spurious plist key removed ✅ RESOLVED 2026-05-10

Removed `NSUserNotificationsUsageDescription` from `ios/Runner/Info.plist`.
Not a recognized Apple key; local notification permission is requested programmatically
via `UNUserNotificationCenter.requestAuthorization()` at runtime.

---

## Step-by-Step: Publishing to the App Store

### Step 0 — Pre-submission checklist (do these first)

- [ ] **0a. Apple Developer Program membership** — enroll at [developer.apple.com/enroll](https://developer.apple.com/enroll). Cost: €99/year. Required before any upload. Entity type (Individual vs. Organisation) appears on the App Store and cannot be changed retroactively.
- [ ] **0b. Create the PrivacyInfo.xcprivacy file and wire it into Xcode** — see Fix 1 above. No upload is accepted without it.
- [ ] **0c. Remove `NSUserNotificationsUsageDescription` from Info.plist** — see Fix 2 above.
- [ ] **0d. Privacy Policy page is live** — publish at `https://paolosantucci.github.io/metra/privacy` (mirrors Android). Required for any app; required for health-adjacent apps by App Review Guideline 5.1.1.
- [ ] **0e. Verify `flutter analyze` → 0 issues on the iOS build path**.

---

### Step 1 — Generate signing materials (one-time, Apple Developer portal)

Go to [developer.apple.com/account](https://developer.apple.com/account):

| What | Where | Notes |
|---|---|---|
| **Distribution Certificate** | Certificates → + → Apple Distribution | Export as `.p12` with a strong password — this becomes `IOS_DIST_CERT_PASSWORD` |
| **App Store Provisioning Profile** | Profiles → + → App Store Distribution | Select bundle ID `com.paolosantucci.metra` + the Distribution cert → download `.mobileprovision` |
| **App Store Connect API Key** | App Store Connect → Users & Access → Integrations → App Store Connect API → + | Role: **App Manager** minimum. Download the `.p8` once only. Note the **Key ID** and **Issuer ID**. |

---

### Step 2 — Populate GitHub Secrets

Go to **GitHub → metra repo → Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret name | What it contains | How to produce it |
|---|---|---|
| `IOS_DIST_CERT_P12_BASE64` | Distribution cert `.p12`, base64-encoded | `base64 -w 0 dist.p12` |
| `IOS_DIST_CERT_PASSWORD` | Password chosen when exporting `.p12` | The password you typed |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store `.mobileprovision`, base64-encoded | `base64 -w 0 profile.mobileprovision` |
| `IOS_KEYCHAIN_PASSWORD` | Random string for the ephemeral CI keychain | `openssl rand -hex 16` |
| `IOS_DEVELOPMENT_TEAM_ID` | 10-character Apple Team ID | Developer portal → Account → Team ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `.p8` file, base64-encoded | `base64 -w 0 AuthKey_XXXX.p8` |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID (10 chars, from portal) | App Store Connect → API Keys |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID (UUID, from portal) | App Store Connect → API Keys |
| `DROPBOX_APP_KEY` | Already in use from Android CI | Already done ✅ |

---

### Step 3 — Create the app record in App Store Connect

Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**:

| Field | Value |
|---|---|
| Platform | iOS |
| Name | `Mētra` (with macron ē — verify Apple accepts the Unicode character; if rejected, use `Metra`) |
| Primary language | Italian |
| Bundle ID | `com.paolosantucci.metra` — must match exactly |
| SKU | `metra-ios-2026` (arbitrary internal identifier, not shown to users) |

---

### Step 4 — Complete the App Store listing

Go to **App Store → 1.0 Prepare for Submission**:

| Field | Content |
|---|---|
| **Short description** | `Diario del ciclo mestruale — privato, locale, libero.` (30 chars) |
| **Full description** | ≤4,000 chars. Italian primary. Emphasise local-first, no cloud server, no telemetry, open source GPL-3.0. |
| **Keywords** | ≤100 chars; include: ciclo mestruale, periodo, salute, privato, locale, tracking |
| **Support URL** | `https://github.com/paolosantucci/metra` (or the GitHub Pages URL) |
| **Privacy Policy URL** | `https://paolosantucci.github.io/metra/privacy` |
| **App icon** | Sourced from the asset catalog — no separate upload required (Apple uses the icon from the IPA) |
| **Screenshots** | Minimum: one set for 6.9" display (iPhone 16 Pro Max — 1320×2868 px). Optional: 6.1" (1179×2556 px). Generate from a physical iPhone running the TestFlight build, or from Xcode Simulator via a borrowed Mac. |

> **Tip:** Screenshots for a 6.9" device are mandatory as of Xcode 15 guidelines. If you only have a smaller device, use Xcode Simulator on a Mac (or the macOS GitHub Actions runner in a debug session with `tmate`) to capture them.

---

### Step 5 — Age Rating questionnaire

Go to **App Information → Age Rating → Edit**. Fill the questionnaire:

- Cartoon or Fantasy Violence → None
- Realistic Violence → None
- Sexual Content → None
- Profanity → None
- Alcohol, Tobacco → None
- Contests → None
- Horror → None
- Medical/Treatment Information → **Infrequent/Mild** (menstrual health data entry)
- User Generated Content → None

Expected result: **4+**

---

### Step 6 — App Privacy questionnaire

Go to **App Privacy → Get Started**. Métra's local-first design makes this straightforward:

**Does your app collect data?**  
→ **Yes** — the app stores menstrual cycle entries, symptoms, and flow data **on the device only**.

**Data type: Health & Fitness → Health Info** (cycle dates, symptoms, flow intensity)

| Question | Answer |
|---|---|
| Is this data used to track users? | **No** |
| Is this data linked to the user's identity? | **No** (stored only on device, never uploaded to your servers) |
| Is this data collected? | **No** — data stays on device; you as developer never receive it |

**Optional cloud backup:**  
User-initiated E2E-encrypted backup to Dropbox / OneDrive — encrypted on-device before upload; you never hold the key. Declare:

> "Health data is optionally backed up by the user to their own cloud storage account. Data is encrypted end-to-end on the device before upload. The developer has no access to the data or the encryption key."

---

### Step 7 — Export Compliance

`ITSAppUsesNonExemptEncryption = false` is already declared in `Info.plist`. This tells Apple that Métra's encryption (AES-256 for local storage) qualifies for the BIS License Exception ENC §740.17(b)(1) — no export compliance documentation is needed. The App Store Connect questionnaire will pre-fill "No" based on this key.

---

### Step 8 — Push the tag to trigger the CI build

```bash
# In pubspec.yaml: confirm version is 1.0.0 (no build-number suffix needed;
# CI uses GITHUB_RUN_NUMBER as CFBundleVersion automatically)

git tag v1.0.0
git push origin v1.0.0
```

This triggers the `deploy_testflight` job in `ios.yml`, which:
1. Installs the distribution certificate into an ephemeral keychain.
2. Installs the provisioning profile.
3. Decodes the App Store Connect API key.
4. Builds `flutter build ios --release --no-codesign`.
5. Patches Runner target signing via the `xcodeproj` Ruby gem.
6. `xcodebuild archive` → `xcodebuild -exportArchive`.
7. Validates the IPA (icon + Info.plist sanity check).
8. Uploads via `xcrun altool --upload-app`.

**Processing time:** Apple takes 15–60 minutes to process the build before it appears in TestFlight.

---

### Step 9 — TestFlight smoke test (mandatory before App Store promotion)

Once the build is processed, install it on a physical iPhone via TestFlight and verify:

| # | Test | Validates |
|---|---|---|
| I-1 | Cupertino Ripristina dialog renders correctly | parity fix from rc17 |
| I-2 | Backup → enter passphrase → tap "Backup again" → no second passphrase prompt | passphrase caching fix |
| I-3 | Lock screen → auto-backup triggers without unlock | iOS Keychain `first_unlock` fix |
| I-4 | Dropbox OAuth: tap "Authorize Dropbox" → Safari opens → auth completes → callback returns | OAuth URL scheme |
| I-5 | Notifications: schedule a reminder → receive it on time | notification scheduling |
| I-6 | Dynamic Type 200%: calendar and daily entry screens — no truncation | accessibility |
| I-7 | VoiceOver: complete a cycle log entry without sight | accessibility E2E |
| I-8 | Open the app's SQLite file in DB Browser for SQLite without the key → fails | SQLCipher encryption |

---

### Step 10 — Submit for App Review

When the TestFlight build passes smoke tests:

1. In App Store Connect → your app → **App Store** tab → **1.0 Prepare for Submission**.
2. Select the TestFlight build under **Build**.
3. Confirm all metadata, screenshots, privacy data, age rating are complete.
4. Click **Add for Review** → **Submit to App Review**.

**Review time:** 24–72 hours for first submissions. Subsequent updates are typically reviewed in hours.

If rejected, Apple will send an email with the specific guideline(s) cited. Address each point and resubmit — do not push a new tag until the rejection is resolved; resubmit the same build from App Store Connect if it is a metadata/policy issue only.

---

### Version-bumping rule for future updates

```yaml
# pubspec.yaml — format: versionName (no build number; CI uses GITHUB_RUN_NUMBER)
version: 1.0.0    # current — first public release
version: 1.0.1    # next patch
version: 1.1.0    # next minor
```

The `CFBundleVersion` (build number shown in Xcode / TestFlight) is set to `$GITHUB_RUN_NUMBER` by the CI. It is always strictly increasing across tag runs and therefore always valid. You never need to manage it manually.

> **Rule:** `CFBundleShortVersionString` (the marketing version) must increase with every App Store release. `CFBundleVersion` must increase with every upload, including rejected ones — the CI handles this automatically.

---

### Final checklist before hitting "Submit to App Review"

- [x] `PrivacyInfo.xcprivacy` created, added to Xcode Runner target, committed _(2026-05-10)_
- [x] `NSUserNotificationsUsageDescription` removed from Info.plist _(2026-05-10)_
- [ ] Apple Developer Program membership active (€99/year)
- [ ] Distribution certificate + App Store provisioning profile generated
- [ ] All 8 GitHub Secrets for iOS CI populated
- [ ] App Store Connect record created (bundle ID `com.paolosantucci.metra`)
- [ ] Privacy Policy live at `https://paolosantucci.github.io/metra/privacy`
- [ ] Store listing complete: description, keywords, support URL, privacy policy URL
- [ ] Screenshots captured for 6.9" device (1320×2868 px) — mandatory
- [ ] Age Rating questionnaire complete (expected: 4+)
- [ ] App Privacy questionnaire complete (health data, local-only, no tracking)
- [ ] Export Compliance auto-resolved via `ITSAppUsesNonExemptEncryption = false` ✅
- [ ] `git tag v1.0.0 && git push origin v1.0.0` triggers green CI run
- [ ] TestFlight build passes all 8 smoke tests (I-1 through I-8) on physical iPhone
- [ ] Build selected in App Store Connect → submitted for review
