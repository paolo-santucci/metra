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

/// Integration test: real [IcloudProvider] + real [SyncOrchestrator] + fake
/// gateway wired end-to-end through the BUG-1 eventual-consistency call path.
///
/// Before T-01 + T-02 this test would have thrown at the provider poll or the
/// orchestrator verification, leaving `lastBackupAt` empty and recording a
/// failure log.  After both fixes, the backup completes normally.
///
/// Scope: wiring/verification only — no new production logic.  If this test
/// requires any production change that is not already landed, that is a missing
/// task and should be reported rather than fixed here.
library icloud_eventual_consistency_integration_test;

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/backup_service.dart';
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
// Wiring helper — mirrors _make() in sync_orchestrator_test.dart exactly.
// Uses a fast Argon2id so encryption does not dominate test runtime.
// ---------------------------------------------------------------------------
SyncOrchestrator _makeOrchestrator({
  required InMemorySecureStorage storage,
  required IcloudProvider provider,
  required FakeAppSettingsRepository settingsRepo,
  required FakeSyncLogRepository syncLogRepo,
  required FakeDailyLogRepository logRepo,
  required DateTime Function() now,
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
    now: now,
  );
}

void main() {
  const passphraseKey = 'metra_backup_passphrase_v1';
  const passphrase = 'test-passphrase-integration';

  test(
    'icloud_backup_completes_end_to_end_under_eventual_consistency',
    () async {
      // ── Fixed clock so the asserted timestamp is deterministic ─────────
      final fixedNow = DateTime.utc(2026, 6, 28, 9, 0, 0);

      // ── Gateway: upload() commits bytes; gather() NEVER returns the new
      //    file within the provider's bounded poll (invisibleForGatherCalls
      //    >> kIcloudPollMaxAttempts = 10).  After T-01 this is non-fatal. ──
      final gateway = FakeIcloudGateway(
        invisibleForGatherCalls: 999,
      );

      // ── Real IcloudProvider — no-op delay so the poll loop runs
      //    synchronously without any real 500 ms waits.  The gateway's
      //    gather() still returns empty for all 10 attempts, which after
      //    T-01 causes a normal return rather than a throw. ─────────────────
      final icloudProvider = IcloudProvider(
        gateway: gateway,
        delay: (_) async {},
      );

      // ── Supporting fakes (same idiom as sync_orchestrator_test.dart) ────
      final storage = InMemorySecureStorage();
      storage.values[passphraseKey] = passphrase;

      final settingsRepo = FakeAppSettingsRepository();
      final syncLogRepo = FakeSyncLogRepository();
      final logRepo = FakeDailyLogRepository();

      // ── Real SyncOrchestrator over the real provider ─────────────────────
      final orchestrator = _makeOrchestrator(
        storage: storage,
        provider: icloudProvider,
        settingsRepo: settingsRepo,
        syncLogRepo: syncLogRepo,
        logRepo: logRepo,
        now: () => fixedNow,
      );

      // ── Act: before T-01+T-02 this would throw at the provider poll or
      //    the orchestrator 'Upload verification failed' gate ────────────────
      await orchestrator.backup();

      // ── Assert 1: completed without throw (implicit — would fail above) ──

      // ── Assert 2: lastBackupAt is populated with the fixed timestamp ──────
      final settings = await settingsRepo.getOrCreate();
      expect(
        settings.lastBackupAt,
        equals(fixedNow),
        reason:
            'lastBackupAt must be recorded even when iCloud listFiles() lags',
      );

      // ── Assert 3: exactly one success log for the iCloud provider ─────────
      final successLogs = syncLogRepo.appended
          .where(
            (e) => e.success && e.operation == SyncOperation.backup,
          )
          .toList();
      expect(
        successLogs,
        hasLength(1),
        reason: 'exactly one success SyncLogEntity must be recorded',
      );
      expect(
        successLogs.first.provider,
        equals(SyncProvider.iCloud),
        reason: 'success log must carry the iCloud provider id',
      );

      // ── Assert 4: the gateway write actually committed the blob (sanity) ──
      expect(
        gateway.store,
        hasLength(1),
        reason: 'gateway.store must contain the uploaded blob confirming the '
            'write was attempted despite the poll seeing nothing',
      );
    },
  );
}
