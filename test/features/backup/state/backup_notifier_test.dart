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
import 'package:metra/data/services/backup/dropbox_provider.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../../helpers/fake_app_settings_repository.dart';
import '../../../helpers/fake_dropbox_provider.dart';
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
}
