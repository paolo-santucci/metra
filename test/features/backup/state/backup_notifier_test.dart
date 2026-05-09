// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/utils/result.dart';
import 'package:metra/data/services/backup/dropbox_provider.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../../helpers/fake_app_settings_repository.dart';
import '../../../helpers/fake_dropbox_provider.dart';
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
  Future<void> restore() async {}
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
  Future<List<String>> listFiles() async => [];

  @override
  Future<void> deleteFile(String filename) async {}
}

void main() {
  late FakeAppSettingsRepository settingsRepo;
  late InMemorySecureStorage storage;
  late _FakeRunner runner;
  late FakeDropboxProvider fakeDropbox;

  setUp(() {
    settingsRepo = FakeAppSettingsRepository();
    storage = InMemorySecureStorage();
    runner = _FakeRunner();
    fakeDropbox = FakeDropboxProvider();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWith((_) async => settingsRepo),
        secureStorageProvider.overrideWithValue(storage),
        backupDataProvider.overrideWith((_) async => BackupData(runner)),
        restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
        cloudBackupProvider.overrideWithValue(fakeDropbox),
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
}
