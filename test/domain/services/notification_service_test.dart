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

// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/services/notification_service.dart';

// Minimal stub for type-signature verification.
// The override signature must match the abstract interface exactly; if
// NotificationScheduleResult does not exist yet, this file will not compile
// (desired RED state).
class _StubNotificationService extends NotificationService {
  @override
  Future<NotificationScheduleResult> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  ) async =>
      const NotificationScheduleSuccess();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelPredictionNotifications() async {}

  @override
  Future<PermissionRequestOutcome> requestPermission() async =>
      const PermissionGranted();

  @override
  Future<bool> hasNotificationPermission() async => true;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<void> openBatteryOptimizationSettings() async {}

  @override
  Future<void> openNotificationSettings() async {}
}

void main() {
  group('NotificationScheduleResult sealed class — FR-15, NFR-03', () {
    test(
      'given_NotificationScheduleSuccess_when_checked_then_is_NotificationScheduleResult',
      () {
        expect(
          const NotificationScheduleSuccess(),
          isA<NotificationScheduleResult>(),
        );
      },
    );

    test(
      'given_StateError_when_wrapped_in_NotificationScheduleFailure_then_error_field_is_same_object',
      () {
        final err = StateError('boom');
        final failure = NotificationScheduleFailure(err);
        expect(failure.error, same(err));
        expect(failure, isA<NotificationScheduleResult>());
      },
    );

    test(
      'given_Exception_when_wrapped_in_NotificationScheduleFailure_then_error_field_is_same_object',
      () {
        final err = Exception('platform failure');
        final failure = NotificationScheduleFailure(err);
        expect(failure.error, same(err));
      },
    );

    test(
      'given_notification_service_dart_when_source_inspected_then_no_forbidden_package_imports',
      () {
        final source = File(
          'lib/domain/services/notification_service.dart',
        ).readAsStringSync();
        expect(source, isNot(contains('package:drift')));
        expect(source, isNot(contains('package:http')));
        expect(
          source,
          isNot(contains('package:flutter_local_notifications')),
        );
        expect(source, isNot(contains('package:flutter/services')));
      },
    );

    test(
      'given_stub_implementing_NotificationService_when_schedulePredictionNotification_called_then_returns_NotificationScheduleResult',
      () async {
        final NotificationService svc = _StubNotificationService();
        final result = await svc.schedulePredictionNotification(
          DateTime(2026, 6, 1, 9, 0),
          'title',
          'body',
        );
        expect(result, isA<NotificationScheduleResult>());
        expect(result, isA<NotificationScheduleSuccess>());
      },
    );
  });

  // Group H — PermissionRequestOutcome type (FR-22, FR-23, NFR-07)
  group('PermissionRequestOutcome sealed class — FR-22, FR-23, NFR-07', () {
    test(
      'given_PermissionGranted_when_exhaustive_switch_then_label_is_granted',
      () {
        const PermissionRequestOutcome o = PermissionGranted();
        final label = switch (o) {
          PermissionGranted() => 'granted',
          PermissionDenied() => 'denied',
          PermissionBlocked() => 'blocked',
        };
        expect(label, 'granted');
      },
    );

    test(
      'given_all_three_subtypes_when_constructed_as_const_then_const_canonicalisation_holds',
      () {
        const a = PermissionGranted();
        const b = PermissionDenied();
        const c = PermissionBlocked();
        expect(identical(const PermissionGranted(), a), isTrue);
        expect(identical(const PermissionDenied(), b), isTrue);
        expect(identical(const PermissionBlocked(), c), isTrue);
      },
    );

    test(
      'given_each_subtype_when_checked_then_is_PermissionRequestOutcome',
      () {
        expect(const PermissionGranted(), isA<PermissionRequestOutcome>());
        expect(const PermissionDenied(), isA<PermissionRequestOutcome>());
        expect(const PermissionBlocked(), isA<PermissionRequestOutcome>());
      },
    );

    test(
      'given_notification_service_dart_when_source_inspected_then_no_package_flutter_import',
      () {
        final content = File(
          'lib/domain/services/notification_service.dart',
        ).readAsStringSync();
        expect(
          content.contains('package:flutter'),
          isFalse,
          reason: 'NFR-07: domain file must have zero Flutter imports',
        );
      },
    );
  });
}
