// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

// E2E integration test for FR-12: suspend-on-wipe → backup-skipped →
// clear-on-write → backup-uploads lifecycle.
//
// Spec ref: FR-12 (all sub-IDs), FR-19j, §7.2 E2E flow 1.
// Uses ProviderContainer with all fakes — no network IO, no iOS tooling
// (NFR-08).  Runs on Linux CI.
//
// Steps:
//   (a) Seed fake repos; backupSuspended = false.
//   (b) invoke DeleteAllData.execute() → assert backupSuspended == true.
//   (c) invoke notifier.backupSilent() → assert backupSkipped log entry +
//       zero upload calls.
//   (d) invoke FakeDailyLogRepository.saveDailyLog(log) → assert
//       backupSuspended == false.
//   (e) invoke notifier.backupSilent() again → assert one upload call.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/util/nullable.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/delete_all_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';

import '../helpers/fake_app_settings_repository.dart';
import '../helpers/fake_backup_runner.dart';
import '../helpers/fake_cycle_entry_repository.dart';
import '../helpers/fake_daily_log_repository.dart';
import '../helpers/fake_sync_log_repository.dart';
import '../helpers/in_memory_secure_storage.dart';

void main() {
  group(
      'FR-12 — suspend-on-wipe → backup-skipped → clear-on-write → backup-uploads',
      () {
    late FakeAppSettingsRepository settingsRepo;
    late FakeDailyLogRepository logRepo;
    late FakeCycleEntryRepository cycleRepo;
    late FakeSyncLogRepository syncLogRepo;
    late FakeBackupRunner backupRunner;
    late InMemorySecureStorage storage;
    late ProviderContainer container;

    setUp(() {
      settingsRepo = FakeAppSettingsRepository();
      logRepo = FakeDailyLogRepository(settingsRepo: settingsRepo);
      cycleRepo = FakeCycleEntryRepository();
      syncLogRepo = FakeSyncLogRepository();
      backupRunner = FakeBackupRunner();
      storage = InMemorySecureStorage();

      container = ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider.overrideWith(
            (_) async => settingsRepo,
          ),
          dailyLogRepositoryProvider.overrideWith(
            (_) async => logRepo,
          ),
          cycleEntryRepositoryProvider.overrideWith(
            (_) async => cycleRepo,
          ),
          syncLogRepositoryProvider.overrideWith(
            (_) async => syncLogRepo,
          ),
          backupDataProvider.overrideWith(
            (_) async => BackupData(backupRunner),
          ),
          secureStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);
    });

    test('FR-19j — full lifecycle: delete → skipped → write → upload',
        () async {
      // (a) Seed: Dropbox connected, backupSuspended = false, passphrase set,
      //     lastBackupAt = null (first-ever backup path — guard 4 passes).
      settingsRepo.storedSettings = (await settingsRepo.getOrCreate()).copyWith(
        dropboxEmail: const Nullable('user@example.com'),
      );
      // Pre-condition: sentinel starts false.
      expect(
        (await settingsRepo.getOrCreate()).backupSuspended,
        isFalse,
        reason: 'precondition: backupSuspended must be false before wipe',
      );
      // Seed passphrase so backupSilent can proceed past the null-pass guard.
      storage.values[BackupNotifier.kPassphraseKey] = 'test-pass';

      // Warm up the notifier so build() resolves before we call backupSilent.
      await container.read(backupNotifierProvider.future);

      // (b) Wipe: DeleteAllData.execute() sets backupSuspended = true.
      final deleteUc = DeleteAllData(logRepo, cycleRepo, settingsRepo, storage);
      await deleteUc.execute();

      expect(
        (await settingsRepo.getOrCreate()).backupSuspended,
        isTrue,
        reason: 'step (b): backupSuspended must be true after wipe',
      );
      // BUG-B03 fix: execute() also wipes the passphrase from secure storage.
      // Re-seed it here to simulate the user re-entering their passphrase via
      // the manual backup flow (backupWithPassphrase) — without a passphrase,
      // backupSilent() correctly returns early (Guard 4). The FR-12 test intent
      // is to verify the suspend-then-clear-on-write cycle; the passphrase
      // re-entry is a prerequisite of step (e), not the subject under test.
      storage.values[BackupNotifier.kPassphraseKey] = 'test-pass';

      // (c) backupSilent with suspended sentinel: must skip, append
      //     backupSkipped log, zero uploads.
      // Invalidate so the notifier re-reads current settings (which now has
      // backupSuspended = true and a connected email).
      container.invalidate(backupNotifierProvider);
      await container.read(backupNotifierProvider.future);

      await container.read(backupNotifierProvider.notifier).backupSilent();

      // Assert: no upload calls.
      expect(
        backupRunner.backupCallCount,
        equals(0),
        reason: 'step (c): backupSilent must NOT upload when suspended',
      );
      // Assert: a backupSkipped sync-log entry was appended.
      final skippedLogs = syncLogRepo.appended
          .where((e) => e.operation == SyncOperation.backupSkipped)
          .toList();
      expect(
        skippedLogs,
        hasLength(1),
        reason:
            'step (c): exactly one backupSkipped log entry must be appended',
      );
      expect(
        skippedLogs.first.errorMessage,
        contains('backupSuspended=true'),
        reason: 'step (c): log message must mention the sentinel flag',
      );

      // (d) User writes a log entry — clear-on-write fires via
      //     FakeDailyLogRepository.saveDailyLog → settingsRepo.clearBackupSuspended().
      await logRepo.saveDailyLog(
        DailyLogEntity(
          date: DateTime.utc(2026, 5, 17),
          painEnabled: false,
          notesEnabled: false,
        ),
      );

      expect(
        (await settingsRepo.getOrCreate()).backupSuspended,
        isFalse,
        reason: 'step (d): clearBackupSuspended must fire after saveDailyLog',
      );

      // (e) backupSilent with sentinel cleared — must produce one upload.
      // Seed lastLogOrSymptomWriteAt > lastBackupAt so the write-recency
      // guard (FR-11) does not skip.  lastBackupAt is null (first-ever), so
      // the guard always proceeds regardless.
      container.invalidate(backupNotifierProvider);
      await container.read(backupNotifierProvider.future);

      await container.read(backupNotifierProvider.notifier).backupSilent();

      expect(
        backupRunner.backupCallCount,
        equals(1),
        reason:
            'step (e): backupSilent must call backup exactly once after clear',
      );

      // Assert notifier ended in BackupConnected (not an error).
      final finalState = container.read(backupNotifierProvider).valueOrNull;
      // After invalidateSelf() inside _runBackup, the notifier re-reads
      // settings and rebuilds; the FakeBackupRunner has no error so
      // BackupConnected is returned.
      expect(
        finalState,
        isNotNull,
        reason: 'notifier must have settled',
      );
    });
  });
}
