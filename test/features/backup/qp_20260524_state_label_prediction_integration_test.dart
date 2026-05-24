// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

// T-F: integration tests wiring all five fixes together (T-A through T-E).
//
// Test 1 — backup_lifecycle_label_reflects_writes_resume_via_manual_tap
//   Exercises: BUG-B01 (reactive label), BUG-B03 (passphrase wipe on delete),
//              BUG-B04 (connect clears suspended), BUG-B02 (manual tap resumes).
//   Infrastructure: real DriftAppSettingsRepository over in-memory Drift DB,
//   real DeleteAllData use case (via provider), fake cloud + fake backup runner.
//
// Test 2 — overdue_user_with_1_cycle_shows_past_prediction_dots
//   Exercises: BUG-P1 (no while-loop in fallback path), BUG-P4 (past calendar
//   dots rendered when user is overdue).
//   Infrastructure: real DriftAppSettingsRepository + DriftCycleEntryRepository
//   over in-memory Drift DB, real CyclePredictionService, CalendarScreen
//   widget test.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';
import 'package:metra/data/repositories/drift_app_settings_repository.dart';
import 'package:metra/data/repositories/drift_cycle_entry_repository.dart';
import 'package:metra/data/repositories/drift_daily_log_repository.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/repositories/app_settings_repository.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/calendar/state/prediction_controller.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../helpers/fake_dropbox_provider.dart';
import '../../helpers/fake_sync_log_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Shared fake infrastructure
// ---------------------------------------------------------------------------

/// A BackupRunner that updates [lastBackupAt] on the real settings repo during
/// [backup()], mirroring what [SyncOrchestrator] does in production.
///
/// Preserves [dropboxEmail] so the state stays [BackupConnected] after backup.
class _LastBackupAtUpdatingRunner implements BackupRunner {
  _LastBackupAtUpdatingRunner(this._settingsRepo);

  final AppSettingsRepository _settingsRepo;
  bool backupCalled = false;

  @override
  Future<void> backup() async {
    backupCalled = true;
    final current = await _settingsRepo.getOrCreate();
    await _settingsRepo.updateBackupState(
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> restore({String? filename}) async {}
}

// ---------------------------------------------------------------------------
// Test 1 — backup lifecycle (B01 + B03 + B04 + B02)
// ---------------------------------------------------------------------------

void main() {
  // ── Test 1 ──────────────────────────────────────────────────────────────────

  test(
    'backup_lifecycle_label_reflects_writes_resume_via_manual_tap',
    () async {
      // ── Setup ───────────────────────────────────────────────────────────────

      // Real Drift in-memory DB + real repositories (all share the same DB).
      final db = AppDatabase(NativeDatabase.memory());
      final realSettingsRepo = DriftAppSettingsRepository(db.appSettingsDao);
      final realCycleRepo = DriftCycleEntryRepository(
        db.cycleEntryDao,
        realSettingsRepo,
      );
      final realLogRepo = DriftDailyLogRepository(
        db.dailyLogDao,
        realSettingsRepo,
      );

      // Pre-seed: create the settings row, then set email + passphrase.
      await realSettingsRepo.getOrCreate();
      await realSettingsRepo.updateBackupState(
        dropboxEmail: 'a@b.test',
        lastBackupAt: null,
      );
      // backupSuspended defaults to false.

      final storage = InMemorySecureStorage();
      storage.values[BackupNotifier.kPassphraseKey] = 'pw';

      final fakeDropbox = FakeDropboxProvider();
      fakeDropbox.currentEmailResult = 'a@b.test';

      final fakeSyncLog = FakeSyncLogRepository();

      // Custom runner that writes lastBackupAt to the real repo on backup().
      final backupRunner = _LastBackupAtUpdatingRunner(realSettingsRepo);

      final container = ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider
              .overrideWith((_) async => realSettingsRepo),
          // Override daily-log + cycle repos so deleteAllDataProvider uses the
          // same in-memory DB (avoids pulling in databaseProvider).
          dailyLogRepositoryProvider.overrideWith((_) async => realLogRepo),
          cycleEntryRepositoryProvider.overrideWith((_) async => realCycleRepo),
          secureStorageProvider.overrideWithValue(storage),
          backupDataProvider
              .overrideWith((_) async => BackupData(backupRunner)),
          restoreDataProvider
              .overrideWith((_) async => RestoreData(backupRunner)),
          cloudBackupProvider.overrideWithValue(fakeDropbox),
          syncLogRepositoryProvider.overrideWith((_) async => fakeSyncLog),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      // ── Act 1: initial build ─────────────────────────────────────────────
      final s1 = await container.read(backupNotifierProvider.future);
      expect(
        s1,
        isA<BackupConnected>(),
        reason: 'precondition: email set, passphrase stored → BackupConnected',
      );
      expect(
        (s1 as BackupConnected).autoBackupActive,
        isTrue,
        reason:
            'precondition: not suspended, passphrase set → autoBackupActive',
      );
      expect(s1.passphraseSet, isTrue);

      // ── Act 2: DeleteAllData.execute() ────────────────────────────────────
      // Read the real DeleteAllData via provider; all repo dependencies are
      // overridden above to use the same in-memory DB instance.
      final deleteUseCase = await container.read(deleteAllDataProvider.future);
      await deleteUseCase.execute();

      // Pump to let the Drift stream re-emit and build() re-run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Assert 2a: passphrase wiped (B03)
      expect(
        storage.values.containsKey(BackupNotifier.kPassphraseKey),
        isFalse,
        reason: 'BUG-B03: execute() must delete the cached passphrase',
      );

      // Assert 2b: backupSuspended written to DB
      final settingsAfterDelete = await realSettingsRepo.getOrCreate();
      expect(
        settingsAfterDelete.backupSuspended,
        isTrue,
        reason:
            'DeleteAllData.execute() must set backupSuspended=true in the real repo',
      );

      // Assert 2c: label flipped reactively (B01) — no manual invalidate needed.
      final s2 = await container.read(backupNotifierProvider.future);
      expect(s2, isA<BackupConnected>());
      final s2c = s2 as BackupConnected;
      expect(
        s2c.passphraseSet,
        isFalse,
        reason: 'BUG-B03: passphrase wiped → passphraseSet must be false',
      );
      expect(
        s2c.autoBackupActive,
        isFalse,
        reason:
            'BUG-B01: reactive label flip — backupSuspended=true + no passphrase '
            '→ autoBackupActive=false without a manual invalidateSelf()',
      );

      // ── Act 3: reconnect via connect() ───────────────────────────────────
      await container.read(backupNotifierProvider.notifier).connect();

      // Pump to let the Drift stream propagate after connect() writes.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Assert 3a: suspended sentinel cleared (B04)
      final settingsAfterConnect = await realSettingsRepo.getOrCreate();
      expect(
        settingsAfterConnect.backupSuspended,
        isFalse,
        reason:
            'BUG-B04: connect() must call clearBackupSuspended() so user is not '
            'permanently stuck in suspended state after reconnect',
      );

      // Assert 3b: state is BackupConnected with no passphrase yet
      final s3 = await container.read(backupNotifierProvider.future);
      expect(s3, isA<BackupConnected>());
      final s3c = s3 as BackupConnected;
      expect(
        s3c.email,
        equals('a@b.test'),
        reason: 'email must be set from connect()',
      );
      expect(
        s3c.passphraseSet,
        isFalse,
        reason: 'no passphrase stored yet → passphraseSet=false',
      );
      expect(
        s3c.autoBackupActive,
        isFalse,
        reason:
            'no passphrase → autoBackupActive=false (not because suspended)',
      );

      // ── Act 4: manual backup with new passphrase (B02) ───────────────────
      await container
          .read(backupNotifierProvider.notifier)
          .backupWithPassphrase('pw_new');

      // Pump to let invalidateSelf() + Drift stream re-emit settle.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Assert 4: backup proceeded — passphrase stored, lastBackupAt set, active.
      expect(
        storage.values[BackupNotifier.kPassphraseKey],
        equals('pw_new'),
        reason: 'backupWithPassphrase must store the new passphrase',
      );

      final s4 = await container.read(backupNotifierProvider.future);
      expect(s4, isA<BackupConnected>());
      final s4c = s4 as BackupConnected;
      expect(
        s4c.passphraseSet,
        isTrue,
        reason:
            'BUG-B02: after manual backup with passphrase, passphraseSet=true',
      );
      expect(
        s4c.autoBackupActive,
        isTrue,
        reason: 'BUG-B02: sentinel cleared by connect() + passphrase now set '
            '→ autoBackupActive=true',
      );
      expect(
        s4c.lastBackupAt,
        isNotNull,
        reason:
            'BUG-B02: backup runner updated lastBackupAt → state must reflect it',
      );

      // Assert: no 'backupSkipped' entry was appended at any point.
      final skipped = fakeSyncLog.appended
          .where((e) => e.errorMessage?.contains('skipped') ?? false)
          .toList();
      expect(
        skipped,
        isEmpty,
        reason: 'No SyncLog backupSkipped entry should exist in the full flow',
      );
    },
  );

  // ── Test 2 ──────────────────────────────────────────────────────────────────
  //
  // Pure ProviderContainer test (no widget pumping) — avoids the pumpAndSettle
  // hang caused by live Drift streams in a Flutter test environment.
  //
  // The widget-level P4 assertion (CalendarDay.hasPrediction=true for past dates)
  // is covered by calendar_screen_overdue_prediction_test.dart (T-D unit test).
  // T-F's role here is to verify the integration: that the real production chain
  // (DriftCycleEntryRepository → WatchCyclePrediction → CyclePredictionService
  //  → cyclePredictionProvider) produces a CyclePrediction whose window covers
  // pastDate, so that CyclePrediction.containsDate(pastDate) — the exact
  // predicate CalendarScreen uses for hasPrediction — returns true (P4 wiring).

  test(
    'overdue_user_with_1_cycle_shows_past_prediction_dots',
    () async {
      // ── Setup ───────────────────────────────────────────────────────────────

      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);

      // One cycle entry: startDate = today - 33 days, cycleLength = null.
      // declaredCycleLength = 28. BUG-P1: expectedStart = today - 5 days.
      final cycleStart = todayUtc.subtract(const Duration(days: 33));

      // The past calendar day to assert (today - 5 = expectedStart).
      final pastDate = todayUtc.subtract(const Duration(days: 5));

      // Real Drift in-memory DB — separate from Test 1.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final realSettingsRepo = DriftAppSettingsRepository(db.appSettingsDao);
      final realCycleRepo = DriftCycleEntryRepository(
        db.cycleEntryDao,
        realSettingsRepo,
      );

      // Seed settings: declaredCycleLength = 28.
      await realSettingsRepo.getOrCreate();
      await realSettingsRepo.saveDeclaredCycleLength(28);

      // Insert the single cycle entry. cycleLength = null → fallback path.
      // Note: insert() also calls clearBackupSuspended() on realSettingsRepo.
      await realCycleRepo.insert(
        CycleEntryEntity(
          id: 0, // DAO assigns real ID on insert
          startDate: cycleStart,
        ),
      );

      // ── Provider-level assertion (P1 + P4 wiring) ─────────────────────────
      // Wire the full real prediction chain:
      //   appSettingsRepositoryProvider → DriftAppSettingsRepository
      //   cycleEntryRepositoryProvider  → DriftCycleEntryRepository
      //   appSettingsStreamProvider     → real Drift stream from realSettingsRepo
      //   watchCyclePredictionProvider  → real WatchCyclePrediction
      //   cyclePredictionServiceProvider → real CyclePredictionService
      //   cyclePredictionProvider       → real StreamProvider (NOT overridden)
      final container = ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider
              .overrideWith((_) async => realSettingsRepo),
          cycleEntryRepositoryProvider.overrideWith((_) async => realCycleRepo),
        ],
      );
      addTearDown(container.dispose);

      // Collect the first non-loading emission from cyclePredictionProvider.
      // Use a completer with timeout so a hang shows as a test failure
      // rather than a silent 30-minute CI timeout.
      CyclePrediction? prediction;
      final completer = Completer<CyclePrediction?>();

      final sub = container.listen(cyclePredictionProvider, (_, next) {
        if (!completer.isCompleted && next is AsyncData<CyclePrediction?>) {
          completer.complete(next.value);
        }
      });
      addTearDown(sub.close);

      prediction = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TestFailure('cyclePredictionProvider timed out after 10s'),
      );

      // ── Assert P1: fallback path returns past expectedStart (no while-loop) ─
      expect(
        prediction,
        isNotNull,
        reason:
            'BUG-P1: CyclePredictionService fallback path must return a non-null '
            'CyclePrediction for 1 cycle + declaredCycleLength=28',
      );
      expect(
        prediction!.expectedStart,
        equals(pastDate),
        reason:
            'BUG-P1: expectedStart must be today-33+28 = today-5 (no while-loop '
            'advancing to the future)',
      );
      expect(
        prediction.windowStart,
        equals(pastDate.subtract(const Duration(days: 2))),
        reason: 'windowStart = expectedStart - 2 days',
      );
      expect(
        prediction.windowEnd,
        equals(pastDate.add(const Duration(days: 2))),
        reason: 'windowEnd = expectedStart + 2 days',
      );
      expect(
        prediction.cyclesUsed,
        equals(0),
        reason: 'cyclesUsed = 0 signals the fallback (estimated) path',
      );

      // ── Assert P4: containsDate(pastDate) == true (calendar hasPrediction) ─
      // CyclePrediction.containsDate is the exact predicate used by CalendarScreen
      // to compute hasPrediction. Verified true here → CalendarDay.hasPrediction
      // would be true for pastDate (T-D's unit test covers the widget rendering).
      expect(
        prediction.containsDate(pastDate),
        isTrue,
        reason:
            'BUG-P4: prediction.containsDate(pastDate=$pastDate) must be true '
            'so CalendarScreen sets hasPrediction=true for this past date. '
            'The legacy !date.isBefore(todayUtc) guard in calendar_screen.dart '
            'has been removed (T-D fix), so the calendar will render the dot.',
      );

      // Regression: dates outside the window must NOT match.
      final beforeWindow =
          prediction.windowStart.subtract(const Duration(days: 1));
      expect(
        prediction.containsDate(beforeWindow),
        isFalse,
        reason:
            'Date just before windowStart must not be inside the prediction window',
      );

      final afterWindow = prediction.windowEnd.add(const Duration(days: 1));
      expect(
        prediction.containsDate(afterWindow),
        isFalse,
        reason:
            'Date just after windowEnd must not be inside the prediction window',
      );
    },
  );
}
