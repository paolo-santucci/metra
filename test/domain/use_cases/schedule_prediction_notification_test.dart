// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/services/notification_service.dart';
import 'package:metra/domain/use_cases/schedule_prediction_notification.dart';

import '../../helpers/fake_notification_service.dart';

void main() {
  late FakeNotificationService fakeService;
  late SchedulePredictionNotification useCase;

  CyclePrediction makePrediction(DateTime expectedStart) {
    return CyclePrediction(
      windowStart: expectedStart.subtract(const Duration(days: 2)),
      windowEnd: expectedStart.add(const Duration(days: 2)),
      expectedStart: expectedStart,
      cyclesUsed: 3,
    );
  }

  setUp(() {
    fakeService = FakeNotificationService();
    useCase = SchedulePredictionNotification(fakeService);
  });

  group('SchedulePredictionNotification.execute', () {
    // Test 1: null prediction → cancel called, no schedule
    test('null prediction → cancel called, no schedule', () async {
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: true,
        onboardingCompleted: false,
      );

      await useCase.execute(
        prediction: null,
        settings: settings,
        title: 'Test title',
        body: 'Test body',
      );

      expect(fakeService.cancelCount, equals(1));
      expect(fakeService.scheduled, isEmpty);
    });

    // Test 2: notifications disabled → cancel called, no schedule
    test('notifications disabled → cancel called, no schedule', () async {
      final prediction = makePrediction(
        DateTime.now().add(const Duration(days: 10)),
      );
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
      );

      await useCase.execute(
        prediction: prediction,
        settings: settings,
        title: 'Test title',
        body: 'Test body',
      );

      expect(fakeService.cancelCount, equals(1));
      expect(fakeService.scheduled, isEmpty);
    });

    // Test 3: notify date in the past → cancel called, no schedule
    test('notify date in the past → cancel called, no schedule', () async {
      // windowStart = 2 days ago, notificationDaysBefore = 3
      // → notifyAt = windowStart - 3 days = 5 days ago → past
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final prediction = makePrediction(
        twoDaysAgo.add(const Duration(days: 2)),
      ); // expectedStart = now, windowStart = twoDaysAgo
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 3,
        notificationsEnabled: true,
        onboardingCompleted: false,
      );

      await useCase.execute(
        prediction: prediction,
        settings: settings,
        title: 'Test title',
        body: 'Test body',
      );

      expect(fakeService.cancelCount, equals(1));
      expect(fakeService.scheduled, isEmpty);
    });

    // Test 4: valid future prediction → cancel then schedule
    test('valid future prediction → cancel then schedule', () async {
      final futureStart = DateTime.now().add(const Duration(days: 10));
      final prediction = makePrediction(
        futureStart.add(const Duration(days: 2)),
      ); // windowStart = futureStart
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: true,
        onboardingCompleted: false,
      );

      await useCase.execute(
        prediction: prediction,
        settings: settings,
        title: 'Test title',
        body: 'Test body',
      );

      expect(fakeService.cancelCount, equals(1));
      expect(fakeService.scheduled, hasLength(1));

      final entry = fakeService.scheduled.first;
      // notifyAt is composed as local midnight(windowStart - 2 days) + 09:00
      // (default notificationTimeMinutes = 540)
      final expectedBase =
          prediction.windowStart.subtract(const Duration(days: 2));
      final expectedLocal = DateTime(
        expectedBase.year,
        expectedBase.month,
        expectedBase.day,
        9, // default 540 minutes = 09:00
        0,
      );
      expect(entry.notifyAt, equals(expectedLocal));
      expect(entry.title, equals('Test title'));
      expect(entry.body, equals('Test body'));
    });

    test(
        'given_notificationDaysBefore_1_when_execute_then_notifyAt_is_windowStart_minus_1_day',
        () async {
      final notifService = FakeNotificationService();
      final uc = SchedulePredictionNotification(notifService);
      final prediction = CyclePrediction(
        expectedStart: DateTime.utc(2026, 6, 1),
        windowStart: DateTime.utc(2026, 5, 30),
        windowEnd: DateTime.utc(2026, 6, 3),
        cyclesUsed: 3,
      );
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationsEnabled: true,
        notificationDaysBefore: 1, // lower bound
        onboardingCompleted: false,
      );

      await uc.execute(
        prediction: prediction,
        settings: settings,
        title: 't',
        body: 'b',
      );

      // 1 day before windowStart = 2026-05-29 at 09:00 local (default 540 min)
      expect(
        notifService.scheduled.first.notifyAt,
        equals(DateTime(2026, 5, 29, 9, 0)),
      );
    });

    test(
        'given_notificationDaysBefore_4_when_execute_then_notifyAt_is_windowStart_minus_4_days',
        () async {
      final notifService = FakeNotificationService();
      final uc = SchedulePredictionNotification(notifService);
      final prediction = CyclePrediction(
        expectedStart: DateTime.utc(2026, 6, 1),
        windowStart: DateTime.utc(2026, 5, 30),
        windowEnd: DateTime.utc(2026, 6, 3),
        cyclesUsed: 3,
      );
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationsEnabled: true,
        notificationDaysBefore: 4, // mid-range
        onboardingCompleted: false,
      );

      await uc.execute(
        prediction: prediction,
        settings: settings,
        title: 't',
        body: 'b',
      );

      // 4 days before windowStart = 2026-05-26 at 09:00 local (default 540 min)
      expect(
        notifService.scheduled.first.notifyAt,
        equals(DateTime(2026, 5, 26, 9, 0)),
      );
    });

    test(
        'given_notificationDaysBefore_7_when_execute_then_notifyAt_is_windowStart_minus_7_days',
        () async {
      final notifService = FakeNotificationService();
      final uc = SchedulePredictionNotification(notifService);
      final prediction = CyclePrediction(
        expectedStart: DateTime.utc(2026, 6, 1),
        windowStart: DateTime.utc(2026, 6, 10),
        windowEnd: DateTime.utc(2026, 6, 13),
        cyclesUsed: 3,
      );
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationsEnabled: true,
        notificationDaysBefore: 7, // upper bound
        onboardingCompleted: false,
      );

      await uc.execute(
        prediction: prediction,
        settings: settings,
        title: 't',
        body: 'b',
      );

      // 7 days before windowStart (2026-06-10) = 2026-06-03 at 09:00 local (default 540 min)
      expect(
        notifService.scheduled.first.notifyAt,
        equals(DateTime(2026, 6, 3, 9, 0)),
      );
    });
  });

  group('TASK-03 smoke tests', () {
    // Base prediction and settings used by multiple smoke tests
    final pred = CyclePrediction(
      expectedStart: DateTime.utc(2099, 7, 20),
      windowStart: DateTime.utc(2099, 7, 18),
      windowEnd: DateTime.utc(2099, 7, 22),
      cyclesUsed: 3,
    );
    final baseSettings = AppSettingsData(
      languageCode: 'it',
      painEnabled: true,
      notesEnabled: true,
      notificationsEnabled: true,
      notificationDaysBefore: 2,
      onboardingCompleted: false,
    );

    test(
      'given_timeMinutes_855_when_execute_then_service_receives_notifyAt_hour14_minute15',
      () async {
        await useCase.execute(
          prediction: pred,
          settings: baseSettings.copyWith(notificationTimeMinutes: 855),
          title: 't',
          body: 'b',
        );
        // 2099-07-18 minus 2 days = 2099-07-16; time set to 14:15 local
        expect(fakeService.scheduled, hasLength(1));
        final notifyAt = fakeService.scheduled.first.notifyAt;
        expect(notifyAt.hour, equals(14));
        expect(notifyAt.minute, equals(15));
      },
    );

    test(
      'given_same_day_past_time_0800_vs_now_0930_then_immediate_show_scheduled_empty',
      () async {
        // today at 09:30 (fake clock)
        final today = DateTime.now();
        final todayAt0930 = DateTime(
          today.year,
          today.month,
          today.day,
          9,
          30,
        );
        final fakeSvc = FakeNotificationService(now: () => todayAt0930);
        final uc = SchedulePredictionNotification(fakeSvc);

        // windowStart - 1 day = today; time = 08:00 (480 minutes)
        final windowStart = DateTime(
          today.year,
          today.month,
          today.day,
        ).add(const Duration(days: 1));
        final sameDayPred = CyclePrediction(
          expectedStart: windowStart.add(const Duration(days: 2)),
          windowStart: windowStart,
          windowEnd: windowStart.add(const Duration(days: 4)),
          cyclesUsed: 3,
        );

        await uc.execute(
          prediction: sameDayPred,
          settings: baseSettings.copyWith(
            notificationDaysBefore: 1,
            notificationTimeMinutes: 480, // 08:00
          ),
          title: 't',
          body: 'b',
        );

        expect(
          fakeSvc.scheduled,
          isEmpty,
          reason: 'past time must not schedule',
        );
        expect(
          fakeSvc.shown,
          hasLength(1),
          reason: 'must show immediately',
        );
      },
    );

    test(
      'given_same_day_future_time_1800_vs_now_0930_then_zoned_schedule_shown_empty',
      () async {
        // today at 09:30 (fake clock)
        final today = DateTime.now();
        final todayAt0930 = DateTime(
          today.year,
          today.month,
          today.day,
          9,
          30,
        );
        final fakeSvc = FakeNotificationService(now: () => todayAt0930);
        final uc = SchedulePredictionNotification(fakeSvc);

        // windowStart - 1 day = today; time = 18:00 (1080 minutes)
        final windowStart = DateTime(
          today.year,
          today.month,
          today.day,
        ).add(const Duration(days: 1));
        final sameDayPred = CyclePrediction(
          expectedStart: windowStart.add(const Duration(days: 2)),
          windowStart: windowStart,
          windowEnd: windowStart.add(const Duration(days: 4)),
          cyclesUsed: 3,
        );

        await uc.execute(
          prediction: sameDayPred,
          settings: baseSettings.copyWith(
            notificationDaysBefore: 1,
            notificationTimeMinutes: 1080, // 18:00
          ),
          title: 't',
          body: 'b',
        );

        expect(
          fakeSvc.shown,
          isEmpty,
          reason: 'future time must not show immediately',
        );
        expect(
          fakeSvc.scheduled,
          hasLength(1),
          reason: 'must schedule',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Boundary group — TASK-13
  // ---------------------------------------------------------------------------
  group('boundary — daysBefore limits', () {
    // Far-future prediction used across all boundary tests so notifyAt is
    // always after today and never accidentally hits the same-day-past path.
    final farFuturePred = CyclePrediction(
      expectedStart: DateTime.utc(2099, 8, 20),
      windowStart: DateTime.utc(2099, 8, 18),
      windowEnd: DateTime.utc(2099, 8, 22),
      cyclesUsed: 3,
    );

    test(
      'given_daysBefore_7_when_execute_then_succeeds',
      () async {
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);
        final settings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationsEnabled: true,
          notificationDaysBefore: 7,
          onboardingCompleted: false,
        );

        await uc.execute(
          prediction: farFuturePred,
          settings: settings,
          title: 't',
          body: 'b',
        );

        // notifyAt = 2099-08-18 - 7 days = 2099-08-11 at 09:00
        expect(svc.scheduled, hasLength(1));
        final notifyAt = svc.scheduled.first.notifyAt;
        expect(notifyAt, equals(DateTime(2099, 8, 11, 9, 0)));
      },
    );

    test(
      'given_daysBefore_6_when_execute_then_succeeds_and_notifyAt_is_windowStart_minus_6_days',
      () async {
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);
        final settings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationsEnabled: true,
          notificationDaysBefore: 6,
          onboardingCompleted: false,
        );

        await uc.execute(
          prediction: farFuturePred,
          settings: settings,
          title: 't',
          body: 'b',
        );

        // notifyAt = 2099-08-18 - 6 days = 2099-08-12 at 09:00
        expect(svc.scheduled, hasLength(1));
        final notifyAt = svc.scheduled.first.notifyAt;
        expect(notifyAt, equals(DateTime(2099, 8, 12, 9, 0)));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Time threading group — TASK-13
  // ---------------------------------------------------------------------------
  group('time threading — notificationTimeMinutes to hour:minute', () {
    // Use a far-future windowStart so no "past" guard fires.
    final farFuturePred = CyclePrediction(
      expectedStart: DateTime.utc(2099, 9, 10),
      windowStart: DateTime.utc(2099, 9, 8),
      windowEnd: DateTime.utc(2099, 9, 12),
      cyclesUsed: 3,
    );
    final baseDays = AppSettingsData(
      languageCode: 'it',
      painEnabled: true,
      notesEnabled: true,
      notificationsEnabled: true,
      notificationDaysBefore: 2,
      onboardingCompleted: false,
    );

    test(
      'given_timeMinutes_0_when_execute_then_notifyAt_is_midnight',
      () async {
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);

        await uc.execute(
          prediction: farFuturePred,
          settings: baseDays.copyWith(notificationTimeMinutes: 0),
          title: 't',
          body: 'b',
        );

        // 2099-09-08 - 2 days = 2099-09-06 at 00:00
        expect(svc.scheduled, hasLength(1));
        final notifyAt = svc.scheduled.first.notifyAt;
        expect(notifyAt.hour, equals(0));
        expect(notifyAt.minute, equals(0));
      },
    );

    test(
      'given_timeMinutes_1439_when_execute_then_notifyAt_hour23_minute59',
      () async {
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);

        await uc.execute(
          prediction: farFuturePred,
          settings: baseDays.copyWith(notificationTimeMinutes: 1439),
          title: 't',
          body: 'b',
        );

        // 2099-09-08 - 2 days = 2099-09-06 at 23:59
        expect(svc.scheduled, hasLength(1));
        final notifyAt = svc.scheduled.first.notifyAt;
        expect(notifyAt.hour, equals(23));
        expect(notifyAt.minute, equals(59));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // EC-15: double-emit idempotency — TASK-13
  // ---------------------------------------------------------------------------
  group('EC-15 idempotency', () {
    test(
      'given_valid_future_prediction_when_execute_twice_then_cancelCount_2_and_scheduled_length_1',
      () async {
        // FakeNotificationService.cancelPredictionNotifications() now clears
        // the scheduled list (mirrors real OS cancel semantics), so a second
        // execute replaces rather than appends the scheduled entry.
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);
        final pred = CyclePrediction(
          expectedStart: DateTime.utc(2099, 10, 20),
          windowStart: DateTime.utc(2099, 10, 18),
          windowEnd: DateTime.utc(2099, 10, 22),
          cyclesUsed: 3,
        );
        final settings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationsEnabled: true,
          notificationDaysBefore: 2,
          onboardingCompleted: false,
        );

        await uc.execute(
          prediction: pred,
          settings: settings,
          title: 't',
          body: 'b',
        );
        await uc.execute(
          prediction: pred,
          settings: settings,
          title: 't',
          body: 'b',
        );

        expect(svc.cancelCount, equals(2));
        expect(svc.scheduled, hasLength(1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // skipIfPast — settings-change guard
  // ---------------------------------------------------------------------------
  group('skipIfPast — settings-change guard', () {
    // Shared prediction and settings for this group.
    final baseSettings = AppSettingsData(
      languageCode: 'it',
      painEnabled: true,
      notesEnabled: true,
      notificationsEnabled: true,
      notificationDaysBefore: 2,
      onboardingCompleted: false,
    );

    test(
      'given_skipIfPast_true_and_same_day_past_time_then_no_show_no_schedule',
      () async {
        // Scenario: user opens Settings at 09:30 and changes notificationDaysBefore
        // such that the computed notifyAt is today at 08:00 (already past).
        // Expected: execute() returns silently — no immediate notification.
        final today = DateTime.now();
        final todayAt0930 = DateTime(today.year, today.month, today.day, 9, 30);
        final fakeSvc = FakeNotificationService(now: () => todayAt0930);
        final uc = SchedulePredictionNotification(fakeSvc);

        // windowStart = tomorrow → notifyAt = today at 08:00 (past relative to 09:30)
        final windowStart = DateTime(
          today.year,
          today.month,
          today.day,
        ).add(const Duration(days: 1));
        final sameDayPred = CyclePrediction(
          expectedStart: windowStart.add(const Duration(days: 2)),
          windowStart: windowStart,
          windowEnd: windowStart.add(const Duration(days: 4)),
          cyclesUsed: 3,
        );

        await uc.execute(
          prediction: sameDayPred,
          settings: baseSettings.copyWith(
            notificationDaysBefore: 1,
            notificationTimeMinutes: 480, // 08:00
          ),
          title: 't',
          body: 'b',
          skipIfPast: true,
          clock: () => todayAt0930,
        );

        expect(
          fakeSvc.shown,
          isEmpty,
          reason: 'skipIfPast: true must suppress the immediate-show path',
        );
        expect(fakeSvc.scheduled, isEmpty);
        expect(fakeSvc.cancelCount, equals(1));
      },
    );

    test(
      'given_skipIfPast_false_and_same_day_past_time_then_immediate_show_preserved',
      () async {
        // Regression guard: skipIfPast defaults to false, so the BUG-005
        // cold-start immediate-show path is preserved for the prediction
        // data-change listener.
        final today = DateTime.now();
        final todayAt0930 = DateTime(today.year, today.month, today.day, 9, 30);
        final fakeSvc = FakeNotificationService(now: () => todayAt0930);
        final uc = SchedulePredictionNotification(fakeSvc);

        final windowStart = DateTime(
          today.year,
          today.month,
          today.day,
        ).add(const Duration(days: 1));
        final sameDayPred = CyclePrediction(
          expectedStart: windowStart.add(const Duration(days: 2)),
          windowStart: windowStart,
          windowEnd: windowStart.add(const Duration(days: 4)),
          cyclesUsed: 3,
        );

        await uc.execute(
          prediction: sameDayPred,
          settings: baseSettings.copyWith(
            notificationDaysBefore: 1,
            notificationTimeMinutes: 480, // 08:00
          ),
          title: 't',
          body: 'b',
          // skipIfPast defaults to false — BUG-005 path must still fire
          clock: () => todayAt0930,
        );

        expect(
          fakeSvc.shown,
          hasLength(1),
          reason:
              'skipIfPast: false (default) must preserve BUG-005 immediate-show',
        );
        expect(fakeSvc.scheduled, isEmpty);
      },
    );

    test(
      'given_skipIfPast_true_and_future_notification_time_then_schedule_proceeds',
      () async {
        // skipIfPast: true must NOT suppress scheduling when notifyAt is in the
        // future — it only blocks past/same-day-past times.
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);
        final farFuturePred = CyclePrediction(
          expectedStart: DateTime.utc(2099, 8, 22),
          windowStart: DateTime.utc(2099, 8, 20),
          windowEnd: DateTime.utc(2099, 8, 24),
          cyclesUsed: 3,
        );

        await uc.execute(
          prediction: farFuturePred,
          settings: baseSettings,
          title: 't',
          body: 'b',
          skipIfPast: true,
        );

        expect(svc.scheduled, hasLength(1));
        expect(svc.shown, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // TASK-10: range guards moved to entity; failure propagation (FR-16)
  // ---------------------------------------------------------------------------
  group(
      'SchedulePredictionNotification.execute — range guards moved to entity (FR-16)',
      () {
    test(
      'given_valid_settings_when_execute_then_completes_without_ArgumentError',
      () async {
        // Validation now happens at AppSettingsData construction (entity layer).
        // Any AppSettingsData that reaches execute() has already passed
        // construction-time guards — no ArgumentError at the use-case level.
        final validSettings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationsEnabled:
              false, // disabled → cancel path; no schedule needed
          notificationDaysBefore: 2,
          onboardingCompleted: false,
        );
        await expectLater(
          useCase.execute(
            prediction: null,
            settings: validSettings,
            title: 't',
            body: 'b',
          ),
          completes,
          reason: 'valid settings must reach execute() and complete normally',
        );
      },
    );

    test(
      'given_throwOnNextSchedule_true_when_execute_then_result_is_NotificationScheduleFailure',
      () async {
        // M4 (TASK-07): the use case now returns a structured result instead of
        // propagating the PlatformException. FakeNotificationService returns a
        // NotificationScheduleFailure wrapping a PlatformException with code
        // 'fake_schedule_failure' when throwOnNextSchedule is true (TASK-03).
        fakeService.throwOnNextSchedule = true;
        final validSettings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationsEnabled: true,
          notificationDaysBefore: 2,
          onboardingCompleted: false,
        );
        final farFuturePred = CyclePrediction(
          expectedStart: DateTime.utc(2099, 8, 20),
          windowStart: DateTime.utc(2099, 8, 18),
          windowEnd: DateTime.utc(2099, 8, 22),
          cyclesUsed: 3,
        );
        final result = await useCase.execute(
          prediction: farFuturePred,
          settings: validSettings,
          title: 't',
          body: 'b',
        );
        expect(result, isA<NotificationScheduleFailure>());
        expect(
          (result as NotificationScheduleFailure).error,
          isA<PlatformException>(),
        );
        expect(
          (result.error as PlatformException).code,
          'fake_schedule_failure',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group C — SchedulePredictionNotification.execute (new return-type assertions)
  // FR-04, FR-05, NFR-03, NFR-04, EC-01, EC-02
  // ---------------------------------------------------------------------------
  group('Group C — SchedulePredictionNotification.execute (return-type assertions)', () {
    // Shared far-future prediction: always future → no past-guard fires.
    final validPrediction = CyclePrediction(
      expectedStart: DateTime.utc(2099, 7, 20),
      windowStart: DateTime.utc(2099, 7, 18),
      windowEnd: DateTime.utc(2099, 7, 22),
      cyclesUsed: 3,
    );
    final enabledSettings = AppSettingsData(
      languageCode: 'it',
      painEnabled: true,
      notesEnabled: true,
      notificationsEnabled: true,
      notificationDaysBefore: 2,
      onboardingCompleted: false,
    );

    test(
      'given_throwOnNextSchedule_true_when_execute_then_result_is_NotificationScheduleFailure_with_PlatformException_error',
      () async {
        // TASK-03 dependency: FakeNotificationService.throwOnNextSchedule will
        // return NotificationScheduleFailure (not throw) after TASK-03 ships.
        // Until then this test lights red on "failure propagated" — expected.
        final svc = FakeNotificationService();
        svc.throwOnNextSchedule = true;
        final uc = SchedulePredictionNotification(svc);

        final result = await uc.execute(
          prediction: validPrediction,
          settings: enabledSettings,
          title: 't',
          body: 'b',
        );

        expect(result, isA<NotificationScheduleFailure>());
        expect(
          (result as NotificationScheduleFailure).error,
          isA<PlatformException>(),
        );
      },
    );

    test(
      'given_default_fake_when_execute_then_result_is_NotificationScheduleSuccess',
      () async {
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);

        final result = await uc.execute(
          prediction: validPrediction,
          settings: enabledSettings,
          title: 't',
          body: 'b',
        );

        expect(result, isA<NotificationScheduleSuccess>());
      },
    );

    test(
      'given_null_prediction_when_execute_then_result_is_NotificationScheduleSuccess_and_nothing_scheduled',
      () async {
        // EC-01: null prediction short-circuit resolves to success.
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);

        final result = await uc.execute(
          prediction: null,
          settings: enabledSettings,
          title: 't',
          body: 'b',
        );

        expect(result, isA<NotificationScheduleSuccess>());
        expect(svc.cancelCount, equals(1));
        expect(svc.scheduled, isEmpty);
      },
    );

    test(
      'given_notifications_disabled_when_execute_then_result_is_NotificationScheduleSuccess_and_nothing_scheduled',
      () async {
        // EC-02: notificationsEnabled == false short-circuit resolves to success.
        final disabledSettings = enabledSettings.copyWith(
          notificationsEnabled: false,
        );
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);

        final result = await uc.execute(
          prediction: validPrediction,
          settings: disabledSettings,
          title: 't',
          body: 'b',
        );

        expect(result, isA<NotificationScheduleSuccess>());
        expect(svc.scheduled, isEmpty);
      },
    );

    test(
      'given_notificationDaysBefore_minus_1_when_execute_then_throws_ArgumentError',
      () async {
        // ArgumentError is thrown at AppSettingsData construction (entity
        // invariant) — not at the use-case level. The lambda passed to
        // expect() must include the construction so the error is captured.
        final svc = FakeNotificationService();
        final uc = SchedulePredictionNotification(svc);

        expect(
          () async {
            final invalidSettings = AppSettingsData(
              languageCode: 'it',
              painEnabled: true,
              notesEnabled: true,
              notificationsEnabled: true,
              notificationDaysBefore: -1, // violates [1, 7] invariant
              onboardingCompleted: false,
            );
            await uc.execute(
              prediction: validPrediction,
              settings: invalidSettings,
              title: 't',
              body: 'b',
            );
          },
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    // ---------------------------------------------------------------------------
    // Domain purity audit (NFR-03)
    // ---------------------------------------------------------------------------
    test(
      'given_notification_service_dart_when_audited_then_no_framework_imports',
      () {
        // This test is a static assertion documented in code rather than
        // a runtime check: lib/domain/services/notification_service.dart must
        // not import any of the following:
        //   "package:flutter/"
        //   "package:drift/"
        //   "package:http/"
        //   "package:flutter_local_notifications/"
        //
        // Verified by: flutter analyze lib/domain/ (CI gate).
        // This test exists as a living spec comment — it passes trivially
        // at runtime because there is nothing to execute.
        expect(true, isTrue);
      },
    );
  });

  group('cold-start regression (BUG-005)', () {
    test(
      'cold_start_after_09_on_notification_day_shows_immediately_not_lost',
      () async {
        // Fixed far-future date; local constructor avoids UTC-offset ambiguity on CI.
        final nowOverride =
            DateTime(2099, 3, 1, 10, 0); // 10:00 local on notify day
        final fakeService = FakeNotificationService(nowOverride: nowOverride);
        final useCase = SchedulePredictionNotification(fakeService);

        // notifyAt = windowStart - notificationDaysBefore = 2099-03-06 - 5d = 2099-03-01
        // Using local constructor: unambiguous in any CI timezone.
        final windowStart =
            DateTime(2099, 3, 6, 12, 0); // local noon (no UTC shift)
        final prediction = CyclePrediction(
          expectedStart: windowStart.add(const Duration(days: 2)),
          windowStart: windowStart,
          windowEnd: windowStart.add(const Duration(days: 4)),
          cyclesUsed: 3,
        );
        final settings = AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationsEnabled: true,
          notificationDaysBefore: 5,
          onboardingCompleted: false,
        );

        await useCase.execute(
          prediction: prediction,
          settings: settings,
          title: 'Promemoria ciclo',
          body: 'La finestra stimata inizia tra 5 giorni',
        );

        expect(
          fakeService.cancelCount,
          equals(1),
          reason: 'use case always cancels before scheduling',
        );
        expect(
          fakeService.scheduled,
          isEmpty,
          reason: 'past 09:00 on same day: must NOT go to the scheduled queue',
        );
        expect(
          fakeService.shown,
          hasLength(1),
          reason:
              'must be shown immediately — cold-start alarm must not be lost',
        );
        expect(fakeService.shown.first.title, equals('Promemoria ciclo'));
        expect(
          fakeService.shown.first.body,
          equals('La finestra stimata inizia tra 5 giorni'),
        );
      },
    );
  });
}
