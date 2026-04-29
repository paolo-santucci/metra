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

void main() {
  group('NotificationService interface', () {
    test('FakeNotificationService implements NotificationService', () {
      final fake = _FakeNotificationService();
      expect(fake, isA<NotificationService>());
    });

    test('initialize() sets the initialized flag', () async {
      final fake = _FakeNotificationService();
      expect(fake.initialized, isFalse);
      await fake.initialize();
      expect(fake.initialized, isTrue);
    });

    test('schedulePredictionNotification() records the call', () async {
      final fake = _FakeNotificationService();
      final date = DateTime(2026, 5, 10);
      await fake.schedulePredictionNotification(date, 'Title', 'Body');
      expect(fake.scheduled, hasLength(1));
      expect(fake.scheduled.first.$1, equals(date));
      expect(fake.scheduled.first.$2, equals('Title'));
      expect(fake.scheduled.first.$3, equals('Body'));
    });

    test('cancelPredictionNotifications() increments cancelCount', () async {
      final fake = _FakeNotificationService();
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
}

// ---------------------------------------------------------------------------
// Test double
// ---------------------------------------------------------------------------

class _FakeNotificationService implements NotificationService {
  bool initialized = false;
  final List<(DateTime, String, String)> scheduled = [];
  int cancelCount = 0;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<void> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  ) async =>
      scheduled.add((notifyAt, title, body));

  @override
  Future<void> cancelPredictionNotifications() async => cancelCount++;
}
