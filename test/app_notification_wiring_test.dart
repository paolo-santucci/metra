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

// Tests for:
//   BUG-002 fix (TASK-03): cold-start permission guard in app.dart listener.
//   FR-09 wiring (TASK-05): cyclePredictionProvider → SchedulePredictionNotification.
//
// Rather than mounting the full MetraApp widget (which requires platform
// channels for routing and DB initialisation), these tests exercise the
// listener and scheduling logic directly via ProviderContainer overrides and
// a FakeNotificationService.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/services/notification_service.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/notification_error_reporter_provider.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import 'helpers/fake_app_settings_repository.dart';
import 'helpers/fake_notification_error_reporter.dart';
import 'helpers/fake_notification_service.dart';

// ---------------------------------------------------------------------------
// Simulates the _MetraInnerState settings listener guard logic.
//
// The real listener is in lib/app.dart. This function mirrors the BUG-002 fix
// guard so tests can exercise it without spinning up the full widget tree.
//
// Guard (from lib/app.dart after BUG-002 fix):
//   if (prev is AsyncData<AppSettingsData>) {
//     final wasEnabled = prev.value.notificationsEnabled;
//     if (currentSettings.notificationsEnabled && !wasEnabled) {
//       await service.requestPermission();
//     }
//   }
// ---------------------------------------------------------------------------
Future<void> _simulateSettingsListenerGuard({
  required AsyncValue<AppSettingsData>? prev,
  required AsyncValue<AppSettingsData> next,
  required FakeNotificationService service,
}) async {
  final currentSettings = next.valueOrNull;
  if (currentSettings == null) return;

  if (prev is AsyncData<AppSettingsData>) {
    final wasEnabled = prev.value.notificationsEnabled;
    if (currentSettings.notificationsEnabled && !wasEnabled) {
      await service.requestPermission();
    }
  }
  // If prev is not AsyncData (e.g. AsyncLoading on cold start), skip the
  // permission check entirely — this is the BUG-002 fix.
}

// ---------------------------------------------------------------------------
// TASK-05 helper: simulates the cyclePredictionProvider ref.listen callback
// in _MetraInnerState.build().
//
// The real listener:
//   1. Reads prediction from next.valueOrNull.
//   2. Reads currentSettings from settingsNotifierProvider.valueOrNull.
//   3. Loads l10n.
//   4. Awaits schedulePredictionNotificationProvider.future.
//   5. Calls scheduler.execute(...).
//
// This helper exercises steps 3–5 directly with a FakeNotificationService
// override on notificationServiceProvider (which schedulePredictionNotification-
// Provider uses internally).
// ---------------------------------------------------------------------------
Future<void> _simulatePredictionListenerSchedule({
  required CyclePrediction? prediction,
  required AppSettingsData settings,
  required FakeNotificationService service,
}) async {
  final container = ProviderContainer(
    overrides: [notificationServiceProvider.overrideWithValue(service)],
  );
  final scheduler =
      await container.read(schedulePredictionNotificationProvider.future);
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await scheduler.execute(
    prediction: prediction,
    settings: settings,
    title: l10n.notification_prediction_title,
    body: prediction != null
        ? l10n.notification_prediction_body(settings.notificationDaysBefore)
        : '',
  );
  container.dispose();
}

// ---------------------------------------------------------------------------
// TASK-08 helper: simulates the _MetraInnerState settings listener body
// (the portion after the permission-guard) from lib/app.dart.
//
// Mirrors app.dart lines 213–309 structurally:
//   1. Dedup guard: skip if prev == current (EC-07).
//   2. Permission branch: requestPermission() when false→true; revert + return
//      when denied (FR-13, EC-06). No snackbar on denial.
//   3. Cold-start guard: skip scheduling if prev is not AsyncData (BUG-002).
//   4. l10n load before await (FR-08 localisation timing).
//   5. switch (result) from scheduler.execute():
//        Success → no side effect.
//        Failure → revert notificationsEnabled + report snackbar (FR-08).
//   6. Outer on PlatformException: catch cancel-throw silently (FR-16).
//
// Uses the caller-supplied [container] so tests can assert on
// [fakeRepo.storedSettings] through the same ProviderContainer.
// ---------------------------------------------------------------------------
Future<void> _simulateSettingsListenerFire({
  required ProviderContainer container,
  required AsyncValue<AppSettingsData>? prev,
  required AsyncValue<AppSettingsData> next,
  required FakeNotificationService service,
  CyclePrediction? prediction,
}) async {
  final currentSettings = next.valueOrNull;
  if (currentSettings == null) return;

  // Dedup guard (EC-07): SettingsNotifier.save() fires the listener twice —
  // once from the in-memory state update, once from the Drift stream rebuild.
  // AppSettingsData.== is structural so the second call is collapsed here.
  if (prev is AsyncData<AppSettingsData> &&
      prev.requireValue == currentSettings) {
    return;
  }

  // BUG-002 fix: only request OS permission on genuine user-driven
  // AsyncData → AsyncData transitions (not cold-start AsyncLoading → AsyncData).
  if (prev is AsyncData<AppSettingsData>) {
    final wasEnabled = prev.value.notificationsEnabled;
    if (currentSettings.notificationsEnabled && !wasEnabled) {
      final granted = await service.requestPermission();
      if (!granted) {
        // FR-13 / EC-06: iOS denial — revert toggle, NO snackbar.
        await container.read(settingsNotifierProvider.notifier).save(
              currentSettings.copyWith(notificationsEnabled: false),
            );
        return;
      }
    }
  }

  // FR-06 / BUG-B02: skip scheduling on cold-start transition.
  if (prev is! AsyncData<AppSettingsData>) return;

  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  // FR-08: capture localised failure message before await so locale is
  // pinned to the user's current settings at scheduling time.
  final failureMessage = l10n.notificationScheduleFailedMessage;
  final scheduler =
      await container.read(schedulePredictionNotificationProvider.future);
  try {
    final result = await scheduler.execute(
      prediction: prediction,
      settings: currentSettings,
      title: l10n.notification_prediction_title,
      body: prediction != null
          ? l10n.notification_prediction_body(
              currentSettings.notificationDaysBefore,
            )
          : '',
      skipIfPast: true,
    );
    switch (result) {
      case NotificationScheduleSuccess():
        // No side effect.
        break;
      case NotificationScheduleFailure():
        // FR-08(a): revert the toggle.
        await container.read(settingsNotifierProvider.notifier).save(
              currentSettings.copyWith(notificationsEnabled: false),
            );
        // FR-08(b): surface a localised error snackbar.
        container
            .read(notificationErrorReporterProvider)
            .report(failureMessage);
    }
  } on PlatformException {
    // FR-16: cancelPredictionNotifications() inside execute() may throw
    // PlatformException. Caught silently — no revert, no snackbar.
  }
}

// ---------------------------------------------------------------------------
// TASK-08 helper: builds a ProviderContainer for the settings-listener tests.
//
// Wires:
//   - notificationServiceProvider → caller-supplied FakeNotificationService
//   - appSettingsRepositoryProvider → caller-supplied FakeAppSettingsRepository
//   - notificationErrorReporterProvider → caller-supplied reporter
// ---------------------------------------------------------------------------
ProviderContainer _makeSettingsListenerContainer({
  required FakeNotificationService service,
  required FakeAppSettingsRepository fakeRepo,
  required NotificationErrorReporter reporter,
}) {
  return ProviderContainer(
    overrides: [
      notificationServiceProvider.overrideWithValue(service),
      appSettingsRepositoryProvider.overrideWith((_) async => fakeRepo),
      notificationErrorReporterProvider.overrideWithValue(reporter),
    ],
  );
}

// ---------------------------------------------------------------------------
// EC-12 test double: models a NotificationErrorReporter whose currentState is
// null (ScaffoldMessenger not yet mounted at cold-start). report() is a no-op.
// ---------------------------------------------------------------------------
class _NoOpNotificationErrorReporter implements NotificationErrorReporter {
  @override
  void report(String message) {
    // Intentional no-op: simulates GlobalKey.currentState == null (EC-12).
  }
}

// ---------------------------------------------------------------------------
// TASK-08 helper: simulates the cyclePredictionProvider listener (FR-15).
//
// Mirrors app.dart prediction-listener body (lines 160–204):
//   - Skips if prev is not AsyncData (cold-start guard).
//   - Reads currentSettings from the container's settingsNotifierProvider.
//   - Calls scheduler.execute() with skipIfPast: false.
//   - On NotificationScheduleFailure: debugPrint only (silent drop, no revert,
//     no snackbar — FR-09 / FR-15).
//   - Outer on PlatformException: caught silently.
//
// Uses the caller-supplied [container] so tests can assert on
// [settingsNotifierProvider] state afterward.
// ---------------------------------------------------------------------------
Future<void> _simulatePredictionListenerFireWithContainer({
  required ProviderContainer container,
  required AsyncValue<CyclePrediction?>? prev,
  required AsyncValue<CyclePrediction?> next,
  required FakeNotificationService service,
}) async {
  if (prev is! AsyncData<CyclePrediction?>) return;
  if (next is! AsyncData<CyclePrediction?>) return;

  final prediction = next.valueOrNull;
  final currentSettings =
      container.read(settingsNotifierProvider).valueOrNull;
  if (currentSettings == null) return;

  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  final scheduler =
      await container.read(schedulePredictionNotificationProvider.future);
  try {
    final result = await scheduler.execute(
      prediction: prediction,
      settings: currentSettings,
      title: l10n.notification_prediction_title,
      body: prediction != null
          ? l10n.notification_prediction_body(
              currentSettings.notificationDaysBefore,
            )
          : '',
    );
    switch (result) {
      case NotificationScheduleSuccess():
        break;
      case NotificationScheduleFailure(:final error):
        // FR-09 / FR-15: silent drop — no revert, no snackbar.
        // ignore: avoid_print
        debugPrint('[predictionListener] schedule failure (silent drop): $error');
    }
  } on PlatformException catch (e) {
    debugPrint('[predictionListener] PlatformException (cancel path): $e');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BUG-002 fix: cold-start permission guard (FR-04, FR-05, EC-05)', () {
    test(
      'AsyncLoading → AsyncData(notificationsEnabled: true) does NOT call requestPermission (FR-04, EC-05)',
      () async {
        final fake = FakeNotificationService()..permissionGranted = false;

        final coldStartSettings = AppSettingsData(
          languageCode: '',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: true, // Persisted as enabled in DB
          onboardingCompleted: true,
        );

        await _simulateSettingsListenerGuard(
          prev: const AsyncLoading<AppSettingsData>(),
          next: AsyncData(coldStartSettings),
          service: fake,
        );

        expect(
          fake.requestPermissionCallCount,
          equals(0),
          reason: 'BUG-002: requestPermission() must NOT be called during the '
              'AsyncLoading → AsyncData cold-start transition (FR-04, EC-05)',
        );
      },
    );

    test(
      'AsyncData(notificationsEnabled: false) → AsyncData(true) DOES call requestPermission once (FR-04 positive)',
      () async {
        final fake = FakeNotificationService()..permissionGranted = true;

        final disabledSettings = AppSettingsData(
          languageCode: '',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: true,
        );
        final enabledSettings = AppSettingsData(
          languageCode: '',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

        await _simulateSettingsListenerGuard(
          prev: AsyncData(disabledSettings),
          next: AsyncData(enabledSettings),
          service: fake,
        );

        expect(
          fake.requestPermissionCallCount,
          equals(1),
          reason: 'requestPermission() must be called exactly once when user '
              'explicitly toggles notifications from false → true (FR-04)',
        );
      },
    );

    test(
      'AsyncData(notificationsEnabled: false) → AsyncData(false) does NOT call requestPermission (FR-05 negative)',
      () async {
        final fake = FakeNotificationService()..permissionGranted = true;

        final disabledSettings = AppSettingsData(
          languageCode: '',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: true,
        );

        await _simulateSettingsListenerGuard(
          prev: AsyncData(disabledSettings),
          next: AsyncData(disabledSettings),
          service: fake,
        );

        expect(
          fake.requestPermissionCallCount,
          equals(0),
          reason:
              'requestPermission() must not be called when notificationsEnabled '
              'remains false (FR-05 negative)',
        );
      },
    );

    test(
      'null prev (first listen call) does NOT call requestPermission',
      () async {
        final fake = FakeNotificationService()..permissionGranted = false;

        final enabledSettings = AppSettingsData(
          languageCode: '',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

        // Riverpod passes null as prev on the very first listen call.
        await _simulateSettingsListenerGuard(
          prev: null,
          next: AsyncData(enabledSettings),
          service: fake,
        );

        expect(
          fake.requestPermissionCallCount,
          equals(0),
          reason: 'requestPermission() must not be called when prev is null '
              '(first listen invocation)',
        );
      },
    );

    test(
      'AsyncData(true) → AsyncData(true) does NOT call requestPermission (already enabled)',
      () async {
        final fake = FakeNotificationService()..permissionGranted = true;

        final enabledSettings = AppSettingsData(
          languageCode: '',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

        await _simulateSettingsListenerGuard(
          prev: AsyncData(enabledSettings),
          next: AsyncData(enabledSettings),
          service: fake,
        );

        expect(
          fake.requestPermissionCallCount,
          equals(0),
          reason:
              'requestPermission() must not be called when notificationsEnabled '
              'was already true (no transition)',
        );
      },
    );
  });

  // ===========================================================================
  // TASK-11: FR-16 / FR-18 / NFR-15 — notificationTimeMinutes threading
  //
  // Verifies that notificationTimeMinutes on AppSettingsData flows through both
  // scheduler.execute() call sites so that the composed notifyAt carries the
  // correct hour and minute.
  //
  // Coverage: FR-16, FR-18, NFR-15.
  // ===========================================================================

  group('TASK-11 notificationTimeMinutes wiring (FR-16, FR-18, NFR-15)', () {
    test(
      'IF-08: notificationTimeMinutes=1380 (23:00) → scheduled.first.notifyAt has hour=23 minute=0',
      () async {
        final fake = FakeNotificationService(
          // Place "now" well before the notifyAt so the fake routes to scheduled.
          now: () => DateTime(2099, 1, 1, 0, 0),
        );
        // windowStart far enough in the future that notifyAt is also future.
        final windowStart = DateTime(2099, 2, 1);
        final prediction = CyclePrediction(
          windowStart: windowStart,
          windowEnd: windowStart.add(const Duration(days: 4)),
          expectedStart: windowStart.add(const Duration(days: 2)),
          cyclesUsed: 3,
        );
        final settings = AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 1,
          notificationsEnabled: true,
          onboardingCompleted: true,
          notificationTimeMinutes: 1380, // 23:00
        );

        await _simulatePredictionListenerSchedule(
          prediction: prediction,
          settings: settings,
          service: fake,
        );

        expect(
          fake.scheduled,
          hasLength(1),
          reason: 'FR-16: exactly one notification must be scheduled',
        );
        expect(
          fake.scheduled.first.notifyAt.hour,
          equals(23),
          reason:
              'FR-16: notifyAt.hour must be 23 when notificationTimeMinutes=1380',
        );
        expect(
          fake.scheduled.first.notifyAt.minute,
          equals(0),
          reason:
              'FR-16: notifyAt.minute must be 0 when notificationTimeMinutes=1380',
        );
      },
    );

    test(
      'EC-04 wiring: notificationTimeMinutes=0 (midnight 00:00) → scheduled.first.notifyAt has hour=0 minute=0',
      () async {
        final fake = FakeNotificationService(
          // Place "now" well before the notifyAt so the fake routes to scheduled.
          now: () => DateTime(2099, 1, 1, 0, 0),
        );
        // windowStart far enough in the future that notifyAt (midnight the day
        // before) is also well in the future relative to now.
        final windowStart = DateTime(2099, 3, 1);
        final prediction = CyclePrediction(
          windowStart: windowStart,
          windowEnd: windowStart.add(const Duration(days: 4)),
          expectedStart: windowStart.add(const Duration(days: 2)),
          cyclesUsed: 3,
        );
        final settings = AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 1,
          notificationsEnabled: true,
          onboardingCompleted: true,
          notificationTimeMinutes: 0, // midnight 00:00 — EC-04 lower bound
        );

        await _simulatePredictionListenerSchedule(
          prediction: prediction,
          settings: settings,
          service: fake,
        );

        expect(
          fake.scheduled,
          hasLength(1),
          reason: 'EC-04: exactly one notification must be scheduled',
        );
        expect(
          fake.scheduled.first.notifyAt.hour,
          equals(0),
          reason:
              'EC-04: notifyAt.hour must be 0 when notificationTimeMinutes=0 '
              '(midnight lower bound — no off-by-9 or wrap to 23:59)',
        );
        expect(
          fake.scheduled.first.notifyAt.minute,
          equals(0),
          reason:
              'EC-04: notifyAt.minute must be 0 when notificationTimeMinutes=0',
        );
      },
    );

    test(
      'BUG-002 preserved: AsyncLoading→AsyncData with notificationTimeMinutes=720 → requestPermissionCallCount==0',
      () async {
        final fake = FakeNotificationService()..permissionGranted = false;

        final coldStartSettings = AppSettingsData(
          languageCode: '',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: true,
          onboardingCompleted: true,
          notificationTimeMinutes: 720, // 12:00 — non-default value
        );

        await _simulateSettingsListenerGuard(
          prev: const AsyncLoading<AppSettingsData>(),
          next: AsyncData(coldStartSettings),
          service: fake,
        );

        expect(
          fake.requestPermissionCallCount,
          equals(0),
          reason:
              'BUG-002: the presence of notificationTimeMinutes must not weaken '
              'the cold-start permission guard — requestPermission() must not be '
              'called during AsyncLoading → AsyncData transition (FR-18, NFR-15)',
        );
      },
    );
  });

  // ===========================================================================
  // TASK-05: FR-09 prediction-listener → notification-scheduler wiring
  //
  // Verifies that SchedulePredictionNotification.execute() is called with the
  // correct notifyAt and non-empty strings when cyclePredictionProvider emits.
  // Also verifies the two EC-08 negative cases (disabled / null prediction).
  //
  // Coverage: FR-03, FR-09, EC-08, NFR-07.
  // ===========================================================================

  group('FR-09 prediction → scheduler → service wiring (TASK-05)', () {
    final windowStart = DateTime.utc(2026, 6, 10);
    final prediction = CyclePrediction(
      windowStart: windowStart.subtract(const Duration(days: 2)),
      windowEnd: windowStart.add(const Duration(days: 2)),
      expectedStart: windowStart,
      cyclesUsed: 3,
    );

    test(
      'happy path: valid prediction + notificationsEnabled → schedules once with correct notifyAt (FR-09)',
      () async {
        final fake = FakeNotificationService()..permissionGranted = true;
        final settings = AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 1,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

        await _simulatePredictionListenerSchedule(
          prediction: prediction,
          settings: settings,
          service: fake,
        );

        expect(
          fake.scheduled.length,
          equals(1),
          reason: 'FR-09: exactly one notification must be scheduled',
        );
        // notifyAt = (windowStart − daysBefore) at notificationTimeMinutes=540 (09:00 local)
        final base = prediction.windowStart.subtract(const Duration(days: 1));
        expect(
          fake.scheduled.first.notifyAt,
          equals(DateTime(base.year, base.month, base.day, 9, 0)),
          reason:
              'FR-09: notifyAt = prediction.windowStart − notificationDaysBefore at 09:00 local (notificationTimeMinutes default=540)',
        );
        expect(
          fake.scheduled.first.title,
          isNotEmpty,
          reason: 'FR-09: notification title must be non-empty',
        );
        expect(
          fake.scheduled.first.body,
          isNotEmpty,
          reason: 'FR-09: notification body must be non-empty',
        );
      },
    );

    test(
      'EC-08 negative: notificationsEnabled=false → no schedule, cancel called (FR-03)',
      () async {
        final fake = FakeNotificationService()..permissionGranted = true;
        final settings = AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 1,
          notificationsEnabled: false,
          onboardingCompleted: true,
        );

        await _simulatePredictionListenerSchedule(
          prediction: prediction,
          settings: settings,
          service: fake,
        );

        expect(
          fake.scheduled,
          isEmpty,
          reason: 'EC-08: must not schedule when notifications are disabled',
        );
        expect(
          fake.cancelCount,
          greaterThanOrEqualTo(1),
          reason: 'FR-03: cancel must be called even when disabled',
        );
      },
    );

    test(
      'EC-08 negative: null prediction + notificationsEnabled → no schedule, cancel called',
      () async {
        final fake = FakeNotificationService()..permissionGranted = true;
        final settings = AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 1,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

        await _simulatePredictionListenerSchedule(
          prediction: null,
          settings: settings,
          service: fake,
        );

        expect(
          fake.scheduled,
          isEmpty,
          reason: 'EC-08: must not schedule when prediction is null',
        );
        expect(
          fake.cancelCount,
          greaterThanOrEqualTo(1),
          reason: 'EC-08: cancel must be called even with null prediction',
        );
      },
    );
  });

  // ===========================================================================
  // TASK-08: FR-13 — iOS denial → toggle revert (no snackbar)
  //
  // When the user enables Notifications and the OS permission is denied,
  // the toggle is reverted to false. No snackbar is shown (EC-06 asymmetry:
  // denial is a normal "user said no" case, not an error to surface).
  //
  // Coverage: FR-13, EC-06, NFR-02.
  // ===========================================================================

  group('FR-13: iOS denial → toggle revert, no snackbar (TASK-08)', () {
    // Shared settings builder for this group.
    AppSettingsData disabledSettings() => AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: true,
        );

    AppSettingsData enabledSettings() => AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

    // Far-future prediction so the use case does not short-circuit on
    // notifyAt < today.  Date is pinned to 2099 so the test is deterministic.
    final futurePrediction = CyclePrediction(
      windowStart: DateTime(2099, 6, 10),
      windowEnd: DateTime(2099, 6, 14),
      expectedStart: DateTime(2099, 6, 12),
      cyclesUsed: 3,
    );

    test(
      'should_revert_toggle_when_os_permission_denied_given_user_enables_notifications',
      () async {
        final fake = FakeNotificationService(permissionGranted: false);
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = disabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        // Initialise the settingsNotifier so it reads from fakeRepo.
        await container.read(settingsNotifierProvider.future);

        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(enabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isFalse,
          reason:
              'FR-13: toggle must revert to false when OS permission is denied',
        );
        expect(
          fake.scheduleCallCount,
          equals(0),
          reason: 'FR-13: no schedule call made when permission is denied',
        );
        expect(
          fakeReporter.messages,
          isEmpty,
          reason:
              'EC-06: no snackbar shown on OS permission denial '
              '(asymmetry with schedule failure)',
        );
        expect(
          fake.requestPermissionCallCount,
          equals(1),
          reason: 'FR-13: requestPermission() called exactly once on toggle-on',
        );
      },
    );

    test(
      'FR-13 contrast: should_keep_toggle_on_and_schedule_when_permission_granted',
      () async {
        final fake = FakeNotificationService(permissionGranted: true);
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = disabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        // Pre-save the enabled state to the notifier — this models what the
        // real app does: the user taps the toggle, the notifier saves enabled,
        // and then the ref.listen callback fires. The listener on success does
        // NOT call save() again, so fakeRepo.storedSettings stays at enabled.
        await container
            .read(settingsNotifierProvider.notifier)
            .save(enabledSettings());

        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(enabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isTrue,
          reason:
              'FR-13 contrast: notificationsEnabled stays true when permission '
              'is granted and scheduling succeeds (no revert save() called)',
        );
        expect(
          fake.scheduleCallCount,
          equals(1),
          reason:
              'FR-13 contrast: exactly one schedule call on successful toggle-on',
        );
        expect(
          fakeReporter.messages,
          isEmpty,
          reason: 'FR-13 contrast: no snackbar on successful toggle-on',
        );
      },
    );
  });

  // ===========================================================================
  // TASK-08: FR-14 — cancel-success + schedule-failure → revert + snackbar
  //
  // When permission is granted but scheduling fails (the use case returns
  // NotificationScheduleFailure), the settings listener reverts the toggle
  // to false and shows a localised error snackbar exactly once.
  //
  // Sub-tests:
  //   EC-07: dedup guard — the revert's second AsyncData emit does NOT
  //          trigger a second snackbar (dedup guard at app.dart line 224).
  //   EC-09: rapid-toggle — two sequential failures each produce one snackbar
  //          (intentional: each is a distinct user action).
  //   EC-12: null currentState race — snackbar dispatch is a no-op but revert
  //          still happens (FR-08(a) independent of FR-08(b)).
  //
  // Coverage: FR-14, EC-07, EC-09, EC-12, NFR-02.
  // ===========================================================================

  group('FR-14: schedule-failure → revert + snackbar (TASK-08)', () {
    AppSettingsData disabledSettings() => AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: true,
        );

    AppSettingsData enabledSettings() => AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

    // Far-future prediction so schedule-failure path is actually reached
    // (without a prediction, execute() short-circuits to NotificationScheduleSuccess).
    final futurePrediction = CyclePrediction(
      windowStart: DateTime(2099, 6, 10),
      windowEnd: DateTime(2099, 6, 14),
      expectedStart: DateTime(2099, 6, 12),
      cyclesUsed: 3,
    );

    test(
      'should_revert_toggle_and_report_snackbar_when_schedule_fails_given_permission_granted',
      () async {
        final fake = FakeNotificationService(permissionGranted: true)
          ..throwOnNextSchedule = true;
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = disabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(enabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isFalse,
          reason: 'FR-14: toggle must revert to false on schedule failure',
        );
        expect(
          fakeReporter.messages.length,
          equals(1),
          reason: 'FR-14: exactly one snackbar dispatched on schedule failure',
        );
        expect(
          fakeReporter.messages.first,
          equals(l10n.notificationScheduleFailedMessage),
          reason:
              'FR-14: snackbar message must match the localised '
              'notificationScheduleFailedMessage key',
        );
        expect(
          fake.scheduleCallCount,
          equals(0),
          reason:
              'FR-14: failed schedule does NOT count as a successful scheduling call',
        );
        expect(
          fake.cancelCallCount,
          equals(1),
          reason:
              'FR-14: cancelPredictionNotifications() called once before the failed schedule',
        );
      },
    );

    test(
      'EC-07: should_report_only_one_snackbar_when_revert_causes_second_identical_emit',
      () async {
        // The revert (save notificationsEnabled: false) causes the settingsNotifier
        // to emit AsyncData(disabled) a second time. The dedup guard in
        // _simulateSettingsListenerFire collapses this into a no-op.
        final fake = FakeNotificationService(permissionGranted: true)
          ..throwOnNextSchedule = true;
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = disabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        // First fire: toggle-on fails, reverts to disabled.
        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(enabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        // Second fire: simulates the revert's structural re-emit
        // (prev == next == disabled after the revert save).
        // The dedup guard must short-circuit this call.
        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(disabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        expect(
          fakeReporter.messages.length,
          equals(1),
          reason:
              'EC-07: dedup guard must prevent the revert re-emit from triggering '
              'a second snackbar (messages.length stays at 1, NOT 2)',
        );
      },
    );

    test(
      'EC-09: should_report_two_snackbars_when_two_distinct_toggle_failures_occur',
      () async {
        // Two sequential failed toggle-on cycles — each is a genuine user
        // action (false → true) and each fails. EC-09 spec allows two snackbars
        // because each is a distinct user-visible error event.
        final fake = FakeNotificationService(permissionGranted: true)
          ..throwOnNextSchedule = true;
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = disabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        // First toggle-on attempt — fails, reverts.
        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(enabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        // Second toggle-on attempt — fails again.
        fake.throwOnNextSchedule = true;
        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(enabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        expect(
          fakeReporter.messages.length,
          equals(2),
          reason:
              'EC-09: two distinct rapid-toggle failures each produce one snackbar '
              '(intentional — each is a separate user-initiated error)',
        );
        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isFalse,
          reason: 'EC-09: toggle remains reverted to false after both failures',
        );
      },
    );

    test(
      'EC-12: should_revert_toggle_even_when_reporter_is_no_op_null_state_race',
      () async {
        // EC-12: if the ScaffoldMessenger is not yet mounted (cold-start race),
        // currentState is null and report() is a no-op. The revert must still
        // happen independently of whether the snackbar was dispatched.
        final fake = FakeNotificationService(permissionGranted: true)
          ..throwOnNextSchedule = true;
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = disabledSettings();

        // Provide a no-op reporter simulating currentState == null (EC-12).
        final noOpReporter = _NoOpNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: noOpReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(enabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isFalse,
          reason:
              'EC-12: toggle revert (FR-08(a)) must happen independently of '
              'snackbar dispatch (FR-08(b)) even when the reporter is a no-op',
        );
      },
    );

    test(
      'FR-14 contrast: should_keep_toggle_on_and_not_report_when_schedule_succeeds',
      () async {
        final fake = FakeNotificationService(permissionGranted: true);
        // throwOnNextSchedule stays false (default) → schedule succeeds.
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = disabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        // Pre-save the enabled state to the notifier — models the real app flow
        // (user taps toggle → notifier saves enabled → listener fires).
        // On success the listener does NOT call save() again, so
        // fakeRepo.storedSettings stays at enabled.
        await container
            .read(settingsNotifierProvider.notifier)
            .save(enabledSettings());

        await _simulateSettingsListenerFire(
          container: container,
          prev: AsyncData(disabledSettings()),
          next: AsyncData(enabledSettings()),
          service: fake,
          prediction: futurePrediction,
        );

        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isTrue,
          reason:
              'FR-14 contrast: notificationsEnabled stays true when scheduling '
              'succeeds (no revert save() was called)',
        );
        expect(
          fakeReporter.messages,
          isEmpty,
          reason: 'FR-14 contrast: no snackbar when scheduling succeeds',
        );
      },
    );
  });

  // ===========================================================================
  // TASK-08: FR-15 — prediction-listener silent drop
  //
  // When the cyclePredictionProvider fires and scheduling fails, the prediction
  // listener silently drops the failure — no toggle revert, no snackbar.
  // This is the EC-06 asymmetry on the prediction side: only the settings
  // listener shows UI feedback, the prediction listener never does.
  //
  // Coverage: FR-15, EC-06, NFR-02.
  // ===========================================================================

  group('FR-15: prediction-listener silent drop on schedule failure (TASK-08)',
      () {
    final windowStart = DateTime(2099, 6, 10);
    final prediction = CyclePrediction(
      windowStart: windowStart,
      windowEnd: windowStart.add(const Duration(days: 4)),
      expectedStart: windowStart.add(const Duration(days: 2)),
      cyclesUsed: 3,
    );

    AppSettingsData enabledSettings() => AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 1,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

    test(
      'should_not_revert_or_report_when_schedule_fails_in_prediction_listener',
      () async {
        final fake = FakeNotificationService(permissionGranted: true)
          ..throwOnNextSchedule = true;
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = enabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        // Initialise settings notifier (reads notificationsEnabled: true).
        await container.read(settingsNotifierProvider.future);

        // Simulate the prediction listener firing (AsyncData → AsyncData with
        // a schedule failure injected).
        await expectLater(
          () => _simulatePredictionListenerFireWithContainer(
            container: container,
            prev: AsyncData<CyclePrediction?>(prediction),
            next: AsyncData<CyclePrediction?>(prediction),
            service: fake,
          ),
          returnsNormally,
          reason: 'FR-15: prediction listener must not throw on schedule failure',
        );

        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isTrue,
          reason:
              'FR-15: notificationsEnabled must remain true — prediction listener '
              'never reverts the toggle on schedule failure',
        );
        expect(
          fakeReporter.messages,
          isEmpty,
          reason:
              'FR-15: prediction listener must not show a snackbar on schedule failure '
              '(silent drop — only settings listener surfaces UI errors)',
        );
      },
    );

    test(
      'FR-15 contrast: should_schedule_successfully_when_no_failure_injected',
      () async {
        final fake = FakeNotificationService(
          permissionGranted: true,
          now: () => DateTime(2026, 1, 1), // well before 2099 prediction
        );
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = enabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        await _simulatePredictionListenerFireWithContainer(
          container: container,
          prev: AsyncData<CyclePrediction?>(prediction),
          next: AsyncData<CyclePrediction?>(prediction),
          service: fake,
        );

        expect(
          fake.scheduleCallCount,
          equals(1),
          reason:
              'FR-15 contrast: exactly one successful schedule when no failure '
              'is injected',
        );
        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isTrue,
          reason: 'FR-15 contrast: notificationsEnabled unchanged after success',
        );
      },
    );
  });

  // ===========================================================================
  // TASK-08: FR-16 — cancel-throws → outer catch handles gracefully
  //
  // When cancelPredictionNotifications() (called first inside execute()) throws
  // a PlatformException, the outer catch in the settings listener handles it
  // silently. No revert occurs (the save() call is never reached), no snackbar
  // is shown. The initial state is preserved.
  //
  // Coverage: FR-16, EC-03, NFR-02.
  // ===========================================================================

  group('FR-16: cancel-throws → outer catch, no revert, no snackbar (TASK-08)',
      () {
    AppSettingsData disabledSettings() => AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: true,
        );

    AppSettingsData enabledSettings() => AppSettingsData(
          languageCode: 'en',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: true,
          onboardingCompleted: true,
        );

    test(
      'should_not_throw_and_preserve_initial_state_when_cancel_throws_platform_exception',
      () async {
        // throwOnNextCancel causes cancelPredictionNotifications() to throw
        // before the schedule call — scheduleCallCount and cancelCallCount both
        // stay at 0 (throw-before-mutation pattern per fake implementation).
        final fake = FakeNotificationService(permissionGranted: true)
          ..throwOnNextCancel = true;
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = disabledSettings();
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        // Must not throw — outer on PlatformException in the listener catches it.
        await expectLater(
          () => _simulateSettingsListenerFire(
            container: container,
            prev: AsyncData(disabledSettings()),
            next: AsyncData(enabledSettings()),
            service: fake,
          ),
          returnsNormally,
          reason:
              'FR-16: PlatformException from cancelPredictionNotifications() must '
              'not escape the listener stack',
        );

        // The cancel threw before any mutation — notificationsEnabled stays at
        // the initial false stored in fakeRepo (no save() was called by the
        // listener because the revert path is never reached).
        expect(
          fakeRepo.storedSettings?.notificationsEnabled,
          isFalse,
          reason:
              'FR-16: initial notificationsEnabled=false is preserved — '
              'no revert save() is called when cancel throws (the PlatformException '
              'is caught by the outer handler before the switch on result)',
        );
        expect(
          fakeReporter.messages,
          isEmpty,
          reason:
              'FR-16: no snackbar shown when cancel throws (outer catch path)',
        );
        expect(
          fake.cancelCallCount,
          equals(0),
          reason:
              'FR-16: cancelCallCount stays at 0 — throw-before-mutation pattern '
              '(the counter increments only on successful cancel completion)',
        );
      },
    );
  });

  // ===========================================================================
  // TASK-08: EC-08 — cold-start dual-guard
  //
  // When settingsNotifierProvider is still in AsyncLoading and transitions
  // to AsyncData in the same listener call (cold-start), neither listener
  // should trigger a schedule call. Both helpers have a "prev is! AsyncData"
  // guard that returns early.
  //
  // Coverage: EC-08, BUG-002 (regression guard).
  // ===========================================================================

  group('EC-08: cold-start dual-guard — no schedule on AsyncLoading→AsyncData',
      () {
    test(
      'should_not_schedule_when_settings_listener_fires_on_cold_start_transition',
      () async {
        final fake = FakeNotificationService(permissionGranted: true);
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = AppSettingsData(
            languageCode: 'en',
            painEnabled: true,
            notesEnabled: true,
            notificationDaysBefore: 2,
            notificationsEnabled: true,
            onboardingCompleted: true,
          );
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        // Cold-start: prev is AsyncLoading (not yet AsyncData).
        await _simulateSettingsListenerFire(
          container: container,
          prev: const AsyncLoading<AppSettingsData>(),
          next: AsyncData(
            AppSettingsData(
              languageCode: 'en',
              painEnabled: true,
              notesEnabled: true,
              notificationDaysBefore: 2,
              notificationsEnabled: true,
              onboardingCompleted: true,
            ),
          ),
          service: fake,
        );

        expect(
          fake.scheduleCallCount,
          equals(0),
          reason:
              'EC-08: no schedule call must happen on cold-start '
              'AsyncLoading → AsyncData transition (prev is! AsyncData guard)',
        );
        expect(
          fake.requestPermissionCallCount,
          equals(0),
          reason:
              'EC-08: requestPermission() must not be called on cold-start '
              'transition (BUG-002 guard)',
        );
      },
    );

    test(
      'should_not_schedule_when_prediction_listener_fires_on_cold_start_transition',
      () async {
        final fake = FakeNotificationService(permissionGranted: true);
        final fakeRepo = FakeAppSettingsRepository()
          ..storedSettings = AppSettingsData(
            languageCode: 'en',
            painEnabled: true,
            notesEnabled: true,
            notificationDaysBefore: 2,
            notificationsEnabled: true,
            onboardingCompleted: true,
          );
        final fakeReporter = FakeNotificationErrorReporter();
        final container = _makeSettingsListenerContainer(
          service: fake,
          fakeRepo: fakeRepo,
          reporter: fakeReporter,
        );
        addTearDown(container.dispose);

        await container.read(settingsNotifierProvider.future);

        final windowStart = DateTime(2099, 6, 10);
        final prediction = CyclePrediction(
          windowStart: windowStart,
          windowEnd: windowStart.add(const Duration(days: 4)),
          expectedStart: windowStart.add(const Duration(days: 2)),
          cyclesUsed: 3,
        );

        // Cold-start: prev is AsyncLoading.
        await _simulatePredictionListenerFireWithContainer(
          container: container,
          prev: const AsyncLoading<CyclePrediction?>(),
          next: AsyncData<CyclePrediction?>(prediction),
          service: fake,
        );

        expect(
          fake.scheduleCallCount,
          equals(0),
          reason:
              'EC-08: no schedule call on cold-start AsyncLoading → AsyncData '
              'transition in the prediction listener',
        );
      },
    );
  });

  // ===========================================================================
  // TASK-08: NFR-06 — Semantics: snackbar content carries a semantics label
  //
  // After triggering an FR-14 failure, the snackbar widget built by the
  // production reporter wraps the text in a SnackBar(content: Text(message)).
  // The Text widget must be reachable via the semantics tree so that
  // TalkBack / VoiceOver can announce the error to the user.
  //
  // Coverage: NFR-06, WCAG 2.2 AA (role=alert analogue).
  // ===========================================================================

  group('NFR-06: snackbar content carries a Semantics text node (TASK-08)', () {
    testWidgets(
      'snackbar_text_node_is_reachable_via_semantics_tree',
      (WidgetTester tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final failureMessage = l10n.notificationScheduleFailedMessage;

        // Build the same SnackBar widget that the production
        // _ScaffoldMessengerReporter.report() constructs. NFR-06 verifies that
        // the Text inside it is accessible — an inaccessible error message is
        // an incomplete implementation per WCAG 2.2 AA and CLAUDE.md §2.4.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(failureMessage)),
                    );
                  },
                  child: const Text('trigger'),
                ),
              ),
            ),
          ),
        );

        // Tap the button to show the snackbar.
        await tester.tap(find.text('trigger'));
        await tester.pump(); // Show snackbar.

        // The snackbar Text widget must be present in the widget tree.
        expect(
          find.text(failureMessage),
          findsOneWidget,
          reason:
              'NFR-06: the localised failure message must appear in the '
              'widget tree so TalkBack/VoiceOver can read it',
        );

        // Verify the Text widget is included in the semantics tree.
        final semantics = tester.getSemantics(find.text(failureMessage));
        expect(
          semantics.label,
          equals(failureMessage),
          reason:
              'NFR-06: Text inside SnackBar must carry a Semantics label '
              'matching the displayed message (WCAG 2.2 AA)',
        );
      },
    );
  });
}
