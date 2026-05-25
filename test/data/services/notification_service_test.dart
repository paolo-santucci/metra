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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
      // Use a far-future date so the FakeNotificationService routes it to
      // `scheduled` (not `shown`) regardless of when the test is executed.
      // The original date (2026-05-10) was once in the future but became
      // today on 2026-05-10, causing the fake to route it to the same-day
      // immediate-show path instead of the scheduled path.
      final date = DateTime(2099, 12, 31, 9, 0);
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
      'UTC midnight in UTC-5 (New York) → previous local calendar day, hour=0 (FR-08 BUG-004)',
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
        // notifyAt.hour == 0 (UTC midnight input); hour forwarded verbatim.
        expect(result.hour, equals(0));
        expect(result.minute, equals(0));
        expect(result.location.name, equals('America/New_York'));
      },
    );

    test(
      'UTC midnight in UTC+2 (Rome, CEST) → same local calendar day, hour=0 (FR-08 Italy regression guard)',
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
        // notifyAt.hour == 0 (UTC midnight input); hour forwarded verbatim.
        expect(result.hour, equals(0));
        expect(result.location.name, equals('Europe/Rome'));
      },
    );

    test(
      'UTC midnight on DST spring-forward date in Italy → no exception, day=29 hour=0 (EC-10)',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final service = FlutterNotificationService();
        // 2026-03-29: Italy clocks spring forward at 02:00 → 03:00.
        // UTC midnight = 2026-03-29 01:00 CET (before the switch) → same calendar day.
        // The requested time (00:00) is before the DST switch — no exception expected.
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
        // notifyAt.hour == 0 (UTC midnight input); hour forwarded verbatim.
        expect(result.hour, equals(0));
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

  // ---------------------------------------------------------------------------
  // Group C — TASK-07 smoke tests: notifyAt hour/minute forwarded (no off-by-9)
  // ---------------------------------------------------------------------------

  group('TASK-07: computeScheduledTz respects notifyAt hour and minute', () {
    setUpAll(tz_data.initializeTimeZones);

    test(
      'computeScheduledTz at 14:15 returns TZDateTime hour=14 minute=15 (no off-by-9)',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final sut = FlutterNotificationService();
        final notifyAt = DateTime(2099, 6, 10, 14, 15);
        final tzd = sut.computeScheduledTz(notifyAt);
        expect(tzd.hour, 14);
        expect(tzd.minute, 15);
      },
    );

    test('grep: no literal ", 9)" in computeScheduledTz body', () async {
      final src = await File(
        'lib/data/services/notification_service.dart',
      ).readAsString();
      expect(
        src,
        isNot(matches(RegExp(r'computeScheduledTz[\s\S]*?,\s*9\s*\)'))),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group D — TASK-14: non-09:00 time forwarding (FR-11)
  // Regression guard: computeScheduledTz must never subtract or hardcode 9 h.
  // ---------------------------------------------------------------------------

  group(
      'TASK-14 Group 1: computeScheduledTz forwards any notifyAt hour/minute (FR-11)',
      () {
    setUpAll(tz_data.initializeTimeZones);

    test(
      '09:00 notifyAt returns hour=9 minute=0 — no accidental subtraction',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final sut = FlutterNotificationService();
        final notifyAt = DateTime(2099, 6, 10, 9, 0);
        final tzd = sut.computeScheduledTz(notifyAt);
        expect(tzd.hour, equals(9));
        expect(tzd.minute, equals(0));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group E — TASK-14: time-of-day edge cases EC-04, EC-05
  // ---------------------------------------------------------------------------

  group('TASK-14 Group 2: computeScheduledTz time-of-day edges (EC-04, EC-05)',
      () {
    setUpAll(tz_data.initializeTimeZones);

    test(
      'notifyAt midnight 00:00 → hour=0 minute=0',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final sut = FlutterNotificationService();
        final notifyAt = DateTime(2099, 6, 10, 0, 0);
        final tzd = sut.computeScheduledTz(notifyAt);
        expect(tzd.hour, equals(0));
        expect(tzd.minute, equals(0));
      },
    );

    test(
      'notifyAt 23:59 → hour=23 minute=59',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final sut = FlutterNotificationService();
        final notifyAt = DateTime(2099, 6, 10, 23, 59);
        final tzd = sut.computeScheduledTz(notifyAt);
        expect(tzd.hour, equals(23));
        expect(tzd.minute, equals(59));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group F — TASK-14: BUG-004 UTC→local day arithmetic preserved (FR-19)
  // Distinct from existing 2026 tests: year 2099, explicit hour/minute echo.
  // ---------------------------------------------------------------------------

  group('TASK-14 Group 3: BUG-004 UTC→local day arithmetic (FR-19)', () {
    setUpAll(tz_data.initializeTimeZones);

    test(
      'UTC 2099-06-08 00:00 in America/New_York → local day=7, hour=0, minute=0',
      () {
        tz.setLocalLocation(tz.getLocation('America/New_York'));
        final sut = FlutterNotificationService();
        // UTC midnight in New York (UTC-4 in June) = 2099-06-07 20:00 local.
        // The notification must fire on June 7 (the correct local calendar day).
        final notifyAt = DateTime.utc(2099, 6, 8, 0, 0);
        final tzd = sut.computeScheduledTz(notifyAt);
        expect(
          tzd.day,
          equals(7),
          reason:
              'UTC midnight in UTC-4 must map to the previous local calendar day',
        );
        expect(
          tzd.hour,
          equals(notifyAt.hour),
          reason: 'hour must echo notifyAt.hour verbatim',
        );
        expect(
          tzd.minute,
          equals(notifyAt.minute),
          reason: 'minute must echo notifyAt.minute verbatim',
        );
        expect(tzd.location.name, equals('America/New_York'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group G — TASK-14: DST regression (NFR-12, Europe/Rome)
  // Tests notifyAt.hour == 2, minute == 30 around the DST transition times.
  // The production function passes hour/minute verbatim to TZDateTime ctor;
  // the timezone package normalizes any ambiguous or gap time silently.
  // ---------------------------------------------------------------------------

  group('TASK-14 Group 4: DST regression Europe/Rome (NFR-12)', () {
    setUpAll(tz_data.initializeTimeZones);

    test(
      'Spring-forward 2026-03-29 02:30 → no exception; valid TZDateTime produced',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final sut = FlutterNotificationService();
        // Italy clocks spring forward at 02:00 → 03:00 on 2026-03-29.
        // UTC 2026-03-29 02:30 = CET 03:30 after the switch (UTC+1 → UTC+2).
        // Local day is still 29. The timezone package silently shifts the
        // gap time forward (02:30 → 03:30), so result.hour == 3, minute == 30.
        final notifyAt = DateTime.utc(2026, 3, 29, 2, 30);
        expect(
          () => sut.computeScheduledTz(notifyAt),
          returnsNormally,
          reason: 'Spring-forward DST must not throw',
        );
        final tzd = sut.computeScheduledTz(notifyAt);
        expect(tzd.year, equals(2026));
        expect(tzd.month, equals(3));
        expect(tzd.day, equals(29));
        // The timezone package normalizes the gap: 02:30 does not exist in
        // Europe/Rome on 2026-03-29, so TZDateTime shifts it to 03:30.
        expect(
          tzd.hour,
          equals(3),
          reason: 'OS-silent gap shift: 02:30 normalizes to 03:30',
        );
        expect(tzd.minute, equals(30));
      },
    );

    test(
      'Fall-back 2026-10-25 02:30 → no exception; hour=2 minute=30 (first occurrence)',
      () {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final sut = FlutterNotificationService();
        // Italy clocks fall back at 03:00 CEST → 02:00 CET on 2026-10-25
        // (UTC 01:00). UTC 02:30 is past the fall-back (UTC 01:00), so the
        // local time is CET 03:30 — but notifyAt.hour == 2 and that is the
        // value passed verbatim to TZDateTime. 02:30 CET on 2026-10-25 is a
        // valid, unambiguous wall-clock time (fall-back produced the second
        // 02:00–03:00 block in CET). The timezone package constructs it without
        // error and hour == 2, minute == 30.
        final notifyAt = DateTime.utc(2026, 10, 25, 2, 30);
        expect(
          () => sut.computeScheduledTz(notifyAt),
          returnsNormally,
          reason: 'Fall-back DST must not throw',
        );
        final tzd = sut.computeScheduledTz(notifyAt);
        expect(tzd.year, equals(2026));
        expect(tzd.month, equals(10));
        expect(tzd.day, equals(25));
        expect(
          tzd.hour,
          equals(2),
          reason:
              'Fall-back: notifyAt.hour==2 echoed verbatim; 02:30 CET is valid',
        );
        expect(tzd.minute, equals(30));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group H — TASK-14: static constant assertions (NFR-15)
  // kPredictionNotificationId == 1001 is already covered in
  // 'FlutterNotificationService constants' above; no duplication needed.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Fix #2: hasNotificationPermission — read-only check (FR-07, no-nag)
  //
  // The implementation calls areNotificationsEnabled() (read-only) on the
  // Android plugin via the 'dexterous.com/flutter/local_notifications' channel.
  // We verify it does NOT call requestNotificationsPermission (which shows a
  // system dialog). Both methods share the same MethodChannel in the plugin.
  // ---------------------------------------------------------------------------
  group(
      'Fix #2: hasNotificationPermission — read-only via areNotificationsEnabled',
      () {
    const kNotifChannel = 'dexterous.com/flutter/local_notifications';

    test(
      'hasNotificationPermission returns false when areNotificationsEnabled '
      'returns false and does NOT invoke requestNotificationsPermission',
      () async {
        bool requestPermissionCalled = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kNotifChannel),
          (call) async {
            if (call.method == 'areNotificationsEnabled') return false;
            if (call.method == 'requestNotificationsPermission') {
              requestPermissionCalled = true;
              return true;
            }
            return null;
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kNotifChannel),
            null,
          );
        });

        final service = FlutterNotificationService();
        final result = await service.hasNotificationPermission();

        expect(
          result,
          isFalse,
          reason:
              'hasNotificationPermission must reflect the OS permission state',
        );
        expect(
          requestPermissionCalled,
          isFalse,
          reason: 'requestNotificationsPermission must NEVER be called by '
              'hasNotificationPermission — it would show a system dialog',
        );
      },
    );

    test(
      'hasNotificationPermission returns true when areNotificationsEnabled '
      'returns true',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kNotifChannel),
          (call) async {
            if (call.method == 'areNotificationsEnabled') return true;
            return null;
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kNotifChannel),
            null,
          );
        });

        final service = FlutterNotificationService();
        final result = await service.hasNotificationPermission();

        expect(result, isTrue);
      },
    );

    test(
      'hasNotificationPermission returns true on non-Android platform '
      '(areNotificationsEnabled returns null — fail-open)',
      () async {
        // Simulate a platform where areNotificationsEnabled returns null
        // (e.g. Android < 13 or iOS where the method is not implemented).
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kNotifChannel),
          (call) async {
            if (call.method == 'areNotificationsEnabled') return null;
            return null;
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kNotifChannel),
            null,
          );
        });

        final service = FlutterNotificationService();
        final result = await service.hasNotificationPermission();

        expect(
          result,
          isTrue,
          reason: 'hasNotificationPermission must fail-open (return true) when '
              'areNotificationsEnabled returns null — do not block scheduling '
              'over a query failure',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group I — T-02 (BUG-02): openNotificationSettings swallows all exceptions
  // ---------------------------------------------------------------------------

  group('T-02: openNotificationSettings — never-throws contract (BUG-02)', () {
    const kNotifSettingsChannel = 'metra/notification_settings';

    test(
      'openNotificationSettings_swallows_MissingPluginException',
      () async {
        // No mock handler registered → Flutter test binding raises
        // MissingPluginException for an unhandled channel invokeMethod call.
        // The bare catch(e) must swallow it; the Future must complete normally.
        final captured = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? msg, {int? wrapWidth}) => captured.add(msg ?? '');
        addTearDown(() => debugPrint = originalDebugPrint);

        final service = FlutterNotificationService();
        await expectLater(service.openNotificationSettings(), completes);

        expect(
          captured.any((m) => m.contains('MissingPluginException')),
          isTrue,
          reason: 'MissingPluginException must be surfaced via debugPrint with '
              'the correct prefix',
        );
      },
    );

    test(
      'openNotificationSettings_swallows_PlatformException',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kNotifSettingsChannel),
          (call) async {
            throw PlatformException(
              code: 'settings_not_available',
              message: 'OEM blocked',
            );
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kNotifSettingsChannel),
            null,
          );
        });

        final captured = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? msg, {int? wrapWidth}) => captured.add(msg ?? '');
        addTearDown(() => debugPrint = originalDebugPrint);

        final service = FlutterNotificationService();
        await expectLater(service.openNotificationSettings(), completes);

        expect(
          captured.any(
            (m) => m.contains('[NotificationService.openNotificationSettings]'),
          ),
          isTrue,
          reason: 'PlatformException must be surfaced via debugPrint',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group J — BUG-006: Android schedule mode + PlatformException visibility
  // ---------------------------------------------------------------------------
  //
  // Group K — TASK-05: battery-optimisation channel (FR-03 platform side)
  // ---------------------------------------------------------------------------

  group(
      'TASK-05: FlutterNotificationService battery-optimisation channel (FR-03)',
      () {
    const kBatteryChannel = 'metra/battery_optimization';

    test(
      'isIgnoringBatteryOptimizations returns true when channel returns true',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kBatteryChannel),
          (call) async {
            if (call.method == 'isIgnoring') return true;
            return null;
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kBatteryChannel),
            null,
          );
        });

        final service = FlutterNotificationService();
        expect(await service.isIgnoringBatteryOptimizations(), isTrue);
      },
    );

    test(
      'isIgnoringBatteryOptimizations returns false when channel returns false',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kBatteryChannel),
          (call) async {
            if (call.method == 'isIgnoring') return false;
            return null;
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kBatteryChannel),
            null,
          );
        });

        final service = FlutterNotificationService();
        expect(await service.isIgnoringBatteryOptimizations(), isFalse);
      },
    );

    test(
      'isIgnoringBatteryOptimizations returns false on PlatformException (does not propagate)',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kBatteryChannel),
          (call) async {
            throw PlatformException(
              code: 'battery_opt_error',
              message: 'simulated failure',
            );
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kBatteryChannel),
            null,
          );
        });

        final service = FlutterNotificationService();
        // Must not throw; must return false as safe default.
        expect(await service.isIgnoringBatteryOptimizations(), isFalse);
      },
    );

    test(
      'openBatteryOptimizationSettings invokes channel and does not throw on success',
      () async {
        var invoked = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kBatteryChannel),
          (call) async {
            if (call.method == 'openSettings') invoked = true;
            return null;
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kBatteryChannel),
            null,
          );
        });

        final service = FlutterNotificationService();
        await expectLater(
          service.openBatteryOptimizationSettings(),
          completes,
        );
        expect(invoked, isTrue);
      },
    );

    test(
      'openBatteryOptimizationSettings does not throw on PlatformException (emits debugPrint)',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel(kBatteryChannel),
          (call) async {
            throw PlatformException(
              code: 'intent_rejected',
              message: 'OEM blocked',
            );
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel(kBatteryChannel),
            null,
          );
        });

        final captured = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? msg, {int? wrapWidth}) => captured.add(msg ?? '');
        addTearDown(() => debugPrint = originalDebugPrint);

        final service = FlutterNotificationService();
        // Must not throw.
        await expectLater(
          service.openBatteryOptimizationSettings(),
          completes,
        );
        expect(
          captured
              .any((m) => m.contains('[NotificationService.openBatteryOpt]')),
          isTrue,
          reason: 'PlatformException must be surfaced via debugPrint',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------

  group('BUG-006: Android schedule mode + PlatformException visibility', () {
    setUpAll(tz_data.initializeTimeZones);

    test(
      'schedulePredictionNotification uses inexactAllowWhileIdle on Android',
      () async {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final plugin = _RecordingPlugin();
        final service = FlutterNotificationService(pluginOverride: plugin);
        final notifyAt = DateTime(2099, 6, 10, 9, 0);

        await service.schedulePredictionNotification(notifyAt, 'T', 'B');

        expect(
          plugin.recordedMode,
          equals(AndroidScheduleMode.inexactAllowWhileIdle),
        );
      },
    );

    test(
      'schedulePredictionNotification returns NotificationScheduleFailure carrying PlatformException from zonedSchedule',
      () async {
        tz.setLocalLocation(tz.getLocation('Europe/Rome'));
        final plugin = _RecordingPlugin()
          ..throwOnSchedule = PlatformException(
            code: 'exact_alarms_not_permitted',
            message: 'denied',
          );
        final service = FlutterNotificationService(pluginOverride: plugin);
        final captured = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? msg, {int? wrapWidth}) => captured.add(msg ?? '');
        addTearDown(() => debugPrint = originalDebugPrint);
        final notifyAt = DateTime(2099, 6, 10, 9, 0);

        final result = await service.schedulePredictionNotification(
          notifyAt,
          'T',
          'B',
        );

        // BUG-006 (M1 update): schedulePredictionNotification now returns
        // NotificationScheduleFailure carrying the PlatformException instead of
        // propagating it. The method must NOT throw.
        expect(
          result,
          isA<NotificationScheduleFailure>(),
          reason:
              'BUG-006: PlatformException from zonedSchedule must be caught '
              'and returned as NotificationScheduleFailure, not propagated',
        );
        expect(
          (result as NotificationScheduleFailure).error,
          isA<PlatformException>(),
          reason:
              'BUG-006: the failure result must carry the original PlatformException',
        );
        // The debugPrint log is still emitted so the error is observable.
        expect(
          captured.any(
            (m) =>
                m.contains('FlutterNotificationService:') &&
                m.contains('exact_alarms_not_permitted'),
          ),
          isTrue,
          reason: 'BUG-006: PlatformException must be surfaced via debugPrint',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Recording test-double for FlutterLocalNotificationsPlugin (BUG-006).
// Records the androidScheduleMode passed to zonedSchedule; optionally throws
// a PlatformException to exercise the error-logging path.
// noSuchMethod returns null for every other plugin method — sufficient because
// the BUG-006 tests only exercise zonedSchedule.
// ---------------------------------------------------------------------------
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  AndroidScheduleMode? recordedMode;
  PlatformException? throwOnSchedule;

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    // ignore: deprecated_member_use
    bool androidAllowWhileIdle = false,
    AndroidScheduleMode? androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    recordedMode = androidScheduleMode;
    if (throwOnSchedule != null) throw throwOnSchedule!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
