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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/use_case_providers.dart';

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
}
