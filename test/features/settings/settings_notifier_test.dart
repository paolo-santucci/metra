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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../helpers/fake_app_settings_repository.dart';

// ---------------------------------------------------------------------------
// Streaming fake — backed by a StreamController so tests can push multiple
// settings emissions after the notifier has initialised.
// ---------------------------------------------------------------------------
class _StreamingFakeAppSettingsRepository implements FakeAppSettingsRepository {
  final _controller = StreamController<AppSettingsData?>.broadcast();
  AppSettingsData? _stored;

  @override
  AppSettingsData? get storedSettings => _stored;
  @override
  set storedSettings(AppSettingsData? v) => _stored = v;

  void emit(AppSettingsData? settings) {
    _stored = settings;
    _controller.add(settings);
  }

  void close() => _controller.close();

  @override
  Stream<AppSettingsData?> watchSettings() => _controller.stream;

  @override
  Future<AppSettingsData> getOrCreate() async =>
      _stored ?? AppSettingsData.defaults();

  @override
  Future<void> updateSettings(AppSettingsData settings) async {
    _stored = settings;
  }

  @override
  Future<void> updateBackupState({
    required String? dropboxEmail,
    required DateTime? lastBackupAt,
  }) async {
    final current = _stored ?? AppSettingsData.defaults();
    _stored = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: dropboxEmail,
      lastBackupAt: lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
    );
    _controller.add(_stored);
  }

  @override
  Future<void> markOnboardingComplete() async {
    final current = _stored ?? AppSettingsData.defaults();
    _stored = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: true,
      declaredCycleLength: current.declaredCycleLength,
    );
    _controller.add(_stored);
  }

  @override
  Future<void> saveDeclaredCycleLength(int cycleLength) async {
    final current = _stored ?? AppSettingsData.defaults();
    _stored = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
      declaredCycleLength: cycleLength,
    );
    _controller.add(_stored);
  }

  @override
  Future<void> updateLastDataWriteAt(DateTime timestamp) async {}

  @override
  Future<void> updateBackupSuspended(bool value) async {
    final current = _stored ?? AppSettingsData.defaults();
    _stored = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
      declaredCycleLength: current.declaredCycleLength,
      notificationTimeMinutes: current.notificationTimeMinutes,
      firstDayOfWeek: current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: current.lastLogOrSymptomWriteAt,
      backupSuspended: value,
    );
    _controller.add(_stored);
  }

  @override
  Future<void> clearBackupSuspended() async {
    final current = _stored ?? AppSettingsData.defaults();
    _stored = AppSettingsData(
      languageCode: current.languageCode,
      darkMode: current.darkMode,
      painEnabled: current.painEnabled,
      notesEnabled: current.notesEnabled,
      notificationDaysBefore: current.notificationDaysBefore,
      notificationsEnabled: current.notificationsEnabled,
      dropboxEmail: current.dropboxEmail,
      lastBackupAt: current.lastBackupAt,
      onboardingCompleted: current.onboardingCompleted,
      declaredCycleLength: current.declaredCycleLength,
      notificationTimeMinutes: current.notificationTimeMinutes,
      firstDayOfWeek: current.firstDayOfWeek,
      lastLogOrSymptomWriteAt: current.lastLogOrSymptomWriteAt,
      backupSuspended: false,
    );
    _controller.add(_stored);
  }

  @override
  List<String> get callLog => const [];

  @override
  Future<void> setActiveProvider(SyncProvider provider) async {}
}

ProviderContainer _makeStreamingContainer(
  _StreamingFakeAppSettingsRepository fakeRepo,
) {
  return ProviderContainer(
    overrides: [
      appSettingsRepositoryProvider.overrideWith((_) async => fakeRepo),
      appSettingsStreamProvider.overrideWith(
        (ref) => fakeRepo.watchSettings(),
      ),
    ],
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // Original tests (unchanged)
  // ---------------------------------------------------------------------------

  ProviderContainer makeContainer(FakeAppSettingsRepository fakeRepo) {
    return ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWith((_) async => fakeRepo),
      ],
    );
  }

  test('build() returns stored settings', () async {
    final fakeRepo = FakeAppSettingsRepository()
      ..storedSettings = AppSettingsData(
        languageCode: 'en',
        painEnabled: false,
        notesEnabled: true,
        notificationDaysBefore: 3,
        notificationsEnabled: true,
        onboardingCompleted: false,
      );
    final container = makeContainer(fakeRepo);
    addTearDown(container.dispose);

    final settings = await container.read(settingsNotifierProvider.future);

    expect(settings.languageCode, equals('en'));
    expect(settings.painEnabled, isFalse);
    expect(settings.notificationDaysBefore, equals(3));
  });

  test('build() returns defaults when no stored settings', () async {
    final fakeRepo = FakeAppSettingsRepository();
    final container = makeContainer(fakeRepo);
    addTearDown(container.dispose);

    final settings = await container.read(settingsNotifierProvider.future);

    expect(settings.languageCode, equals(''));
    expect(settings.painEnabled, isTrue);
    expect(settings.notificationsEnabled, isFalse);
  });

  test('save() persists to repo and updates state', () async {
    final fakeRepo = FakeAppSettingsRepository();
    final container = makeContainer(fakeRepo);
    addTearDown(container.dispose);

    await container.read(settingsNotifierProvider.future);

    final updated = AppSettingsData(
      languageCode: 'en',
      painEnabled: false,
      notesEnabled: false,
      notificationDaysBefore: 5,
      notificationsEnabled: true,
      onboardingCompleted: false,
    );
    await container.read(settingsNotifierProvider.notifier).save(updated);

    expect(fakeRepo.storedSettings, equals(updated));
    final state = container.read(settingsNotifierProvider).valueOrNull;
    expect(state, equals(updated));
  });

  // ---------------------------------------------------------------------------
  // BUG-003 reactivity tests (FR-06, EC-11): verify that SettingsNotifier
  // rebuilds when appSettingsStreamProvider emits a new value.
  // ---------------------------------------------------------------------------

  group('SettingsNotifier reactivity (BUG-003 fix)', () {
    test(
      'notifier reflects declaredCycleLength after stream emits new value (FR-06)',
      () async {
        final fakeRepo = _StreamingFakeAppSettingsRepository();
        final container = _makeStreamingContainer(fakeRepo);
        addTearDown(container.dispose);
        addTearDown(fakeRepo.close);

        // Emit initial state: no declaredCycleLength yet.
        fakeRepo.emit(AppSettingsData.defaults());
        await Future<void>.delayed(Duration.zero);

        // Emit updated state simulating saveDeclaredCycleLength(28).
        fakeRepo.emit(
          AppSettingsData(
            languageCode: '',
            painEnabled: true,
            notesEnabled: true,
            notificationDaysBefore: 2,
            notificationsEnabled: false,
            onboardingCompleted: false,
            declaredCycleLength: 28,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final state = await container.read(settingsNotifierProvider.future);
        expect(
          state.declaredCycleLength,
          equals(28),
          reason: 'BUG-003: notifier must reflect declaredCycleLength=28 after '
              'stream emission',
        );
      },
    );

    test(
      'notifier reflects dropboxEmail and lastBackupAt after stream emits (FR-06)',
      () async {
        final fakeRepo = _StreamingFakeAppSettingsRepository();
        final container = _makeStreamingContainer(fakeRepo);
        addTearDown(container.dispose);
        addTearDown(fakeRepo.close);

        // Emit initial state.
        fakeRepo.emit(AppSettingsData.defaults());
        await Future<void>.delayed(Duration.zero);

        // Emit updated state simulating updateBackupState.
        final backupDate = DateTime(2026, 6, 1);
        fakeRepo.emit(
          AppSettingsData(
            languageCode: '',
            painEnabled: true,
            notesEnabled: true,
            notificationDaysBefore: 2,
            notificationsEnabled: false,
            onboardingCompleted: false,
            dropboxEmail: 'a@b.com',
            lastBackupAt: backupDate,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final state = await container.read(settingsNotifierProvider.future);
        expect(
          state.dropboxEmail,
          equals('a@b.com'),
          reason: 'notifier must reflect dropboxEmail after stream emission',
        );
        expect(
          state.lastBackupAt,
          equals(backupDate),
          reason: 'notifier must reflect lastBackupAt after stream emission',
        );
      },
    );

    test(
      'notifier resolves to defaults when stream emits null (EC-11)',
      () async {
        final fakeRepo = _StreamingFakeAppSettingsRepository();
        final container = _makeStreamingContainer(fakeRepo);
        addTearDown(container.dispose);
        addTearDown(fakeRepo.close);

        // Emit null (fresh install, no row yet).
        fakeRepo.emit(null);
        await Future<void>.delayed(Duration.zero);

        final state = await container.read(settingsNotifierProvider.future);
        // When stream emits null, should get defaults
        // (same as previous getOrCreate() behavior).
        expect(
          state.languageCode,
          equals(''),
          reason:
              'notifier must return defaults when stream emits null (EC-11)',
        );
      },
    );
  });
}
