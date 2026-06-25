// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

// Platforms: Android, iOS, Linux (in-memory only — no device interaction)
//
// TASK-08 — FR-04 honest log-stamp integration test (iCloud).
//
// Asserts that SyncOrchestrator records provider == SyncProvider.iCloud
// when _TrackingICloudProvider is injected, and provider == SyncProvider.dropbox
// when FakeDropboxProvider is injected. This proves the stamp follows the
// injected provider's `id`, not a hardcode.
//
// DIP guard: sync_orchestrator.dart is NOT modified; no iCloud branch is
// introduced. The read-after-write contract is satisfied entirely by the
// tracking double's listFiles() returning the just-uploaded blob.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/backup_service.dart';
import 'package:metra/data/services/backup/sync_orchestrator.dart';
import 'package:metra/data/services/encryption_service.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

import 'package:metra/data/services/backup/cloud_backup_provider.dart';

import '../../../helpers/fake_app_settings_repository.dart';
import '../../../helpers/fake_daily_log_repository.dart';
import '../../../helpers/fake_dropbox_provider.dart';
import '../../../helpers/fake_icloud_provider.dart';
import '../../../helpers/fake_sync_log_repository.dart';
import '../../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Test-local upload-tracking subclass.
//
// FakeICloudProvider.listFiles() returns [] unconditionally, which causes
// SyncOrchestrator.backup() to throw 'Upload verification failed' at the
// post-upload check. A minimal subclass — defined here, NOT in
// fake_icloud_provider.dart — tracks uploads so listFiles() returns the
// uploaded filename, satisfying the verification step.
// This subclass is local to this test file and does not change the shared fake.
// ---------------------------------------------------------------------------

class _TrackingICloudProvider extends FakeICloudProvider {
  final List<String> _uploadedNames = [];

  @override
  Future<void> upload(Uint8List blob, String filename) async {
    _uploadedNames.add(filename);
  }

  @override
  Future<List<BackupFileEntry>> listFiles() async {
    return _uploadedNames
        .map(
          (name) => BackupFileEntry(
            name: name,
            timestampUtc: DateTime.utc(2026, 6, 24),
            sizeBytes: 0,
          ),
        )
        .toList()
        .reversed
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Shared fixture builder — mirrors _make() in sync_orchestrator_test.dart,
// accepting CloudBackupProvider so it works for both fakes.
// ---------------------------------------------------------------------------

SyncOrchestrator _makeWith({
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
    now: () => DateTime.utc(2026, 6, 24, 12, 0, 0),
  );
}

void main() {
  const passphrase = 'test-passphrase-42';
  const passphraseKey = 'metra_backup_passphrase_v1';

  late InMemorySecureStorage storage;
  late FakeAppSettingsRepository settingsRepo;
  late FakeSyncLogRepository syncLogRepo;
  late FakeDailyLogRepository logRepo;

  setUp(() {
    storage = InMemorySecureStorage();
    settingsRepo = FakeAppSettingsRepository();
    syncLogRepo = FakeSyncLogRepository();
    logRepo = FakeDailyLogRepository();
    storage.values[passphraseKey] = passphrase;
  });

  group(
    'FR-04 — SyncOrchestrator log-stamp follows injected iCloud provider id',
    () {
      test(
        'should_record_iCloud_provider_when_TrackingICloudProvider_injected',
        () async {
          final provider = _TrackingICloudProvider();
          final orch = _makeWith(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );

          await orch.backup();

          expect(syncLogRepo.appended, hasLength(1));
          final log = syncLogRepo.appended.first;
          expect(log.success, isTrue);
          expect(log.operation, SyncOperation.backup);
          expect(
            log.provider,
            SyncProvider.iCloud,
            reason:
                'The recorded SyncLogEntity.provider must match the injected '
                "provider's id (iCloud), not a hardcoded dropbox or googleDrive "
                'value. DIP guard: no iCloud branch exists in sync_orchestrator.dart.',
          );
        },
      );

      test(
        'should_record_dropbox_provider_when_FakeDropboxProvider_injected'
        '_negative_guard',
        () async {
          final provider = FakeDropboxProvider();
          final orch = _makeWith(
            storage: storage,
            provider: provider,
            settingsRepo: settingsRepo,
            syncLogRepo: syncLogRepo,
            logRepo: logRepo,
          );

          await orch.backup();

          expect(syncLogRepo.appended, hasLength(1));
          final log = syncLogRepo.appended.first;
          expect(log.success, isTrue);
          expect(log.operation, SyncOperation.backup);
          expect(
            log.provider,
            SyncProvider.dropbox,
            reason: 'Negative guard: injecting FakeDropboxProvider must stamp '
                'dropbox — proves the stamp is driven by provider.id, not a '
                'hardcode.',
          );
        },
      );
    },
  );
}
