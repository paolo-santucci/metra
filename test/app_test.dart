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

// TASK-08 tests for lib/app.dart cold-start consolidation.
//
// Four changes under test:
//   FR-05 / BUG-B02: cyclePredictionProvider ref.listen uses prev-is-AsyncData guard.
//   FR-06 / BUG-B02: settingsNotifierProvider ref.listen uses prev-is-AsyncData guard.
//   FR-07 / BUG-B03: cold-start POST_NOTIFICATIONS re-check after initialize().
//   FR-15 / BUG-D04: _autoSyncIfConfigured routes through backupNotifierProvider.notifier.backupSilent().
//   FR-18 / BUG-D06: _autoSyncIfConfigured catch emits debugPrint('[autoSync] ...').
//
// Strategy: simulator helpers that mirror production logic (same pattern as
// app_notification_wiring_test.dart). Source-substring safety nets guard
// against simulator/production drift.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';

import 'helpers/fake_notification_service.dart';

// ---------------------------------------------------------------------------
// Source-substring safety nets (advisor recommendation).
// These catch simulator/production divergence: if the guard exists in the
// simulator but not in lib/app.dart, these assertions fail.
// ---------------------------------------------------------------------------

const _appDartPath = 'lib/app.dart';

String _appDartSource() => File(_appDartPath).readAsStringSync();

// ---------------------------------------------------------------------------
// Scheduler call counter — simulates SchedulePredictionNotification.execute.
// ---------------------------------------------------------------------------
class _FakeScheduler {
  int callCount = 0;

  Future<void> execute() async {
    callCount++;
  }
}

// ---------------------------------------------------------------------------
// Simulator: cyclePredictionProvider listener (FR-05 / BUG-B02).
//
// Mirrors the real listener in _MetraInnerState.build() after TASK-08:
//   ref.listen<AsyncValue<CyclePrediction?>>(
//     cyclePredictionProvider,
//     (prev, next) async {
//       if (prev is AsyncData<CyclePrediction?> && next is AsyncData<CyclePrediction?>) {
//         await scheduler.execute(...);
//       }
//     },
//   );
// ---------------------------------------------------------------------------
Future<void> _simulateCyclePredictionListener({
  required AsyncValue<CyclePrediction?>? prev,
  required AsyncValue<CyclePrediction?> next,
  required _FakeScheduler scheduler,
}) async {
  if (prev is AsyncData<CyclePrediction?> &&
      next is AsyncData<CyclePrediction?>) {
    await scheduler.execute();
  }
}

// ---------------------------------------------------------------------------
// Simulator: settingsNotifierProvider listener (FR-06 / BUG-B02).
//
// Mirrors the real listener in _MetraInnerState.build() after TASK-08.
// Note: the existing requestPermission() guard (BUG-002 fix) is separate
// and tested in app_notification_wiring_test.dart. This simulator covers
// only the scheduler.execute() guard added by FR-06.
//
//   ref.listen<AsyncValue<AppSettingsData>>(
//     settingsNotifierProvider,
//     (prev, next) async {
//       ...
//       if (prev is AsyncData<AppSettingsData> && next is AsyncData<AppSettingsData>) {
//         await scheduler.execute(...);
//       }
//     },
//   );
// ---------------------------------------------------------------------------
Future<void> _simulateSettingsListenerSchedulerGuard({
  required AsyncValue<AppSettingsData>? prev,
  required AsyncValue<AppSettingsData> next,
  required _FakeScheduler scheduler,
}) async {
  final currentSettings = next.valueOrNull;
  if (currentSettings == null) return;
  if (prev is AsyncData<AppSettingsData> &&
      next is AsyncData<AppSettingsData>) {
    await scheduler.execute();
  }
}

// ---------------------------------------------------------------------------
// Simulator: cold-start POST_NOTIFICATIONS re-check (FR-07 / BUG-B03).
//
// Mirrors the logic chained after notificationService.initialize():
//
//   final settings = await ref.read(settingsNotifierProvider.future);
//   if (settings.notificationsEnabled) {
//     final granted = await notificationService.requestPermission();
//     if (!granted) {
//       await ref.read(settingsNotifierProvider.notifier)
//           .save(settings.copyWith(notificationsEnabled: false));
//     }
//   }
// ---------------------------------------------------------------------------
class _FakeSettingsNotifier {
  AppSettingsData _current;
  int saveCallCount = 0;
  AppSettingsData? lastSaved;

  _FakeSettingsNotifier(this._current);

  AppSettingsData get current => _current;

  Future<void> save(AppSettingsData updated) async {
    saveCallCount++;
    lastSaved = updated;
    _current = updated;
  }
}

Future<void> _simulateColdStartPermissionRecheck({
  required AppSettingsData persistedSettings,
  required FakeNotificationService notificationService,
  required _FakeSettingsNotifier settingsNotifier,
}) async {
  if (!persistedSettings.notificationsEnabled) return;
  // Fix #2 / FR-07: uses hasNotificationPermission() (read-only check),
  // not requestPermission() — never re-prompts the user at cold-start.
  final granted = await notificationService.hasNotificationPermission();
  if (!granted) {
    await settingsNotifier.save(
      persistedSettings.copyWith(notificationsEnabled: false),
    );
  }
}

// ---------------------------------------------------------------------------
// Simulator: _autoSyncIfConfigured (FR-15 / FR-18).
//
// Mirrors the rewritten _autoSyncIfConfigured in lib/app.dart after TASK-08.
// Key changes:
//   - Reads passphrase from secureStorage; returns early if null (unchanged).
//   - Calls backupNotifier.backupSilent() instead of backupDataProvider.future.
//   - catch (e) emits debugPrint('[autoSync] ...').
// ---------------------------------------------------------------------------
class _FakeBackupNotifier {
  int backupSilentCallCount = 0;
  Exception? throwOnSilent;

  Future<void> backupSilent() async {
    backupSilentCallCount++;
    if (throwOnSilent != null) throw throwOnSilent!;
  }
}

class _FakeSecureStorage {
  final Map<String, String?> _store;

  _FakeSecureStorage(this._store);

  Future<String?> read({required String key}) async => _store[key];
}

Future<void> _simulateAutoSyncIfConfigured({
  required _FakeSecureStorage secureStorage,
  required _FakeBackupNotifier backupNotifier,
  required List<String> debugPrintCapture,
}) async {
  // Mirrors: lib/app.dart _autoSyncIfConfigured after TASK-08 changes.
  try {
    final pass = await secureStorage.read(key: 'metra_backup_passphrase_v1');
    if (pass == null) return;
    await backupNotifier.backupSilent();
  } catch (e) {
    debugPrintCapture.add('[autoSync] ${e.runtimeType}: $e');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Source-substring safety nets — guard simulator/production drift.
  group('Source-substring safety nets (production code contracts)', () {
    test(
      'lib/app.dart cyclePredictionProvider listener contains prev-is-AsyncData guard (FR-05)',
      () {
        final source = _appDartSource();
        // The guard may use the positive form (prev is AsyncData<CyclePrediction?>)
        // or the negated early-return form (prev is! AsyncData<CyclePrediction?>).
        // Either form satisfies FR-05. Match the base type expression.
        expect(
          source,
          contains('AsyncData<CyclePrediction?>'),
          reason:
              'FR-05: lib/app.dart cyclePredictionProvider listener must guard '
              'scheduler.execute() with an AsyncData<CyclePrediction?> type check',
        );
      },
    );

    test(
      'lib/app.dart settingsNotifierProvider listener contains prev-is-AsyncData guard for scheduler (FR-06)',
      () {
        final source = _appDartSource();
        expect(
          source,
          contains('prev is AsyncData<AppSettingsData>'),
          reason:
              'FR-06: lib/app.dart settingsNotifierProvider listener must guard '
              'scheduler.execute() with prev is AsyncData<AppSettingsData> '
              '(in addition to the existing requestPermission guard)',
        );
      },
    );

    test(
      'lib/app.dart _autoSyncIfConfigured calls backupNotifierProvider, not backupDataProvider (FR-15)',
      () {
        final source = _appDartSource();
        expect(
          source,
          contains('backupNotifierProvider'),
          reason: 'FR-15: lib/app.dart _autoSyncIfConfigured must call '
              'backupNotifierProvider.notifier.backupSilent()',
        );
        // The direct backupDataProvider.future call must be gone from
        // _autoSyncIfConfigured. It may still appear in backup_providers.dart
        // declarations; this grep only fails if it reappears in app.dart.
        expect(
          source,
          isNot(contains('backupDataProvider.future')),
          reason:
              'FR-15: lib/app.dart must not await backupDataProvider.future '
              'directly — route through backupNotifierProvider instead',
        );
      },
    );

    test(
      'lib/app.dart _autoSyncIfConfigured catch uses debugPrint with [autoSync] tag (FR-18)',
      () {
        final source = _appDartSource();
        expect(
          source,
          contains('[autoSync]'),
          reason: 'FR-18: lib/app.dart _autoSyncIfConfigured catch must emit '
              "debugPrint('[autoSync] ...')",
        );
      },
    );

    test(
      'lib/app.dart _verifyNotificationPermissionOnColdStart uses '
      'hasNotificationPermission(), not requestPermission() (Fix #2, FR-07, no-nag)',
      () {
        final source = _appDartSource();
        // The method definition starts at "Future<void> _verifyNotification..."
        // Find the definition (not the call site, which has no "Future<void>").
        const defMarker =
            'Future<void> _verifyNotificationPermissionOnColdStart()';
        final defIdx = source.indexOf(defMarker);
        expect(
          defIdx,
          greaterThanOrEqualTo(0),
          reason:
              '_verifyNotificationPermissionOnColdStart must be declared in lib/app.dart',
        );
        // The method ends just before _autoSyncIfConfigured's declaration.
        const nextDefMarker = 'Future<void> _autoSyncIfConfigured()';
        final nextDefIdx = source.indexOf(nextDefMarker, defIdx);
        expect(
          nextDefIdx,
          greaterThan(defIdx),
          reason:
              '_autoSyncIfConfigured must follow _verifyNotification... in source',
        );
        final methodBody = source.substring(defIdx, nextDefIdx);

        expect(
          methodBody,
          contains('hasNotificationPermission()'),
          reason:
              'Fix #2 / FR-07: _verifyNotificationPermissionOnColdStart body '
              'must call hasNotificationPermission() (read-only check) — '
              'requestPermission() would re-show the system dialog',
        );
        expect(
          methodBody,
          isNot(contains('requestPermission()')),
          reason: '_verifyNotificationPermissionOnColdStart must NOT call '
              'requestPermission() — that would re-prompt the user at '
              'cold-start, violating the Métra "no nag" voice',
        );
      },
    );
  });

  // ===========================================================================
  // FR-05 / BUG-B02: cyclePredictionProvider listener scheduler guard
  // ===========================================================================

  group('FR-05 / BUG-B02: cyclePredictionProvider listener scheduler guard',
      () {
    test(
      'Cold-start AsyncLoading→AsyncData does NOT invoke scheduler.execute (FR-05, BUG-B02, EC-04)',
      () async {
        final scheduler = _FakeScheduler();
        final prediction = CyclePrediction(
          windowStart: DateTime(2099, 3, 1),
          windowEnd: DateTime(2099, 3, 5),
          expectedStart: DateTime(2099, 3, 3),
          cyclesUsed: 3,
        );

        // Cold-start: prev=AsyncLoading, next=AsyncData (first emission)
        await _simulateCyclePredictionListener(
          prev: const AsyncLoading<CyclePrediction?>(),
          next: AsyncData(prediction),
          scheduler: scheduler,
        );

        expect(
          scheduler.callCount,
          equals(0),
          reason: 'FR-05: scheduler.execute() must NOT be called on cold-start '
              'AsyncLoading → AsyncData transition (would exhaust alarm quota, BUG-B02)',
        );
      },
    );

    test(
      'AsyncData→AsyncData transition DOES invoke scheduler.execute once (FR-05 normal path)',
      () async {
        final scheduler = _FakeScheduler();
        final predictionV1 = CyclePrediction(
          windowStart: DateTime(2099, 3, 1),
          windowEnd: DateTime(2099, 3, 5),
          expectedStart: DateTime(2099, 3, 3),
          cyclesUsed: 3,
        );
        final predictionV2 = CyclePrediction(
          windowStart: DateTime(2099, 4, 1),
          windowEnd: DateTime(2099, 4, 5),
          expectedStart: DateTime(2099, 4, 3),
          cyclesUsed: 4,
        );

        // Legitimate data-update transition: prev=AsyncData, next=AsyncData
        await _simulateCyclePredictionListener(
          prev: AsyncData(predictionV1),
          next: AsyncData(predictionV2),
          scheduler: scheduler,
        );

        expect(
          scheduler.callCount,
          equals(1),
          reason:
              'FR-05: scheduler.execute() must be called exactly once for a '
              'legitimate AsyncData → AsyncData data-update transition',
        );
      },
    );

    test(
      'null prev (first listen call) does NOT invoke scheduler.execute',
      () async {
        final scheduler = _FakeScheduler();
        final prediction = CyclePrediction(
          windowStart: DateTime(2099, 3, 1),
          windowEnd: DateTime(2099, 3, 5),
          expectedStart: DateTime(2099, 3, 3),
          cyclesUsed: 3,
        );

        // Riverpod calls listener with null prev on the very first call.
        await _simulateCyclePredictionListener(
          prev: null,
          next: AsyncData(prediction),
          scheduler: scheduler,
        );

        expect(
          scheduler.callCount,
          equals(0),
          reason: 'null prev must not trigger scheduler.execute()',
        );
      },
    );
  });

  // ===========================================================================
  // FR-06 / BUG-B02: settingsNotifierProvider listener scheduler guard
  // ===========================================================================

  group('FR-06 / BUG-B02: settingsNotifierProvider listener scheduler guard',
      () {
    const baseSettings = AppSettingsData(
      languageCode: 'it',
      painEnabled: true,
      notesEnabled: true,
      notificationDaysBefore: 2,
      notificationsEnabled: true,
      onboardingCompleted: true,
    );

    test(
      'Cold-start AsyncLoading→AsyncData does NOT invoke scheduler.execute (FR-06, BUG-B02)',
      () async {
        final scheduler = _FakeScheduler();

        await _simulateSettingsListenerSchedulerGuard(
          prev: const AsyncLoading<AppSettingsData>(),
          next: const AsyncData(baseSettings),
          scheduler: scheduler,
        );

        expect(
          scheduler.callCount,
          equals(0),
          reason: 'FR-06: scheduler.execute() must NOT be called on cold-start '
              'AsyncLoading → AsyncData transition for settingsNotifierProvider',
        );
      },
    );

    test(
      'AsyncData→AsyncData transition DOES invoke scheduler.execute once (FR-06 normal path)',
      () async {
        final scheduler = _FakeScheduler();
        const updatedSettings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 3,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

        await _simulateSettingsListenerSchedulerGuard(
          prev: const AsyncData(baseSettings),
          next: const AsyncData(updatedSettings),
          scheduler: scheduler,
        );

        expect(
          scheduler.callCount,
          equals(1),
          reason:
              'FR-06: scheduler.execute() must be called exactly once for a '
              'legitimate AsyncData → AsyncData settings-update transition',
        );
      },
    );

    test(
      'null prev (first listen call) does NOT invoke scheduler.execute',
      () async {
        final scheduler = _FakeScheduler();

        await _simulateSettingsListenerSchedulerGuard(
          prev: null,
          next: const AsyncData(baseSettings),
          scheduler: scheduler,
        );

        expect(
          scheduler.callCount,
          equals(0),
          reason: 'null prev must not trigger scheduler.execute()',
        );
      },
    );
  });

  // ===========================================================================
  // FR-07 / BUG-B03: cold-start POST_NOTIFICATIONS re-check
  // ===========================================================================

  group('FR-07 / BUG-B03: cold-start POST_NOTIFICATIONS re-check', () {
    const enabledSettings = AppSettingsData(
      languageCode: 'it',
      painEnabled: true,
      notesEnabled: true,
      notificationDaysBefore: 2,
      notificationsEnabled: true,
      onboardingCompleted: true,
    );

    test(
      'OS permission revoked → persisted notificationsEnabled reverts to false (FR-07, BUG-B03, EC-03)',
      () async {
        // Fix #2: use hasNotificationPermissionValue (read-only check).
        // permissionGranted controls requestPermission(); we set it to true
        // to prove it is NOT called — only hasNotificationPermission matters here.
        final service = FakeNotificationService(
          hasNotificationPermissionValue: false,
        )..permissionGranted = true; // requestPermission must NOT be invoked
        final notifier = _FakeSettingsNotifier(enabledSettings);

        await _simulateColdStartPermissionRecheck(
          persistedSettings: enabledSettings,
          notificationService: service,
          settingsNotifier: notifier,
        );

        // Fix #2: cold-start uses hasNotificationPermission(), not requestPermission().
        expect(
          service.hasNotificationPermissionCallCount,
          equals(1),
          reason: 'FR-07 / Fix #2: hasNotificationPermission() must be called '
              'exactly once during cold-start re-check (read-only, no dialog)',
        );
        expect(
          service.requestPermissionCallCount,
          equals(0),
          reason:
              'FR-07 / Fix #2: requestPermission() must NOT be called during '
              'cold-start — that would re-prompt the user (Métra "no nag" voice)',
        );
        expect(
          notifier.saveCallCount,
          equals(1),
          reason:
              'FR-07: settings must be saved once when OS permission is absent',
        );
        expect(
          notifier.lastSaved?.notificationsEnabled,
          isFalse,
          reason:
              'FR-07: persisted notificationsEnabled must be flipped to false '
              'when OS permission is revoked at cold-start (EC-03)',
        );
      },
    );

    test(
      'OS permission still granted → notificationsEnabled unchanged (FR-07, granted path)',
      () async {
        // Fix #2: hasNotificationPermissionValue=true (default) and
        // requestPermission is not called (requestPermissionCallCount must be 0).
        final service = FakeNotificationService(
          hasNotificationPermissionValue: true,
        );
        final notifier = _FakeSettingsNotifier(enabledSettings);

        await _simulateColdStartPermissionRecheck(
          persistedSettings: enabledSettings,
          notificationService: service,
          settingsNotifier: notifier,
        );

        expect(
          service.hasNotificationPermissionCallCount,
          equals(1),
          reason:
              'FR-07 / Fix #2: hasNotificationPermission() called once on granted path',
        );
        expect(
          service.requestPermissionCallCount,
          equals(0),
          reason: 'FR-07 / Fix #2: requestPermission() must NOT be called — '
              'cold-start is read-only',
        );
        expect(
          notifier.saveCallCount,
          equals(0),
          reason:
              'FR-07: settings must NOT be saved when OS permission is still '
              'granted — no unnecessary write',
        );
        expect(
          notifier.current.notificationsEnabled,
          isTrue,
          reason:
              'FR-07: notificationsEnabled must remain true when permission is granted',
        );
      },
    );

    test(
      'notificationsEnabled=false → re-check is skipped entirely (FR-07)',
      () async {
        const disabledSettings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: true,
        );
        final service = FakeNotificationService(
          hasNotificationPermissionValue: false,
        );
        final notifier = _FakeSettingsNotifier(disabledSettings);

        await _simulateColdStartPermissionRecheck(
          persistedSettings: disabledSettings,
          notificationService: service,
          settingsNotifier: notifier,
        );

        // Neither check should run when notifications are already off.
        expect(
          service.hasNotificationPermissionCallCount,
          equals(0),
          reason:
              'FR-07 / Fix #2: hasNotificationPermission() must not be called '
              'when notifications are already disabled',
        );
        expect(
          service.requestPermissionCallCount,
          equals(0),
          reason:
              'FR-07: requestPermission() must not be called when notifications '
              'are already disabled',
        );
        expect(
          notifier.saveCallCount,
          equals(0),
          reason: 'FR-07: no save when notificationsEnabled is already false',
        );
      },
    );
  });

  // ===========================================================================
  // FR-15 / BUG-D04: _autoSyncIfConfigured routes through backupSilent()
  // ===========================================================================

  group('FR-15 / BUG-D04: _autoSyncIfConfigured routes through backupSilent()',
      () {
    test(
      'Cached passphrase present → backupSilent() called once (FR-15, BUG-D04, EC-11)',
      () async {
        final storage =
            _FakeSecureStorage({'metra_backup_passphrase_v1': 'cached-pass'});
        final notifier = _FakeBackupNotifier();
        final captured = <String>[];

        await _simulateAutoSyncIfConfigured(
          secureStorage: storage,
          backupNotifier: notifier,
          debugPrintCapture: captured,
        );

        expect(
          notifier.backupSilentCallCount,
          equals(1),
          reason:
              'FR-15: backupSilent() must be called exactly once when a cached '
              'passphrase is present (routes through BackupNotifier, not backupDataProvider)',
        );
        expect(
          captured,
          isEmpty,
          reason: 'FR-15: no error should be emitted on success path',
        );
      },
    );

    test(
      'No cached passphrase → backupSilent() NOT called (early return)',
      () async {
        final storage =
            _FakeSecureStorage({'metra_backup_passphrase_v1': null});
        final notifier = _FakeBackupNotifier();
        final captured = <String>[];

        await _simulateAutoSyncIfConfigured(
          secureStorage: storage,
          backupNotifier: notifier,
          debugPrintCapture: captured,
        );

        expect(
          notifier.backupSilentCallCount,
          equals(0),
          reason:
              'No passphrase → early return, backupSilent() must not be called',
        );
      },
    );
  });

  // ===========================================================================
  // FR-18 / BUG-D06: _autoSyncIfConfigured catch emits debugPrint '[autoSync]'
  // ===========================================================================

  group('FR-18 / BUG-D06: _autoSyncIfConfigured catch logs [autoSync]', () {
    test(
      'Exception in backupSilent → debugPrint with [autoSync] tag emitted (FR-18, BUG-D06)',
      () async {
        final storage =
            _FakeSecureStorage({'metra_backup_passphrase_v1': 'cached-pass'});
        final notifier = _FakeBackupNotifier()
          ..throwOnSilent = Exception('network error');
        final captured = <String>[];

        await _simulateAutoSyncIfConfigured(
          secureStorage: storage,
          backupNotifier: notifier,
          debugPrintCapture: captured,
        );

        expect(
          captured,
          hasLength(1),
          reason:
              'FR-18: exactly one debugPrint line must be emitted when backupSilent throws',
        );
        expect(
          captured.first,
          contains('[autoSync]'),
          reason: "FR-18: the log line must contain the '[autoSync]' tag",
        );
        expect(
          captured.first,
          contains('network error'),
          reason: 'FR-18: the log line must contain the exception message',
        );
      },
    );

    test(
      'Exception in backupSilent → does NOT propagate out of _autoSyncIfConfigured (FR-18)',
      () async {
        final storage =
            _FakeSecureStorage({'metra_backup_passphrase_v1': 'pass'});
        final notifier = _FakeBackupNotifier()
          ..throwOnSilent = Exception('crash');
        final captured = <String>[];

        // This must not throw.
        await expectLater(
          _simulateAutoSyncIfConfigured(
            secureStorage: storage,
            backupNotifier: notifier,
            debugPrintCapture: captured,
          ),
          completes,
          reason: 'FR-18: exception in backupSilent must be caught; '
              '_autoSyncIfConfigured must not propagate it',
        );
      },
    );
  });
}
