// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/metra_exception.dart';
import '../../../core/utils/result.dart';
import '../../../data/services/backup/backup_filename.dart';
import '../../../providers/backup_providers.dart';
import '../../../providers/encryption_provider.dart';
import '../../../providers/repository_providers.dart';
import 'backup_state.dart';

class BackupNotifier extends AsyncNotifier<BackupState> {
  static const _passphraseKey = 'metra_backup_passphrase_v1';

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
          discoveredLastBackupAt = BackupFilename.parseTimestamp(files.first);
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
    final pass =
        await ref.read(secureStorageProvider).read(key: _passphraseKey);
    if (pass == null) return;
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

  Future<void> restore() async {
    state = const AsyncData(BackupRunning(BackupOperation.restoring));
    try {
      final uc = await ref.read(restoreDataProvider.future);
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

  Future<void> restoreWithPassphrase(String passphrase) async {
    final storage = ref.read(secureStorageProvider);
    // Read the old passphrase so it can be restored if the download or
    // decryption fails. Invariant: a failed restore must not overwrite
    // a previously-working passphrase in secure storage.
    final oldPassphrase = await storage.read(key: _passphraseKey);

    // Write the new passphrase so the orchestrator picks it up during restore.
    await storage.write(key: _passphraseKey, value: passphrase);

    await restore();

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
