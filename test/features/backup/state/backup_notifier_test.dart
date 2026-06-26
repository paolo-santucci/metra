// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/utils/result.dart';
import 'package:metra/data/database/app_database.dart';
import 'package:metra/data/repositories/drift_app_settings_repository.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/cloud_backup_provider.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/core/constants/app_constants.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../../helpers/fake_app_settings_repository.dart';
import '../../../helpers/fake_dropbox_provider.dart';
import '../../../helpers/fake_icloud_provider.dart';
import '../../../helpers/fake_sync_log_repository.dart';
import '../../../helpers/in_memory_secure_storage.dart';

class _FakeRunner implements BackupRunner {
  Result<void> backupResult = const Ok(null);
  Result<void> restoreResult = const Ok(null);
  bool backupCalled = false;
  bool restoreCalled = false;
  int restoreCallCount = 0;
  String? lastFilename;

  @override
  Future<void> backup() async {
    backupCalled = true;
    final r = backupResult;
    if (r is Err<void>) throw r.error;
  }

  @override
  Future<int> restore({String? filename}) async {
    restoreCalled = true;
    restoreCallCount++;
    lastFilename = filename;
    final r = restoreResult;
    if (r is Err<void>) throw r.error;
    return 0;
  }
}

/// A runner that blocks until [release] is completed, allowing tests to
/// inspect the notifier while it is mid-operation (BackupRunning state).
class _BlockingRunner implements BackupRunner {
  final Completer<void> release;
  int backupCallCount = 0;

  _BlockingRunner(this.release);

  @override
  Future<void> backup() async {
    backupCallCount++;
    await release.future;
  }

  @override
  Future<int> restore({String? filename}) async => 0;
}

/// A runner whose [restore] simulates [SyncOrchestrator.restore] alignment:
/// sets [lastLogOrSymptomWriteAt] = [tb] on the settings repository.
///
/// This models the contract verified by the 'restore alignment' group in
/// sync_orchestrator_test.dart without requiring real encryption/Dropbox wiring
/// in the notifier-layer integration test.
class _AligningRestoreRunner implements BackupRunner {
  _AligningRestoreRunner(this._settingsRepo, this._tb);

  final FakeAppSettingsRepository _settingsRepo;
  final DateTime _tb;
  bool restoreCalled = false;

  @override
  Future<void> backup() async {}

  @override
  Future<int> restore({String? filename}) async {
    restoreCalled = true;
    await _settingsRepo.updateLastDataWriteAt(_tb);
    return 0;
  }
}

/// A Dropbox provider whose [authorize] throws the given [error].
class _ThrowingDropboxProvider implements CloudBackupProvider {
  _ThrowingDropboxProvider(this.error);
  final Object error;

  @override
  SyncProvider get id => SyncProvider.dropbox;

  @override
  Future<void> authorize() => Future.error(error);

  @override
  Future<String?> currentEmail() async => null;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> upload(Uint8List blob, String filename) async {}

  @override
  Future<Uint8List> download(String filename) async => Uint8List(0);

  @override
  Future<List<BackupFileEntry>> listFiles() async => [];

  @override
  Future<void> deleteFile(String filename) async {}
}

/// Spy-enabled Google Drive fake for [BackupNotifier.switchProvider] tests.
///
/// Tracks [authorizeCalls], [disconnectCalls], and [deleteCalls] so ordering
/// invariants and exclusion assertions can be made without modifying
/// the shared [FakeDropboxProvider] helper with Google-Drive-specific logic.
class _FakeGoogleDriveProvider implements CloudBackupProvider {
  int disconnectCalls = 0;
  int authorizeCalls = 0;
  bool disconnectThrows = false;
  bool authorizeThrows = false;
  String? currentEmailResult = 'user@google.com';
  bool failNextList = false;
  final List<String> deleteCalls = [];

  @override
  SyncProvider get id => SyncProvider.googleDrive;

  @override
  Future<void> authorize() async {
    authorizeCalls++;
    if (authorizeThrows) {
      throw const SyncException('Google Drive auth failed');
    }
  }

  @override
  Future<String?> currentEmail() async => currentEmailResult;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (disconnectThrows) {
      disconnectThrows = false;
      throw const SyncException('Google Drive disconnect failed');
    }
  }

  @override
  Future<void> upload(Uint8List blob, String filename) async {}

  @override
  Future<Uint8List> download(String filename) async => Uint8List(0);

  @override
  Future<List<BackupFileEntry>> listFiles() async {
    if (failNextList) {
      failNextList = false;
      throw Exception('list failed');
    }
    return [];
  }

  @override
  Future<void> deleteFile(String filename) async {
    deleteCalls.add(filename);
  }
}

/// Google Drive fake whose [authorize] blocks until [release] is completed.
///
/// Used in the re-entrancy (EC-06) test to hold [switchProvider] inside
/// the post-flip connect step so the second call can see [BackupRunning].
class _BlockingAuthGoogleDriveProvider implements CloudBackupProvider {
  _BlockingAuthGoogleDriveProvider(this.release);

  final Completer<void> release;
  int authorizeCalls = 0;

  @override
  SyncProvider get id => SyncProvider.googleDrive;

  @override
  Future<void> authorize() async {
    authorizeCalls++;
    await release.future;
  }

  @override
  Future<String?> currentEmail() async => 'user@google.com';

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> upload(Uint8List blob, String filename) async {}

  @override
  Future<Uint8List> download(String filename) async => Uint8List(0);

  @override
  Future<List<BackupFileEntry>> listFiles() async => [];

  @override
  Future<void> deleteFile(String filename) async {}
}

void main() {
  late FakeAppSettingsRepository settingsRepo;
  late InMemorySecureStorage storage;
  late _FakeRunner runner;
  late FakeDropboxProvider fakeDropbox;
  late FakeSyncLogRepository fakeSyncLogRepo;

  setUp(() {
    settingsRepo = FakeAppSettingsRepository();
    storage = InMemorySecureStorage();
    runner = _FakeRunner();
    fakeDropbox = FakeDropboxProvider();
    fakeSyncLogRepo = FakeSyncLogRepository();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWith((_) async => settingsRepo),
        secureStorageProvider.overrideWithValue(storage),
        backupDataProvider.overrideWith((_) async => BackupData(runner)),
        restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
        cloudBackupProvider.overrideWithValue(fakeDropbox),
        syncLogRepositoryProvider.overrideWith((_) async => fakeSyncLogRepo),
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
    // Notifier must be in BackupConnected state; without an email the new
    // BackupNotConnected guard would early-return before reading the passphrase.
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
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
    // Notifier must be in BackupConnected state; without an email the
    // BackupNotConnected guard would early-return before calling the runner.
    await settingsRepo.updateBackupState(
      dropboxEmail: 'a@b.com',
      lastBackupAt: null,
    );
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
    // cloudBackupProvider is overridden in makeContainer() with fakeDropbox.
    // The fake's disconnect() is a no-op, matching the real DropboxProvider
    // behavior when no token is stored. The settings are cleared by the notifier.
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(backupNotifierProvider.future);
    await container.read(backupNotifierProvider.notifier).disconnect();
    final settings = await settingsRepo.getOrCreate();
    expect(settings.dropboxEmail, isNull);
    expect(settings.lastBackupAt, isNull);
    expect(storage.values.containsKey('metra_backup_passphrase_v1'), isFalse);
  });

  group('BackupNotifier.connect — existing backup check', () {
    test('connect() — empty Dropbox → BackupConnected(lastBackupAt: null)',
        () async {
      // fakeDropbox.currentEmailResult = 'user@example.com' (default)
      // fakeDropbox.files is empty (default)
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);
      await container.read(backupNotifierProvider.notifier).connect();
      final s = await container.read(backupNotifierProvider.future);
      expect(s, isA<BackupConnected>());
      expect((s as BackupConnected).lastBackupAt, isNull);
      expect(s.email, equals('user@example.com'));
    });

    test('connect() — one backup file → BackupConnected(lastBackupAt set)',
        () async {
      fakeDropbox.files['metra_backup_20260429T100000Z.enc'] = Uint8List(0);
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);
      await container.read(backupNotifierProvider.notifier).connect();
      final s = await container.read(backupNotifierProvider.future);
      expect(s, isA<BackupConnected>());
      expect(
        (s as BackupConnected).lastBackupAt,
        equals(DateTime.utc(2026, 4, 29, 10, 0, 0)),
      );
    });

    test('connect() — multiple files → lastBackupAt = newest', () async {
      // FakeDropboxProvider.listFiles() sorts desc, so newest is first.
      fakeDropbox.files['metra_backup_20260429T100000Z.enc'] = Uint8List(0);
      fakeDropbox.files['metra_backup_20260101T000000Z.enc'] = Uint8List(0);
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);
      await container.read(backupNotifierProvider.notifier).connect();
      final s = await container.read(backupNotifierProvider.future);
      expect(s, isA<BackupConnected>());
      expect(
        (s as BackupConnected).lastBackupAt,
        equals(DateTime.utc(2026, 4, 29, 10, 0, 0)),
      );
    });

    test('connect() — listFiles throws → connect succeeds, lastBackupAt: null',
        () async {
      fakeDropbox.failNextList = true;
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);
      await container.read(backupNotifierProvider.notifier).connect();
      final s = await container.read(backupNotifierProvider.future);
      expect(s, isA<BackupConnected>());
      expect((s as BackupConnected).lastBackupAt, isNull);
    });

    test('connect() — currentEmail returns null → BackupErrorState', () async {
      fakeDropbox.currentEmailResult = null;
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);
      await container.read(backupNotifierProvider.notifier).connect();
      final s = container.read(backupNotifierProvider).valueOrNull;
      expect(s, isA<BackupErrorState>());
    });
  });

  // -----------------------------------------------------------------------
  // Fix #1 — backupSilent early-return when BackupNotConnected
  // -----------------------------------------------------------------------
  group('Fix #1 — backupSilent early-return when BackupNotConnected', () {
    test(
      'backupSilent early-returns when state is BackupNotConnected — '
      'no _runBackup invocation and no secure-storage read',
      () async {
        // Arrange: notifier in BackupNotConnected state (no dropboxEmail).
        // Passphrase IS present in storage (the bug: without the guard,
        // backupSilent would read it and proceed to _runBackup).
        storage.values['metra_backup_passphrase_v1'] = 'cached-pass';

        final container = makeContainer();
        addTearDown(container.dispose);
        final initialState =
            await container.read(backupNotifierProvider.future);
        expect(
          initialState,
          isA<BackupNotConnected>(),
          reason: 'precondition: no dropboxEmail → BackupNotConnected',
        );

        // Act: backupSilent() with BackupNotConnected state.
        await container.read(backupNotifierProvider.notifier).backupSilent();

        // Assert: runner was never called.
        expect(
          runner.backupCalled,
          isFalse,
          reason: 'BackupNotConnected guard must prevent _runBackup invocation',
        );

        // Assert: state remains BackupNotConnected (no state corruption).
        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupNotConnected>(),
          reason: 'state must remain BackupNotConnected after early-return',
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // FR-14 notifier-layer early-return guard (NFR-10, EC-02)
  // -----------------------------------------------------------------------
  group('FR-14 notifier guard — backupSilent during BackupRunning', () {
    test(
      'given BackupRunning, backupSilent() is a no-op '
      '(runner not called again, state unchanged)',
      () async {
        // Arrange: notifier must start in BackupConnected so backupSilent
        // passes the BackupNotConnected guard and enters BackupRunning.
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        // Passphrase present so backupSilent proceeds to _runBackup.
        storage.values['metra_backup_passphrase_v1'] = 'test-pass';

        final releaser = Completer<void>();
        final blockingRunner = _BlockingRunner(releaser);

        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider
                .overrideWith((_) async => settingsRepo),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider
                .overrideWith((_) async => BackupData(blockingRunner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            cloudBackupProvider.overrideWithValue(fakeDropbox),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(() {
          if (!releaser.isCompleted) releaser.complete();
        });

        await container.read(backupNotifierProvider.future);

        // Start the first call but don't await it — notifier enters BackupRunning.
        unawaited(
          container.read(backupNotifierProvider.notifier).backupSilent(),
        );
        // Let microtasks run so the state transitions to BackupRunning.
        await Future<void>.delayed(Duration.zero);

        // Verify we are in BackupRunning before the second call.
        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupRunning>(),
        );
        final callCountBefore = blockingRunner.backupCallCount;

        // Act: second backupSilent() — must complete immediately (guard)
        // or time out if guard is missing.
        await container
            .read(backupNotifierProvider.notifier)
            .backupSilent()
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'backupSilent did not return within 3 s — '
                'early-return guard is missing',
              ),
            );

        // Assert: runner was NOT called again and state stays BackupRunning.
        expect(blockingRunner.backupCallCount, equals(callCountBefore));
        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupRunning>(),
        );

        // Cleanup: unblock the first call.
        releaser.complete();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('FR-14 notifier guard — backupWithPassphrase during BackupRunning', () {
    test(
      'given BackupRunning, backupWithPassphrase() is a no-op '
      '(runner not called, secureStorage not written)',
      () async {
        // Arrange: notifier must start in BackupConnected so backupSilent
        // passes the BackupNotConnected guard and drives us into BackupRunning.
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        // Passphrase present so backupSilent drives us into BackupRunning.
        storage.values['metra_backup_passphrase_v1'] = 'existing-pass';

        final releaser = Completer<void>();
        final blockingRunner = _BlockingRunner(releaser);
        // Track writes to secure storage.
        final trackingStorage = InMemorySecureStorage();
        trackingStorage.values['metra_backup_passphrase_v1'] = 'existing-pass';

        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider
                .overrideWith((_) async => settingsRepo),
            secureStorageProvider.overrideWithValue(trackingStorage),
            backupDataProvider
                .overrideWith((_) async => BackupData(blockingRunner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            cloudBackupProvider.overrideWithValue(fakeDropbox),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(() {
          if (!releaser.isCompleted) releaser.complete();
        });

        await container.read(backupNotifierProvider.future);

        // Drive the notifier into BackupRunning via backupSilent.
        unawaited(
          container.read(backupNotifierProvider.notifier).backupSilent(),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupRunning>(),
        );

        // Record the passphrase value BEFORE the second call.
        final passBefore = trackingStorage.values['metra_backup_passphrase_v1'];

        // Act: backupWithPassphrase during BackupRunning — must complete
        // immediately (guard returns early) or time out if guard is missing.
        await container
            .read(backupNotifierProvider.notifier)
            .backupWithPassphrase('any-pass')
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'backupWithPassphrase did not return within 3 s — '
                'early-return guard is missing',
              ),
            );

        // Assert: runner was not called again (count == 1 from the first call).
        expect(blockingRunner.backupCallCount, equals(1));
        // Assert: secure storage was NOT written (passphrase unchanged).
        expect(
          trackingStorage.values['metra_backup_passphrase_v1'],
          equals(passBefore),
        );
        // Assert: state is still BackupRunning.
        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupRunning>(),
        );

        releaser.complete();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  // -----------------------------------------------------------------------
  // FR-11 / FR-12 / FR-13 / FR-14 / FR-16 — backupSilent skip guard
  // -----------------------------------------------------------------------
  group('backupSilent skip guard', () {
    // Helper: seed the settingsRepo and storage, build a container, await
    // initialization, then return the container.
    Future<ProviderContainer> buildSkipContainer({
      required String? dropboxEmail,
      required DateTime? lastBackupAt,
      required DateTime? lastWriteAt,
      bool withPassphrase = true,
    }) async {
      // Set dropboxEmail and lastBackupAt via updateBackupState.
      if (dropboxEmail != null) {
        await settingsRepo.updateBackupState(
          dropboxEmail: dropboxEmail,
          lastBackupAt: lastBackupAt,
        );
      }
      // Set lastLogOrSymptomWriteAt via dedicated writer.
      if (lastWriteAt != null) {
        await settingsRepo.updateLastDataWriteAt(lastWriteAt);
      }
      if (withPassphrase) {
        storage.values['metra_backup_passphrase_v1'] = 'test-pass';
      }
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);
      return container;
    }

    // Case (a) FR-13: null lastLogOrSymptomWriteAt AND lastBackupAt set → skip
    test('skips when lastLogOrSymptomWriteAt is null and lastBackupAt is set',
        () async {
      final tb = DateTime.utc(2026, 5, 1, 10);
      final container = await buildSkipContainer(
        dropboxEmail: 'a@b.com',
        lastBackupAt: tb,
        lastWriteAt: null,
      );
      await container.read(backupNotifierProvider.notifier).backupSilent();
      expect(runner.backupCalled, isFalse);
    });

    // Case (b) FR-11: lastWriteAt == lastBackupAt exactly → skip (boundary)
    test('skips when lastWriteAt == lastBackupAt exactly (boundary)', () async {
      final t = DateTime.utc(2026, 5, 1, 10);
      final container = await buildSkipContainer(
        dropboxEmail: 'a@b.com',
        lastBackupAt: t,
        lastWriteAt: t,
      );
      await container.read(backupNotifierProvider.notifier).backupSilent();
      expect(runner.backupCalled, isFalse);
    });

    // Case (b) FR-11: lastWriteAt < lastBackupAt → skip
    test('skips when lastWriteAt is before lastBackupAt', () async {
      final tb = DateTime.utc(2026, 5, 1, 10);
      final tw = DateTime.utc(2026, 5, 1, 9);
      final container = await buildSkipContainer(
        dropboxEmail: 'a@b.com',
        lastBackupAt: tb,
        lastWriteAt: tw,
      );
      await container.read(backupNotifierProvider.notifier).backupSilent();
      expect(runner.backupCalled, isFalse);
    });

    // Case (c) FR-12: lastBackupAt == null → always proceed (even if lastWriteAt null)
    test('proceeds when lastBackupAt is null regardless of lastWriteAt',
        () async {
      final container = await buildSkipContainer(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
        lastWriteAt: null,
      );
      await container.read(backupNotifierProvider.notifier).backupSilent();
      expect(runner.backupCalled, isTrue);
    });

    // Case (d) FR-11 neg: lastWriteAt > lastBackupAt → proceed
    test('proceeds when lastWriteAt is after lastBackupAt', () async {
      final tb = DateTime.utc(2026, 5, 1, 9);
      final tw = DateTime.utc(2026, 5, 1, 10);
      final container = await buildSkipContainer(
        dropboxEmail: 'a@b.com',
        lastBackupAt: tb,
        lastWriteAt: tw,
      );
      await container.read(backupNotifierProvider.notifier).backupSilent();
      expect(runner.backupCalled, isTrue);
    });

    // FR-14: manual path ignores the guard
    test('backupWithPassphrase uploads even when skip condition holds',
        () async {
      final t = DateTime.utc(2026, 5, 1, 10);
      final container = await buildSkipContainer(
        dropboxEmail: 'a@b.com',
        lastBackupAt: t,
        lastWriteAt: t,
        withPassphrase: false, // backupWithPassphrase supplies its own
      );
      await container
          .read(backupNotifierProvider.notifier)
          .backupWithPassphrase('p');
      expect(runner.backupCalled, isTrue);
    });

    // FR-16: diagnostic log on skip
    test(
        'skip writes SyncLogEntity with operation backupSkipped '
        'and both timestamps in errorMessage', () async {
      final tb = DateTime.utc(2026, 5, 1, 10);
      final tw = DateTime.utc(2026, 4, 30, 9);
      final container = await buildSkipContainer(
        dropboxEmail: 'a@b.com',
        lastBackupAt: tb,
        lastWriteAt: tw,
      );
      await container.read(backupNotifierProvider.notifier).backupSilent();
      expect(fakeSyncLogRepo.appended, hasLength(1));
      final e = fakeSyncLogRepo.appended.last;
      expect(e.operation, SyncOperation.backupSkipped);
      expect(e.success, isTrue);
      expect(e.errorMessage, contains('lastWriteAt='));
      expect(e.errorMessage, contains('lastBackupAt='));
    });

    // No spurious log on proceed path
    test('proceed path does NOT append a backupSkipped entry', () async {
      final container = await buildSkipContainer(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
        lastWriteAt: null,
      );
      await container.read(backupNotifierProvider.notifier).backupSilent();
      expect(
        fakeSyncLogRepo.appended
            .where((e) => e.operation == SyncOperation.backupSkipped),
        isEmpty,
      );
    });
  });

  // -----------------------------------------------------------------------
  // TASK-07: integration group
  // -----------------------------------------------------------------------
  group('integration', () {
    // ----------------------------------------------------------------
    // Test 4 — Restore → cold-start no-reupload (NFR-06 / FR-15 / NFR-01)
    //
    // The runner's restore() simulates SyncOrchestrator.restore() alignment:
    // it sets lastLogOrSymptomWriteAt = lastBackupAt on the settings repo,
    // which is the contract verified in sync_orchestrator_test.dart
    // 'restore alignment' group. This test verifies the chain:
    //   restore() alignment → skip guard sees lastWriteAt == lastBackupAt
    //   → backupSilent() skips → 0 bytes uploaded (NFR-01).
    // ----------------------------------------------------------------
    test(
      'after successful restore, next backupSilent does not re-upload',
      () async {
        final tb = DateTime.utc(2026, 5, 1, 10, 0, 0);

        // Seed: connected Dropbox with lastBackupAt = T_b.
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: tb,
        );
        storage.values['metra_backup_passphrase_v1'] = 'test-pass';

        // A runner whose restore() aligns lastLogOrSymptomWriteAt to
        // lastBackupAt — mirrors SyncOrchestrator.restore() contract.
        final aligningRunner = _AligningRestoreRunner(settingsRepo, tb);

        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider
                .overrideWith((_) async => settingsRepo),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider.overrideWith((_) async => BackupData(runner)),
            restoreDataProvider
                .overrideWith((_) async => RestoreData(aligningRunner)),
            cloudBackupProvider.overrideWithValue(fakeDropbox),
            syncLogRepositoryProvider
                .overrideWith((_) async => fakeSyncLogRepo),
          ],
        );
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        // Action 1: restore (aligns lastLogOrSymptomWriteAt = lastBackupAt).
        await container.read(backupNotifierProvider.notifier).restore();
        expect(aligningRunner.restoreCalled, isTrue);

        // Verify alignment: lastLogOrSymptomWriteAt is now = lastBackupAt.
        final afterRestore = await settingsRepo.getOrCreate();
        expect(afterRestore.lastLogOrSymptomWriteAt, equals(tb));

        // Reset the backup runner flag so we can cleanly detect a second upload.
        runner.backupCalled = false;
        final filesBeforeSilent = Map<String, dynamic>.from(fakeDropbox.files);

        // Action 2: cold-start backupSilent — must skip because
        // lastWriteAt (= tb) is not after lastBackupAt (= tb).
        await container.read(backupNotifierProvider.notifier).backupSilent();

        // Assert: runner NOT called (NFR-01 — 0 new bytes uploaded).
        expect(
          runner.backupCalled,
          isFalse,
          reason: 'backupSilent should skip when lastWriteAt == lastBackupAt '
              'after restore alignment',
        );
        expect(
          fakeDropbox.files,
          equals(filesBeforeSilent),
          reason: 'NFR-01: no files should have been uploaded',
        );
      },
    );

    // ----------------------------------------------------------------
    // Test 5 — SyncLog purge clears backup_skipped entries (NFR-04 / FR-16)
    // ----------------------------------------------------------------
    test(
      'backup_skipped entries are cleared by SyncLogRepository.deleteAll()',
      () async {
        final tb = DateTime.utc(2026, 5, 1, 10, 0, 0);
        final tw = DateTime.utc(2026, 4, 30, 9, 0, 0);

        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: tb,
        );
        await settingsRepo.updateLastDataWriteAt(tw);
        storage.values['metra_backup_passphrase_v1'] = 'test-pass';

        final container = makeContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        // Trigger skip → one backupSkipped entry appended.
        await container.read(backupNotifierProvider.notifier).backupSilent();
        expect(
          fakeSyncLogRepo.appended
              .where((e) => e.operation == SyncOperation.backupSkipped),
          hasLength(1),
          reason: 'precondition: one backupSkipped entry should exist',
        );

        // Act: "Clear diagnostic logs" path — deleteAll() on the sync log repo.
        await fakeSyncLogRepo.deleteAll();

        // Assert: log is empty.
        expect(
          fakeSyncLogRepo.appended,
          isEmpty,
          reason: 'all log entries should be removed after deleteAll()',
        );
      },
    );

    // ----------------------------------------------------------------
    // Test 6 — _BlockingRunner concurrency: BackupRunning guard fires
    // before the skip guard (EC-08)
    //
    // The first backupSilent() must PROCEED (so lastWriteAt > lastBackupAt),
    // enter _runBackup(), and block. The second call must return immediately
    // via the BackupRunning guard — NOT via the skip guard — so no
    // backupSkipped entry is appended.
    // ----------------------------------------------------------------
    test(
      'second backupSilent during a blocked first call returns immediately '
      'via BackupRunning guard, not skip guard',
      () async {
        // Seed: lastWriteAt > lastBackupAt so the FIRST call proceeds.
        final tb = DateTime.utc(2026, 5, 1, 9, 0, 0);
        final tw = DateTime.utc(2026, 5, 1, 10, 0, 0);
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: tb,
        );
        await settingsRepo.updateLastDataWriteAt(tw);
        storage.values['metra_backup_passphrase_v1'] = 'test-pass';

        final releaser = Completer<void>();
        final blockingRunner = _BlockingRunner(releaser);

        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider
                .overrideWith((_) async => settingsRepo),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider
                .overrideWith((_) async => BackupData(blockingRunner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            cloudBackupProvider.overrideWithValue(fakeDropbox),
            syncLogRepositoryProvider
                .overrideWith((_) async => fakeSyncLogRepo),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(() {
          if (!releaser.isCompleted) releaser.complete();
        });

        await container.read(backupNotifierProvider.future);

        // First call: proceeds (lastWriteAt > lastBackupAt), enters BackupRunning.
        unawaited(
          container.read(backupNotifierProvider.notifier).backupSilent(),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupRunning>(),
          reason: 'first call must have entered BackupRunning',
        );
        expect(blockingRunner.backupCallCount, 1);

        // Second call: must return immediately via BackupRunning guard.
        await container
            .read(backupNotifierProvider.notifier)
            .backupSilent()
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'second backupSilent did not return within 3 s — '
                'BackupRunning guard may be missing',
              ),
            );

        // Runner was called exactly once (the first call, blocked).
        expect(
          blockingRunner.backupCallCount,
          1,
          reason: 'runner must be called exactly once',
        );

        // No backupSkipped entry: the second call was stopped by BackupRunning,
        // not the skip guard.
        expect(
          fakeSyncLogRepo.appended
              .where((e) => e.operation == SyncOperation.backupSkipped),
          isEmpty,
          reason: 'BackupRunning guard must fire before the skip guard — '
              'no backupSkipped entry should be appended',
        );

        // Unblock the first call.
        releaser.complete();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  // -----------------------------------------------------------------------
  // TASK-16 — HC-2 / FR-12d / R-M3-A / EC-02 / EC-10
  // sentinel read PRECEDES any secure-storage operation
  // -----------------------------------------------------------------------
  group('TASK-16 — backupSuspended sentinel guard', () {
    test('FR-12d — backupSilent skips when suspended', () async {
      await settingsRepo.updateBackupSuspended(true);
      await settingsRepo.updateBackupState(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
      );
      storage.values['metra_backup_passphrase_v1'] = 'existing-pass';

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      await container.read(backupNotifierProvider.notifier).backupSilent();

      expect(runner.backupCalled, isFalse);
      expect(
        fakeSyncLogRepo.appended.last.operation,
        equals(SyncOperation.backupSkipped),
      );
      expect(
        fakeSyncLogRepo.appended.last.errorMessage,
        equals('skipped: backupSuspended=true'),
      );
    });

    test(
        'HC-2 / R-M3-A — backupWithPassphrase: clears suspended sentinel then '
        'writes passphrase (BUG-B02: manual tap is the resume path)', () async {
      await settingsRepo.updateBackupSuspended(true);
      await settingsRepo.updateBackupState(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      // Reset counters after build() completes.
      storage.resetCallCounts();
      settingsRepo.callLog.clear();

      await container
          .read(backupNotifierProvider.notifier)
          .backupWithPassphrase('new-pass');

      // BUG-B02: manual tap IS the resume path.
      // clearBackupSuspended() must be called (HC-2: before any storage write).
      expect(
        settingsRepo.callLog,
        contains('clearBackupSuspended'),
        reason:
            'clearBackupSuspended must be called before any secure-storage op',
      );
      // Passphrase must be written after clearing the sentinel.
      expect(storage.writeCount, greaterThan(0));
      // No backupSkipped entry — the user-driven tap is succeeding.
      expect(
        fakeSyncLogRepo.appended
            .where((e) => e.operation == SyncOperation.backupSkipped),
        isEmpty,
      );
    });

    test(
        'EC-02 (revised BUG-B02) — backupWithPassphrase when suspended clears '
        'sentinel and overwrites passphrase (resume path)', () async {
      await settingsRepo.updateBackupSuspended(true);
      await settingsRepo.updateBackupState(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
      );
      storage.values['metra_backup_passphrase_v1'] = 'old-pass';

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      await container
          .read(backupNotifierProvider.notifier)
          .backupWithPassphrase('new-pass');

      // BUG-B02: manual tap resumes — the new passphrase must be written,
      // not the old one preserved. The sentinel is cleared first (HC-2).
      expect(
        storage.values['metra_backup_passphrase_v1'],
        equals('new-pass'),
        reason: 'After clearing the suspended sentinel, backupWithPassphrase '
            'must write the new passphrase (not preserve the old one)',
      );
      // Sentinel cleared.
      final s = await settingsRepo.getOrCreate();
      expect(s.backupSuspended, isFalse);
    });

    test(
        'EC-10 (revised BUG-B02) — backupWithPassphrase when suspended: '
        'backup runner is invoked and sentinel is cleared', () async {
      await settingsRepo.updateBackupSuspended(true);
      await settingsRepo.updateBackupState(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
      );
      storage.values['metra_backup_passphrase_v1'] = 'old-pass';

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      // Reset counters AFTER build() completes so we only count calls inside
      // backupWithPassphrase() itself.
      storage.resetCallCounts();
      settingsRepo.callLog.clear();

      await container
          .read(backupNotifierProvider.notifier)
          .backupWithPassphrase('new-pass');

      // BUG-B02: manual tap is the resume path. Sentinel cleared before storage.
      expect(
        settingsRepo.callLog,
        contains('clearBackupSuspended'),
        reason: 'clearBackupSuspended must be called (HC-2 ordering)',
      );
      // Passphrase written (backup runner invoked).
      expect(
        storage.writeCount,
        greaterThan(0),
        reason: 'Passphrase write must proceed after clearing sentinel',
      );
      expect(
        runner.backupCalled,
        isTrue,
        reason:
            'Backup runner must be called when suspended sentinel is cleared',
      );
    });

    test('Regression: existing write-recency skip-guard still works', () async {
      // backupSuspended = false (default), so the suspended guard does not fire.
      await settingsRepo.updateBackupState(
        dropboxEmail: 'a@b.com',
        lastBackupAt: DateTime.utc(2026, 5, 17, 12),
      );
      await settingsRepo.updateLastDataWriteAt(
        DateTime.utc(2026, 5, 17, 11),
      ); // older than lastBackupAt — should skip
      storage.values['metra_backup_passphrase_v1'] = 'existing-pass';

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      await container.read(backupNotifierProvider.notifier).backupSilent();

      expect(runner.backupCalled, isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // TASK-17 — FR-14a / §5.1.10 — restoreWithPassphrase filename forwarding
  // -----------------------------------------------------------------------
  group('TASK-17 — restoreWithPassphrase filename forwarding', () {
    test('FR-14a — restoreWithPassphrase forwards filename', () async {
      await settingsRepo.updateBackupState(
        dropboxEmail: 'a@b.com',
        lastBackupAt: null,
      );
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);
      await container
          .read(backupNotifierProvider.notifier)
          .restoreWithPassphrase(
            'pass',
            filename: 'metra_backup_20260517T120000Z_abc123.enc',
          );
      expect(
        runner.lastFilename,
        equals('metra_backup_20260517T120000Z_abc123.enc'),
      );
    });

    test('FR-14a null — restoreWithPassphrase(filename: null) preserves legacy',
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
          .restoreWithPassphrase('pass', filename: null);
      expect(runner.lastFilename, isNull);
      expect(runner.restoreCallCount, equals(1));
    });
  });

  // -----------------------------------------------------------------------
  // FR-17 / BUG-C04 — debugPrint in connect() catch block
  // -----------------------------------------------------------------------
  group('FR-17 — connect() catch block emits debugPrint', () {
    late List<String> captured;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      captured = [];
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) captured.add(message);
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test(
      'given authorize throws SocketException, '
      'debugPrint is emitted BEFORE state transitions to BackupErrorState',
      () async {
        final throwing = _ThrowingDropboxProvider(
          const SocketException('boom'),
        );
        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider
                .overrideWith((_) async => settingsRepo),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider.overrideWith((_) async => BackupData(runner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            cloudBackupProvider.overrideWithValue(throwing),
          ],
        );
        addTearDown(container.dispose);

        // Track event ordering: record a tag whenever state becomes an error.
        final events = <String>[];

        // Override debugPrint to also record into events.
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) {
            captured.add(message);
            events.add('print:$message');
          }
        };
        container.listen<AsyncValue<BackupState>>(
          backupNotifierProvider,
          (_, next) {
            if (next.valueOrNull is BackupErrorState) {
              events.add('state:BackupErrorState');
            }
          },
        );

        await container.read(backupNotifierProvider.future);
        await container.read(backupNotifierProvider.notifier).connect();

        // Verify the debugPrint line was emitted.
        final printLine = captured.firstWhere(
          (l) =>
              l.contains('[BackupNotifier.connect]') &&
              l.contains('SocketException') &&
              l.contains('boom'),
          orElse: () => '',
        );
        expect(
          printLine,
          isNotEmpty,
          reason:
              'Expected a debugPrint line containing [BackupNotifier.connect], '
              'SocketException, and boom',
        );

        // Verify state transitioned to BackupErrorState.
        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupErrorState>(),
        );

        // Verify ordering: print event precedes error-state event.
        final printIdx = events.indexWhere((e) => e.startsWith('print:'));
        final stateIdx =
            events.indexWhere((e) => e == 'state:BackupErrorState');
        expect(
          printIdx,
          lessThan(stateIdx),
          reason: 'debugPrint must be emitted before state transitions to '
              'BackupErrorState',
        );
      },
    );

    test(
      'given authorize throws SyncException (MetraException subclass), '
      'BackupErrorState.message == e.message '
      'AND debugPrint is still emitted',
      () async {
        final throwing = _ThrowingDropboxProvider(
          const SyncException('custom error'),
        );
        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider
                .overrideWith((_) async => settingsRepo),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider.overrideWith((_) async => BackupData(runner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            cloudBackupProvider.overrideWithValue(throwing),
          ],
        );
        addTearDown(container.dispose);

        await container.read(backupNotifierProvider.future);
        await container.read(backupNotifierProvider.notifier).connect();

        // Verify user-visible error message uses e.message (not the generic string).
        final s = container.read(backupNotifierProvider).valueOrNull;
        expect(s, isA<BackupErrorState>());
        expect((s as BackupErrorState).message, equals('custom error'));

        // Verify debugPrint was still emitted (unconditional, not branched).
        final printLine = captured.firstWhere(
          (l) => l.contains('[BackupNotifier.connect]'),
          orElse: () => '',
        );
        expect(
          printLine,
          isNotEmpty,
          reason:
              'Expected a debugPrint line containing [BackupNotifier.connect] '
              'even for MetraException (SyncException) paths',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // TASK-06 — Group E: backupNow() + autoBackupActive
  // -------------------------------------------------------------------------

  group('TASK-06 — backupNow + autoBackupActive', () {
    // E-01: BackupRunning guard
    test(
      'E-01: backupNow is a no-op when already in BackupRunning',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        storage.values['metra_backup_passphrase_v1'] = 'test-pass';

        final releaser = Completer<void>();
        final blockingRunner = _BlockingRunner(releaser);

        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider
                .overrideWith((_) async => settingsRepo),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider
                .overrideWith((_) async => BackupData(blockingRunner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            cloudBackupProvider.overrideWithValue(fakeDropbox),
            syncLogRepositoryProvider
                .overrideWith((_) async => fakeSyncLogRepo),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(() {
          if (!releaser.isCompleted) releaser.complete();
        });

        await container.read(backupNotifierProvider.future);

        // First call blocks inside BackupRunning.
        unawaited(
          container.read(backupNotifierProvider.notifier).backupNow(),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupRunning>(),
        );
        final callCountBefore = blockingRunner.backupCallCount;

        // Second call must return immediately (guard).
        await container
            .read(backupNotifierProvider.notifier)
            .backupNow()
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'backupNow did not return within 3 s — '
                'BackupRunning guard is missing',
              ),
            );

        expect(blockingRunner.backupCallCount, equals(callCountBefore));
        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupRunning>(),
        );

        releaser.complete();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    // E-02: BackupNotConnected guard
    test(
      'E-02: backupNow is a no-op when BackupNotConnected',
      () async {
        // No email → build() emits BackupNotConnected.
        final container = makeContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container.read(backupNotifierProvider.notifier).backupNow();

        expect(runner.backupCalled, isFalse);
        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupNotConnected>(),
        );
      },
    );

    // E-03: backupSuspended guard — BUG-B02: manual tap is the resume path.
    // clearBackupSuspended() is called, then backup proceeds.
    test(
      'E-03 (BUG-B02): backupNow clears suspended sentinel and runs backup',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        await settingsRepo.updateBackupSuspended(true);
        storage.values['metra_backup_passphrase_v1'] = 'test-pass';
        settingsRepo.callLog.clear();

        final container = makeContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        settingsRepo.callLog.clear(); // clear build() artifacts

        await container.read(backupNotifierProvider.notifier).backupNow();

        // Sentinel cleared (HC-2: before any secureStorage read).
        expect(
          settingsRepo.callLog,
          contains('clearBackupSuspended'),
          reason: 'clearBackupSuspended must be called by backupNow()',
        );
        // Backup runs.
        expect(
          runner.backupCalled,
          isTrue,
          reason:
              'backupNow() must call the backup runner after clearing sentinel',
        );
        // No skip log entry.
        expect(
          fakeSyncLogRepo.appended
              .where((e) => e.operation == SyncOperation.backupSkipped),
          isEmpty,
          reason: 'backupNow() must not log a skip entry (user tap succeeds)',
        );
      },
    );

    // E-04: null passphrase guard — silent return, no backup
    test(
      'E-04: backupNow returns silently when passphrase is null',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        // storage has NO passphrase key.

        final container = makeContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container.read(backupNotifierProvider.notifier).backupNow();

        expect(runner.backupCalled, isFalse);
      },
    );

    // E-05: write-recency bypass — backupNow runs even when nothing is new
    test(
      'E-05: backupNow bypasses write-recency guard and calls runner',
      () async {
        final tb = DateTime.utc(2026, 5, 1);
        // lastBackupAt > lastLogOrSymptomWriteAt → backupSilent would skip.
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: tb.add(const Duration(hours: 1)),
        );
        // lastLogOrSymptomWriteAt is null (never written) — backupSilent skips.
        storage.values['metra_backup_passphrase_v1'] = 'test-pass';

        final container = makeContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container.read(backupNotifierProvider.notifier).backupNow();

        // backupNow must call the runner despite no new writes.
        expect(runner.backupCalled, isTrue);
      },
    );

    // E-06: FR-19 — backupNow never writes to secure storage
    test(
      'E-06: backupNow does not write to secure storage (FR-19)',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        storage.values['metra_backup_passphrase_v1'] = 'existing-pass';
        storage.resetCallCounts();

        final container = makeContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container.read(backupNotifierProvider.notifier).backupNow();

        expect(
          storage.writeCount,
          isZero,
          reason: 'backupNow must never write to secure storage (FR-19)',
        );
      },
    );

    // E-07: autoBackupActive projection
    // BUG-01 fix: autoBackupActive is now conjunctive — requires both
    // !backupSuspended AND passphraseSet. Seed storage with a passphrase.
    test(
      'E-07: autoBackupActive is true when backupSuspended=false and passphrase set',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        // backupSuspended defaults to false.
        // Passphrase must also be present (BUG-01 fix).
        storage.values[BackupNotifier.kPassphraseKey] = 'pw';

        final container = makeContainer();
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);

        expect(s, isA<BackupConnected>());
        expect((s as BackupConnected).autoBackupActive, isTrue);
      },
    );

    test(
      'E-07b: autoBackupActive is false when backupSuspended=true',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        await settingsRepo.updateBackupSuspended(true);

        final container = makeContainer();
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);

        expect(s, isA<BackupConnected>());
        expect((s as BackupConnected).autoBackupActive, isFalse);
      },
    );

    // E-08: _handleBackup routing — covered in backup_screen_test.dart (E-08)
    // The notifier-layer portion is fully exercised by E-01 through E-06 above.
  });

  // -----------------------------------------------------------------------
  // BUG-B01 — build() is reactive to Drift stream
  // Verifies that BackupNotifier.build() watches the Drift stream via
  // appSettingsStreamProvider so that a backupSuspended write is reflected
  // without a cold restart.
  // -----------------------------------------------------------------------
  group('BUG-B01 — build() reflects backupSuspended write reactively', () {
    test(
      'build_reflects_backupSuspended_after_drift_stream_emit',
      () async {
        // Setup: real DriftAppSettingsRepository over an in-memory Drift DB.
        // The real repo's watchSettings() emits whenever backupSuspended changes.
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final realRepo = DriftAppSettingsRepository(db.appSettingsDao);

        // Pre-seed: create the settings row first, then set email.
        // updateBackupState uses a raw UPDATE that requires the row to exist.
        await realRepo.getOrCreate();
        await realRepo.updateBackupState(
          dropboxEmail: 'a@b.test',
          lastBackupAt: null,
        );
        // backupSuspended defaults to false.

        final storage = InMemorySecureStorage();
        storage.values[BackupNotifier.kPassphraseKey] = 'pw';

        // Wire the container: appSettingsRepositoryProvider uses the real repo
        // (which the real appSettingsStreamProvider will pull from automatically).
        // Do NOT override appSettingsStreamProvider with a fake — the whole point
        // of this test is to verify the real stream propagates writes.
        final fakeDropbox = FakeDropboxProvider();
        final fakeSyncLogRepo = FakeSyncLogRepository();
        final fakeRunner = _FakeRunner();

        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider.overrideWith((_) async => realRepo),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider
                .overrideWith((_) async => BackupData(fakeRunner)),
            restoreDataProvider
                .overrideWith((_) async => RestoreData(fakeRunner)),
            cloudBackupProvider.overrideWithValue(fakeDropbox),
            syncLogRepositoryProvider
                .overrideWith((_) async => fakeSyncLogRepo),
          ],
        );
        addTearDown(container.dispose);

        // Act 1: initial build.
        final s1 = await container.read(backupNotifierProvider.future);
        expect(s1, isA<BackupConnected>());
        expect(
          (s1 as BackupConnected).autoBackupActive,
          isTrue,
          reason:
              'precondition: email set, suspended=false, passphrase present '
              '→ autoBackupActive must be true',
        );

        // Act 2: write backupSuspended=true directly on the real repo.
        // This fires the Drift stream which triggers appSettingsStreamProvider
        // to re-emit, which triggers build() to re-run.
        await realRepo.updateBackupSuspended(true);

        // Pump to let the Drift stream emit and the StreamProvider propagate.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Assert 2: notifier re-built; autoBackupActive is now false.
        final s2 = await container.read(backupNotifierProvider.future);
        expect(s2, isA<BackupConnected>());
        expect(
          (s2 as BackupConnected).autoBackupActive,
          isFalse,
          reason:
              'BUG-B01: after backupSuspended=true written to the real Drift '
              'repo, the Drift stream should re-trigger build(), flipping '
              'autoBackupActive to false without a cold restart',
        );
        expect(
          s2.passphraseSet,
          isTrue,
          reason: 'passphraseSet must remain true — passphrase unchanged',
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // BUG-B04 — connect() clears backupSuspended before invalidateSelf()
  // Verifies that after a wipe (backupSuspended=true), reconnecting via
  // connect() clears the sentinel so the user is not permanently suspended.
  //
  // Uses a real DriftAppSettingsRepository over an in-memory DB so that
  // the reactive appSettingsStreamProvider emits updated values after
  // connect() mutates the repo — same pattern as BUG-B01 test.
  // -----------------------------------------------------------------------
  group('BUG-B04 — connect() clears backupSuspended before invalidate', () {
    test(
      'connect_clears_backupSuspended_before_invalidate',
      () async {
        // Setup: real DriftAppSettingsRepository over an in-memory Drift DB.
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final realRepo = DriftAppSettingsRepository(db.appSettingsDao);

        // Repo pre-state: suspended post-wipe. No email (not yet connected).
        await realRepo.getOrCreate();
        await realRepo.updateBackupSuspended(true);
        // email defaults to null — BackupNotConnected.

        final storage = InMemorySecureStorage();
        // No passphrase stored — freshly wiped state.

        final fakeDrpbx = FakeDropboxProvider();
        fakeDrpbx.currentEmailResult = 'a@b.test';
        // fakeDrpbx.files is empty → listFiles() returns [].

        final fakeSyncLog = FakeSyncLogRepository();
        final fakeRunner = _FakeRunner();

        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider.overrideWith((_) async => realRepo),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider
                .overrideWith((_) async => BackupData(fakeRunner)),
            restoreDataProvider
                .overrideWith((_) async => RestoreData(fakeRunner)),
            cloudBackupProvider.overrideWithValue(fakeDrpbx),
            syncLogRepositoryProvider.overrideWith((_) async => fakeSyncLog),
          ],
        );
        addTearDown(container.dispose);

        // Initial build: email=null → BackupNotConnected.
        final initialState =
            await container.read(backupNotifierProvider.future);
        expect(
          initialState,
          isA<BackupNotConnected>(),
          reason: 'precondition: no email → BackupNotConnected',
        );

        // Act: connect().
        await container.read(backupNotifierProvider.notifier).connect();

        // Let the Drift stream propagate the email + suspended=false writes.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Assert 1: suspended sentinel cleared (via real repo read).
        final settings = await realRepo.getOrCreate();
        expect(
          settings.backupSuspended,
          isFalse,
          reason: 'BUG-B04: connect() must call clearBackupSuspended() so the '
              'user is not stuck in suspended state after reconnecting',
        );

        // Assert 2: final state is BackupConnected(autoBackupActive: false,
        // passphraseSet: false) — false because no passphrase stored, NOT
        // because still suspended.
        final s = await container.read(backupNotifierProvider.future);
        expect(s, isA<BackupConnected>());
        final connected = s as BackupConnected;
        expect(
          connected.email,
          equals('a@b.test'),
          reason: 'email should be set from connect()',
        );
        expect(
          connected.autoBackupActive,
          isFalse,
          reason: 'no passphrase → autoBackupActive must be false',
        );
        expect(
          connected.passphraseSet,
          isFalse,
          reason: 'no passphrase stored → passphraseSet must be false',
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // TASK-09 — FR-18, FR-19, FR-23
  // Connected-predicate seam, skip-log provider literal swaps, passphrase
  // constant (FR-23 closure).
  // -----------------------------------------------------------------------
  group('TASK-09 — FR-18 / FR-19 / FR-23', () {
    // ----------------------------------------------------------------
    // Static-analysis grep tests — verify code properties, not runtime values.
    // These must FAIL before the refactor and PASS after.
    // ----------------------------------------------------------------

    test(
      'FR-23 static: backup_notifier.dart contains no "metra_backup_passphrase_v1" '
      'string literal (must delegate to AppConstants.kBackupPassphraseKey)',
      () async {
        final file = File(
          'lib/features/backup/state/backup_notifier.dart',
        );
        final content = await file.readAsString();
        expect(
          content,
          isNot(contains("'metra_backup_passphrase_v1'")),
          reason:
              'FR-23: the literal "metra_backup_passphrase_v1" must be removed '
              'from backup_notifier.dart — only AppConstants.kBackupPassphraseKey '
              'may carry the value',
        );
      },
    );

    test(
      'FR-18 static: backup_notifier.dart contains no "SyncProvider.dropbox" '
      'literals at the skip-log sites in backupSilent() '
      '(must use settings.activeProvider)',
      () async {
        final file = File(
          'lib/features/backup/state/backup_notifier.dart',
        );
        final content = await file.readAsString();
        // After the refactor the file may still reference SyncProvider.dropbox
        // in comments or other contexts, but the count of occurrences inside
        // backupSilent() at the SyncLogEntity provider: argument must be 0.
        // We assert total occurrences of the literal in backupSilent are 0
        // by checking that no "provider: SyncProvider.dropbox" appears in
        // the file (the only production usage was the two skip-log sites).
        expect(
          content,
          isNot(contains('provider: SyncProvider.dropbox')),
          reason: 'FR-18: the two "provider: SyncProvider.dropbox" literals in '
              'backupSilent() must be replaced with settings.activeProvider; '
              'no "provider: SyncProvider.dropbox" must remain in the file',
        );
      },
    );

    test(
      'FR-19 static: backup_notifier.dart has no inline "dropboxEmail == null" '
      'and settings_screen.dart has no inline dropboxEmail checks '
      '(predicate behind a single _isConnected seam)',
      () async {
        final notifierFile = File(
          'lib/features/backup/state/backup_notifier.dart',
        );
        final settingsFile = File(
          'lib/features/settings/settings_screen.dart',
        );
        final notifierContent = await notifierFile.readAsString();
        final settingsContent = await settingsFile.readAsString();

        // The positive-null form ("== null") must be completely absent from
        // the notifier — the seam definition uses the negative form ("!= null")
        // and that is the single allowed occurrence of the predicate body.
        expect(
          notifierContent,
          isNot(contains('dropboxEmail == null')),
          reason: 'FR-19: inline "dropboxEmail == null" must be removed from '
              'backup_notifier.dart — only _isConnected may derive the predicate',
        );
        // The seam (_isConnected) must exist — verify the production expression
        // "settings.dropboxEmail != null" is present exactly once.
        // (Doc-comment occurrences of the bare form "dropboxEmail != null" are
        // allowed and not counted here — we grep for the qualified form.)
        final seamCount =
            'settings.dropboxEmail != null'.allMatches(notifierContent).length;
        expect(
          seamCount,
          equals(1),
          reason:
              'FR-19: "settings.dropboxEmail != null" must appear exactly once '
              'in backup_notifier.dart — the _isConnected seam body. '
              'Actual count: $seamCount',
        );
        // settings_screen.dart must have zero occurrences of either form.
        expect(
          settingsContent,
          isNot(contains('dropboxEmail == null')),
          reason:
              'FR-19: no inline dropboxEmail checks in settings_screen.dart',
        );
        expect(
          settingsContent,
          isNot(contains('dropboxEmail != null')),
          reason:
              'FR-19: no inline dropboxEmail checks in settings_screen.dart',
        );
      },
    );

    // FR-23 closure: kPassphraseKey resolves to the right string value;
    // the constant in AppConstants must also match.
    test(
      'FR-23: BackupNotifier.kPassphraseKey value equals '
      'AppConstants.kBackupPassphraseKey (same storage key, no literal in notifier)',
      () {
        // The constant must resolve to the canonical key so that
        // secure-storage reads/writes are byte-identical before and after
        // this refactor.  The notifier exposes kPassphraseKey publicly
        // so callers (e.g. BackupScreen) can read the cached value without
        // hardcoding the string; that value must equal AppConstants.kBackupPassphraseKey.
        expect(
          BackupNotifier.kPassphraseKey,
          equals(AppConstants.kBackupPassphraseKey),
          reason:
              'FR-23: kPassphraseKey must delegate to AppConstants.kBackupPassphraseKey '
              '— the resolved value must remain "metra_backup_passphrase_v1"',
        );
        // Belt-and-suspenders: verify the canonical value itself is unchanged.
        expect(
          BackupNotifier.kPassphraseKey,
          equals('metra_backup_passphrase_v1'),
          reason: 'the resolved storage key must stay byte-identical to the '
              'historic value to preserve existing KeyChain/Encrypted-SharedPrefs entries',
        );
      },
    );

    // FR-19: connected-predicate Dropbox-correct — non-null email → connected,
    // null → disconnected.  This verifies the predicate seam produces the
    // correct result without testing its internal implementation.
    test(
      'FR-19: non-null dropboxEmail resolves to BackupConnected (seam correct)',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.test',
          lastBackupAt: null,
        );
        final container = makeContainer();
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);
        expect(
          s,
          isA<BackupConnected>(),
          reason: 'FR-19: non-null dropboxEmail → seam must report connected; '
              'BackupConnected expected',
        );
      },
    );

    test(
      'FR-19: null dropboxEmail resolves to BackupNotConnected (seam correct)',
      () async {
        // No updateBackupState call → dropboxEmail stays null.
        final container = makeContainer();
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);
        expect(
          s,
          isA<BackupNotConnected>(),
          reason: 'FR-19: null dropboxEmail → seam must report disconnected; '
              'BackupNotConnected expected',
        );
      },
    );

    // FR-18: skip-log entries carry the active-provider id, not a hardcoded
    // SyncProvider.dropbox literal.  In M1 the active provider IS dropbox, so
    // the observable value is the same — but it must come from settings, not
    // a compile-time literal.
    test(
      'FR-18: backupSuspended skip-log entry carries active provider id '
      '(dropbox in M1 — read from settings, not hardcoded)',
      () async {
        // Seed: connected, suspended.
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: null,
        );
        await settingsRepo.updateBackupSuspended(true);
        storage.values[BackupNotifier.kPassphraseKey] = 'pw';

        final container = makeContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container.read(backupNotifierProvider.notifier).backupSilent();

        expect(fakeSyncLogRepo.appended, hasLength(1));
        final entry = fakeSyncLogRepo.appended.last;
        expect(
          entry.provider,
          equals(SyncProvider.dropbox),
          reason: 'FR-18: in M1 active provider is dropbox — skip-log provider '
              'must equal SyncProvider.dropbox',
        );
        expect(
          entry.operation,
          equals(SyncOperation.backupSkipped),
        );
      },
    );

    test(
      'FR-18: write-recency skip-log entry carries active provider id '
      '(dropbox in M1 — read from settings, not hardcoded)',
      () async {
        // Seed: lastWriteAt < lastBackupAt → write-recency skip fires.
        final tb = DateTime.utc(2026, 6, 1, 10);
        final tw = DateTime.utc(2026, 6, 1, 9);
        await settingsRepo.updateBackupState(
          dropboxEmail: 'a@b.com',
          lastBackupAt: tb,
        );
        await settingsRepo.updateLastDataWriteAt(tw);
        storage.values[BackupNotifier.kPassphraseKey] = 'pw';

        final container = makeContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container.read(backupNotifierProvider.notifier).backupSilent();

        expect(fakeSyncLogRepo.appended, hasLength(1));
        final entry = fakeSyncLogRepo.appended.last;
        expect(
          entry.provider,
          equals(SyncProvider.dropbox),
          reason:
              'FR-18: in M1 active provider is dropbox — write-recency skip-log '
              'provider must equal SyncProvider.dropbox',
        );
        expect(
          entry.operation,
          equals(SyncOperation.backupSkipped),
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // TASK-07 — Group I + Scenario Group D
  // Connected-predicate generalisation + nullable BackupConnected.email
  // FR-15, FR-16, NFR-06
  // -----------------------------------------------------------------------
  group('TASK-07 — connected-predicate generalisation (FR-15/FR-16/NFR-06)',
      () {
    // Helper that wires the iCloud fake as the active cloud provider.
    ProviderContainer makeIcloudContainer(FakeICloudProvider iCloudProvider) {
      return ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider.overrideWith((_) async => settingsRepo),
          secureStorageProvider.overrideWithValue(storage),
          backupDataProvider.overrideWith((_) async => BackupData(runner)),
          restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
          cloudBackupProvider.overrideWithValue(iCloudProvider),
          syncLogRepositoryProvider.overrideWith((_) async => fakeSyncLogRepo),
        ],
      );
    }

    // I-01 EC-11: iCloud connected (authorize succeeds) → _isConnected true
    //             → build() emits BackupConnected
    test(
      'I-01 EC-11: iCloud connected (authorize succeeds) → BackupConnected',
      () async {
        await settingsRepo.setActiveProvider(SyncProvider.iCloud);
        final container = makeIcloudContainer(
          FakeICloudProvider(authorizeThrows: false),
        );
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);
        expect(
          s,
          isA<BackupConnected>(),
          reason:
              'EC-11: iCloud authorize() success → _isConnected must return '
              'true (probe, not dropboxEmail check)',
        );
      },
    );

    // I-02 EC-07/NFR-06: iCloud signed-out (authorize throws SyncException)
    //                     → BackupNotConnected; no exception escapes build()
    test(
      'I-02 EC-07/NFR-06: iCloud signed-out (authorize throws SyncException) '
      '→ BackupNotConnected, no exception escapes build()',
      () async {
        await settingsRepo.setActiveProvider(SyncProvider.iCloud);
        final container = makeIcloudContainer(
          FakeICloudProvider(authorizeThrows: true),
        );
        addTearDown(container.dispose);
        // If an exception escaped build() this would throw rather than returning
        // a BackupNotConnected.
        final s = await container.read(backupNotifierProvider.future);
        expect(
          s,
          isA<BackupNotConnected>(),
          reason: 'EC-07/NFR-06: SyncException from authorize() must be caught '
              'locally; signed-out iCloud reports not-connected',
        );
      },
    );

    // I-03 EC-12: dropbox email present → BackupConnected (no regression)
    test(
      'I-03 EC-12 regression: dropbox email present → BackupConnected',
      () async {
        // activeProvider defaults to SyncProvider.dropbox
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.test',
          lastBackupAt: null,
        );
        final container = makeIcloudContainer(FakeICloudProvider());
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);
        expect(
          s,
          isA<BackupConnected>(),
          reason: 'EC-12: dropbox email present → connected predicate must '
              'return true (email-sentinel path unchanged)',
        );
      },
    );

    // I-04 EC-12: dropbox no email → BackupNotConnected (no regression)
    test(
      'I-04 EC-12 regression: dropbox no email → BackupNotConnected',
      () async {
        // No email, activeProvider = dropbox (default)
        final container = makeIcloudContainer(FakeICloudProvider());
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);
        expect(
          s,
          isA<BackupNotConnected>(),
          reason: 'EC-12: dropbox null email → connected predicate must '
              'return false (email-sentinel path unchanged)',
        );
      },
    );

    // I-05 EC-12: googleDrive email present → BackupConnected (no regression)
    test(
      'I-05 EC-12 regression: googleDrive email present → BackupConnected',
      () async {
        await settingsRepo.setActiveProvider(SyncProvider.googleDrive);
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@gmail.test',
          lastBackupAt: null,
        );
        final container = makeIcloudContainer(FakeICloudProvider());
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);
        expect(
          s,
          isA<BackupConnected>(),
          reason: 'EC-12: googleDrive email present → connected predicate '
              'must return true (email-sentinel path unchanged)',
        );
      },
    );

    // I-06 FR-16: build() iCloud connected → BackupConnected.email is null
    //             (no force-unwrap, no throw)
    test(
      'I-06 FR-16: build() iCloud connected → BackupConnected.email is null',
      () async {
        await settingsRepo.setActiveProvider(SyncProvider.iCloud);
        final container = makeIcloudContainer(
          FakeICloudProvider(authorizeThrows: false),
        );
        addTearDown(container.dispose);
        final s = await container.read(backupNotifierProvider.future);
        expect(s, isA<BackupConnected>());
        expect(
          (s as BackupConnected).email,
          isNull,
          reason: 'FR-16: iCloud has no email; build() must not force-unwrap '
              'dropboxEmail — BackupConnected.email must be null',
        );
      },
    );

    // I-07 FR-16: connect() iCloud (currentEmail()==null) stores dropboxEmail:null,
    //             completes without SyncException
    test(
      'I-07 FR-16: connect() iCloud stores dropboxEmail:null, NO SyncException',
      () async {
        await settingsRepo.setActiveProvider(SyncProvider.iCloud);
        final container = makeIcloudContainer(
          FakeICloudProvider(authorizeThrows: false),
        );
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        // connect() must complete without throwing and must NOT emit BackupErrorState.
        await container.read(backupNotifierProvider.notifier).connect();

        // Stored settings must have dropboxEmail = null for iCloud.
        final settings = await settingsRepo.getOrCreate();
        expect(
          settings.dropboxEmail,
          isNull,
          reason: 'FR-16: iCloud connect() must store dropboxEmail:null '
              '(no email available), not throw SyncException',
        );

        // Final state must not be BackupErrorState (no SyncException escaped).
        final s = await container.read(backupNotifierProvider.future);
        expect(
          s,
          isNot(isA<BackupErrorState>()),
          reason: 'FR-16: connect() for iCloud must not throw '
              'SyncException("Could not fetch account") when email is null',
        );
      },
    );

    // I-08 FR-16: BackupConnected.email is String? (compile-time guard)
    test(
      'I-08 FR-16: BackupConnected.email is String? (accepts null)',
      () {
        // If BackupConnected.email were non-nullable this would fail at compile time.
        const state = BackupConnected(
          provider: SyncProvider.dropbox,
          email: null,
          autoBackupActive: false,
          passphraseSet: false,
        );
        expect(state.email, isNull);
      },
    );

    // I-09 FR-15/FR-16-neg static: no dropboxEmail! in the notifier file;
    //      _isConnected has an explicit 'case SyncProvider.iCloud:' arm.
    test(
      'I-09 FR-15/FR-16-neg static: no dropboxEmail! in backup_notifier.dart; '
      '_isConnected has case SyncProvider.iCloud:',
      () async {
        final file = File(
          'lib/features/backup/state/backup_notifier.dart',
        );
        final content = await file.readAsString();
        expect(
          content,
          isNot(contains('dropboxEmail!')),
          reason: 'FR-16: dropboxEmail must never be force-unwrapped — '
              'BackupConnected.email is now nullable',
        );
        expect(
          content,
          contains('case SyncProvider.iCloud:'),
          reason: 'FR-15: _isConnected must have an explicit '
              'case SyncProvider.iCloud: arm (not a default: or activeProvider != null)',
        );
      },
    );
  });

  // ── TASK-05 TDD: BackupNotifier.switchProvider ordered flow ──
  //
  // These tests are written BEFORE the implementation (TDD red phase).
  // They drive the exact contract of §5.1 and EC-02/04/05/06/07/08.
  //
  // Container strategy: override [resolveBackupProvider] family directly so
  // [ref.read(resolveBackupProvider(target))] inside switchProvider returns the
  // spy fakes.  [cloudBackupProvider] is left unoverridden in most tests so it
  // chains through the family (for the CC-2 test it is explicitly pinned to
  // fakeDropbox to expose a stale-read scenario).

  group('TASK-05 — BackupNotifier.switchProvider', () {
    late _FakeGoogleDriveProvider fakeGoogleDrive;
    late FakeICloudProvider fakeICloud;

    setUp(() {
      fakeGoogleDrive = _FakeGoogleDriveProvider();
      fakeICloud = FakeICloudProvider();
    });

    /// Standard container for switchProvider tests.
    ///
    /// Overrides [resolveBackupProvider] so the spy fakes are returned for
    /// each [SyncProvider] key.  [cloudBackupProvider] resolves through the
    /// family (not pinned), which is correct for all tests except CC-2.
    ProviderContainer makeSwitchContainer() {
      return ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider.overrideWith(
            (_) async => settingsRepo,
          ),
          secureStorageProvider.overrideWithValue(storage),
          backupDataProvider.overrideWith((_) async => BackupData(runner)),
          restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
          resolveBackupProvider.overrideWith((ref, id) {
            switch (id) {
              case SyncProvider.dropbox:
                return fakeDropbox;
              case SyncProvider.googleDrive:
                return fakeGoogleDrive;
              case SyncProvider.iCloud:
                return fakeICloud;
            }
          }),
          syncLogRepositoryProvider.overrideWith((_) async => fakeSyncLogRepo),
        ],
      );
    }

    // ── S-01: token scope ────────────────────────────────────────────────────
    // active=dropbox, switchProvider(googleDrive) ok:
    //   fakeDropbox.disconnectCalls == 1
    //   fakeGoogleDrive.disconnectCalls == 0
    //   passphrase key value unchanged before/after
    test(
      'S-01 token scope: active=dropbox → switchProvider(googleDrive) ok — '
      'disconnect/authorize counts and passphrase unchanged',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );
        storage.values[BackupNotifier.kPassphraseKey] = 'my-passphrase';

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        expect(
          fakeDropbox.disconnectCalls,
          1,
          reason: 'old provider (dropbox) disconnect() must be called once',
        );
        expect(
          fakeGoogleDrive.disconnectCalls,
          0,
          reason: 'new provider (googleDrive) disconnect() must NOT be called',
        );
        expect(
          fakeGoogleDrive.authorizeCalls,
          1,
          reason: 'new provider (googleDrive) authorize() must be called once',
        );
        expect(
          storage.values[BackupNotifier.kPassphraseKey],
          'my-passphrase',
          reason: 'switchProvider must never touch the passphrase key (FR-13)',
        );
        final settings = await settingsRepo.getOrCreate();
        expect(settings.activeProvider, SyncProvider.googleDrive);
      },
    );

    // ── S-02: no notifier routing ────────────────────────────────────────────
    // Verifies that BackupNotifier.connect() and .disconnect() are not invoked.
    // Proxy: both notifier-level methods delete the passphrase key.  If the key
    // is still present after switch, neither was called.
    test(
      'S-02 no notifier routing: notifier connect()/disconnect() NOT invoked '
      '— passphrase key survives (both methods delete it)',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );
        storage.values[BackupNotifier.kPassphraseKey] = 'must-survive';

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        expect(
          storage.values.containsKey(BackupNotifier.kPassphraseKey),
          isTrue,
          reason:
              'passphrase key must be present — notifier disconnect/connect '
              'would have deleted it (CC-1)',
        );
        expect(
          storage.values[BackupNotifier.kPassphraseKey],
          'must-survive',
          reason: 'passphrase value must be unchanged (FR-13)',
        );
      },
    );

    // ── S-03: deleteFile not called ──────────────────────────────────────────
    test(
      'S-03 deleteFile: fakeDropbox.deleteCalls empty after success (.enc intact)',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        expect(
          fakeDropbox.deleteCalls,
          isEmpty,
          reason: 'switchProvider must never call deleteFile on the old '
              'provider — old .enc files stay intact (FR-13)',
        );
        expect(fakeGoogleDrive.deleteCalls, isEmpty);
      },
    );

    // ── S-04: abort gate (EC-04) ─────────────────────────────────────────────
    // old.disconnect() throws → activeProvider stays dropbox,
    // fakeGoogleDrive.authorizeCalls == 0, setActiveProvider never called,
    // state BackupErrorState.
    test(
      'S-04 abort gate (EC-04): old.disconnect() throws → '
      'activeProvider unchanged, new not authorized, BackupErrorState',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );
        fakeDropbox.disconnectThrows = true;

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        settingsRepo.callLog.clear();
        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        final settings = await settingsRepo.getOrCreate();
        expect(
          settings.activeProvider,
          SyncProvider.dropbox,
          reason: 'abort gate: activeProvider must stay dropbox (FR-11)',
        );
        expect(
          fakeGoogleDrive.authorizeCalls,
          0,
          reason: 'abort gate: new provider must not be authorized (FR-11)',
        );
        expect(
          settingsRepo.callLog,
          isNot(contains('setActiveProvider')),
          reason: 'abort gate: setActiveProvider must not be called (FR-11)',
        );
        final s = container.read(backupNotifierProvider).valueOrNull;
        expect(
          s,
          isA<BackupErrorState>(),
          reason: 'abort gate: state must be BackupErrorState',
        );
      },
    );

    // ── S-05: pre-flip ordering ──────────────────────────────────────────────
    // old.disconnect() must complete before setActiveProvider is ever called.
    test(
      'S-05 pre-flip ordering: old.disconnect() completes before '
      'setActiveProvider is called',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );

        // Capture whether setActiveProvider has been called at the moment
        // disconnect() runs.  If it has, the ordering invariant is violated.
        bool setActiveProviderCalledBeforeDisconnect = false;
        fakeDropbox.onDisconnectCalled = () {
          setActiveProviderCalledBeforeDisconnect =
              settingsRepo.callLog.contains('setActiveProvider');
        };

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        settingsRepo.callLog.clear();
        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        expect(
          setActiveProviderCalledBeforeDisconnect,
          isFalse,
          reason:
              'setActiveProvider must NOT be called before disconnect() returns '
              '(FR-10 ordering)',
        );
        expect(
          settingsRepo.callLog,
          contains('setActiveProvider'),
          reason:
              'setActiveProvider must be called at some point during switch',
        );
      },
    );

    // ── S-06: post-flip failure (EC-05 / OQ-01) ──────────────────────────────
    // authorize() throws AFTER setActiveProvider:
    //   activeProvider == googleDrive (no rollback)
    //   dropboxEmail cleared
    //   state BackupErrorState
    //   next build() → BackupNotConnected for googleDrive
    test(
      'S-06 post-flip failure (EC-05/OQ-01): authorize() throws after flip → '
      'activeProvider stays googleDrive (no rollback), state BackupErrorState, '
      'next build() → BackupNotConnected',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );
        fakeGoogleDrive.authorizeThrows = true;

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        // No rollback: activeProvider stays target.
        final settings = await settingsRepo.getOrCreate();
        expect(
          settings.activeProvider,
          SyncProvider.googleDrive,
          reason: 'OQ-01: activeProvider must stay flipped (no rollback)',
        );
        expect(
          settings.dropboxEmail,
          isNull,
          reason: 'old identity cleared at step 4 — dropboxEmail must be null',
        );

        // Current state is BackupErrorState.
        final s = container.read(backupNotifierProvider).valueOrNull;
        expect(
          s,
          isA<BackupErrorState>(),
          reason: 'post-flip failure must surface BackupErrorState',
        );

        // "Next build()" — trigger a rebuild and verify BackupNotConnected.
        // With activeProvider=googleDrive and dropboxEmail=null,
        // _isConnected() returns false → BackupNotConnected.
        container.invalidate(backupNotifierProvider);
        final nextState = await container.read(backupNotifierProvider.future);
        expect(
          nextState,
          isA<BackupNotConnected>(),
          reason:
              'OQ-01: next build() must emit BackupNotConnected for the new '
              'provider so the user can retry from a clean state',
        );
      },
    );

    // ── S-07: iCloud null email (EC-08) ──────────────────────────────────────
    // iOS override; currentEmail()==null tolerated; completes successfully.
    test(
      'S-07 iCloud null email (EC-08): iOS platform; currentEmail()==null; '
      'switchProvider(iCloud) completes — BackupConnected(provider: iCloud)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );
        // fakeICloud.currentEmail() returns null by default (iCloud has no email).

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        // Must NOT throw — null email is tolerated for iCloud (EC-08).
        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.iCloud);

        final settings = await settingsRepo.getOrCreate();
        expect(
          settings.activeProvider,
          SyncProvider.iCloud,
          reason: 'activeProvider must be flipped to iCloud',
        );
        expect(
          settings.dropboxEmail,
          isNull,
          reason: 'iCloud stores null email (EC-08)',
        );

        // Build re-run via invalidateSelf → iCloud probe → connected.
        final finalState = await container.read(backupNotifierProvider.future);
        expect(
          finalState,
          isA<BackupConnected>(),
          reason: 'iCloud null email must NOT yield BackupErrorState',
        );
        expect(
          (finalState as BackupConnected).provider,
          SyncProvider.iCloud,
        );
      },
    );

    // ── S-08: first-connect idempotent forget (EC-02) ────────────────────────
    // NotConnected state (no email); old.disconnect() is a no-op;
    // switchProvider(googleDrive) proceeds to authorize; passphrase untouched.
    test(
      'S-08 EC-02: NotConnected, no dropbox token — old.disconnect() is a '
      'no-op; switchProvider(googleDrive) proceeds; passphrase untouched',
      () async {
        // No email → BackupNotConnected; activeProvider defaults to dropbox.
        storage.values[BackupNotifier.kPassphraseKey] = 'existing-pass';

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        final settings = await settingsRepo.getOrCreate();
        expect(
          settings.activeProvider,
          SyncProvider.googleDrive,
          reason: 'EC-02: switch must proceed even from NotConnected state',
        );
        expect(
          fakeGoogleDrive.authorizeCalls,
          1,
          reason: 'new provider must be authorized',
        );
        // Passphrase untouched (switchProvider never reads/writes/deletes it).
        expect(
          storage.values[BackupNotifier.kPassphraseKey],
          'existing-pass',
          reason: 'EC-02: passphrase must be untouched (FR-13)',
        );
      },
    );

    // ── S-09: re-entrancy (EC-06) ─────────────────────────────────────────────
    // state BackupRunning(switching); 2nd call returns immediately;
    // authorizeCalls <= 1; single invalidateSelf.
    test(
      'S-09 EC-06: state BackupRunning(switching); 2nd call returns immediately; '
      'authorizeCalls <= 1',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );

        final releaser = Completer<void>();
        final blockingGoogleDrive = _BlockingAuthGoogleDriveProvider(releaser);

        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider.overrideWith(
              (_) async => settingsRepo,
            ),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider.overrideWith((_) async => BackupData(runner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            resolveBackupProvider.overrideWith((ref, id) {
              switch (id) {
                case SyncProvider.dropbox:
                  return fakeDropbox;
                case SyncProvider.googleDrive:
                  return blockingGoogleDrive;
                case SyncProvider.iCloud:
                  return fakeICloud;
              }
            }),
            syncLogRepositoryProvider
                .overrideWith((_) async => fakeSyncLogRepo),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(() {
          if (!releaser.isCompleted) releaser.complete();
        });

        await container.read(backupNotifierProvider.future);

        // First call blocks inside blockingGoogleDrive.authorize().
        unawaited(
          container
              .read(backupNotifierProvider.notifier)
              .switchProvider(SyncProvider.googleDrive),
        );
        // Allow microtasks to advance state to BackupRunning(switching).
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(backupNotifierProvider).valueOrNull,
          isA<BackupRunning>(),
          reason: 'precondition: first call must have entered BackupRunning',
        );

        // Second call must return immediately (re-entrancy guard).
        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'switchProvider did not return within 3 s — '
                're-entrancy guard is missing',
              ),
            );

        expect(
          blockingGoogleDrive.authorizeCalls,
          lessThanOrEqualTo(1),
          reason: 'EC-06: re-entrant call must not invoke authorize() again',
        );

        // Unblock the first call.
        releaser.complete();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    // ── S-10: explicit resolver (CC-2) ────────────────────────────────────────
    // switchProvider reads resolveBackupProvider(target), NOT cloudBackupProvider.
    // Setup: cloudBackupProvider is pinned to fakeDropbox (simulating stale-read).
    // If the implementation incorrectly uses cloudBackupProvider for the new
    // provider, fakeDropbox.authorizeCalls would increment instead of
    // fakeGoogleDrive.authorizeCalls.
    test(
      'S-10 CC-2: explicit resolver — resolveBackupProvider(target) used, '
      'NOT cloudBackupProvider (stale-read hazard)',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );

        // Pin cloudBackupProvider to fakeDropbox to expose the stale-read hazard.
        // resolveBackupProvider(googleDrive) correctly returns fakeGoogleDrive.
        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider.overrideWith(
              (_) async => settingsRepo,
            ),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider.overrideWith((_) async => BackupData(runner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            // Stale pin: cloudBackupProvider always returns fakeDropbox,
            // even after setActiveProvider(googleDrive).
            cloudBackupProvider.overrideWithValue(fakeDropbox),
            // resolveBackupProvider correctly routes to the fakes.
            resolveBackupProvider.overrideWith((ref, id) {
              switch (id) {
                case SyncProvider.dropbox:
                  return fakeDropbox;
                case SyncProvider.googleDrive:
                  return fakeGoogleDrive;
                case SyncProvider.iCloud:
                  return fakeICloud;
              }
            }),
            syncLogRepositoryProvider
                .overrideWith((_) async => fakeSyncLogRepo),
          ],
        );
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        final dropboxAuthBefore = fakeDropbox.authorizeCalls;

        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        expect(
          fakeGoogleDrive.authorizeCalls,
          1,
          reason: 'CC-2: resolveBackupProvider(googleDrive) must be used — '
              'fakeGoogleDrive.authorizeCalls must be 1',
        );
        expect(
          fakeDropbox.authorizeCalls,
          dropboxAuthBefore,
          reason:
              'CC-2: cloudBackupProvider must NOT be used for the new provider — '
              'fakeDropbox.authorizeCalls must be unchanged',
        );
      },
    );

    // ── S-11: reactive churn (EC-07) ──────────────────────────────────────────
    // Even with intermediate settings writes mid-switch, the flow converges via
    // invalidateSelf.  Verified by asserting the correct final state.
    test(
      'S-11 EC-07: converges via invalidateSelf — final state '
      'BackupConnected(provider: googleDrive) after switch',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        // invalidateSelf() causes build() to re-run; verify convergence.
        final finalState = await container.read(backupNotifierProvider.future);
        expect(
          finalState,
          isA<BackupConnected>(),
          reason: 'EC-07: switch must converge to BackupConnected via '
              'invalidateSelf()',
        );
        expect(
          (finalState as BackupConnected).provider,
          SyncProvider.googleDrive,
        );
        expect(
          fakeGoogleDrive.authorizeCalls,
          1,
          reason: 'target provider authorized exactly once',
        );
      },
    );

    // ── S-12: post-switch field (FR-15) ───────────────────────────────────────
    // success → emitted BackupConnected.provider == googleDrive.
    test(
      'S-12 FR-15: success → BackupConnected.provider == googleDrive',
      () async {
        await settingsRepo.updateBackupState(
          dropboxEmail: 'user@dropbox.com',
          lastBackupAt: null,
        );

        final container = makeSwitchContainer();
        addTearDown(container.dispose);
        await container.read(backupNotifierProvider.future);

        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);

        final finalState = await container.read(backupNotifierProvider.future);
        expect(finalState, isA<BackupConnected>());
        expect(
          (finalState as BackupConnected).provider,
          SyncProvider.googleDrive,
          reason: 'FR-15: emitted BackupConnected.provider must equal the '
              'switched-to provider (googleDrive)',
        );
      },
    );
  });

  // ── TASK-04 TDD: build() populates BackupConnected.provider from settings ──

  group('TASK-04 — BackupConnected.provider populated from settings', () {
    test(
      'build() with activeProvider==iCloud emits BackupConnected.provider==iCloud',
      () async {
        // Seed iCloud as the active provider so _isConnected() takes the
        // SyncProvider.iCloud arm (container probe via authorize()).
        await settingsRepo.setActiveProvider(SyncProvider.iCloud);
        // No dropboxEmail needed: iCloud uses the authorize() container probe,
        // not the email sentinel used for Dropbox / Google Drive.

        // Override cloudBackupProvider with FakeICloudProvider so that
        // authorize() succeeds (no SyncException) → _isConnected() returns true.
        final icloudContainer = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider.overrideWith(
              (_) async => settingsRepo,
            ),
            secureStorageProvider.overrideWithValue(storage),
            backupDataProvider.overrideWith((_) async => BackupData(runner)),
            restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
            cloudBackupProvider.overrideWithValue(FakeICloudProvider()),
            syncLogRepositoryProvider.overrideWith(
              (_) async => fakeSyncLogRepo,
            ),
          ],
        );
        addTearDown(icloudContainer.dispose);

        final s = await icloudContainer.read(backupNotifierProvider.future);
        // Fails before implementation: BackupConnected has no `provider` field.
        expect(s, isA<BackupConnected>());
        expect(
          (s as BackupConnected).provider,
          SyncProvider.iCloud,
          reason: 'build() must populate BackupConnected.provider from '
              'settings.activeProvider (not from a view re-read), so that '
              'the connected view can render the active provider name (FR-15)',
        );
      },
    );
  });
}
