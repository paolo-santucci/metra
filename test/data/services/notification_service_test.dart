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

// Full E2E tests for FlutterNotificationService require a live platform
// channel (flutter_local_notifications registers a method channel).
// Those tests must run on a physical device or emulator.
// This file covers what is testable without a platform channel:
//   - the domain interface is well-formed (constructable, callable via fake)
//   - the stable notification-ID constant value (orphan-risk guard)

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/notification_service.dart';
import 'package:metra/domain/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../helpers/fake_notification_service.dart';

void main() {
  group('NotificationService interface', () {
    test('FakeNotificationService implements NotificationService', () {
      final fake = FakeNotificationService();
      expect(fake, isA<NotificationService>());
    });

    test('initialize() sets the initialized flag', () async {
      final fake = FakeNotificationService();
      expect(fake.initialized, isFalse);
      await fake.initialize();
      expect(fake.initialized, isTrue);
    });

    test('schedulePredictionNotification() records the call', () async {
      final fake = FakeNotificationService();
      final date = DateTime(2026, 5, 10);
      await fake.schedulePredictionNotification(date, 'Title', 'Body');
      expect(fake.scheduled, hasLength(1));
      expect(fake.scheduled.first.notifyAt, equals(date));
      expect(fake.scheduled.first.title, equals('Title'));
      expect(fake.scheduled.first.body, equals('Body'));
    });

    test('cancelPredictionNotifications() increments cancelCount', () async {
      final fake = FakeNotificationService();
      await fake.cancelPredictionNotifications();
      await fake.cancelPredictionNotifications();
      expect(fake.cancelCount, equals(2));
    });
  });

  group('FlutterNotificationService constants', () {
    // This constant must never change without a migration plan.
    // Changing it would orphan any already-scheduled notifications
    // on devices that have not yet received the update.
    test('kPredictionNotificationId is stable at 1001', () {
      expect(
        FlutterNotificationService.kPredictionNotificationId,
        equals(1001),
      );
    });
  });

  group('FlutterNotificationService.computeScheduledTz (BUG-004 fix)', () {
    // computeScheduledTz is a @visibleForTesting helper that converts a UTC
    // DateTime to the local TZDateTime at 09:00 on the correct local calendar
    // day. These tests verify the timezone/local conversion is correct.
    setUpAll(tz_data.initializeTimeZones);

    test(
      'UTC midnight in UTC-5 (New York) → previous local calendar day at 09:00 (FR-08)',
      () {
        tz.setLocalLocation(tz.getLocation('America/New_York'));
        final service = FlutterNotificationService();
        // UTC 2026-06-08 00:00 = 2026-06-07 19:00 in New York (UTC-5).
        // So the notification should fire on June 7, not June 8.
        final result = service.computeScheduledTz(
          DateTime.utc(2026, 6, 8, 0, 0, 0),
        );
        expect(result.year, equals(2026));
        expect(result.month, equals(6));
        expect(
          result.day,
          equals(7),
          reason: 'BUG-004: UTC midnight in UTC-5 must resolve to the PREVIOUS '
              'local calendar day (June 7, not June 8)',
        );
        expect(result.hour, equals(9));
        expect(result.minute, equals(0));
        expect(result.location.name, equals('America/New_York'));
      },
    );

    test(
      'UTC midnight in UTC+2 (Rome, CEST) → same local calendar day at 09:00 (FR-08 Italy regression guard)',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final service = FlutterNotificationService();
        // UTC 2026-06-08 00:00 = 2026-06-08 02:00 CEST — same calendar day.
        final result = service.computeScheduledTz(
          DateTime.utc(2026, 6, 8, 0, 0, 0),
        );
        expect(result.year, equals(2026));
        expect(result.month, equals(6));
        expect(
          result.day,
          equals(8),
          reason: 'Italy regression guard: UTC midnight in UTC+2 must stay on '
              'the same local calendar day (June 8)',
        );
        expect(result.hour, equals(9));
        expect(result.location.name, equals('Europe/Rome'));
      },
    );

    test(
      'UTC midnight on DST spring-forward date in Italy → no exception, day=29 at 09:00 (EC-10)',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final service = FlutterNotificationService();
        // 2026-03-29: Italy clocks spring forward at 02:00 → 03:00.
        // UTC midnight = 2026-03-29 01:00 CET (before the switch) → same calendar day.
        // 09:00 is unambiguously after the DST switch — no exception expected.
        expect(
          () => service.computeScheduledTz(
            DateTime.utc(2026, 3, 29, 0, 0, 0),
          ),
          returnsNormally,
          reason: 'DST spring-forward must not throw',
        );
        final result = service.computeScheduledTz(
          DateTime.utc(2026, 3, 29, 0, 0, 0),
        );
        expect(result.year, equals(2026));
        expect(result.month, equals(3));
        expect(result.day, equals(29));
        expect(result.hour, equals(9));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group A — FakeNotificationService routing (same-day cold-start path)
  // ---------------------------------------------------------------------------

  group('FakeNotificationService.schedulePredictionNotification routing', () {
    test('same_day_past_09_records_to_shown_not_scheduled', () async {
      final fake = FakeNotificationService(
        nowOverride: DateTime(2099, 1, 1, 10, 0), // 10:00 on the notify day
      );
      final notifyAt = DateTime(2099, 1, 1, 9, 0); // same local day

      await fake.schedulePredictionNotification(notifyAt, 'Title', 'Body');

      expect(fake.shown, hasLength(1));
      expect(fake.showCount, equals(1));
      expect(fake.scheduled, isEmpty);
      expect(fake.shown.first.notifyAt, equals(notifyAt));
    });

    test('future_date_records_to_scheduled_not_shown', () async {
      final fake = FakeNotificationService(
        nowOverride: DateTime(2026, 5, 7, 10, 0),
      );
      final notifyAt = DateTime(2099, 1, 1, 9, 0); // far future

      await fake.schedulePredictionNotification(notifyAt, 'Title', 'Body');

      expect(fake.scheduled, hasLength(1));
      expect(fake.shown, isEmpty);
      expect(fake.showCount, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Group B — FlutterNotificationService.shouldShowImmediately predicate
  // These tests FAIL until T-02 adds shouldShowImmediately to
  // FlutterNotificationService. That is the intended T-02 contract.
  // ---------------------------------------------------------------------------

  group('FlutterNotificationService.shouldShowImmediately', () {
    setUpAll(tz_data.initializeTimeZones);

    test('same_day_after_scheduled_time_returns_true', () {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
      final service = FlutterNotificationService();
      final scheduledDate = tz.TZDateTime(tz.local, 2026, 5, 7, 9, 0);
      final now = tz.TZDateTime(tz.local, 2026, 5, 7, 9, 29);
      expect(service.shouldShowImmediately(scheduledDate, now), isTrue);
    });

    test('different_day_returns_false', () {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
      final service = FlutterNotificationService();
      final scheduledDate = tz.TZDateTime(tz.local, 2026, 5, 7, 9, 0);
      final now = tz.TZDateTime(tz.local, 2026, 5, 8, 9, 29);
      expect(service.shouldShowImmediately(scheduledDate, now), isFalse);
    });

    test('same_day_exact_boundary_returns_true', () {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
      final service = FlutterNotificationService();
      final scheduledDate = tz.TZDateTime(tz.local, 2026, 5, 7, 9, 0);
      final now = tz.TZDateTime(tz.local, 2026, 5, 7, 9, 0);
      expect(service.shouldShowImmediately(scheduledDate, now), isTrue);
    });

    test('same_day_before_scheduled_time_returns_false', () {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
      final service = FlutterNotificationService();
      final scheduledDate = tz.TZDateTime(tz.local, 2026, 5, 7, 9, 0);
      final now = tz.TZDateTime(tz.local, 2026, 5, 7, 8, 59);
      expect(service.shouldShowImmediately(scheduledDate, now), isFalse);
    });
  });
}
