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

// iOS branch unit tests for FlutterNotificationService.
//
// All tests run on Linux CI via a fake FlutterLocalNotificationsPlugin
// injected through the @visibleForTesting pluginOverride constructor param.
// No platform channel is touched; no MethodChannel mock is needed.
//
// Spec refs: FR-01, FR-02, FR-03, NFR-07, EC-10, EC-11
//
// Plan deviation note:
//   The plan lists a test case "NotificationsEnabledOptions(isEnabled: null)
//   → result == true". In flutter_local_notifications 17.2.x,
//   NotificationsEnabledOptions.isEnabled is `required final bool` (non-nullable).
//   It is impossible to construct NotificationsEnabledOptions with isEnabled==null.
//   That case is semantically identical to checkPermissions() returning null
//   (which is already tested by "checkPermissions returns null → true (NFR-07)").
//   The impossible test case is dropped; all other plan assertions are preserved.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/notification_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Group A — hasNotificationPermission (FR-01, NFR-07, EC-10)
  // ---------------------------------------------------------------------------

  group('Group A — hasNotificationPermission iOS branch', () {
    test(
      'iOS plugin with isEnabled:true → result is true; '
      'checkPermissions called once; requestPermissions never called',
      () async {
        final iosStub = _FakeIOSPlugin(checkResult: _enabledOptions(true));
        final plugin = _FakePlugin(iosPlugin: iosStub);
        final service = FlutterNotificationService(pluginOverride: plugin);

        final result = await service.hasNotificationPermission();

        expect(result, isTrue);
        expect(iosStub.checkPermissionsCallCount, equals(1));
        expect(iosStub.requestPermissionsCallCount, equals(0));
      },
    );

    test(
      'iOS plugin with isEnabled:false → result is false (NFR-07 fail-open '
      'applies to null, not explicit false)',
      () async {
        final iosStub = _FakeIOSPlugin(checkResult: _enabledOptions(false));
        final plugin = _FakePlugin(iosPlugin: iosStub);
        final service = FlutterNotificationService(pluginOverride: plugin);

        final result = await service.hasNotificationPermission();

        expect(result, isFalse);
        expect(iosStub.checkPermissionsCallCount, equals(1));
        expect(iosStub.requestPermissionsCallCount, equals(0));
      },
    );

    test(
      'iOS plugin checkPermissions returns null → result is true (NFR-07 fail-open)',
      () async {
        final iosStub = _FakeIOSPlugin(checkResult: null);
        final plugin = _FakePlugin(iosPlugin: iosStub);
        final service = FlutterNotificationService(pluginOverride: plugin);

        final result = await service.hasNotificationPermission();

        expect(result, isTrue);
        expect(iosStub.checkPermissionsCallCount, equals(1));
      },
    );

    test(
      'Both Android and iOS resolvers return null → result is true (EC-10 '
      'fail-open); no exception thrown',
      () async {
        final plugin = _FakePlugin(iosPlugin: null, androidPlugin: null);
        final service = FlutterNotificationService(pluginOverride: plugin);

        expect(
          service.hasNotificationPermission,
          returnsNormally,
        );
        final result = await service.hasNotificationPermission();
        expect(result, isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group B — requestPermission (FR-02, NFR-07, EC-10)
  // ---------------------------------------------------------------------------

  group('Group B — requestPermission iOS branch', () {
    test(
      'iOS plugin requestPermissions returns true → result is true; '
      'called exactly once with (sound:true, alert:true, badge:true); '
      'checkPermissions never called',
      () async {
        final iosStub = _FakeIOSPlugin(requestResult: true);
        final plugin = _FakePlugin(iosPlugin: iosStub);
        final service = FlutterNotificationService(pluginOverride: plugin);

        final result = await service.requestPermission();

        expect(result, isTrue);
        expect(iosStub.requestPermissionsCallCount, equals(1));
        expect(
          iosStub.lastRequestArgs,
          equals({'sound': true, 'alert': true, 'badge': true}),
        );
        expect(iosStub.checkPermissionsCallCount, equals(0));
      },
    );

    test(
      'iOS plugin requestPermissions returns false → result is false',
      () async {
        final iosStub = _FakeIOSPlugin(requestResult: false);
        final plugin = _FakePlugin(iosPlugin: iosStub);
        final service = FlutterNotificationService(pluginOverride: plugin);

        final result = await service.requestPermission();

        expect(result, isFalse);
        expect(iosStub.requestPermissionsCallCount, equals(1));
      },
    );

    test(
      'iOS plugin requestPermissions returns null → result is false '
      '(NFR-07 fail-closed for explicit request)',
      () async {
        final iosStub = _FakeIOSPlugin(requestResult: null);
        final plugin = _FakePlugin(iosPlugin: iosStub);
        final service = FlutterNotificationService(pluginOverride: plugin);

        final result = await service.requestPermission();

        expect(result, isFalse);
        expect(iosStub.requestPermissionsCallCount, equals(1));
      },
    );

    test(
      'Both Android and iOS resolvers return null → result is false (EC-10 '
      'fail-closed for explicit request); no exception thrown',
      () async {
        final plugin = _FakePlugin(iosPlugin: null, androidPlugin: null);
        final service = FlutterNotificationService(pluginOverride: plugin);

        expect(
          service.requestPermission,
          returnsNormally,
        );
        final result = await service.requestPermission();
        expect(result, isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group C — Android branch preserved (FR-03)
  // When Android resolver is non-null, Android plugin is used and
  // iOS resolver/methods are never touched.
  // ---------------------------------------------------------------------------

  group('Group C — Android branch preserved (FR-03)', () {
    test(
      'hasNotificationPermission: Android resolver non-null → Android plugin '
      'called; iOS resolver and iOS methods never touched',
      () async {
        final androidStub = _FakeAndroidPlugin(areEnabled: true);
        final iosStub = _FakeIOSPlugin(checkResult: _enabledOptions(false));
        final plugin = _FakePlugin(
          androidPlugin: androidStub,
          iosPlugin: iosStub,
        );
        final service = FlutterNotificationService(pluginOverride: plugin);

        final result = await service.hasNotificationPermission();

        expect(result, isTrue);
        expect(androidStub.areNotificationsEnabledCallCount, equals(1));
        expect(iosStub.checkPermissionsCallCount, equals(0));
        expect(iosStub.requestPermissionsCallCount, equals(0));
      },
    );

    test(
      'requestPermission: Android resolver non-null → Android plugin called; '
      'iOS resolver and iOS methods never touched',
      () async {
        final androidStub = _FakeAndroidPlugin(requestResult: true);
        final iosStub = _FakeIOSPlugin(requestResult: false);
        final plugin = _FakePlugin(
          androidPlugin: androidStub,
          iosPlugin: iosStub,
        );
        final service = FlutterNotificationService(pluginOverride: plugin);

        final result = await service.requestPermission();

        expect(result, isTrue);
        expect(androidStub.requestNotificationsPermissionCallCount, equals(1));
        expect(iosStub.requestPermissionsCallCount, equals(0));
        expect(iosStub.checkPermissionsCallCount, equals(0));
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

NotificationsEnabledOptions _enabledOptions(bool enabled) =>
    NotificationsEnabledOptions(
      isEnabled: enabled,
      isSoundEnabled: enabled,
      isAlertEnabled: enabled,
      isBadgeEnabled: enabled,
      isProvisionalEnabled: false,
      isCriticalEnabled: false,
    );

/// Fake [FlutterLocalNotificationsPlugin] that returns configurable
/// platform-specific implementations for iOS and Android resolvers.
///
/// All other methods return null via [noSuchMethod].
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  _FakePlugin({
    _FakeIOSPlugin? iosPlugin,
    _FakeAndroidPlugin? androidPlugin,
  })  : _iosPlugin = iosPlugin,
        _androidPlugin = androidPlugin;

  final _FakeIOSPlugin? _iosPlugin;
  final _FakeAndroidPlugin? _androidPlugin;

  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() {
    if (T == IOSFlutterLocalNotificationsPlugin) {
      return _iosPlugin as T?;
    }
    if (T == AndroidFlutterLocalNotificationsPlugin) {
      return _androidPlugin as T?;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Fake [IOSFlutterLocalNotificationsPlugin] that records calls and returns
/// configurable results for [checkPermissions] and [requestPermissions].
class _FakeIOSPlugin implements IOSFlutterLocalNotificationsPlugin {
  _FakeIOSPlugin({
    this.checkResult,
    this.requestResult,
  });

  final NotificationsEnabledOptions? checkResult;
  final bool? requestResult;

  int checkPermissionsCallCount = 0;
  int requestPermissionsCallCount = 0;
  Map<String, bool>? lastRequestArgs;

  @override
  Future<NotificationsEnabledOptions?> checkPermissions() async {
    checkPermissionsCallCount++;
    return checkResult;
  }

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
  }) async {
    requestPermissionsCallCount++;
    lastRequestArgs = {
      'sound': sound,
      'alert': alert,
      'badge': badge,
    };
    return requestResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Fake [AndroidFlutterLocalNotificationsPlugin] that records calls and returns
/// configurable results for [areNotificationsEnabled] and
/// [requestNotificationsPermission].
class _FakeAndroidPlugin implements AndroidFlutterLocalNotificationsPlugin {
  _FakeAndroidPlugin({
    this.areEnabled,
    this.requestResult,
  });

  final bool? areEnabled;
  final bool? requestResult;

  int areNotificationsEnabledCallCount = 0;
  int requestNotificationsPermissionCallCount = 0;

  @override
  Future<bool?> areNotificationsEnabled() async {
    areNotificationsEnabledCallCount++;
    return areEnabled;
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    requestNotificationsPermissionCallCount++;
    return requestResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
