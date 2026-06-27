// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

// Platforms: Android, iOS, Linux (in-memory only — no device interaction)
//
// TASK-09 — FR-03/FR-04/FR-05/FR-07/NFR-09
// IcloudProvider × SyncOrchestrator end-to-end integration (Scenario Group A).
//
// Drives the UNMODIFIED SyncOrchestrator via the REAL IcloudProvider backed
// by FakeIcloudGateway. Covers the four scenarios from spec §7.2 Scenario
// Group A:
//
//   A-1: Full backup — blob immediately visible in gather(); backup() completes,
//        listFiles() returns 1 correctly-named entry, log stamps iCloud.
//   A-2: Eventual-consistency — blob invisible for 3 gather() calls then
//        visible; driven under fake_async with an injectable delay; backup()
//        completes, post-upload verify passes, gather() called ≥ 4 times
//        (4 poll + 1 listFiles verify).
//   A-3: Quota — gateway throws PlatformException(kQuotaExceededCode) on the
//        first upload then succeeds; the 507 progressive-prune loop engages,
//        prunes the oldest file, retries, and backup() completes.
//   A-4: Poll-exhausted — blob never visible within kIcloudPollMaxAttempts;
//        SyncOrchestrator catches the SyncException, logs a failed-backup
//        entry, does NOT hang.
//
// DIP guard: sync_orchestrator.dart is NOT modified; no iCloud branch exists
// in it. The read-after-write contract is synthesised entirely inside
// IcloudProvider (FR-04).

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/backup_service.dart';
import 'package:metra/data/services/backup/cloud_backup_provider.dart';
import 'package:metra/data/services/backup/icloud_gateway.dart';
import 'package:metra/data/services/backup/icloud_provider.dart';
import 'package:metra/data/services/backup/sync_orchestrator.dart';
import 'package:metra/data/services/encryption_service.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

import '../../../helpers/fake_app_settings_repository.dart';
import '../../../helpers/fake_daily_log_repository.dart';
import '../../../helpers/fake_icloud_gateway.dart';
import '../../../helpers/fake_sync_log_repository.dart';
import '../../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Local test double
// ---------------------------------------------------------------------------

/// Extends [FakeIcloudGateway] to track the total number of [gather]
/// invocations across the life of a test.
///
/// Used to verify that the bounded-poll loop inside [IcloudProvider.upload]
/// calls [gather] the expected number of times (3 invisible + 1 visible = 4
/// poll calls) plus any additional calls from [IcloudProvider.listFiles].
class _CountingGateway extends FakeIcloudGateway {
  _CountingGateway({super.invisibleForGatherCalls});

  int gatherCallCount = 0;

  @override
  Future<List<IcloudEntry>> gather() {
    gatherCallCount++;
    return super.gather();
  }
}

// ---------------------------------------------------------------------------
// Shared fixture builder
// ---------------------------------------------------------------------------

/// Mirrors `_makeWith` in [sync_orchestrator_icloud_logstamp_test.dart],
/// accepting any [CloudBackupProvider] so the same helper works for all four
/// scenarios.
///
/// Injects a low-cost Argon2id (memory: 256, iterations: 1) so the KDF
/// completes as a fast microtask inside [fakeAsync].
SyncOrchestrator _makeOrchestrator({
  required InMemorySecureStorage storage,
  required CloudBackupProvider provider,
  required FakeAppSettingsRepository settingsRepo,
  required FakeSyncLogRepository syncLogRepo,
  required FakeDailyLogRepository logRepo,
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
  return SyncOrchestrator(
    backupService: backupService,
    encryptionService: enc,
    provider: provider,
    settingsRepo: settingsRepo,
    syncLogRepo: syncLogRepo,
    logRepo: logRepo,
    recompute: () async {},
    secureStorage: storage,
    // Fixed clock so the generated filename is deterministic.
    now: () => DateTime.utc(2026, 6, 24, 12, 0, 0),
  );
}

// ---------------------------------------------------------------------------
// Test constants
// ---------------------------------------------------------------------------

const _passphrase = 'test-passphrase-42';
const _passphraseKey = 'metra_backup_passphrase_v1';

// Pre-built filenames used as existing blobs in the quota scenario (A-3).
// Must follow the metra_backup_YYYYMMDDTHHMMSSZ_<6char>.enc pattern so
// BackupFilename.parseTimestamp() accepts them and listFiles() surfaces them.
const _existingFile1 = 'metra_backup_20260601T000000Z_aaaaaa.enc'; // oldest
const _existingFile2 = 'metra_backup_20260602T000000Z_bbbbbb.enc'; // newer

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late InMemorySecureStorage storage;
  late FakeAppSettingsRepository settingsRepo;
  late FakeSyncLogRepository syncLogRepo;
  late FakeDailyLogRepository logRepo;

  setUp(() {
    storage = InMemorySecureStorage();
    settingsRepo = FakeAppSettingsRepository();
    syncLogRepo = FakeSyncLogRepository();
    logRepo = FakeDailyLogRepository();
    storage.values[_passphraseKey] = _passphrase;
  });

  group(
    'Scenario Group A — IcloudProvider × SyncOrchestrator end-to-end '
    '(spec §7.2)',
    () {
      // -----------------------------------------------------------------------
      // A-1: Full backup — blob immediately visible
      // -----------------------------------------------------------------------
      test(
        'should_complete_backup_when_blob_immediately_visible_given_iCloud_provider'
        ' (FR-01/FR-04/FR-05)',
        () async {
          // FakeIcloudGateway default: invisibleForGatherCalls = 0, so the
          // blob is visible on the very first gather() call after upload.
          final gw = FakeIcloudGateway();
          final provider = IcloudProvider(gateway: gw);
          final orch = _makeOrchestrator(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );

          // The orchestrator must complete without throwing.
          await orch.backup();

          // listFiles() returns the one uploaded file (FR-05).
          final files = await provider.listFiles();
          expect(
            files,
            hasLength(1),
            reason: 'exactly one backup file should appear after a successful '
                'backup',
          );
          // The filename follows the metra_backup_YYYYMMDDTHHMMSSZ_<6char>.enc
          // pattern with the UTC timestamp from the fixed clock.
          expect(
            files.first.name,
            matches(
              RegExp(r'^metra_backup_20260624T120000Z_[a-z0-9]{6}\.enc$'),
            ),
            reason: 'filename must embed the UTC timestamp and a 6-char suffix',
          );

          // The SyncLog stamps SyncProvider.iCloud (FR-04 / DIP guard).
          expect(
            syncLogRepo.appended,
            hasLength(1),
            reason: 'exactly one log entry: the success stamp',
          );
          final log = syncLogRepo.appended.first;
          expect(log.success, isTrue);
          expect(log.operation, SyncOperation.backup);
          expect(
            log.provider,
            SyncProvider.iCloud,
            reason:
                'SyncLogEntity.provider must be iCloud when IcloudProvider is '
                'injected — DIP guard: no iCloud branch in sync_orchestrator.dart '
                '(FR-04)',
          );
        },
      );

      // -----------------------------------------------------------------------
      // A-2: Eventual-consistency — blob invisible for 3 gather() calls then
      //      visible; driven under fake_async with an injectable delay.
      // -----------------------------------------------------------------------
      test(
        'should_complete_backup_when_blob_eventually_consistent_given_fake_async'
        ' (EC-03/FR-03)',
        () {
          fakeAsync((fake) {
            final gw = _CountingGateway(invisibleForGatherCalls: 3);
            final provider = IcloudProvider(
              gateway: gw,
              // Injectable delay — intercepted by fakeAsync so the poll loop
              // can be driven deterministically without real wall-clock waits.
              delay: Future<void>.delayed,
            );
            final orch = _makeOrchestrator(
              storage: storage,
              provider: provider,
              settingsRepo: settingsRepo,
              syncLogRepo: syncLogRepo,
              logRepo: logRepo,
            );

            bool completed = false;
            Object? capturedError;
            orch.backup().then((_) {
              completed = true;
            }).catchError((Object e) {
              capturedError = e;
            });

            // Drive all pending microtasks (storage read, snapshot, encryption)
            // then advance the virtual clock past the 3 poll delays × 500 ms =
            // 1 500 ms needed for the blob to become visible.
            // 5 seconds is well in excess of the 1 500 ms needed.
            fake.elapse(const Duration(seconds: 5));

            expect(
              completed,
              isTrue,
              reason:
                  'backup() must complete once the blob becomes visible on the '
                  '4th gather() call',
            );
            expect(
              capturedError,
              isNull,
              reason: 'no exception should escape a successful backup',
            );

            // The poll loop called gather() 4 times (3 invisible + 1 visible).
            // One additional gather() comes from IcloudProvider.listFiles()
            // invoked by the orchestrator for the post-upload verify/prune step.
            // Total expected = 5.
            expect(
              gw.gatherCallCount,
              5,
              reason:
                  '4 gather() calls during the poll (3 invisible + 1 visible) '
                  '+ 1 gather() call from listFiles() for verify/prune '
                  '(EC-03 / FR-03)',
            );

            // The gateway store holds exactly the one uploaded file —
            // no pre-seeded files and no pruning occurs (1 file < cap of 3).
            expect(
              gw.store.length,
              1,
              reason: 'one blob should be in the in-memory store after a '
                  'successful backup',
            );

            // The SyncLog stamps iCloud (FR-04 DIP guard — no iCloud branch in
            // the unmodified SyncOrchestrator).
            expect(syncLogRepo.appended, hasLength(1));
            expect(syncLogRepo.appended.first.success, isTrue);
            expect(syncLogRepo.appended.first.provider, SyncProvider.iCloud);
          });
        },
      );

      // -----------------------------------------------------------------------
      // A-3: Quota — 507 progressive-prune loop engages, then retry completes.
      // -----------------------------------------------------------------------
      test(
        'should_engage_507_prune_loop_when_quota_on_first_upload'
        '_and_complete_on_retry (EC-05/FR-07)',
        () async {
          // TODO(M6): confirm IcloudGateway.kQuotaExceededCode matches the
          // real icloud_storage PlatformException code on a physical device.

          final gw = FakeIcloudGateway();

          // Pre-seed two valid backup blobs so that listFiles() returns
          // length >= 2 when the 507 loop checks for the safety floor.
          // The filenames must match the metra_backup_*.enc pattern so that
          // BackupFilename.parseTimestamp() accepts them.
          final seedBlob = Uint8List.fromList([0]);
          gw.store[_existingFile1] = seedBlob; // oldest (aaaaaa < bbbbbb)
          gw.store[_existingFile2] = seedBlob; // newer

          // Gateway throws the pinned quota code on the FIRST upload call.
          // FakeIcloudGateway resets throwQuotaOnNextUpload to false after
          // throwing, so the retry upload succeeds.
          gw.throwQuotaOnNextUpload = true;

          final provider = IcloudProvider(gateway: gw);
          final orch = _makeOrchestrator(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );

          // The 507 loop should:
          //   1. Catch InsufficientStorageException from the first upload.
          //   2. Call listFiles() → 2 pre-seeded files → length > 1.
          //   3. Delete the oldest (_existingFile1).
          //   4. Log a failed/prune entry.
          //   5. Retry upload → succeeds (quota flag reset).
          //   6. Verify the new file is visible.
          //   7. Log a success entry.
          await orch.backup();

          // Two log entries: [prune-failed, success].
          expect(
            syncLogRepo.appended,
            hasLength(2),
            reason: 'one progressive-prune log entry from the 507 loop and one '
                'success log entry from the completed backup',
          );

          final pruneLog = syncLogRepo.appended.first;
          expect(pruneLog.success, isFalse);
          expect(pruneLog.provider, SyncProvider.iCloud);
          expect(
            pruneLog.errorMessage,
            contains('progressive-prune'),
            reason: 'the 507 loop records a progressive-prune entry before '
                'retrying (sync_orchestrator.dart:106-115)',
          );

          final successLog = syncLogRepo.appended.last;
          expect(successLog.success, isTrue);
          expect(successLog.operation, SyncOperation.backup);
          expect(successLog.provider, SyncProvider.iCloud);

          // After the loop: oldest pre-seeded file was deleted by the 507 loop;
          // the newer pre-seeded file and the new backup both remain.
          expect(
            gw.store.length,
            2,
            reason:
                '_existingFile1 (oldest) was pruned; _existingFile2 and the '
                'new backup remain',
          );
          expect(
            gw.store.containsKey(_existingFile1),
            isFalse,
            reason: 'the oldest pre-seeded file must have been deleted by the '
                '507 loop',
          );
          expect(
            gw.store.containsKey(_existingFile2),
            isTrue,
            reason: 'the newer pre-seeded file must be retained',
          );
        },
      );

      // -----------------------------------------------------------------------
      // A-4: Poll-exhausted but gateway write COMMITTED — eventual consistency.
      //      For iCloud (an eventually-consistent provider) a successful gateway
      //      write IS the success criterion: neither the provider's courtesy
      //      poll nor the orchestrator's post-upload verification may fail the
      //      backup on non-visibility (BUG-1 fix, qp-20260627-icloud-eventual-
      //      consistency-fix). The backup must SUCCEED and log success; it must
      //      also not hang.
      // -----------------------------------------------------------------------
      test(
        'should_complete_backup_and_log_success_when_poll_exhausted_for_icloud'
        ' (EC-04/FR-03 eventual-consistency)',
        () {
          fakeAsync((fake) {
            // invisibleForGatherCalls >> kIcloudPollMaxAttempts (10) so the
            // blob never becomes visible within the poll bound — yet the
            // gateway write succeeded, so the backup must still complete.
            final gw = FakeIcloudGateway(invisibleForGatherCalls: 9999);
            final provider = IcloudProvider(
              gateway: gw,
              delay: Future<void>.delayed,
            );
            final orch = _makeOrchestrator(
              storage: storage,
              provider: provider,
              settingsRepo: settingsRepo,
              syncLogRepo: syncLogRepo,
              logRepo: logRepo,
            );

            bool completed = false;
            Object? capturedError;
            orch.backup().then((_) {
              completed = true;
            }).catchError((Object e) {
              capturedError = e;
            });

            // Advance the virtual clock past the full poll bound:
            //   kIcloudPollMaxAttempts (10) × kIcloudPollInterval (500 ms)
            //   = 5 000 ms total; 9 inter-attempt delays × 500 ms = 4 500 ms
            //   (no trailing delay on the final attempt — off-by-one guard).
            // 10 seconds is comfortably beyond the 4 500 ms needed (no hang).
            fake.elapse(const Duration(seconds: 10));

            expect(
              completed,
              isTrue,
              reason: 'backup() must complete even when the poll bound is '
                  'exhausted: the gateway write succeeded and iCloud is '
                  'eventually consistent (BUG-1 fix)',
            );
            expect(
              capturedError,
              isNull,
              reason: 'no exception may escape a backup whose bytes were '
                  'committed to the iCloud container',
            );

            // The orchestrator logs a SUCCESS entry (the verification no longer
            // fails the backup for iCloud — kEventuallyConsistentProviders).
            expect(
              syncLogRepo.appended,
              isNotEmpty,
              reason: 'at least one SyncLogEntity must be appended',
            );
            final log = syncLogRepo.appended.last;
            expect(
              log.success,
              isTrue,
              reason: 'the final log entry must record a successful backup '
                  '(gateway-write success is the iCloud success criterion)',
            );
            expect(
              log.provider,
              SyncProvider.iCloud,
              reason: 'the success log must stamp SyncProvider.iCloud (FR-04)',
            );
            expect(
              log.operation,
              SyncOperation.backup,
              reason: 'the operation kind must be backup',
            );
          });
        },
      );
    },
  );
}
