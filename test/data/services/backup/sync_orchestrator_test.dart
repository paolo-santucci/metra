// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/backup_service.dart';
import 'package:metra/data/services/backup/sync_orchestrator.dart';
import 'package:metra/data/services/encryption_service.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

import '../../../helpers/fake_app_settings_repository.dart';
import '../../../helpers/fake_daily_log_repository.dart';
import '../../../helpers/fake_dropbox_provider.dart';
import '../../../helpers/fake_sync_log_repository.dart';
import '../../../helpers/in_memory_secure_storage.dart';

class _FakeRecompute {
  int callCount = 0;
  Future<dynamic> call() async => callCount++;
}

SyncOrchestrator _make({
  required InMemorySecureStorage storage,
  required FakeDropboxProvider provider,
  required FakeAppSettingsRepository settingsRepo,
  required FakeSyncLogRepository syncLogRepo,
  required FakeDailyLogRepository logRepo,
  _FakeRecompute? recompute,
  DateTime Function()? now,
}) {
  final enc = EncryptionService(
    kdfOverride: Argon2id(
      memory: 256,
      iterations: 1,
      parallelism: 1,
      hashLength: 32,
    ),
  );
  final backupService = BackupService(logRepo);
  final recomp = recompute ?? _FakeRecompute();
  return SyncOrchestrator(
    backupService: backupService,
    encryptionService: enc,
    provider: provider,
    settingsRepo: settingsRepo,
    syncLogRepo: syncLogRepo,
    logRepo: logRepo,
    recompute: recomp.call,
    secureStorage: storage,
    now: now ?? () => DateTime.utc(2026, 4, 29, 10, 0, 0),
  );
}

void main() {
  const passphrase = 'test-passphrase-42';
  const passphraseKey = 'metra_backup_passphrase_v1';

  late InMemorySecureStorage storage;
  late FakeDropboxProvider provider;
  late FakeAppSettingsRepository settingsRepo;
  late FakeSyncLogRepository syncLogRepo;
  late FakeDailyLogRepository logRepo;

  setUp(() {
    storage = InMemorySecureStorage();
    provider = FakeDropboxProvider();
    settingsRepo = FakeAppSettingsRepository();
    syncLogRepo = FakeSyncLogRepository();
    logRepo = FakeDailyLogRepository();
  });

  group('backup()', () {
    test(
      'happy path: blob uploaded, lastBackupAt set, success log appended',
      () async {
        storage.values[passphraseKey] = passphrase;
        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
        );
        await orch.backup();

        expect(provider.files, hasLength(1));
        final filename = provider.files.keys.first;
        expect(filename, startsWith('metra_backup_'));
        expect(filename, endsWith('.enc'));

        final settings = await settingsRepo.getOrCreate();
        expect(settings.lastBackupAt, isNotNull);

        expect(syncLogRepo.appended, hasLength(1));
        expect(syncLogRepo.appended.first.success, isTrue);
        expect(syncLogRepo.appended.first.operation, SyncOperation.backup);
        expect(syncLogRepo.appended.first.provider, SyncProvider.dropbox);
      },
    );

    test(
      'deletes older files after uploading new one',
      () async {
        storage.values[passphraseKey] = passphrase;
        provider.files['metra_backup_20260427T000000Z.enc'] =
            Uint8List.fromList([1]);
        provider.files['metra_backup_20260428T000000Z.enc'] =
            Uint8List.fromList([2]);

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 4, 29, 10, 0, 0),
        );
        await orch.backup();

        expect(provider.files, hasLength(1));
        expect(provider.files.keys.first, 'metra_backup_20260429T100000Z.enc');
      },
    );

    test(
      'upload failure: SyncLog(success:false) appended, exception rethrown',
      () async {
        storage.values[passphraseKey] = passphrase;
        provider.failNextUpload = true;

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
        );
        await expectLater(orch.backup(), throwsA(isA<SyncException>()));

        expect(syncLogRepo.appended, hasLength(1));
        expect(syncLogRepo.appended.first.success, isFalse);
      },
    );

    test(
      'no passphrase: throws SyncException, failure log appended',
      () async {
        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
        );
        await expectLater(orch.backup(), throwsA(isA<SyncException>()));
        expect(syncLogRepo.appended.first.success, isFalse);
      },
    );
  });

  group('restore()', () {
    Future<void> seedBackup() async {
      storage.values[passphraseKey] = passphrase;
      await _make(
        storage: storage,
        provider: provider,
        settingsRepo: settingsRepo,
        syncLogRepo: syncLogRepo,
        logRepo: logRepo,
      ).backup();
      syncLogRepo.appended.clear();
    }

    group('restore alignment (FR-15)', () {
      test(
        'aligns lastLogOrSymptomWriteAt to lastBackupAt after successful restore',
        () async {
          // Seed a valid encrypted blob (backup() also sets lastBackupAt).
          await seedBackup();
          final tb = (await settingsRepo.getOrCreate()).lastBackupAt!;
          final orch = _make(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );
          await orch.restore();
          final after = await settingsRepo.getOrCreate();
          expect(after.lastLogOrSymptomWriteAt, equals(tb));
        },
      );

      test(
        'does NOT align when lastBackupAt is null',
        () async {
          // Blob present but no lastBackupAt in settings.
          await seedBackup();
          await settingsRepo.updateBackupState(
            dropboxEmail: null,
            lastBackupAt: null,
          );
          final orch = _make(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );
          await orch.restore();
          final after = await settingsRepo.getOrCreate();
          // Guard skips alignment when lastBackupAt is null.
          expect(after.lastLogOrSymptomWriteAt, isNull);
        },
      );

      test(
        'does NOT align when restore fails (wrong passphrase)',
        () async {
          // Seed a valid blob and a known lastBackupAt.
          await seedBackup();
          // Pre-seed lastLogOrSymptomWriteAt to a sentinel so "unchanged"
          // is a real equality assertion, not just "still null".
          final sentinel = DateTime.utc(2026, 3, 1, 8);
          await settingsRepo.updateLastDataWriteAt(sentinel);
          // Corrupt the passphrase so decryption fails.
          storage.values[passphraseKey] = 'wrong-passphrase';
          final orch = _make(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );
          await expectLater(orch.restore(), throwsA(isA<MetraException>()));
          final after = await settingsRepo.getOrCreate();
          expect(after.lastLogOrSymptomWriteAt, equals(sentinel));
        },
      );
    });

    test(
      'happy path: deleteAllAndReplace called, recompute invoked, success log',
      () async {
        await seedBackup();
        final recomp = _FakeRecompute();
        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          recompute: recomp,
        );
        await orch.restore();

        expect(logRepo.deleteAllAndReplaceCalledWithLogs, isNotNull);
        expect(recomp.callCount, 1);
        expect(syncLogRepo.appended, hasLength(1));
        expect(syncLogRepo.appended.first.success, isTrue);
        expect(syncLogRepo.appended.first.operation, SyncOperation.restore);
      },
    );

    test(
      'wrong passphrase: MetraException thrown, data not mutated',
      () async {
        await seedBackup();
        storage.values[passphraseKey] = 'wrong-passphrase';
        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
        );
        await expectLater(orch.restore(), throwsA(isA<MetraException>()));
        expect(logRepo.deleteAllAndReplaceCalledWithLogs, isNull);
        expect(syncLogRepo.appended.first.success, isFalse);
      },
    );

    test(
      'empty Dropbox: SyncException thrown, data not mutated',
      () async {
        storage.values[passphraseKey] = passphrase;
        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
        );
        await expectLater(orch.restore(), throwsA(isA<SyncException>()));
        expect(logRepo.deleteAllAndReplaceCalledWithLogs, isNull);
      },
    );
  });
}
