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
import 'package:metra/domain/services/notification_service.dart';

class FakeNotificationService implements NotificationService {
  bool initialized = false;
  final List<({DateTime notifyAt, String title, String body})> scheduled = [];
  int cancelCount = 0;
  bool permissionGranted;

  /// Configurable return value for [isIgnoringBatteryOptimizations].
  ///
  /// Defaults to [true] (whitelisted). Set to [false] to exercise the
  /// "not whitelisted" branch in Settings UI tests (TASK-07, FR-03).
  bool isIgnoringBatteryOptimizationsValue;

  /// Configurable return value for [hasNotificationPermission].
  ///
  /// Defaults to [true] (permission granted). Set to [false] to exercise the
  /// "OS permission revoked" branch in cold-start re-check tests (Fix #2,
  /// FR-07).
  bool hasNotificationPermissionValue;

  /// Number of times [hasNotificationPermission] has been called.
  ///
  /// Used by Fix #2 / FR-07 tests to assert the cold-start re-check calls
  /// the read-only method exactly once and never calls [requestPermission].
  int hasNotificationPermissionCallCount = 0;

  /// Number of times [openBatteryOptimizationSettings] has been called.
  ///
  /// Used by TASK-07 widget tests to assert that tapping the Settings row
  /// invokes the method exactly once (FR-03).
  int openBatteryOptimizationSettingsCallCount = 0;

  /// Number of times [requestPermission] has been called.
  ///
  /// Used by BUG-002 regression tests to verify the cold-start guard
  /// does not call requestPermission() during AsyncLoading → AsyncData
  /// transitions (FR-04, EC-05). Fix #2 asserts this stays at 0 during
  /// cold-start re-checks.
  int requestPermissionCallCount = 0;

  /// Optional clock override for deterministic tests. Defaults to DateTime.now().
  ///
  /// Deprecated: prefer the [now] callback parameter which supports
  /// advancing time across calls in a single test instance.
  @Deprecated('Use now: () => yourDateTime instead')
  final DateTime? _nowOverride;

  /// Optional clock factory for deterministic tests. Evaluated on each call
  /// to [_now]. Takes precedence over [nowOverride].
  final DateTime Function()? _nowFn;

  /// Whether the next call to [schedulePredictionNotification] should throw
  /// a [PlatformException] instead of scheduling. Auto-clears after one use
  /// (one-shot — FR-14, OQ-M1-05). Set in tests to exercise the caller's
  /// error-handling path.
  bool throwOnNextSchedule = false;

  /// Number of times the immediate-show path was triggered (cold-start same-day case).
  int showCount = 0;

  /// Records of immediately-shown notifications (cold-start same-day case).
  final List<({DateTime notifyAt, String title, String body})> shown = [];

  FakeNotificationService({
    this.permissionGranted = true,
    this.isIgnoringBatteryOptimizationsValue = true,
    this.hasNotificationPermissionValue = true,
    @Deprecated('Use now: () => yourDateTime instead') DateTime? nowOverride,
    DateTime Function()? now,
  })  : _nowOverride = nowOverride,
        _nowFn = now;

  DateTime _now() => _nowFn?.call() ?? _nowOverride ?? DateTime.now();

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<NotificationScheduleResult> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  ) async {
    // One-shot failure injection — FR-14, EC-11 (throw-before-mutation).
    if (throwOnNextSchedule) {
      throwOnNextSchedule = false; // auto-clear before throw
      throw PlatformException(
        code: 'fake_schedule_failure',
        message: 'FakeNotificationService.throwOnNextSchedule injected failure',
      );
    }

    final local = notifyAt.toLocal();
    final notifyDay = DateTime(local.year, local.month, local.day);
    final nowTime = _now();
    final nowDay = DateTime(nowTime.year, nowTime.month, nowTime.day);
    final sameDay = notifyDay == nowDay;
    final atOrBeforeNow = !local.isAfter(nowTime);

    if (sameDay && atOrBeforeNow) {
      shown.add((notifyAt: notifyAt, title: title, body: body));
      showCount++;
    } else {
      scheduled.add((notifyAt: notifyAt, title: title, body: body));
    }
    return const NotificationScheduleSuccess();
  }

  @override
  Future<void> cancelPredictionNotifications() async {
    cancelCount++;
    scheduled.clear();
    shown.clear();
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCallCount++;
    return permissionGranted;
  }

  @override
  Future<bool> hasNotificationPermission() async {
    hasNotificationPermissionCallCount++;
    return hasNotificationPermissionValue;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async =>
      isIgnoringBatteryOptimizationsValue;

  @override
  Future<void> openBatteryOptimizationSettings() async {
    openBatteryOptimizationSettingsCallCount++;
  }
}
