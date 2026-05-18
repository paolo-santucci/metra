// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/backup_filename.dart';
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
      'keeps all files when total count is within N=3 retention cap',
      () async {
        storage.values[passphraseKey] = passphrase;
        // Seed 2 old files; after uploading 1 new one, total = 3 — exactly at
        // the N=3 cap, so no pruning occurs (skip(3) yields empty set).
        provider.files['metra_backup_20260427T000000Z_aaaaaa.enc'] =
            Uint8List.fromList([1]);
        provider.files['metra_backup_20260428T000000Z_aaaaab.enc'] =
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

        // 2 seeded + 1 new upload = 3 total, exactly at the cap — no pruning.
        expect(provider.files, hasLength(3));
        expect(provider.deleteCalls, isEmpty);
        // The newly uploaded file is the only one with today's timestamp.
        expect(
          provider.files.keys.any(
            (k) => k.startsWith('metra_backup_20260429T100000Z_'),
          ),
          isTrue,
        );
      },
    );

    test(
      'FR-13 — backup() with 15 seeded files keeps newest 3 after upload',
      () async {
        storage.values[passphraseKey] = passphrase;
        // Pre-populate 15 files with descending timestamps (oldest = day 1,
        // newest = day 15). listFiles() synthesises entries newest-first via
        // lexicographic sort, matching timestamp-descending order.
        for (var i = 1; i <= 15; i++) {
          final name = BackupFilename.filenameFor(
            DateTime.utc(2026, 5, i, 12),
            randomSuffix: 'seed${i.toString().padLeft(2, '0')}',
          );
          provider.files[name] = Uint8List.fromList([i]);
        }
        // Fix _now() to a time after all seeded entries so the new upload
        // is newest-first in the list.
        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 5, 20, 12, 0, 0),
        );
        await orch.backup();

        // listFiles returns 16 (15 seeded + 1 new upload).
        // N=3 retention: prune the 13 oldest → 3 remain.
        expect(provider.deleteCalls.length, equals(13));
        expect(provider.files, hasLength(3));

        // The just-uploaded file must NOT have been pruned.
        final uploadedName = provider.files.keys.firstWhere(
          (k) => k.startsWith('metra_backup_20260520T120000Z_'),
        );
        expect(provider.deleteCalls, isNot(contains(uploadedName)));
      },
    );

    test(
      'FR-13a — per-file delete failure is logged and prune continues',
      () async {
        storage.values[passphraseKey] = passphrase;
        for (var i = 1; i <= 15; i++) {
          final name = BackupFilename.filenameFor(
            DateTime.utc(2026, 5, i, 12),
            randomSuffix: 'seed${i.toString().padLeft(2, '0')}',
          );
          provider.files[name] = Uint8List.fromList([i]);
        }
        // Make the oldest file's delete throw.
        final oldestName = BackupFilename.filenameFor(
          DateTime.utc(2026, 5, 1, 12),
          randomSuffix: 'seed01',
        );
        provider.deleteThrows = {
          oldestName: const SyncException('delete-failed'),
        };

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 5, 20, 12, 0, 0),
        );
        // Must not throw despite the per-file delete failure.
        await orch.backup();

        // All 13 prune candidates were attempted (16 total - 3 retention cap).
        expect(provider.deleteCalls.length, equals(13));

        // Exactly 1 prune-failure log entry, plus 1 overall success log.
        final failureLogs = syncLogRepo.appended
            .where(
              (e) =>
                  !e.success &&
                  (e.errorMessage ?? '').contains('prune-failure:'),
            )
            .toList();
        expect(failureLogs.length, equals(1));
        expect(
          syncLogRepo.appended.where((e) => e.success).length,
          equals(1),
        );
      },
    );

    test(
      'EC-11 — first-ever backup with empty folder: 0 prune deletes',
      () async {
        storage.values[passphraseKey] = passphrase;
        // provider.files is empty — no previous backups exist.
        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
        );
        await orch.backup();

        expect(provider.deleteCalls, isEmpty);
        final successLogs = syncLogRepo.appended
            .where(
              (e) => e.success && e.operation == SyncOperation.backup,
            )
            .toList();
        expect(successLogs, isNotEmpty);
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

    group('Group C — 507 retry loop', () {
      // Sentinels: null = upload success, InsufficientStorageException = 507.
      const storageFullEx = InsufficientStorageException();

      // Helper: seeds [count] backup files with descending timestamps.
      // Returns names newest-first so [provider.files.keys.last] (after sort) is
      // the oldest, matching [listFiles()] ordering.
      void seedFiles(int count) {
        for (var i = count; i >= 1; i--) {
          final name = BackupFilename.filenameFor(
            DateTime.utc(2026, 5, i, 12),
            randomSuffix: 'seed${i.toString().padLeft(2, '0')}',
          );
          provider.files[name] = Uint8List.fromList([i]);
        }
      }

      test('507 once, 2 prior files → 1 delete + retry upload succeeds',
          () async {
        storage.values[passphraseKey] = passphrase;
        // 2 prior files; first upload → 507, second upload → success.
        provider.uploadResponses = [storageFullEx, null];
        seedFiles(2);

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 6, 1, 10),
        );
        await orch.backup();

        // Exactly 1 file deleted from the retry loop.
        expect(provider.deleteCalls.length, equals(1));
        // 2 upload attempts were made.
        expect(provider.uploadCalls.length, equals(2));
        // 1 progressive-prune informational log entry.
        final pruneLogs = syncLogRepo.appended
            .where(
              (e) =>
                  !e.success &&
                  (e.errorMessage ?? '').startsWith('progressive-prune:'),
            )
            .toList();
        expect(pruneLogs.length, equals(1));
      });

      test(
          '507 with files.length == 1 → rethrows InsufficientStorageException, '
          'zero deletes', () async {
        storage.values[passphraseKey] = passphrase;
        provider.uploadResponses = [storageFullEx];
        seedFiles(1);

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 6, 1, 10),
        );
        await expectLater(
          orch.backup(),
          throwsA(isA<InsufficientStorageException>()),
        );
        expect(provider.deleteCalls, isEmpty);
      });

      test(
          'NFR-02 cap — 507 forever with 5 prior files: max 2 deletes then rethrow',
          () async {
        storage.values[passphraseKey] = passphrase;
        provider.uploadResponses =
            List.filled(99, storageFullEx, growable: true);
        seedFiles(5);

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 6, 1, 10),
        );
        await expectLater(
          orch.backup(),
          throwsA(isA<InsufficientStorageException>()),
        );
        expect(provider.deleteCalls.length, lessThanOrEqualTo(2));
      });

      test('EC-06 — deleteFile exception swallowed; backup completes on retry',
          () async {
        storage.values[passphraseKey] = passphrase;
        // 2 prior files; first upload → 507, second upload → success.
        provider.uploadResponses = [storageFullEx, null];
        seedFiles(2);

        // Make the oldest file's delete throw.
        final sortedNames = provider.files.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        final oldestName = sortedNames.last;
        provider.deleteThrows = {
          oldestName: const SyncException('Delete failed: 404'),
        };

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 6, 1, 10),
        );
        // Must complete despite the deleteFile exception.
        await orch.backup();
      });
    });

    group('Group D — FR-10 retention cap N=3', () {
      test(
          'FR-10 — kBackupRetentionMaxFiles == 3 and post-upload prune deletes 2 of 5',
          () async {
        storage.values[passphraseKey] = passphrase;
        // Seed 4 files; upload adds 1 new → 5 total; retain 3 → prune 2 oldest.
        for (var i = 1; i <= 4; i++) {
          final name = BackupFilename.filenameFor(
            DateTime.utc(2026, 5, i, 12),
            randomSuffix: 'seed${i.toString().padLeft(2, '0')}',
          );
          provider.files[name] = Uint8List.fromList([i]);
        }

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 5, 20, 12, 0, 0),
        );
        await orch.backup();

        // 4 seeded + 1 new = 5 total; skip(3) = 2 oldest deleted.
        expect(provider.deleteCalls.length, equals(2));
      });

      test(
          'EC-15 silent post-upgrade prune — 7 files → 4 deletes, no dialogs/notifications',
          () async {
        storage.values[passphraseKey] = passphrase;
        // Seed 6 files; upload adds 1 new → 7 total; retain 3 → prune 4 oldest.
        for (var i = 1; i <= 6; i++) {
          final name = BackupFilename.filenameFor(
            DateTime.utc(2026, 5, i, 12),
            randomSuffix: 'seed${i.toString().padLeft(2, '0')}',
          );
          provider.files[name] = Uint8List.fromList([i]);
        }

        final orch = _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 5, 20, 12, 0, 0),
        );
        await orch.backup();

        // 6 seeded + 1 new = 7 total; skip(3) = 4 oldest deleted.
        expect(provider.deleteCalls.length, equals(4));
      });
    });
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

    group('filename forwarding (FR-14a)', () {
      // Seeds one real encrypted blob via backup(), then registers a second
      // synthetic blob by copying it under an older-timestamp name.
      // Returns [newestName, olderName] — names sorted descending (newest first).
      Future<List<String>> seedTwoBackups() async {
        storage.values[passphraseKey] = passphrase;
        await _make(
          storage: storage,
          provider: provider,
          settingsRepo: settingsRepo,
          syncLogRepo: syncLogRepo,
          logRepo: logRepo,
          now: () => DateTime.utc(2026, 5, 17, 12, 0, 0),
        ).backup();
        syncLogRepo.appended.clear();
        final newestName = provider.files.keys.first;
        // Register a second blob (same encrypted content) under an older name
        // so the prune did not remove it.
        const olderName = 'metra_backup_20260517T110000Z_older1.enc';
        provider.files[olderName] = provider.files[newestName]!;
        return [newestName, olderName]; // [newestName, olderName]
      }

      test(
        'FR-14a — filename-forwarding: downloads exact filename not entries.first',
        () async {
          final names = await seedTwoBackups();
          final newestName = names[0];
          final olderName = names[1];
          // seedEntries puts newest first so entries.first != olderName.
          provider.seedEntries = [
            BackupFileEntry(
              name: newestName,
              timestampUtc: DateTime.utc(2026, 5, 17, 12),
              sizeBytes: 1,
            ),
            BackupFileEntry(
              name: olderName,
              timestampUtc: DateTime.utc(2026, 5, 17, 11),
              sizeBytes: 1,
            ),
          ];
          final orch = _make(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );
          await orch.restore(filename: olderName);
          expect(provider.downloadCalledWith, equals(olderName));
        },
      );

      test(
        'FR-14a — null filename downloads entries.first (legacy)',
        () async {
          final names = await seedTwoBackups();
          final newestName = names[0];
          provider.seedEntries = [
            BackupFileEntry(
              name: newestName,
              timestampUtc: DateTime.utc(2026, 5, 17, 12),
              sizeBytes: 1,
            ),
          ];
          final orch = _make(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );
          await orch.restore(filename: null);
          expect(provider.downloadCalledWith, equals(newestName));
        },
      );

      test(
        'EC-04 — named file missing: SyncException propagates',
        () async {
          await seedTwoBackups();
          final newestName = (provider.files.keys.toList()
                ..sort((a, b) => b.compareTo(a)))
              .first;
          provider.seedEntries = [
            BackupFileEntry(
              name: newestName,
              timestampUtc: DateTime.utc(2026, 5, 17, 12),
              sizeBytes: 1,
            ),
          ];
          provider.downloadThrows = {
            'missing.enc': const SyncException('Download failed: 409'),
          };
          final orch = _make(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );
          await expectLater(
            orch.restore(filename: 'missing.enc'),
            throwsA(isA<SyncException>()),
          );
        },
      );
    });
  });
}
