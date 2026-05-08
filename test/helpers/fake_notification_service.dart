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

import 'package:metra/domain/services/notification_service.dart';

class FakeNotificationService implements NotificationService {
  bool initialized = false;
  final List<({DateTime notifyAt, String title, String body})> scheduled = [];
  int cancelCount = 0;
  bool permissionGranted;

  /// Number of times [requestPermission] has been called.
  ///
  /// Used by BUG-002 regression tests to verify the cold-start guard
  /// does not call requestPermission() during AsyncLoading → AsyncData
  /// transitions (FR-04, EC-05).
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

  /// Number of times the immediate-show path was triggered (cold-start same-day case).
  int showCount = 0;

  /// Records of immediately-shown notifications (cold-start same-day case).
  final List<({DateTime notifyAt, String title, String body})> shown = [];

  FakeNotificationService({
    this.permissionGranted = true,
    @Deprecated('Use now: () => yourDateTime instead') DateTime? nowOverride,
    DateTime Function()? now,
  })  : _nowOverride = nowOverride,
        _nowFn = now;

  DateTime _now() => _nowFn?.call() ?? _nowOverride ?? DateTime.now();

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<void> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  ) async {
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
}
