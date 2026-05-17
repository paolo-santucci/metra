# Consolidated Assessment — Pre-release fixes (Android + iOS)

**Date**: 2026-05-09
**Source clusters**: A (UI), B (notifications), C (Dropbox OAuth), D (backup password)
**Total findings**: 20 (0 critical, 7 high, 4 medium, 9 low)

---

## Cross-module concerns

### CC-1 — Backup module shared by clusters C and D
`lib/features/backup/state/backup_notifier.dart` is touched by both Issue #3 (Dropbox connection) and Issue #5 (passphrase caching). The Dropbox fix (BUG-C04) and the passphrase-cache fix (BUG-D01) both modify the same `connect()` / `_handleBackup` call paths. **Sequential ownership in the build phase to avoid merge churn.**

### CC-2 — `lib/app.dart` cold-start sequence is fragile
Both Issue #2 (BUG-B02 double scheduler.execute) and Issue #5 (BUG-D04, D05, D06 auto-sync) live in `lib/app.dart`. The cold-start `_autoSyncIfConfigured` and the `ref.listen` for notification scheduling both fire on the same `AsyncLoading→AsyncData` transition. Fixes must be reviewed together to avoid regressing each other.

### CC-3 — Latent release-build defect surfaces alongside Issue #3
`INTERNET` permission (BUG-C02) only declared in `android/app/src/debug/AndroidManifest.xml`. Will break **every release APK**. Must be fixed in the same change as the OAuth fix or the rc18 build will crash on every Dropbox / network call.

---

## Unified Spec Inputs

### Issue #1A — Material time picker dial overlap (Android)

**Root cause** (REVISED after flutter-frontend-engineer second opinion — see `cluster-a-time-picker-second-opinion.md`):

The bug-hunter's "framework constraint" claim was **partially wrong**. Three corrections:

1. M3 dial is `256×256`, not `280×280` (`time_picker.dart:3747-3748`).
2. Geometry actually has **+4 px clearance** with default labels — overlap is NOT inherent to M3.
3. `dialTextStyle` IS overridable via `TimePickerThemeData` (`time_picker_theme.dart:60`).

**Real root cause**: Métra's own theme overrides `dialTextStyle` to `fontSize: 18, fontWeight: w600` at `settings_screen.dart:499–502`. M3 default is `bodyLarge` (~14–16 pt, w400). The thicker/larger glyphs visually encroach on the selector when only 4 px clearance exists. There is also an intentional M3 behavior (`time_picker.dart:1117–1122`): the same-theta inner label ("23" when "11" is selected) is rendered INSIDE the selector via `clipPath` — invisible with thin labels, conspicuous with thick ones.

**Fix** (TRIVIAL): delete the `dialTextStyle` override at `settings_screen.dart:499–502` — restores Material 3 default appearance with proper clearance. ~4 lines removed.

**Files**: `lib/features/settings/settings_screen.dart:499–502` (delete `dialTextStyle` from the timePickerTheme override).

### Issue #1B — Time-picker header font too large (Android)

**Root cause** (CONFIRMED): `settings_screen.dart:504` sets `fontSize: 52` on the `displayLarge` style override for `hourMinute`. Note from the second-opinion review: the M3 default for `displayLarge` would inject `displayHero = 56 pt`, so the current 52 pt override is actually slightly smaller than M3 default — the user wants it smaller still.

**Fix**: pick a smaller value (32–50 range; `statCard` role uses 32 pt DM Serif Display as a design-system anchor; second-opinion suggested ~38 pt).

**ASK USER** to nominate the target size. **Default proposal**: **40 pt** (between `statCard` 32 and current 52).

**Files**: `lib/features/settings/settings_screen.dart:504`.

### Issue #2 — Notifications fail on real phone

**Root cause** (RANKED, multi-hypothesis — bug-hunter could not pin to one without `adb` diagnostics on the failing device):

| Rank | Hypothesis | Confidence | Fix |
|------|-----------|-----------|-----|
| #1 | **BUG-B01** OEM battery layer kills `inexactAllowWhileIdle` (Samsung One UI / Xiaomi MIUI / OnePlus / Huawei) | HIGH | User-gated `requestIgnoreBatteryOptimizations` intent in settings; surface a "battery optimisation" warning row when notifications are enabled but the app is not whitelisted |
| #2 | **BUG-B02** `lib/app.dart` `ref.listen` double-fires `scheduler.execute()` on cold start (`AsyncLoading→AsyncData`), exhausting alarm quota in RESTRICTED standby bucket | HIGH (code defect, device-independent) | Add `prev is AsyncData` guard in both ref.listen handlers |
| #3 | **BUG-B03** `POST_NOTIFICATIONS` permission revoked at OS level after a previous grant — code only checks on toggle `false→true`, never on cold-start | HIGH (Android 13+) | Cold-start `checkSelfPermission` before first `scheduler.execute()`; if denied, surface in UI |

**The spec must include all three fixes** — they are independent root-cause candidates and the user reports the bug on an unspecified real phone. Fixing only one risks a re-test failure. Bug-hunter's "diagnostic-first protocol" (5 `adb` commands) should also be documented for the user to run once.

**Files**:
- `lib/data/services/notification_service.dart` (battery-opt query, permission check)
- `lib/app.dart` (ref.listen guard)
- `android/app/src/main/AndroidManifest.xml` (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission)
- `lib/features/settings/settings_screen.dart` (battery-opt warning UI row)
- `lib/l10n/app_*.arb` (strings)

### Issue #3 — Dropbox OAuth fails on real phone

**Root cause #1 (CONFIRMED, primary)** — **BUG-C01**: `android/app/src/main/AndroidManifest.xml:62` declares `<service android:name="com.linusu.flutter_web_auth_2.KeepAliveService" android:exported="false"/>`. Chrome's keep-alive bind fails (cross-UID), Android OOM kills the Métra process while the Custom Tab is foreground; on redirect a fresh process starts; `FlutterWebAuth2Plugin.callbacks` static map is empty; the Future never completes → `BackupRunning(connecting)` hangs forever. Emulator does not aggressively kill processes, so the bug only manifests on real devices.

**Fix**: change `android:exported="false"` → `android:exported="true"`.

**Root cause #2 (CONFIRMED, latent — release-build only)** — **BUG-C02**: `INTERNET` permission missing from `android/app/src/main/AndroidManifest.xml`. Only present in `src/debug/AndroidManifest.xml`. **Every release APK will throw `SocketException` on every HTTP call** (Dropbox token exchange, upload, download, list — entire backup module dead in release). Must be fixed in the same PR.

**Fix**: add `<uses-permission android:name="android.permission.INTERNET"/>` to main manifest.

**Supporting fixes**:
- BUG-C03 (MED): wrap `_webAuth(...)` in `Future.timeout(Duration(minutes: 5), ...)` to prevent permanent UI hang on process death.
- BUG-C04 (LOW): add `debugPrint('[BackupNotifier.connect] $e')` in the catch block — currently swallows the exception type, which is why BUG-C02 was missed in rc14 review.

**Files**:
- `android/app/src/main/AndroidManifest.xml` (exported=true, INTERNET)
- `lib/data/services/backup/dropbox_provider.dart` (timeout)
- `lib/features/backup/state/backup_notifier.dart` (debugPrint)

### Issue #4 — Cupertino picker "Ripristina" font weight

**Root cause** (CONFIRMED, lines quoted):
- Ripristina (`settings_screen.dart:958–964`): `TextStyle(color: accentFlow, fontSize: 17)` — **no `fontWeight`** → defaults to `w400`.
- OK (`settings_screen.dart:979–986`): `TextStyle(color: accentFlow, fontWeight: FontWeight.w600, fontSize: 17)` — `w600`.

**Fix**: add `fontWeight: FontWeight.w600` to the Ripristina `TextStyle`.

**Files**: `lib/features/settings/settings_screen.dart:958–964`.

**Test**: existing BUG-008 test asserts color only — extend to assert `fontWeight: FontWeight.w600`.

### Issue #5 — Backup passphrase asked every time

**Root cause** (CONFIRMED) — **BUG-D01**: `lib/features/backup/backup_screen.dart:141–156` `_handleBackup()` calls `PassphraseDialog.show()` (mode `setNew`) **unconditionally** on every "Salva ora" tap. Never reads `secureStorageProvider` to check whether `metra_backup_passphrase_v1` already exists. The passphrase IS cached correctly elsewhere (`backup_notifier.dart:96` writes it; `sync_orchestrator.dart:64` and `app.dart:80` read it for auto-sync). **The UI is just not wired to the cache.**

**Adjacent root cause** — **BUG-D02**: `BackupNotifier.backupSilent()` (lines 112–117) is the correct implementation for the Nth-tap (reads stored passphrase, no dialog). It has unit tests. **Zero production callers.** It needs to be wired into `_handleBackup` as the conditional Nth-time path.

**Fix shape**:
1. In `backup_screen.dart::_handleBackup`, read `secureStorageProvider.read('metra_backup_passphrase_v1')` first.
2. If null/empty → first-time setup: show `PassphraseDialog` (setNew), call `notifier.backup(passphrase)`.
3. If present → call `notifier.backupSilent()`. No dialog. No prompt.
4. Auto-backup path (`lib/app.dart::_autoSyncIfConfigured`) already uses cached passphrase — verify it routes through `BackupNotifier` so `lastBackupAt` updates correctly (BUG-D04: currently calls `backupDataProvider.future` directly, bypassing the notifier).

**Latent bugs in the same investigation**:
- **BUG-D03 (MED)** — concurrent rollback race on fast double-tap. Fix: disable buttons in `BackupRunning` state explicitly.
- **BUG-D04 (MED)** — auto-sync bypasses `BackupNotifier.invalidateSelf()` → `lastBackupAt` UI stale.
- **BUG-D05 (MED, iOS-specific)** — `FlutterSecureStorage` defaults to `kSecAttrAccessibleWhenUnlocked` on iOS. Background auto-backup while screen locked → read fails. Fix: pass `IOSOptions(accessibility: KeychainAccessibility.afterFirstUnlock)` in the storage provider. **Required for Issue #5's "automatic backup" requirement to actually work on iOS.**
- **BUG-D06 (LOW)** — `_autoSyncIfConfigured` `catch (_)` swallows errors silently. Add `debugPrint`.

**NOT to fix** (intrinsic, documented): **BUG-D07** — Argon2id re-derived on every backup is correct (fresh salt per blob = semantic security). The passphrase is cached; the derived key is not (intentionally). The ~2–4 s Argon2id cost is intrinsic. Do not "optimise" by caching the derived key — that would compromise the encryption.

**Files**:
- `lib/features/backup/backup_screen.dart` (conditional dialog, button disable)
- `lib/features/backup/state/backup_notifier.dart` (wire `backupSilent()`)
- `lib/app.dart` (route auto-sync through notifier; debugPrint catch)
- `lib/providers/encryption_provider.dart` (iOS Keychain accessibility)

**Constraints**:
- Zero-knowledge cloud: passphrase never leaves device. Already respected — passphrase lives in `flutter_secure_storage`.
- Key rotation: existing flow supports it (passphrase delete + re-write + Argon2id re-derive). Must not break.
- GPL-3.0 license headers on any new files.
- No telemetry on the new debugPrint paths.

---

## Test coverage baseline

- **Cluster A (UI)**: BUG-008 test exists for Ripristina color — extend for fontWeight. No tests for time-picker theming. Time-picker dial fix needs a widget test asserting `initialEntryMode` (if path B is chosen) or font size (always).
- **Cluster B (notifications)**: existing BUG-006 group covers `inexactAllowWhileIdle` mode. Need: cold-start guard test, POST_NOTIFICATIONS cold-start check test, battery-opt UI row test.
- **Cluster C (Dropbox)**: backup_notifier_test exists. Need: timeout test on `_webAuth`, debugPrint in catch.
- **Cluster D (passphrase)**: `backup_notifier_test.dart` lines 154/162 already cover `backupSilent()`. Need: integration test for `_handleBackup` first-time vs Nth-time branch in widget test.

---

## Open questions — all resolved 2026-05-09

1. ~~OQ-1A~~ **RESOLVED** — second-opinion confirmed the fix is to delete the `dialTextStyle` override (~4 lines), restoring M3 default appearance.
2. ~~OQ-1B~~ **RESOLVED — header size = 40 pt** (DM Serif Display). Between current 52 and statCard 32; large enough to read but no longer dominant.
3. ~~OQ-2~~ **RESOLVED — silent settings toggle**. Add "Allow background scheduling" row in Settings under notifications. Tap opens OS battery-optimisation panel. No nag, no banner. Métra voice respected.
4. ~~OQ-2b~~ **RESOLVED — ship all 3 fixes together**. Fix BUG-B01 (battery opt), BUG-B02 (cold-start race), BUG-B03 (POST_NOTIFICATIONS cold-start check) in one batch. No prior diagnostic.

