// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/utils/result.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../../helpers/fake_app_settings_repository.dart';
import '../../../helpers/in_memory_secure_storage.dart';

class _FakeRunner implements BackupRunner {
  Result<void> backupResult = const Ok(null);
  Result<void> restoreResult = const Ok(null);
  bool backupCalled = false;
  bool restoreCalled = false;

  @override
  Future<void> backup() async {
    backupCalled = true;
    final r = backupResult;
    if (r is Err<void>) throw r.error;
  }

  @override
  Future<void> restore() async {
    restoreCalled = true;
    final r = restoreResult;
    if (r is Err<void>) throw r.error;
  }
}

void main() {
  late FakeAppSettingsRepository settingsRepo;
  late InMemorySecureStorage storage;
  late _FakeRunner runner;

  setUp(() {
    settingsRepo = FakeAppSettingsRepository();
    storage = InMemorySecureStorage();
    runner = _FakeRunner();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWith((_) async => settingsRepo),
        secureStorageProvider.overrideWithValue(storage),
        backupDataProvider.overrideWith((_) async => BackupData(runner)),
        restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
      ],
    );
  }

  test('initial state when not connected is BackupNotConnected', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final s = await container.read(backupNotifierProvider.future);
    expect(s, isA<BackupNotConnected>());
  });

  test('initial state when connected is BackupConnected', () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: DateTime.utc(2026, 4, 29),
    );
    final container = makeContainer();
    addTearDown(container.dispose);
    final s = await container.read(backupNotifierProvider.future);
    expect(s, isA<BackupConnected>());
    expect((s as BackupConnected).email, 'a@b.com');
  });

  test('backupWithPassphrase stores passphrase and calls backup runner',
      () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container
        .read(backupNotifierProvider.notifier)
        .backupWithPassphrase('test-pass');
    expect(storage.values['metra_backup_passphrase_v1'], 'test-pass');
    expect(runner.backupCalled, isTrue);
  });

  test(
      'backupWithPassphrase restores old passphrase when backup fails '
      '(state-corruption guard)', () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
    storage.values['metra_backup_passphrase_v1'] = 'old-pass';
    runner.backupResult = const Err(SyncException('network error'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container
        .read(backupNotifierProvider.notifier)
        .backupWithPassphrase('new-pass');

    // Cloud still holds a blob encrypted with old-pass — storage must match.
    expect(storage.values['metra_backup_passphrase_v1'], 'old-pass');
    final s = container.read(backupNotifierProvider).valueOrNull;
    expect(s, isA<BackupErrorState>());
  });

  test(
      'backupWithPassphrase removes key when backup fails '
      'and there was no prior passphrase', () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
    // No prior passphrase in storage.
    runner.backupResult = const Err(SyncException('upload failed'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container
        .read(backupNotifierProvider.notifier)
        .backupWithPassphrase('new-pass');

    // Storage must not hold the new passphrase since the backup never succeeded.
    expect(
      storage.values.containsKey('metra_backup_passphrase_v1'),
      isFalse,
    );
    final s = container.read(backupNotifierProvider).valueOrNull;
    expect(s, isA<BackupErrorState>());
  });

  test('backupSilent does nothing when no passphrase in storage', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container.read(backupNotifierProvider.notifier).backupSilent();
    expect(runner.backupCalled, isFalse);
  });

  test('backupSilent calls backup when passphrase exists', () async {
    storage.values['metra_backup_passphrase_v1'] = 'existing-pass';
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container.read(backupNotifierProvider.notifier).backupSilent();
    expect(runner.backupCalled, isTrue);
  });

  test('restore Ok invalidates self', () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container.read(backupNotifierProvider.notifier).restore();
    expect(runner.restoreCalled, isTrue);
  });

  test('restore Err becomes BackupErrorState', () async {
    runner.restoreResult = const Err(SyncException('oops'));
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container.read(backupNotifierProvider.notifier).restore();
    final s = container.read(backupNotifierProvider).valueOrNull;
    expect(s, isA<BackupErrorState>());
    expect((s as BackupErrorState).message, contains('oops'));
  });

  test('backup Err becomes BackupErrorState', () async {
    runner.backupResult = const Err(SyncException('disk full'));
    storage.values['metra_backup_passphrase_v1'] = 'pass';
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container.read(backupNotifierProvider.notifier).backupSilent();
    final s = container.read(backupNotifierProvider).valueOrNull;
    expect(s, isA<BackupErrorState>());
    expect((s as BackupErrorState).message, contains('disk full'));
  });

  test('restoreWithPassphrase stores passphrase and calls restore runner',
      () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container
        .read(backupNotifierProvider.notifier)
        .restoreWithPassphrase('test-pass');
    expect(storage.values['metra_backup_passphrase_v1'], 'test-pass');
    expect(runner.restoreCalled, isTrue);
  });

  test(
      'restoreWithPassphrase restores old passphrase when restore fails '
      '(state-corruption guard)', () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
    storage.values['metra_backup_passphrase_v1'] = 'old-pass';
    runner.restoreResult = const Err(SyncException('wrong passphrase'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container
        .read(backupNotifierProvider.notifier)
        .restoreWithPassphrase('typo-pass');

    // Restore failed — secure storage must keep the previously-working pass.
    expect(storage.values['metra_backup_passphrase_v1'], 'old-pass');
    final s = container.read(backupNotifierProvider).valueOrNull;
    expect(s, isA<BackupErrorState>());
  });

  test(
      'restoreWithPassphrase removes key when restore fails '
      'and there was no prior passphrase', () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
    // No prior passphrase in storage.
    runner.restoreResult = const Err(SyncException('decryption failed'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container
        .read(backupNotifierProvider.notifier)
        .restoreWithPassphrase('typo-pass');

    // Storage must not hold the new passphrase since the restore never succeeded.
    expect(
      storage.values.containsKey('metra_backup_passphrase_v1'),
      isFalse,
    );
    final s = container.read(backupNotifierProvider).valueOrNull;
    expect(s, isA<BackupErrorState>());
  });

  test('disconnect clears email, lastBackupAt, and passphrase', () async {
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: DateTime.utc(2026, 4, 29),
    );
    storage.values['metra_backup_passphrase_v1'] = 'my-pass';
    // dropboxProviderProvider is NOT overridden — the real DropboxProvider
    // uses the injected InMemorySecureStorage (wired via secureStorageProvider).
    // With no access-token in storage, disconnect() skips the revoke call
    // and runs two no-op deletes, so it completes successfully.
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container.read(backupNotifierProvider.notifier).disconnect();
    final settings = await settingsRepo.getOrCreate();
    expect(settings.dropboxEmail, isNull);
    expect(settings.lastBackupAt, isNull);
    expect(storage.values.containsKey('metra_backup_passphrase_v1'), isFalse);
  });
}
