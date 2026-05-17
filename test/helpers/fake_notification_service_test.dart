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
  // TASK-10: throwOnNextSchedule failure-injection knob (FR-14, EC-11, OQ-M1-05)
  // ---------------------------------------------------------------------------

  group('FakeNotificationService.throwOnNextSchedule — FR-14, EC-11, OQ-M1-05',
      () {
    test(
      'given_knob_false_when_schedule_then_returns_Success_and_records_one_entry',
      () async {
        final fake = FakeNotificationService();
        final result = await fake.schedulePredictionNotification(
          DateTime.utc(2026, 6, 1),
          'title',
          'body',
        );
        expect(result, isA<NotificationScheduleSuccess>());
        expect(fake.scheduled.length + fake.shown.length, equals(1));
      },
    );

    test(
      'given_knob_true_when_schedule_then_throws_PlatformException_and_lists_remain_empty',
      () async {
        final fake = FakeNotificationService();
        fake.throwOnNextSchedule = true;
        await expectLater(
          fake.schedulePredictionNotification(
            DateTime.utc(2026, 6, 1),
            'title',
            'body',
          ),
          throwsA(
            allOf(
              isA<PlatformException>(),
              predicate<PlatformException>(
                (e) => e.code == 'fake_schedule_failure',
              ),
            ),
          ),
        );
        expect(fake.scheduled, isEmpty);
        expect(fake.shown, isEmpty);
        // One-shot: knob auto-clears to false after the throw.
        expect(fake.throwOnNextSchedule, isFalse);
      },
    );

    test(
      'given_knob_fired_once_when_second_call_then_succeeds_and_records_one_entry',
      () async {
        final fake = FakeNotificationService();
        fake.throwOnNextSchedule = true;
        try {
          await fake.schedulePredictionNotification(
            DateTime.utc(2026, 6, 1),
            'title',
            'body',
          );
        } catch (_) {}
        final result2 = await fake.schedulePredictionNotification(
          DateTime.utc(2026, 6, 2),
          'title',
          'body',
        );
        expect(result2, isA<NotificationScheduleSuccess>());
        expect(fake.scheduled.length + fake.shown.length, equals(1));
      },
    );

    test(
      'given_knob_on_instance_a_when_instance_b_schedules_then_b_succeeds',
      () async {
        final a = FakeNotificationService()..throwOnNextSchedule = true;
        final b = FakeNotificationService();
        await expectLater(
          a.schedulePredictionNotification(
            DateTime.utc(2026, 6, 1),
            'title',
            'body',
          ),
          throwsA(isA<PlatformException>()),
        );
        final result = await b.schedulePredictionNotification(
          DateTime.utc(2026, 6, 1),
          'title',
          'body',
        );
        expect(result, isA<NotificationScheduleSuccess>());
      },
    );
  });
}
