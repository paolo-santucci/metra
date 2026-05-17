# Cluster D — Backup Password Assessment
## sp-20260509-android-ios-prerelease-bugs

**Date:** 2026-05-09  
**Scope:** backup password prompt fires on every tap; automatic backup skips prompt silently.

---

## Findings

---

[HIGH] BUG-D01: PassphraseDialog shown unconditionally on every "Salva ora" tap
File: `lib/features/backup/backup_screen.dart:141-156`, `lib/features/backup/widgets/passphrase_dialog.dart:33-43`
Category: logic-error
CWE: CWE-406 (Insufficient Control of Network Message Volume in a Network-Based System — not applicable; closest is CWE-693 Protection Mechanism Failure — use-case logic flaw)

Evidence:
```dart
// backup_screen.dart:141-156
Future<void> _handleBackup() async {
  final messenger = ScaffoldMessenger.of(context);
  await PassphraseDialog.show(        // <-- ALWAYS shown, no guard
    context,
    onConfirmed: (passphrase) {
      unawaited(
        ref.read(backupNotifierProvider.notifier)
           .backupWithPassphrase(passphrase),
      );
      ...
    },
  );
}
```

Analysis: `_handleBackup()` unconditionally calls `PassphraseDialog.show()` with mode `setNew` (8-char + confirm). It never reads `secureStorageProvider` to check whether `metra_backup_passphrase_v1` is already present. The passphrase IS written to secure storage on first confirm (`backup_notifier.dart:96`) and IS read by `SyncOrchestrator.backup()` (`sync_orchestrator.dart:64`) and by `_autoSyncIfConfigured` (`app.dart:80`) — but the UI tap path bypasses all that cached state. The "Nth tap" code path (`BackupNotifier.backupSilent`) is fully implemented and tested but has **zero callers in production code**.

Trigger: User who has already completed one backup taps "Salva ora" — dialog fires regardless. Confirmed by reading backup_screen.dart and grepping all `backupSilent` callers (only test files).

Impact: Every manual backup forces an unnecessary passphrase entry + Argon2id re-derivation (64 MB, 3 iterations, ~2–4 s on mobile). UX regression that contradicts the feature intent.

---

[HIGH] BUG-D02: BackupNotifier.backupSilent() is dead code — no production caller
File: `lib/features/backup/state/backup_notifier.dart:112-117`
Category: logic-error

Evidence:
```dart
// backup_notifier.dart:112-117
Future<void> backupSilent() async {
  final pass =
      await ref.read(secureStorageProvider).read(key: _passphraseKey);
  if (pass == null) return;
  await _runBackup();
}
```

Analysis: `backupSilent()` is the correct implementation for Nth-tap and auto-backup: it reads the stored passphrase and skips the dialog. Two tests verify its behavior. The method is never called from UI code — not from `backup_screen.dart`, not from `app.dart`. The auto-sync path in `app.dart:82` calls `backupDataProvider` directly, not through the notifier.

Trigger: The method simply never executes in production.

Impact: The fix for BUG-D01 is already implemented; it just needs wiring. Without wiring, auto-sync also bypasses `BackupNotifier.invalidateSelf()` (see BUG-D04).

---

[MEDIUM] BUG-D03: Passphrase rollback race — concurrent backup taps use wrong rollback target
File: `lib/features/backup/state/backup_notifier.dart:88-110`
Category: race-condition

Evidence:
```dart
// backup_notifier.dart:88-110
Future<void> backupWithPassphrase(String passphrase) async {
  final storage = ref.read(secureStorageProvider);
  final oldPassphrase = await storage.read(key: _passphraseKey);  // read old
  await storage.write(key: _passphraseKey, value: passphrase);    // write new
  await _runBackup();
  final currentState = state.valueOrNull;
  if (currentState is BackupErrorState) {
    if (oldPassphrase != null) {
      await storage.write(key: _passphraseKey, value: oldPassphrase); // restore old
    } else {
      await storage.delete(key: _passphraseKey);
    }
  }
}
```

Analysis: Two concurrent calls (e.g. tap while previous is still running despite `BackupRunning` state guard — possible if the state update races the second tap) interleave as: call-1 reads `old=null`, call-2 reads `old=passphrase-1`. If call-2 fails, it restores `passphrase-1`; if call-1 also fails, it deletes the key (because `oldPassphrase==null`), leaving storage inconsistent. The `BackupRunning` UI guard is advisory (state is `AsyncData(BackupRunning...)` and buttons are not disabled), so the race is triggerable with fast double-tap.

Trigger: User double-taps "Salva ora" before first `BackupRunning` state renders; both taps dispatch `backupWithPassphrase` with different passphrases.

Impact: Silent passphrase corruption in secure storage; subsequent backups encrypt with an unexpected key or fail with "No passphrase configured".

---

[MEDIUM] BUG-D04: Auto-sync bypasses BackupNotifier — lastBackupAt does not refresh in open BackupScreen
File: `lib/app.dart:74-87`, `lib/providers/backup_providers.dart:70-73`
Category: state-corruption

Evidence:
```dart
// app.dart:82-83
final uc = await ref.read(backupDataProvider.future);
await uc();  // calls SyncOrchestrator.backup() directly
```

Analysis: `_autoSyncIfConfigured` calls the `BackupData` use-case directly, bypassing `BackupNotifier`. `SyncOrchestrator.backup()` updates `lastBackupAt` in the DB (`sync_orchestrator.dart:87-90`) but does not call `invalidateSelf()` on `backupNotifierProvider`. If `BackupScreen` is open when auto-sync fires, the displayed `lastBackupAt` timestamp is stale until the user navigates away and back.

Trigger: App is opened with BackupScreen already visible (deep link or tab switch) at the moment `initState` fires `_autoSyncIfConfigured`.

Impact: Stale `lastBackupAt` displayed; low severity but creates user confusion ("backup didn't run").

---

[MEDIUM] BUG-D05: iOS FlutterSecureStorage accessibility defaults to WhenUnlocked — blocks unattended auto-backup
File: `lib/providers/encryption_provider.dart:24-28`
Category: state-corruption
CWE: CWE-311 (Missing Encryption of Sensitive Data — adjacent; the constraint is accessibility, not absence of encryption)

Evidence:
```dart
// encryption_provider.dart:24-28
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // No IOSOptions — defaults to kSecAttrAccessibleWhenUnlocked
  ),
);
```

Analysis: `flutter_secure_storage` defaults iOS keychain items to `kSecAttrAccessibleWhenUnlocked`. Reading an item with this accessibility level fails when the device is locked (screen off), which is the typical state when an auto-backup fires from `_autoSyncIfConfigured` on cold start triggered by a system push/background task. Auto-backup reads `metra_backup_passphrase_v1` from this storage (`app.dart:80`). If the device is locked at that moment, `storage.read()` throws a platform exception, caught by `catch (_) {}` and silently swallowed. `kSecAttrAccessibleAfterFirstUnlock` allows reads after device has been unlocked at least once since boot — the correct level for background tasks that run while screen is off.

Trigger: Auto-backup fires while device screen is locked but app was launched by a background mechanism after the user unlocked at least once since boot.

Impact: Auto-backup silently skips; user never gets an error. The correct iOS accessibility flag is missing.

---

[LOW] BUG-D06: Auto-sync catch swallows all errors with no log
File: `lib/app.dart:84-86`
Category: error-swallow

Evidence:
```dart
} catch (_) {
  // Silent — user can retry from BackupScreen.
}
```

Analysis: All exceptions from `_autoSyncIfConfigured` are discarded. No `debugPrint`, no sync-log entry, no user feedback. Violates the project's error-handling convention (CLAUDE.md §5: "Never `catch(e) {}` without at least a local log"). A crash inside `backupDataProvider.future` or `settingsRepo.getOrCreate()` silently fails.

Trigger: Any exception in the auto-sync path.

Impact: Invisible failures; debugging requires adding instrumentation retroactively.

---

[LOW] BUG-D07: Argon2id re-derived on every backup — perf bug after passphrase is cached
File: `lib/data/services/encryption_service.dart:62-79`, `lib/data/services/backup/sync_orchestrator.dart:68-70`
Category: logic-error

Evidence:
```dart
// sync_orchestrator.dart:68-70 (via encryption_service.dart:66)
final blob = await _encryption.encrypt(bytes, passphrase); // derives key fresh each time
```

Analysis: `EncryptionService.encrypt()` generates a fresh 16-byte salt and re-derives the 32-byte AES key via Argon2id (64 MB, 3 iter, 4-lane) on every call. This is correct for cloud-blob security (unique salt per blob = unique key = semantic security). Caching the derived key is NOT possible without also fixing the per-blob salt. The passphrase cache (BUG-D01 fix) eliminates the password prompt; the Argon2id cost (~2–4 s) is intrinsic to the algorithm and cannot be removed without a security regression. This is a confirmed fact, not a fixable bug. Documenting so the spec does not propose derived-key caching as the mechanism.

---

## Summary

7 findings (0 critical, 2 high, 3 medium, 2 low)  
Highest-risk area: `lib/features/backup/backup_screen.dart` + `lib/features/backup/state/backup_notifier.dart`  
Recommended next action: wire `backupSilent()` as the conditional path in `_handleBackup`; add a pre-tap key-existence check; add `IOSOptions` to `secureStorageProvider`.

---

## Spec Inputs

### ROOT CAUSE

The root cause is entirely in `backup_screen.dart:141-156`. `_handleBackup()` calls `PassphraseDialog.show()` unconditionally on every tap. The correct conditional method — `BackupNotifier.backupSilent()` — already exists, is tested, and reads the cached passphrase from secure storage, but has zero production callers. The UI never checks whether the passphrase is already stored.

The passphrase caching infrastructure is correct and complete:  
- Write path: `backup_notifier.dart:96` (`backupWithPassphrase`)  
- Read path (notifier): `backup_notifier.dart:113` (`backupSilent`)  
- Read path (auto-sync): `app.dart:80` (`_autoSyncIfConfigured`)  
- Read path (orchestrator): `sync_orchestrator.dart:64` (`SyncOrchestrator.backup()`)

### Affected Components

| File | Lines | Issue |
|---|---|---|
| `lib/features/backup/backup_screen.dart` | 141-156 | Unconditional dialog (BUG-D01) |
| `lib/features/backup/state/backup_notifier.dart` | 112-117 | Dead `backupSilent()` (BUG-D02) |
| `lib/features/backup/state/backup_notifier.dart` | 88-110 | Rollback race (BUG-D03) |
| `lib/app.dart` | 74-87 | Auto-sync bypasses notifier (BUG-D04), swallows errors (BUG-D06) |
| `lib/providers/encryption_provider.dart` | 24-28 | iOS accessibility level (BUG-D05) |
| `lib/data/services/encryption_service.dart` | 62-79 | Argon2id re-derived per backup (BUG-D07 — not fixable, documented) |

### Constraints the Fix Must Respect

1. **Zero-knowledge cloud**: encryption key/passphrase never leaves the device; the cloud blob stores only AES-256-GCM ciphertext with a unique salt per blob.
2. **Key never leaves device**: `metra_backup_passphrase_v1` lives exclusively in `FlutterSecureStorage`. No logging of passphrase or derived bytes.
3. **Keychain accessibility**: iOS must be changed from default `kSecAttrAccessibleWhenUnlocked` to `kSecAttrAccessibleAfterFirstUnlock` to support background auto-backup. Tradeoff: items remain accessible after first post-boot unlock (device-unlock IS the trust boundary per CLAUDE.md §2).
4. **Key rotation**: disconnect flow (`backup_notifier.dart:75`) already wipes `_passphraseKey`. Re-connect + new passphrase is the rotation path. An explicit "Cambia password" affordance does not exist; the spec must decide whether to add one.
5. **GPL-3.0 license header**: any new `.dart` file must carry the full license block as in existing files.
6. **No telemetry / no new dependencies**: fix must use `flutter_secure_storage` (already present) only.
7. **Concurrent-tap guard**: `backupWithPassphrase` rollback race (BUG-D03) must be fixed by disabling the "Salva ora" button while `BackupRunning` state is active (not currently enforced in UI).

### Proposed Fix Shape

`_handleBackup()` in `backup_screen.dart` should read `secureStorageProvider` (or a new `BackupNotifier` method returning `bool hasPassphrase`) before showing the dialog. If a passphrase is present, skip the dialog and call `backupSilent()` directly. If absent (first time), show the dialog in `setNew` mode as today. The same conditional logic should apply to `_handleRestore()` — if a passphrase is cached, skip the `unlock`-mode dialog and attempt decrypt directly (showing the dialog only on `CryptoException`, i.e., wrong key). `_autoSyncIfConfigured` in `app.dart` should be replaced with a call to `BackupNotifier.backupSilent()` through the notifier so that `invalidateSelf()` fires correctly and `lastBackupAt` refreshes on-screen. `secureStorageProvider` must add `IOSOptions(accessibility: KeychainAccessibility.afterFirstUnlock)`. `catch (_)` in `_autoSyncIfConfigured` must log via `debugPrint`.

### Test Coverage Baseline + New Tests Needed

**Existing tests** (already pass):  
- `test/features/backup/state/backup_notifier_test.dart`: `backupSilent` (2 tests at lines 154, 162).

**New tests required:**  
1. Widget test: `_handleBackup` skips dialog when passphrase is in storage → calls `backupSilent`.  
2. Widget test: `_handleBackup` shows dialog when no passphrase stored (first time).  
3. Widget test: double-tap "Salva ora" while `BackupRunning` — second tap no-ops (button disabled).  
4. Unit test: `_autoSyncIfConfigured` calls `backupNotifierProvider.notifier.backupSilent()` (not `backupDataProvider` directly) after auto-sync runs.  
5. Integration test: first tap → dialog → enter passphrase → backup runs; second tap → no dialog → backup runs with cached passphrase.

### Open Questions for Spec Phase

1. **Explicit "Cambia password backup" affordance?** Currently, rotation requires disconnect + reconnect + new passphrase. Is a dedicated in-screen "Cambia password" button required for the MVP?
2. **Restore passphrase caching**: should a restore also skip the dialog if the cached passphrase matches the blob's key? (Risk: if user restores a blob encrypted with a different passphrase, the AES-GCM tag failure is the signal, not a pre-check.)
3. **Auto-sync throttle / WiFi-only gate**: `_autoSyncIfConfigured` fires on every app launch with no debounce, battery, or network checks. Should the spec define a minimum interval (e.g., 1 h) or WiFi-only flag?
4. **iOS `afterFirstUnlock` trade-off acceptance**: needs explicit product owner sign-off — it slightly widens the attack window (device stolen unlocked then screen-locked still allows key read).
5. **Argon2id cost UX**: ~2–4 s derivation on first-time setup. Is a progress indicator shown during `backupWithPassphrase`? Currently the snackbar fires before the derivation completes (because `unawaited` is used at line 147).
