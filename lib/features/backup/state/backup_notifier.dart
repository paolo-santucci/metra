// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/metra_exception.dart';
import '../../../core/utils/result.dart';
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
      final dropbox = ref.read(dropboxProviderProvider);
      await dropbox.authorize();
      final email = await dropbox.currentEmail();
      if (email == null) throw const SyncException('Could not fetch account');
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      final current = await settingsRepo.getOrCreate();
      await settingsRepo.updateBackupState(
        dropboxEmail: email,
        lastBackupAt: current.lastBackupAt,
      );
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncData(BackupErrorState(e.toString()));
    }
  }

  Future<void> disconnect() async {
    state = const AsyncData(BackupRunning(BackupOperation.disconnecting));
    try {
      final dropbox = ref.read(dropboxProviderProvider);
      await dropbox.disconnect();
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      await settingsRepo.updateBackupState(
        dropboxEmail: null,
        lastBackupAt: null,
      );
      await ref.read(secureStorageProvider).delete(key: _passphraseKey);
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncData(BackupErrorState(e.toString()));
    }
  }

  Future<void> backupWithPassphrase(String passphrase) async {
    await ref.read(secureStorageProvider).write(
          key: _passphraseKey,
          value: passphrase,
        );
    await _runBackup();
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
      state = AsyncData(BackupErrorState(e.toString()));
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
      state = AsyncData(BackupErrorState(e.toString()));
    }
  }
}

final backupNotifierProvider =
    AsyncNotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
