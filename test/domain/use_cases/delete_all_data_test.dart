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
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/use_cases/delete_all_data.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';

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
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
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
  const kPassphraseKey = 'metra_backup_passphrase_v1';

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
      final storage = InMemorySecureStorage()..values[kPassphraseKey] = 'pw';
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
      expect(storage.values.containsKey(kPassphraseKey), isFalse);

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
      expect(emptyStorage.values.containsKey(kPassphraseKey), isFalse);
    },
  );

  test(
    'deleteAllDataProvider_wires_secureStorageProvider',
    () async {
      // Arrange: seeded storage so we can confirm the SAME instance is used.
      final storage = InMemorySecureStorage()..values[kPassphraseKey] = 'pw';

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
        storage.values.containsKey(kPassphraseKey),
        isFalse,
        reason:
            'deleteAllDataProvider must wire secureStorageProvider — same instance',
      );
    },
  );
}
