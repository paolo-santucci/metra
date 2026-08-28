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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/constants/app_constants.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/domain/use_cases/delete_all_data.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Local subclass that also logs setActiveProvider calls.
// Needed for EC-08 ordering tests: the base FakeAppSettingsRepository does not
// log setActiveProvider, so we add that here without touching the shared fake.
// ---------------------------------------------------------------------------
class _LoggingSettingsRepo extends FakeAppSettingsRepository {
  @override
  Future<void> setActiveProvider(SyncProvider provider) async {
    await super.setActiveProvider(provider);
    callLog.add('setActiveProvider:$provider');
  }
}

// ---------------------------------------------------------------------------
// Tiny wrapper used ONLY for call-order assertion in Test 1.
// Wraps an InMemorySecureStorage and, at delete() time, captures a snapshot
// of the settingsRepo callLog — proving updateBackupSuspended(true) ran first.
// ---------------------------------------------------------------------------
class _OrderCapturingStorage implements FlutterSecureStorage {
  _OrderCapturingStorage(this._inner, this._settingsRepo);

  final InMemorySecureStorage _inner;
  final FakeAppSettingsRepository _settingsRepo;

  /// callLog snapshot captured at the moment delete() was invoked.
  List<String>? callLogAtDelete;

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    callLogAtDelete = List<String>.from(_settingsRepo.callLog);
    await _inner.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeDailyLogRepository fakeLogRepo;
  late FakeCycleEntryRepository fakeCycleRepo;
  late FakeAppSettingsRepository fakeSettingsRepo;
  late InMemorySecureStorage fakeStorage;
  late DeleteAllData useCase;

  setUp(() {
    fakeLogRepo = FakeDailyLogRepository();
    fakeCycleRepo = FakeCycleEntryRepository();
    fakeSettingsRepo = FakeAppSettingsRepository();
    fakeStorage = InMemorySecureStorage();
    useCase = DeleteAllData(
      fakeLogRepo,
      fakeCycleRepo,
      fakeSettingsRepo,
      fakeStorage,
    );
  });

  // ── Pre-existing tests (4-arg constructor now) ───────────────────────────

  test(
    'given_four_repos_when_constructed_then_DeleteAllData_accepts_FlutterSecureStorage',
    () {
      final instance = DeleteAllData(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
        FakeAppSettingsRepository(),
        InMemorySecureStorage(),
      );
      expect(instance, isA<DeleteAllData>());
    },
  );

  test('execute() calls deleteAll on both repositories', () async {
    await useCase.execute();

    expect(fakeLogRepo.deleteAllCalled, isTrue);
    expect(fakeCycleRepo.deleteAllCalled, isTrue);
  });

  test('execute() clears data in both fakes', () async {
    await fakeLogRepo
        .saveDailyLog(DailyLogEntity(date: DateTime.utc(2026, 1, 1)));
    await fakeCycleRepo.insert(
      CycleEntryEntity(id: 0, startDate: DateTime.utc(2026, 1, 1)),
    );

    await useCase.execute();

    expect(fakeLogRepo.savedLogs, isEmpty);
    expect(fakeCycleRepo.entries, isEmpty);
  });

  test(
    'FR-12a — happy path: updateBackupSuspended(true) recorded AFTER both deleteAll calls',
    () async {
      final fakeLogs = FakeDailyLogRepository();
      final fakeCycles = FakeCycleEntryRepository();
      final fakeSettings = FakeAppSettingsRepository();
      await DeleteAllData(
        fakeLogs,
        fakeCycles,
        fakeSettings,
        InMemorySecureStorage(),
      ).execute();
      expect(fakeLogs.callLog, contains('deleteAll'));
      expect(fakeCycles.callLog, contains('deleteAll'));
      expect(fakeSettings.callLog, contains('updateBackupSuspended:true'));
    },
  );

  test(
    'NFR-04 — partial failure: cycleRepo.deleteAll throws, settings is not mutated',
    () async {
      final fakeLogs = FakeDailyLogRepository();
      final fakeCycles = FakeCycleEntryRepository()
        ..throwOnDeleteAll = StateError('boom');
      final fakeSettings = FakeAppSettingsRepository();
      await expectLater(
        DeleteAllData(
          fakeLogs,
          fakeCycles,
          fakeSettings,
          InMemorySecureStorage(),
        ).execute(),
        throwsA(isA<StateError>()),
      );
      expect(
        fakeSettings.callLog.contains('updateBackupSuspended:true'),
        isFalse,
      );
    },
  );

  // ── BUG-B03 new tests ───────────────────────────────────────────────────

  test(
    'execute_deletes_passphrase_after_updating_backupSuspended',
    () async {
      // Arrange: storage pre-seeded; use the order-capturing wrapper to prove
      // updateBackupSuspended(true) ran BEFORE secureStorage.delete().
      final storage = InMemorySecureStorage()
        ..values[AppConstants.kBackupPassphraseKey] = 'pw';
      final settings = FakeAppSettingsRepository();
      final capturingStorage = _OrderCapturingStorage(storage, settings);

      final uc = DeleteAllData(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
        settings,
        capturingStorage,
      );

      // Act
      await uc.execute();

      // Assert: key removed from storage.
      expect(
        storage.values.containsKey(AppConstants.kBackupPassphraseKey),
        isFalse,
      );

      // Assert: at the moment delete() ran, settingsRepo had already recorded
      // updateBackupSuspended(true) — proving HC-2 ordering.
      expect(
        capturingStorage.callLogAtDelete,
        isNotNull,
        reason: 'delete() must have been called',
      );
      expect(
        capturingStorage.callLogAtDelete,
        contains('updateBackupSuspended:true'),
        reason:
            'updateBackupSuspended(true) must precede secureStorage.delete()',
      );

      // Assert other repos called exactly once.
      expect(settings.callLog, contains('updateBackupSuspended:true'));
    },
  );

  test(
    'execute_does_not_throw_when_passphrase_key_absent',
    () async {
      // Arrange: empty storage — key was never set.
      final emptyStorage = InMemorySecureStorage();
      final uc = DeleteAllData(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
        FakeAppSettingsRepository(),
        emptyStorage,
      );

      // Act + Assert: no exception.
      await expectLater(uc.execute(), completes);

      // The key is still absent — no side-effects.
      expect(
        emptyStorage.values.containsKey(AppConstants.kBackupPassphraseKey),
        isFalse,
      );
    },
  );

  test(
    'deleteAllDataProvider_wires_secureStorageProvider',
    () async {
      // Arrange: seeded storage so we can confirm the SAME instance is used.
      final storage = InMemorySecureStorage()
        ..values[AppConstants.kBackupPassphraseKey] = 'pw';

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          dailyLogRepositoryProvider.overrideWith(
            (ref) async => FakeDailyLogRepository(),
          ),
          cycleEntryRepositoryProvider.overrideWith(
            (ref) async => FakeCycleEntryRepository(),
          ),
          appSettingsRepositoryProvider.overrideWith(
            (ref) async => FakeAppSettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Act: resolve the provider and call execute().
      final uc = await container.read(deleteAllDataProvider.future);
      await uc.execute();

      // Assert: the same FakeStorage instance had its key deleted.
      expect(
        storage.values.containsKey(AppConstants.kBackupPassphraseKey),
        isFalse,
        reason:
            'deleteAllDataProvider must wire secureStorageProvider — same instance',
      );
    },
  );

  // ── FR-21 / FR-23 new tests (TASK-11) ────────────────────────────────────

  test(
    'given_execute_when_called_then_setActiveProvider_dropbox_is_invoked_via_dedicated_writer',
    () async {
      // FR-21: execute() must call setActiveProvider(SyncProvider.dropbox).
      // The logging subclass records the call; we assert it appears in callLog.
      final loggingSettings = _LoggingSettingsRepo();
      final uc = DeleteAllData(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
        loggingSettings,
        InMemorySecureStorage(),
      );

      await uc.execute();

      expect(
        loggingSettings.callLog,
        contains('setActiveProvider:SyncProvider.dropbox'),
        reason:
            'execute() must reset activeProvider to dropbox via dedicated writer',
      );
      // Confirm the stored value reflects the reset.
      final stored = await loggingSettings.getOrCreate();
      expect(stored.activeProvider, SyncProvider.dropbox);
    },
  );

  test(
    'given_execute_when_called_then_setActiveProvider_and_updateBackupSuspended_precede_passphrase_wipe_EC08',
    () async {
      // EC-08 ordering: setActiveProvider(dropbox) + updateBackupSuspended(true)
      // must both appear in callLog BEFORE secureStorage.delete() fires.
      final loggingSettings = _LoggingSettingsRepo();
      final storage = InMemorySecureStorage()
        ..values[AppConstants.kBackupPassphraseKey] = 'pw';
      final capturingStorage = _OrderCapturingStorage(storage, loggingSettings);

      final uc = DeleteAllData(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
        loggingSettings,
        capturingStorage,
      );

      await uc.execute();

      // Both writes must have been recorded before delete() fired.
      expect(
        capturingStorage.callLogAtDelete,
        isNotNull,
        reason: 'delete() must have been called',
      );
      expect(
        capturingStorage.callLogAtDelete,
        contains('setActiveProvider:SyncProvider.dropbox'),
        reason: 'setActiveProvider(dropbox) must precede passphrase wipe',
      );
      expect(
        capturingStorage.callLogAtDelete,
        contains('updateBackupSuspended:true'),
        reason: 'updateBackupSuspended(true) must precede passphrase wipe',
      );
    },
  );

  test(
    'given_execute_when_called_then_delete_all_data_references_shared_constant',
    () async {
      // FR-23: kBackupPassphraseKey from app_constants.dart must be used
      // (not an inline literal). The storage uses the shared constant as key;
      // if delete_all_data.dart still used its own literal, the key would not
      // be deleted.
      final storage = InMemorySecureStorage()
        ..values[AppConstants.kBackupPassphraseKey] = 'pw';

      final uc = DeleteAllData(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
        FakeAppSettingsRepository(),
        storage,
      );

      await uc.execute();

      // If the production code used a different literal key, the value would
      // remain in storage — which would fail this assertion.
      expect(
        storage.values.containsKey(AppConstants.kBackupPassphraseKey),
        isFalse,
        reason:
            'execute() must delete using the shared AppConstants.kBackupPassphraseKey',
      );
    },
  );
}
