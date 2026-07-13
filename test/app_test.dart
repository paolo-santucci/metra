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
// Also covers TASK-04 (code-review-10-findings SP, FR-10): the two silent
// handlers in _initNotificationsAndVerifyPermission — the :117 catchError and
// the :143 inner catch — each emit a debugPrint tagged '[initNotifications]'
// with no behavioural change.
//
// Strategy: simulator helpers that mirror production logic (same pattern as
// app_notification_wiring_test.dart). Source-substring safety nets guard
// against simulator/production drift.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/l10n/app_localizations.dart';

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
// Simulator: _initNotificationsAndVerifyPermission (TASK-07, FR-10, #34).
//
// Mirrors the real method added to _MetraInnerState in lib/app.dart: resolve
// the locale-derived Android channel display name BEFORE calling
// notificationService.initialize(channelName), falling back to the
// brand-neutral 'Mētra' literal on any settings/l10n failure (EC-20), then
// always run the permission recheck afterward regardless of which branch
// supplied the channel name.
//
// TASK-04 (code-review-10-findings SP, FR-10): the inner catch (:143) now
// also emits a debugPrint tagged '[initNotifications]' — captured via the
// optional debugPrintCapture list (same convention as _autoSyncIfConfigured's
// debugPrintCapture above), with no change to the EC-20 fallback behaviour.
// ---------------------------------------------------------------------------
Future<void> _simulateInitNotificationsAndVerifyPermission({
  required FakeNotificationService notificationService,
  required Future<String> Function() loadLanguageCode,
  required Future<String> Function(String languageCode) loadChannelName,
  required Future<void> Function() verifyPermission,
  List<String>? debugPrintCapture,
}) async {
  var channelName = 'Mētra';
  try {
    final languageCode = await loadLanguageCode();
    channelName = await loadChannelName(languageCode);
  } catch (e) {
    // Settings/l10n unavailable at cold-start — brand-neutral fallback (EC-20).
    debugPrintCapture?.add('[initNotifications] fallback: $e');
  }
  await notificationService.initialize(channelName);
  await verifyPermission();
}

// ---------------------------------------------------------------------------
// Simulator: initState()'s .catchError wrapper around
// _initNotificationsAndVerifyPermission() (TASK-04, FR-10).
//
// Mirrors:
//   _initNotificationsAndVerifyPermission().catchError((Object e) {
//     debugPrint('[initNotifications] catchError: $e');
//   });
//
// The handler parameter stays Object-typed, never rethrows, and returns
// void — asserted here by the fact that awaiting this simulator always
// completes even when initNotifications() throws (HC-8).
// ---------------------------------------------------------------------------
Future<void> _simulateInitNotificationsCatchError({
  required Future<void> Function() initNotifications,
  required List<String> debugPrintCapture,
}) async {
  await initNotifications().catchError((Object e) {
    debugPrintCapture.add('[initNotifications] catchError: $e');
  });
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
    final baseSettings = AppSettingsData(
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
          next: AsyncData(baseSettings),
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
        final updatedSettings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 3,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

        await _simulateSettingsListenerSchedulerGuard(
          prev: AsyncData(baseSettings),
          next: AsyncData(updatedSettings),
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
          next: AsyncData(baseSettings),
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
    final enabledSettings = AppSettingsData(
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
        final disabledSettings = AppSettingsData(
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

  // ===========================================================================
  // Group J — TASK-07 (#34): locale-derived Android notification channel name
  // (FR-10, EC-20, EC-21, OQ-08)
  // ===========================================================================

  group('Group J: locale-derived notification channel name (TASK-07, #34)', () {
    Future<String> loadChannelNameFor(String languageCode) async {
      final l10n = await AppLocalizations.delegate.load(Locale(languageCode));
      return l10n.notification_channel_name;
    }

    test(
      'IT locale → initialize() is called with the Italian notification_channel_name',
      () async {
        final service = FakeNotificationService();

        await _simulateInitNotificationsAndVerifyPermission(
          notificationService: service,
          loadLanguageCode: () async => 'it',
          loadChannelName: loadChannelNameFor,
          verifyPermission: service.hasNotificationPermission,
        );

        final expected = await loadChannelNameFor('it');
        expect(service.channelName, equals(expected));
        expect(service.initializeCallCount, equals(1));
      },
    );

    test(
      'EN locale → initialize() is called with the English notification_channel_name',
      () async {
        final service = FakeNotificationService();

        await _simulateInitNotificationsAndVerifyPermission(
          notificationService: service,
          loadLanguageCode: () async => 'en',
          loadChannelName: loadChannelNameFor,
          verifyPermission: service.hasNotificationPermission,
        );

        final expected = await loadChannelNameFor('en');
        expect(service.channelName, equals(expected));
        expect(service.initializeCallCount, equals(1));
      },
    );

    test(
      'EC-20: settings/l10n load failure → falls back to the brand-neutral '
      '"Mētra" literal AND the permission recheck still runs afterward',
      () async {
        final service = FakeNotificationService();

        await _simulateInitNotificationsAndVerifyPermission(
          notificationService: service,
          loadLanguageCode: () async => throw Exception('settings unavailable'),
          loadChannelName: loadChannelNameFor,
          verifyPermission: service.hasNotificationPermission,
        );

        expect(
          service.channelName,
          equals('Mētra'),
          reason: 'EC-20: brand-neutral fallback must be used when '
              'settings/l10n resolution fails',
        );
        expect(
          service.hasNotificationPermissionCallCount,
          equals(1),
          reason: 'the permission recheck must still run unconditionally after '
              'initialize(), even when locale resolution failed (EC-20) — '
              'the sequence must not be short-circuited',
        );
      },
    );

    test(
      'EC-21: .initialize( appears exactly once in lib/app.dart — a later '
      'settings/language change must not re-invoke it',
      () {
        final source = _appDartSource();
        final count = '.initialize('.allMatches(source).length;
        expect(
          count,
          equals(1),
          reason: 'EC-21: there must be exactly one production call site '
              'that invokes .initialize(...) — a later in-app language '
              'change (SettingsNotifier.save(languageCode:)) must not '
              're-invoke it, since initState() runs exactly once',
        );
      },
    );

    test(
      'Deleted-contract grep guard: no zero-argument initialize call site '
      'remains in any non-comment line under lib/ or test/',
      () {
        // Built via concatenation (not a single literal) so this guard's own
        // source line is not itself a false positive when this same test
        // scans test/app_test.dart.
        const noArgCallPattern = '.initialize' '()';
        final offenders = <String>[];
        for (final dirName in ['lib', 'test']) {
          final dir = Directory(dirName);
          if (!dir.existsSync()) continue;
          for (final entity in dir.listSync(recursive: true)) {
            if (entity is! File || !entity.path.endsWith('.dart')) continue;
            final lines = entity.readAsLinesSync();
            for (final line in lines) {
              if (line.trimLeft().startsWith('//')) {
                continue; // skip comments/doc-comments (e.g. prose mentions)
              }
              if (line.contains(noArgCallPattern)) {
                offenders.add(entity.path);
                break;
              }
            }
          }
        }
        expect(
          offenders,
          isEmpty,
          reason: 'TASK-07 (#34): the zero-argument initialize call must be '
              'fully migrated to initialize(channelName) everywhere; '
              'offending files: $offenders',
        );
      },
    );

    test(
      'Source-substring safety net: settingsNotifierProvider.future precedes '
      'notification_channel_name, which precedes the .initialize( call site, '
      'and _verifyNotificationPermissionOnColdStart() still runs '
      'unconditionally afterward',
      () {
        final source = _appDartSource();
        final settingsIdx = source.indexOf('settingsNotifierProvider.future');
        final channelNameIdx = source.indexOf('notification_channel_name');
        final initIdx = source.indexOf('.initialize(');
        final verifyCallIdx =
            source.indexOf('_verifyNotificationPermissionOnColdStart();');

        expect(
          settingsIdx,
          greaterThanOrEqualTo(0),
          reason: 'settingsNotifierProvider.future must be read before '
              'resolving the channel name',
        );
        expect(
          channelNameIdx,
          greaterThan(settingsIdx),
          reason: 'notification_channel_name must be resolved after '
              'settingsNotifierProvider.future',
        );
        expect(
          initIdx,
          greaterThan(channelNameIdx),
          reason: 'the .initialize( call must come after the '
              'notification_channel_name resolution',
        );
        expect(
          verifyCallIdx,
          greaterThan(initIdx),
          reason: 'FR-10: _verifyNotificationPermissionOnColdStart() must '
              'still be invoked unconditionally after initialize(), '
              'preserving the FR-07/BUG-B03 cold-start recheck ordering',
        );
      },
    );
  });

  // ===========================================================================
  // Group D — TASK-04 (code-review-10-findings SP, FR-10): initNotifications
  // silent-handler diagnostics.
  // ===========================================================================

  group(
    'Group D: initNotifications silent-handler diagnostics (TASK-04, FR-10)',
    () {
      test(
        "catchError (:117): chained future throws → debugPrint contains "
        "'[initNotifications]'; handler does not rethrow",
        () async {
          final captured = <String>[];

          await expectLater(
            _simulateInitNotificationsCatchError(
              initNotifications: () async =>
                  throw Exception('notification init failed'),
              debugPrintCapture: captured,
            ),
            completes,
            reason: 'catchError must not rethrow — the chained future '
                'error must be swallowed (HC-8)',
          );

          expect(
            captured,
            hasLength(1),
            reason: 'exactly one debugPrint line must be emitted by catchError',
          );
          expect(
            captured.first,
            contains('[initNotifications]'),
            reason: "the catchError handler must tag its log with "
                "'[initNotifications]'",
          );
        },
      );

      test(
        "inner catch (:143): settings/l10n load throws → debugPrint "
        "contains '[initNotifications]' AND the 'Mētra' fallback channel "
        'name path still runs (EC-20)',
        () async {
          final service = FakeNotificationService();
          final captured = <String>[];

          await _simulateInitNotificationsAndVerifyPermission(
            notificationService: service,
            loadLanguageCode: () async =>
                throw Exception('settings unavailable'),
            loadChannelName: (languageCode) async {
              final l10n =
                  await AppLocalizations.delegate.load(Locale(languageCode));
              return l10n.notification_channel_name;
            },
            verifyPermission: service.hasNotificationPermission,
            debugPrintCapture: captured,
          );

          expect(
            service.channelName,
            equals('Mētra'),
            reason: 'EC-20: brand-neutral fallback must still run when the '
                'inner catch also logs',
          );
          expect(
            captured,
            hasLength(1),
            reason: 'exactly one debugPrint line must be emitted by the '
                'inner catch',
          );
          expect(
            captured.first,
            contains('[initNotifications]'),
            reason: "the inner catch handler must tag its log with "
                "'[initNotifications]'",
          );
        },
      );

      test(
        'happy path: neither handler fires, so no debugPrint is emitted',
        () async {
          final service = FakeNotificationService();
          final captured = <String>[];

          await _simulateInitNotificationsCatchError(
            initNotifications: () =>
                _simulateInitNotificationsAndVerifyPermission(
              notificationService: service,
              loadLanguageCode: () async => 'it',
              loadChannelName: (languageCode) async {
                final l10n =
                    await AppLocalizations.delegate.load(Locale(languageCode));
                return l10n.notification_channel_name;
              },
              verifyPermission: service.hasNotificationPermission,
              debugPrintCapture: captured,
            ),
            debugPrintCapture: captured,
          );

          expect(
            captured,
            isEmpty,
            reason: 'no diagnostic should be logged on the happy path',
          );
        },
      );

      test(
        'Grep guard: the new :117/:143 log literals avoid the four '
        'forbidden substrings, and ".initialize(" count in lib/app.dart '
        'stays exactly 1',
        () {
          final source = _appDartSource();

          // Locate every '[initNotifications]' log call site and inspect a
          // bounded single-line window around each so the forbidden-substring
          // check targets the actual debugPrint argument, not the whole file.
          const tag = '[initNotifications]';
          final occurrences = <int>[];
          var searchFrom = 0;
          while (true) {
            final idx = source.indexOf(tag, searchFrom);
            if (idx == -1) break;
            occurrences.add(idx);
            searchFrom = idx + tag.length;
          }

          expect(
            occurrences.length,
            equals(2),
            reason: 'expected exactly two [initNotifications] log call '
                'sites (:117 catchError, :143 inner catch)',
          );

          const forbidden = [
            'settingsNotifierProvider.future',
            'notification_channel_name',
            '.initialize(',
            '_verifyNotificationPermissionOnColdStart();',
          ];

          for (final idx in occurrences) {
            final windowEnd = (idx + 200).clamp(0, source.length);
            final window = source.substring(idx, windowEnd);
            final newlineIdx = window.indexOf('\n');
            final singleLine =
                newlineIdx == -1 ? window : window.substring(0, newlineIdx);
            for (final needle in forbidden) {
              expect(
                singleLine,
                isNot(contains(needle)),
                reason: 'log literal at offset $idx must not contain the '
                    "forbidden substring '$needle' (would corrupt the "
                    'app_test.dart ordering greps, :934-973)',
              );
            }
          }

          final initializeCount = '.initialize('.allMatches(source).length;
          expect(
            initializeCount,
            equals(1),
            reason: 'TASK-04 must not introduce a second ".initialize(" '
                'call site — the EC-21 guard above depends on exactly one '
                'occurrence',
          );

          expect(
            source,
            contains('.catchError((Object'),
            reason: 'HC-8: the catchError handler parameter must stay '
                'Object-typed',
          );
        },
      );
    },
  );
}
