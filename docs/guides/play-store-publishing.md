<!-- ======================================================================
     INTERNAL DEVELOPER GUIDE — NOT FOR PUBLICATION
     This file is not published to the GitHub Pages site (verified: it
     returns 404). It contains Play Console click-paths, service-account
     provisioning and CI secret rotation procedures intended for the solo
     maintainer only.
     ====================================================================== -->

# Play Store Publishing — Internal Guide

**Audience:** Solo maintainer (Fedora Linux distrobox, no local Mac, Android builds via GitHub Actions).

**Purpose:** Explain exactly what is already wired on GitHub, what is missing, and how to run `.github/workflows/android-play.yml` to push a signed AAB to a Play track (default: **internal testing**).

**Workflow:** `.github/workflows/android-play.yml` · **Guard tests:** `test/ci/play_publish_workflow_test.dart`

---

## 1. What is already in place

| Piece | Where | Status |
| --- | --- | --- |
| Release keystore (base64) | `secrets.KEYSTORE_BASE64` | ✅ set 2026-05-10 |
| Store / key password, alias | `secrets.KEYSTORE_STORE_PASSWORD`, `KEYSTORE_KEY_PASSWORD`, `KEYSTORE_KEY_ALIAS` | ✅ set 2026-05-10 |
| Signed AAB build | `android.yml` (artifact `release-aab`) | ✅ green on `main` |
| Application id | `com.paolosantucci.metraapp` in `android/app/build.gradle.kts` | ✅ |
| Android version | `versionCode` / `versionName` pinned in `android/app/build.gradle.kts` | ✅ independent of `pubspec.yaml` |
| OAuth dart-defines | `secrets.DROPBOX_APP_KEY`, `GOOGLE_OAUTH_CLIENT_ID` | ✅ |
| Upload key registered with Play | upload_cert.der downloaded from Play Console | ✅ App Signing enrolled |

**The one thing that is missing on GitHub: a Google Play Developer API credential.** Everything else exists.

## 2. The missing piece — service account

### 2.1 Google Cloud project

1. <https://console.cloud.google.com> → create (or reuse) a project, e.g. `metra-play-publisher`.
2. **APIs & Services → Library → "Google Play Android Developer API" → Enable.**

### 2.2 Service account + JSON key

1. **IAM & Admin → Service accounts → Create service account.** Name: `play-publisher`. No project roles needed (Play permissions are granted in step 2.3, not in GCP).
2. Open the account → **Keys → Add key → Create new key → JSON**.
3. Download the `.json` once. This file is the credential; it is not recoverable, only replaceable.

### 2.3 Grant it access in Play Console

1. <https://play.google.com/console> → **Users and permissions** → **Invite new users**.
2. Email: the service account address (`play-publisher@<project>.iam.gserviceaccount.com`).
3. **App permissions** → add `Métra` (`com.paolosantucci.metraapp`).
4. Enable, at minimum:
   - *Releases → Release to testing tracks* (internal, closed, open)
   - *Releases → Release to production* — only if you intend to dispatch the `production` track from CI
   - *App information → View app information* (needed to read the app state)
5. Leave *Admin* off. The service account needs to publish, not to administer the account.

### 2.4 Store it as a GitHub secret

```bash
gh secret set PLAY_SERVICE_ACCOUNT_JSON < ~/path/to/play-publisher.json
```

Paste the **entire JSON file**, not a base64 blob and not just the client email.

Verify:

```bash
gh secret list | grep PLAY
```

## 3. Running a publish

```bash
# Internal testing track — the usual case. No review, testers see it in minutes.
gh workflow run android-play.yml -f track=internal -f status=completed

# Stage without releasing (uploaded, nothing goes live on the track)
gh workflow run android-play.yml -f track=internal -f status=draft
```

Or: **Actions → Android Play Publish → Run workflow**.

The run builds the AAB itself (does not reuse `android.yml`'s artifact), verifies it with `jarsigner`, uploads it, and writes a summary with track, status, package and commit.

Pull requests and `main` pushes **never** trigger it. There is no tag trigger on purpose: `v*` means "upload iOS to TestFlight" (`ios.yml`), and Android must not piggyback on it.

## 4. Gotchas that will bite

**`versionCode` is not bumped by CI.** It is pinned in `android/app/build.gradle.kts`. Re-running the workflow against the same code fails with *"Version code N has already been used"*. Bump `versionCode` by +1 (and `versionName` when the release changes) in its own commit before dispatching. This is deliberate: it keeps the published number visible in the diff rather than in a workflow variable.

**The upload key must be the one Play knows.** `metra-release.keystore` must be the key pair behind `upload_cert.der`. Verify before blaming the workflow:

```bash
keytool -printcert -file upload_cert.der
keytool -list -v -keystore ~/path/to/metra-release.keystore -alias metra
```

The `SHA256` fingerprints must match.

**The very first AAB of an app must be uploaded through the Play Console UI.** The API cannot create the initial release of a brand-new listing. Métra is already past that point (closed testing exists), so this only matters if the listing is ever recreated.

**Tracks are not interchangeable.** `internal` and `alpha`/`beta` (closed/open testing) skip review; `production` does not, and a rejected production release blocks nothing else but does not go live. Dispatch `production` only after the manual E2E gate in `STATUS.yaml` (`OQ-QA-05` Drive round-trip) and with the privacy-policy URL live.

**A `draft` status is not a safety net for production.** It stages the release in the Console; promoting it is still a separate human action there.

**Debug signing is the failure mode the preflight exists for.** Without `key.properties`, `build.gradle.kts` falls back to the Android debug key (`android/app/build.gradle.kts:55-59`). Play then rejects the upload with a certificate mismatch that reads like a Play-side problem. The preflight refuses to start instead.

## 5. Rotating or losing the credential

- **Service account key compromised:** create a new JSON key for the same service account, replace the secret, then delete the old key in GCP. No Play Console action needed — permissions are attached to the service account, not the key.
- **Service account revoked in Play Console by accident:** re-invite the same address; permissions do not return automatically.
- **Upload keystore lost:** you cannot recover it. Play App Signing lets you request an *upload key reset* in Play Console (`App integrity → Upload key certificate → Request upload key reset`) — this is the only reason the split between upload key and app signing key exists. The app signing key itself stays with Google and is never lost.

## 6. Verifying a publish

```bash
gh run list --workflow=android-play.yml --limit 5
gh run view <run-id> --log | tail -40
```

Then Play Console → **Testing → Internal testing**: the release appears with the `versionCode` reported in the workflow log, and the testers list plus opt-in URL are unchanged.
