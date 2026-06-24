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
  /// predicate (FR-19).
  ///
  /// In M1 (Dropbox only) this is equivalent to `dropboxEmail != null`.
  /// When M3 adds iCloud (email-less), this seam is the only place to extend
  /// — no scattered inline `dropboxEmail` checks anywhere else.
  ///
  /// IMPORTANT: the result must match the Dropbox-correct semantic exactly:
  ///   connected ⟺ dropboxEmail != null
  /// The iCloud email-less case (ODQ-2) is DEFERRED to M3.
  static bool _isConnected(AppSettingsData settings) =>
      settings.dropboxEmail != null;

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
    if (!_isConnected(settings)) {
      return const BackupNotConnected();
    }
    final passphrase =
        await ref.read(secureStorageProvider).read(key: _passphraseKey);
    final passphraseSet = passphrase != null && passphrase.isNotEmpty;
    final autoBackupActive = !settings.backupSuspended && passphraseSet;
    return BackupConnected(
      email: settings.dropboxEmail!,
      lastBackupAt: settings.lastBackupAt,
      autoBackupActive: autoBackupActive,
      passphraseSet: passphraseSet,
    );
  }

  Future<void> connect() async {
    state = const AsyncData(BackupRunning(BackupOperation.connecting));
    try {
      final dropbox = ref.read(cloudBackupProvider);
      await dropbox.authorize();
      final email = await dropbox.currentEmail();
      if (email == null) throw const SyncException('Could not fetch account');
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      DateTime? discoveredLastBackupAt;
      try {
        final files = await dropbox.listFiles(); // sorted desc, newest first
        if (files.isNotEmpty) {
          discoveredLastBackupAt =
              BackupFilename.parseTimestamp(files.first.name);
        }
      } catch (_) {
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
      await ref.read(secureStorageProvider).delete(key: _passphraseKey);
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
      await settingsRepo.updateBackupState(
        dropboxEmail: null,
        lastBackupAt: null,
      );
      await ref.read(secureStorageProvider).delete(key: _passphraseKey);
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
