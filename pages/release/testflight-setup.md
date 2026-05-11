# TestFlight Publishing — Setup Guide

This guide walks you through the one-time configuration required to publish
Mētra to TestFlight via the GitHub Actions `deploy_testflight` workflow job.
No Mac is required for most steps; a temporary Mac is only needed for one
optional path (Path A in Section 2).

---

## Prerequisites

Before starting, verify:

- [ ] Apple Developer Program membership is active (paid, not free).
- [ ] App record created in App Store Connect with bundle ID
  `com.paolosantucci.metra` and display name `Mētra`.
- [ ] At least one internal tester or internal group added under the TestFlight
  tab of the app record (required before Apple will accept builds).
- [ ] You have access to the GitHub repository Settings → Secrets and variables
  → Actions page.

---

## Section 1 — Generate an App Store Connect API Key

The workflow authenticates to App Store Connect using an API key (.p8 file),
not your Apple ID. This avoids 2FA prompts and does not require password
rotation.

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com).
2. Navigate to **Users and Access** → **Integrations** → **App Store Connect
   API**.
3. Click **Generate API Key**.
4. Name it `Metra CI`, set Role to **App Manager**.
5. Click **Generate**. The `.p8` file downloads immediately — **this is the
   only time you can download it**. Save it securely.
6. Note the **Key ID** (10 characters, e.g. `ABCD1234EF`) and **Issuer ID**
   (UUID, shown above the keys table — one per team).

Convert the `.p8` to base64 on Linux:

```bash
base64 -w0 AuthKey_ABCD1234EF.p8 > AuthKey_ABCD1234EF.p8.b64
```

You now have the values for three secrets:

| Secret | Value |
|--------|-------|
| `APP_STORE_CONNECT_API_KEY_ID` | `ABCD1234EF` (Key ID) |
| `APP_STORE_CONNECT_API_ISSUER_ID` | UUID Issuer ID from the table header |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Contents of `AuthKey_ABCD1234EF.p8.b64` |

---

## Section 2 — Generate a Distribution Certificate and Provisioning Profile

You need an Apple Distribution certificate (cert + private key, exported as a
`.p12` file) and an App Store provisioning profile (`.mobileprovision` file).

### Path A — One-time Mac access (recommended)

Use this if you can borrow a Mac or rent a cloud Mac (e.g., MacStadium, Scaleway
Apple Silicon) for 30 minutes.

**Generate the certificate:**

1. Open **Keychain Access** → menu bar **Keychain Access** → **Certificate
   Assistant** → **Request a Certificate From a Certificate Authority**.
2. Fill in your email and Common Name. Select **Saved to disk**. Save the
   `.certSigningRequest` (CSR) file.
3. In the [Apple Developer portal](https://developer.apple.com) → **Certificates,
   IDs & Profiles** → **Certificates** → **+**, choose **Apple Distribution**.
4. Upload the CSR. Download the `.cer` file. Double-click to install it in
   Keychain Access.
5. In Keychain Access, find **Apple Distribution: Your Name** under **My
   Certificates**. Right-click → **Export** → choose `.p12` format. Set a
   strong password (you will need this again).

**Convert to base64 (can be done on Linux):**

```bash
base64 -w0 dist.p12 > dist.p12.b64
```

**Generate the provisioning profile:**

1. In Apple Developer portal → **Profiles** → **+** → **App Store** (under
   Distribution).
2. Select the `com.paolosantucci.metra` App ID.
3. Select the Apple Distribution certificate you just created.
4. Name the profile (any name — the workflow uses the UUID, not the name).
5. Click **Generate**, then **Download**.

**Convert to base64:**

```bash
base64 -w0 metra_appstore.mobileprovision > metra_appstore.mobileprovision.b64
```

You now have values for:

| Secret | Value |
|--------|-------|
| `IOS_DIST_CERT_P12_BASE64` | Contents of `dist.p12.b64` |
| `IOS_DIST_CERT_PASSWORD` | Password set when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Contents of `metra_appstore.mobileprovision.b64` |

### Path B — No Mac at all (OpenSSL on Linux)

This path generates the CSR entirely on Linux. Apple's Developer portal accepts
CSR uploads regardless of operating system.

**Generate the key pair and CSR:**

```bash
# Generate a 2048-bit RSA key (Apple requires 2048 minimum)
openssl genrsa -out dist_key.pem 2048

# Generate the CSR (fill in your email and name at the prompts)
openssl req -new -key dist_key.pem -out dist.certSigningRequest \
  -subj "/emailAddress=your@email.com/CN=Metra Distribution/C=IT"
```

**Submit to Apple:**

1. In Apple Developer portal → Certificates → + → Apple Distribution.
2. Upload `dist.certSigningRequest`.
3. Download the resulting `distribution.cer`.

**Assemble the .p12:**

```bash
# Convert Apple's DER .cer to PEM
openssl x509 -inform DER -in distribution.cer -out dist_cert.pem

# Bundle key + cert into a .p12
openssl pkcs12 -export \
  -inkey dist_key.pem \
  -in dist_cert.pem \
  -out dist.p12 \
  -password pass:CHOSEN_PASSWORD
```

Replace `CHOSEN_PASSWORD` with a strong password you will save as
`IOS_DIST_CERT_PASSWORD`.

**Convert to base64:**

```bash
base64 -w0 dist.p12 > dist.p12.b64
```

The provisioning profile is generated in the Apple Developer portal exactly
as in Path A (Steps 1–5 above) — no Mac required for that step.

> **Risk note:** Path B has not been officially validated by Apple's
> documentation. The CSR format (OpenSSL defaults) should be compatible, but if
> the portal rejects the CSR, Path A is the fallback. Path A is always
> preferred when any Mac access is feasible.

---

## Section 3 — Add GitHub Secrets

In your GitHub repository: **Settings** → **Secrets and variables** → **Actions**
→ **New repository secret**.

Add each of the following:

| Secret name | Where you got it |
|-------------|-----------------|
| `IOS_DIST_CERT_P12_BASE64` | Contents of `dist.p12.b64` |
| `IOS_DIST_CERT_PASSWORD` | Password chosen during `.p12` export |
| `IOS_PROVISIONING_PROFILE_BASE64` | Contents of `metra_appstore.mobileprovision.b64` |
| `IOS_KEYCHAIN_PASSWORD` | Any strong random string (e.g. `openssl rand -base64 32`) — used for the temporary CI keychain only |
| `APP_STORE_CONNECT_API_KEY_ID` | 10-char Key ID from Section 1 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | UUID Issuer ID from Section 1 |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Contents of `AuthKey_*.p8.b64` from Section 1 |
| `IOS_DEVELOPMENT_TEAM_ID` | Your 10-char Apple Team ID (Apple Developer → Account → Membership → Team ID) |

The existing `DROPBOX_APP_KEY` secret remains unchanged.

---

## Section 4 — Tag a Release and Trigger the Build

The `deploy_testflight` job runs only on `v*` tag pushes. To trigger it:

```bash
# Ensure your local main branch is up to date
git pull --ff-only origin main

# Create an annotated tag
git tag -a v0.1.0 -m "First TestFlight build"

# Push the tag (this triggers the iOS workflow)
git push origin v0.1.0
```

Navigate to the **Actions** tab in GitHub. You will see the iOS workflow running.
Both `build_ios` (the PR smoke build) and `deploy_testflight` will run, because
the workflow `on: push: tags: ['v*']` trigger fires for tag pushes and both jobs
share the same workflow file. The `build_ios` job is harmless on a tag push;
`deploy_testflight` is the one that signs and uploads.

Wait for the `deploy_testflight` job to complete (typically 20–35 minutes on a
`macos-latest` runner, including Flutter pub get, build, and upload).

---

## Section 5 — Post-Upload Steps in App Store Connect

**Processing time:** After a successful `xcrun altool --upload-app`, the build
appears in App Store Connect → TestFlight within 5–30 minutes. Apple performs
automated checks before it is visible.

**Export Compliance:** Apple will ask whether the app uses encryption. Mētra
uses AES-256-GCM via the `cryptography` package, which is subject to US export
controls (ITSAppUsesNonExemptEncryption = YES). However, Apple provides a mass-
market software exemption under EAR §740.17(b). The standard answer for a
consumer app shipping standard encryption is:

> "Yes, the app uses encryption. The encryption is exempt under §740.17(b)(1)
> (Apple's mass-market exemption)."

To skip the interactive prompt on every TestFlight upload, add these keys to
`ios/Runner/Info.plist` (inside the root `<dict>`):

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<true/>
<key>ITSEncryptionExportComplianceCode</key>
<string>YOUR-COMPLIANCE-CODE-UUID</string>
```

Apple issues the `ITSEncryptionExportComplianceCode` UUID after you complete the
compliance questionnaire once in App Store Connect. Alternatively, if you choose
to claim the exemption and do not require an ERN, use:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

This tells Apple the app uses only standard OS encryption and is exempt without
requiring a code. Check with legal counsel if uncertain which answer applies.

**Distribute to testers:** Once the build shows as "Ready to Test", open
TestFlight → select the build → Add to Group → pick your internal test group.
Testers receive a notification in the TestFlight app.

---

## Section 6 — Troubleshooting

### Keychain unlock fails

```
security: SecKeychainUnlock <path>: The user name or passphrase you entered is not correct.
```

The `IOS_KEYCHAIN_PASSWORD` secret does not match the password used when the
keychain was created in the same step. This is a runner state issue — it should
not occur since the keychain is created and unlocked in one step. If it does,
check that the secret value has no leading/trailing whitespace.

### Profile UUID mismatch / no valid signing identity

```
error: exportArchive: No profiles for 'com.paolosantucci.metra' were found
```

The provisioning profile installed in `~/Library/MobileDevice/Provisioning
Profiles/` does not match the bundle ID or has expired. Regenerate the profile
in the Apple Developer portal (profiles expire after 1 year) and update
`IOS_PROVISIONING_PROFILE_BASE64`.

### altool 401 Unauthorized

```
altool[...]: *** Error: Unable to validate your application.
ERROR ITMS-90189: "Redundant Binary Upload"  or  401 Unauthorized
```

- Verify `APP_STORE_CONNECT_API_KEY_ID` and `APP_STORE_CONNECT_API_ISSUER_ID`
  match exactly what is shown in App Store Connect.
- Verify the `.p8` file was base64-encoded without line breaks (`base64 -w0`).
  A multi-line base64 string silently truncates on decode.
- Verify the API key has **App Manager** role, not Developer.

### Build number conflict

```
ERROR ITMS-90032: "Invalid value for key CFBundleVersion"
```

Two uploads with the same `GITHUB_RUN_NUMBER` are not possible since the run
number is unique per repository. If you see this error it means a previous
upload with that build number already reached Apple's servers (even if the CI
job later failed). Wait for the previous build to process, then re-tag with a
new patch version and push again to generate a new run number.

### p12 import fails silently / codesign hangs

If the archive step hangs without output, the most common cause is that
`security set-key-partition-list` did not run successfully. Verify the step log
shows no error. The flag `-S "apple-tool:,apple:"` (comma, no space) is
required; omitting it or using `-S apple-tool:` alone leaves codesign unable
to unlock the key.

### xcodebuild archive: "No signing certificate found" / code signing errors

The workflow passes `CODE_SIGN_STYLE=Manual`, `DEVELOPMENT_TEAM`,
`PROVISIONING_PROFILE_SPECIFIER`, and `CODE_SIGN_IDENTITY="Apple Distribution"`
as command-line arguments to `xcodebuild archive`. These override the committed
`project.pbxproj`, so the file does not need to be patched. If signing still
fails, verify in order:

1. The keychain step ran successfully and the distribution cert was imported.
   Look for the line `1 identity imported.` in the
   "Create ephemeral keychain and import certificate" step.
2. The provisioning profile UUID was extracted and exported. The
   "Install provisioning profile" step should set `PROFILE_UUID` in
   `GITHUB_ENV` (the value is masked in logs).
3. The `IOS_DEVELOPMENT_TEAM_ID` secret matches the team that signed the
   distribution certificate (10-char alphanumeric).
4. The cert in `IOS_DIST_CERT_P12_BASE64` is an **Apple Distribution**
   certificate (not Apple Development). The workflow hardcodes
   `CODE_SIGN_IDENTITY="Apple Distribution"`, so a development cert will
   not match.
