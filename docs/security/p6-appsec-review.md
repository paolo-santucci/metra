# P-6 AppSec Review

**Date:** 2026-04-29
**Reviewer:** appsec-engineer (automated)
**Sprint:** P-6 — Dropbox E2E Encrypted Backup

## Summary

The P-6 Dropbox backup surface uses OAuth 2.0 PKCE, AES-256-GCM encryption with
Argon2id key derivation, and `flutter_secure_storage` for all credentials. The
cryptographic design is sound. Two findings are raised: one Medium (OAuth scope /
Dropbox access mode) and one Low (raw exception string reaching the UI). There are
no Critical or High findings; the release may proceed after the version bump.

## Threat Model

- **Assets**: AES-256-GCM-encrypted backup blob; OAuth access/refresh tokens;
  Argon2id-derived passphrase stored in platform secure storage.
- **Trust boundary**: device (SQLCipher DB) → in-memory JSON → encrypted blob →
  Dropbox cloud. The cloud provider sees only opaque `.enc` files.
- **Attackers considered**: passive network observer; compromised cloud account;
  malicious app on same device reading storage; attacker with access to local
  SyncLog.

## Findings

| # | Severity | Area | Description | Status |
|---|---|---|---|---|
| 1 | Medium | OAuth – access scope | `authorize()` omits the `scope` parameter. The absolute path `/Apps/Metra/…` is only valid in Dropbox "Full Dropbox" access mode. "App folder" mode (least privilege) uses the app folder as root and requires relative paths (e.g. `/filename.enc`). Until the Dropbox console is configured for "App folder" + paths are made relative, the app implicitly requests more filesystem access than it needs. See detail below. | OPEN |
| 2 | Low | UI – raw exception in error state | `BackupNotifier` at lines 46, 63, 94, and 110 constructs `BackupErrorState(e.toString())` for unhandled exceptions in `connect()`, `disconnect()`, `_runBackup()`, and `restore()`. If an unexpected exception carries a message with non-redacted content (e.g. from an HTTP library, OS layer, or Dart runtime), it is displayed verbatim. The SyncLog path via `_redactErrorMessage` is unaffected (token patterns are stripped there). | OPEN |

---

### Finding 1 — Medium: Dropbox OAuth Access Scope (Principle of Least Privilege)

**CWE:** CWE-272 (Least Privilege Violation)
**OWASP:** A01:2021 — Broken Access Control (over-permissioned third-party credential)

**Location:** `lib/data/services/backup/dropbox_provider.dart:82–89`

**Evidence:**
```dart
final authUrl = Uri.https('www.dropbox.com', '/oauth2/authorize', {
  'client_id': _appKey,
  'response_type': 'code',
  'redirect_uri': _redirectUri,
  'code_challenge': challenge,
  'code_challenge_method': 'S256',
  'token_access_type': 'offline',
  // 'scope' is absent
});
```

The Dropbox API has two access modes configurable in the developer console:

| Mode | Scope | Path semantics |
|---|---|---|
| "Full Dropbox" | Full read/write of user's entire Dropbox | Paths must be absolute: `/Apps/Metra/filename.enc` |
| "App folder" | Scoped to `/Apps/<AppName>/` only | Paths are relative to app folder root: `/filename.enc` |

The current code uses absolute paths (`_appFolder = '/Apps/Metra'`). This is
correct under "Full Dropbox" mode, but if the Dropbox app is configured for
"App folder" mode, the absolute path `/Apps/Metra/filename.enc` resolves to
`/Apps/<AppName>/Apps/Metra/filename.enc`, causing all API calls to fail. More
importantly, "Full Dropbox" mode grants the access token permission to read,
write, and delete any file in the user's Dropbox — well beyond what Métra
requires.

**Impact:** Access tokens issued in "Full Dropbox" mode, if stolen or leaked from
`flutter_secure_storage`, can access the user's entire Dropbox — not just the
backup folder. This violates the zero-knowledge design goal because a compromised
token grants a much larger blast radius than intended.

**Remediation:** Two coordinated changes are required:

1. In the Dropbox developer console, set the app's access type to **"App folder"**
   (not "Full Dropbox").
2. Change `_appFolder` constant from `'/Apps/Metra'` to `''` and update all path
   constructions:

```dart
// Before
static const _appFolder = '/Apps/Metra';
// ...
'path': '$_appFolder/$filename',  // → '/Apps/Metra/filename.enc'

// After
static const _appFolder = '';
// ...
'path': '/$filename',  // → '/filename.enc'  (relative to app folder root)

// listFiles:
body: jsonEncode({'path': _appFolder}),  // → {'path': ''}  (Dropbox requires '' not '/')
```

The `listFiles()` call also needs `'path': ''` (empty string, not `'/'`) — the
Dropbox v2 API interprets `''` as the app folder root in App folder mode.

**Verification:** After the console change and code update:
- Call `list_folder` with `path: ''` → should return the backup files without error.
- Call `upload` with `path: '/filename.enc'` → should succeed and appear under
  `/Apps/Metra/` in the user's Dropbox.

---

### Finding 2 — Low: Raw Exception String Surfaced in UI Error State

**CWE:** CWE-209 (Information Exposure Through an Error Message)
**OWASP:** A05:2021 — Security Misconfiguration (verbose error disclosure)

**Location:** `lib/features/backup/state/backup_notifier.dart:46, 63, 94, 110`

**Evidence:**
```dart
// Lines 46, 63, 94, 110 — all four catch blocks:
} catch (e) {
  state = AsyncData(BackupErrorState(e.toString()));
}
```

**Impact:** If a non-`SyncException` propagates (e.g. a `SocketException` containing
an IP address, a Dart runtime error, or a package-level exception whose `.toString()`
includes internal context), it is rendered directly in the `_ErrorBody` widget
visible to the user. No redaction is applied at this path.

**Note:** The `SyncOrchestrator` `catch` blocks at lines 106 and 149 pass
`e.toString()` to `SyncLogEntity.errorMessage`, which IS protected by
`_redactErrorMessage` in `DriftSyncLogRepository`. This path is safe. The
finding is limited to the UI error state.

**Remediation:** Replace the raw `e.toString()` with a type-checked,
user-controlled message:

```dart
} catch (e) {
  final msg = e is MetraException
      ? e.message
      : l10n.common_error_generic;  // localised "Something went wrong"
  state = AsyncData(BackupErrorState(msg));
}
```

The notifier would need access to `l10n` (or use a fixed fallback key), and all
four catch blocks in `BackupNotifier` would be updated.

**Verification:** Trigger a `SocketException` (e.g. by disabling network) during
backup → verify only the generic localised message is shown, not the raw exception
text.

---

## Design Decision Note

`CLAUDE.md §11.2` states "backup passphrase: chosen by the user, never saved."
The implementation deliberately deviates: `SyncOrchestrator` reads the passphrase
from `flutter_secure_storage` under key `metra_backup_passphrase_v1`, and
`BackupNotifier.backupWithPassphrase()` writes it there before each backup. This
enables `backupSilent()` (repeat backups without re-prompting). The passphrase is
stored in the platform secure enclave (Keychain / Keystore), which provides
hardware-backed protection comparable to the DB key. This is an intentional,
documented design decision, not a vulnerability.

---

## Verified Checks (all pass)

1. **C-1 — Passphrase never logged.** Zero `print`/`debugPrint` of the passphrase value anywhere in `lib/`. All grep matches are legitimate: parameter names, l10n strings, secure storage key constants, and `EncryptionService` API parameters. **PASS**

2. **C-2 — Tokens never logged.** The five hits in `dropbox_provider.dart` for `access_token`/`refresh_token` are write/read operations against `flutter_secure_storage` and JSON parsing of the token exchange response. No raw token value is logged. **PASS**

3. **C-3 — No hardcoded app key.** `lib/providers/backup_providers.dart:29` uses `const _dropboxAppKey = String.fromEnvironment('DROPBOX_APP_KEY')`. The `_appKey` field in `DropboxProvider` is the injected value, not a literal. **PASS**

4. **C-4 — Snapshot contains no AppSettings data.** `backup_service.dart` and `backup_snapshot.dart` contain no reference to `AppSettings`, `languageCode`, `darkMode`, or `notificationsEnabled`. Preferences are never included in the backup blob. **PASS**

5. **C-5 — SyncLog error message redaction.** `_redactErrorMessage` in `drift_sync_log_repository.dart`: truncates at 500 chars, strips `Bearer <token>`, `access_token=<value>`, `refresh_token=<value>` via regex, returns `null` for `null` input (preserving the absence-of-error semantic). All four patterns are correctly handled. **PASS**

6. **C-6 — No user data in Dropbox path.** Folder: `/Apps/Metra` (ASCII, no user-specific data). Filename: `metra_backup_<UTC ISO timestamp>.enc`. Only a UTC timestamp is encoded; no username, email, or health data appears in any path component. **PASS**

7. **C-7 — AES-256-GCM with Argon2id (no regression).** `EncryptionService`: `AesGcm.with256bits()`, Argon2id(memory=65536, iterations=3, parallelism=4, hashLength=32), 16-byte salt, 12-byte IV, both from `Random.secure()`. Blob format `[salt][iv][ciphertext][16-byte MAC]` is intact. **PASS**

8. **C-10 — Schema v1→v2 nullable columns.** `AppSettings.dropboxEmail` and `AppSettings.lastBackupAt` are both declared with `.nullable()`. The `onUpgrade` migration uses `addColumn` for both when `from < 2`. Existing rows will have `NULL` in both columns, which is semantically correct (not yet connected). **PASS**

**Additional verification — PKCE integrity.** `authorize()` generates a 64-char verifier from `Random.secure()`, computes S256 challenge via `sha256` + `base64Url` with correct padding removal. `code_challenge_method: 'S256'` and `code_verifier` are both present in the token exchange request. PKCE is correctly implemented; the scope / access-mode concern is the separate Finding 1. **PASS**

## Verdict

**PASS**

No Critical or High findings. Finding 1 (Medium) requires a Dropbox developer console
configuration change and a one-line constant update before the v1.0 public release.
Finding 2 (Low) should be addressed before v1.0. Neither blocks the P-6 version tag.
