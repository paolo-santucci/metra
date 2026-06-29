// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/metra_exception.dart';
import '../../../core/utils/result.dart';
import '../../../data/services/backup/backup_filename.dart';
import '../../../domain/entities/app_settings_data.dart';
import '../../../domain/entities/sync_log_entity.dart';
import '../../../providers/backup_providers.dart';
import '../../../providers/encryption_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/use_case_providers.dart';
import 'backup_state.dart';

class BackupNotifier extends AsyncNotifier<BackupState> {
  /// Secure-storage key for the cached backup passphrase.
  ///
  /// Delegates to [AppConstants.kBackupPassphraseKey] so there is exactly one
  /// definition of the key string in the codebase (FR-23).  Exposed as a
  /// public constant so [BackupScreen] can read the cached value without
  /// hardcoding the literal string in the UI layer.
  static const kPassphraseKey = AppConstants.kBackupPassphraseKey;

  // Keep the private alias to avoid changing every internal call-site.
  static const _passphraseKey = kPassphraseKey;

  /// Single derivation point for the "is a backup provider connected?"
  /// predicate (FR-15).
  ///
  /// Exhaustive switch over [AppSettingsData.activeProvider] (TASK-07, M3):
  ///   - dropbox / googleDrive → email-sentinel (`dropboxEmail != null`),
  ///     preserving the pre-M3 behaviour exactly (zero regression).
  ///   - iCloud → idempotent container probe via [CloudBackupProvider.authorize];
  ///     a [SyncException] means signed-out/unavailable (NFR-06); the catch is
  ///     LOCAL — no exception may escape [build()] (EC-07).
  ///
  /// Not `activeProvider != null` — that defaults to dropbox and is never null.
  Future<bool> _isConnected(AppSettingsData settings) async {
    switch (settings.activeProvider) {
      case SyncProvider.dropbox:
      case SyncProvider.googleDrive:
        return settings.dropboxEmail != null; // unchanged sentinel (FR-19)
      case SyncProvider.iCloud:
        try {
          await ref.read(cloudBackupProvider).authorize(); // container probe
          return true;
        } on SyncException {
          return false; // signed-out → not connected (NFR-06)
        }
    }
  }

  @override
  Future<BackupState> build() async {
    // BUG-B01: watch the reactive Drift stream so build() re-triggers on every
    // stream emission (e.g. after backupSuspended is written by DeleteAllData).
    // Awaiting .future ensures build() blocks until the first emission — this
    // preserves compatibility with fake StreamProviders backed by Stream.value().
    // We deliberately ignore the emitted value and re-read fresh data via
    // getOrCreate(), which always returns the current DB/in-memory state and
    // is not subject to stream-lag between the emission and the read.
    await ref.watch(appSettingsStreamProvider.future);
    final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();
    if (!await _isConnected(settings)) {
      return const BackupNotConnected();
    }
    final passphrase =
        await ref.read(secureStorageProvider).read(key: _passphraseKey);
    final passphraseSet = passphrase != null && passphrase.isNotEmpty;
    final autoBackupActive = !settings.backupSuspended && passphraseSet;
    return BackupConnected(
      // TASK-04 (FR-15, OQ-06): populate provider from settings so the
      // connected view can render the active provider's display name without
      // re-reading settings (single source of truth, no stale-read hazard).
      provider: settings.activeProvider,
      email: settings.dropboxEmail, // nullable — no `!` (FR-16)
      lastBackupAt: settings.lastBackupAt,
      autoBackupActive: autoBackupActive,
      passphraseSet: passphraseSet,
    );
  }

  Future<void> connect() async {
    state = const AsyncData(BackupRunning(BackupOperation.connecting));
    try {
      final provider = ref.read(cloudBackupProvider);
      await provider.authorize();
      final email = await provider.currentEmail();
      // iCloud has no email; only fail on null for OAuth-based providers (FR-16).
      if (email == null && provider.id != SyncProvider.iCloud) {
        throw const SyncException('Could not fetch account');
      }
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      // BUG-02 (defensive): capture secureStorageProvider BEFORE any Drift write
      // so ref.read cannot fire after the notifier is marked dirty by a
      // stream re-emission (same structural hazard as BUG-01 in switchProvider).
      final storage = ref.read(secureStorageProvider);
      DateTime? discoveredLastBackupAt;
      try {
        final files = await provider.listFiles(); // sorted desc, newest first
        if (files.isNotEmpty) {
          discoveredLastBackupAt =
              BackupFilename.parseTimestamp(files.first.name);
        }
      } catch (e) {
        debugPrint(
          '[BackupNotifier.connect] listFiles() error (best-effort): $e',
        );
        // best-effort: listing failure does not abort the connect flow
      }
      await settingsRepo.updateBackupState(
        dropboxEmail: email,
        lastBackupAt: discoveredLastBackupAt,
      );
      // BUG-B04: clear the post-wipe suspended sentinel before invalidating.
      // Without this, a delete-all → reconnect sequence leaves backupSuspended=true,
      // which would make the Stato label show "non attivo" after reconnect even
      // when the user enters a passphrase.
      await settingsRepo.clearBackupSuspended();
      // BUG-B06: wipe any passphrase left in iOS Keychain / Android EncryptedSharedPrefs
      // from a prior install. KeychainAccessibility.first_unlock items survive app
      // uninstall on iOS; EncryptedSharedPreferences survive on Android API 23+.
      // Without this delete, build() reads the stale key and computes
      // passphraseSet=true → autoBackupActive=true before the user has set a passphrase.
      // Safe: disconnect() already deletes this key, so this is idempotent on a
      // fresh-install first-connect. backupSilent() guards on pass==null and will
      // not fire until the user enters a passphrase via backupWithPassphrase().
      await storage.delete(key: _passphraseKey);
      ref.invalidateSelf();
    } catch (e) {
      debugPrint('[BackupNotifier.connect] ${e.runtimeType}: $e');
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  Future<void> disconnect() async {
    state = const AsyncData(BackupRunning(BackupOperation.disconnecting));
    try {
      final dropbox = ref.read(cloudBackupProvider);
      await dropbox.disconnect();
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      // BUG-02 (defensive): capture secureStorageProvider BEFORE any Drift write
      // so ref.read cannot fire after the notifier is marked dirty by a
      // stream re-emission (same structural hazard as BUG-01 in switchProvider).
      final storage = ref.read(secureStorageProvider);
      await settingsRepo.updateBackupState(
        dropboxEmail: null,
        lastBackupAt: null,
      );
      // BUG-2: reset the active provider to the default (dropbox) so that
      // _isConnected evaluates the email-sentinel branch on the next build().
      // Without this, iCloud stays "connected" because _isConnected probes the
      // still-available container via authorize() — there is no disconnect
      // sentinel for iCloud.  Resetting to dropbox + null dropboxEmail gives
      // the null-email sentinel path, which correctly reports disconnected.
      // This is identical to the idiom used by DeleteAllData (C-07: no new
      // persisted field; harmless for Dropbox/Google Drive which are already
      // governed by the email sentinel).
      await settingsRepo.setActiveProvider(SyncProvider.dropbox);
      await storage.delete(key: _passphraseKey);
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  /// Switches the active backup provider from the current one to [target].
  ///
  /// Ordered contract (spec §5.1):
  ///   1. Re-entrancy guard: return immediately if [BackupRunning].
  ///   2. Platform guard: assert [target] is in [availableProviders].
  ///   3. Set state → [BackupRunning(BackupOperation.switching)].
  ///   4. Read old provider via [resolveBackupProvider(settings.activeProvider)].
  ///   5. **Abort gate**: [old.disconnect()]; on throw → [BackupErrorState], return;
  ///      activeProvider unchanged, target never authorized (FR-11).
  ///   6. [setActiveProvider(target)] — the flip.
  ///   7. Clear identity: [updateBackupState(null, null)].
  ///   8. Resolve new provider via [resolveBackupProvider(target)].
  ///      MUST NOT use [cloudBackupProvider] here — it still points to the old
  ///      provider until the Drift stream re-emits (CC-2 stale-read hazard).
  ///   9. Authorize + currentEmail + best-effort listFiles.
  ///  10. updateBackupState + clearBackupSuspended.
  ///  11. On post-flip failure (steps 9–10 throw) → [BackupErrorState], return.
  ///      No rollback — activeProvider stays [target] (OQ-01, architect decision).
  ///      The next [build()] observes target with no email → [BackupNotConnected],
  ///      giving the user a clean retry surface.
  ///  12. [ref.invalidateSelf()].
  ///
  /// Security invariants (FR-13, CC-1):
  ///   - Never reads, writes, or deletes [kPassphraseKey].
  ///   - Never calls the notifier's own [connect()] / [disconnect()] — both
  ///     delete the passphrase key.
  ///   - Never calls [old.deleteFile] — old .enc files are left intact.
  Future<void> switchProvider(SyncProvider target) async {
    // Step 1: re-entrancy guard — a switch already in progress takes priority.
    if (state.valueOrNull is BackupRunning) return;

    // Step 2: platform guard — iCloud is iOS-only (availableProviders enforces it).
    assert(availableProviders(defaultTargetPlatform).contains(target));

    // Step 3: signal switch in progress.
    state = const AsyncData(BackupRunning(BackupOperation.switching));

    // Step 4: read BOTH the old and new providers BEFORE any Drift mutation.
    // BUG-01 fix: the previous code read resolveBackupProvider(target) at step 8,
    // after settingsRepo.setActiveProvider() and settingsRepo.updateBackupState()
    // had already written to Drift, causing the appSettingsStreamProvider to
    // re-emit and mark BackupNotifier dirty — the subsequent ref.read then
    // threw a Riverpod assertion (CC-2 stale-read hazard).
    // Hoisting both reads here is safe: resolveBackupProvider resolves by its
    // 'id' argument (not by reactive settings), so capturing newProvider before
    // the flip returns the same instance that step-8 would have returned — the
    // CC-2 invariant is preserved.
    final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();
    final old = ref.read(resolveBackupProvider(settings.activeProvider));
    final newProvider = ref.read(resolveBackupProvider(target));

    // Step 5: abort gate — if disconnect throws, leave activeProvider unchanged.
    try {
      await old.disconnect();
    } catch (e) {
      debugPrint(
        '[BackupNotifier.switchProvider] abort gate — old.disconnect() '
        'failed: $e; aborting switch, activeProvider unchanged',
      );
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
      return;
    }

    // Step 6: flip — this is the point of no return (OQ-01).
    await settingsRepo.setActiveProvider(target);

    // Step 7: clear old identity fields.
    await settingsRepo.updateBackupState(
      dropboxEmail: null,
      lastBackupAt: null,
    );

    // Step 8: newProvider already captured at step 4 (hoisted before any Drift
    // mutation for CC-2 safety — see BUG-01 fix comment above).

    // Steps 9–11: post-flip connect sequence.  Any exception here does NOT roll back
    // activeProvider (OQ-01 architect decision) — the next build() will observe target
    // with no email and yield BackupNotConnected, giving the user a clean retry surface.
    try {
      await newProvider.authorize();
      final email = await newProvider.currentEmail();
      // iCloud has no email — only fail on null for OAuth-based providers (EC-08).
      if (email == null && target != SyncProvider.iCloud) {
        throw const SyncException('Could not fetch account');
      }
      DateTime? discoveredLastBackupAt;
      try {
        final files = await newProvider.listFiles();
        if (files.isNotEmpty) {
          discoveredLastBackupAt =
              BackupFilename.parseTimestamp(files.first.name);
        }
      } catch (e) {
        debugPrint(
          '[BackupNotifier.switchProvider] listFiles() error (best-effort): $e',
        );
        // best-effort: list failure does not abort the switch flow
      }
      await settingsRepo.updateBackupState(
        dropboxEmail: email,
        lastBackupAt: discoveredLastBackupAt,
      );
      await settingsRepo.clearBackupSuspended();
    } catch (e) {
      debugPrint(
        '[BackupNotifier.switchProvider] post-flip failure — $e; '
        'activeProvider stays ${target.name} (OQ-01, no rollback)',
      );
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
      return;
    }

    // Step 12: trigger build() with the new settings.
    ref.invalidateSelf();
  }

  Future<void> backupWithPassphrase(String passphrase) async {
    if (state.valueOrNull is BackupRunning) return;
    // HC-2: sentinel read PRECEDES any secure-storage operation.
    // If backupSuspended = true (set by DeleteAllData on wipe), skip silently
    // and log a diagnostic entry — no passphrase is read or written.
    final settingsForSentinel =
        await ref.read(appSettingsRepositoryProvider.future);
    final sentinelSettings = await settingsForSentinel.getOrCreate();
    if (sentinelSettings.backupSuspended) {
      // BUG-B02: manual backup IS the resume path. Clear sentinel BEFORE
      // any secure-storage interaction (HC-2 ordering).
      await settingsForSentinel.clearBackupSuspended();
      // No SyncLog skip entry — the user-driven tap is succeeding, not skipping.
      // backupSilent() retains the skip-log path (different semantics:
      // silent cold-start vs. user-driven tap).
    }
    final storage = ref.read(secureStorageProvider);
    // Read the old passphrase so it can be restored if the upload fails.
    // The invariant: after a failed backup the cloud blob is still encrypted
    // with the old key, so secure storage must keep the old passphrase.
    final oldPassphrase = await storage.read(key: _passphraseKey);

    // Write the new passphrase so the orchestrator picks it up during backup.
    await storage.write(key: _passphraseKey, value: passphrase);

    await _runBackup();

    // If the backup failed, _runBackup sets an error state but does not throw.
    // We must detect the failure by inspecting state and restore the old value.
    final currentState = state.valueOrNull;
    if (currentState is BackupErrorState) {
      if (oldPassphrase != null) {
        await storage.write(key: _passphraseKey, value: oldPassphrase);
      } else {
        await storage.delete(key: _passphraseKey);
      }
    }
  }

  Future<void> backupSilent() async {
    if (state.valueOrNull is BackupRunning) return;
    // Not configured: no account is connected, so there is nowhere to back up.
    // Without this guard, a passphrase left in secure storage after Dropbox
    // disconnect would cause _runBackup to fire and fail silently on every
    // cold-start (BUG-D04 follow-up / FR-14).
    if (state.valueOrNull is BackupNotConnected) return;

    // FR-11/FR-12/FR-13: skip cold-start backup when no new data has been
    // written since the last backup. Manual backup (backupWithPassphrase)
    // bypasses this guard intentionally.
    final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();

    // HC-2 sentinel: guard 3 — inserted between BackupNotConnected (guard 2)
    // and the write-recency check (guard 4). Reuses the settings read above.
    if (settings.backupSuspended) {
      final syncLogRepo = await ref.read(syncLogRepositoryProvider.future);
      await syncLogRepo.append(
        SyncLogEntity(
          timestamp: DateTime.now().toUtc(),
          // FR-18: use the active-provider id from settings, not a hardcoded
          // SyncProvider.dropbox literal — preserves correctness when the
          // active provider changes in future milestones.
          provider: settings.activeProvider,
          operation: SyncOperation.backupSkipped,
          success: true,
          errorMessage: 'skipped: backupSuspended=true',
        ),
      );
      return;
    }

    final lastBackupAt = settings.lastBackupAt;
    final lastWriteAt = settings.lastLogOrSymptomWriteAt;

    // FR-12: first-ever backup always proceeds (no prior backup to compare against).
    if (lastBackupAt != null) {
      // FR-13: no log/symptom ever written → nothing to back up.
      // FR-11: write timestamp not after last backup → nothing new since last upload.
      if (lastWriteAt == null || !lastWriteAt.isAfter(lastBackupAt)) {
        // FR-16: append a diagnostic log entry so the user can inspect why
        // the backup was skipped via the sync log view.
        final syncLogRepo = await ref.read(syncLogRepositoryProvider.future);
        await syncLogRepo.append(
          SyncLogEntity(
            timestamp: DateTime.now().toUtc(),
            // FR-18: use the active-provider id from settings, not a hardcoded
            // SyncProvider.dropbox literal — preserves correctness when the
            // active provider changes in future milestones.
            provider: settings.activeProvider,
            operation: SyncOperation.backupSkipped,
            success: true,
            errorMessage:
                'skipped: lastWriteAt=$lastWriteAt lastBackupAt=$lastBackupAt',
          ),
        );
        return;
      }
    }
    // Cases: (c) first-ever backup, or (d) new data exists → proceed.

    final pass =
        await ref.read(secureStorageProvider).read(key: _passphraseKey);
    if (pass == null) return;
    await _runBackup();
  }

  /// Manual backup triggered from the UI (FR-16/FR-19/FR-20).
  ///
  /// Differences from [backupSilent]:
  /// - Bypasses the write-recency guard — runs even when nothing is new.
  /// - Never writes to secure storage (FR-19 invariant).
  ///
  /// Guard order:
  ///   1. BackupRunning  → no-op (re-entrancy guard)
  ///   2. BackupNotConnected → no-op (no account)
  ///   3. backupSuspended → log skip entry, return
  ///   4. null passphrase → silent return
  ///   5. → _runBackup()
  Future<void> backupNow() async {
    // Guard 1: already running.
    if (state.valueOrNull is BackupRunning) return;

    // Guard 2: not connected.
    if (state.valueOrNull is BackupNotConnected) return;

    // Guard 3: backup suspended (e.g. post-wipe sentinel).
    // BUG-B02: manual tap IS the resume path — clear the sentinel and proceed.
    // HC-2 ordering: clearBackupSuspended() runs BEFORE any secureStorage read.
    final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();
    if (settings.backupSuspended) {
      await settingsRepo.clearBackupSuspended();
      // No SyncLog skip entry — the user-driven tap is succeeding, not skipping.
      // backupSilent() retains the skip-log path (different semantics:
      // silent cold-start vs. user-driven tap).
    }

    // Guard 4: no passphrase — nothing to encrypt with.
    final pass =
        await ref.read(secureStorageProvider).read(key: _passphraseKey);
    if (pass == null) return;

    // Guard 5 bypassed intentionally: write-recency check is NOT applied here.
    await _runBackup();
  }

  Future<void> _runBackup() async {
    state = const AsyncData(BackupRunning(BackupOperation.backingUp));
    try {
      final uc = await ref.read(backupDataProvider.future);
      final result = await uc();
      switch (result) {
        case Ok():
          ref.invalidateSelf();
        case Err(:final error):
          state = AsyncData(BackupErrorState(error.message));
      }
    } catch (e) {
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  /// Returns the number of daily-log rows restored, or null on failure.
  /// On null, the notifier has already set [BackupErrorState] — the caller
  /// uses null as the "do not show success snackbar" signal.
  Future<int?> restore({String? filename}) async {
    state = const AsyncData(BackupRunning(BackupOperation.restoring));
    try {
      final uc = await ref.read(restoreDataProvider.future);
      final result = await uc(filename: filename);
      switch (result) {
        case Ok(:final value):
          ref.invalidateSelf();
          // BUG-R1: invalidate cached cycle-day providers so the UI reflects
          // the restored data. Do NOT invalidate cyclePredictionProvider —
          // the Drift stream propagates that change automatically; manual
          // invalidation would reset the badge to AsyncLoading (C-04).
          ref.invalidate(currentCycleDayProvider);
          ref.invalidate(cycleDayForDateProvider);
          return value; // propagate count to caller
        case Err(:final error):
          state = AsyncData(BackupErrorState(error.message));
          return null;
      }
    } catch (e) {
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
      return null;
    }
  }

  /// Returns the count from [restore] (null on failure or rollback path).
  Future<int?> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async {
    final storage = ref.read(secureStorageProvider);
    // Read the old passphrase so it can be restored if the download or
    // decryption fails. Invariant: a failed restore must not overwrite
    // a previously-working passphrase in secure storage.
    final oldPassphrase = await storage.read(key: _passphraseKey);

    // Write the new passphrase so the orchestrator picks it up during restore.
    await storage.write(key: _passphraseKey, value: passphrase);

    final count = await restore(filename: filename);

    // If the restore failed, restore() sets an error state but does not throw.
    // Detect failure via state and roll back the secure-storage value.
    final currentState = state.valueOrNull;
    if (currentState is BackupErrorState) {
      if (oldPassphrase != null) {
        await storage.write(key: _passphraseKey, value: oldPassphrase);
      } else {
        await storage.delete(key: _passphraseKey);
      }
    }
    return count;
  }
}

final backupNotifierProvider =
    AsyncNotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
