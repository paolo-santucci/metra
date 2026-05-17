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
import 'package:metra/data/services/notification_service.dart';
import 'package:metra/domain/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'fake_notification_service.dart';

void main() {
  group('FakeNotificationService time-routing (TASK-02, FR-02, NFR-11)', () {
    test(
      'given_same_day_past_notifyAt_when_now_is_23:30_and_notifyAt_is_00:00_then_routes_to_shown',
      () async {
        final fake = FakeNotificationService(
          now: () => DateTime(2099, 1, 1, 23, 30),
        );
        await fake.schedulePredictionNotification(
          DateTime(2099, 1, 1, 0, 0),
          't',
          'b',
        );
        expect(fake.shown, hasLength(1));
        expect(fake.scheduled, isEmpty);
      },
    );

    test(
      'given_same_day_future_notifyAt_when_now_is_08:00_and_notifyAt_is_23:00_then_routes_to_scheduled',
      () async {
        final fake = FakeNotificationService(
          now: () => DateTime(2099, 1, 1, 8, 0),
        );
        await fake.schedulePredictionNotification(
          DateTime(2099, 1, 1, 23, 0),
          't',
          'b',
        );
        expect(fake.scheduled, hasLength(1));
        expect(fake.shown, isEmpty);
      },
    );

    test(
      'given_future_date_when_now_is_2026-05-07_10:00_and_notifyAt_is_2099-01-01_09:00_then_routes_to_scheduled',
      () async {
        final fake = FakeNotificationService(
          now: () => DateTime(2026, 5, 7, 10, 0),
        );
        await fake.schedulePredictionNotification(
          DateTime(2099, 1, 1, 9, 0),
          't',
          'b',
        );
        expect(fake.scheduled, hasLength(1));
        expect(fake.shown, isEmpty);
      },
    );
  });

  group('Production parity NFR-11', () {
    late FlutterNotificationService prodService;

    setUpAll(() {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.UTC);
    });

    setUp(() {
      prodService = FlutterNotificationService();
    });

    test(
      'given_same_day_past_when_notifyAt_is_08:00_and_now_is_09:30_then_fake_and_prod_both_route_to_shown',
      () async {
        final now = DateTime(2099, 6, 1, 9, 30);
        final notifyAt = DateTime(2099, 6, 1, 8, 0);

        // Fake side: inspect shown/scheduled lists.
        final fake = FakeNotificationService(now: () => now);
        await fake.schedulePredictionNotification(notifyAt, 't', 'b');
        final fakeRoutesToShown = fake.shown.isNotEmpty;

        // Production side: use the @visibleForTesting predicate directly.
        final tzNow = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
        );
        final tzScheduled = tz.TZDateTime(
          tz.local,
          notifyAt.year,
          notifyAt.month,
          notifyAt.day,
          notifyAt.hour,
          notifyAt.minute,
        );
        final prodRoutesToShown =
            prodService.shouldShowImmediately(tzScheduled, tzNow);

        expect(fakeRoutesToShown, isTrue);
        expect(prodRoutesToShown, equals(fakeRoutesToShown));
      },
    );

    test(
      'given_same_day_future_when_notifyAt_is_18:00_and_now_is_09:30_then_fake_and_prod_both_route_to_scheduled',
      () async {
        final now = DateTime(2099, 6, 1, 9, 30);
        final notifyAt = DateTime(2099, 6, 1, 18, 0);

        // Fake side: inspect shown/scheduled lists.
        final fake = FakeNotificationService(now: () => now);
        await fake.schedulePredictionNotification(notifyAt, 't', 'b');
        final fakeRoutesToShown = fake.shown.isNotEmpty;

        // Production side: use the @visibleForTesting predicate directly.
        final tzNow = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
        );
        final tzScheduled = tz.TZDateTime(
          tz.local,
          notifyAt.year,
          notifyAt.month,
          notifyAt.day,
          notifyAt.hour,
          notifyAt.minute,
        );
        final prodRoutesToShown =
            prodService.shouldShowImmediately(tzScheduled, tzNow);

        expect(fakeRoutesToShown, isFalse);
        expect(prodRoutesToShown, equals(fakeRoutesToShown));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix #2: FakeNotificationService.hasNotificationPermission tracking
  // ---------------------------------------------------------------------------

  group('Fix #2: FakeNotificationService.hasNotificationPermission tracking',
      () {
    test(
      'hasNotificationPermission returns the configured value (default=true) '
      'and increments hasNotificationPermissionCallCount; '
      'does NOT increment requestPermissionCallCount',
      () async {
        final fake = FakeNotificationService();
        expect(
          fake.hasNotificationPermissionCallCount,
          equals(0),
          reason: 'counter starts at zero',
        );
        expect(
          fake.requestPermissionCallCount,
          equals(0),
          reason: 'requestPermissionCallCount starts at zero',
        );

        final result = await fake.hasNotificationPermission();

        expect(
          result,
          isTrue,
          reason: 'default hasNotificationPermissionValue is true',
        );
        expect(
          fake.hasNotificationPermissionCallCount,
          equals(1),
          reason: 'hasNotificationPermission increments its own counter',
        );
        expect(
          fake.requestPermissionCallCount,
          equals(0),
          reason:
              'hasNotificationPermission must NOT increment requestPermissionCallCount',
        );
      },
    );

    test(
      'hasNotificationPermission returns false when hasNotificationPermissionValue=false',
      () async {
        final fake =
            FakeNotificationService(hasNotificationPermissionValue: false);
        final result = await fake.hasNotificationPermission();
        expect(result, isFalse);
        expect(fake.hasNotificationPermissionCallCount, equals(1));
        expect(fake.requestPermissionCallCount, equals(0));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // TASK-05: FakeNotificationService battery-optimisation tracking (FR-03)
  // ---------------------------------------------------------------------------

  group('TASK-05: FakeNotificationService battery-optimisation methods (FR-03)',
      () {
    test(
      'isIgnoringBatteryOptimizations defaults to true',
      () async {
        final fake = FakeNotificationService();
        expect(await fake.isIgnoringBatteryOptimizations(), isTrue);
      },
    );

    test(
      'isIgnoringBatteryOptimizations returns configured false when set via constructor',
      () async {
        final fake = FakeNotificationService(
          isIgnoringBatteryOptimizationsValue: false,
        );
        expect(await fake.isIgnoringBatteryOptimizations(), isFalse);
      },
    );

    test(
      'openBatteryOptimizationSettings increments call count on each invocation',
      () async {
        final fake = FakeNotificationService();
        expect(fake.openBatteryOptimizationSettingsCallCount, equals(0));
        await fake.openBatteryOptimizationSettings();
        expect(fake.openBatteryOptimizationSettingsCallCount, equals(1));
        await fake.openBatteryOptimizationSettings();
        expect(fake.openBatteryOptimizationSettingsCallCount, equals(2));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group D — FakeNotificationService schedule contract (FR-06, TASK-03)
  //
  // The throwOnNextSchedule knob must RETURN a structured failure result
  // (NotificationScheduleFailure) — never throw — to match the production
  // NotificationService contract (FR-06).  The old throw-based assertions
  // were replaced here as part of TASK-03.
  // ---------------------------------------------------------------------------

  group('Group D — FakeNotificationService.throwOnNextSchedule (FR-06, TASK-03)',
      () {
    test(
      'should_return_NotificationScheduleFailure_when_throwOnNextSchedule_is_true_given_knob_set',
      () async {
        final fake = FakeNotificationService(
          now: () => DateTime(2099, 1, 1),
        );
        fake.throwOnNextSchedule = true;
        final result = await fake.schedulePredictionNotification(
          DateTime.utc(2099, 6, 1),
          'title',
          'body',
        );
        expect(result, isA<NotificationScheduleFailure>());
        expect(
          (result as NotificationScheduleFailure).error,
          isA<PlatformException>(),
        );
        expect(
          ((result).error as PlatformException).code,
          'fake_schedule_failure',
        );
        // One-shot: knob auto-clears to false after returning failure.
        expect(fake.throwOnNextSchedule, isFalse);
        // Lists remain empty — failure injection suppresses mutation.
        expect(fake.scheduled, isEmpty);
        expect(fake.shown, isEmpty);
      },
    );

    test(
      'should_return_NotificationScheduleSuccess_on_second_call_when_knob_already_consumed_given_single_shot_reset',
      () async {
        final fake = FakeNotificationService(
          now: () => DateTime(2099, 1, 1),
        );
        fake.throwOnNextSchedule = true;
        // Consume the knob — discard result.
        await fake.schedulePredictionNotification(
          DateTime.utc(2099, 6, 1),
          'title',
          'body',
        );
        // Second call must succeed.
        final result2 = await fake.schedulePredictionNotification(
          DateTime.utc(2099, 6, 2),
          'title',
          'body',
        );
        expect(result2, isA<NotificationScheduleSuccess>());
        expect(fake.scheduled.length + fake.shown.length, equals(1));
      },
    );

    test(
      'should_return_NotificationScheduleSuccess_twice_when_default_state_given_knob_never_set',
      () async {
        final fake = FakeNotificationService(
          now: () => DateTime(2099, 1, 1),
        );
        final result1 = await fake.schedulePredictionNotification(
          DateTime.utc(2099, 6, 1),
          'title',
          'body',
        );
        final result2 = await fake.schedulePredictionNotification(
          DateTime.utc(2099, 6, 2),
          'title',
          'body',
        );
        expect(result1, isA<NotificationScheduleSuccess>());
        expect(result2, isA<NotificationScheduleSuccess>());
        expect(fake.throwOnNextSchedule, isFalse);
      },
    );

    test(
      'given_knob_fired_once_when_second_call_then_succeeds_and_records_one_entry',
      () async {
        final fake = FakeNotificationService(
          now: () => DateTime(2099, 1, 1),
        );
        fake.throwOnNextSchedule = true;
        // Consume the knob (returns failure, does not throw).
        await fake.schedulePredictionNotification(
          DateTime.utc(2099, 6, 1),
          'title',
          'body',
        );
        final result2 = await fake.schedulePredictionNotification(
          DateTime.utc(2099, 6, 2),
          'title',
          'body',
        );
        expect(result2, isA<NotificationScheduleSuccess>());
        expect(fake.scheduled.length + fake.shown.length, equals(1));
      },
    );

    test(
      'given_knob_on_instance_a_when_instance_b_schedules_then_b_returns_success',
      () async {
        DateTime now() => DateTime(2099, 1, 1);
        final a = FakeNotificationService(now: now)..throwOnNextSchedule = true;
        final b = FakeNotificationService(now: now);
        final aResult = await a.schedulePredictionNotification(
          DateTime.utc(2099, 6, 1),
          'title',
          'body',
        );
        expect(aResult, isA<NotificationScheduleFailure>());
        final bResult = await b.schedulePredictionNotification(
          DateTime.utc(2099, 6, 1),
          'title',
          'body',
        );
        expect(bResult, isA<NotificationScheduleSuccess>());
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group D' — FakeNotificationService cancel knob (FR-16 enabler, OQ-QA-01)
  // ---------------------------------------------------------------------------

  group(
    "Group D' — FakeNotificationService.throwOnNextCancel (FR-16, OQ-QA-01)",
    () {
      test(
        'should_throw_PlatformException_when_throwOnNextCancel_is_true_given_knob_set',
        () async {
          final fake = FakeNotificationService();
          fake.throwOnNextCancel = true;
          await expectLater(
            fake.cancelPredictionNotifications,
            throwsA(
              allOf(
                isA<PlatformException>(),
                predicate<PlatformException>(
                  (e) => e.code == 'fake_cancel_failure',
                ),
              ),
            ),
          );
          // One-shot: knob auto-clears to false after the throw.
          expect(fake.throwOnNextCancel, isFalse);
          // Counters must NOT increment on the throw path (throw-before-mutation).
          expect(fake.cancelCount, equals(0));
          expect(fake.cancelCallCount, equals(0));
        },
      );

      test(
        'should_complete_normally_and_increment_cancelCallCount_when_default_state_given_knob_not_set',
        () async {
          final fake = FakeNotificationService();
          await fake.cancelPredictionNotifications();
          expect(fake.cancelCallCount, equals(1));
          expect(fake.cancelCount, equals(1));
        },
      );

      test(
        'should_throw_only_once_and_succeed_on_second_call_given_single_shot_reset',
        () async {
          final fake = FakeNotificationService();
          fake.throwOnNextCancel = true;
          // First call throws.
          try {
            await fake.cancelPredictionNotifications();
          } on PlatformException {
            // expected
          }
          expect(fake.throwOnNextCancel, isFalse);
          // Second call must succeed.
          await fake.cancelPredictionNotifications();
          expect(fake.cancelCallCount, equals(1));
          expect(fake.cancelCount, equals(1));
        },
      );
    },
  );
}
