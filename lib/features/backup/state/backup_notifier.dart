// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/metra_exception.dart';
import '../../../core/utils/result.dart';
import '../../../data/services/backup/backup_filename.dart';
import '../../../domain/entities/sync_log_entity.dart';
import '../../../providers/backup_providers.dart';
import '../../../providers/encryption_provider.dart';
import '../../../providers/repository_providers.dart';
import 'backup_state.dart';

class BackupNotifier extends AsyncNotifier<BackupState> {
  /// Secure-storage key for the cached backup passphrase.
  ///
  /// Exposed as a public constant so [BackupScreen] can read the cached value
  /// without hardcoding the literal string in the UI layer.
  static const kPassphraseKey = 'metra_backup_passphrase_v1';

  // Keep the private alias to avoid changing every internal call-site.
  static const _passphraseKey = kPassphraseKey;

  @override
  Future<BackupState> build() async {
    final settingsRepo = await ref.watch(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();
    if (settings.dropboxEmail == null) {
      return const BackupNotConnected();
    }
    return BackupConnected(
      email: settings.dropboxEmail!,
      lastBackupAt: settings.lastBackupAt,
      autoBackupActive: !settings.backupSuspended,
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
      final syncLogRepo = await ref.read(syncLogRepositoryProvider.future);
      await syncLogRepo.append(
        SyncLogEntity(
          timestamp: DateTime.now().toUtc(),
          provider: SyncProvider.dropbox,
          operation: SyncOperation.backupSkipped,
          success: true,
          errorMessage: 'skipped: backupSuspended=true',
        ),
      );
      return;
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
          provider: SyncProvider.dropbox,
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
            provider: SyncProvider.dropbox,
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
    final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();
    if (settings.backupSuspended) {
      final syncLogRepo = await ref.read(syncLogRepositoryProvider.future);
      await syncLogRepo.append(
        SyncLogEntity(
          timestamp: DateTime.now().toUtc(),
          provider: SyncProvider.dropbox,
          operation: SyncOperation.backupSkipped,
          success: true,
          errorMessage: 'skipped: backupSuspended=true',
        ),
      );
      return;
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

  Future<void> restore({String? filename}) async {
    state = const AsyncData(BackupRunning(BackupOperation.restoring));
    try {
      final uc = await ref.read(restoreDataProvider.future);
      final result = await uc(filename: filename);
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

  Future<void> restoreWithPassphrase(
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

    await restore(filename: filename);

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
  }
}

final backupNotifierProvider =
    AsyncNotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
