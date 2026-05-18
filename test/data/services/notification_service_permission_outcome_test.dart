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

// Groups F + G: PermissionRequestOutcome detection for FlutterNotificationService.
//
// These tests are in a sibling file (not notification_service_test.dart) because
// the canonical file imports FakeNotificationService which still implements the
// old Future<bool> requestPermission() signature — that is fixed in TASK-11.
// TASK-12 consolidates these groups into the canonical file once TASK-11 is done.
//
// Platform detection strategy:
//   - Android branch: mock the 'dexterous.com/flutter/local_notifications'
//     MethodChannel and rely on defaultTargetPlatform == android (test default).
//   - iOS branch: set debugDefaultTargetPlatformOverride = TargetPlatform.iOS
//     in setUp/tearDown so resolvePlatformSpecificImplementation returns the iOS
//     plugin, then mock the same channel with iOS method names.
//   - "Neither plugin" branch (EC-11): set debugDefaultTargetPlatformOverride =
//     TargetPlatform.linux so both Android and iOS resolutions return null.

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:metra/domain/services/notification_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kNotifChannel = 'dexterous.com/flutter/local_notifications';

// EC-11 "neither plugin" test uses debugDefaultTargetPlatformOverride = linux
// so resolvePlatformSpecificImplementation returns null for both Android + iOS.

// ---------------------------------------------------------------------------
// Channel-log helper for openNotificationSettings tests (Group G)
// ---------------------------------------------------------------------------

class _ChannelLog {
  String? lastInvocation;
  PlatformException? _throwOnNext;

  set throwOnNext(PlatformException e) => _throwOnNext = e;

  Future<Object?> handleCall(MethodCall call) async {
    if (_throwOnNext != null) {
      final e = _throwOnNext!;
      _throwOnNext = null;
      throw e;
    }
    lastInvocation = call.method;
    return null;
  }
}

void main() {
  // -------------------------------------------------------------------------
  // Group F — requestPermission() three-outcome detection
  // -------------------------------------------------------------------------

  group('Group F — Android: requestPermission() PermissionRequestOutcome', () {
    const channel = MethodChannel(_kNotifChannel);

    test('Android — requestNotificationsPermission true → PermissionGranted',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'areNotificationsEnabled') return true;
        if (call.method == 'requestNotificationsPermission') return true;
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final service = FlutterNotificationService();
      final result = await service.requestPermission();
      expect(result, isA<PermissionGranted>());
    });

    test(
      'Android — request false AND before=false AND after=false → PermissionBlocked',
      () async {
        var areEnabledCallCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'areNotificationsEnabled') {
            // First call (before) → false; second call (after) → false.
            areEnabledCallCount++;
            return false;
          }
          if (call.method == 'requestNotificationsPermission') return false;
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final service = FlutterNotificationService();
        final result = await service.requestPermission();
        expect(result, isA<PermissionBlocked>());
        // Both before and after must be queried (exactly 2 calls).
        expect(areEnabledCallCount, equals(2));
      },
    );

    test(
      'Android — request false but areEnabled was true before (state differs) → PermissionDenied',
      () async {
        var areEnabledCallCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'areNotificationsEnabled') {
            areEnabledCallCount++;
            // First call (before) → true (was enabled); second call (after) → false.
            return areEnabledCallCount == 1 ? true : false;
          }
          if (call.method == 'requestNotificationsPermission') return false;
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final service = FlutterNotificationService();
        final result = await service.requestPermission();
        expect(result, isA<PermissionDenied>());
      },
    );

    test(
      'Android pre-API-33 — requestNotificationsPermission returns null (treated as true) → PermissionGranted (EC-14)',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'areNotificationsEnabled') return true;
          // Pre-API-33: method returns null (no runtime permission needed).
          if (call.method == 'requestNotificationsPermission') return null;
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final service = FlutterNotificationService();
        final result = await service.requestPermission();
        // null from requestNotificationsPermission is treated as granted on
        // pre-API-33 devices (EC-14): no runtime permission means always granted.
        expect(result, isA<PermissionGranted>());
      },
    );
  });

  group('Group F — iOS: requestPermission() PermissionRequestOutcome', () {
    const channel = MethodChannel(_kNotifChannel);

    late FlutterLocalNotificationsPlatform savedInstance;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      // The singleton FlutterLocalNotificationsPlugin was initialized for Android.
      // Override the platform instance to iOS so resolvePlatformSpecificImplementation
      // returns the iOS plugin (it checks both defaultTargetPlatform AND instance type).
      savedInstance = FlutterLocalNotificationsPlatform.instance;
      FlutterLocalNotificationsPlatform.instance =
          IOSFlutterLocalNotificationsPlugin();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      FlutterLocalNotificationsPlatform.instance = savedInstance;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'iOS — pre-call checkPermissions isEnabled=true → PermissionGranted; requestPermissions NOT called',
      () async {
        var requestCallCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'checkPermissions') {
            return <String, dynamic>{
              'isEnabled': true,
              'isSoundEnabled': true,
              'isAlertEnabled': true,
              'isBadgeEnabled': true,
              'isProvisionalEnabled': false,
              'isCriticalEnabled': false,
            };
          }
          if (call.method == 'requestPermissions') {
            requestCallCount++;
            return true;
          }
          return null;
        });

        final service = FlutterNotificationService();
        final result = await service.requestPermission();
        expect(result, isA<PermissionGranted>());
        expect(
          requestCallCount,
          equals(0),
          reason:
              'EC-12: must not re-invoke requestPermissions when already enabled',
        );
      },
    );

    test(
      'iOS — pre and post checkPermissions isEnabled=false (dialog suppressed) → PermissionBlocked',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'checkPermissions') {
            return <String, dynamic>{
              'isEnabled': false,
              'isSoundEnabled': false,
              'isAlertEnabled': false,
              'isBadgeEnabled': false,
              'isProvisionalEnabled': false,
              'isCriticalEnabled': false,
            };
          }
          if (call.method == 'requestPermissions') return false;
          return null;
        });

        final service = FlutterNotificationService();
        final result = await service.requestPermission();
        expect(result, isA<PermissionBlocked>());
      },
    );

    // SPEC NOTE: The third iOS case ("pre undetermined, request false, post denied
    // → PermissionDenied") cannot be implemented faithfully with flutter_local_notifications
    // v17 — NotificationsEnabledOptions exposes only isEnabled (not UNAuthorizationStatus.
    // notDetermined). When pre.isEnabled==false AND post.isEnabled==false, the spec
    // returns PermissionBlocked (same as the suppressed-dialog case).
    // This test is intentionally absent per the advisory finding; the case maps to
    // PermissionBlocked in practice. Reported to orchestrator for spec clarification.

    test(
      'iOS — requestPermissions returns true → PermissionGranted',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'checkPermissions') {
            // pre: not enabled
            return <String, dynamic>{
              'isEnabled': false,
              'isSoundEnabled': false,
              'isAlertEnabled': false,
              'isBadgeEnabled': false,
              'isProvisionalEnabled': false,
              'isCriticalEnabled': false,
            };
          }
          if (call.method == 'requestPermissions') return true;
          return null;
        });

        final service = FlutterNotificationService();
        final result = await service.requestPermission();
        expect(result, isA<PermissionGranted>());
      },
    );
  });

  group('Group F — EC-11: neither plugin resolves → PermissionDenied', () {
    test('Neither plugin resolves → PermissionDenied (safe lower bound)',
        () async {
      // Set platform to linux — FlutterLocalNotificationsPlugin only initialises
      // an impl for android/iOS/macOS. On linux, both
      // resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      // and <IOSFlutterLocalNotificationsPlugin>() return null (EC-11).
      // Must return PermissionDenied, NOT PermissionBlocked (safe lower bound).
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final service = FlutterNotificationService();
      final result = await service.requestPermission();
      expect(result, isA<PermissionDenied>());
    });
  });

  // -------------------------------------------------------------------------
  // Group G — openNotificationSettings()
  // -------------------------------------------------------------------------

  group('Group G — openNotificationSettings()', () {
    const notifSettingsChannel = MethodChannel('metra/notification_settings');

    test(
      'openNotificationSettings — Android channel records invokeMethod("open")',
      () async {
        final log = _ChannelLog();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(notifSettingsChannel, log.handleCall);
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(notifSettingsChannel, null);
        });

        final service = FlutterNotificationService();
        await service.openNotificationSettings();
        expect(log.lastInvocation, equals('open'));
      },
    );

    test(
      'openNotificationSettings — PlatformException swallowed (no rethrow)',
      () async {
        final log = _ChannelLog();
        log.throwOnNext = PlatformException(code: 'X', message: 'test error');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(notifSettingsChannel, log.handleCall);
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(notifSettingsChannel, null);
        });

        final captured = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? msg, {int? wrapWidth}) => captured.add(msg ?? '');
        addTearDown(() => debugPrint = originalDebugPrint);

        final service = FlutterNotificationService();
        // Must not throw.
        await expectLater(service.openNotificationSettings(), completes);
        // Must log the exception via debugPrint.
        expect(
          captured.any(
            (m) => m.contains('[NotificationService.openNotificationSettings]'),
          ),
          isTrue,
          reason: 'PlatformException must be surfaced via debugPrint',
        );
      },
    );

    test(
      'openNotificationSettings — iOS: attempts open via channel when no iOS plugin open path',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        // No need to override FlutterLocalNotificationsPlatform.instance here —
        // openNotificationSettings goes through the MethodChannel directly,
        // independent of plugin resolution.

        final log = _ChannelLog();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(notifSettingsChannel, log.handleCall);
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(notifSettingsChannel, null);
        });

        final service = FlutterNotificationService();
        await service.openNotificationSettings();
        expect(log.lastInvocation, equals('open'));
      },
    );
  });
}
