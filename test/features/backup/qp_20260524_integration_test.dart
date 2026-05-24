// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later
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

// T-D — Integration: backup lifecycle + restore cycle-day invalidation
// (qp-20260524-backup-ui-prediction-bugs.md §4 T-D)
//
// Scenario covered by the single integration test:
//
//   Act 1 — connected, no passphrase:
//             BackupConnected(passphraseSet: false, autoBackupActive: false)
//
//   Act 2 — backupWithPassphrase('pw') succeeds:
//             BackupConnected(passphraseSet: true, autoBackupActive: true,
//                             lastBackupAt: <non-null>)
//
//   Act 3 — restore() succeeds:
//             BackupConnected (notifier rebuilt from updated storage)
//             currentCycleDayProvider counter == 2 (invalidated by Ok branch)
//             cycleDayForDateProvider counter == 2 (invalidated by Ok branch)
//
// Platform: Linux CI — no device required.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/util/nullable.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/repositories/app_settings_repository.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/fake_dropbox_provider.dart';
import '../../helpers/fake_sync_log_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Runners
// ---------------------------------------------------------------------------

/// A [BackupRunner] that records a `lastBackupAt` timestamp on `backup()`.
///
/// `_OkRunner` (no-op) cannot be used for Act 2 because the plan asserts
/// `lastBackupAt: <non-null>` after the backup. `BackupNotifier._runBackup`
/// calls `ref.invalidateSelf()` after a successful backup, which triggers a
/// `build()` re-read from [AppSettingsRepository]. Unless the repository was
/// actually updated with a non-null `lastBackupAt`, the rebuild would produce
/// `BackupConnected(lastBackupAt: null)`.
class _LastBackupWritingRunner implements BackupRunner {
  _LastBackupWritingRunner(this._settingsRepo);
  final AppSettingsRepository _settingsRepo;

  @override
  Future<void> backup() async {
    final current = await _settingsRepo.getOrCreate();
    // updateBackupState does NOT internally copyWith — pass dropboxEmail
    // explicitly to prevent it being overwritten with null (which would cause
    // the notifier rebuild to land in BackupNotConnected).
    await _settingsRepo.updateBackupState(
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<int> restore({String? filename}) async => 0;
}

/// A [BackupRunner] that succeeds immediately without side-effects.
///
/// Used for the restore-side so the Ok branch fires and triggers the
/// `ref.invalidateSelf()` + cycle-day provider invalidations.
class _OkRunner implements BackupRunner {
  @override
  Future<void> backup() async {}

  @override
  Future<int> restore({String? filename}) async => 0;
}

// ---------------------------------------------------------------------------
// Integration test
// ---------------------------------------------------------------------------

void main() {
  group(
    'T-D — backup lifecycle + restore cycle-day invalidation',
    () {
      test(
        'backup_lifecycle_state_flips_correctly_on_passphrase_write_and_restore_invalidates_cycleday',
        () async {
          // ── Counters ────────────────────────────────────────────────────────
          var cycleDayCount = 0;
          var cycleDayForDateCount = 0;
          final testDate = DateTime.utc(2026, 5, 24);

          // ── Fakes ───────────────────────────────────────────────────────────
          final settingsRepo = FakeAppSettingsRepository()
            ..storedSettings = AppSettingsData.defaults().copyWith(
              dropboxEmail: const Nullable('a@b.test'),
            );
          final storage = InMemorySecureStorage(); // empty — no passphrase yet
          final syncLogRepo = FakeSyncLogRepository();
          final backupRunner = _LastBackupWritingRunner(settingsRepo);
          final restoreRunner = _OkRunner();

          // ── Container ───────────────────────────────────────────────────────
          final container = ProviderContainer(
            overrides: [
              appSettingsRepositoryProvider.overrideWith(
                (_) async => settingsRepo,
              ),
              secureStorageProvider.overrideWithValue(storage),
              backupDataProvider.overrideWith(
                (_) async => BackupData(backupRunner),
              ),
              restoreDataProvider.overrideWith(
                (_) async => RestoreData(restoreRunner),
              ),
              cloudBackupProvider.overrideWithValue(FakeDropboxProvider()),
              syncLogRepositoryProvider.overrideWith(
                (_) async => syncLogRepo,
              ),
              // Counter providers — increment on every create() call.
              currentCycleDayProvider.overrideWith((_) async {
                cycleDayCount++;
                return null;
              }),
              cycleDayForDateProvider.overrideWith((_, date) async {
                cycleDayForDateCount++;
                return null;
              }),
            ],
          );
          addTearDown(container.dispose);

          // ── Prime cycle-day providers once (counters → 1) ──────────────────
          await container.read(currentCycleDayProvider.future);
          await container.read(cycleDayForDateProvider(testDate).future);
          expect(cycleDayCount, 1, reason: 'primed once before any backup');
          expect(
            cycleDayForDateCount,
            1,
            reason: 'primed once before any backup',
          );

          // ══════════════════════════════════════════════════════════════════
          // Act 1 — read initial state (connected, no passphrase)
          // ══════════════════════════════════════════════════════════════════

          final state1 = await container.read(backupNotifierProvider.future);

          expect(
            state1,
            isA<BackupConnected>(),
            reason:
                'Act 1: email is set so notifier must return BackupConnected',
          );
          final connected1 = state1 as BackupConnected;
          expect(
            connected1.passphraseSet,
            isFalse,
            reason:
                'Act 1: no passphrase in storage → passphraseSet must be false',
          );
          expect(
            connected1.autoBackupActive,
            isFalse,
            reason: 'Act 1: no passphrase → autoBackupActive must be false',
          );

          // ══════════════════════════════════════════════════════════════════
          // Act 2 — backupWithPassphrase writes the passphrase and triggers a
          //         successful backup (via _LastBackupWritingRunner).
          //         After Ok, the notifier calls invalidateSelf() → rebuild.
          // ══════════════════════════════════════════════════════════════════

          await container
              .read(backupNotifierProvider.notifier)
              .backupWithPassphrase('pw');

          // Force the rebuild triggered by invalidateSelf() to complete.
          final state2 = await container.read(backupNotifierProvider.future);

          expect(
            state2,
            isA<BackupConnected>(),
            reason:
                'Act 2: after successful backup notifier must rebuild to BackupConnected',
          );
          final connected2 = state2 as BackupConnected;
          expect(
            connected2.passphraseSet,
            isTrue,
            reason:
                'Act 2: passphrase written to storage by backupWithPassphrase → '
                'passphraseSet must be true',
          );
          expect(
            connected2.autoBackupActive,
            isTrue,
            reason: 'Act 2: passphrase set and backupSuspended=false → '
                'autoBackupActive must be true',
          );
          expect(
            connected2.lastBackupAt,
            isNotNull,
            reason:
                'Act 2: _LastBackupWritingRunner writes lastBackupAt; rebuild '
                'must pick it up as non-null',
          );

          // ══════════════════════════════════════════════════════════════════
          // Act 3 — restore() triggers the Ok branch which must:
          //   • call ref.invalidateSelf()
          //   • call ref.invalidate(currentCycleDayProvider)
          //   • call ref.invalidate(cycleDayForDateProvider)
          //   • NOT call ref.invalidate(cyclePredictionProvider) (C-04)
          // ══════════════════════════════════════════════════════════════════

          await container
              .read(backupNotifierProvider.notifier)
              .restore(filename: 'metra_backup_test.enc');

          // Force the notifier rebuild to complete.
          final state3 = await container.read(backupNotifierProvider.future);

          expect(
            state3,
            isA<BackupConnected>(),
            reason:
                'Act 3: restore Ok branch must not leave the notifier in an '
                'error state; notifier rebuilds from persisted settings → '
                'BackupConnected',
          );

          // Re-read cycle-day providers to trigger the recreation
          // (invalidate + next read = counter increment).
          await container.read(currentCycleDayProvider.future);
          await container.read(cycleDayForDateProvider(testDate).future);

          expect(
            cycleDayCount,
            2,
            reason: 'Act 3: currentCycleDayProvider must be invalidated by the '
                'restore Ok branch (C-04: cyclePredictionProvider is NOT touched)',
          );
          expect(
            cycleDayForDateCount,
            2,
            reason: 'Act 3: cycleDayForDateProvider must be invalidated by the '
                'restore Ok branch',
          );
        },
      );
    },
  );
}
